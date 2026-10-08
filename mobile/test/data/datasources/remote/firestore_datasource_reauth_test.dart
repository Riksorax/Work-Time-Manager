import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'firestore_datasource_reauth_test.mocks.dart';

@GenerateMocks([FirebaseAuth, User, FirebaseFirestore, GoogleSignIn, UserInfo])
void main() {
  late MockFirebaseAuth auth;
  late MockGoogleSignIn google;
  late FirestoreDataSourceImpl ds;

  setUp(() {
    auth = MockFirebaseAuth();
    google = MockGoogleSignIn();
    ds = FirestoreDataSourceImpl(auth, MockFirebaseFirestore(), google);
  });

  test('kein currentUser -> false', () async {
    when(auth.currentUser).thenReturn(null);
    expect(await ds.reauthenticate(), isFalse);
    verifyZeroInteractions(google);
  });

  test('User ohne google.com-Provider -> false, ohne GoogleSignIn', () async {
    final user = MockUser();
    final info = MockUserInfo();
    when(info.providerId).thenReturn('password');
    when(user.providerData).thenReturn([info]);
    when(auth.currentUser).thenReturn(user);
    expect(await ds.reauthenticate(), isFalse);
    verifyZeroInteractions(google);
  });
}
