import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleSignInInit;

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInit ??= _googleSignIn.initialize();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_open', true);
    return credential;
  }

  Future<UserCredential> signInWithGoogle({
    bool requireGmailDotCom = false,
  }) async {
    UserCredential credential;

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      credential = await _auth.signInWithPopup(provider);
    } else {
      await _ensureGoogleSignInInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw FirebaseAuthException(
          code: 'google_sign_in_unsupported',
          message: 'Google Sign-In is not supported on this platform.',
        );
      }

      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing_google_id_token',
          message: 'Google Sign-In did not return an ID token.',
        );
      }

      final OAuthCredential googleCredential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      credential = await _auth.signInWithCredential(googleCredential);
    }

    final String? email = credential.user?.email;
    if (requireGmailDotCom &&
        email != null &&
        !email.toLowerCase().endsWith('@gmail.com')) {
      await signOut();
      throw FirebaseAuthException(
        code: 'invalid_email_domain',
        message: 'Please sign in with a gmail.com account.',
      );
    }

    final bool isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
    if (isNewUser) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_open', true);
    }

    return credential;
  }

  Future<void> ensureUserProfile({
    String? displayName,
    bool seedDisplayNameFromEmail = true,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final String? fallbackName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : seedDisplayNameFromEmail
        ? user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : user.email?.split('@').first ?? 'User'
        : null;

    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref
        .get()
        .timeout(const Duration(seconds: 15));

    if (!snapshot.exists) {
      if (fallbackName != null) {
        await _syncAuthDisplayName(user, fallbackName);
      }
      await ref
          .set(<String, dynamic>{
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
            'disabled': false,
            ...?fallbackName == null
                ? null
                : <String, dynamic>{'displayName': fallbackName},
          })
          .timeout(const Duration(seconds: 15));
      try {
        await _recordPublicStudentCount();
      } catch (e) {
        debugPrint('[Auth] Public student count update failed: $e');
      }
    } else {
      final String? storedDisplayName =
          snapshot.data()?['displayName'] as String?;
      final String? profileDisplayName = displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : storedDisplayName?.trim().isNotEmpty == true
          ? storedDisplayName!.trim()
          : fallbackName;
      if (profileDisplayName != null) {
        await _syncAuthDisplayName(user, profileDisplayName);
      }
      await ref
          .set(<String, dynamic>{
            'email': user.email,
            'lastSeen': FieldValue.serverTimestamp(),
            ...?profileDisplayName == null
                ? null
                : <String, dynamic>{'displayName': profileDisplayName},
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }
    final String sanitized = _sanitizeDisplayName(displayName);
    await user.updateDisplayName(sanitized);
    await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'displayName': sanitized,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();
    }
  }

  String _sanitizeDisplayName(String displayName) {
    return displayName.trim().isEmpty ? 'User' : displayName.trim();
  }

  Future<void> _syncAuthDisplayName(User user, String displayName) async {
    final String sanitized = _sanitizeDisplayName(displayName);
    if (user.displayName == sanitized) {
      return;
    }
    await user.updateDisplayName(sanitized);
  }

  Future<void> _recordPublicStudentCount() async {
    final DocumentReference<Map<String, dynamic>> metricsRef = _firestore
        .collection('publicMetrics')
        .doc('studymate');

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(metricsRef);
      final Map<String, dynamic>? data = snapshot.data();
      final int currentCount = data?['studentCount'] is int
          ? data!['studentCount'] as int
          : data?['downloadCount'] is int
          ? data!['downloadCount'] as int
          : 0;

      transaction.set(metricsRef, <String, dynamic>{
        'studentCount': currentCount + 1,
        'ratingTotal': data?['ratingTotal'] ?? 0,
        'ratingCount': data?['ratingCount'] ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
