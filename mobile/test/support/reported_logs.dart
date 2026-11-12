import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Vorübergehende Netzwerkfehler (#506), wie sie `package:http` bzw. dart:io
/// beim Verbindungsabbruch liefern.
final transientNetworkErrors = <String, Object>{
  'SocketException': const SocketException('Software caused connection abort',
      osError: OSError('Software caused connection abort', 103)),
  'ClientException(SocketException)': http.ClientException(
      'SocketException: Software caused connection abort (OS Error: '
      'Software caused connection abort, errno = 103)'),
  'TimeoutException': TimeoutException('Zeitüberschreitung'),
};

/// Zeichnet Logger-Ereignisse auf. Ab `Level.warning` meldet der Logger an
/// Crashlytics (`lib/core/utils/logger.dart`), `reported` liefert genau diese.
void captureLogs(List<LogEvent> events) {
  void listener(LogEvent e) => events.add(e);
  setUp(() {
    events.clear();
    Logger.addLogListener(listener);
  });
  tearDown(() => Logger.removeLogListener(listener));
}

/// Ereignisse ab `Level.warning`, deren Meldung [tag] enthält.
Iterable<LogEvent> reported(List<LogEvent> events, String tag) =>
    events.where((e) =>
        e.level.index >= Level.warning.index &&
        e.message.toString().contains(tag));
