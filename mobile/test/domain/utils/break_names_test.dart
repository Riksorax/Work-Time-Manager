import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/break_names.dart';

void main() {
  group('parseDefaultBreakName', () {
    test('erkennt die Standardnamen aller Plattformen', () {
      expect(parseDefaultBreakName('Pause')!.kind, DefaultBreakNameKind.plain);
      expect(parseDefaultBreakName('Automatische Pause')!.kind,
          DefaultBreakNameKind.automatic);
      expect(parseDefaultBreakName('Mittagspause')!.kind,
          DefaultBreakNameKind.lunch);
      expect(
          parseDefaultBreakName('Kurzpause')!.kind, DefaultBreakNameKind.short);
    });

    test('erkennt nummerierte Namen mit und ohne Raute', () {
      final plain = parseDefaultBreakName('Pause 2')!;
      final hash = parseDefaultBreakName('Pause #13')!;

      expect(plain.kind, DefaultBreakNameKind.numbered);
      expect(plain.number, 2);
      expect(hash.kind, DefaultBreakNameKind.numbered);
      expect(hash.number, 13);
    });

    test('lässt frei vergebene Namen unberührt', () {
      expect(parseDefaultBreakName('Kaffee'), isNull);
      expect(parseDefaultBreakName('Laufende Pause'), isNull);
      expect(parseDefaultBreakName('Pause mit Kollegen'), isNull);
      expect(parseDefaultBreakName('Pause 2 lang'), isNull);
      expect(parseDefaultBreakName('pause'), isNull);
      expect(parseDefaultBreakName(''), isNull);
    });
  });
}
