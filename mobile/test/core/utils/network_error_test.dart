import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/utils/network_error.dart';
import 'package:http/http.dart' as http;

void main() {
  group('isTransientNetworkError', () {
    test('SocketException und TimeoutException sind transient', () {
      expect(isTransientNetworkError(const SocketException('x')), isTrue);
      expect(isTransientNetworkError(TimeoutException('x')), isTrue);
    });

    test('ClientException mit SocketException in der Meldung ist transient',
        () {
      expect(
          isTransientNetworkError(http.ClientException(
              'SocketException: Software caused connection abort')),
          isTrue);
    });

    test('ClientException ohne SocketException ist nicht transient', () {
      expect(
          isTransientNetworkError(http.ClientException('HTTP 500')), isFalse);
    });

    test('sonstige Fehler sind nicht transient', () {
      expect(isTransientNetworkError(StateError('x')), isFalse);
      expect(isTransientNetworkError(Exception('SocketException')), isFalse);
    });
  });
}
