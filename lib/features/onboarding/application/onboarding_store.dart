import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';

/// Approved local settings boundary; household schema remains unchanged.
abstract interface class OnboardingStore {
  Future<Result<bool, DataFailure>> readCompleted();
  Future<Result<void, DataFailure>> complete();
}
