import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/routing/getto_shell.dart';
import 'package:getto/design_system/components/getto_shell_page.dart';
import 'package:getto/design_system/theme/getto_theme.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Home child route survives Buy/Bills branch switching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              GettoShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const GettoShellPage(
                    title: 'Home',
                    pageKey: ValueKey('test-home'),
                  ),
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (context, state) => const Scaffold(
                        body: Center(
                          child: Text(
                            'Home child retained',
                            key: Key('home-child'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/buy',
                  builder: (context, state) => const GettoShellPage(
                    title: 'Buy',
                    pageKey: ValueKey('test-buy'),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/bills',
                  builder: (context, state) => const GettoShellPage(
                    title: 'Bills',
                    pageKey: ValueKey('test-bills'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: GettoTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();

    router.go('/home/detail');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-child')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('getto-nav-buy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('test-buy')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('getto-nav-bills')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('test-bills')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('getto-nav-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-child')), findsOneWidget);

    // Re-selecting the current destination intentionally returns to its root.
    await tester.tap(find.byKey(const ValueKey('getto-nav-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('test-home')), findsOneWidget);
  });
}
