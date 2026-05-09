import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/assignment.dart';
import '../models/exam.dart';
import '../models/subject.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 7000;
  static const Duration _foregroundExactReminderWindow = Duration(minutes: 2);
  static const String _deliveredReminderKeysStorage =
      'delivered_reminder_keys_v1';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initializes notification channels, time zone data, and platform permissions.
  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      final String timeZoneName = 'Asia/Manila';
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Error initializing timezones: $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _isInitialized = true;

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'iskolar_reminders_v4',
        'Iskolar Reminders',
        description: 'Assignment and daily schedule reminders.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  /// Requests Android notification permission only after the app UI is visible.
  Future<bool?> requestNotificationsPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestExactAlarmsPermission();
    return androidPlugin?.requestNotificationsPermission();
  }

  /// Opens the system settings for exact alarms (Android 14+).
  Future<void> openExactAlarmSettings() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> rescheduleAll({
    required List<Assignment> assignments,
    required List<Subject> subjects,
    required List<Exam> exams,
    required bool enableDailyReminder,
    required bool enableOneDayReminder,
    required bool enableOneHourReminder,
    required bool enableExactTimeReminder,
    required String studentName,
  }) async {
    if (!_isInitialized) return;
    try {
      await cancelAllNotifications();

      if (enableDailyReminder) {
        await scheduleDailyReminder(
          subjects: subjects,
          studentName: studentName,
        );
      }

      for (final Assignment assignment in assignments) {
        await scheduleAssignmentReminders(
          assignment: assignment,
          enableOneDayReminder: enableOneDayReminder,
          enableOneHourReminder: enableOneHourReminder,
          enableExactTimeReminder: enableExactTimeReminder,
        );
      }

      for (final Exam exam in exams) {
        await scheduleExamReminders(
          exam: exam,
          enableOneDayReminder: enableOneDayReminder,
          enableOneHourReminder: enableOneHourReminder,
          enableExactTimeReminder: enableExactTimeReminder,
        );
      }
    } catch (e) {
      debugPrint('Error in rescheduleAll: $e');
    }
  }

  /// Schedules one-day and one-hour reminders for a single assignment.
  Future<void> scheduleAssignmentReminders({
    required Assignment assignment,
    required bool enableOneDayReminder,
    required bool enableOneHourReminder,
    required bool enableExactTimeReminder,
  }) async {
    if (!_isInitialized || assignment.id == null) {
      return;
    }

    await cancelAssignmentNotifications(assignment.id!);

    if (assignment.isCompleted) {
      return;
    }

    if (enableOneDayReminder) {
      await _scheduleOneOffReminder(
        id: (assignment.id! * 100) + 1,
        when: assignment.dueDate.subtract(const Duration(days: 1)),
        title: 'Assignment due tomorrow',
        body:
            '${assignment.title} for ${assignment.subject} is due tomorrow at ${assignment.dueLabel}.',
      );
    }

    if (enableOneHourReminder) {
      await _scheduleOneOffReminder(
        id: (assignment.id! * 100) + 2,
        when: assignment.dueDate.subtract(const Duration(hours: 1)),
        title: 'Assignment due in 1 hour',
        body:
            '${assignment.title} for ${assignment.subject} is almost due. Final push, StudyMate!',
      );
    }

    if (enableExactTimeReminder) {
      final String scheduledStr = DateFormat(
        'hh:mm:ss a',
      ).format(assignment.dueDate);
      debugPrint(
        '[NotificationService] Planning EXACT reminder for ${assignment.title} at $scheduledStr',
      );
      await _scheduleOneOffReminder(
        id: (assignment.id! * 100) + 3,
        when: assignment.dueDate,
        title: 'Assignment Due Now!',
        body:
            'Time is up! ${assignment.title} for ${assignment.subject} is due now.',
      );
    }
  }

  /// Cancels reminders tied to a single assignment record.
  Future<void> cancelAssignmentNotifications(int assignmentId) async {
    await _plugin.cancel((assignmentId * 100) + 1);
    await _plugin.cancel((assignmentId * 100) + 2);
    await _plugin.cancel((assignmentId * 100) + 3);
  }

  /// Schedules one-day, one-hour, and exact-time reminders for an exam.
  Future<void> scheduleExamReminders({
    required Exam exam,
    required bool enableOneDayReminder,
    required bool enableOneHourReminder,
    required bool enableExactTimeReminder,
  }) async {
    if (exam.id == null) {
      return;
    }

    await cancelExamNotifications(exam.id!);

    if (enableOneDayReminder) {
      await _scheduleOneOffReminder(
        id: (exam.id! * 100) + 10,
        when: exam.dateTime.subtract(const Duration(days: 1)),
        title: 'Upcoming Exam Tomorrow',
        body:
            '${exam.title} for ${exam.subject} is tomorrow at ${DateFormat('hh:mm a').format(exam.dateTime)}.',
      );
    }

    if (enableOneHourReminder) {
      await _scheduleOneOffReminder(
        id: (exam.id! * 100) + 20,
        when: exam.dateTime.subtract(const Duration(hours: 1)),
        title: 'Exam starting in 1 hour',
        body:
            '${exam.title} is starting soon in ${exam.room}. Good luck, StudyMate!',
      );
    }

    if (enableExactTimeReminder) {
      await _scheduleOneOffReminder(
        id: (exam.id! * 100) + 30,
        when: exam.dateTime,
        title: 'Exam Starting Now!',
        body:
            'Time to shine! ${exam.title} for ${exam.subject} is starting now in ${exam.room}.',
      );
    }
  }

  Future<void> cancelExamNotifications(int examId) async {
    await _plugin.cancel((examId * 100) + 10);
    await _plugin.cancel((examId * 100) + 20);
    await _plugin.cancel((examId * 100) + 30);
  }

  /// Creates a repeating 7:00 AM reminder for the day's class schedule.
  Future<void> scheduleDailyReminder({
    required List<Subject> subjects,
    required String studentName,
  }) async {
    final List<Subject> todaySubjects = subjects
        .where((Subject subject) => subject.occursOn(DateTime.now()))
        .toList();

    String firstStartTime = '';
    if (todaySubjects.isNotEmpty) {
      ScheduleSlot? earliestSlot;
      for (final Subject subject in todaySubjects) {
        for (final ScheduleSlot slot in subject.getSlotsForDay(
          DateTime.now().weekday,
        )) {
          if (earliestSlot == null ||
              slot.startTime.compareTo(earliestSlot.startTime) < 0) {
            earliestSlot = slot;
          }
        }
      }
      firstStartTime = earliestSlot?.startTime ?? '';
    }

    final String body = todaySubjects.isEmpty
        ? 'Walang class sa schedule mo today. Perfect day to catch up and recharge.'
        : 'May ${todaySubjects.length} class ka today, $studentName. Unang klase: $firstStartTime.';

    try {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Good morning, $studentName',
        body,
        _nextMorningSeven(),
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Good morning, $studentName',
        body,
        _nextMorningSeven(),
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Clears every notification created by the app.
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }

  /// Immediately shows a notification (useful for testing permissions and channels).
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(9999, title, body, _notificationDetails());
  }

  /// Checks reminders while the app is open so exact-time alerts still fire in foreground.
  Future<void> deliverDueNowFallback({
    required List<Assignment> assignments,
    required List<Exam> exams,
    required bool enableExactTimeReminder,
  }) async {
    if (!_isInitialized || !enableExactTimeReminder) {
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime earliestAllowed = now.subtract(
      _foregroundExactReminderWindow,
    );

    for (final Assignment assignment in assignments) {
      if (assignment.id == null || assignment.isCompleted) {
        continue;
      }

      if (_isWithinForegroundWindow(
        targetTime: assignment.dueDate,
        earliestAllowed: earliestAllowed,
        now: now,
      )) {
        final String reminderKey = _assignmentExactReminderKey(assignment);
        if (await _hasDeliveredReminder(reminderKey)) {
          continue;
        }

        debugPrint(
          '[NotificationService] FOREGROUND EXACT assignment ${assignment.id} due now. Showing fallback notification.',
        );
        await _plugin.cancel((assignment.id! * 100) + 3);
        await _plugin.show(
          (assignment.id! * 100) + 3,
          'Assignment Due Now!',
          'Time is up! ${assignment.title} for ${assignment.subject} is due now.',
          _notificationDetails(),
        );
        await _markReminderDelivered(reminderKey);
      }
    }

    for (final Exam exam in exams) {
      if (exam.id == null) {
        continue;
      }

      if (_isWithinForegroundWindow(
        targetTime: exam.dateTime,
        earliestAllowed: earliestAllowed,
        now: now,
      )) {
        final String reminderKey = _examExactReminderKey(exam);
        if (await _hasDeliveredReminder(reminderKey)) {
          continue;
        }

        debugPrint(
          '[NotificationService] FOREGROUND EXACT exam ${exam.id} due now. Showing fallback notification.',
        );
        await _plugin.cancel((exam.id! * 100) + 30);
        await _plugin.show(
          (exam.id! * 100) + 30,
          'Exam Starting Now!',
          'Time to shine! ${exam.title} for ${exam.subject} is starting now in ${exam.room}.',
          _notificationDetails(),
        );
        await _markReminderDelivered(reminderKey);
      }
    }
  }

  /// Clears the stored once-only reminder history.
  Future<void> clearDeliveredReminderState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deliveredReminderKeysStorage);
  }

  /// Schedules one notification only if its target time is still in the future.
  Future<void> _scheduleOneOffReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(when);

    // If the target time has already passed, do not notify late.
    if (!when.isAfter(now)) {
      debugPrint(
        '[NotificationService] SKIPPED $id: Time $when is in the past by ${diff.inSeconds} seconds.',
      );
      return;
    }

    // Otherwise, schedule it for the future as normal.
    try {
      tz.TZDateTime scheduledDate = tz.TZDateTime.from(when, tz.local);
      final tz.TZDateTime localNow = tz.TZDateTime.now(tz.local);

      // Safety: ensure scheduled time is strictly in the future
      if (scheduledDate.isBefore(localNow) || scheduledDate.isAtSameMomentAs(localNow)) {
        scheduledDate = localNow.add(const Duration(seconds: 5));
      }

      debugPrint(
        '[NotificationService] SCHEDULING $id for $scheduledDate (Local now: $localNow)',
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Successfully scheduled notification $id');
    } catch (e) {
      debugPrint('Exact schedule failed, trying inexact: $e');
      try {
        tz.TZDateTime fallbackDate = tz.TZDateTime.from(when, tz.local);
        final tz.TZDateTime fallbackNow = tz.TZDateTime.now(tz.local);
        if (fallbackDate.isBefore(fallbackNow)) {
          fallbackDate = fallbackNow.add(const Duration(seconds: 5));
        }
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          fallbackDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint('Inexact schedule also failed: $e2. Firing instantly instead.');
        await _plugin.show(id, title, body, _notificationDetails());
      }
    }
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'iskolar_reminders_v4',
        'Iskolar Reminders',
        channelDescription: 'Assignment and daily schedule reminders.',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        ticker: 'StudyMate Reminder',
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
      ),
    );
  }

  tz.TZDateTime _nextMorningSeven() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      7,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  bool _isWithinForegroundWindow({
    required DateTime targetTime,
    required DateTime earliestAllowed,
    required DateTime now,
  }) {
    return !targetTime.isBefore(earliestAllowed) && !targetTime.isAfter(now);
  }

  String _assignmentExactReminderKey(Assignment assignment) {
    return 'assignment:${assignment.id}:exact:${assignment.dueDate.toIso8601String()}';
  }

  String _examExactReminderKey(Exam exam) {
    return 'exam:${exam.id}:exact:${exam.dateTime.toIso8601String()}';
  }

  Future<bool> _hasDeliveredReminder(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> delivered =
        prefs.getStringList(_deliveredReminderKeysStorage) ?? <String>[];
    return delivered.contains(key);
  }

  Future<void> _markReminderDelivered(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> delivered =
        prefs.getStringList(_deliveredReminderKeysStorage) ?? <String>[];
    if (delivered.contains(key)) {
      return;
    }
    delivered.add(key);
    await prefs.setStringList(_deliveredReminderKeysStorage, delivered);
  }
}
