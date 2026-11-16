import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/firebase_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/hybrid_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/local_overtime_repository_impl.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Genau der Fehler aus dem Gerätetest 1.9.0 im Flugmodus (#573).
final hostLookupError = http.ClientException(
    "SocketException: Failed host lookup: 'api.work-time-manager.app' "
    '(OS Error: No address associated with hostname, errno = 7)',
    Uri.parse('https://api.work-time-manager.app/api/overtime'));

/// Gleitzeit-Endpunkt des Servers je Nutzer und Profil (`uid|profil`).
/// [offline] wirft [hostLookupError], [failWith] einen beliebigen Fehler.
class OfflineOvertimeDataSource extends Fake implements FirestoreDataSource {
  final Map<String, int> minutes = {};
  bool offline = false;
  Object? failWith;
  int overtimeCalls = 0;

  void _check() {
    if (offline) throw hostLookupError;
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<Duration> getOvertime(String userId, {String? profileId}) async {
    overtimeCalls++;
    _check();
    return Duration(minutes: minutes['$userId|${profileId ?? 'default'}'] ?? 0);
  }

  @override
  Future<DateTime?> getLastOvertimeUpdate(String userId,
      {String? profileId}) async {
    _check();
    return null;
  }
}

/// Echte Hybrid-/Firebase-Repositories wie in `overtimeRepositoryProvider`,
/// mit dem Speicher für den zuletzt bekannten Saldo.
OvertimeRepository signedInOvertimeRepository(
        OfflineOvertimeDataSource ds, SharedPreferences prefs,
        {String uid = 'u1', String? profileId}) =>
    HybridOvertimeRepositoryImpl(
      firebaseRepository: FirebaseOvertimeRepositoryImpl(
          dataSource: ds, userId: uid, profileId: profileId, prefs: prefs),
      localRepository: LocalOvertimeRepositoryImpl(prefs),
      userId: uid,
    );

/// Merkt [minutes] als zuletzt bekannten Saldo (wie nach einem früheren
/// erfolgreichen Laden).
Future<void> rememberOvertime(SharedPreferences prefs, int minutes,
        {String uid = 'u1', String? profileId}) =>
    prefs.setInt(
        FirebaseOvertimeRepositoryImpl.minutesKeyFor(
            userId: uid, profileId: profileId),
        minutes);

/// Roboto und Material-Icons aus dem Flutter-SDK (wie
/// `reports_page_net_rows_test`), damit ein Überlauf sichtbar würde.
Future<void> loadMaterialFonts() async {
  final candidates = [
    File(Platform.resolvedExecutable).parent.parent.parent.path,
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts',
  ];
  Directory? dir;
  for (final c in candidates) {
    final d = Directory('$c/material_fonts');
    if (File('${d.path}/Roboto-Regular.ttf').existsSync()) dir = d;
  }
  if (dir == null) {
    throw StateError('material_fonts nicht gefunden (gesucht: $candidates)');
  }
  final roboto = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf'
  ]) {
    final bytes = File('${dir.path}/$f').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons');
  final bytes = File('${dir.path}/MaterialIcons-Regular.otf').readAsBytesSync();
  icons.addFont(Future.value(ByteData.view(bytes.buffer)));
  await icons.load();
}
