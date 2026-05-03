import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/presentation/widgets/premium_blur_gate.dart';

void main() {
  Widget createSubject({
    required String featureTitle,
    required String featureText,
    VoidCallback? onUpgrade,
    Widget child = const SizedBox.expand(),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PremiumBlurGate(
          featureTitle: featureTitle,
          featureText: featureText,
          onUpgrade: onUpgrade,
          child: child,
        ),
      ),
    );
  }

  group('PremiumBlurGate', () {
    testWidgets('zeigt featureTitle im Overlay', (tester) async {
      await tester.pumpWidget(createSubject(
        featureTitle: 'Wochenberichte',
        featureText: 'Beschreibungstext',
        onUpgrade: () {},
      ));

      expect(find.text('Wochenberichte'), findsOneWidget);
    });

    testWidgets('zeigt featureText im Overlay', (tester) async {
      await tester.pumpWidget(createSubject(
        featureTitle: 'Test',
        featureText: 'Detailbeschreibung für das Feature',
        onUpgrade: () {},
      ));

      expect(find.text('Detailbeschreibung für das Feature'), findsOneWidget);
    });

    testWidgets('zeigt Premium-Icon', (tester) async {
      await tester.pumpWidget(createSubject(
        featureTitle: 'Test',
        featureText: 'Text',
        onUpgrade: () {},
      ));

      expect(find.byIcon(Icons.workspace_premium), findsWidgets);
    });

    testWidgets('zeigt "Premium freischalten"-Button wenn onUpgrade gesetzt', (tester) async {
      await tester.pumpWidget(createSubject(
        featureTitle: 'Test',
        featureText: 'Text',
        onUpgrade: () {},
      ));

      expect(find.text('Premium freischalten'), findsOneWidget);
      expect(
        find.text('Abonnements können derzeit nur in der mobilen App verwaltet werden.'),
        findsNothing,
      );
    });

    testWidgets('ruft onUpgrade auf wenn Button gedrückt', (tester) async {
      var called = false;
      await tester.pumpWidget(createSubject(
        featureTitle: 'Test',
        featureText: 'Text',
        onUpgrade: () => called = true,
      ));

      await tester.tap(find.text('Premium freischalten'));
      expect(called, isTrue);
    });

    testWidgets('zeigt Web-Hinweis wenn onUpgrade null', (tester) async {
      await tester.pumpWidget(createSubject(
        featureTitle: 'Test',
        featureText: 'Text',
        onUpgrade: null,
      ));

      expect(
        find.text('Abonnements können derzeit nur in der mobilen App verwaltet werden.'),
        findsOneWidget,
      );
      expect(find.text('Premium freischalten'), findsNothing);
    });

    testWidgets('rendert child hinter dem Overlay', (tester) async {
      await tester.pumpWidget(createSubject(
        featureTitle: 'Test',
        featureText: 'Text',
        onUpgrade: () {},
        child: const Text('Inhalt darunter'),
      ));

      // Child ist im Widget-Tree vorhanden (auch wenn gebluurt)
      expect(find.text('Inhalt darunter'), findsOneWidget);
    });
  });
}
