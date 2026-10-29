import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/composition/lifecycle_providers.dart';
import '../../../design_system/components/getto_count_stepper.dart';
import '../../../design_system/motion/getto_motion.dart';
import '../../../design_system/tokens/getto_colors.dart';
import '../../../design_system/tokens/getto_radii.dart';
import '../../../design_system/typography/getto_typography.dart';
import '../domain/item_lifecycle.dart';
import '../domain/lifecycle_checkpoint.dart';
import '../domain/lifecycle_cycle.dart';
import 'household_widgets.dart';
import 'lifecycle_controller.dart';
import 'lifecycle_widgets.dart';

Future<LifecycleTaskOutcome?> showLifecycleTask(
  BuildContext context, {
  required ItemLifecycle initial,
  required LifecycleTask task,
  LifecycleCycle? cycle,
  LifecycleCheckpoint? checkpoint,
  String? countDraft,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final controller = LifecycleController(
    repository: container.read(lifecycleRepositoryProvider),
    restockUseCase: container.read(restockItemUseCaseProvider),
    today: container.read(localTodayProvider),
    expected: initial,
    task: task,
    cycle: cycle,
    checkpoint: checkpoint,
    countDraft: countDraft,
  );
  try {
    return await Navigator.of(context, rootNavigator: true).push(
      _LifecycleTaskRoute(
        draft: controller,
        builder: (_) => LifecycleTaskSheet(controller: controller),
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: Navigator.of(context, rootNavigator: true).context,
        ),
        barrierLabel: MaterialLocalizations.of(context)
            .modalBarrierDismissLabel,
        sheetAnimationStyle: GettoMotion.shouldReduce(context)
            ? AnimationStyle.noAnimation
            : AnimationStyle(
                duration: GettoMotion.emphasis,
                reverseDuration: GettoMotion.standard,
              ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

class _LifecycleTaskRoute extends ModalBottomSheetRoute<LifecycleTaskOutcome> {
  _LifecycleTaskRoute({
    required this.draft,
    required super.builder,
    required super.capturedThemes,
    required super.barrierLabel,
    super.sheetAnimationStyle,
  }) : super(
         isScrollControlled: true,
         useSafeArea: true,
         backgroundColor: GettoColors.surface,
         modalBarrierColor: const Color(0x5214211A),
         showDragHandle: false,
         shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(
             top: Radius.circular(GettoRadii.xxl),
           ),
         ),
       );
  final LifecycleController draft;
  bool lastBusy = false;
  @override
  bool get enableDrag => !draft.busy;
  @override
  bool get barrierDismissible => !draft.busy;
  @override
  void install() {
    super.install();
    draft.addListener(changedBusy);
  }

  void changedBusy() {
    if (lastBusy != draft.busy) {
      lastBusy = draft.busy;
      changedExternalState();
    }
  }

  @override
  bool didPop(LifecycleTaskOutcome? result) {
    if (draft.busy) {
      controller?.forward();
      return false;
    }
    return super.didPop(result);
  }

  @override
  void dispose() {
    draft.removeListener(changedBusy);
    super.dispose();
  }
}

class LifecycleTaskSheet extends StatefulWidget {
  const LifecycleTaskSheet({required this.controller, super.key});
  final LifecycleController controller;
  @override
  State<LifecycleTaskSheet> createState() => _LifecycleTaskSheetState();
}

class _LifecycleTaskSheetState extends State<LifecycleTaskSheet> {
  LifecycleController get c => widget.controller;
  late final count = TextEditingController(text: c.countText);
  @override
  void dispose() {
    count.dispose();
    super.dispose();
  }

  void update(VoidCallback change) {
    change();
    c.changed();
  }

  Future<void> save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (await c.submit() && mounted) Navigator.of(context).pop(c.outcome);
  }

  Future<void> chooseFinishDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = c.today();
    final draft = lifecycleDraftDate(c.finishText);
    final initial = draft == null || draft.isAfter(now) ? now : draft;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Actual finish date',
    );
    if (date != null && mounted) {
      update(
        () => c.finishText =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
    }
  }

  String get title {
    if (c.needsResolution) return 'A cycle is already active';
    return switch (c.task) {
      LifecycleTask.start => 'Start using this item',
      LifecycleTask.restock => 'Restock this item',
      LifecycleTask.finish => 'When did it finish?',
      LifecycleTask.correctDates => 'Correct observation dates',
      LifecycleTask.removeCycle => 'Remove wrong observation?',
      LifecycleTask.checkpoint => 'Optional progress note',
      LifecycleTask.correctCount => 'Set current count',
      LifecycleTask.resolveAvailability => 'Resolve the active observation',
    };
  }

  String get saveLabel => c.needsResolution
      ? (c.task == LifecycleTask.restock
            ? 'Resolve and restock'
            : c.resolution == LifecycleResolutionChoice.wrong
            ? 'Remove wrong observation'
            : 'Save finish')
      : switch (c.task) {
          LifecycleTask.start => 'Start observation',
          LifecycleTask.restock => 'Save restock',
          LifecycleTask.finish ||
          LifecycleTask.correctDates => 'Save correction',
          LifecycleTask.removeCycle => 'Remove observation',
          LifecycleTask.checkpoint =>
            c.checkpoint == null ? 'Save progress note' : 'Save corrected note',
          LifecycleTask.correctCount => 'Save count',
          LifecycleTask.resolveAvailability => 'Save resolution',
        };
  Widget dateField(
    String label,
    String value,
    String key,
    ValueChanged<String> changed,
  ) => LifecycleDateField(
    label: label,
    value: value,
    fieldKey: Key(key),
    today: c.today(),
    enabled: !c.busy && !c.unavailable,
    onChanged: (value) => update(() => changed(value)),
  );
  List<Widget> resolutionChoices() => [
    LifecycleChoiceGroup(
      children: [
        LifecycleChoice(
          'Finished now',
          'Close the previous observation using the shown date.',
          artwork: 'restock-finished',
          selected: c.resolution == LifecycleResolutionChoice.finishedNow,
          onTap: c.busy
              ? null
              : () => c.chooseResolution(LifecycleResolutionChoice.finishedNow),
        ),
        LifecycleChoice(
          'Finished earlier',
          'Choose its actual finish date.',
          artwork: 'restock-earlier',
          selected: c.resolution == LifecycleResolutionChoice.finishedEarlier,
          onTap: c.busy
              ? null
              : () => c.chooseResolution(
                  LifecycleResolutionChoice.finishedEarlier,
                ),
        ),
        LifecycleChoice(
          'Previous cycle was wrong',
          'Remove its evidence only with explicit confirmation.',
          artwork: 'wrong-cycle',
          warning: true,
          selected: c.resolution == LifecycleResolutionChoice.wrong,
          onTap: c.busy
              ? null
              : () => c.chooseResolution(LifecycleResolutionChoice.wrong),
        ),
      ],
    ),
    if (c.resolution != null && c.resolution != LifecycleResolutionChoice.wrong)
      dateField(
        'Previous finish date',
        c.finishText,
        'lifecycle-finish-date',
        (v) => c.finishText = v,
      ),
    if (c.task == LifecycleTask.restock && c.resolution != null)
      const HouseholdMessage(
        'The previous observation and replacement will be saved together. Nothing changes until you save.',
      ),
  ];
  List<Widget> reconciliation() => [
    const HouseholdMessage(
      'Review the progress notes affected by these dates. Nothing is removed unless you choose Remove.',
    ),
    for (final note in c.ownedCheckpoints) ...[
      Text(
        '${note.kind == LifecycleCheckpointKind.aboutHalf ? 'About half' : 'Nearly finished'} · ${lifecycleDateLabel(context, note.observedOn)}',
        style: GettoTypography.labelLarge,
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        key: ValueKey('reconcile-remove-${note.id}'),
        value:
            c.reconciliationChoices[note.id] ==
            ObservationReconciliation.remove,
        onChanged: c.busy
            ? null
            : (value) => update(
                () => c.reconciliationChoices[note.id] = value!
                    ? ObservationReconciliation.remove
                    : c.observationDates.containsKey(note.id)
                    ? ObservationReconciliation.changeDate
                    : ObservationReconciliation.keep,
              ),
        title: Text(
          'Remove ${note.kind == LifecycleCheckpointKind.aboutHalf ? 'About half' : 'Nearly finished'} note',
        ),
      ),
      if (c.reconciliationChoices[note.id] != ObservationReconciliation.remove)
        dateField(
          'Revised progress-note date',
          c.observationDates[note.id] ?? note.observedOn.toString(),
          'reconcile-date-${note.id}',
          (v) {
            c.observationDates[note.id] = v;
            c.reconciliationChoices[note.id] =
                ObservationReconciliation.changeDate;
          },
        ),
    ],
  ];
  List<Widget> fields() {
    final selectedResolution = !c.needsResolution || c.resolution != null;
    final finishDraft = lifecycleDraftDate(c.finishText);
    final startDraft = c.task == LifecycleTask.correctDates
        ? lifecycleDraftDate(c.startText)
        : c.cycle?.startedOn;
    return [
      Text(
        c.expected.item.name,
        textAlign: TextAlign.center,
        style: GettoTypography.labelLarge,
      ),
      if (c.cycle != null && c.task != LifecycleTask.start)
        Text(
          'Selected observation: started ${lifecycleDateLabel(context, c.cycle!.startedOn)}${c.cycle!.finishedOn == null ? ' · still active' : ' · finished ${lifecycleDateLabel(context, c.cycle!.finishedOn!)}'}',
          textAlign: TextAlign.center,
          style: GettoTypography.bodySmall,
        ),
      if (c.needsResolution) ...resolutionChoices(),
      if (selectedResolution) ...[
        if (c.task == LifecycleTask.start ||
            c.task == LifecycleTask.restock ||
            c.task == LifecycleTask.correctDates)
          dateField(
            c.task == LifecycleTask.restock
                ? 'Replacement start date'
                : 'Start date',
            c.startText,
            'lifecycle-start-date',
            (v) => c.startText = v,
          ),
        if (c.task == LifecycleTask.start)
          const HouseholdMessage(
            'Start observing the stock already in use. An unknown count stays unknown.',
          ),
        if (c.needsTotal && !c.resolvingCount) ...[
          const Text(
            'Enter the total usable stock at home, not the amount added. Unknown is different from zero.',
          ),
          Semantics(
            label: 'Current usable total',
            child: TextField(
              key: const Key('lifecycle-count'),
              controller: count,
              enabled: !c.busy && !c.unavailable,
              keyboardType: TextInputType.number,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (v) => update(() => c.countText = v),
              decoration: const InputDecoration(
                labelText: 'Current usable total',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (c.draftTotal != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GettoCountStepper(
                value: c.draftTotal!,
                maximum: 9223372036854775807,
                onChanged: c.busy
                    ? null
                    : (value) => update(() {
                        c.countText = '$value';
                        count.text = '$value';
                      }),
              ),
            ),
        ],
        if (c.task == LifecycleTask.finish ||
            (c.task == LifecycleTask.correctDates &&
                c.cycle?.finishedOn != null)) ...[
          if (c.task == LifecycleTask.finish)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: c.busy
                      ? null
                      : () => update(() => c.finishText = c.today().toString()),
                  child: const Text('Finished now'),
                ),
                OutlinedButton(
                  onPressed: c.busy
                      ? null
                      : () {
                          chooseFinishDate();
                        },
                  child: const Text('Finished earlier'),
                ),
              ],
            ),
          dateField(
            'Finish date',
            c.finishText,
            'lifecycle-finish-date',
            (v) => c.finishText = v,
          ),
          if (finishDraft != null &&
              startDraft != null &&
              !finishDraft.isBefore(startDraft))
            Text(
              'Cycle duration: ${lifecycleDuration(finishDraft.differenceInDays(startDraft))}',
              style: GettoTypography.titleMedium,
            ),
          Text(
            c.task == LifecycleTask.finish
                ? 'This records an actual finish and marks the item out of stock.'
                : 'This corrects historical dates only. Current stock stays unchanged.',
          ),
        ],
        if (c.task == LifecycleTask.checkpoint) ...[
          const Text(
            'Optional evidence, never a required stage. Skip without saving a note.',
          ),
          LifecycleChoiceGroup(
            children: [
              LifecycleChoice(
                'About half',
                c.ownedCheckpoints.any(
                      (p) => p.kind == LifecycleCheckpointKind.aboutHalf,
                    )
                    ? 'Correct the existing observation.'
                    : 'Record a coarse midpoint observation.',
                artwork: 'about-half',
                selected: c.kind == LifecycleCheckpointKind.aboutHalf,
                onTap: c.busy
                    ? null
                    : () => c.chooseKind(LifecycleCheckpointKind.aboutHalf),
              ),
              LifecycleChoice(
                'Nearly finished',
                c.ownedCheckpoints.any(
                      (p) => p.kind == LifecycleCheckpointKind.nearlyFinished,
                    )
                    ? 'Correct the existing observation.'
                    : 'Record a late-cycle observation.',
                artwork: 'nearly-finished',
                selected: c.kind == LifecycleCheckpointKind.nearlyFinished,
                onTap: c.busy
                    ? null
                    : () =>
                          c.chooseKind(LifecycleCheckpointKind.nearlyFinished),
              ),
            ],
          ),
          if (c.kind != null)
            dateField(
              'Progress-note date',
              c.observedText,
              'lifecycle-observed-date',
              (v) => c.observedText = v,
            ),
        ],
        if (c.destructive) ...[
          HouseholdMessage(
            'Remove the observation for ${c.expected.item.name} started ${lifecycleDateLabel(context, c.cycle!.startedOn)} and its progress notes. This cannot be undone. The item remains saved.',
            error: true,
          ),
          CheckboxListTile(
            key: const Key('confirm-evidence-removal'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: c.destructiveConfirmed,
            onChanged: c.busy
                ? null
                : (value) => update(() => c.destructiveConfirmed = value!),
            title: const Text(
              'I confirm removal of this observation and its progress notes',
            ),
          ),
        ],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => PopScope(
      canPop: !c.busy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            child: SingleChildScrollView(
              key: const Key('lifecycle-sheet-scroll'),
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD2CE),
                        borderRadius: BorderRadius.circular(GettoRadii.pill),
                      ),
                    ),
                  ),
                  Semantics(
                    header: true,
                    namesRoute: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GettoTypography.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.needsResolution
                        ? 'Resolve the current observation before changing current stock.'
                        : 'Record what is true. You do not need to rebuild missed history.',
                    textAlign: TextAlign.center,
                    style: GettoTypography.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  for (final field in fields()) ...[
                    field,
                    const SizedBox(height: 16),
                  ],
                  if (c.information != null) ...[
                    HouseholdMessage(c.information!),
                    const SizedBox(height: 12),
                  ],
                  if (c.failure != null) ...[
                    if (c.storageFailure)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: GettoColors.errorSurface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const LifecycleArtwork('error'),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Not Saved',
                                      style: GettoTypography.labelLarge
                                          .copyWith(color: GettoColors.error),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                c.errorMessage,
                                style: GettoTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      HouseholdMessage(c.errorMessage, error: true),
                    const SizedBox(height: 12),
                    if (c.needsReconciliation) ...reconciliation(),
                    if (c.conflict)
                      HouseholdAction(
                        c.busy ? 'Reviewing…' : 'Review current state',
                        secondary: true,
                        onPressed: c.busy ? null : c.reviewCurrent,
                      ),
                    if (c.activeConflict &&
                        c.task == LifecycleTask.correctCount)
                      HouseholdAction(
                        'Resolve active observation',
                        secondary: true,
                        onPressed: c.busy ? null : c.resolveCount,
                      ),
                  ],
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: c.busy,
                    child: HouseholdAction(
                      c.busy
                          ? 'Saving…'
                          : c.storageFailure
                          ? 'Retry'
                          : saveLabel,
                      destructive: c.destructive,
                      onPressed:
                          !c.canSubmit ||
                              (c.needsResolution && c.resolution == null)
                          ? null
                          : save,
                    ),
                  ),
                  if (c.storageFailure) ...[
                    const SizedBox(height: 10),
                    HouseholdAction(
                      'Keep editing',
                      secondary: true,
                      onPressed: c.busy ? null : c.keepEditing,
                    ),
                  ],
                  const SizedBox(height: 10),
                  HouseholdAction(
                    c.task == LifecycleTask.checkpoint ? 'Skip' : 'Cancel',
                    secondary: true,
                    onPressed: c.busy
                        ? null
                        : () => Navigator.of(context).pop(),
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
