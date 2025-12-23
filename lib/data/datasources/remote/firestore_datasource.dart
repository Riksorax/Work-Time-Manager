import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../models/work_entry_model.dart';

abstract class FirestoreDataSource {
  Stream<firebase.User?> get authStateChanges;
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> deleteAccount();

  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date);
  Future<void> saveWorkEntry(String userId, WorkEntryModel model);
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(String userId, int year, int month);
  Future<void> deleteWorkEntry(String userId, String entryId);
}

class FirestoreDataSourceImpl implements FirestoreDataSource {
  final firebase.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  FirestoreDataSourceImpl(this._firebaseAuth, this._firestore, this._googleSignIn);

  @override
  Stream<firebase.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Auf Web: Verwende Firebase signInWithPopup direkt
        // Dies ist die empfohlene Methode für Web und benötigt kein google_sign_in Package
        await _firebaseAuth.signInWithPopup(firebase.GoogleAuthProvider());
      } else {
        // Auf Mobile: Verwende google_sign_in mit authenticate()
        final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate(
          scopeHint: ['email', 'profile'],
        );

        if (googleUser == null) {
          logger.w("Google Sign-In wurde abgebrochen");
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final firebase.AuthCredential credential = firebase.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        await _firebaseAuth.signInWithCredential(credential);
      }
    } on GoogleSignInException catch (e) {
      logger.e("Google Sign-In Exception: code=${e.code.name}, description=${e.description}");
      rethrow;
    } on firebase.FirebaseAuthException catch (e) {
      logger.e("Firebase Auth Exception: code=${e.code}, message=${e.message}");
      rethrow;
    } catch (e) {
      logger.e("Fehler beim Google Sign-In: $e");
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    final userId = user.uid;
    try {
      await user.delete();
    } on firebase.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Re-Auth - plattformspezifisch
        if (kIsWeb) {
          // Auf Web: Verwende Firebase signInWithPopup für Re-Auth
          final userCredential = await _firebaseAuth.signInWithPopup(firebase.GoogleAuthProvider());
          await userCredential.user?.delete();
        } else {
          // Auf Mobile: authenticate()
          final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate(
            scopeHint: ['email', 'profile'],
          );
          if (googleUser == null) {
            logger.w("Re-Authentifizierung wurde abgebrochen");
            return;
          }

          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final firebase.AuthCredential credential = firebase.GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
          );

          await user.reauthenticateWithCredential(credential);
          await user.delete();
        }
      } else {
        logger.e("Fehler beim Löschen des Accounts: $e");
        rethrow;
      }
    } on GoogleSignInException catch (e) {
      logger.e("Google Sign-In Exception beim Löschen: code=${e.code.name}, description=${e.description}");
      rethrow;
    } catch (e) {
      logger.e("Unerwarteter Fehler beim Löschen des Accounts: $e");
      rethrow;
    }
    
    // Cleanup Firestore
    try {
      final workEntriesCollection = _firestore.collection('users').doc(userId).collection('work_entries');
      final workEntriesSnapshot = await workEntriesCollection.get();
      final batch = _firestore.batch();
      for (final doc in workEntriesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      logger.e("KRITISCH: Fehler beim Löschen der Firestore-Daten nach Account-Löschung: $e");
      rethrow;
    }
    
    await _googleSignIn.signOut();
  }

  String _getMonthDocId(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  DocumentReference<Map<String, dynamic>> _getMonthDocRef(String userId, DateTime date) {
    final monthId = _getMonthDocId(date);
    return _firestore.collection('users').doc(userId).collection('work_entries').doc(monthId);
  }

  @override
  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date) async {
    logger.i('[Firestore] Lade WorkEntry für User: $userId, Datum: $date');
    final docRef = _getMonthDocRef(userId, date);
    final snapshot = await docRef.get();
    final dayKey = date.day.toString();
    
    if (snapshot.exists && snapshot.data() != null) {
      final monthData = snapshot.data()!;
      final dayData = monthData['days']?[dayKey];
      
      if (dayData != null) {
        final entry = WorkEntryModel.fromMap(dayData).copyWith(id: WorkEntryModel.generateId(date));
        return entry;
      }
    }
    return null;
  }

  @override
  Future<void> saveWorkEntry(String userId, WorkEntryModel model) async {
    logger.i('[Firestore] Speichere WorkEntry für User: $userId, Datum: ${model.date}');
    final docRef = _getMonthDocRef(userId, model.date);
    final dayKey = model.date.day.toString();
    final data = { 'days': { dayKey: model.toMap() } };
    
    try {
      await docRef.set(data, SetOptions(merge: true));
    } catch (e) {
      logger.e('[Firestore] FEHLER beim Speichern: $e');
      rethrow;
    }
  }

  @override
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(String userId, int year, int month) async {
    final date = DateTime(year, month);
    final docRef = _getMonthDocRef(userId, date);
    final snapshot = await docRef.get();
    if (snapshot.exists && snapshot.data() != null) {
      final monthData = snapshot.data()!;
      final daysMap = monthData['days'] as Map<String, dynamic>? ?? {};
      return daysMap.entries.map((entry) {
        try {
          final dayData = entry.value as Map<String, dynamic>;
          final entryDate = DateTime(year, month, int.parse(entry.key));
          return WorkEntryModel.fromMap(dayData).copyWith(id: WorkEntryModel.generateId(entryDate));
        } catch (e) {
          logger.w('[Firestore] Fehler beim Parsen eines Eintrags (Tag ${entry.key}): $e');
          return null;
        }
      }).where((element) => element != null).cast<WorkEntryModel>().toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }
    return [];
  }

  @override
  Future<void> deleteWorkEntry(String userId, String entryId) async {
    final date = WorkEntryModel.parseId(entryId);
    final docRef = _getMonthDocRef(userId, date);
    final dayKey = date.day.toString();
    await docRef.update({ 'days.$dayKey': FieldValue.delete() });
  }
}
