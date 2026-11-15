import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_work_time/data/repositories/settings_repository_impl.dart';

import 'settings_repository_impl_test.mocks.dart';

// Dashboard-Anzeige (#526): showWorkLocationOnDashboard (Standard aus) und
// showHomeOfficeOnDashboard (Standard an), je Nutzer und Profil, angemeldet
// mit dem Server synchronisiert (Muster vacationDaysPerYear).
void main() {
  late MockFirestoreDataSource mockDs;

  setUp(() {
    mockDs = MockFirestoreDataSource();
    when(mockDs.saveSettings(any, any, profileId: anyNamed('profileId')))
        .thenAnswer((_) async {});
  });

  Future<SettingsRepositoryImpl> repo(
      {String uid = 'u1',
      String? profile,
      Map<String, Object> initial = const {}}) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return SettingsRepositoryImpl(prefs, mockDs, uid, profile);
  }

  test('Standardwerte: Orte aus, Home-Office an', () async {
    final r = await repo();
    expect(r.getShowWorkLocationOnDashboard(), isFalse);
    expect(r.getShowHomeOfficeOnDashboard(), isTrue);
  });

  test('Fremdtyp unter dem Key: Standardwert', () async {
    final r = await repo(initial: {
      'show_work_location_on_dashboard_u1': 'ja',
      'show_home_office_on_dashboard_u1': 3,
    });
    expect(r.getShowWorkLocationOnDashboard(), isFalse);
    expect(r.getShowHomeOfficeOnDashboard(), isTrue);
  });

  test('Setter schreiben profilspezifisch und synchronisieren', () async {
    final r = await repo(profile: 'p1');
    await r.setShowWorkLocationOnDashboard(true);
    await r.setShowHomeOfficeOnDashboard(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('show_work_location_on_dashboard_u1_p1'), isTrue);
    expect(prefs.getBool('show_home_office_on_dashboard_u1_p1'), isFalse);
    expect(r.getShowWorkLocationOnDashboard(), isTrue);
    expect(r.getShowHomeOfficeOnDashboard(), isFalse);
    verify(mockDs.saveSettings('u1', {'showWorkLocationOnDashboard': true},
            profileId: 'p1'))
        .called(1);
    verify(mockDs.saveSettings('u1', {'showHomeOfficeOnDashboard': false},
            profileId: 'p1'))
        .called(1);

    // Standard-Profil bleibt unberührt.
    final def = SettingsRepositoryImpl(prefs, mockDs, 'u1');
    expect(def.getShowWorkLocationOnDashboard(), isFalse);
    expect(def.getShowHomeOfficeOnDashboard(), isTrue);
  });

  test('Gast: nur lokal, kein Server-Aufruf', () async {
    final r = await repo(uid: 'local');
    await r.setShowWorkLocationOnDashboard(true);
    await r.setShowHomeOfficeOnDashboard(false);
    expect(r.getShowWorkLocationOnDashboard(), isTrue);
    expect(r.getShowHomeOfficeOnDashboard(), isFalse);
    verifyNever(
        mockDs.saveSettings(any, any, profileId: anyNamed('profileId')));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('show_work_location_on_dashboard_local'), isTrue);
  });

  group('syncFromFirestore', () {
    test('übernimmt beide Werte und meldet eine Änderung', () async {
      final r = await repo();
      when(mockDs.getSettings('u1', profileId: anyNamed('profileId')))
          .thenAnswer((_) async => {
                'showWorkLocationOnDashboard': true,
                'showHomeOfficeOnDashboard': false,
              });
      expect(await r.syncFromFirestore(), isTrue);
      expect(r.getShowWorkLocationOnDashboard(), isTrue);
      expect(r.getShowHomeOfficeOnDashboard(), isFalse);
    });

    test('gleiche Werte: keine Änderung gemeldet', () async {
      final r = await repo();
      when(mockDs.getSettings('u1', profileId: anyNamed('profileId')))
          .thenAnswer((_) async => {
                'showWorkLocationOnDashboard': false,
                'showHomeOfficeOnDashboard': true,
              });
      expect(await r.syncFromFirestore(), isFalse);
    });

    test('fehlende Felder/Fremdtypen lassen lokale Werte stehen', () async {
      final r = await repo(initial: {
        'show_work_location_on_dashboard_u1': true,
        'show_home_office_on_dashboard_u1': false,
      });
      when(mockDs.getSettings('u1', profileId: anyNamed('profileId')))
          .thenAnswer((_) async => {'showWorkLocationOnDashboard': 'x'});
      expect(await r.syncFromFirestore(), isFalse);
      expect(r.getShowWorkLocationOnDashboard(), isTrue);
      expect(r.getShowHomeOfficeOnDashboard(), isFalse);
    });
  });
}
