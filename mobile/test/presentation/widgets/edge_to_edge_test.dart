import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/presentation/widgets/common/edge_to_edge.dart';

/// Edge-to-Edge (#468): Icon-Helligkeit der Systemleisten folgt dem Theme,
/// Querformat-Insets (Cutout, 3-Tasten-Navigation) gelten zentral links/rechts.
void main() {
  Widget host({
    required ThemeData theme,
    required Widget child,
    MediaQueryData media = const MediaQueryData(),
  }) {
    return MaterialApp(
      theme: theme,
      builder: (context, _) => MediaQuery(data: media, child: child),
    );
  }

  group('enableEdgeToEdge', () {
    testWidgets('setzt SystemUiMode.edgeToEdge', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await enableEdgeToEdge();

      final call = calls.singleWhere(
          (c) => c.method == 'SystemChrome.setEnabledSystemUIMode');
      expect(call.arguments, 'SystemUiMode.edgeToEdge');
    });
  });

  group('SystemBarsStyle', () {
    testWidgets('Hell-Theme: dunkle Icons', (tester) async {
      await tester.pumpWidget(host(
        theme: AppTheme.lightTheme,
        child: const SystemBarsStyle(child: SizedBox()),
      ));
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
      expect(region.value.statusBarIconBrightness, Brightness.dark);
      expect(region.value.systemNavigationBarIconBrightness, Brightness.dark);
      expect(region.value.statusBarColor, isNull);
      expect(region.value.systemNavigationBarColor, isNull);
    });

    testWidgets('Dunkel-Theme: helle Icons', (tester) async {
      await tester.pumpWidget(host(
        theme: AppTheme.darkTheme,
        child: const SystemBarsStyle(child: SizedBox()),
      ));
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.systemNavigationBarIconBrightness, Brightness.light);
    });
  });

  group('HorizontalSafeInsets', () {
    const landscape = MediaQueryData(
      size: Size(800, 400),
      padding: EdgeInsets.only(left: 48, right: 48, top: 24, bottom: 20),
    );

    testWidgets('rueckt Inhalt um linken und rechten Inset ein',
        (tester) async {
      const key = Key('body');
      await tester.pumpWidget(host(
        theme: AppTheme.lightTheme,
        media: landscape,
        child: const HorizontalSafeInsets(child: SizedBox.expand(key: key)),
      ));
      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, 48);
      expect(rect.right, 800 - 48);
    });

    testWidgets('laesst oben und unten unberuehrt (Scaffold/Sheets regeln das)',
        (tester) async {
      late EdgeInsets inner;
      await tester.pumpWidget(host(
        theme: AppTheme.lightTheme,
        media: landscape,
        child: HorizontalSafeInsets(
          child: Builder(builder: (context) {
            inner = MediaQuery.paddingOf(context);
            return const SizedBox.expand();
          }),
        ),
      ));
      expect(inner.top, 24);
      expect(inner.bottom, 20);
      // Seitliche Insets sind verbraucht: kein doppeltes Einruecken.
      expect(inner.left, 0);
      expect(inner.right, 0);
    });
  });
}
