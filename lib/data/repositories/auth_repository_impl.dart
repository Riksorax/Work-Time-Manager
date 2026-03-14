import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/firestore_datasource.dart';

/// Die konkrete Implementierung des AuthRepository-Vertrags.
class AuthRepositoryImpl implements AuthRepository {
  final FirestoreDataSource _dataSource;

  // Die Abhängigkeit (DataSource) wird über den Konstruktor injiziert.
  AuthRepositoryImpl(this._dataSource);

  /// Implementiert den Stream, der auf An- und Abmeldeereignisse lauscht.
  static const _rcAndroidKey = String.fromEnvironment('RC_ANDROID_KEY');
  static const _rcIosKey = String.fromEnvironment('RC_IOS_KEY');
  static bool get _isRcInitialized =>
      !kIsWeb && (_rcAndroidKey.isNotEmpty || _rcIosKey.isNotEmpty);

  @override
  Stream<UserEntity?> get authStateChanges {
    return _dataSource.authStateChanges.asyncMap((firebaseUser) async {
      // RevenueCat Synchronisation (nur Mobile, nur wenn RC initialisiert)
      if (_isRcInitialized) {
        if (firebaseUser != null) {
          try {
            await Purchases.logIn(firebaseUser.uid);
          } catch (_) {
            // Fehler ignorieren – kein gültiger Key oder Netzwerkproblem
          }
        } else {
          try {
            await Purchases.logOut();
          } catch (_) {
            // Wird geworfen wenn der RC-User anonym ist – sicher ignorieren
          }
        }
      }

      return firebaseUser != null
          ? _mapFirebaseUserToEntity(firebaseUser)
          : null;
    });
  }

  /// Startet den Anmeldevorgang, indem die entsprechende Methode der Datenquelle aufgerufen wird.
  @override
  Future<void> signInWithGoogle() async {
    await _dataSource.signInWithGoogle();
  }

  /// Meldet den Benutzer ab, indem die entsprechende Methode der Datenquelle aufgerufen wird.
  @override
  Future<void> signOut() async {
    await _dataSource.signOut();
  }

  /// Löscht den Account des Benutzers, indem die entsprechende Methode der Datenquelle aufgerufen wird.
  @override
  Future<void> deleteAccount() async {
    await _dataSource.deleteAccount();
  }

  /// Eine private Hilfsmethode, um das Mapping an einer zentralen Stelle zu halten.
  UserEntity _mapFirebaseUserToEntity(firebase.User firebaseUser) {
    return UserEntity(
      id: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
    );
  }
}