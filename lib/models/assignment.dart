import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AssignmentPriority { low, medium, high }

class Assignment {
  const Assignment({
    this.id,
    this.remoteId,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.priority,
    this.isCompleted = false,
    this.completedAt,
  });

  final int? id;
  final String? remoteId;
  final String title;
  final String subject;
  final DateTime dueDate;
  final AssignmentPriority priority;
  final bool isCompleted;
  final DateTime? completedAt;

  Color get priorityColor {
    switch (priority) {
      case AssignmentPriority.low:
        return const Color(0xFF22C55E);
      case AssignmentPriority.medium:
        return const Color(0xFFF59E0B);
      case AssignmentPriority.high:
        return const Color(0xFFEF4444);
    }
  }

  String get priorityLabel {
    switch (priority) {
      case AssignmentPriority.low:
        return 'Low';
      case AssignmentPriority.medium:
        return 'Medium';
      case AssignmentPriority.high:
        return 'High';
    }
  }

  String get dueLabel => DateFormat('MMM d, yyyy - hh:mm a').format(dueDate);

  bool get isDueToday {
    final DateTime now = DateTime.now();
    return now.year == dueDate.year &&
        now.month == dueDate.month &&
        now.day == dueDate.day;
  }

  bool get isOverdue => !isCompleted && dueDate.isBefore(DateTime.now());

  Assignment copyWith({
    int? id,
    String? remoteId,
    String? title,
    String? subject,
    DateTime? dueDate,
    AssignmentPriority? priority,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'remoteId': remoteId,
      'title': title,
      'subject': subject,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority.name,
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Assignment.fromMap(Map<String, Object?> map) {
    return Assignment(
      id: map['id'] as int?,
      remoteId: map['remoteId'] as String?,
      title: map['title'] as String,
      subject: map['subject'] as String,
      dueDate: DateTime.parse(map['dueDate'] as String),
      priority: AssignmentPriority.values.firstWhere(
        (AssignmentPriority value) => value.name == map['priority'],
        orElse: () => AssignmentPriority.medium,
      ),
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      completedAt: map['completedAt'] == null
          ? null
          : DateTime.tryParse(map['completedAt'] as String),
    );
  }
}
