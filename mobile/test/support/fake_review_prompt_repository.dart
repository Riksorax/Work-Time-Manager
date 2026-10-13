import 'package:flutter_work_time/domain/repositories/review_prompt_repository.dart';

/// In-Memory-Ersatz für den Bewertungsanfrage-Zustand.
class FakeReviewPromptRepository implements ReviewPromptRepository {
  FakeReviewPromptRepository({this.firstUse, this.prompted = false});

  DateTime? firstUse;
  bool prompted;
  int markPromptedCalls = 0;

  @override
  DateTime? getFirstUseDate() => firstUse;

  @override
  Future<void> saveFirstUseDateIfAbsent(DateTime date) async {
    firstUse ??= date;
  }

  @override
  bool wasPrompted() => prompted;

  @override
  Future<void> markPrompted() async {
    markPromptedCalls++;
    prompted = true;
  }
}
