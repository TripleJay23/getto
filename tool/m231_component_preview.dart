import 'package:flutter/material.dart';
import 'package:getto/design_system/components/getto_artwork.dart';
import 'package:getto/design_system/components/getto_count_stepper.dart';
import 'package:getto/design_system/components/getto_empty_state_card.dart';
import 'package:getto/design_system/components/getto_home_area_row.dart';
import 'package:getto/design_system/components/getto_item_row.dart';
import 'package:getto/design_system/components/getto_skeleton_row.dart';
import 'package:getto/design_system/components/getto_status_badge.dart';
import 'package:getto/design_system/theme/getto_theme.dart';
import 'package:getto/design_system/tokens/getto_colors.dart';
import 'package:getto/design_system/typography/getto_typography.dart';

/// M2.3.1 inspection-only entrypoint. Never register it in product routing.
///
/// Start with `flutter run -t tool/m231_component_preview.dart -d <device>`.
/// Every example is in-memory; it cannot read or modify household storage.
void main() => runApp(const M231ComponentPreviewApp());

class M231ComponentPreviewApp extends StatelessWidget {
  const M231ComponentPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: GettoTheme.light,
    home: const M231ComponentPreviewPage(),
  );
}

class M231ComponentPreviewPage extends StatefulWidget {
  const M231ComponentPreviewPage({super.key});

  @override
  State<M231ComponentPreviewPage> createState() =>
      _M231ComponentPreviewPageState();
}

class _M231ComponentPreviewPageState extends State<M231ComponentPreviewPage> {
  double _previewWidth = 320;
  double _textScale = 1;
  int _count = 1;
  bool _controlsEnabled = true;

  void _announce(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Preview only: $action')));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('M2.3.1 · Component review')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Isolated UI review', style: GettoTypography.titleMedium),
              Text(
                'Actual app viewport: ${media.size.width.toStringAsFixed(2)} × '
                '${media.size.height.toStringAsFixed(2)}dp',
                style: GettoTypography.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Adjust the reference width and text size. On a narrower '
                'device, swipe horizontally to inspect the entire 430dp '
                'canvas. This is not a product screen.',
                style: GettoTypography.bodySmall.copyWith(
                  color: GettoColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text('Content width', style: GettoTypography.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('320dp'),
                    selected: _previewWidth == 320,
                    onSelected: (_) => setState(() => _previewWidth = 320),
                  ),
                  ChoiceChip(
                    label: const Text('430dp'),
                    selected: _previewWidth == 430,
                    onSelected: (_) => setState(() => _previewWidth = 430),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Text size', style: GettoTypography.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('100%'),
                    selected: _textScale == 1,
                    onSelected: (_) => setState(() => _textScale = 1),
                  ),
                  ChoiceChip(
                    label: const Text('200%'),
                    selected: _textScale == 2,
                    onSelected: (_) => setState(() => _textScale = 2),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Controls enabled'),
                value: _controlsEnabled,
                onChanged: (enabled) =>
                    setState(() => _controlsEnabled = enabled),
              ),
              Text(
                'Bundled original Figma SVGs · reference canvas '
                '${_previewWidth.toInt()}dp · component text '
                '${(_textScale * 100).toInt()}%.',
                style: GettoTypography.bodySmall,
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  key: const Key('m231-preview-canvas'),
                  width: _previewWidth,
                  child: MediaQuery(
                    data: media.copyWith(
                      textScaler: TextScaler.linear(_textScale),
                    ),
                    child: _PreviewContent(
                      count: _count,
                      controlsEnabled: _controlsEnabled,
                      onCountChanged: (next) => setState(() => _count = next),
                      onPreviewAction: _announce,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Inspection only · no household data is read or saved.',
                style: GettoTypography.labelSmall.copyWith(
                  color: GettoColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.count,
    required this.controlsEnabled,
    required this.onCountChanged,
    required this.onPreviewAction,
  });

  final int count;
  final bool controlsEnabled;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<String> onPreviewAction;

  static const _badges = <GettoBadgeState>[
    GettoBadgeState.learning,
    GettoBadgeState.earlyEstimate,
    GettoBadgeState.established,
    GettoBadgeState.attention,
    GettoBadgeState.checkNeeded,
    GettoBadgeState.expiring,
    GettoBadgeState.expired,
    GettoBadgeState.acquired,
    GettoBadgeState.readyToRestock,
    GettoBadgeState.upcoming,
    GettoBadgeState.dueToday,
    GettoBadgeState.overdue,
    GettoBadgeState.paid,
    GettoBadgeState.inUse,
    GettoBadgeState.inHome,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Semantic status badges · 15 states'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final state in _badges) GettoStatusBadge(state: state),
          ],
        ),
        const SizedBox(height: 24),
        _section('Controlled count stepper · 0–3'),
        Align(
          alignment: Alignment.centerLeft,
          child: GettoCountStepper(
            value: count,
            maximum: 3,
            onChanged: controlsEnabled ? onCountChanged : null,
          ),
        ),
        const SizedBox(height: 24),
        _section('Household item row'),
        GettoItemRow(
          title: 'Toothpaste',
          subtitle: 'Bathroom · In use',
          status: GettoBadgeState.inUse,
          onTap: controlsEnabled
              ? () => onPreviewAction('item row tapped')
              : null,
        ),
        const SizedBox(height: 12),
        GettoItemRow(
          title: 'Extra long household item name',
          subtitle: 'Bathroom · Optional package context',
          status: GettoBadgeState.readyToRestock,
          onTap: controlsEnabled
              ? () => onPreviewAction('long item row tapped')
              : null,
        ),
        const SizedBox(height: 24),
        _section('Manage areas · equal action capability'),
        GettoHomeAreaRow(
          name: 'Kitchen',
          activeItems: 6,
          isDefault: true,
          onManage: controlsEnabled
              ? () => onPreviewAction('manage default Kitchen area')
              : null,
        ),
        const SizedBox(height: 12),
        GettoHomeAreaRow(
          name: 'Personal study and storage space',
          activeItems: 2,
          isDefault: false,
          onManage: controlsEnabled
              ? () => onPreviewAction('manage custom area')
              : null,
        ),
        const SizedBox(height: 24),
        _section('Empty state and next step'),
        GettoEmptyStateCard(
          illustration: const GettoArtwork(art: GettoArt.search),
          title: 'No matches',
          description: 'Try another name or clear the search.',
          actionLabel: 'Clear search',
          onAction: controlsEnabled
              ? () => onPreviewAction('clear search')
              : null,
        ),
        const SizedBox(height: 24),
        _section('Static local-read loading'),
        Semantics(
          label: 'Loading item preview',
          child: const GettoSkeletonRow(kind: GettoSkeletonKind.item),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Loading bill preview',
          child: const GettoSkeletonRow(kind: GettoSkeletonKind.bill),
        ),
      ],
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: GettoTypography.titleSmall),
  );
}
