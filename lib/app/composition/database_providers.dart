import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';

/// Riverpod provider exposing the singleton [AppDatabase] instance.
/// Automatically closes the database connection when disposed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
