import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/app_info_page.dart';
import 'package:flutter_work_time/presentation/screens/login_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

Widget _app(Widget home, Locale locale) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: home,
      ),
    );

bool _isLogo(Widget w) =>
    w is Image &&
    w.image is AssetImage &&
    (w.image as AssetImage).assetName == 'assets/icon/app_logo_256.png';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'WTM',
      packageName: 'de.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  for (final locale in const [Locale('de'), Locale('en')]) {
    testWidgets(
        'LoginPage zeigt das neue Logo ohne Fehler (${locale.languageCode})',
        (tester) async {
      await tester.pumpWidget(_app(const LoginPage(), locale));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate(_isLogo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'AppInfoPage zeigt rundes Logo ohne Fehler (${locale.languageCode})',
        (tester) async {
      await tester.pumpWidget(_app(const AppInfoPage(), locale));
      await tester.pumpAndSettle();

      final logoBox = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).image != null)
          .single;
      final deco = logoBox.decoration as BoxDecoration;
      expect(
        (deco.image!.image as AssetImage).assetName,
        'assets/icon/app_logo_256.png',
      );
      expect(deco.shape, BoxShape.circle);
      expect(deco.borderRadius, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
