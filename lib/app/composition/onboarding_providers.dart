import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/onboarding/application/onboarding_store.dart';
import '../../features/onboarding/data/file_onboarding_store.dart';

final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => FileOnboardingStore(() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/onboarding.v1');
  }),
);

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final result = await ref.watch(onboardingStoreProvider).readCompleted();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (_) => throw StateError('Setup progress could not be read.'),
  );
});
