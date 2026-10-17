import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/presentation/widgets/common/sheet_insets.dart';

void main() {
  Future<double> measure(WidgetTester tester, MediaQueryData data) async {
    late double result;
    await tester.pumpWidget(MediaQuery(
      data: data,
      child: Builder(builder: (context) {
        result = bottomSheetBottomInset(context);
        return const SizedBox();
      }),
    ));
    return result;
  }

  testWidgets('ohne Insets 0', (tester) async {
    expect(await measure(tester, const MediaQueryData()), 0);
  });

  testWidgets('ohne Tastatur: Navigationsleiste', (tester) async {
    expect(
      await measure(
        tester,
        const MediaQueryData(
          padding: EdgeInsets.only(bottom: 34),
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
      ),
      34,
    );
  });

  testWidgets('mit Tastatur: Maximum statt Summe', (tester) async {
    expect(
      await measure(
        tester,
        const MediaQueryData(
          viewInsets: EdgeInsets.only(bottom: 300),
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
      ),
      300,
    );
  });
}
