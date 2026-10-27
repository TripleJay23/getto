import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/composition/household_providers.dart';
import '../../../design_system/components/getto_count_stepper.dart';
import '../../../design_system/components/getto_item_row.dart';
import '../../../design_system/components/getto_screen_artwork.dart';
import '../../../design_system/components/getto_status_badge.dart';
import '../../../design_system/tokens/getto_colors.dart';
import '../../../design_system/typography/getto_typography.dart';
import '../domain/area.dart';
import '../domain/behavior_profile.dart';
import '../domain/item.dart';
import '../domain/stock_status.dart';
import 'household_widgets.dart';
import 'item_management_controller.dart';

void _back(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

InputDecoration _field(String label, {String? helper}) => InputDecoration(
  // The wrapping external label owns the accessible field name.
  helperText: helper,
  helperMaxLines: 4,
  filled: true,
  fillColor: GettoColors.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFDDE3DF)),
  ),
);

Widget _label(String label, Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    ExcludeSemantics(child: Text(label, style: GettoTypography.labelSmall)),
    const SizedBox(height: 6),
    Semantics(label: label, child: child),
  ],
);

/// Growing child app bar and scrollable body, within the existing Home branch.
class _ItemPage extends StatelessWidget {
  const _ItemPage(this.title, this.children, {this.busy = false, this.more});
  final String title;
  final List<Widget> children;
  final bool busy;
  final Widget? more;

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
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
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
                            style:
                                MediaQuery.textScalerOf(context).scale(24) > 36
                                ? GettoTypography.titleSmall
                                : GettoTypography.titleLarge,
                          ),
                        ),
                      ),
                      ?more,
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
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

class _ItemRecord extends ConsumerWidget {
  const _ItemRecord(this.id, {required this.builder});
  final int id;
  final Widget Function(Item) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(itemStreamProvider(id))
      .when(
        loading: () =>
            const _ItemPage('Item', [HouseholdMessage('Loading saved item…')]),
        error: (_, _) => _ItemPage('Item', [
          const HouseholdMessage(
            "Couldn't load this item. Your saved data has not been reset.",
            error: true,
          ),
          HouseholdAction(
            'Retry',
            onPressed: () => ref.invalidate(itemStreamProvider(id)),
          ),
        ]),
        data: (item) => item == null
            ? _ItemPage('Item unavailable', [
                const HouseholdMessage(
                  'This item was deleted or is no longer available.',
                ),
                HouseholdAction(
                  'Return to Home',
                  onPressed: () => context.go('/home'),
                ),
              ])
            : builder(item),
      );
}

String _behavior(Item item) => switch (item.behaviorProfile) {
  BehaviorProfile.replenishable => 'Single-unit replenishable',
  BehaviorProfile.countableReplenishable => 'Countable replenishable',
  BehaviorProfile.durable => 'Durable item',
};

String _area(Item item, List<Area> areas) {
  final area = areas.where((a) => a.id == item.areaId).firstOrNull;
  return area == null
      ? 'Home area'
      : '${area.name}${area.isArchived ? ' (archived area)' : ''}';
}

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({required this.itemId, super.key});
  final int itemId;
  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool modalOpen = false;
  Future<void> command(Item item, _Command command) async {
    if (modalOpen) return;
    modalOpen = true;
    try {
      final saved = command == _Command.correct
          ? await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              isDismissible: false,
              enableDrag: false,
              useSafeArea: true,
              builder: (_) => _ItemCommandForm(item, command),
            )
          : await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _ItemCommandForm(item, command),
            );
      if (!mounted || saved != true) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (command) {
            _Command.archive =>
              '${item.name} archived. You can restore it from Archived items.',
            _Command.restore => '${item.name} restored to Home.',
            _Command.delete => '${item.name} permanently deleted.',
            _Command.correct => 'Current availability saved.',
          }),
        ),
      );
      if (command == _Command.delete) context.go('/home');
    } finally {
      modalOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => _ItemRecord(
    widget.itemId,
    builder: (item) {
      final areas = ref.watch(allAreasStreamProvider);
      return _ItemPage(
        'Item',
        [
          Text(item.name, style: GettoTypography.titleLarge),
          Text(
            '${_area(item, areas.asData?.value ?? [])} · ${_behavior(item)}',
            style: GettoTypography.bodySmall,
          ),
          if (areas.hasError) ...[
            const HouseholdMessage("Couldn't load the area name.", error: true),
            HouseholdAction(
              'Retry area',
              onPressed: () => ref.invalidate(allAreasStreamProvider),
            ),
          ],
          if (item.unit != null)
            Text(
              'Package context: ${item.unit}',
              style: GettoTypography.bodyMedium,
            ),
          if (item.isArchived)
            const HouseholdMessage(
              'Archived. This item remains saved and is excluded from Home and search.',
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: item.stockStatus == StockStatus.inStock
                ? const GettoStatusBadge(state: GettoBadgeState.inHome)
                : const HouseholdMessage('Not at home'),
          ),
          if (item.behaviorProfile == BehaviorProfile.countableReplenishable)
            HouseholdMessage(
              item.packageCount == null
                  ? 'Current count unknown'
                  : 'Current count: ${item.packageCount}',
            ),
          if (item.behaviorProfile == BehaviorProfile.durable)
            const HouseholdMessage(
              'Physical presence only. No Start / Finish lifecycle is required for this item.',
            ),
          if (item.isArchived)
            const HouseholdMessage(
              'Restore this item to edit its details or correct availability.',
            ),
          if (!item.isArchived) ...[
            HouseholdAction(
              'Edit or move',
              onPressed: () => context.push('/home/items/${item.id}/edit'),
            ),
            HouseholdAction(
              item.behaviorProfile == BehaviorProfile.countableReplenishable
                  ? 'Set current count'
                  : 'Correct presence',
              secondary: true,
              onPressed: () => command(item, _Command.correct),
            ),
          ],
          HouseholdAction(
            item.isArchived ? 'Restore item' : 'Archive item',
            secondary: !item.isArchived,
            onPressed: () => command(
              item,
              item.isArchived ? _Command.restore : _Command.archive,
            ),
          ),
        ],
        more: PopupMenuButton<String>(
          tooltip: 'Item options',
          icon: const SizedBox.square(
            dimension: 24,
            child: GettoScreenArtwork('more'),
          ),
          onSelected: (_) => command(item, _Command.delete),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
          ],
        ),
      );
    },
  );
}

class ArchivedItemsScreen extends ConsumerWidget {
  const ArchivedItemsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(allAreasStreamProvider).asData?.value ?? <Area>[];
    return ref
        .watch(archivedItemsStreamProvider)
        .when(
          loading: () => const _ItemPage('Archived items', [
            HouseholdMessage('Loading archived items…'),
          ]),
          error: (_, _) => _ItemPage('Archived items', [
            const HouseholdMessage(
              "Couldn't load archived items.",
              error: true,
            ),
            HouseholdAction(
              'Retry',
              onPressed: () => ref.invalidate(archivedItemsStreamProvider),
            ),
          ]),
          data: (items) => _ItemPage('Archived items', [
            const Text(
              'Archived items remain saved. Select an item to restore it to Home.',
            ),
            if (items.isEmpty) const HouseholdMessage('No archived items'),
            for (final item in items)
              GettoItemRow(
                title: item.name,
                subtitle: _area(item, areas),
                factualStatus: 'Archived',
                onTap: () => context.push('/home/items/${item.id}'),
              ),
          ]),
        );
  }
}

class ItemEditScreen extends StatelessWidget {
  const ItemEditScreen({required this.itemId, super.key});
  final int itemId;
  @override
  Widget build(BuildContext context) => _ItemRecord(
    itemId,
    builder: (item) => _EditForm(key: ValueKey(item.id), initial: item),
  );
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.initial, super.key});
  final Item initial;
  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  late final ItemManagementController controller;
  late final TextEditingController name;
  late final TextEditingController unit;
  @override
  void initState() {
    super.initState();
    controller = ItemManagementController(
      ref.read(itemRepositoryProvider),
      widget.initial,
    );
    name = TextEditingController(text: controller.name);
    unit = TextEditingController(text: controller.unit);
  }

  @override
  void didUpdateWidget(covariant _EditForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A direct archived route has no draft to expose until restoration.
    // An already-open active draft is retained across external archive/restore.
    if (controller.expected.isArchived && !widget.initial.isArchived) {
      controller.expected = widget.initial;
      controller.name = widget.initial.name;
      controller.areaId = widget.initial.areaId;
      controller.unit = widget.initial.unit ?? '';
      name.text = controller.name;
      unit.text = controller.unit;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    name.dispose();
    unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(allAreasStreamProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (widget.initial.isArchived) {
          return _ItemPage('Archived item', [
            Text(widget.initial.name, style: GettoTypography.titleMedium),
            const HouseholdMessage(
              'Restore this item from item details before editing. Any draft is retained while this page stays open.',
            ),
            HouseholdAction(
              'View item',
              onPressed: controller.busy ? null : () => _back(context),
            ),
          ], busy: controller.busy);
        }
        final choices = (areas.asData?.value ?? <Area>[])
            .where((a) => !a.isArchived || a.id == controller.expected.areaId)
            .toList();
        final selectedExists = choices.any((a) => a.id == controller.areaId);
        return _ItemPage('Edit item', [
          _label(
            'Item name',
            TextField(
              key: const Key('edit-name'),
              controller: name,
              enabled: !controller.busy,
              textCapitalization: TextCapitalization.sentences,
              decoration: _field('Item name', helper: '1 to 100 characters'),
              onChanged: (value) => controller.name = value,
            ),
          ),
          if (areas.isLoading) const HouseholdMessage('Loading home areas…'),
          if (areas.hasError) ...[
            const HouseholdMessage(
              "Couldn't load home areas. Your edits are retained.",
              error: true,
            ),
            HouseholdAction(
              'Retry areas',
              onPressed: controller.busy
                  ? null
                  : () => ref.invalidate(allAreasStreamProvider),
            ),
          ],
          _label(
            'Home area',
            DropdownButtonFormField<int>(
              key: ValueKey('${controller.areaId}-$selectedExists'),
              initialValue: selectedExists ? controller.areaId : null,
              isExpanded: true,
              decoration: _field('Home area'),
              items: [
                for (final a in choices)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(
                      '${a.name}${a.isArchived ? ' (current archived area)' : ''}',
                    ),
                  ),
              ],
              onChanged: controller.busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => controller.areaId = value);
                      }
                    },
            ),
          ),
          _label(
            'Package context (optional)',
            TextField(
              key: const Key('edit-unit'),
              controller: unit,
              enabled: !controller.busy,
              decoration: _field(
                'Package context (optional)',
                helper: 'Up to 20 characters. Clear to remove.',
              ),
              onChanged: (value) => controller.unit = value,
            ),
          ),
          const Text(
            "Changing the name, area or package context won't change the item's current availability or count.",
          ),
          if (controller.error != null)
            HouseholdMessage(controller.error!, error: true),
          if (controller.conflict) ...[
            HouseholdMessage(
              'Latest saved details: ${widget.initial.name} · ${_area(widget.initial, areas.asData?.value ?? [])} · ${widget.initial.unit ?? 'No package context'}${widget.initial.isArchived ? ' · Archived' : ''}',
            ),
            HouseholdAction(
              'Use latest saved version with my draft',
              secondary: true,
              onPressed: () => controller.acknowledge(widget.initial),
            ),
          ],
          HouseholdAction(
            controller.busy ? 'Saving…' : 'Save changes',
            minimumHeight: 50,
            onPressed:
                controller.busy ||
                    areas.hasError ||
                    areas.isLoading ||
                    !selectedExists ||
                    controller.conflict
                ? null
                : () async {
                    final saved = await controller.saveMetadata();
                    if (!context.mounted || !saved) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item details saved.')),
                    );
                    _back(context);
                  },
          ),
          HouseholdAction(
            'Cancel',
            secondary: true,
            onPressed: controller.busy ? null : () => _back(context),
          ),
        ], busy: controller.busy);
      },
    );
  }
}

enum _Command { archive, restore, delete, correct }

class _ItemCommandForm extends ConsumerStatefulWidget {
  const _ItemCommandForm(this.item, this.command);
  final Item item;
  final _Command command;
  @override
  ConsumerState<_ItemCommandForm> createState() => _ItemCommandFormState();
}

class _ItemCommandFormState extends ConsumerState<_ItemCommandForm> {
  late final ItemManagementController controller;
  late final TextEditingController count;
  StockStatus? presence;
  @override
  void initState() {
    super.initState();
    controller = ItemManagementController(
      ref.read(itemRepositoryProvider),
      widget.item,
    );
    count = TextEditingController(
      text: widget.item.packageCount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    controller.dispose();
    count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final correcting = widget.command == _Command.correct;
      final current = ref
          .watch(itemStreamProvider(widget.item.id))
          .asData
          ?.value;
      final readOnly =
          correcting && (current?.isArchived ?? widget.item.isArchived);
      final deleting = widget.command == _Command.delete;
      final countable =
          widget.item.behaviorProfile == BehaviorProfile.countableReplenishable;
      final value = int.tryParse(count.text);
      final title = switch (widget.command) {
        _Command.archive => 'Archive ${widget.item.name}?',
        _Command.restore => 'Restore ${widget.item.name}?',
        _Command.delete => 'Delete ${widget.item.name}?',
        _Command.correct =>
          countable ? 'Set current count' : 'Correct presence',
      };
      final content = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (deleting)
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GettoColors.errorSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SvgPicture.asset(
                    'assets/figma/m233/delete.svg',
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            const SizedBox(height: 13),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GettoTypography.titleMedium,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              switch (widget.command) {
                _Command.archive => 'Archived items leave Home and search, but remain saved. You can restore them later.',
                _Command.restore => 'The item returns to Home in its currently saved area, with its saved details. Items in archived areas remain visible in All.',
                _Command.delete => 'This permanently deletes the item and its saved details. This cannot be undone.',
                _Command.correct =>
                  'Set what is true now for ${widget.item.name}. This only corrects saved availability${countable ? ' and count' : ''}.',
              },
              textAlign: TextAlign.center,
              style: GettoTypography.bodySmall,
            ),
            if (correcting) ...[
              if (readOnly)
                const HouseholdMessage(
                  'This item is archived. Restore it from item details before correcting availability. Your entry is still here.',
                ),
              const SizedBox(height: 20),
              if (countable) ...[
                if (widget.item.packageCount == null)
                  const HouseholdMessage(
                    'Count unknown. Enter an explicit count; zero means out of stock.',
                  ),
                _label(
                  'Current count',
                  TextField(
                    key: const Key('correction-count'),
                    controller: count,
                    enabled: !controller.busy && !readOnly,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _field(
                      'Current count',
                      helper: 'A nonnegative whole number',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 12),
                if (value != null && value >= 0)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Center(
                      child: GettoCountStepper(
                        value: value,
                        maximum: 9223372036854775807,
                        onChanged: controller.busy || readOnly
                            ? null
                            : (v) => setState(() => count.text = '$v'),
                      ),
                    ),
                  ),
              ] else ...[
                HouseholdAction(
                  'In home',
                  secondary: presence != StockStatus.inStock,
                  onPressed: controller.busy || readOnly
                      ? null
                      : () => setState(() => presence = StockStatus.inStock),
                ),
                const SizedBox(height: 12),
                HouseholdAction(
                  'Not at home',
                  secondary: presence != StockStatus.outOfStock,
                  onPressed: controller.busy || readOnly
                      ? null
                      : () => setState(() => presence = StockStatus.outOfStock),
                ),
              ],
            ],
            if (controller.error != null) ...[
              const SizedBox(height: 13),
              HouseholdMessage(controller.error!, error: true),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                backgroundColor: deleting
                    ? const Color(0xFFAC2B29)
                    : GettoColors.actionPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed:
                  controller.busy ||
                      readOnly ||
                      (correcting &&
                          (countable
                              ? value == null || value < 0
                              : presence == null))
                  ? null
                  : () async {
                      final saved = await switch (widget.command) {
                        _Command.archive => controller.archive(),
                        _Command.restore => controller.restore(),
                        _Command.delete => controller.delete(),
                        _Command.correct =>
                          countable
                              ? controller.correctCount(value!)
                              : controller.correctPresence(presence!),
                      };
                      if (context.mounted && saved) {
                        Navigator.of(context).pop(true);
                      }
                    },
              child: Text(
                controller.busy
                    ? 'Saving…'
                    : switch (widget.command) {
                        _Command.archive => 'Archive item',
                        _Command.restore => 'Restore item',
                        _Command.delete => 'Delete permanently',
                        _Command.correct =>
                          countable ? 'Save count' : 'Save presence',
                      },
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 9),
            HouseholdAction(
              'Cancel',
              secondary: true,
              minimumHeight: 48,
              onPressed: controller.busy
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      );
      return PopScope(
        canPop: !controller.busy,
        child: correcting
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(child: content),
              )
            : Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                backgroundColor: const Color(0xFFFFFEFB),
                constraints: const BoxConstraints(maxWidth: 344),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFDBE0DD)),
                ),
                child: SingleChildScrollView(child: content),
              ),
      );
    },
  );
}
