import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/material.dart' show DateUtils;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../models/work_entry_model.dart';

/// Die Schnittstelle (der Vertrag) für unsere Remote-Datenquelle.
/// Sie definiert, welche Firebase-Operationen möglich sein müssen.
abstract class FirestoreDataSource {
  // --- Authentifizierung ---
  Stream<firebase.User?> get authStateChanges;
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> deleteAccount();

  // --- Arbeitseinträge ---
  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date);
  Future<void> saveWorkEntry(String userId, WorkEntryModel model);
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(String userId, int year, int month);
  Future<void> deleteWorkEntry(String userId, String entryId);
  Future<List<WorkEntryModel>> getAllOldWorkEntries(String userId);
  Future<void> deleteAllOldWorkEntries(String userId, List<String> entryIds);
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final firebase.AuthCredential credential = firebase.GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      print("Fehler beim Google Sign-In: $e");
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
        final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
        if (googleUser == null) return;
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final firebase.AuthCredential credential = firebase.GoogleAuthProvider.credential(idToken: googleAuth.idToken);
        await user.reauthenticateWithCredential(credential);
        await user.delete();
      } else {
        print("Fehler beim Löschen des Accounts: $e");
        rethrow;
      }
    } catch (e) {
      print("Unerwarteter Fehler beim Löschen des Accounts: $e");
      rethrow;
    }
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
      print("KRITISCH: Fehler beim Löschen der Firestore-Daten nach Account-Löschung: $e");
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
    print('[Firestore] Lade WorkEntry für User: $userId, Datum: $date');
    final docRef = _getMonthDocRef(userId, date);
    final snapshot = await docRef.get();
    final dayKey = date.day.toString();
    print('[Firestore] Dokument existiert: ${snapshot.exists}, DayKey: $dayKey');
    if (snapshot.exists && snapshot.data() != null) {
      final monthData = snapshot.data()!;
      final dayData = monthData['days']?[dayKey];
      print('[Firestore] DayData gefunden: ${dayData != null}');
      if (dayData != null) {
        final entry = WorkEntryModel.fromMap(dayData).copyWith(id: WorkEntryModel.generateId(date));
        print('[Firestore] WorkEntry geladen: Start=${entry.workStart}, End=${entry.workEnd}');
        return entry;
      }
    }
    print('[Firestore] Kein WorkEntry gefunden für diesen Tag');
    return null;
  }

  @override
  Future<void> saveWorkEntry(String userId, WorkEntryModel model) async {
    print('[Firestore] Speichere WorkEntry für User: $userId, Datum: ${model.date}');
    final docRef = _getMonthDocRef(userId, model.date);
    final dayKey = model.date.day.toString();
    final data = { 'days': { dayKey: model.toMap() } };
    print('[Firestore] Daten: workStart=${model.workStart}, workEnd=${model.workEnd}');
    try {
      await docRef.set(data, SetOptions(merge: true));
      print('[Firestore] Erfolgreich gespeichert in Dokument: ${docRef.path}');
    } catch (e) {
      print('[Firestore] FEHLER beim Speichern: $e');
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
        final dayData = entry.value as Map<String, dynamic>;
        final entryDate = DateTime(year, month, int.parse(entry.key));
        return WorkEntryModel.fromMap(dayData).copyWith(id: WorkEntryModel.generateId(entryDate));
      }).toList()
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

  @override
  Future<List<WorkEntryModel>> getAllOldWorkEntries(String userId) async {
    final collectionRef = _firestore.collection('users').doc(userId).collection('work_entries');
    final querySnapshot = await collectionRef.get();
    
    final oldEntries = <WorkEntryModel>[];
    final oldIdRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    for (final doc in querySnapshot.docs) {
      if (oldIdRegex.hasMatch(doc.id)) {
        oldEntries.add(WorkEntryModel.fromFirestore(doc));
      }
    }
    return oldEntries;
  }

  @override
  Future<void> deleteAllOldWorkEntries(String userId, List<String> entryIds) async {
    final collectionRef = _firestore.collection('users').doc(userId).collection('work_entries');
    final batch = _firestore.batch();
    for (final id in entryIds) {
      batch.delete(collectionRef.doc(id));
    }
    await batch.commit();
  }
}
