import 'dart:io';

import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../application/onboarding_store.dart';

class FileOnboardingStore implements OnboardingStore {
  FileOnboardingStore(this._file);
  final Future<File> Function() _file;
  static const _completed = 'getto.onboarding.v1:complete\n';

  @override
  Future<Result<bool, DataFailure>> readCompleted() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const Result.success(false);
      if (await file.readAsString() != _completed) {
        return const Result.failure(
          StorageIoFailure('Setup progress could not be read.'),
        );
      }
      return const Result.success(true);
    } catch (_) {
      return const Result.failure(
        StorageIoFailure('Setup progress could not be read.'),
      );
    }
  }

  @override
  Future<Result<void, DataFailure>> complete() async {
    try {
      final file = await _file();
      // A previous committed marker remains authoritative until replacement.
      // An interrupted pending file is never treated as acknowledged progress.
      final pending = File('${file.path}.pending');
      await pending.writeAsString(_completed, flush: true);
      await pending.rename(file.path);
      return const Result.success(null);
    } catch (_) {
      return const Result.failure(
        StorageIoFailure('Setup progress could not be saved.'),
      );
    }
  }
}
