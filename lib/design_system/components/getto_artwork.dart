import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Unmodified local exports from the accepted Figma component masters.
/// Source nodes and checksums are recorded in assets/figma/m231/provenance.json.
enum GettoArt {
  learning('badge-learning.svg', 16),
  earlyEstimate('badge-early-estimate.svg', 16),
  established('badge-established.svg', 16),
  attention('badge-attention-check-needed.svg', 16),
  expiring('badge-expiring.svg', 16),
  expired('badge-expired-overdue.svg', 16),
  acquired('badge-acquired.svg', 16),
  readyToRestock('badge-ready-to-restock.svg', 16),
  upcoming('badge-upcoming.svg', 16),
  dueToday('badge-due-today.svg', 16),
  paid('badge-paid.svg', 16),
  inUse('badge-in-use.svg', 16),
  inHome('badge-in-home.svg', 16),
  decrease('count-decrease.svg', 24),
  increase('count-increase.svg', 24),
  chevron('area-chevron.svg', 18),
  search('empty-search.svg', 40);

  const GettoArt(this.file, this.dimension);

  final String file;
  final double dimension;
  String get assetPath => 'assets/figma/m231/$file';
}

/// Decorative artwork. The enclosing status or control owns its semantics.
class GettoArtwork extends StatelessWidget {
  const GettoArtwork({
    required this.art,
    this.followIconTheme = false,
    super.key,
  });

  final GettoArt art;
  final bool followIconTheme;

  @override
  Widget build(BuildContext context) {
    final tint = followIconTheme ? IconTheme.of(context).color : null;
    return SizedBox.square(
      dimension: art.dimension,
      child: SvgPicture.asset(
        art.assetPath,
        excludeFromSemantics: true,
        colorFilter: tint == null
            ? null
            : ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
  }
}
