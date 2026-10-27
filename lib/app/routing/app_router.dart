import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/getto_shell_page.dart';
import '../../features/household/presentation/home_screen.dart';
import '../../features/household/presentation/area_management_screen.dart';
import '../../features/household/presentation/item_management_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import 'getto_shell.dart';

GoRouter createAppRouter({String initialLocation = '/start'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            GettoShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'manage-areas',
                    builder: (context, state) => const AreaManagementScreen(),
                    routes: [
                      GoRoute(
                        path: ':areaId/remove',
                        builder: (context, state) => AreaRemovalScreen(
                          areaId:
                              int.tryParse(
                                state.pathParameters['areaId'] ?? '',
                              ) ??
                              -1,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'archived',
                    builder: (context, state) => const ArchivedItemsScreen(),
                  ),
                  GoRoute(
                    path: 'items/:itemId',
                    builder: (context, state) => ItemDetailScreen(
                      itemId:
                          int.tryParse(state.pathParameters['itemId'] ?? '') ??
                          -1,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => ItemEditScreen(
                          itemId:
                              int.tryParse(
                                state.pathParameters['itemId'] ?? '',
                              ) ??
                              -1,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'areas/:id',
                    builder: (context, state) => HomeScreen(
                      areaId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
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
                  pageKey: ValueKey('getto-buy-page'),
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
                  pageKey: ValueKey('getto-bills-page'),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
