import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:mockito/mockito.dart';

import 'firestore_datasource_reauth_test.mocks.dart';

/// Konto-Löschung (#511): Nach `user.delete()` ist niemand mehr angemeldet,
/// jeder Firestore-Zugriff scheitert an den Security Rules. Die Daten räumt
/// der Server ab (Cloud Function `onUserDeleted`).
void main() {
  late MockFirebaseAuth auth;
  late MockFirebaseFirestore firestore;
  late MockGoogleSignIn google;
  late MockUser user;
  late FirestoreDataSourceImpl ds;

  setUp(() {
    auth = MockFirebaseAuth();
    firestore = MockFirebaseFirestore();
    google = MockGoogleSignIn();
    user = MockUser();
    ds = FirestoreDataSourceImpl(auth, firestore, google);
    when(auth.currentUser).thenReturn(user);
    when(user.delete()).thenAnswer((_) async {});
    when(google.signOut()).thenAnswer((_) async {});
  });

  test('kein currentUser -> nichts passiert', () async {
    when(auth.currentUser).thenReturn(null);
    await ds.deleteAccount();
    verifyZeroInteractions(firestore);
    verifyZeroInteractions(google);
  });

  test('löscht den Auth-User und greift danach nicht mehr auf Firestore zu',
      () async {
    await ds.deleteAccount();
    verify(user.delete()).called(1);
    verifyZeroInteractions(firestore);
    verify(google.signOut()).called(1);
  });

  test('Fehler bei der Google-Abmeldung wird nicht weitergeworfen', () async {
    when(google.signOut()).thenThrow(StateError('signOut'));
    await expectLater(ds.deleteAccount(), completes);
    verify(user.delete()).called(1);
  });

  test('Fehler beim Löschen des Auth-Users wird weitergeworfen', () async {
    when(user.delete()).thenThrow(StateError('delete'));
    await expectLater(ds.deleteAccount(), throwsStateError);
    verifyZeroInteractions(firestore);
    verifyNever(google.signOut());
  });
}
