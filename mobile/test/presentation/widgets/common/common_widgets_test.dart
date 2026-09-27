import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/widgets/common/error_display.dart';
import 'package:flutter_work_time/presentation/widgets/common/loading_indicator.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: child,
    );
  }

  group('Common Widgets', () {
    testWidgets('LoadingIndicator shows CircularProgressIndicator',
        (tester) async {
      await tester.pumpWidget(wrap(const LoadingIndicator()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ErrorDisplay shows error message', (tester) async {
      const errorMessage = 'Test Error Message';
      await tester.pumpWidget(wrap(
        const Scaffold(body: ErrorDisplay(error: errorMessage)),
      ));

      expect(find.text(errorMessage), findsOneWidget);
      expect(find.text('Ein Fehler ist aufgetreten'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('ErrorDisplay shows retry button when onRetry is provided',
        (tester) async {
      bool retryCalled = false;
      await tester.pumpWidget(wrap(
        Scaffold(
          body: ErrorDisplay(
            error: 'Error',
            onRetry: () => retryCalled = true,
          ),
        ),
      ));

      final retryButton = find.text('Erneut versuchen');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      expect(retryCalled, true);
    });

    testWidgets('ErrorDisplay does not show retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Scaffold(body: ErrorDisplay(error: 'Error')),
      ));

      expect(find.text('Erneut versuchen'), findsNothing);
    });
    group('LoadingIndicator', () {
      // already tested above
    });
  });
}
