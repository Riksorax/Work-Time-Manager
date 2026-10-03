import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';

void main() {
  test('Default ist 30', () {
    expect(const SettingsEntity().vacationDaysPerYear, 30);
  });

  test('copyWith aendert nur vacationDaysPerYear', () {
    const base = SettingsEntity();
    final copy = base.copyWith(vacationDaysPerYear: 25);
    expect(copy.vacationDaysPerYear, 25);
    expect(copy, const SettingsEntity(vacationDaysPerYear: 25));
  });

  test('copyWithBundesland und copyWithTimezoneOverride erhalten Anspruch', () {
    const base = SettingsEntity(vacationDaysPerYear: 25);
    expect(base.copyWithBundesland(Bundesland.values.first).vacationDaysPerYear,
        25);
    expect(
        base.copyWithTimezoneOverride('Europe/Berlin').vacationDaysPerYear, 25);
  });

  test('props unterscheidet Anspruch', () {
    expect(const SettingsEntity(vacationDaysPerYear: 25),
        isNot(const SettingsEntity(vacationDaysPerYear: 30)));
  });
}
