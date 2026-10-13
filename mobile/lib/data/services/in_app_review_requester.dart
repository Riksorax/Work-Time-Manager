import 'package:flutter/foundation.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../domain/services/review_requester.dart';

/// [ReviewRequester] über die Google-Play-In-App-Review-API (`in_app_review`).
/// Nur auf Android aktiv; auf iOS/Web und bei jedem Plugin-Fehler passiert
/// nichts (kein Fallback-Popup).
class InAppReviewRequester implements ReviewRequester {
  final InAppReview _inAppReview;
  final bool Function() _isAndroid;

  InAppReviewRequester({
    InAppReview? inAppReview,
    bool Function()? isAndroid,
  })  : _inAppReview = inAppReview ?? InAppReview.instance,
        _isAndroid = isAndroid ??
            (() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<bool> isAvailable() async {
    if (!_isAndroid()) return false;
    try {
      return await _inAppReview.isAvailable();
    } catch (e) {
      logger.w('[Review] Verfügbarkeit nicht prüfbar (${e.runtimeType})');
      return false;
    }
  }

  @override
  Future<void> requestReview() async {
    if (!_isAndroid()) return;
    try {
      await _inAppReview.requestReview();
    } catch (e) {
      logger.w('[Review] Anfrage fehlgeschlagen (${e.runtimeType})');
    }
  }
}
