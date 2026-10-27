import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/domain/result/result.dart';

void main() {
  group('Result', () {
    test('Success holds value and reports correct flags', () {
      const result = Result<int, Failure>.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('FailureResult holds failure and reports correct flags', () {
      const failure = StorageIoFailure('Disk error');
      const result = Result<int, Failure>.failure(failure);
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('fold handles both success and failure cases', () {
      const success = Result<int, Failure>.success(10);
      final successValue = success.fold(
        onSuccess: (v) => v * 2,
        onFailure: (f) => -1,
      );
      expect(successValue, 20);

      const failure = Result<int, Failure>.failure(StorageIoFailure('error'));
      final failureValue = failure.fold(
        onSuccess: (v) => v * 2,
        onFailure: (f) => -1,
      );
      expect(failureValue, -1);
    });

    test('map transforms success value and preserves failure', () {
      const success = Result<int, Failure>.success(5);
      final mappedSuccess = success.map((v) => '$v items');
      expect(mappedSuccess.valueOrNull, '5 items');

      const failure = Result<int, Failure>.failure(StorageIoFailure('err'));
      final mappedFailure = failure.map((v) => '$v items');
      expect(mappedFailure.isFailure, isTrue);
      expect(mappedFailure.failureOrNull?.message, 'err');
    });

    test('flatMap chains Results', () {
      Result<String, Failure> doubleToString(int v) =>
          Result.success('${v * 2}');
      Result<String, Failure> failOnZero(int v) => v == 0
          ? const Result.failure(ValidationError('Zero not allowed'))
          : Result.success('$v');

      const s1 = Result<int, Failure>.success(10);
      expect(s1.flatMap(doubleToString).valueOrNull, '20');

      const s2 = Result<int, Failure>.success(0);
      expect(s2.flatMap(failOnZero).isFailure, isTrue);
    });
  });
}
