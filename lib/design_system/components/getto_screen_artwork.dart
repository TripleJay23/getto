import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Original screen assets exported from the final R3 Figma nodes.
/// Native SVG dimensions and node provenance live beside the bundled assets.
class GettoScreenArtwork extends StatelessWidget {
  const GettoScreenArtwork(this.name, {this.color, super.key});
  final String name;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      const {
        'orientation',
        'ready-home',
        'first-item',
        'saved-item',
      }.contains(name)
      ? Image.asset(
          'assets/figma/m232/$name.png',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.high,
        )
      : SvgPicture.asset(
          'assets/figma/${name == 'back' ? 'm233' : 'm232'}/$name.svg',
          excludeFromSemantics: true,
          colorFilter: color == null
              ? null
              : ColorFilter.mode(color!, BlendMode.srcIn),
        );
}
