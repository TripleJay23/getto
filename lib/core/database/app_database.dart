import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/household/domain/behavior_profile.dart';
import '../../features/household/domain/stock_status.dart';
import 'converters/household_converters.dart';
import 'tables/areas_table.dart';
import 'tables/items_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [AreasTable, ItemsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Seed new households only; existing catalogs are never rewritten (M2.3.2-D03).
        final defaultAreas = [
          AreasTableCompanion.insert(
            name: 'Kitchen',
            iconName: const Value('kitchen'),
            displayOrder: const Value(0),
            isSystem: const Value(true),
          ),
          AreasTableCompanion.insert(
            name: 'Bathroom',
            iconName: const Value('bathroom'),
            displayOrder: const Value(1),
            isSystem: const Value(true),
          ),
          AreasTableCompanion.insert(
            name: 'Bedroom',
            iconName: const Value('bedroom'),
            displayOrder: const Value(2),
            isSystem: const Value(true),
          ),
          AreasTableCompanion.insert(
            name: 'Living Room',
            iconName: const Value('living_room'),
            displayOrder: const Value(3),
            isSystem: const Value(true),
          ),
        ];

        await batch((batch) {
          batch.insertAll(areasTable, defaultAreas);
        });
      },
      beforeOpen: (details) async {
        // Enforce foreign keys on every SQLite connection (M2-D04)
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File('${dbFolder.path}/getto.sqlite');
      return NativeDatabase.createInBackground(
        file,
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
          rawDb.execute('PRAGMA journal_mode = WAL;');
          rawDb.execute('PRAGMA synchronous = FULL;');
        },
      );
    });
  }
}
