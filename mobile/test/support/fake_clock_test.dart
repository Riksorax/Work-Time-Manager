import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_clock.dart';

void main() {
  test('FakeClock läuft mit fakeAsync mit und jumpTo setzt Offset', () {
    fakeAsync((async) {
      final clock = FakeClock(DateTime(2026, 10, 2, 23, 59, 30))..bind(async);
      expect(clock(), DateTime(2026, 10, 2, 23, 59, 30));
      async.elapse(const Duration(seconds: 31));
      expect(clock(), DateTime(2026, 10, 3, 0, 0, 1));
      clock.jumpTo(DateTime(2026, 10, 3, 9));
      expect(clock(), DateTime(2026, 10, 3, 9));
      async.elapse(const Duration(minutes: 1));
      expect(clock(), DateTime(2026, 10, 3, 9, 1));
    });
  });
}
