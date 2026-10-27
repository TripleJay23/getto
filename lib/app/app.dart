import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/theme/getto_theme.dart';

class GettoApp extends StatelessWidget {
  const GettoApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Getto',
      debugShowCheckedModeBanner: false,
      theme: GettoTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
