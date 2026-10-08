import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/leave_balance_utils.dart';

void main() {
  WorkEntryEntity entry(DateTime date, WorkEntryType type) =>
      WorkEntryEntity(id: date.toIso8601String(), date: date, type: type);

  test('Konstanten', () {
    expect(defaultVacationDaysPerYear, 30);
    expect(maxVacationDaysPerYear, 366);
  });

  test('zaehlt vacation und sick, ignoriert holiday und work', () {
    final result = calculateLeaveBalance([
      entry(DateTime(2026, 3, 2), WorkEntryType.vacation),
      entry(DateTime(2026, 3, 3), WorkEntryType.vacation),
      entry(DateTime(2026, 3, 4), WorkEntryType.sick),
      entry(DateTime(2026, 3, 5), WorkEntryType.holiday),
      entry(DateTime(2026, 3, 6), WorkEntryType.work),
    ], 2026, 30);

    expect(result.year, 2026);
    expect(result.entitlement, 30);
    expect(result.taken, 2);
    expect(result.remaining, 28);
    expect(result.sickDays, 1);
  });

  test('Jahreswechsel: nur Eintraege des gewuenschten Jahres', () {
    final entries = [
      entry(DateTime(2025, 12, 31), WorkEntryType.vacation),
      entry(DateTime(2026, 1, 1), WorkEntryType.vacation),
      entry(DateTime(2026, 12, 31), WorkEntryType.sick),
      entry(DateTime(2027, 1, 1), WorkEntryType.sick),
    ];
    final y2026 = calculateLeaveBalance(entries, 2026, 30);
    expect(y2026.taken, 1);
    expect(y2026.sickDays, 1);
    final y2025 = calculateLeaveBalance(entries, 2025, 30);
    expect(y2025.taken, 1);
    expect(y2025.sickDays, 0);
  });

  test('Samstag zaehlt als Urlaubstag', () {
    final result = calculateLeaveBalance(
        [entry(DateTime(2026, 6, 6), WorkEntryType.vacation)], 2026, 30);
    expect(result.taken, 1);
  });

  test('Ueberschreitung wird nicht geklemmt', () {
    final entries = List.generate(
        5, (i) => entry(DateTime(2026, 4, 1 + i), WorkEntryType.vacation));
    expect(calculateLeaveBalance(entries, 2026, 3).remaining, -2);
  });

  test('leer', () {
    final zero = calculateLeaveBalance(const [], 2026, 0);
    expect((zero.entitlement, zero.taken, zero.remaining, zero.sickDays),
        (0, 0, 0, 0));
    expect(calculateLeaveBalance(const [], 2026, 30).remaining, 30);
  });
}
