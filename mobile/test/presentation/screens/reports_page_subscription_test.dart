import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/view_models/auth_view_model.dart';

void main() {
  group('Reports Page Subscription Tests', () {
    testWidgets('WeeklyReportView shows login button when user is null', (tester) async {
      final controller = StreamController<UserEntity?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => controller.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(body: WeeklyReportView()),
          ),
        ),
      );
      
      controller.add(null);
      await tester.pump(); // Process stream event

      expect(find.text('Anmeldung erforderlich für Wochenberichte'), findsOneWidget);
      expect(find.text('Anmelden'), findsOneWidget);
      expect(find.text('Premium-Funktion'), findsNothing);
      
      await controller.close();
    });

    testWidgets('WeeklyReportView shows premium blur gate when user is logged in but NO premium', (tester) async {
      const user = UserEntity(id: '123', email: 'test@test.com', displayName: 'Test User');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            isPremiumProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: WeeklyReportView()),
          ),
        ),
      );
      await tester.pump(); // Allow Stream to emit

      // Login Screen sollte weg sein
      expect(find.text('Anmelden erforderlich für Wochenberichte'), findsNothing);

      // Blur-Gate mit Kaufanreiz sollte da sein
      expect(find.text('Wochenberichte'), findsOneWidget);
      expect(find.text('Premium freischalten'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium), findsWidgets);
    });

    testWidgets('MonthlyReportView shows login button when user is null', (tester) async {
      final controller = StreamController<UserEntity?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => controller.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MonthlyReportView()),
          ),
        ),
      );
      
      controller.add(null);
      await tester.pump();

      expect(find.text('Anmeldung erforderlich für Monatsberichte'), findsOneWidget);
      expect(find.text('Anmelden'), findsOneWidget);
      
      await controller.close();
    });

    testWidgets('MonthlyReportView shows premium blur gate when user is logged in but NO premium', (tester) async {
      const user = UserEntity(id: '123', email: 'test@test.com', displayName: 'Test User');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            isPremiumProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MonthlyReportView()),
          ),
        ),
      );
      await tester.pump(); // Allow Stream to emit

      // Login Screen sollte weg sein
      expect(find.text('Anmelden erforderlich für Monatsberichte'), findsNothing);

      // Blur-Gate mit Kaufanreiz sollte da sein
      expect(find.text('Monatsberichte'), findsOneWidget);
      expect(find.text('Premium freischalten'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium), findsWidgets);
    });
  });
}
