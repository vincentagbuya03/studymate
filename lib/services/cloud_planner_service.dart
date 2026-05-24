import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart' as rx;

import '../models/assignment.dart';
import '../models/exam.dart';
import '../models/grade.dart';
import '../models/subject.dart';

class PlannerSnapshot {
  const PlannerSnapshot({
    required this.subjects,
    required this.assignments,
    required this.exams,
    required this.grades,
  });

  final List<Subject> subjects;
  final List<Assignment> assignments;
  final List<Exam> exams;
  final List<Grade> grades;
}

class CloudPlannerService {
  CloudPlannerService._();

  static final CloudPlannerService instance = CloudPlannerService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('Planner data requires a signed-in user.');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _userRef.collection(name);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserProfile() {
    return _userRef.snapshots();
  }

  Stream<PlannerSnapshot> watchPlanner() {
    return rx.Rx.combineLatest5(
      _userRef.snapshots(),
      _collection('subjects').orderBy('name').snapshots(),
      _collection('assignments').orderBy('dueDate').snapshots(),
      _collection('exams').orderBy('dateTime').snapshots(),
      _collection('grades').orderBy('date', descending: true).snapshots(),
      (
        DocumentSnapshot<Map<String, dynamic>> profile,
        QuerySnapshot<Map<String, dynamic>> subjects,
        QuerySnapshot<Map<String, dynamic>> assignments,
        QuerySnapshot<Map<String, dynamic>> exams,
        QuerySnapshot<Map<String, dynamic>> grades,
      ) {
        final bool disabled = profile.data()?['disabled'] == true;
        if (disabled) {
          throw StateError('This account has been disabled.');
        }
        return PlannerSnapshot(
          subjects: subjects.docs.map(_subjectFromDoc).toList(),
          assignments: assignments.docs.map(_assignmentFromDoc).toList(),
          exams: exams.docs.map(_examFromDoc).toList(),
          grades: grades.docs.map(_gradeFromDoc).toList(),
        );
      },
    );
  }

  Future<PlannerSnapshot> loadPlannerData() async {
    final results = await Future.wait([
      _collection('subjects').orderBy('name').get(),
      _collection('assignments').orderBy('dueDate').get(),
      _collection('exams').orderBy('dateTime').get(),
      _collection('grades').orderBy('date', descending: true).get(),
    ]).timeout(const Duration(seconds: 15));

    return PlannerSnapshot(
      subjects: results[0].docs.map(_subjectFromDoc).toList(),
      assignments: results[1].docs.map(_assignmentFromDoc).toList(),
      exams: results[2].docs.map(_examFromDoc).toList(),
      grades: results[3].docs.map(_gradeFromDoc).toList(),
    );
  }

  Future<Subject> upsertSubject(Subject subject) async {
    final doc = _docFor('subjects', subject.remoteId);
    final Subject saved = subject.copyWith(
      id: subject.id ?? _stableLocalId(doc.id),
      remoteId: doc.id,
    );
    await doc.set(_cleanMap(saved.toMap()), SetOptions(merge: true));
    return saved;
  }

  Future<void> deleteSubject(Subject subject) {
    return _deleteByRemoteOrLocalId('subjects', subject.remoteId, subject.id);
  }

  Future<Assignment> upsertAssignment(Assignment assignment) async {
    final doc = _docFor('assignments', assignment.remoteId);
    final Assignment saved = assignment.copyWith(
      id: assignment.id ?? _stableLocalId(doc.id),
      remoteId: doc.id,
    );
    await doc.set(_cleanMap(saved.toMap()), SetOptions(merge: true));
    return saved;
  }

  Future<void> deleteAssignment(Assignment assignment) {
    return _deleteByRemoteOrLocalId(
      'assignments',
      assignment.remoteId,
      assignment.id,
    );
  }

  Future<Exam> upsertExam(Exam exam) async {
    final doc = _docFor('exams', exam.remoteId);
    final Exam saved = exam.copyWith(
      id: exam.id ?? _stableLocalId(doc.id),
      remoteId: doc.id,
    );
    await doc.set(_cleanMap(saved.toMap()), SetOptions(merge: true));
    return saved;
  }

  Future<void> deleteExam(Exam exam) {
    return _deleteByRemoteOrLocalId('exams', exam.remoteId, exam.id);
  }

  Future<Grade> upsertGrade(Grade grade) async {
    final doc = _docFor('grades', grade.remoteId);
    final Grade saved = Grade(
      id: grade.id ?? _stableLocalId(doc.id),
      remoteId: doc.id,
      subject: grade.subject,
      score: grade.score,
      maxScore: grade.maxScore,
      category: grade.category,
      date: grade.date,
    );
    await doc.set(_cleanMap(saved.toMap()), SetOptions(merge: true));
    return saved;
  }

  Future<void> deleteGrade(Grade grade) {
    return _deleteByRemoteOrLocalId('grades', grade.remoteId, grade.id);
  }

  Future<void> clearPlannerData() async {
    final WriteBatch batch = _firestore.batch();
    for (final name in const ['subjects', 'assignments', 'exams', 'grades']) {
      final snapshot = await _collection(name).get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _docFor(
    String collection,
    String? remoteId,
  ) {
    if (remoteId == null || remoteId.isEmpty) {
      return _collection(collection).doc();
    }
    return _collection(collection).doc(remoteId);
  }

  Future<void> _deleteByRemoteOrLocalId(
    String collection,
    String? remoteId,
    int? id,
  ) async {
    if (remoteId != null && remoteId.isNotEmpty) {
      await _collection(collection).doc(remoteId).delete();
      return;
    }
    if (id == null) {
      return;
    }
    final query = await _collection(
      collection,
    ).where('id', isEqualTo: id).get();
    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }

  Map<String, Object?> _cleanMap(Map<String, Object?> map) {
    return Map<String, Object?>.from(map)
      ..removeWhere((_, Object? value) => value == null)
      ..['updatedAt'] = FieldValue.serverTimestamp();
  }

  Subject _subjectFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Subject.fromMap(<String, Object?>{
      ...doc.data(),
      'id': doc.data()['id'] ?? _stableLocalId(doc.id),
      'remoteId': doc.id,
    });
  }

  Assignment _assignmentFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return Assignment.fromMap(<String, Object?>{
      ...doc.data(),
      'id': doc.data()['id'] ?? _stableLocalId(doc.id),
      'remoteId': doc.id,
    });
  }

  Exam _examFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Exam.fromMap(<String, dynamic>{
      ...doc.data(),
      'id': doc.data()['id'] ?? _stableLocalId(doc.id),
      'remoteId': doc.id,
    });
  }

  Grade _gradeFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Grade.fromMap(<String, dynamic>{
      ...doc.data(),
      'id': doc.data()['id'] ?? _stableLocalId(doc.id),
      'remoteId': doc.id,
    });
  }

  int _stableLocalId(String remoteId) {
    int hash = 0;
    for (final int codeUnit in remoteId.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash == 0 ? 1 : hash;
  }

  Future<void> enableOfflinePersistence() async {
    _firestore.settings = const Settings(persistenceEnabled: true);
  }
}
