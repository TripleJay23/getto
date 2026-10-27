import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/getto_primary_navigation.dart';
import '../../design_system/responsive/getto_responsive.dart';

/// One persistent navigator per Home/Buy/Bills branch.
/// Window-class changes affect navigation chrome, not branch identity.
class GettoShell extends StatelessWidget {
  const GettoShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final windowClass = GettoResponsive.classify(
      MediaQuery.sizeOf(context).width,
    );

    if (windowClass != GettoWindowClass.compact) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              GettoRailNavigation(
                selectedIndex: navigationShell.currentIndex,
                onSelected: _selectBranch,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: GettoBottomNavigation(
        selectedIndex: navigationShell.currentIndex,
        onSelected: _selectBranch,
      ),
    );
  }
}
