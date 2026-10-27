import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/composition/household_providers.dart';
import '../../../design_system/components/getto_home_area_row.dart';
import '../../../design_system/components/getto_item_row.dart';
import '../../../design_system/components/getto_screen_artwork.dart';
import '../../../design_system/motion/getto_motion.dart';
import '../../../design_system/tokens/getto_colors.dart';
import '../../../design_system/typography/getto_typography.dart';
import '../domain/area.dart';
import '../domain/area_repository.dart';
import 'area_management_controller.dart';
import 'household_widgets.dart';

void _back(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

Future<T?> _showAreaTask<T>(
  BuildContext context,
  AreaManagementController commands,
  WidgetBuilder builder,
) => Navigator.of(context, rootNavigator: true).push(
  _AreaTaskRoute<T>(
    commands: commands,
    builder: builder,
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

/// Backdrop/drag are native while idle; route-level guards also protect direct pops.
class _AreaTaskRoute<T> extends ModalBottomSheetRoute<T> {
  _AreaTaskRoute({
    required this.commands,
    required super.builder,
    required super.capturedThemes,
    required super.barrierLabel,
    super.sheetAnimationStyle,
  }) : super(
         isScrollControlled: true,
         useSafeArea: true,
         backgroundColor: GettoColors.surface,
         modalBarrierColor: const Color(0x5214211A),
         shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
         ),
         clipBehavior: Clip.none,
       );
  final AreaManagementController commands;
  bool lastBusy = false;
  @override
  bool get enableDrag => !commands.busy;
  @override
  bool get barrierDismissible => !commands.busy;
  @override
  void install() {
    super.install();
    lastBusy = commands.busy;
    commands.addListener(updateBusy);
  }

  void updateBusy() {
    if (lastBusy != commands.busy) {
      lastBusy = commands.busy;
      changedExternalState();
    }
  }

  @override
  bool didPop(T? result) {
    if (commands.busy) {
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
    dismissible: !commands.busy,
    semanticsLabel: barrierLabel,
    onDismiss: () {
      if (!commands.busy) navigator?.pop();
    },
  );
  @override
  void dispose() {
    commands.removeListener(updateBusy);
    super.dispose();
  }
}

String _itemWord(int count) => count == 1 ? 'item' : 'items';

class _AreaPage extends StatelessWidget {
  const _AreaPage(
    this.title,
    this.children, {
    this.busy = false,
    this.scrollController,
  });
  final String title;
  final List<Widget> children;
  final bool busy;
  final ScrollController? scrollController;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: busy ? null : () => _back(context),
                        icon: const SizedBox.square(
                          dimension: 24,
                          child: GettoScreenArtwork('back'),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: GettoTypography.titleMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
                    children: [
                      for (final child in children) ...[
                        child,
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AreaManagementScreen extends ConsumerStatefulWidget {
  const AreaManagementScreen({super.key});
  @override
  ConsumerState<AreaManagementScreen> createState() =>
      _AreaManagementScreenState();
}

class _AreaManagementScreenState extends ConsumerState<AreaManagementScreen> {
  bool modalOpen = false;
  bool reordering = false;
  final scroll = ScrollController();
  final reorderKey = GlobalKey();
  final reorderFocus = FocusNode(debugLabel: 'Area reorder controls');
  @override
  void dispose() {
    scroll.dispose();
    reorderFocus.dispose();
    super.dispose();
  }

  Future<void> revealReorder() async {
    setState(() => reordering = true);
    if (scroll.hasClients) scroll.jumpTo(0);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final target = reorderKey.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(target, alignment: .25);
      if (mounted) reorderFocus.requestFocus();
    }
  }

  Future<void> task(Area? area, {bool archive = false}) async {
    if (modalOpen) return;
    modalOpen = true;
    final controller = ref.read(areaManagementControllerProvider);
    controller.name = area?.name ?? '';
    controller.error = null;
    controller.conflict = false;
    try {
      await _showAreaTask<void>(
        context,
        controller,
        (_) => _AreaNameOrArchive(
          controller: controller,
          area: area,
          archive: archive,
        ),
      );
    } finally {
      modalOpen = false;
    }
  }

  Future<void> options(Area area) async {
    if (modalOpen) return;
    modalOpen = true;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: GettoMotion.shouldReduce(context)
          ? AnimationStyle.noAnimation
          : null,
      backgroundColor: GettoColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Manage ${area.name}', style: GettoTypography.titleMedium),
                const SizedBox(height: 12),
                for (final action in [
                  'Rename area',
                  'Reorder areas',
                  if (area.isArchived) 'Restore area' else 'Archive area',
                  'Delete area',
                  'Cancel',
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: HouseholdAction(
                      action,
                      secondary: true,
                      minimumHeight: 48,
                      onPressed: () => Navigator.pop(sheet, action),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    modalOpen = false;
    if (!mounted) return;
    final controller = ref.read(areaManagementControllerProvider);
    switch (action) {
      case 'Rename area':
        await task(area);
      case 'Reorder areas':
        await revealReorder();
      case 'Archive area':
        await task(area, archive: true);
      case 'Restore area':
        if (await controller.restore(area.id) && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('${area.name} restored.')));
        } else if (mounted && controller.error != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(controller.error!)));
        }
      case 'Delete area':
        context.push('/home/manage-areas/${area.id}/remove');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(areaManagementControllerProvider);
    final catalog = ref.watch(allAreasStreamProvider);
    final items = ref.watch(allItemsStreamProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = (catalog.asData?.value ?? <Area>[])
            .where((a) => !a.isArchived)
            .toList();
        final archived = (catalog.asData?.value ?? <Area>[])
            .where((a) => a.isArchived)
            .toList();
        Widget row(Area area) => GettoHomeAreaRow(
          key: ValueKey('manage-area-${area.id}'),
          name: area.name,
          activeItems: (items.asData?.value ?? [])
              .where((i) => i.areaId == area.id)
              .length,
          isDefault: area.isSystem,
          onManage: controller.busy ? null : () => options(area),
        );
        return _AreaPage(
          'Manage areas',
          [
            if (controller.error != null)
              HouseholdMessage(controller.error!, error: true),
            if (catalog.isLoading || items.isLoading)
              const HouseholdMessage('Loading saved areas…'),
            if (catalog.hasError || items.hasError) ...[
              const HouseholdMessage(
                "Couldn't load saved areas. Your data has not been reset.",
                error: true,
              ),
              HouseholdAction(
                'Retry areas',
                onPressed: controller.busy
                    ? null
                    : () {
                        ref.invalidate(allAreasStreamProvider);
                        ref.invalidate(allItemsStreamProvider);
                      },
              ),
            ] else if (catalog.hasValue && items.hasValue) ...[
              if (reordering)
                HouseholdMessage(
                  active.isEmpty
                      ? 'No active areas to reorder. Restore or create an area.'
                      : 'Reorder areas using Move up and Move down.',
                ),
              if (active.isEmpty)
                const HouseholdMessage(
                  'No active areas. Add an area or restore one below.',
                ),
              for (var index = 0; index < active.length; index++) ...[
                row(active[index]),
                Focus(
                  key: index == 0 ? reorderKey : null,
                  focusNode: index == 0 ? reorderFocus : null,
                  skipTraversal: true,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: controller.busy || index == 0
                            ? null
                            : () async {
                                final name = active[index].name;
                                if (await controller.move(
                                      catalog.requireValue,
                                      active[index].id,
                                      -1,
                                    ) &&
                                    context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$name moved up.')),
                                  );
                                }
                              },
                        child: Text('Move ${active[index].name} up'),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: controller.busy || index == active.length - 1
                            ? null
                            : () async {
                                final name = active[index].name;
                                if (await controller.move(
                                      catalog.requireValue,
                                      active[index].id,
                                      1,
                                    ) &&
                                    context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$name moved down.'),
                                    ),
                                  );
                                }
                              },
                        child: Text('Move ${active[index].name} down'),
                      ),
                    ],
                  ),
                ),
              ],
              HouseholdAction(
                'Add custom area',
                minimumHeight: 50,
                onPressed: controller.busy ? null : () => task(null),
              ),
              Semantics(
                header: true,
                child: Text(
                  'Archived areas',
                  style: GettoTypography.titleMedium,
                ),
              ),
              const Text(
                'Archived areas keep their items. Active items remain visible in Home All. Restore keeps the saved position.',
              ),
              if (archived.isEmpty) const Text('No archived areas.'),
              for (final area in archived) row(area),
            ],
          ],
          busy: controller.busy,
          scrollController: scroll,
        );
      },
    );
  }
}

class _AreaNameOrArchive extends ConsumerStatefulWidget {
  const _AreaNameOrArchive({
    required this.controller,
    this.area,
    required this.archive,
  });
  final AreaManagementController controller;
  final Area? area;
  final bool archive;
  @override
  ConsumerState<_AreaNameOrArchive> createState() => _AreaNameOrArchiveState();
}

class _AreaNameOrArchiveState extends ConsumerState<_AreaNameOrArchive> {
  late final name = TextEditingController(text: widget.controller.name);
  late Area? expected = widget.area;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final saved = ref.watch(allAreasStreamProvider);
    final latest = saved.asData?.value
        .where((a) => a.id == expected?.id)
        .firstOrNull;
    final unavailable = expected != null && saved.hasValue && latest == null;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => PopScope(
        canPop: !controller.busy,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.archive
                      ? 'Archive ${expected!.name}?'
                      : expected == null
                      ? 'Add custom area'
                      : 'Rename area',
                  style: GettoTypography.titleMedium,
                ),
                const SizedBox(height: 16),
                if (widget.archive)
                  const Text(
                    'Hide this area from filters and item-entry destinations. All items stay saved in place; active items remain visible in Home All.',
                  )
                else
                  TextField(
                    key: const Key('area-name'),
                    controller: name,
                    enabled: !controller.busy && !unavailable,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Area name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => controller.name = value,
                  ),
                if (unavailable)
                  const HouseholdMessage(
                    'This area is unavailable. Your entry is retained.',
                    error: true,
                  ),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  HouseholdMessage(controller.error!, error: true),
                ],
                if (controller.conflict && latest != null) ...[
                  Text('Latest saved name: ${latest.name}'),
                  HouseholdAction(
                    'Review saved name',
                    secondary: true,
                    onPressed: controller.busy
                        ? null
                        : () {
                            setState(() {
                              expected = latest;
                              controller.conflict = false;
                              controller.error = null;
                            });
                          },
                  ),
                ],
                const SizedBox(height: 20),
                HouseholdAction(
                  widget.archive ? 'Archive area' : 'Save area',
                  minimumHeight: 50,
                  onPressed:
                      controller.busy || controller.conflict || unavailable
                      ? null
                      : () async {
                          final success = widget.archive
                              ? await controller.archive(expected!.id)
                              : await controller.saveName(expected: expected);
                          if (context.mounted && success) {
                            Navigator.pop(context);
                          }
                        },
                ),
                const SizedBox(height: 10),
                HouseholdAction(
                  'Cancel',
                  secondary: true,
                  minimumHeight: 48,
                  onPressed: controller.busy
                      ? null
                      : () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AreaRemovalScreen extends ConsumerStatefulWidget {
  const AreaRemovalScreen({required this.areaId, super.key});
  final int areaId;
  @override
  ConsumerState<AreaRemovalScreen> createState() => _AreaRemovalScreenState();
}

class _AreaRemovalScreenState extends ConsumerState<AreaRemovalScreen> {
  bool modalOpen = false;
  @override
  Widget build(BuildContext context) {
    final source = ref.watch(areaStreamProvider(widget.areaId));
    final items = ref.watch(areaItemsIncludingArchivedProvider(widget.areaId));
    final areas = ref.watch(areasStreamProvider);
    final controller = ref.watch(areaManagementControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final area = source.asData?.value;
        final contained = items.asData?.value ?? [];
        final destinations = (areas.asData?.value ?? <Area>[])
            .where((a) => a.id != widget.areaId)
            .toList();
        final loading = source.isLoading || items.isLoading || areas.isLoading;
        final error = source.hasError || items.hasError || areas.hasError;
        return _AreaPage(area?.name ?? 'Area removal', [
          if (controller.error != null)
            HouseholdMessage(controller.error!, error: true),
          if (loading)
            const HouseholdMessage('Loading contained items…')
          else if (error) ...[
            const HouseholdMessage(
              "Couldn't load area removal. Your saved data has not been reset.",
              error: true,
            ),
            HouseholdAction(
              'Retry removal',
              onPressed: controller.busy
                  ? null
                  : () {
                      ref.invalidate(areaStreamProvider(widget.areaId));
                      ref.invalidate(
                        areaItemsIncludingArchivedProvider(widget.areaId),
                      );
                      ref.invalidate(areasStreamProvider);
                    },
            ),
          ] else if (area == null) ...[
            const HouseholdMessage(
              'This area is unavailable. Items remain saved in their current areas.',
            ),
            HouseholdAction(
              'Manage areas',
              onPressed: () => context.go('/home/manage-areas'),
            ),
          ] else ...[
            Text(
              '${contained.length} saved ${_itemWord(contained.length)} in ${area.name}',
              style: GettoTypography.titleMedium,
            ),
            const Text(
              'Keep every item when changing this area. Move all includes archived items. Archive keeps everything in place.',
            ),
            for (final item in contained)
              GettoItemRow(
                title: item.name,
                subtitle: area.name,
                factualStatus: item.isArchived
                    ? 'Archived item'
                    : 'Active item',
              ),
            if (!area.isArchived)
              HouseholdAction(
                'Archive area',
                secondary: true,
                onPressed: controller.busy || modalOpen
                    ? null
                    : () async {
                        modalOpen = true;
                        await showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => Dialog(
                            child: _AreaNameOrArchive(
                              controller: controller,
                              area: area,
                              archive: true,
                            ),
                          ),
                        );
                        if (mounted) setState(() => modalOpen = false);
                      },
              ),
            if (contained.isNotEmpty && destinations.isEmpty)
              const HouseholdMessage(
                'No other active area is available. Add or restore an area before moving these items.',
              ),
            HouseholdAction(
              contained.isEmpty
                  ? 'Review deletion'
                  : 'Review move all and delete',
              minimumHeight: 50,
              onPressed:
                  controller.busy ||
                      modalOpen ||
                      (contained.isNotEmpty && destinations.isEmpty)
                  ? null
                  : () async {
                      modalOpen = true;
                      try {
                        if (!await controller.reviewRemoval(area.id)) {
                          return;
                        }
                        if (!context.mounted) return;
                        final reviewed = controller.confirmation!;
                        final success = await _showAreaTask<bool>(
                          context,
                          controller,
                          (_) => _RemovalConfirmation(
                            controller: controller,
                            initial: reviewed,
                          ),
                        );
                        if (context.mounted && success == true) {
                          context.go('/home/manage-areas');
                        }
                      } finally {
                        if (mounted) setState(() => modalOpen = false);
                      }
                    },
            ),
          ],
        ], busy: controller.busy);
      },
    );
  }
}

class _RemovalConfirmation extends ConsumerStatefulWidget {
  const _RemovalConfirmation({required this.controller, required this.initial});
  final AreaManagementController controller;
  final AreaRemovalSnapshot initial;
  @override
  ConsumerState<_RemovalConfirmation> createState() =>
      _RemovalConfirmationState();
}

class _RemovalConfirmationState extends ConsumerState<_RemovalConfirmation> {
  late int? destination = widget.initial.destination?.id;
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final initial = widget.initial;
    final areas = ref.watch(areasStreamProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.confirmation;
        final preview = snapshot ?? initial;
        final target = preview.destination;
        final destinations = (areas.asData?.value ?? <Area>[])
            .where((area) => area.id != initial.source.id)
            .toList();
        final eligible = destinations.any((area) => area.id == destination);
        final requiresDestination =
            preview.items.isNotEmpty || destination != null;
        final canDelete =
            snapshot != null &&
            !areas.isLoading &&
            !areas.hasError &&
            (requiresDestination
                ? eligible && target?.id == destination
                : snapshot.items.isEmpty);
        final archivedCount = preview.items
            .where((item) => item.isArchived)
            .length;
        return PopScope(
          canPop: !controller.busy,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Delete ${preview.source.name} area?',
                      style: GettoTypography.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      !requiresDestination
                          ? 'Delete this empty area permanently. This cannot be undone.'
                          : target == null
                          ? 'Choose a destination, then confirm removal of ${preview.source.name}. Every saved item is kept.'
                          : 'Move all ${preview.items.length} saved ${_itemWord(preview.items.length)} to ${target.name}, then delete ${preview.source.name}. No items are deleted. Saved information and archived status stay intact.',
                    ),
                    if (requiresDestination) ...[
                      const SizedBox(height: 16),
                      if (areas.isLoading)
                        const HouseholdMessage(
                          'Loading eligible destinations…',
                        ),
                      if (areas.hasError) ...[
                        const HouseholdMessage(
                          "Couldn't load destinations. Your review is retained.",
                          error: true,
                        ),
                        HouseholdAction(
                          'Retry destinations',
                          secondary: true,
                          onPressed: controller.busy
                              ? null
                              : () => ref.invalidate(areasStreamProvider),
                        ),
                      ] else if (destinations.isEmpty)
                        const HouseholdMessage(
                          'No other active area is available. Cancel to add or restore an area.',
                        )
                      else
                        DropdownButtonFormField<int>(
                          key: ValueKey('destination-$destination-$eligible'),
                          initialValue: eligible ? destination : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Destination area',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final area in destinations)
                              DropdownMenuItem(
                                value: area.id,
                                child: Text(area.name),
                              ),
                          ],
                          onChanged: controller.busy
                              ? null
                              : (id) async {
                                  if (id == null) return;
                                  setState(() => destination = id);
                                  await controller.reviewRemoval(
                                    initial.source.id,
                                    targetAreaId: id,
                                  );
                                },
                        ),
                      const SizedBox(height: 12),
                      Text(
                        '$archivedCount archived ${_itemWord(archivedCount)} included.',
                      ),
                    ],
                    if (controller.error != null) ...[
                      const SizedBox(height: 12),
                      HouseholdMessage(controller.error!, error: true),
                    ],
                    if (controller.conflict ||
                        (snapshot == null && !controller.busy)) ...[
                      const SizedBox(height: 12),
                      const HouseholdMessage(
                        'Review changed items and destinations before confirming again.',
                      ),
                      HouseholdAction(
                        'Refresh review',
                        secondary: true,
                        onPressed: controller.busy
                            ? null
                            : () => controller.reviewRemoval(
                                initial.source.id,
                                targetAreaId: destination,
                              ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        padding: const EdgeInsets.all(16),
                        backgroundColor: const Color(0xFFAC2B29),
                      ),
                      onPressed: controller.busy || !canDelete
                          ? null
                          : () async {
                              if (await controller.confirmRemoval() &&
                                  context.mounted) {
                                Navigator.pop(context, true);
                              }
                            },
                      child: Text(
                        !requiresDestination
                            ? 'Delete empty area'
                            : 'Move all and delete area',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    HouseholdAction(
                      'Cancel',
                      secondary: true,
                      minimumHeight: 48,
                      onPressed: controller.busy
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
