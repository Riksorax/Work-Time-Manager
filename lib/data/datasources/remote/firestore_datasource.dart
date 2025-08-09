import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/material.dart' show DateUtils;
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/work_entry_model.dart';

/// Die Schnittstelle (der Vertrag) für unsere Remote-Datenquelle.
/// Sie definiert, welche Firebase-Operationen möglich sein müssen.
abstract class FirestoreDataSource {
  // --- Authentifizierung ---
  /// Stream, der auf An- und Abmeldeereignisse von Firebase lauscht.
  Stream<firebase.User?> get authStateChanges;

  /// Startet den Google Sign-In Flow und meldet den Benutzer bei Firebase an.
  Future<void> signInWithGoogle();

  /// Meldet den Benutzer bei Firebase und Google ab.
  Future<void> signOut();

  // --- Arbeitseinträge ---
  /// Ruft einen einzelnen Arbeitseintrag für einen bestimmten Benutzer und ein bestimmtes Datum ab.
  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date);

  /// Speichert (erstellt oder überschreibt) einen Arbeitseintrag für einen Benutzer.
  Future<void> saveWorkEntry(String userId, WorkEntryModel model);

  /// Ruft alle Arbeitseinträge für einen bestimmten Monat ab.
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(
      String userId,
      int year,
      int month,
      );
}

/// Die konkrete Implementierung der FirestoreDataSource.
class FirestoreDataSourceImpl implements FirestoreDataSource {
  final firebase.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  /// Die Abhängigkeiten zu den Firebase-Diensten werden über den Konstruktor
  /// injiziert (Dependency Injection), was die Testbarkeit erleichtert.
  FirestoreDataSourceImpl(
      this._firebaseAuth,
      this._firestore,
      this._googleSignIn,
      );

  // --- Authentifizierungsimplementierung ---
  @override
  Stream<firebase.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<void> signInWithGoogle() async {
    try {
      // 1. Starte den Google Sign-In Dialog.
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();

      // Wenn der User den Dialog abbricht, ist googleUser null.
      if (googleUser == null) {
        return;
      }

      // 2. Hole die Authentifizierungsdetails.
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Erstelle ein Firebase-Credential mit den Google-Tokens.
      final firebase.AuthCredential credential =
      firebase.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 4. Melde dich mit dem Credential bei Firebase an.
      await _firebaseAuth.signInWithCredential(credential);

    } catch (e) {
      print("Fehler beim Google Sign-In: $e");
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    // Es ist wichtig, sich von beiden Diensten abzumelden.
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // --- Implementierung für Arbeitseinträge ---
  /// Hilfsmethode, um den Pfad zu einem Dokument eines Arbeitseintrags zu erhalten.
  DocumentReference<Map<String, dynamic>> _getWorkEntryDocRef(
      String userId,
      String docId,
      ) {
    return _firestore.collection('users').doc(userId).collection('work_entries').doc(docId);
  }

  @override
  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date) async {
    // Generiere die konsistente Dokumenten-ID für das Datum.
    final docId = WorkEntryModel.generateId(date);
    final docRef = _getWorkEntryDocRef(userId, docId);

    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null) {
      // Wenn das Dokument existiert, erstelle ein Model daraus.
      return WorkEntryModel.fromFirestore(snapshot);
    } else {
      // Wenn kein Dokument für diesen Tag existiert, wird null zurückgegeben.
      // Das Repository ist dafür verantwortlich, daraus ein leeres Objekt zu machen.
      return null;
    }
  }

  @override
  Future<void> saveWorkEntry(String userId, WorkEntryModel model) async {
    final docRef = _getWorkEntryDocRef(userId, model.id);
    // set erstellt das Dokument, wenn es nicht existiert, oder überschreibt es komplett,
    // was genau dem Verhalten von "Speichern" entspricht.
    await docRef.set(model.toFirestore());
  }

  @override
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(
      String userId,
      int year,
      int month,
      ) async {
    // Definiere den Datumsbereich für die Abfrage.
    final startOfMonth = DateTime.utc(year, month, 1);
    // Der letzte Tag des Monats.
    final endOfMonth = DateTime.utc(year, month + 1, 0, 23, 59, 59);

    final collectionRef = _firestore.collection('users').doc(userId).collection('work_entries');

    // Führe die Abfrage aus.
    final querySnapshot = await collectionRef
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThanOrEqualTo: endOfMonth)
        .get();

    // Wandle die resultierenden Dokumente in eine Liste von Models um.
    return querySnapshot.docs.map((doc) => WorkEntryModel.fromFirestore(doc)).toList();
  }
}
