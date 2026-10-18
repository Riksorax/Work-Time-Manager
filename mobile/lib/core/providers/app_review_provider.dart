import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_review_service.dart';
import 'providers.dart';

final appReviewServiceProvider = Provider<AppReviewService>((ref) {
  return AppReviewService(
    prefs: ref.watch(sharedPreferencesProvider),
  );
});
