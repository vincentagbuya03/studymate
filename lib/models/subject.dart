import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleSlot {
  const ScheduleSlot({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  final int day; // 1 (Mon) to 7 (Sun)
  final String startTime;
  final String endTime;

  Map<String, dynamic> toMap() => {
    'day': day,
    'startTime': startTime,
    'endTime': endTime,
  };

  factory ScheduleSlot.fromMap(Map<String, dynamic> map) => ScheduleSlot(
    day: map['day'] as int,
    startTime: map['startTime'] as String,
    endTime: map['endTime'] as String,
  );

  String get dayLabel {
    const List<String> map = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return map[day - 1];
  }

  String get timeLabel => '$startTime - $endTime';
}

class Subject {
  const Subject({
    this.id,
    required this.name,
    required this.room,
    required this.slots,
    required this.colorValue,
    this.units = 3.0,
    this.notes = '',
  });

  final int? id;
  final String name;
  final String room;
  final List<ScheduleSlot> slots;
  final int colorValue;
  final double units;
  final String notes;

  Color get color => Color(colorValue);

  bool occursOn(DateTime date) {
    return slots.any((slot) => slot.day == date.weekday);
  }

  List<ScheduleSlot> getSlotsForDay(int weekday) {
    return slots.where((slot) => slot.day == weekday).toList();
  }

  Subject copyWith({
    int? id,
    String? name,
    String? room,
    List<ScheduleSlot>? slots,
    int? colorValue,
    double? units,
    String? notes,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      room: room ?? this.room,
      slots: slots ?? this.slots,
      colorValue: colorValue ?? this.colorValue,
      units: units ?? this.units,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'room': room,
      'slots': jsonEncode(slots.map((s) => s.toMap()).toList()),
      'colorValue': colorValue,
      'units': units,
      'notes': notes,
    };
  }

  factory Subject.fromMap(Map<String, Object?> map) {
    final List<dynamic> slotsJson = jsonDecode(map['slots'] as String);
    return Subject(
      id: map['id'] as int?,
      name: map['name'] as String,
      room: map['room'] as String,
      slots: slotsJson.map((s) => ScheduleSlot.fromMap(s as Map<String, dynamic>)).toList(),
      colorValue: map['colorValue'] as int,
      units: (map['units'] as num?)?.toDouble() ?? 3.0,
      notes: map['notes'] as String? ?? '',
    );
  }

  static String formatTimeOfDay(TimeOfDay time) {
    final DateTime date = DateTime(2000, 1, 1, time.hour, time.minute);
    return DateFormat('hh:mm a').format(date);
  }
}
