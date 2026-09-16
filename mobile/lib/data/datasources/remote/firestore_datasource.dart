import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:flutter_work_time/core/config/google_sign_in_config.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../models/work_entry_model.dart';
import 'package:flutter_work_time/core/utils/time_precision.dart';
import 'package:flutter_work_time/domain/entities/weekly_reflection_entity.dart';

abstract class FirestoreDataSource {
  Stream<firebase.User?> get authStateChanges;
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> deleteAccount();

  // Work Entries (optionales profileId siehe #138 - null/'default' = bestehender,
  // nicht migrierter Pfad; jedes andere Profil lebt in einer Subcollection)
  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date, {String? profileId});
  Future<void> saveWorkEntry(String userId, WorkEntryModel model, {String? profileId});
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(String userId, int year, int month,
      {String? profileId});
  Future<void> deleteWorkEntry(String userId, String entryId, {String? profileId});

  // Overtime
  Future<Duration> getOvertime(String userId, {String? profileId});
  Future<void> saveOvertime(String userId, Duration overtime, {String? profileId});
  Future<DateTime?> getLastOvertimeUpdate(String userId, {String? profileId});
  Future<void> saveLastOvertimeUpdate(String userId, DateTime date, {String? profileId});

  // User Profile
  Future<void> setUserProfile(String userId, Map<String, dynamic> data);

  // Settings (plattformübergreifend: weeklyTargetHours, workdays)
  Future<Map<String, dynamic>?> getSettings(String userId, {String? profileId});
  Future<void> saveSettings(String userId, Map<String, dynamic> settings, {String? profileId});

  // Weekly Reflection (siehe #137)
  Future<WeeklyReflectionEntity?> getWeeklyReflection(String userId, int year, int week);
  Future<void> saveWeeklyReflection(String userId, WeeklyReflectionEntity reflection);

  // Arbeitszeit-Profile (siehe #138)
  Future<List<Map<String, dynamic>>> getWorkProfiles(String userId);
  Future<String> addWorkProfile(String userId, String name);
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
        // WICHTIG: initialize() muss vor authenticate() aufgerufen werden (seit google_sign_in 7.0)
        // und benötigt auf Android zwingend die serverClientId, sonst wirft
        // authenticate() eine clientConfigurationError-Exception.
        await _googleSignIn.initialize(serverClientId: GoogleSignInConfig.serverClientId);

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
    await _firebaseAuth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
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
          await _googleSignIn.initialize(serverClientId: GoogleSignInConfig.serverClientId);

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
      final userDocRef = _firestore.collection('users').doc(userId);

      // Work Entries löschen
      final workEntriesCollection = userDocRef.collection('work_entries');
      final workEntriesSnapshot = await workEntriesCollection.get();
      final batch = _firestore.batch();
      for (final doc in workEntriesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Overtime-Daten löschen
      final overtimeCollection = userDocRef.collection('overtime');
      final overtimeSnapshot = await overtimeCollection.get();
      for (final doc in overtimeSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      await userDocRef.delete();
    } catch (e) {
      logger.e("KRITISCH: Fehler beim Löschen der Firestore-Daten nach Account-Löschung: $e");
      rethrow;
    }
    
    await _googleSignIn.signOut();
  }

  String _getMonthDocId(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  /// Basis-Dokumentpfad für profil-gebundene Daten (siehe #138): `null`/
  /// `'default'` verweist auf den bestehenden, nicht migrierten Pfad
  /// `users/{uid}/{collection}/{docId}`; jedes andere Profil liegt unter
  /// `users/{uid}/profiles/{profileId}/{collection}/{docId}`.
  DocumentReference<Map<String, dynamic>> _profileScopedDoc(
      String userId, String collection, String docId, {String? profileId}) {
    final userDoc = _firestore.collection('users').doc(userId);
    if (profileId == null || profileId == 'default') {
      return userDoc.collection(collection).doc(docId);
    }
    return userDoc.collection('profiles').doc(profileId).collection(collection).doc(docId);
  }

  DocumentReference<Map<String, dynamic>> _getMonthDocRef(String userId, DateTime date,
      {String? profileId}) {
    return _profileScopedDoc(userId, 'work_entries', _getMonthDocId(date), profileId: profileId);
  }

  @override
  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date, {String? profileId}) async {
    logger.i('[Firestore] Lade WorkEntry für User: $userId, Datum: $date, Profil: $profileId');
    final docRef = _getMonthDocRef(userId, date, profileId: profileId);
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
  Future<void> saveWorkEntry(String userId, WorkEntryModel model, {String? profileId}) async {
    logger.i('[Firestore] Speichere WorkEntry für User: $userId, Datum: ${model.date}, Profil: $profileId');
    final docRef = _getMonthDocRef(userId, model.date, profileId: profileId);
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
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(String userId, int year, int month,
      {String? profileId}) async {
    final date = DateTime(year, month);
    final docRef = _getMonthDocRef(userId, date, profileId: profileId);
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
  Future<void> deleteWorkEntry(String userId, String entryId, {String? profileId}) async {
    final date = WorkEntryModel.parseId(entryId);
    final docRef = _getMonthDocRef(userId, date, profileId: profileId);
    final dayKey = date.day.toString();
    await docRef.update({ 'days.$dayKey': FieldValue.delete() });
  }

  // ============================================================================
  // OVERTIME METHODS
  // ============================================================================

  DocumentReference<Map<String, dynamic>> _getOvertimeDocRef(String userId, {String? profileId}) {
    return _profileScopedDoc(userId, 'overtime', 'balance', profileId: profileId);
  }

  @override
  Future<Duration> getOvertime(String userId, {String? profileId}) async {
    logger.i('[Firestore] Lade Overtime für User: $userId, Profil: $profileId');
    final docRef = _getOvertimeDocRef(userId, profileId: profileId);
    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      final minutes = data['minutes'] as int? ?? 0;
      logger.i('[Firestore] Overtime geladen: $minutes Minuten');
      return Duration(minutes: minutes);
    }

    logger.i('[Firestore] Keine Overtime-Daten gefunden, gebe 0 zurück');
    return Duration.zero;
  }

  @override
  Future<void> saveOvertime(String userId, Duration overtime, {String? profileId}) async {
    logger.i('[Firestore] Speichere Overtime für User: $userId, Wert: ${toStoredMinutes(overtime)} Minuten');
    final docRef = _getOvertimeDocRef(userId, profileId: profileId);

    await docRef.set({
      'minutes': toStoredMinutes(overtime),
    }, SetOptions(merge: true));
  }

  @override
  Future<DateTime?> getLastOvertimeUpdate(String userId, {String? profileId}) async {
    final docRef = _getOvertimeDocRef(userId, profileId: profileId);
    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      final timestamp = data['lastUpdated'] as Timestamp?;
      return timestamp?.toDate();
    }

    return null;
  }

  @override
  Future<void> saveLastOvertimeUpdate(String userId, DateTime date, {String? profileId}) async {
    logger.i('[Firestore] Speichere Overtime-Update-Datum für User: $userId');
    final docRef = _getOvertimeDocRef(userId, profileId: profileId);

    await docRef.set({
      'lastUpdated': Timestamp.fromDate(date),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setUserProfile(String userId, Map<String, dynamic> data) async {
    logger.i('[Firestore] Aktualisiere User-Profil für $userId: $data');
    await _firestore.collection('users').doc(userId).set(data, SetOptions(merge: true));
  }

  @override
  Future<Map<String, dynamic>?> getSettings(String userId, {String? profileId}) async {
    final snap =
        await _profileScopedDoc(userId, 'settings', 'current', profileId: profileId).get();
    return snap.exists ? snap.data() : null;
  }

  @override
  Future<void> saveSettings(String userId, Map<String, dynamic> settings,
      {String? profileId}) async {
    await _profileScopedDoc(userId, 'settings', 'current', profileId: profileId)
        .set(settings, SetOptions(merge: true));
  }

  // ============================================================================
  // WEEKLY REFLECTION METHODS (siehe #137)
  // ============================================================================

  DocumentReference<Map<String, dynamic>> _getWeeklyReflectionDocRef(
      String userId, String docId) {
    return _firestore
        .collection('users').doc(userId)
        .collection('weekly_reflections').doc(docId);
  }

  @override
  Future<WeeklyReflectionEntity?> getWeeklyReflection(
      String userId, int year, int week) async {
    final empty = WeeklyReflectionEntity(year: year, week: week);
    final snapshot = await _getWeeklyReflectionDocRef(userId, empty.id).get();

    if (!snapshot.exists || snapshot.data() == null) return null;

    final data = snapshot.data()!;
    return WeeklyReflectionEntity(
      year: year,
      week: week,
      whatWentWell: data['whatWentWell'] as String? ?? '',
      whatWasHard: data['whatWasHard'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<void> saveWeeklyReflection(
      String userId, WeeklyReflectionEntity reflection) async {
    logger.i('[Firestore] Speichere Wochen-Reflexion ${reflection.id} für User: $userId');
    await _getWeeklyReflectionDocRef(userId, reflection.id).set({
      'whatWentWell': reflection.whatWentWell,
      'whatWasHard': reflection.whatWasHard,
      'updatedAt': Timestamp.fromDate(reflection.updatedAt ?? DateTime.now()),
    }, SetOptions(merge: true));
  }

  // ============================================================================
  // WORK PROFILE METHODS (siehe #138)
  // ============================================================================

  CollectionReference<Map<String, dynamic>> _profilesCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('profiles');
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkProfiles(String userId) async {
    final snapshot = await _profilesCollection(userId).get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  @override
  Future<String> addWorkProfile(String userId, String name) async {
    logger.i('[Firestore] Lege neues Arbeitszeit-Profil an für User: $userId, Name: $name');
    final docRef = await _profilesCollection(userId).add({
      'name': name,
      'createdAt': Timestamp.now(),
    });
    return docRef.id;
  }
}
