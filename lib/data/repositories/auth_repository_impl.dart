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
  @override
  Stream<UserEntity?> get authStateChanges {
    // Rufe den Stream der Datenquelle ab, der Firebase-Benutzerobjekte liefert.
    return _dataSource.authStateChanges.map((firebaseUser) {
      
      // RevenueCat Synchronisation (nur Mobile)
      if (!kIsWeb) {
        if (firebaseUser != null) {
          // User hat sich eingeloggt oder App wurde mit eingeloggtem User gestartet
          Purchases.logIn(firebaseUser.uid);
        } else {
          // User hat sich ausgeloggt
          Purchases.logOut();
        }
      }

      // Wandle das Firebase-Benutzerobjekt in unsere eigene UserEntity um.
      // Wenn der Firebase-Benutzer null ist (abgemeldet), gib auch null zurück.
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