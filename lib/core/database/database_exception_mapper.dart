import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:sqlite3/sqlite3.dart';

import '../domain/result/failure.dart';

/// Maps SQLite and Drift exceptions into typed, actionable [DataFailure] instances.
/// Ensures no sensitive household data or unstructured SQL dumps leak across layers.
DataFailure mapDatabaseException(Object error, [StackTrace? stackTrace]) {
  Object actual = error;
  // NativeDatabase.createInBackground transports the original SQLite error.
  // Unwrap structured causes only; never inspect/log remote SQL or stack text.
  for (var depth = 0; depth < 8; depth++) {
    if (actual is DriftWrappedException && actual.cause != null) {
      actual = actual.cause!;
    } else if (actual is DriftRemoteException) {
      actual = actual.remoteCause;
    } else {
      break;
    }
  }

  if (actual is SqliteException) {
    final message = actual.message.toLowerCase();
    final extendedCode = actual.extendedResultCode;
    final diagnostic = DatabaseDiagnosticInfo(
      resultCode: actual.resultCode,
      extendedResultCode: extendedCode,
    );

    // Unique constraint violations
    if (extendedCode == 2067 ||
        extendedCode == 1555 ||
        message.contains('unique constraint') ||
        message.contains('unique')) {
      return UniqueConflictFailure(
        'An active record with this unique constraint already exists',
        diagnostic,
      );
    }

    // Foreign key constraint violations
    if (extendedCode == 787 || message.contains('foreign key')) {
      return ForeignConstraintFailure(
        'Referenced entity does not exist or has active dependents preventing modification',
        diagnostic,
      );
    }

    // Check constraint violations
    if (extendedCode == 275 ||
        extendedCode == 1811 ||
        extendedCode == 1299 ||
        message.contains('check constraint')) {
      return CheckConstraintFailure(
        'Operation violates database check constraints and consistency rules',
        diagnostic,
      );
    }

    // Database locking
    if (actual.resultCode == 5 ||
        actual.resultCode == 6 ||
        message.contains('busy') ||
        message.contains('locked')) {
      return DatabaseLockedFailure(
        'Database is currently locked by a concurrent operation',
        diagnostic,
      );
    }

    // Storage I/O errors
    if (actual.resultCode == 10 || message.contains('disk i/o')) {
      return StorageIoFailure(
        'Storage I/O failure while reading or writing to local database',
        diagnostic,
      );
    }

    // Database corruption
    if (actual.resultCode == 11 ||
        actual.resultCode == 26 ||
        message.contains('corrupt')) {
      return DatabaseCorruptionFailure(
        'Local database corruption detected',
        diagnostic,
      );
    }

    return UnexpectedDataFailure(
      'Database operation failed with SQLite error code ${actual.resultCode}',
      diagnostic,
    );
  }

  if (actual is DataFailure) {
    return actual;
  }

  return UnexpectedDataFailure(
    'Unexpected data access failure',
    actual.runtimeType.toString(),
  );
}
