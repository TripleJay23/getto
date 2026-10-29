import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/composition/lifecycle_providers.dart';
import '../../../design_system/components/getto_status_badge.dart';
import '../../../design_system/motion/getto_motion.dart';
import '../../../design_system/tokens/getto_colors.dart';
import '../../../design_system/tokens/getto_radii.dart';
import '../../../design_system/typography/getto_typography.dart';
import '../domain/behavior_profile.dart';
import '../domain/item_lifecycle.dart';
import '../domain/lifecycle_checkpoint.dart';
import '../domain/lifecycle_cycle.dart';
import '../domain/stock_status.dart';
import 'household_widgets.dart';
import 'lifecycle_controller.dart';
import 'lifecycle_task_sheet.dart';
import 'lifecycle_widgets.dart';

enum _RealityChoice { stillUsing, finish, earlier, startDate, restock }

class LifecycleDetail extends ConsumerStatefulWidget {
  const LifecycleDetail({required this.aggregate, super.key});
  final ItemLifecycle aggregate;
  @override
  ConsumerState<LifecycleDetail> createState() => _LifecycleDetailState();
}

class _LifecycleDetailState extends ConsumerState<LifecycleDetail> {
  bool modalOpen = false;
  String? acknowledgement;
  int? beforeId;
  ItemLifecycle get aggregate => widget.aggregate;
  Future<void> task(
    LifecycleTask task, {
    LifecycleCycle? cycle,
    LifecycleCheckpoint? checkpoint,
  }) async {
    if (modalOpen) return;
    modalOpen = true;
    try {
      final result = await showLifecycleTask(
        context,
        initial: aggregate,
        task: task,
        cycle: cycle,
        checkpoint: checkpoint,
      );
      if (mounted && result != null) {
        setState(() => acknowledgement = result.message);
      }
    } finally {
      modalOpen = false;
    }
  }

  Future<void> correct() async {
    if (modalOpen) return;
    modalOpen = true;
    final selected = await showModalBottomSheet<_RealityChoice>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GettoColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GettoRadii.xxl),
        ),
      ),
      sheetAnimationStyle: GettoMotion.shouldReduce(context)
          ? AnimationStyle.noAnimation
          : AnimationStyle(
              duration: GettoMotion.emphasis,
              reverseDuration: GettoMotion.standard,
            ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  namesRoute: true,
                  child: Text(
                    'What is true right now?',
                    textAlign: TextAlign.center,
                    style: GettoTypography.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the quickest correction. You do not need to rebuild missed history.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                LifecycleChoiceGroup(
                  children: [
                    if (aggregate.activeCycle != null) ...[
                      LifecycleChoice(
                        'Still in use',
                        'Keep the current observation active.',
                        artwork: 'still-in-use',
                        next: true,
                        onTap: () =>
                            Navigator.of(sheetContext)
                                .pop(_RealityChoice.stillUsing),
                      ),
                      LifecycleChoice(
                        'Finished now',
                        'Close the observation using today.',
                        artwork: 'finished-now',
                        next: true,
                        onTap: () =>
                            Navigator.of(sheetContext)
                                .pop(_RealityChoice.finish),
                      ),
                      LifecycleChoice(
                        'Finished earlier',
                        'Choose the actual finish date.',
                        artwork: 'finished-earlier',
                        next: true,
                        onTap: () =>
                            Navigator.of(sheetContext)
                                .pop(_RealityChoice.earlier),
                      ),
                      LifecycleChoice(
                        'Correct start date',
                        'Repair when this observation began.',
                        artwork: 'correct-start',
                        next: true,
                        onTap: () =>
                            Navigator.of(sheetContext)
                                .pop(_RealityChoice.startDate),
                      ),
                    ],
                    LifecycleChoice(
                      'Restock',
                      'Start using replacement stock explicitly.',
                      artwork: 'restock-earlier',
                      next: true,
                      onTap: () =>
                          Navigator.of(sheetContext)
                              .pop(_RealityChoice.restock),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                HouseholdAction(
                  'Cancel',
                  secondary: true,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    modalOpen = false;
    if (!mounted || selected == null) return;
    if (selected == _RealityChoice.stillUsing) {
      setState(() => acknowledgement = 'Still in use · no change needed');
      return;
    }
    await task(switch (selected) {
      _RealityChoice.finish || _RealityChoice.earlier => LifecycleTask.finish,
      _RealityChoice.startDate => LifecycleTask.correctDates,
      _RealityChoice.restock => LifecycleTask.restock,
      _RealityChoice.stillUsing => LifecycleTask.finish,
    });
  }

  Widget history() {
    final fingerprint = aggregate.completedCycles
        .map((c) => '${c.id}:${c.startedOn}:${c.finishedOn}')
        .join('|');
    final key = (
      itemId: aggregate.item.id,
      evidenceKey: fingerprint,
      beforeId: beforeId,
    );
    final history = ref.watch(lifecycleHistoryProvider(key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Recent observations', style: GettoTypography.titleSmall),
        ),
        const SizedBox(height: 8),
        history.when(
          loading: () => const HouseholdMessage('Loading saved observations…'),
          error: (_, _) => historyError(key),
          data: (result) {
            if (result.isFailure) return historyError(key);
            final page = result.valueOrNull!;
            final visible = [
              for (final row in page)
                ...aggregate.completedCycles.where((c) => c.id == row.id),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (visible.isEmpty)
                  HouseholdMessage(
                    beforeId == null
                        ? 'No completed cycles yet. You only need to update this item when reality changes.'
                        : 'No older observations on this page.',
                  ),
                for (final cycle in visible)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GettoColors.surface,
                      border: Border.all(color: const Color(0xFFDDE3DF)),
                      borderRadius: BorderRadius.circular(GettoRadii.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${lifecycleDateLabel(context, cycle.startedOn)} → ${lifecycleDateLabel(context, cycle.finishedOn!)}',
                          style: GettoTypography.labelLarge,
                        ),
                        Text(
                          'Actual duration: ${lifecycleDuration(cycle.durationDays!)}',
                          style: GettoTypography.bodySmall,
                        ),
                        for (final note in aggregate.checkpoints.where(
                          (p) => p.cycleId == cycle.id,
                        )) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${note.kind == LifecycleCheckpointKind.aboutHalf ? 'About half' : 'Nearly finished'} · ${lifecycleDateLabel(context, note.observedOn)}',
                          ),
                          if (!aggregate.item.isArchived)
                            TextButton(
                              onPressed: () => task(
                                LifecycleTask.checkpoint,
                                cycle: cycle,
                                checkpoint: note,
                              ),
                              child: Text(
                                'Correct ${note.kind == LifecycleCheckpointKind.aboutHalf ? 'About half' : 'Nearly finished'} note',
                              ),
                            ),
                        ],
                        if (!aggregate.item.isArchived) ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () =>
                                task(LifecycleTask.correctDates, cycle: cycle),
                            child: const Text('Correct dates'),
                          ),
                          TextButton(
                            onPressed: () =>
                                task(LifecycleTask.removeCycle, cycle: cycle),
                            child: const Text('Remove observation'),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (page.length == 5)
                  HouseholdAction(
                    'Older observations',
                    secondary: true,
                    onPressed: () => setState(() => beforeId = page.last.id),
                  ),
                if (beforeId != null)
                  TextButton(
                    onPressed: () => setState(() => beforeId = null),
                    child: const Text('Back to recent observations'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget historyError(LifecycleHistoryKey key) => Column(
    children: [
      const HouseholdMessage(
        "Couldn't load recent observations. Saved evidence has not been reset.",
        error: true,
      ),
      HouseholdAction(
        'Retry history',
        secondary: true,
        onPressed: () => ref.invalidate(lifecycleHistoryProvider(key)),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    if (aggregate.item.behaviorProfile == BehaviorProfile.durable) {
      return const SizedBox.shrink();
    }
    final active = aggregate.activeCycle;
    final readOnly = aggregate.item.isArchived;
    final today = ref.watch(localTodayProvider)();
    final elapsed = active == null
        ? null
        : today.differenceInDays(active.startedOn);
    final primary = active != null
        ? 'Finish'
        : aggregate.item.stockStatus == StockStatus.outOfStock ||
              aggregate.completedCycles.isNotEmpty
        ? 'Restock'
        : 'Start';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6F1),
            borderRadius: BorderRadius.circular(GettoRadii.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Current observation',
                    style: GettoTypography.labelSmall,
                  ),
                  if (active != null)
                    const GettoStatusBadge(state: GettoBadgeState.inUse)
                  else
                    Text(
                      aggregate.completedCycles.isEmpty
                          ? 'No recorded observation'
                          : 'Observation completed',
                      style: GettoTypography.labelMedium,
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: GettoColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const LifecycleArtwork('cycle-calendar'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      active == null
                          ? 'Start when stock enters use'
                          : elapsed == 0
                          ? 'Started today'
                          : elapsed != null && elapsed > 0
                          ? 'Started ${lifecycleDuration(elapsed)} ago'
                          : 'Started ${lifecycleDateLabel(context, active.startedOn)}',
                      style: GettoTypography.titleSmall,
                    ),
                  ),
                ],
              ),
              if (active != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Start date: ${lifecycleDateLabel(context, active.startedOn)}',
                  style: GettoTypography.bodySmall,
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(height: 1, color: Color(0xFFD0E0D6)),
              ),
              Text(
                'No estimate is available. This history records your actual observations.',
                style: GettoTypography.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!readOnly) ...[
          HouseholdAction(
            primary,
            onPressed: () => task(
              active != null
                  ? LifecycleTask.finish
                  : primary == 'Start'
                  ? LifecycleTask.start
                  : LifecycleTask.restock,
            ),
          ),
          const SizedBox(height: 10),
          HouseholdAction('Correct', secondary: true, onPressed: correct),
          if (active != null) ...[
            const SizedBox(height: 10),
            HouseholdAction(
              'Add progress note',
              secondary: true,
              onPressed: () => task(LifecycleTask.checkpoint),
            ),
            for (final note in aggregate.checkpoints.where(
              (p) => p.cycleId == active.id,
            ))
              TextButton(
                onPressed: () => task(
                  LifecycleTask.checkpoint,
                  cycle: active,
                  checkpoint: note,
                ),
                child: Text(
                  '${note.kind == LifecycleCheckpointKind.aboutHalf ? 'About half' : 'Nearly finished'} · ${lifecycleDateLabel(context, note.observedOn)} · Correct',
                ),
              ),
          ],
        ],
        if (acknowledgement != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  const LifecycleArtwork('success'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      acknowledgement!,
                      style: GettoTypography.labelLarge.copyWith(
                        color: GettoColors.textBrand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        history(),
      ],
    );
  }
}
