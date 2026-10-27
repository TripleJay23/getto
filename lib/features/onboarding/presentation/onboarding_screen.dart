import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/composition/household_providers.dart';
import '../../../app/composition/onboarding_providers.dart';
import '../../../design_system/components/getto_screen_artwork.dart';
import '../../../design_system/components/getto_status_badge.dart';
import '../../../design_system/tokens/getto_colors.dart';
import '../../../design_system/typography/getto_typography.dart';
import '../../household/domain/item.dart';
import '../../household/domain/stock_status.dart';
import '../../household/presentation/household_widgets.dart';
import '../../household/presentation/item_entry_sheet.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  Item? saved;
  bool busy = false;
  String? error;
  bool redirectScheduled = false;
  Future<void> complete() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await ref.read(onboardingStoreProvider).complete();
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(onboardingCompletedProvider);
      context.go('/home');
    } else {
      setState(() {
        busy = false;
        error = saved == null ? "Couldn't save setup progress. Please retry." : 'Your item is saved. Setup progress could not be saved. Retry to continue to Home.';
      });
    }
  }

  Future<void> add() async {
    if (busy) return;
    setState(() => busy = true);
    final item = await showItemEntry(context, firstItem: saved == null);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (item != null) {
        saved = item;
        step = 2;
      }
    });
  }

  Widget art(String asset, double ratio) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final available = media.size.height - media.padding.vertical;
      final orientation = asset == 'orientation';
      final height = math.min(
        constraints.maxWidth / ratio,
        math.min(
          orientation ? 224.0 : 190.0,
          available * (orientation ? .28 : .22),
        ),
      );
      return SizedBox(
        height: height,
        child: Center(
          child: AspectRatio(
            aspectRatio: ratio,
            child: GettoScreenArtwork(asset),
          ),
        ),
      );
    },
  );
  Text description(String value) => Text(
    value,
    style: GettoTypography.bodyMedium.copyWith(
      color: GettoColors.textSecondary,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final completed = ref.watch(onboardingCompletedProvider);
    if (completed.asData?.value == true && !redirectScheduled) {
      redirectScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }
    final heading = GettoTypography.titleLarge.copyWith(
      fontSize: 26,
      height: 34 / 26,
    );
    final areas = ref.watch(areasStreamProvider);
    final areaName =
        areas.asData?.value
            .where((a) => a.id == saved?.areaId)
            .firstOrNull
            ?.name ??
        'Your home';
    final savedAreaItems = saved == null
        ? null
        : ref.watch(itemsByAreaStreamProvider(saved!.areaId)).asData?.value;
    final content = <Widget>[];
    final actions = <Widget>[];
    if (completed.isLoading || completed.asData?.value == true) {
      content.add(
        Semantics(liveRegion: true, child: const Text('Loading saved setup…')),
      );
    } else if (completed.hasError) {
      content.add(
        const HouseholdMessage(
          "Couldn't read setup progress. Your household data has not been reset.",
          error: true,
        ),
      );
      actions.add(
        HouseholdAction(
          'Retry',
          onPressed: () => ref.invalidate(onboardingCompletedProvider),
        ),
      );
    } else {
      switch (step) {
        case 0:
          content.addAll([
            art('orientation', 372 / 312),
            const SizedBox(height: 24),
            Text('Run your home with less to remember.', style: heading),
            const SizedBox(height: 12),
            description(
              'Keep track of the things that matter. Getto learns as you use it. You do not need to set up everything today.',
            ),
          ]);
          actions.add(
            HouseholdAction(
              'Set up my home',
              onPressed: () => setState(() => step = 1),
            ),
          );
        case 1:
          content.addAll([
            Text('Your home is ready', style: heading),
            const SizedBox(height: 14),
            description(
              'Start with one thing you do not want to forget about.',
            ),
            const SizedBox(height: 12),
            art('ready-home', 374 / 210),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
              decoration: BoxDecoration(
                color: GettoColors.surfaceSubtle,
                border: Border.all(color: const Color(0xFFDDE3DF)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Familiar areas are ready',
                    style: GettoTypography.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  if (areas.isLoading)
                    const Text('Loading home areas…')
                  else if (areas.hasError) ...[
                    const HouseholdMessage(
                      "Couldn't load home areas.",
                      error: true,
                    ),
                    const SizedBox(height: 12),
                    HouseholdAction(
                      'Retry areas',
                      onPressed: () => ref.invalidate(areasStreamProvider),
                    ),
                  ] else ...[
                    Text(
                      areas.asData!.value.map((a) => a.name).join(' · '),
                      style: GettoTypography.bodySmall.copyWith(
                        color: GettoColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ]);
          actions.addAll([
            HouseholdAction('Add first item', onPressed: busy ? null : add),
            const SizedBox(height: 12),
            HouseholdAction(
              busy ? 'Saving setup…' : 'Explore my home',
              secondary: true,
              onPressed: busy ? null : complete,
            ),
          ]);
        case 2:
          content.addAll([
            Text(areaName, style: heading),
            const SizedBox(height: 4),
            Text(
              savedAreaItems == null
                  ? 'Item saved'
                  : '${savedAreaItems.length} ${savedAreaItems.length == 1 ? 'item' : 'items'}',
              style: GettoTypography.bodySmall.copyWith(
                color: GettoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            art('saved-item', 374 / 210),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: GettoColors.surface,
                border: Border.all(color: const Color(0xFFDDE3DF)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(saved!.name, style: GettoTypography.titleSmall),
                  const SizedBox(height: 12),
                  if (saved!.stockStatus == StockStatus.inStock)
                    const GettoStatusBadge(state: GettoBadgeState.inHome)
                  else
                    Text('Not at home', style: GettoTypography.labelSmall),
                  const SizedBox(height: 12),
                  Text(
                    'Saved in your selected home area.',
                    style: GettoTypography.bodySmall.copyWith(
                      color: GettoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 24,
                    color: GettoColors.actionPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Added to your home',
                        style: GettoTypography.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'You can stop here. Your home does not need to be fully catalogued.',
                        style: GettoTypography.bodySmall.copyWith(
                          color: GettoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ]);
          actions.addAll([
            HouseholdAction('Add another item', onPressed: busy ? null : add),
            const SizedBox(height: 12),
            HouseholdAction(
              'Done for now',
              secondary: true,
              onPressed: () => setState(() => step = 3),
            ),
          ]);
        default:
          content.addAll([
            Text('Your home is ready!', style: heading),
            const SizedBox(height: 16),
            Text(
              'Your first item is saved. Getto will grow with your home, one small step at a time.',
              style: GettoTypography.bodySmall.copyWith(
                fontSize: 15,
                height: 23 / 15,
                color: GettoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            art('saved-item', 374 / 210),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF7F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.check,
                          size: 20,
                          color: GettoColors.textBrand,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'First item added successfully',
                          style: GettoTypography.bodyLarge.copyWith(
                            color: GettoColors.textBrand,
                            fontWeight: FontWeight.w600,
                            height: 24 / 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saved in $areaName',
                    style: GettoTypography.bodySmall.copyWith(
                      color: GettoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You can add other items whenever you need them. There is no need to catalog everything now.',
              style: GettoTypography.bodySmall.copyWith(
                color: GettoColors.textSecondary,
                height: 21 / 14,
              ),
            ),
          ]);
          actions.addAll([
            HouseholdAction(
              busy
                  ? 'Saving setup…'
                  : error == null
                  ? 'Go to Home'
                  : 'Retry',
              onPressed: busy ? null : complete,
            ),
            const SizedBox(height: 10),
            HouseholdAction(
              'Add another item',
              secondary: true,
              onPressed: busy ? null : add,
            ),
          ]);
      }
      if (error != null) {
        content.addAll([
          const SizedBox(height: 16),
          HouseholdMessage(error!, error: true),
        ]);
      }
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        if (!busy && step > 0 && step < 2) setState(() => step--);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        key: ValueKey('onboarding-content-$step'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: content,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: actions,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
