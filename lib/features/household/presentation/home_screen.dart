import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/composition/household_providers.dart';
import '../../../design_system/components/getto_artwork.dart';
import '../../../design_system/components/getto_item_row.dart';
import '../../../design_system/components/getto_screen_artwork.dart';
import '../../../design_system/components/getto_skeleton_row.dart';
import '../../../design_system/components/getto_status_badge.dart';
import '../../../design_system/tokens/getto_colors.dart';
import '../../../design_system/typography/getto_typography.dart';
import '../domain/area.dart';
import '../domain/item.dart';
import '../domain/stock_status.dart';
import 'household_widgets.dart';
import 'item_entry_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({this.areaId, super.key});
  final int? areaId;
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late final TextEditingController search;
  final searchFocus = FocusNode();
  double lastKeyboardInset = 0;
  bool modalOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    search = TextEditingController(text: ref.read(homeSearchQueryProvider));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    lastKeyboardInset = View.of(context).viewInsets.bottom;
  }

  @override
  void didChangeMetrics() {
    final inset = View.of(context).viewInsets.bottom;
    if (lastKeyboardInset > 0 && inset == 0 && searchFocus.hasFocus) {
      searchFocus.unfocus();
    }
    lastKeyboardInset = inset;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchFocus.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> addItem() async {
    if (modalOpen) return;
    modalOpen = true;
    try {
      final saved = await showItemEntry(context);
      if (mounted && saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${saved.name} added to your home.')),
        );
      }
    } finally {
      modalOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(allAreasStreamProvider);
    final items = ref.watch(allItemsStreamProvider);
    final query = ref.watch(homeSearchQueryProvider);
    if (search.text != query) {
      search.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    final loading = areas.isLoading || items.isLoading;
    final error = areas.hasError || items.hasError;
    final allAreas = areas.asData?.value ?? const <Area>[];
    final activeAreas = allAreas.where((a) => !a.isArchived).toList();
    final activeItems = items.asData?.value ?? const <Item>[];
    final selected = allAreas.where((a) => a.id == widget.areaId).firstOrNull;
    final unavailable =
        widget.areaId != null && (selected == null || selected.isArchived);
    final contextual = widget.areaId == null
        ? activeItems
        : activeItems.where((i) => i.areaId == widget.areaId).toList();
    final needle = query.trim().toLowerCase();
    final visible = contextual
        .where((i) => i.name.toLowerCase().contains(needle))
        .toList();
    final subtitle = loading
        ? 'Loading saved items'
        : error
        ? 'Saved items unavailable'
        : widget.areaId == null
        ? '${activeItems.length} ${activeItems.length == 1 ? 'item' : 'items'} in your home'
        : '${contextual.length} active ${contextual.length == 1 ? 'item' : 'items'} in ${selected?.name ?? 'this area'}';
    return Scaffold(
      key: const ValueKey('getto-home-page'),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FloatingActionButton(
          tooltip: 'Add household item',
          backgroundColor: GettoColors.actionPrimary,
          foregroundColor: GettoColors.surface,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onPressed: addItem,
          child: const GettoArtwork(
            art: GettoArt.increase,
            followIconTheme: true,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CustomScrollView(
              key: PageStorageKey('home-scroll-${widget.areaId}'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Home',
                                    style: GettoTypography.titleLarge.copyWith(
                                      fontSize: 28,
                                      height: 36 / 28,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: GettoTypography.bodySmall.copyWith(
                                      color: GettoColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            PopupMenuButton<String>(
                              tooltip: 'More home options',
                              onSelected: (value) {
                                if (value == 'add') {
                                  addItem();
                                } else if (value == 'archived') {
                                  context.push('/home/archived');
                                } else if (value == 'manage-areas') {
                                  searchFocus.unfocus();
                                  context.push('/home/manage-areas');
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'manage-areas',
                                  child: Text('Manage areas'),
                                ),
                                PopupMenuItem(
                                  value: 'add',
                                  child: Text('Add item'),
                                ),
                                PopupMenuItem(
                                  value: 'archived',
                                  child: Text('Archived items'),
                                ),
                              ],
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: GettoColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFDDE3DF),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const SizedBox.square(
                                  dimension: 24,
                                  child: GettoScreenArtwork('more'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('home-search'),
                          controller: search,
                          focusNode: searchFocus,
                          style: GettoTypography.bodySmall,
                          textInputAction: TextInputAction.search,
                          onTapOutside: (_) => searchFocus.unfocus(),
                          onSubmitted: (_) => searchFocus.unfocus(),
                          onChanged: ref
                              .read(homeSearchQueryProvider.notifier)
                              .change,
                          decoration: InputDecoration(
                            isDense: true,
                            constraints: const BoxConstraints(minHeight: 48),
                            hintText: 'Search items',
                            hintStyle: GettoTypography.bodySmall.copyWith(
                              color: GettoColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: GettoColors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox.square(
                                dimension: 20,
                                child: GettoScreenArtwork('search'),
                              ),
                            ),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      search.clear();
                                      ref
                                          .read(
                                            homeSearchQueryProvider.notifier,
                                          )
                                          .change('');
                                    },
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFDDE3DF),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFDDE3DF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          key: const ValueKey('home-area-filters'),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _AreaFilter(
                                label: 'All',
                                selected: widget.areaId == null,
                                onPressed: () => context.go('/home'),
                              ),
                              for (final area in activeAreas)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _AreaFilter(
                                    label: area.name,
                                    selected: widget.areaId == area.id,
                                    onPressed: () {
                                      if (widget.areaId != area.id) {
                                        context.go('/home/areas/${area.id}');
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    !loading && !error && contextual.isEmpty ? 42 : 18,
                    24,
                    100,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (error) ...[
                          const HouseholdMessage(
                            "Couldn't load your home. Your saved data has not been reset.",
                            error: true,
                          ),
                          const SizedBox(height: 12),
                          HouseholdAction(
                            'Retry',
                            onPressed: () {
                              ref.invalidate(allAreasStreamProvider);
                              ref.invalidate(allItemsStreamProvider);
                            },
                          ),
                        ] else if (loading) ...[
                          Semantics(
                            liveRegion: true,
                            child: const Text('Loading your saved home…'),
                          ),
                          for (var i = 0; i < 3; i++)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: GettoSkeletonRow(
                                kind: GettoSkeletonKind.item,
                              ),
                            ),
                        ] else if (unavailable) ...[
                          const HouseholdMessage(
                            'This home area is unavailable. Your items remain saved.',
                          ),
                          const SizedBox(height: 12),
                          HouseholdAction(
                            'Browse Home',
                            onPressed: () => context.go('/home'),
                          ),
                        ] else if (needle.isNotEmpty && visible.isEmpty) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'No matching items',
                              style: GettoTypography.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Try another item name or clear your search.',
                            style: GettoTypography.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          HouseholdAction(
                            'Clear search',
                            onPressed: () => ref
                                .read(homeSearchQueryProvider.notifier)
                                .change(''),
                          ),
                        ] else if (contextual.isEmpty) ...[
                          Text(
                            activeItems.isEmpty
                                ? 'Nothing to track yet'
                                : 'No items in this area yet',
                            style: GettoTypography.titleLarge.copyWith(
                              fontSize: 23,
                              height: 34 / 23,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Your home is ready. Start with one item whenever you like.',
                            style: GettoTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.w400,
                              height: 22 / 15,
                              color: GettoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const AspectRatio(
                            aspectRatio: 374 / 190,
                            child: GettoScreenArtwork('empty-home'),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            activeAreas.isEmpty
                                ? 'Create a home area while adding an item.'
                                : '${activeAreas.map((a) => a.name).join(', ')} are already available.',
                            style: GettoTypography.bodySmall.copyWith(
                              color: GettoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          HouseholdAction(
                            activeItems.isEmpty ? 'Add first item' : 'Add item',
                            onPressed: addItem,
                          ),
                        ] else ...[
                          Text(
                            needle.isEmpty
                                ? 'Still tracking'
                                : '${visible.length} matching ${visible.length == 1 ? 'item' : 'items'}',
                            style: GettoTypography.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            foregroundDecoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFDDE3DF),
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < visible.length; i++) ...[
                                    if (i > 0)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        child: Divider(
                                          height: 1,
                                          color: Color(0x99DDE3DF),
                                        ),
                                      ),
                                    GettoItemRow(
                                      onTap: () => context.push(
                                        '/home/items/${visible[i].id}',
                                      ),
                                      grouped: true,
                                      title: visible[i].name,
                                      subtitle:
                                          '${allAreas.where((a) => a.id == visible[i].areaId).firstOrNull?.name ?? 'Home area'}${visible[i].unit == null ? '' : ' · ${visible[i].unit}'}${visible[i].packageCount == null ? '' : ' · ${visible[i].packageCount} remaining'}',
                                      status:
                                          visible[i].stockStatus ==
                                              StockStatus.inStock
                                          ? GettoBadgeState.inHome
                                          : null,
                                      factualStatus:
                                          visible[i].stockStatus ==
                                              StockStatus.outOfStock
                                          ? 'Not at home'
                                          : null,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaFilter extends StatelessWidget {
  const _AreaFilter({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(label == 'All' ? 58 : 0, 48),
        padding: EdgeInsets.symmetric(
          horizontal: label == 'All' ? 12 : 20,
          vertical: 12,
        ),
        backgroundColor: selected
            ? const Color(0xFFF2F8F5)
            : Colors.transparent,
        foregroundColor: selected
            ? GettoColors.textBrand
            : GettoColors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: GettoTypography.labelMedium.copyWith(
          color: selected ? GettoColors.textBrand : GettoColors.textSecondary,
          letterSpacing: .1,
        ),
      ),
    ),
  );
}
