import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/repositories/review_prompt_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late ReviewPromptRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = ReviewPromptRepositoryImpl(prefs);
  });

  test('Erstnutzung wird nur einmal gespeichert', () async {
    expect(repo.getFirstUseDate(), isNull);
    await repo.saveFirstUseDateIfAbsent(DateTime(2026, 3, 4));
    await repo.saveFirstUseDateIfAbsent(DateTime(2027, 1, 1));
    expect(repo.getFirstUseDate(), DateTime(2026, 3, 4));
    expect(prefs.getString('first_use_date'), '2026-03-04');
  });

  test('ungültiges Datum wird wie "nicht erfasst" behandelt', () async {
    await prefs.setString('first_use_date', 'kaputt');
    expect(repo.getFirstUseDate(), isNull);
  });

  test('Flag review_prompt_shown wird persistiert', () async {
    expect(repo.wasPrompted(), isFalse);
    await repo.markPrompted();
    expect(repo.wasPrompted(), isTrue);
    expect(prefs.getBool('review_prompt_shown'), isTrue);
    expect(ReviewPromptRepositoryImpl(prefs).wasPrompted(), isTrue);
  });
}
