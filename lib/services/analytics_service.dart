import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppPublicMetrics {
  const AppPublicMetrics({
    required this.studentCount,
    required this.ratingAverage,
    required this.ratingCount,
  });

  final int studentCount;
  final double ratingAverage;
  final int ratingCount;

  static const AppPublicMetrics fallback = AppPublicMetrics(
    studentCount: 0,
    ratingAverage: 4.9,
    ratingCount: 0,
  );
}

class AppReview {
  const AppReview({
    required this.displayName,
    required this.rating,
    required this.comment,
  });

  final String displayName;
  final int rating;
  final String comment;
}

/// Handles public app metrics and signed-in student reviews.
class AnalyticsService {
  AnalyticsService._privateConstructor();
  static final AnalyticsService instance =
      AnalyticsService._privateConstructor();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> get _metricsRef =>
      _firestore.collection('publicMetrics').doc('studymate');

  CollectionReference<Map<String, dynamic>> get _reviewsRef =>
      _firestore.collection('publicReviews');

  /// Increments the public student count used by the web download page.
  ///
  /// This is best-effort; failures are logged but not rethrown.
  Future<void> incrementStudentCount() async {
    try {
      await _firestore.runTransaction((transaction) async {
        final metricsSnapshot = await transaction.get(_metricsRef);
        final metricsData = metricsSnapshot.data();
        final int currentStudentCount = metricsData?['studentCount'] is int
            ? metricsData!['studentCount'] as int
            : metricsData?['downloadCount'] is int
            ? metricsData!['downloadCount'] as int
            : AppPublicMetrics.fallback.studentCount;

        transaction.set(_metricsRef, <String, dynamic>{
          'studentCount': (currentStudentCount + 1).clamp(0, 1 << 31),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('[Analytics] Could not increment studentCount: $e');
    }
  }

  Stream<AppPublicMetrics> watchPublicMetrics() {
    return _metricsRef.snapshots().map((snapshot) {
      return _metricsFromData(snapshot.data());
    });
  }

  Stream<List<AppReview>> watchPublicReviews({int limit = 6}) {
    return _reviewsRef
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _reviewFromData(doc.data()))
              .whereType<AppReview>()
              .toList();
        });
  }

  Future<AppPublicMetrics> getPublicMetrics() async {
    try {
      final snapshot = await _metricsRef.get().timeout(
        const Duration(seconds: 4),
      );
      return _metricsFromData(snapshot.data());
    } catch (e) {
      debugPrint('[Analytics] Public metrics unavailable: $e');
      return AppPublicMetrics.fallback;
    }
  }

  Future<AppReview?> getMyReview() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final snapshot = await _reviewsRef.doc(user.uid).get();
    return _reviewFromData(snapshot.data());
  }

  Future<void> submitReview({
    required int rating,
    required String comment,
    required String displayName,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Please sign in before rating StudyMate.',
      );
    }

    final int sanitizedRating = rating.clamp(1, 5);
    final String sanitizedComment = comment.trim();
    final String sanitizedDisplayName = displayName.trim().isEmpty
        ? 'StudyMate Student'
        : displayName.trim();

    if (sanitizedComment.length < 8) {
      throw ArgumentError('Please add a short comment with your rating.');
    }

    final reviewRef = _reviewsRef.doc(user.uid);

    try {
      final reviewSnapshot = await reviewRef.get();
      final reviewData = reviewSnapshot.data();
      final int previousRating = reviewData?['rating'] is int
          ? reviewData!['rating'] as int
          : 0;

      await reviewRef.set(<String, dynamic>{
        'userId': user.uid,
        'displayName': sanitizedDisplayName,
        'rating': sanitizedRating,
        'comment': sanitizedComment,
        'approved': true,
        'createdAt': reviewData?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        await _updateReviewMetrics(
          previousRating: previousRating,
          nextRating: sanitizedRating,
        );
      } catch (e) {
        debugPrint('[Analytics] Review saved, but metrics update failed: $e');
      }
    } catch (e) {
      debugPrint('[Analytics] Could not submit review: $e');
      rethrow;
    }
  }

  Future<void> _updateReviewMetrics({
    required int previousRating,
    required int nextRating,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final metricsSnapshot = await transaction.get(_metricsRef);
      final metricsData = metricsSnapshot.data();

      final int currentTotal = metricsData?['ratingTotal'] is int
          ? metricsData!['ratingTotal'] as int
          : 0;
      final int currentCount = metricsData?['ratingCount'] is int
          ? metricsData!['ratingCount'] as int
          : 0;
      final int nextTotal = (currentTotal - previousRating + nextRating).clamp(
        0,
        1 << 31,
      );
      final int nextCount = previousRating == 0
          ? currentCount + 1
          : currentCount;

      transaction.set(_metricsRef, <String, dynamic>{
        'studentCount':
            metricsData?['studentCount'] ??
            AppPublicMetrics.fallback.studentCount,
        'ratingTotal': nextTotal,
        'ratingCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  AppPublicMetrics _metricsFromData(Map<String, dynamic>? data) {
    if (data == null) {
      return AppPublicMetrics.fallback;
    }

    final int studentCount = data['studentCount'] is int
        ? data['studentCount'] as int
        : data['downloadCount'] is int
        ? data['downloadCount'] as int
        : AppPublicMetrics.fallback.studentCount;
    final int ratingTotal = data['ratingTotal'] is int
        ? data['ratingTotal'] as int
        : 0;
    final int ratingCount = data['ratingCount'] is int
        ? data['ratingCount'] as int
        : 0;

    return AppPublicMetrics(
      studentCount: studentCount,
      ratingAverage: ratingCount == 0
          ? AppPublicMetrics.fallback.ratingAverage
          : ratingTotal / ratingCount,
      ratingCount: ratingCount,
    );
  }

  AppReview? _reviewFromData(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    if (data['approved'] == false) {
      return null;
    }

    final String displayName = data['displayName'] is String
        ? data['displayName'] as String
        : 'StudyMate Student';
    final int rating = data['rating'] is int ? data['rating'] as int : 0;
    final String comment = data['comment'] is String
        ? data['comment'] as String
        : '';

    if (rating < 1 || rating > 5 || comment.trim().isEmpty) {
      return null;
    }

    return AppReview(
      displayName: displayName,
      rating: rating,
      comment: comment,
    );
  }
}
