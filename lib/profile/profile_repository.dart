import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> loadProfile(String uid);

  Future<void> saveProfile(UserProfile profile);
}

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profileDocument(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  @override
  Future<UserProfile?> loadProfile(String uid) async {
    final snapshot = await _profileDocument(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }

    return UserProfile.fromMap({
      ...data,
      'uid': data['uid'] as String? ?? uid,
      'createdAt': _dateFrom(data['createdAt']),
      'updatedAt': _dateFrom(data['updatedAt']),
    });
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final now = DateTime.now();
    final profileToSave = profile.copyWith(
      createdAt: profile.createdAt ?? now,
      updatedAt: now,
    );

    await _profileDocument(profile.uid).set(
      profileToSave.toMap(),
      SetOptions(merge: true),
    );
  }

  DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class MemoryUserProfileRepository implements UserProfileRepository {
  MemoryUserProfileRepository({UserProfile? initialProfile})
    : _profile = initialProfile;

  UserProfile? _profile;

  @override
  Future<UserProfile?> loadProfile(String uid) async {
    final profile = _profile;
    if (profile == null || profile.uid != uid) return null;
    return profile;
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
  }
}
