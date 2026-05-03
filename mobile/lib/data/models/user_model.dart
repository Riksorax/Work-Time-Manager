import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the application-specific user data stored in Firestore.
class UserModel {
  /// The unique user ID from Firebase Auth.
  final String uid;

  /// The user's display name.
  final String? displayName;

  /// The user's email address.
  final String? email;

  /// The URL of the user's profile picture.
  final String? photoURL;

  /// The target weekly working hours for this user.
  final int targetWeeklyHours;

  UserModel({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
    this.targetWeeklyHours = 40, // Default value of 40 hours
  });

  /// Creates a [UserModel] instance from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError("Missing data for UserModel ${snapshot.id}");
    }
    return UserModel(
      uid: snapshot.id,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      photoURL: data['photoURL'] as String?,
      targetWeeklyHours: data['targetWeeklyHours'] as int? ?? 40,
    );
  }

  /// Converts this [UserModel] instance to a map for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'targetWeeklyHours': targetWeeklyHours,
    };
  }

  /// Creates a new [UserModel] instance with updated fields.
  UserModel copyWith({
    String? displayName,
    String? email,
    String? photoURL,
    int? targetWeeklyHours,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      targetWeeklyHours: targetWeeklyHours ?? this.targetWeeklyHours,
    );
  }
}