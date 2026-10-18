import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/logger.dart';

/// Verwaltet den nativen Google-Play-In-App-Review-Flow zur Steigerung
/// organischer Store-Bewertungen (ASO / Play-Store-Ranking).
///
/// Zählt abgeschlossene Arbeitstage (maximal einmal pro Kalendertag) und
/// fragt nach Erreichen von [completedDaysThreshold] einmalig über die
/// native Play-Core-Review-API nach einer Bewertung, ohne dass der Nutzer
/// die App verlassen muss.
class AppReviewService {
  static const _completedDaysCountKey = 'app_review_completed_days_count';
  static const _lastCountedDateKey = 'app_review_last_counted_date';
  static const _reviewPromptShownKey = 'app_review_prompt_shown';

  static const int defaultCompletedDaysThreshold = 5;
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=app.work_time_manager';

  final SharedPreferences _prefs;
  final int completedDaysThreshold;
  final Future<bool> Function() _isAvailable;
  final Future<void> Function() _requestReview;
  final Future<void> Function() _openStoreListing;

  AppReviewService({
    required SharedPreferences prefs,
    this.completedDaysThreshold = defaultCompletedDaysThreshold,
    Future<bool> Function()? isAvailable,
    Future<void> Function()? requestReview,
    Future<void> Function()? openStoreListing,
  })  : _prefs = prefs,
        _isAvailable = isAvailable ?? _defaultIsAvailable,
        _requestReview = requestReview ?? _defaultRequestReview,
        _openStoreListing = openStoreListing ?? _defaultOpenStoreListing;

  static Future<bool> _defaultIsAvailable() async {
    if (kIsWeb) return false;
    return InAppReview.instance.isAvailable();
  }

  static Future<void> _defaultRequestReview() async {
    if (kIsWeb) return;
    await InAppReview.instance.requestReview();
  }

  static Future<void> _defaultOpenStoreListing() async {
    if (!kIsWeb) {
      try {
        await InAppReview.instance.openStoreListing();
        return;
      } catch (e) {
        logger.w('[AppReview] Nativer Store-Aufruf fehlgeschlagen: $e');
      }
    }
    final uri = Uri.parse(playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  int get completedDaysCount => _prefs.getInt(_completedDaysCountKey) ?? 0;

  bool get hasShownReviewPrompt =>
      _prefs.getBool(_reviewPromptShownKey) ?? false;

  String? get lastCountedDate => _prefs.getString(_lastCountedDateKey);

  /// Registriert einen abgeschlossenen Arbeitstag für [date] und löst bei
  /// Erreichen des Schwellwerts einmalig den nativen In-App-Review-Dialog aus.
  ///
  /// Gibt `true` zurück, wenn der Review-Dialog angefordert wurde.
  Future<bool> recordCompletedWorkDayAndMaybeRequestReview(
      DateTime date) async {
    try {
      final dateKey = _formatDateKey(date);
      var count = completedDaysCount;

      if (lastCountedDate != dateKey) {
        count += 1;
        await _prefs.setInt(_completedDaysCountKey, count);
        await _prefs.setString(_lastCountedDateKey, dateKey);
      }

      if (hasShownReviewPrompt || count < completedDaysThreshold) {
        return false;
      }

      if (!await _isAvailable()) {
        return false;
      }

      await _prefs.setBool(_reviewPromptShownKey, true);
      await _requestReview();
      logger.i(
          '[AppReview] In-App-Review nach $count abgeschlossenen Arbeitstagen angefordert');
      return true;
    } catch (e) {
      logger.w('[AppReview] Prüfung für In-App-Review fehlgeschlagen: $e');
      return false;
    }
  }

  /// Öffnet direkt den Play-Store-Eintrag (z. B. über „App bewerten" in der
  /// App-Info-Seite).
  Future<void> openStoreListing() async {
    try {
      await _openStoreListing();
    } catch (e) {
      logger.w('[AppReview] Konnte Store-Eintrag nicht öffnen: $e');
    }
  }

  static String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
