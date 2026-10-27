import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:getto/features/onboarding/data/file_onboarding_store.dart';

void main() {
  late Directory directory;
  late File file;
  late FileOnboardingStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('getto_onboarding_');
    file = File('${directory.path}/onboarding.v1');
    store = FileOnboardingStore(() async => file);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('first launch is incomplete; committed Explore/completion survives a new store', () async {
    expect((await store.readCompleted()).valueOrNull, isFalse);
    expect((await store.complete()).isSuccess, isTrue);
    final restarted = FileOnboardingStore(() async => File(file.path));
    expect((await restarted.readCompleted()).valueOrNull, isTrue);
    expect(await File('${file.path}.pending').exists(), isFalse);
    expect((await restarted.complete()).isSuccess, isTrue);
  });

  test(
    'interrupted pending write is not acknowledged; committed marker wins',
    () async {
      await File('${file.path}.pending').writeAsString('partial');
      expect((await store.readCompleted()).valueOrNull, isFalse);
      expect((await store.complete()).isSuccess, isTrue);
      await File('${file.path}.pending').writeAsString('partial');
      expect((await store.readCompleted()).valueOrNull, isTrue);
    },
  );

  test('corrupt or future-version progress reports failure without overwriting bytes', () async {
    await file.writeAsString('future.version');
    expect((await store.readCompleted()).isFailure, isTrue);
    expect(await file.readAsString(), 'future.version');
  });

  test(
    'write failure returns typed failure and can recover without false success',
    () async {
      final missing = Directory('${directory.path}/unavailable');
      final retryStore = FileOnboardingStore(
        () async => File('${missing.path}/onboarding.v1'),
      );
      expect((await retryStore.complete()).isFailure, isTrue);
      await missing.create();
      expect((await retryStore.complete()).isSuccess, isTrue);
      expect((await retryStore.readCompleted()).valueOrNull, isTrue);
    },
  );
}
