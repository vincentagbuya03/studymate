import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/assignment.dart';
import '../models/exam.dart';
import '../models/grade.dart';
import '../models/subject.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  /// Opens the local SQLite database and creates tables on first launch.
  Future<void> initialize() async {
    if (_database != null) {
      return;
    }

    final String databasesPath = await getDatabasesPath();
    final String path = join(databasesPath, 'iskolar.db');

    _database = await openDatabase(
      path,
      version: 4,
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE exams(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              subject TEXT NOT NULL,
              dateTime TEXT NOT NULL,
              room TEXT NOT NULL,
              notes TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE grades(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              subject TEXT NOT NULL,
              score REAL NOT NULL,
              maxScore REAL NOT NULL,
              category TEXT NOT NULL,
              date TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE subjects ADD COLUMN slots TEXT');
          final List<Map<String, dynamic>> oldSubjects = await db.query(
            'subjects',
          );
          for (var s in oldSubjects) {
            final String startTime = s['startTime'] as String;
            final String endTime = s['endTime'] as String;
            final List<String> days = (s['days'] as String)
                .split(',')
                .where((d) => d.isNotEmpty)
                .toList();
            final List<Map<String, dynamic>> slots = days
                .map(
                  (d) => {
                    'day': int.parse(d),
                    'startTime': startTime,
                    'endTime': endTime,
                  },
                )
                .toList();
            await db.update(
              'subjects',
              {'slots': jsonEncode(slots)},
              where: 'id = ?',
              whereArgs: [s['id']],
            );
          }
        }
        if (oldVersion < 4) {
          try {
            await db.execute(
              'ALTER TABLE subjects ADD COLUMN units REAL DEFAULT 3.0',
            );
          } catch (e) {
            debugPrint('Units column already exists, skipping.');
          }
          try {
            await db.execute(
              'ALTER TABLE subjects ADD COLUMN notes TEXT DEFAULT ""',
            );
          } catch (e) {
            debugPrint('Notes column already exists, skipping.');
          }
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE subjects(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        room TEXT NOT NULL,
        slots TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        units REAL NOT NULL DEFAULT 3.0,
        notes TEXT NOT NULL DEFAULT ""
      )
    ''');

    await db.execute('''
      CREATE TABLE assignments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subject TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        priority TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        completedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE exams(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subject TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        room TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE grades(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        score REAL NOT NULL,
        maxScore REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<Database> get database async {
    await initialize();
    return _database!;
  }

  /// Returns all subjects ordered by start time for cleaner schedule views.
  Future<List<Subject>> getSubjects() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'subjects',
      orderBy: 'name ASC',
    );
    return rows.map(Subject.fromMap).toList();
  }

  /// Inserts a new subject and returns its generated row id.
  Future<int> insertSubject(Subject subject) async {
    final Database db = await database;
    return db.insert('subjects', subject.toMap());
  }

  /// Persists updates to an existing subject record.
  Future<int> updateSubject(Subject subject) async {
    final Database db = await database;
    return db.update(
      'subjects',
      subject.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[subject.id],
    );
  }

  /// Deletes a subject by id.
  Future<int> deleteSubject(int id) async {
    final Database db = await database;
    return db.delete('subjects', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Returns all assignments ordered by due date.
  Future<List<Assignment>> getAssignments() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'assignments',
      orderBy: 'dueDate ASC',
    );
    return rows.map(Assignment.fromMap).toList();
  }

  /// Inserts a new assignment and returns its generated row id.
  Future<int> insertAssignment(Assignment assignment) async {
    final Database db = await database;
    return db.insert('assignments', assignment.toMap());
  }

  /// Saves edits to an existing assignment.
  Future<int> updateAssignment(Assignment assignment) async {
    final Database db = await database;
    return db.update(
      'assignments',
      assignment.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[assignment.id],
    );
  }

  /// Deletes an assignment by id.
  Future<int> deleteAssignment(int id) async {
    final Database db = await database;
    return db.delete('assignments', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Returns all exams ordered by date.
  Future<List<Exam>> getExams() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'exams',
      orderBy: 'dateTime ASC',
    );
    return rows.map(Exam.fromMap).toList();
  }

  Future<int> insertExam(Exam exam) async {
    final Database db = await database;
    return db.insert('exams', exam.toMap());
  }

  Future<int> updateExam(Exam exam) async {
    final Database db = await database;
    return db.update(
      'exams',
      exam.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[exam.id],
    );
  }

  Future<int> deleteExam(int id) async {
    final Database db = await database;
    return db.delete('exams', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Returns all grades ordered by date.
  Future<List<Grade>> getGrades() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'grades',
      orderBy: 'date DESC',
    );
    return rows.map(Grade.fromMap).toList();
  }

  Future<int> insertGrade(Grade grade) async {
    final Database db = await database;
    return db.insert('grades', grade.toMap());
  }

  Future<int> deleteGrade(int id) async {
    final Database db = await database;
    return db.delete('grades', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Wipes planner data for a full offline reset.
  Future<void> clearAllData() async {
    final Database db = await database;
    await db.delete('subjects');
    await db.delete('assignments');
    await db.delete('exams');
    await db.delete('grades');
  }
}
