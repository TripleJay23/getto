import 'package:flutter/material.dart';

import '../responsive/getto_responsive.dart';
import '../tokens/getto_spacing.dart';
import '../typography/getto_typography.dart';

/// Neutral shell-only content proof; feature screens replace this from M2 on.
class GettoShellPage extends StatelessWidget {
  const GettoShellPage({required this.title, required this.pageKey, super.key});

  final String title;
  final Key pageKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Getto'), centerTitle: false),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: GettoReadableContent(
            child: Padding(
              padding: const EdgeInsets.only(
                top: GettoSpacing.xl,
                bottom: GettoSpacing.xl,
              ),
              child: Text(
                title,
                key: pageKey,
                style: GettoTypography.titleLarge,
                textAlign: TextAlign.start,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
