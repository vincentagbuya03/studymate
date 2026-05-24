import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserProfile {
  const AdminUserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.disabled,
    this.createdAt,
    this.lastSeen,
  });

  final String uid;
  final String displayName;
  final String email;
  final bool disabled;
  final DateTime? createdAt;
  final DateTime? lastSeen;

  factory AdminUserProfile.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AdminUserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'User',
      email: data['email'] as String? ?? '',
      disabled: data['disabled'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
    );
  }
}

class AdminService {
  AdminService._();

  static final AdminService instance = AdminService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AdminUserProfile>> watchUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final List<AdminUserProfile> profiles = snapshot.docs
              .map(AdminUserProfile.fromDoc)
              .toList();
          final Map<String, AdminUserProfile> dedupedByEmail =
              <String, AdminUserProfile>{};

          for (final AdminUserProfile profile in profiles) {
            final String emailKey = profile.email.trim().toLowerCase();
            final String dedupeKey = emailKey.isEmpty ? profile.uid : emailKey;
            final AdminUserProfile? existing = dedupedByEmail[dedupeKey];
            if (existing == null ||
                _shouldReplaceExisting(
                  existing: existing,
                  candidate: profile,
                )) {
              dedupedByEmail[dedupeKey] = profile;
            }
          }

          final List<AdminUserProfile> users = dedupedByEmail.values.toList()
            ..sort((AdminUserProfile a, AdminUserProfile b) {
              final DateTime aTime = a.createdAt ?? a.lastSeen ?? DateTime(0);
              final DateTime bTime = b.createdAt ?? b.lastSeen ?? DateTime(0);
              return bTime.compareTo(aTime);
            });
          return users;
        });
  }

  Future<void> createUserProfile({
    required String uid,
    required String displayName,
    required String email,
    bool disabled = false,
  }) {
    final String trimmedUid = uid.trim();
    return _firestore.collection('users').doc(trimmedUid).set(<String, dynamic>{
      'displayName': displayName.trim().isEmpty ? 'User' : displayName.trim(),
      'email': email.trim(),
      'disabled': disabled,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile({
    required String uid,
    required String displayName,
    required String email,
    required bool disabled,
  }) {
    return _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'displayName': displayName.trim().isEmpty ? 'User' : displayName.trim(),
      'email': email.trim(),
      'disabled': disabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setUserDisabled({required String uid, required bool disabled}) {
    return _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'disabled': disabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteUserProfile({required String uid}) {
    return _firestore.collection('users').doc(uid).delete();
  }

  static bool _shouldReplaceExisting({
    required AdminUserProfile existing,
    required AdminUserProfile candidate,
  }) {
    final DateTime existingTime =
        existing.lastSeen ?? existing.createdAt ?? DateTime(0);
    final DateTime candidateTime =
        candidate.lastSeen ?? candidate.createdAt ?? DateTime(0);

    if (candidateTime.isAfter(existingTime)) {
      return true;
    }
    if (candidateTime.isBefore(existingTime)) {
      return false;
    }

    final bool existingLooksPlaceholder =
        existing.email.isNotEmpty &&
        existing.displayName.trim().toLowerCase() ==
            existing.email.split('@').first.trim().toLowerCase();
    final bool candidateLooksPlaceholder =
        candidate.email.isNotEmpty &&
        candidate.displayName.trim().toLowerCase() ==
            candidate.email.split('@').first.trim().toLowerCase();

    if (existingLooksPlaceholder != candidateLooksPlaceholder) {
      return existingLooksPlaceholder && !candidateLooksPlaceholder;
    }

    return candidate.uid.compareTo(existing.uid) > 0;
  }
}
