import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/composition/household_providers.dart';
import '../../../design_system/components/getto_screen_artwork.dart';
import '../../../design_system/motion/getto_motion.dart';
import '../../../design_system/tokens/getto_colors.dart';
import '../../../design_system/typography/getto_typography.dart';
import '../domain/area.dart';
import '../domain/behavior_profile.dart';
import '../domain/item.dart';
import '../domain/stock_status.dart';
import 'household_widgets.dart';
import 'item_entry_controller.dart';

Future<Item?> showItemEntry(BuildContext context, {bool firstItem = false}) {
  final draft = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(itemEntryControllerProvider);
  return Navigator.of(context, rootNavigator: true).push(
    _ItemEntryRoute(
      draft: draft,
      builder: (_) => ItemEntrySheet(firstItem: firstItem),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: true).context,
      ),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      sheetAnimationStyle: GettoMotion.shouldReduce(context)
          ? AnimationStyle.noAnimation
          : null,
    ),
  );
}

/// Keep the Material sheet's native gestures, locking only an in-flight write.
class _ItemEntryRoute extends ModalBottomSheetRoute<Item> {
  _ItemEntryRoute({
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
           borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
         ),
         // Padded form content stays inside the rounded Material surface.
         // Avoid a redundant full-sheet path clip during native transitions.
         clipBehavior: Clip.none,
       );
  final ItemEntryController draft;
  bool lastBusy = false;
  @override
  bool get enableDrag => !draft.busy;
  @override
  bool get barrierDismissible => !draft.busy;
  @override
  void install() {
    super.install();
    lastBusy = draft.busy;
    draft.addListener(updateBusy);
  }

  void updateBusy() {
    if (lastBusy != draft.busy) {
      lastBusy = draft.busy;
      changedExternalState();
    }
  }

  @override
  bool didPop(Item? result) {
    if (draft.busy) {
      controller?.forward();
      return false;
    }
    return super.didPop(result);
  }

  @override
  Widget buildModalBarrier() => AnimatedModalBarrier(
    color: animation!.drive(
      ColorTween(
        begin: const Color(0x0014211A),
        end: barrierColor,
      ).chain(CurveTween(curve: barrierCurve)),
    ),
    dismissible: !draft.busy,
    semanticsLabel: barrierLabel,
    // Scrim dismisses the whole idle sheet; Android Back still follows form steps.
    onDismiss: () {
      if (!draft.busy) navigator?.pop();
    },
  );
  @override
  void dispose() {
    draft.removeListener(updateBusy);
    super.dispose();
  }
}

class ItemEntrySheet extends ConsumerStatefulWidget {
  const ItemEntrySheet({this.firstItem = false, super.key});
  final bool firstItem;
  @override
  ConsumerState<ItemEntrySheet> createState() => _ItemEntrySheetState();
}

class _ItemEntrySheetState extends ConsumerState<ItemEntrySheet> {
  late final ItemEntryController draft;
  late final TextEditingController name;
  final areaName = TextEditingController();
  bool customArea = false;
  @override
  void initState() {
    super.initState();
    draft = ref.read(itemEntryControllerProvider);
    name = TextEditingController(text: draft.name);
  }

  @override
  void dispose() {
    name.dispose();
    areaName.dispose();
    super.dispose();
  }

  void back() {
    if (draft.busy) return;
    if (customArea) {
      setState(() => customArea = false);
      draft.keepEditing();
    } else if (draft.step == 1) {
      draft.change(step: 0);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final item = await draft.save();
    if (mounted && item != null) Navigator.of(context).pop(item);
  }

  InputDecoration field(String label, {String? hint, String? error}) =>
      InputDecoration(
        hintText: hint,
        errorText: error,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintStyle: GettoTypography.bodyMedium,
        counterText: '',
      );

  Widget fieldFrame(String label, Widget input) => Semantics(
    label: label,
    child: Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GettoColors.surface,
        border: Border.all(color: const Color(0xFFDDE3DF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              label,
              style: GettoTypography.labelSmall.copyWith(
                color: GettoColors.textSecondary,
                letterSpacing: .2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          input,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(areasStreamProvider);
    return AnimatedBuilder(
      animation: draft,
      builder: (context, _) {
        final active = areas.asData?.value ?? const <Area>[];
        final eligible = active.any((a) => a.id == draft.area?.id);
        final details = !customArea && draft.step == 1;
        final view = MediaQuery.of(context);
        final enlarged = view.textScaler.scale(16) > 22;
        final available = math.max(
          100.0,
          view.size.height * .94 -
              view.viewInsets.bottom -
              view.padding.top -
              view.padding.bottom,
        );
        final height = math.min(
          available,
          enlarged
              ? available
              : details
              ? 666.0
              : customArea
              ? 360.0
              : 500.0,
        );
        final body = <Widget>[
          if (!details) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                customArea
                    ? 'Add area'
                    : widget.firstItem
                    ? 'First item'
                    : 'Add household item',
                style: GettoTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              customArea
                  ? 'Choose a place you recognize at home.'
                  : widget.firstItem
                  ? 'Name it and choose a home area.'
                  : 'Next: item type and availability.',
              style: GettoTypography.bodyMedium.copyWith(
                color: GettoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
          ] else ...[
            Text('Finish adding this item', style: GettoTypography.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Choose what it is and whether it is home.',
              style: GettoTypography.bodySmall.copyWith(
                color: GettoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (customArea) ...[
            fieldFrame(
              'Area name',
              TextField(
                key: const Key('custom-area-name'),
                controller: areaName,
                enabled: !draft.busy,
                maxLength: 50,
                style: GettoTypography.bodyMedium,
                decoration: field('Area name', hint: 'Enter area name'),
                onChanged: (_) => draft.keepEditing(),
              ),
            ),
          ] else if (!details) ...[
            fieldFrame(
              'Item name',
              TextField(
                key: const Key('item-name'),
                controller: name,
                maxLength: 100,
                enabled: !draft.busy,
                style: GettoTypography.bodyMedium,
                decoration: field(
                  'Item name',
                  hint: 'Enter item name',
                  error: name.text.isNotEmpty && !draft.validName
                      ? 'Enter a name from 1 to 100 characters.'
                      : null,
                ),
                onChanged: (text) => draft.change(name: text),
              ),
            ),
            const SizedBox(height: 10),
            if (areas.isLoading)
              const HouseholdMessage('Loading home areas…')
            else if (areas.hasError) ...[
              const HouseholdMessage("Couldn't load home areas.", error: true),
              const SizedBox(height: 12),
              HouseholdAction(
                'Retry areas',
                onPressed: () => ref.invalidate(areasStreamProvider),
              ),
            ] else ...[
              fieldFrame(
                'Home area',
                DropdownButtonFormField<int>(
                  icon: const SizedBox(
                    width: 20,
                    height: 20,
                    child: GettoScreenArtwork('dropdown'),
                  ),
                  key: ValueKey(
                    'area-${eligible ? draft.area?.id : null}-${active.length}',
                  ),
                  initialValue: eligible ? draft.area?.id : null,
                  selectedItemBuilder: (_) => [
                    for (final area in active)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(area.name),
                      ),
                    const Text('Custom · Create a home area'),
                  ],
                  isExpanded: true,
                  itemHeight: null,
                  menuMaxHeight: math.min(360, view.size.height * .45),
                  style: GettoTypography.bodyMedium,
                  decoration: field('Home area'),
                  hint: Text(
                    'Select home area',
                    style: GettoTypography.bodyMedium,
                  ),
                  items: [
                    for (final area in active)
                      DropdownMenuItem(
                        value: area.id,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(area.name),
                        ),
                      ),
                    const DropdownMenuItem(
                      value: -1,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Custom · Create a home area'),
                      ),
                    ),
                  ],
                  onChanged: draft.busy
                      ? null
                      : (id) {
                          if (id == -1) {
                            draft.keepEditing();
                            setState(() => customArea = true);
                          } else if (id != null) {
                            draft.change(
                              area: active.firstWhere((a) => a.id == id),
                            );
                          }
                        },
                ),
              ),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Create a custom area to get started.'),
                ),
            ],
            if (draft.areaWasCreated)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: HouseholdMessage(
                  draft.area?.id == draft.createdArea?.id
                      ? 'Your new area is saved and selected.'
                      : 'Your new area is saved.',
                ),
              ),
          ] else ...[
            Text('How do you use it?', style: GettoTypography.labelLarge),
            const SizedBox(height: 12),
            for (final (profile, label, detail) in const [
              (
                BehaviorProfile.replenishable,
                'Use it up',
                'Soap, toothpaste, daily essentials',
              ),
              (
                BehaviorProfile.countableReplenishable,
                'Count what remains',
                'Eggs, rolls or other counted supplies',
              ),
              (
                BehaviorProfile.durable,
                'Keep it around',
                'Lamp, charger or lasting belongings',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Choice(
                  label: label,
                  detail: detail,
                  selected: draft.profile == profile,
                  onTap: draft.busy
                      ? null
                      : () => draft.change(profile: profile),
                ),
              ),
            const SizedBox(height: 4),
            Text('Is it at home now?', style: GettoTypography.labelLarge),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 100),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final (index, status, label) in const [
                      (0, StockStatus.inStock, 'Yes, at home'),
                      (1, StockStatus.outOfStock, 'Not at home'),
                    ]) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _Choice(
                          label: label,
                          selected: draft.presence == status,
                          presence: true,
                          onTap: draft.busy
                              ? null
                              : () => draft.change(presence: status),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Text(
              'No count, expiry or usage history is required.',
              style: GettoTypography.bodySmall.copyWith(
                fontSize: 12,
                height: 18 / 12,
                color: GettoColors.textSecondary,
              ),
            ),
          ],
          if (draft.error != null) ...[
            const SizedBox(height: 12),
            HouseholdMessage(draft.error!, error: true),
            const SizedBox(height: 12),
            HouseholdAction(
              'Keep editing',
              secondary: true,
              minimumHeight: 50,
              onPressed: draft.busy ? null : draft.keepEditing,
            ),
          ],
        ];
        return PopScope(
          canPop: !draft.busy && !customArea && draft.step == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) back();
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: view.viewInsets.bottom),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    details ? 12 : 16,
                    24,
                    details ? 24 : 26,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ExcludeSemantics(
                        child: SizedBox(
                          key: const Key('item-sheet-handle'),
                          height: details ? 18 : 20,
                          child: Center(
                            child: Container(
                              width: details ? 36 : 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD2CE),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: details ? 12 : 18),
                      Expanded(
                        child: SingleChildScrollView(
                          key: const ValueKey('item-form-scroll'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: body,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (customArea) ...[
                        HouseholdAction(
                          draft.busy ? 'Creating area…' : 'Create area',
                          minimumHeight: 50,
                          onPressed: draft.busy
                              ? null
                              : () async {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  final created = await draft.createArea(
                                    areaName.text,
                                  );
                                  if (mounted && created != null) {
                                    setState(() => customArea = false);
                                  }
                                },
                        ),
                        const SizedBox(height: 10),
                        HouseholdAction(
                          'Cancel',
                          secondary: true,
                          minimumHeight: 50,
                          onPressed: draft.busy ? null : back,
                        ),
                      ] else if (!details)
                        HouseholdAction(
                          'Continue',
                          // A different step's action must not inherit this ink/focus state.
                          key: const ValueKey('continue-item'),
                          onPressed:
                              draft.hasIdentity && eligible && !draft.busy
                              ? () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  draft.change(step: 1);
                                }
                              : null,
                        )
                      else ...[
                        HouseholdAction(
                          draft.busy
                              ? 'Saving…'
                              : draft.error == null
                              ? 'Add item'
                              : 'Retry',
                          key: const ValueKey('save-item'),
                          minimumHeight: 50,
                          onPressed: draft.hasChoices && !draft.busy
                              ? save
                              : null,
                        ),
                        const SizedBox(height: 12),
                        HouseholdAction(
                          'Back',
                          secondary: true,
                          minimumHeight: 50,
                          onPressed: draft.busy ? null : back,
                        ),
                      ],
                      if (draft.busy)
                        Semantics(
                          liveRegion: true,
                          child: const Text('Saving locally. Please wait.'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
    this.presence = false,
  });
  final String label;
  final String? detail;
  final bool selected;
  final bool presence;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final indicator = ExcludeSemantics(
      child: SizedBox.square(
        dimension: presence ? 18 : 20,
        child: selected
            ? Icon(
                Icons.radio_button_checked,
                size: presence ? 18 : 20,
                color: GettoColors.actionPrimary,
              )
            : GettoScreenArtwork(presence ? 'presence-none' : 'choice-none'),
      ),
    );
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(double.infinity, presence ? 52 : 62),
          alignment: Alignment.centerLeft,
          side: BorderSide(
            color: selected
                ? GettoColors.actionPrimary
                : const Color(0xFFDCE4DF),
          ),
          backgroundColor: selected
              ? const Color(0xFFF2F8F5)
              : GettoColors.surface,
          padding: EdgeInsets.symmetric(
            horizontal: presence ? 12 : 14,
            vertical: 9,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            if (presence) ...[indicator, const SizedBox(width: 8)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: presence
                        ? GettoTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 20 / 13,
                          )
                        : GettoTypography.labelLarge,
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      style: GettoTypography.bodySmall.copyWith(
                        fontSize: 12,
                        height: 17 / 12,
                        color: GettoColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!presence) ...[const SizedBox(width: 12), indicator],
          ],
        ),
      ),
    );
  }
}
