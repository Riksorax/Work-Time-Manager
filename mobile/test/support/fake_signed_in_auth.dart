import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_test/flutter_test.dart';

/// Angemeldeter Nutzer für Tests des `ApiClient`: `_headers()` braucht nur
/// `currentUser` und dessen ID-Token.
class FakeSignedInUser extends Fake implements firebase.User {
  FakeSignedInUser({this.tokenError});

  /// Fehler, den der Token-Abruf wirft (z. B. Abmeldung während des Abrufs).
  final Object? tokenError;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (tokenError != null) throw tokenError!;
    return 'test-token';
  }
}

/// `FirebaseAuth` mit angemeldetem Nutzer; mit `signedIn: false` ohne.
class FakeSignedInAuth extends Fake implements firebase.FirebaseAuth {
  FakeSignedInAuth({this.signedIn = true});

  bool signedIn;

  /// Fehler, den der Token-Abruf des angemeldeten Nutzers wirft.
  Object? tokenError;

  @override
  firebase.User? get currentUser =>
      signedIn ? FakeSignedInUser(tokenError: tokenError) : null;
}
