import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';

import '../../support/reported_logs.dart';

void main() {
  group('isExpectedLoadFailure', () {
    test('Aufruf ohne angemeldeten Nutzer gilt als erwartet', () {
      expect(isExpectedLoadFailure(const NotSignedInException('getOvertime')),
          isTrue);
    });

    for (final entry in transientNetworkErrors.entries) {
      test('${entry.key} gilt als erwartet', () {
        expect(isExpectedLoadFailure(entry.value), isTrue);
      });
    }

    test('API-Fehler und andere Fehler gelten nicht als erwartet', () {
      expect(isExpectedLoadFailure(const ApiException('getOvertime', 500)),
          isFalse);
      expect(isExpectedLoadFailure(StateError('x')), isFalse);
    });
  });

  group('errorLabel', () {
    test('ApiException nennt den Status', () {
      expect(errorLabel(const ApiException('getOvertime', 401)),
          'ApiException(401)');
    });

    test('andere Fehler nennen nur den Typ', () {
      expect(errorLabel(StateError('geheim')), 'StateError');
    });
  });
}
