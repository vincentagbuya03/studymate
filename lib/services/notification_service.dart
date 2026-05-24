import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/assignment.dart';
import '../models/exam.dart';
import '../models/subject.dart';
import 'alarm_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderIdBase = 7000;
  static const int _dailyReminderSlots = 14;
  static const int _legacyAssignmentExactAlarmIdBase = 100000;
  static const int _legacyExamExactAlarmIdBase = 200000;
  static const Duration _foregroundExactReminderWindow = Duration(minutes: 2);
  static const Duration _sameMinuteSchedulingGrace = Duration(seconds: 90);
  static const Duration _immediateScheduleDelay = Duration(seconds: 5);
  static const String _deliveredReminderKeysStorage =
      'delivered_reminder_keys_v1';
  static const String _handledDailyReminderDatesStorage =
      'handled_daily_reminder_dates_v1';

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
        'iskolar_reminders_v5', // Incremented version to ensure channel update
        'StudyMate Alarms',
        description: 'Wake-up alarms with custom sound.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'studymate_reminders_v1',
        'StudyMate Reminders',
        description: 'Task and exam reminder notifications.',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
      ),
    );
  }

  /// Requests Android notification permission only (POST_NOTIFICATIONS).
  /// Does NOT request exact alarm permission — use [requestExactAlarmPermission] for that.
  Future<bool> requestNotificationsPermission() async {
    if (kIsWeb) return true;
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final bool? granted = await androidPlugin?.requestNotificationsPermission();

    // Android versions below 13 do not require the POST_NOTIFICATIONS runtime
    // permission, so the plugin may return null even though notifications work.
    return granted ?? true;
  }

  /// Checks whether the app can schedule exact alarms (Android 12+).
  /// Returns true on web, or if the platform check succeeds.
  Future<bool> checkExactAlarmPermission() async {
    if (kIsWeb) return true;
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final bool? canSchedule = await androidPlugin
        ?.canScheduleExactNotifications();
    return canSchedule ?? true;
  }

  /// Opens the system settings page for exact alarms (SCHEDULE_EXACT_ALARM).
  /// On Android 12+, the user must manually toggle this ON for release builds.
  Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) return true;
    if (await checkExactAlarmPermission()) {
      return true;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final bool? granted = await androidPlugin?.requestExactAlarmsPermission();
    if (granted == true) {
      return true;
    }

    return checkExactAlarmPermission();
  }

  /// Opens the system settings for exact alarms (Android 14+).
  Future<void> openExactAlarmSettings() async {
    if (kIsWeb) return;
    await requestExactAlarmPermission();
  }

  Future<void> rescheduleAll({
    required List<Assignment> assignments,
    required List<Subject> subjects,
    required List<Exam> exams,
    required bool enableDailyReminder,
    required bool enableOneDayReminder,
    required bool enableOneHourReminder,
    required bool enableExactTimeReminder,
    required TimeOfDay classAlarmTime,
    required String alarmSoundPath,
    required String studentName,
  }) async {
    if (!_isInitialized || kIsWeb) return;
    try {
      await cancelTrackedNotifications(assignments: assignments, exams: exams);

      if (enableDailyReminder) {
        await scheduleDailyReminder(
          subjects: subjects,
          studentName: studentName,
          alarmTime: classAlarmTime,
          alarmSoundPath: alarmSoundPath,
        );
      }

      for (final Assignment assignment in assignments) {
        await scheduleAssignmentReminders(
          assignment: assignment,
          enableOneDayReminder: enableOneDayReminder,
          enableOneHourReminder: enableOneHourReminder,
          enableExactTimeReminder: enableExactTimeReminder,
          alarmSoundPath: alarmSoundPath,
        );
      }

      for (final Exam exam in exams) {
        await scheduleExamReminders(
          exam: exam,
          enableOneDayReminder: enableOneDayReminder,
          enableOneHourReminder: enableOneHourReminder,
          enableExactTimeReminder: enableExactTimeReminder,
          alarmSoundPath: alarmSoundPath,
        );
      }
    } catch (e) {
      debugPrint('Error in rescheduleAll: $e');
    }
  }

  /// Cancels notifications and alarms that can be derived from current app data.
  Future<void> cancelTrackedNotifications({
    required List<Assignment> assignments,
    required List<Exam> exams,
  }) async {
    if (kIsWeb) return;

    await _cancelDailyReminderNotifications();
    await _cancelAlarmBackedReminders(assignments: assignments, exams: exams);

    for (final Assignment assignment in assignments) {
      final int? id = assignment.id;
      if (id != null) {
        await cancelAssignmentNotifications(id);
      }
    }

    for (final Exam exam in exams) {
      final int? id = exam.id;
      if (id != null) {
        await cancelExamNotifications(id);
      }
    }
  }

  Future<void> scheduleAssignmentReminders({
    required Assignment assignment,
    required bool enableOneDayReminder,
    required bool enableOneHourReminder,
    required bool enableExactTimeReminder,
    required String alarmSoundPath,
  }) async {
    if (!_isInitialized || assignment.id == null || kIsWeb) {
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
        scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    if (enableOneHourReminder) {
      await _scheduleOneOffReminder(
        id: (assignment.id! * 100) + 2,
        when: assignment.dueDate.subtract(const Duration(hours: 1)),
        title: 'Assignment due in 1 hour',
        body:
            '${assignment.title} for ${assignment.subject} is almost due. Final push, StudyMate!',
        scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    if (enableExactTimeReminder) {
      final String scheduledStr = DateFormat(
        'hh:mm:ss a',
      ).format(assignment.dueDate);
      debugPrint(
        '[NotificationService] Planning EXACT reminder for ${assignment.title} at $scheduledStr',
      );
      await _scheduleExactNotificationReminder(
        id: _assignmentExactNotificationId(assignment.id!),
        when: assignment.dueDate,
        title: 'Assignment Due Now!',
        body:
            'Time is up! ${assignment.title} for ${assignment.subject} is due now.',
      );
    }
  }

  /// Cancels reminders tied to a single assignment record.
  Future<void> cancelAssignmentNotifications(int assignmentId) async {
    if (kIsWeb) return;
    await _cancelNotification((assignmentId * 100) + 1);
    await _cancelNotification((assignmentId * 100) + 2);
    await _cancelNotification(_assignmentExactNotificationId(assignmentId));
    await _cancelNotification(_legacyAssignmentExactAlarmId(assignmentId));
    await AlarmService.instance.stopAlarm(
      _legacyAssignmentExactAlarmId(assignmentId),
    );
  }

  /// Schedules one-day, one-hour, and exact-time reminders for an exam.
  Future<void> scheduleExamReminders({
    required Exam exam,
    required bool enableOneDayReminder,
    required bool enableOneHourReminder,
    required bool enableExactTimeReminder,
    required String alarmSoundPath,
  }) async {
    if (exam.id == null || kIsWeb) {
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
        scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    if (enableOneHourReminder) {
      await _scheduleOneOffReminder(
        id: (exam.id! * 100) + 20,
        when: exam.dateTime.subtract(const Duration(hours: 1)),
        title: 'Exam starting in 1 hour',
        body:
            '${exam.title} is starting soon in ${exam.room}. Good luck, StudyMate!',
        scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    if (enableExactTimeReminder) {
      await _scheduleExactNotificationReminder(
        id: _examExactNotificationId(exam.id!),
        when: exam.dateTime,
        title: 'Exam Starting Now!',
        body:
            'Time to shine! ${exam.title} for ${exam.subject} is starting now in ${exam.room}.',
      );
    }
  }

  Future<void> cancelExamNotifications(int examId) async {
    if (kIsWeb) return;
    await _cancelNotification((examId * 100) + 10);
    await _cancelNotification((examId * 100) + 20);
    await _cancelNotification(_examExactNotificationId(examId));
    await _cancelNotification(_legacyExamExactAlarmId(examId));
    await AlarmService.instance.stopAlarm(_legacyExamExactAlarmId(examId));
  }

  Future<void> scheduleDailyReminder({
    required List<Subject> subjects,
    required String studentName,
    required TimeOfDay alarmTime,
    required String alarmSoundPath,
  }) async {
    if (kIsWeb) return;
    final bool canScheduleExactAlarms = await checkExactAlarmPermission();

    await _cancelDailyReminderAlarms();
    await _cancelDailyReminderNotifications();

    final DateTime now = DateTime.now();
    int scheduledCount = 0;

    for (int i = 0; i < 14; i++) {
      final DateTime candidateDate = now.add(Duration(days: i));
      if (await _hasHandledDailyReminder(candidateDate)) {
        continue;
      }

      DateTime candidateAlarmTime = DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
        alarmTime.hour,
        alarmTime.minute,
      );

      if (candidateAlarmTime.isBefore(now)) {
        final bool justMissedThisMinute =
            candidateAlarmTime.year == now.year &&
            candidateAlarmTime.month == now.month &&
            candidateAlarmTime.day == now.day &&
            candidateAlarmTime.hour == now.hour &&
            candidateAlarmTime.minute == now.minute &&
            now.difference(candidateAlarmTime) <= _sameMinuteSchedulingGrace;

        if (!justMissedThisMinute) {
          continue;
        }

        candidateAlarmTime = now.add(_immediateScheduleDelay);
      }

      final bool hasClass = subjects.any(
        (subject) => subject.occursOn(candidateDate),
      );
      if (!hasClass) {
        continue;
      }

      final List<Subject> classDaySubjects = subjects
          .where((Subject subject) => subject.occursOn(candidateDate))
          .toList();

      String firstStartTime = '';
      ScheduleSlot? earliestSlot;
      for (final Subject subject in classDaySubjects) {
        for (final ScheduleSlot slot in subject.getSlotsForDay(
          candidateDate.weekday,
        )) {
          if (earliestSlot == null ||
              slot.startTime.compareTo(earliestSlot.startTime) < 0) {
            earliestSlot = slot;
          }
        }
      }
      firstStartTime = earliestSlot?.startTime ?? '';

      final String body =
          'You have ${classDaySubjects.length} class(es) today, $studentName. First class: $firstStartTime.';

      final int reminderId = _dailyReminderIdBase + scheduledCount;
      if (canScheduleExactAlarms) {
        final bool alarmScheduled = await AlarmService.instance.scheduleAlarm(
          id: reminderId,
          dateTime: candidateAlarmTime,
          title: 'Class Day Alarm',
          body: body,
          assetAudioPath: alarmSoundPath,
        );

        if (!alarmScheduled) {
          await _scheduleOneOffReminder(
            id: reminderId,
            when: candidateAlarmTime,
            title: 'Class Day Alarm',
            body: body,
            scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            details: _alarmNotificationDetails(),
          );
        }
      } else {
        debugPrint(
          '[NotificationService] Exact alarm permission missing; scheduling class-day notification fallback for $candidateAlarmTime.',
        );
        await _scheduleOneOffReminder(
          id: reminderId,
          when: candidateAlarmTime,
          title: 'Class Day Alarm',
          body: body,
          scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          details: _alarmNotificationDetails(),
        );
      }
      scheduledCount++;
      if (scheduledCount >= _dailyReminderSlots) {
        break;
      }
    }
  }

  /// Clears every notification created by the app.
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized || kIsWeb) return;
    try {
      await _cancelDailyReminderNotifications();
      await AlarmService.instance.stopAllAlarms();
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }

  Future<void> _cancelAlarmBackedReminders({
    required List<Assignment> assignments,
    required List<Exam> exams,
  }) async {
    await _cancelDailyReminderAlarms();

    for (final Assignment assignment in assignments) {
      final int? id = assignment.id;
      if (id != null) {
        await AlarmService.instance.stopAlarm(
          _legacyAssignmentExactAlarmId(id),
        );
      }
    }

    for (final Exam exam in exams) {
      final int? id = exam.id;
      if (id != null) {
        await AlarmService.instance.stopAlarm(_legacyExamExactAlarmId(id));
      }
    }
  }

  Future<void> _cancelDailyReminderAlarms() async {
    await AlarmService.instance.stopAlarms(
      List<int>.generate(
        _dailyReminderSlots,
        (int index) => _dailyReminderIdBase + index,
      ),
    );
  }

  Future<void> _cancelDailyReminderNotifications() async {
    for (int i = 0; i < _dailyReminderSlots; i++) {
      await _cancelNotification(_dailyReminderIdBase + i);
    }
  }

  Future<void> _cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[NotificationService] Failed to cancel notification $id: $e');
    }
  }

  /// Immediately shows a notification (useful for testing permissions and channels).
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await _plugin.show(9999, title, body, _reminderNotificationDetails());
  }

  /// Checks reminders while the app is open so exact-time alerts still fire in foreground.
  Future<void> deliverDueNowFallback({
    required List<Assignment> assignments,
    required List<Exam> exams,
    required bool enableExactTimeReminder,
  }) async {
    if (!_isInitialized || !enableExactTimeReminder || kIsWeb) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android &&
        await checkExactAlarmPermission()) {
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
        await _cancelNotification(
          _assignmentExactNotificationId(assignment.id!),
        );
        await _plugin.show(
          _assignmentExactNotificationId(assignment.id!),
          'Assignment Due Now!',
          'Time is up! ${assignment.title} for ${assignment.subject} is due now.',
          _reminderNotificationDetails(),
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
        await _cancelNotification(_examExactNotificationId(exam.id!));
        await _plugin.show(
          _examExactNotificationId(exam.id!),
          'Exam Starting Now!',
          'Time to shine! ${exam.title} for ${exam.subject} is starting now in ${exam.room}.',
          _reminderNotificationDetails(),
        );
        await _markReminderDelivered(reminderKey);
      }
    }
  }

  /// Clears the stored once-only reminder history.
  Future<void> clearDeliveredReminderState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deliveredReminderKeysStorage);
    await prefs.remove(_handledDailyReminderDatesStorage);
  }

  Future<void> markDailyReminderHandled({
    required int alarmId,
    required DateTime alarmDateTime,
  }) async {
    if (!_isDailyReminderId(alarmId)) {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<String> handledDates = await _handledDailyReminderDates(
      prefs,
      referenceDate: alarmDateTime,
    );
    handledDates.add(_dailyReminderDateKey(alarmDateTime));
    await prefs.setStringList(
      _handledDailyReminderDatesStorage,
      handledDates.toList()..sort(),
    );
  }

  /// Schedules one notification only if its target time is still in the future.
  Future<void> _scheduleOneOffReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required AndroidScheduleMode scheduleMode,
    NotificationDetails? details,
  }) async {
    final DateTime now = DateTime.now();
    DateTime targetTime = when;
    final Duration diff = now.difference(when);
    final NotificationDetails notificationDetails =
        details ?? _reminderNotificationDetails();

    if (!when.isAfter(now)) {
      if (diff <= _sameMinuteSchedulingGrace) {
        targetTime = now.add(_immediateScheduleDelay);
        debugPrint(
          '[NotificationService] $id was due $diff ago; scheduling immediate fallback at $targetTime.',
        );
      } else {
        debugPrint(
          '[NotificationService] SKIPPED $id: Time $when is in the past by ${diff.inSeconds} seconds.',
        );
        return;
      }
    }

    // Otherwise, schedule it for the future as normal.
    try {
      tz.TZDateTime scheduledDate = tz.TZDateTime.from(targetTime, tz.local);
      final tz.TZDateTime localNow = tz.TZDateTime.now(tz.local);

      // Safety: ensure scheduled time is strictly in the future
      if (scheduledDate.isBefore(localNow) ||
          scheduledDate.isAtSameMomentAs(localNow)) {
        scheduledDate = localNow.add(_immediateScheduleDelay);
      }

      debugPrint(
        '[NotificationService] SCHEDULING $id for $scheduledDate (Local now: $localNow)',
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Successfully scheduled notification $id');
    } catch (e) {
      debugPrint('Primary schedule failed, trying inexact: $e');
      try {
        tz.TZDateTime fallbackDate = tz.TZDateTime.from(targetTime, tz.local);
        final tz.TZDateTime fallbackNow = tz.TZDateTime.now(tz.local);
        if (fallbackDate.isBefore(fallbackNow)) {
          fallbackDate = fallbackNow.add(_immediateScheduleDelay);
        }
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          fallbackDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint(
          'Inexact schedule also failed: $e2. Firing instantly instead.',
        );
        await _plugin.show(id, title, body, notificationDetails);
      }
    }
  }

  Future<void> _scheduleExactNotificationReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    final DateTime? targetTime = _normalizeFutureTrigger(when);
    if (targetTime == null) {
      debugPrint(
        '[NotificationService] SKIPPED exact notification $id because $when is too far in the past.',
      );
      return;
    }

    await _scheduleOneOffReminder(
      id: id,
      when: targetTime,
      title: title,
      body: body,
      scheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  DateTime? _normalizeFutureTrigger(DateTime when) {
    final DateTime now = DateTime.now();
    if (when.isAfter(now)) {
      return when;
    }

    final Duration diff = now.difference(when);
    if (diff <= _sameMinuteSchedulingGrace) {
      return now.add(_immediateScheduleDelay);
    }

    return null;
  }

  NotificationDetails _alarmNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'iskolar_reminders_v5',
        'StudyMate Alarms',
        channelDescription: 'Wake-up alarms with custom sound.',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        fullScreenIntent: true,
        ticker: 'StudyMate Reminder',
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarm.mp3',
      ),
    );
  }

  NotificationDetails _reminderNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'studymate_reminders_v1',
        'StudyMate Reminders',
        channelDescription: 'Task and exam reminder notifications.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
        ticker: 'StudyMate Reminder',
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
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

  int _legacyAssignmentExactAlarmId(int assignmentId) {
    return _legacyAssignmentExactAlarmIdBase + assignmentId;
  }

  int _legacyExamExactAlarmId(int examId) {
    return _legacyExamExactAlarmIdBase + examId;
  }

  int _assignmentExactNotificationId(int assignmentId) {
    return (assignmentId * 100) + 3;
  }

  int _examExactNotificationId(int examId) {
    return (examId * 100) + 30;
  }

  Future<bool> _hasHandledDailyReminder(DateTime date) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<String> handledDates = await _handledDailyReminderDates(
      prefs,
      referenceDate: date,
    );
    return handledDates.contains(_dailyReminderDateKey(date));
  }

  Future<Set<String>> _handledDailyReminderDates(
    SharedPreferences prefs, {
    required DateTime referenceDate,
  }) async {
    final DateTime oldestDate = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    ).subtract(const Duration(days: 14));
    final List<String> stored =
        prefs.getStringList(_handledDailyReminderDatesStorage) ?? <String>[];
    final Set<String> retained = stored.where((String key) {
      final DateTime? handledDate = DateTime.tryParse(key);
      return handledDate != null && !handledDate.isBefore(oldestDate);
    }).toSet();

    if (retained.length != stored.length) {
      await prefs.setStringList(
        _handledDailyReminderDatesStorage,
        retained.toList()..sort(),
      );
    }

    return retained;
  }

  bool _isDailyReminderId(int id) {
    return id >= _dailyReminderIdBase &&
        id < _dailyReminderIdBase + _dailyReminderSlots;
  }

  String _dailyReminderDateKey(DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    return day.toIso8601String();
  }
}
