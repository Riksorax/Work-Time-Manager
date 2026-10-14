import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/version_service.dart';
import 'package:in_app_update/in_app_update.dart';

void main() {
  group('completeFlexibleUpdateWhenDownloaded', () {
    late StreamController<InstallStatus> status;
    late int completeCalls;

    setUp(() {
      status = StreamController<InstallStatus>.broadcast();
      completeCalls = 0;
      VersionService.completeFlexibleUpdateWhenDownloaded(
        status.stream,
        () async => completeCalls++,
      );
    });

    tearDown(() => status.close());

    Future<void> emit(InstallStatus s) async {
      status.add(s);
      await Future<void>.delayed(Duration.zero);
    }

    test('installiert erst nach dem Download, genau einmal', () async {
      await emit(InstallStatus.pending);
      await emit(InstallStatus.downloading);
      expect(completeCalls, 0);

      await emit(InstallStatus.downloaded);
      await emit(InstallStatus.downloaded);
      expect(completeCalls, 1);
    });

    for (final end in [
      InstallStatus.failed,
      InstallStatus.canceled,
      InstallStatus.installed,
    ]) {
      test('beendet bei $end ohne Installation', () async {
        await emit(end);
        await emit(InstallStatus.downloaded);
        expect(completeCalls, 0);
      });
    }

    test('Fehler bei der Installation bleibt abgefangen', () async {
      final failing = StreamController<InstallStatus>.broadcast();
      VersionService.completeFlexibleUpdateWhenDownloaded(
        failing.stream,
        () async => throw StateError('boom'),
      );
      failing.add(InstallStatus.downloaded);
      await Future<void>.delayed(Duration.zero);
      await failing.close();
    });
  });
}
