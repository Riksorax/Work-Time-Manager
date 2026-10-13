import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/services/in_app_review_requester.dart';
import 'package:in_app_review/in_app_review.dart';

class _FakeInAppReview extends Fake implements InAppReview {
  bool available = true;
  bool throws = false;
  int requestCalls = 0;
  int availableCalls = 0;

  @override
  Future<bool> isAvailable() async {
    availableCalls++;
    if (throws) throw Exception('play services');
    return available;
  }

  @override
  Future<void> requestReview() async {
    requestCalls++;
    if (throws) throw Exception('play services');
  }
}

void main() {
  late _FakeInAppReview plugin;

  setUp(() => plugin = _FakeInAppReview());

  InAppReviewRequester requester({required bool android}) =>
      InAppReviewRequester(inAppReview: plugin, isAndroid: () => android);

  test('Android: verfügbar und Anfrage geht ans Plugin', () async {
    final r = requester(android: true);
    expect(await r.isAvailable(), isTrue);
    await r.requestReview();
    expect(plugin.requestCalls, 1);
  });

  test('nicht Android: nie verfügbar, Plugin unberührt', () async {
    final r = requester(android: false);
    expect(await r.isAvailable(), isFalse);
    await r.requestReview();
    expect(plugin.availableCalls, 0);
    expect(plugin.requestCalls, 0);
  });

  test('Plugin nicht verfügbar -> false', () async {
    plugin.available = false;
    expect(await requester(android: true).isAvailable(), isFalse);
  });

  test('Plugin-Fehler wird geschluckt', () async {
    plugin.throws = true;
    final r = requester(android: true);
    expect(await r.isAvailable(), isFalse);
    await r.requestReview();
  });
}
