import 'package:flutter/material.dart';

import '../tokens/getto_radii.dart';

/// Static decorative loading placeholders from Figma 208:177.
///
/// The parent announces loading once; these shapes are not individual
/// accessible controls. No shimmer is used, including under reduced motion.
enum GettoSkeletonKind { item, bill }

class GettoSkeletonRow extends StatelessWidget {
  const GettoSkeletonRow({required this.kind, super.key});

  final GettoSkeletonKind kind;

  static const _neutral = Color(0xFFECEFEB);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDE3DF)),
          borderRadius: BorderRadius.circular(GettoRadii.lg),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: kind == GettoSkeletonKind.item ? 76 : 96,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
            child: kind == GettoSkeletonKind.item ? _buildItem() : _buildBill(),
          ),
        ),
      ),
    );
  }

  Widget _buildItem() => Row(
    children: [
      _line(44, 44, GettoRadii.md),
      const SizedBox(width: 12),
      Expanded(
        child: SizedBox(
          height: 34,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(double.infinity, 12),
              const SizedBox(height: 9),
              _line(96, 10),
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(width: 84, height: 48, child: Center(child: _line(72, 28))),
    ],
  );

  Widget _buildBill() => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(128, 12),
              const SizedBox(height: 8),
              _line(112, 10),
              const SizedBox(height: 8),
              _line(82, 10),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 92,
        height: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_line(82, 22), const SizedBox(height: 6), _line(68, 24)],
        ),
      ),
    ],
  );

  static Widget _line(double width, double height, [double radius = 999]) =>
      Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: _neutral,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
