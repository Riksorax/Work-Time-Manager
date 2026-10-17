import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';

void main() {
  test('Hell-Theme: dunkle Systemleisten-Icons', () {
    final style = AppTheme.lightTheme.appBarTheme.systemOverlayStyle;
    expect(style, isNotNull);
    expect(style!.statusBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
  });

  test('Dunkel-Theme: helle Systemleisten-Icons', () {
    final style = AppTheme.darkTheme.appBarTheme.systemOverlayStyle;
    expect(style, isNotNull);
    expect(style!.statusBarIconBrightness, Brightness.light);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });

  test('keine veralteten Systemleistenfarben', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final style = theme.appBarTheme.systemOverlayStyle!;
      expect(style.statusBarColor, isNull);
      expect(style.systemNavigationBarColor, isNull);
    }
  });
}
