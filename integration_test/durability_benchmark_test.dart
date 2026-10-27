import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

class LatencyReport {
  LatencyReport({
    required this.name,
    required this.sampleSize,
    required this.minMs,
    required this.meanMs,
    required this.p50Ms,
    required this.p90Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.maxMs,
    required this.stdDevMs,
  });

  final String name;
  final int sampleSize;
  final double minMs;
  final double meanMs;
  final double p50Ms;
  final double p90Ms;
  final double p95Ms;
  final double p99Ms;
  final double maxMs;
  final double stdDevMs;

  @override
  String toString() {
    return '=== $name (N=$sampleSize) ===\n'
        '  Min:      ${minMs.toStringAsFixed(2)} ms\n'
        '  Mean:     ${meanMs.toStringAsFixed(2)} ms\n'
        '  P50:      ${p50Ms.toStringAsFixed(2)} ms\n'
        '  P90:      ${p90Ms.toStringAsFixed(2)} ms\n'
        '  P95:      ${p95Ms.toStringAsFixed(2)} ms\n'
        '  P99:      ${p99Ms.toStringAsFixed(2)} ms\n'
        '  Worst:    ${maxMs.toStringAsFixed(2)} ms\n'
        '  StdDev:   ${stdDevMs.toStringAsFixed(2)} ms\n';
  }
}

LatencyReport computeReport(String name, List<int> microsecondsList) {
  final sorted = List<int>.from(microsecondsList)..sort();
  final n = sorted.length;
  final double minMs = sorted.first / 1000.0;
  final double maxMs = sorted.last / 1000.0;
  final double sumMs = sorted.fold<int>(0, (a, b) => a + b) / 1000.0;
  final double meanMs = sumMs / n;

  double percentile(double p) {
    final index = (p * (n - 1)).round();
    return sorted[index] / 1000.0;
  }

  final double p50Ms = percentile(0.50);
  final double p90Ms = percentile(0.90);
  final double p95Ms = percentile(0.95);
  final double p99Ms = percentile(0.99);

  final variance =
      sorted
          .map((us) => pow((us / 1000.0) - meanMs, 2))
          .fold<double>(0.0, (a, b) => a + b) /
      n;
  final stdDevMs = sqrt(variance);

  return LatencyReport(
    name: name,
    sampleSize: n,
    minMs: minMs,
    meanMs: meanMs,
    p50Ms: p50Ms,
    p90Ms: p90Ms,
    p95Ms: p95Ms,
    p99Ms: p99Ms,
    maxMs: maxMs,
    stdDevMs: stdDevMs,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Empirical SQLite durability benchmark on physical hardware (NORMAL vs FULL)',
    (tester) async {
      final docDir = await getApplicationDocumentsDirectory();
      final benchDir = Directory('${docDir.path}/benchmark_durable');
      if (await benchDir.exists()) {
        await benchDir.delete(recursive: true);
      }
      await benchDir.create(recursive: true);

      const repetitions = 100;
      const warmupCount = 10;

      Future<LatencyReport> runBenchmark({
        required String name,
        required String syncPragma,
      }) async {
        final dbFile = File('${benchDir.path}/$name.sqlite');
        final db = AppDatabase(
          NativeDatabase.createInBackground(
            dbFile,
            setup: (rawDb) {
              rawDb.execute('PRAGMA foreign_keys = ON;');
              rawDb.execute('PRAGMA journal_mode = WAL;');
              rawDb.execute('PRAGMA synchronous = $syncPragma;');
            },
          ),
        );

        // Await table creation and verify PRAGMAs
        final syncModeRow = await db
            .customSelect('PRAGMA synchronous;')
            .getSingle();
        final journalModeRow = await db
            .customSelect('PRAGMA journal_mode;')
            .getSingle();
        final actualSync = syncModeRow.data['synchronous'];
        final actualJournal = journalModeRow.data['journal_mode'];

        // Warm up and verify seed
        final kitchen = await (db.select(
          db.areasTable,
        )..where((t) => t.name.equals('Kitchen'))).getSingle();

        for (var i = 0; i < warmupCount; i++) {
          await db.transaction(() async {
            await db
                .into(db.itemsTable)
                .insert(
                  ItemsTableCompanion.insert(
                    areaId: kitchen.id,
                    name: 'Warmup Item $i',
                    behaviorProfile: BehaviorProfile.replenishable,
                    stockStatus: StockStatus.inStock,
                  ),
                );
          });
        }

        final latenciesUs = <int>[];
        final stopwatch = Stopwatch();

        for (var i = 0; i < repetitions; i++) {
          final isEven = i % 2 == 0;
          stopwatch.reset();
          stopwatch.start();

          await db.transaction(() async {
            if (isEven) {
              await db
                  .into(db.itemsTable)
                  .insert(
                    ItemsTableCompanion.insert(
                      areaId: kitchen.id,
                      name: 'Benchmark Item $i',
                      behaviorProfile: BehaviorProfile.countableReplenishable,
                      stockStatus: StockStatus.inStock,
                      packageCount: Value(i + 1),
                    ),
                  );
            } else {
              // Update status and package count on previously inserted item
              final lastItem =
                  await (db.select(db.itemsTable)
                        ..orderBy([(t) => OrderingTerm.desc(t.id)])
                        ..limit(1))
                      .getSingle();

              await (db.update(
                db.itemsTable,
              )..where((t) => t.id.equals(lastItem.id))).write(
                const ItemsTableCompanion(
                  stockStatus: Value(StockStatus.outOfStock),
                  packageCount: Value(0),
                ),
              );
            }
          });

          stopwatch.stop();
          latenciesUs.add(stopwatch.elapsedMicroseconds);
        }

        await db.close();

        return computeReport(
          '$name (journal=$actualJournal, synchronous=$actualSync)',
          latenciesUs,
        );
      }

      // Execute NORMAL benchmark
      final reportNormal = await runBenchmark(
        name: 'WAL_NORMAL',
        syncPragma: 'NORMAL',
      );

      // Execute FULL benchmark
      final reportFull = await runBenchmark(
        name: 'WAL_FULL',
        syncPragma: 'FULL',
      );

      // Output reports
      // ignore: avoid_print
      print('\n================ DURABILITY BENCHMARK RESULTS ================');
      // ignore: avoid_print
      print(reportNormal);
      // ignore: avoid_print
      print(reportFull);
      // ignore: avoid_print
      print('==============================================================\n');

      expect(reportNormal.sampleSize, repetitions);
      expect(reportFull.sampleSize, repetitions);

      // Both must satisfy the ordinary local acknowledgement <= 100ms target
      expect(
        reportNormal.p95Ms,
        lessThanOrEqualTo(100.0),
        reason: 'WAL NORMAL P95 must be <= 100ms',
      );
      expect(
        reportFull.p95Ms,
        lessThanOrEqualTo(100.0),
        reason: 'WAL FULL P95 must be <= 100ms',
      );

      // Clean up benchmark files
      if (await benchDir.exists()) {
        await benchDir.delete(recursive: true);
      }
    },
  );
}
