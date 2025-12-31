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

      expect(find.text('Anmelden erforderlich für Wochenberichte'), findsOneWidget);
      expect(find.text('Anmelden'), findsOneWidget);
      expect(find.text('Premium-Funktion'), findsNothing);
      
      await controller.close();
    });

    testWidgets('WeeklyReportView shows premium lock when user is logged in but NO premium', (tester) async {
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
      
      // Premium Lock Screen sollte da sein
      expect(find.text('Premium-Funktion'), findsOneWidget);
      expect(find.text('Wochenberichte sind nur für Premium-Nutzer verfügbar. Behalte den vollen Überblick über deine Überstunden.'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
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

      expect(find.text('Anmelden erforderlich für Monatsberichte'), findsOneWidget);
      expect(find.text('Anmelden'), findsOneWidget);
      
      await controller.close();
    });

    testWidgets('MonthlyReportView shows premium lock when user is logged in but NO premium', (tester) async {
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

      // Premium Lock Screen sollte da sein
      expect(find.text('Premium-Funktion'), findsOneWidget);
      expect(find.text('Monatsberichte und detaillierte Analysen sind nur für Premium-Nutzer verfügbar.'), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });
  });
}
