import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/domain/local_date/local_date.dart';
import '../../../design_system/tokens/getto_colors.dart';
import '../../../design_system/tokens/getto_radii.dart';
import '../../../design_system/typography/getto_typography.dart';

String lifecycleDateLabel(BuildContext context, LocalDate date) =>
    '${MaterialLocalizations.of(context).formatMediumDate(DateTime(date.year, date.month, date.day))}, ${date.year}';
LocalDate? lifecycleDraftDate(String text) {
  try {
    return LocalDate.parse(text);
  } catch (_) {
    return null;
  }
}

String lifecycleDuration(int days) => '$days ${days == 1 ? 'day' : 'days'}';

/// Exact exported vectors at their native accepted dimensions, never stretched.
class LifecycleArtwork extends StatelessWidget {
  const LifecycleArtwork(this.name, {super.key});
  final String name;
  static const assets = <String, (String, double, double)>{
    'cycle-calendar': ('assets/figma/m304/cycle-calendar.svg', 30, 30),
    'still-in-use': ('assets/figma/m304/still-in-use.svg', 26, 26),
    'finished-now': ('assets/figma/m304/finished-now.svg', 26, 26),
    'finished-earlier': ('assets/figma/m304/finished-earlier.svg', 26, 26),
    'correct-start': ('assets/figma/m304/correct-start.svg', 26, 26),
    'next': ('assets/figma/m304/next.svg', 18, 18),
    'restock-finished': ('assets/figma/m304/restock-finished.svg', 26, 26),
    'restock-earlier': ('assets/figma/m304/restock-earlier.svg', 26, 26),
    'wrong-cycle': ('assets/figma/m304/wrong-cycle.svg', 26, 26),
    'about-half': ('assets/figma/m304/about-half.svg', 28, 28),
    'nearly-finished': ('assets/figma/m304/nearly-finished.svg', 28, 28),
    'date': ('assets/figma/m304/date.svg', 20, 20),
    'error': ('assets/figma/m304/error.svg', 20, 20),
    'success': ('assets/figma/m304/success.svg', 24, 24),
  };
  @override
  Widget build(BuildContext context) {
    final (path, width, height) = assets[name]!;
    return SvgPicture.asset(
      path,
      width: width,
      height: height,
      excludeFromSemantics: true,
    );
  }
}

class LifecycleChoice extends StatelessWidget {
  const LifecycleChoice(
    this.title,
    this.description, {
    required this.artwork,
    required this.onTap,
    this.selected = false,
    this.next = false,
    this.warning = false,
    super.key,
  });
  final String title, description, artwork;
  final VoidCallback? onTap;
  final bool selected, next, warning;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? const Color(0xFFF2F8F5) : GettoColors.surface,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: warning
                        ? GettoColors.attentionSurface
                        : const Color(0xFFEDF6F1),
                    borderRadius: BorderRadius.circular(GettoRadii.md),
                  ),
                  child: LifecycleArtwork(artwork),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GettoTypography.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GettoTypography.bodySmall.copyWith(
                          color: GettoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (next) ...[
                  const SizedBox(width: 8),
                  const LifecycleArtwork('next'),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LifecycleChoiceGroup extends StatelessWidget {
  const LifecycleChoiceGroup({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFDDE3DF)),
      borderRadius: BorderRadius.circular(GettoRadii.xl),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i != 0)
            const Padding(
              padding: EdgeInsets.only(left: 64, right: 14),
              child: Divider(height: 1, color: Color(0xFFE2EAE4)),
            ),
          children[i],
        ],
      ],
    ),
  );
}

class LifecycleDateField extends StatefulWidget {
  const LifecycleDateField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.today,
    required this.fieldKey,
    this.enabled = true,
    super.key,
  });
  final String label, value;
  final ValueChanged<String> onChanged;
  final LocalDate today;
  final Key fieldKey;
  final bool enabled;
  @override
  State<LifecycleDateField> createState() => _LifecycleDateFieldState();
}

class _LifecycleDateFieldState extends State<LifecycleDateField> {
  late final text = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant LifecycleDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != text.text) text.text = widget.value;
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    FocusManager.instance.primaryFocus?.unfocus();
    LocalDate parsed;
    try {
      parsed = LocalDate.parse(widget.value);
    } catch (_) {
      parsed = widget.today;
    }
    if (parsed.isAfter(widget.today)) parsed = widget.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(parsed.year, parsed.month, parsed.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(
        widget.today.year,
        widget.today.month,
        widget.today.day,
      ),
      helpText: widget.label,
    );
    if (picked != null && mounted) {
      widget.onChanged(
        LocalDate(picked.year, picked.month, picked.day).toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExcludeSemantics(
        child: Text(widget.label, style: GettoTypography.labelSmall),
      ),
      const SizedBox(height: 6),
      Semantics(
        label: widget.label,
        child: TextField(
          key: widget.fieldKey,
          controller: text,
          enabled: widget.enabled,
          keyboardType: TextInputType.datetime,
          onChanged: widget.onChanged,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: InputDecoration(
            helperText: 'YYYY-MM-DD · today or earlier',
            helperMaxLines: 3,
            filled: true,
            fillColor: GettoColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GettoRadii.md),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            suffixIcon: IconButton(
              tooltip: 'Choose ${widget.label.toLowerCase()}',
              onPressed: widget.enabled ? pick : null,
              icon: const LifecycleArtwork('date'),
            ),
          ),
        ),
      ),
    ],
  );
}
