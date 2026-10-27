import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/app/app.dart';
import 'package:getto/app/routing/app_router.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M1 shell boots and retains three destinations on device', (
    tester,
  ) async {
    final router = createAppRouter(initialLocation: '/home');
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(child: GettoApp(router: router)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('getto-home-page')), findsOneWidget);

    final compact =
        MediaQuery.sizeOf(
          tester.element(find.byKey(const ValueKey('getto-home-page'))),
        ).width <
        600;
    expect(find.byType(NavigationBar), compact ? findsOneWidget : findsNothing);
    expect(
      find.byType(NavigationRail),
      compact ? findsNothing : findsOneWidget,
    );

    if (compact) {
      await tester.tap(find.byKey(const ValueKey('getto-nav-buy')));
    } else {
      await tester.tap(find.byIcon(Icons.shopping_bag_outlined).first);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('getto-buy-page')), findsOneWidget);

    if (compact) {
      await tester.tap(find.byKey(const ValueKey('getto-nav-bills')));
    } else {
      await tester.tap(find.byIcon(Icons.receipt_long_outlined).first);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('getto-bills-page')), findsOneWidget);
  });
}
