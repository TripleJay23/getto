import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/design_system/components/getto_status_badge.dart';
import 'package:getto/design_system/theme/getto_theme.dart';

void main() {
  const labels = <GettoBadgeState, String>{
    GettoBadgeState.learning: 'Learning',
    GettoBadgeState.earlyEstimate: 'Early estimate',
    GettoBadgeState.established: 'Established',
    GettoBadgeState.attention: 'Attention',
    GettoBadgeState.checkNeeded: 'Check needed',
    GettoBadgeState.expiring: 'Expiring',
    GettoBadgeState.expired: 'Expired',
    GettoBadgeState.acquired: 'Acquired',
    GettoBadgeState.readyToRestock: 'Ready to restock',
    GettoBadgeState.upcoming: 'Upcoming',
    GettoBadgeState.dueToday: 'Due today',
    GettoBadgeState.overdue: 'Overdue',
    GettoBadgeState.paid: 'Paid',
    GettoBadgeState.inUse: 'In use',
    GettoBadgeState.inHome: 'In home',
  };

  testWidgets('every live Figma variant has visible text and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    expect(labels.length, 15);
    for (final entry in labels.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: GettoTheme.light,
          home: Scaffold(
            body: Center(
              child: GettoStatusBadge(
                state: entry.key,
                icon: const Icon(Icons.circle, size: 16),
              ),
            ),
          ),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(find.bySemanticsLabel(entry.value), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });

  testWidgets('a badge has no independent destructive or edit action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GettoStatusBadge(
            state: GettoBadgeState.attention,
            icon: Icon(Icons.info, size: 16),
          ),
        ),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Attention'), findsOneWidget);
  });
}
