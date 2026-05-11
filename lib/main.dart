import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/assignment.dart';
import 'models/exam.dart';
import 'models/grade.dart';
import 'models/subject.dart';
import 'screens/assignment_screen.dart';
import 'screens/exams_screen.dart';
import 'screens/focus_timer_screen.dart';
import 'screens/grades_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'screens/alarm_ring_screen.dart';
import 'widgets/app_logo.dart';
import 'widgets/editor_sheets.dart';
import 'web/app_download_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseService.instance.initialize();
  await NotificationService.instance.initialize();
  await AlarmService.instance.initialize();
  runApp(const StudyMateApp());
}

class StudyMateApp extends StatefulWidget {
  const StudyMateApp({super.key});

  @override
  State<StudyMateApp> createState() => _StudyMateAppState();
}

class _StudyMateAppState extends State<StudyMateApp>
    with WidgetsBindingObserver {
  static const String _notificationPermissionPromptedKey =
      'notification_permission_prompted';
  static const Duration _foregroundReminderPollInterval = Duration(seconds: 5);

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final DatabaseService _databaseService = DatabaseService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  List<Subject> _subjects = <Subject>[];
  List<Assignment> _assignments = <Assignment>[];
  List<Exam> _exams = <Exam>[];
  List<Grade> _grades = <Grade>[];
  bool _isLoading = true;
  bool _isDarkMode = false;
  bool _dailyReminderEnabled = true;
  bool _dayBeforeReminderEnabled = true;
  bool _hourBeforeReminderEnabled = true;
  bool _exactTimeReminderEnabled = true;
  TimeOfDay _classAlarmTime = const TimeOfDay(hour: 7, minute: 0);
  String _alarmSoundPath = 'assets/audio/alarm_clock_old.mp3';
  String _studentName = 'User';
  int _selectedIndex = 0;
  bool _isFirstOpen = false;
  Timer? _foregroundReminderTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _listenToAlarms();
  }

  StreamSubscription? _ringingSubscription;

  void _listenToAlarms() {
    _ringingSubscription = AlarmService.instance.ringingStream.listen((alarmSet) {
      if (!mounted) return;
      for (final settings in alarmSet.alarms) {
        _showAlarmRingScreen(settings.id, settings.notificationSettings.title, settings.notificationSettings.body);
      }
    });
  }

  /// Check on startup if an alarm is already ringing (e.g. app was opened
  /// from the notification while the alarm was still going).
  void _checkForRingingAlarms() {
    final ringing = AlarmService.instance.currentlyRinging;
    if (ringing.isNotEmpty) {
      final settings = ringing.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAlarmRingScreen(settings.id, settings.notificationSettings.title, settings.notificationSettings.body);
      });
    }
  }

  bool _isAlarmScreenShowing = false;

  void _showAlarmRingScreen(int alarmId, String title, String body) {
    if (!mounted || _isAlarmScreenShowing) return;
    _isAlarmScreenShowing = true;

    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AlarmRingScreen(
          alarmId: alarmId,
          title: title,
          body: body,
        ),
      ),
    ).then((_) {
      _isAlarmScreenShowing = false;
      _refreshNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundReminderTimer?.cancel();
    _ringingSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startForegroundReminderWatcher();
      _runForegroundReminderCheck();
      _checkForRingingAlarms();
      _refreshNotifications();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _foregroundReminderTimer?.cancel();
    }
  }

  /// Loads local settings, database records, and notification schedules.
  Future<void> _bootstrap() async {
    await _loadPreferences();
    await _loadPlannerData();
    await _notificationService.rescheduleAll(
      assignments: _assignments,
      subjects: _subjects,
      exams: _exams,
      enableDailyReminder: _dailyReminderEnabled,
      enableOneDayReminder: _dayBeforeReminderEnabled,
      enableOneHourReminder: _hourBeforeReminderEnabled,
      enableExactTimeReminder: _exactTimeReminderEnabled,
      classAlarmTime: _classAlarmTime,
      alarmSoundPath: _alarmSoundPath,
      studentName: _studentName,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _startForegroundReminderWatcher();
      _runForegroundReminderCheck();
      _queueNotificationPermissionPrompt();
      _checkForRingingAlarms();
    }
  }

  Future<void> _loadPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _studentName = prefs.getString('student_name') ?? 'User';
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    _dailyReminderEnabled = prefs.getBool('daily_reminder') ?? true;
    _dayBeforeReminderEnabled = prefs.getBool('day_before_reminder') ?? true;
    _hourBeforeReminderEnabled = prefs.getBool('hour_before_reminder') ?? true;
    _exactTimeReminderEnabled = prefs.getBool('exact_time_reminder') ?? true;
    _alarmSoundPath = prefs.getString('alarm_sound_path') ?? 'assets/audio/alarm_clock_old.mp3';
    final int? alarmHour = prefs.getInt('class_alarm_hour');
    final int? alarmMinute = prefs.getInt('class_alarm_minute');
    if (alarmHour != null && alarmMinute != null) {
      _classAlarmTime = TimeOfDay(hour: alarmHour, minute: alarmMinute);
    }
    _isFirstOpen = prefs.getBool('is_first_open') ?? true;
  }

  /// Fetches the latest subjects and assignments from the local database.
  Future<void> _loadPlannerData() async {
    final List<Subject> subjects = await _databaseService.getSubjects();
    final List<Assignment> assignments = await _databaseService
        .getAssignments();
    final List<Exam> exams = await _databaseService.getExams();
    final List<Grade> grades = await _databaseService.getGrades();

    if (!mounted) {
      _subjects = subjects;
      _assignments = assignments;
      _exams = exams;
      _grades = grades;
      return;
    }

    setState(() {
      _subjects = subjects;
      _assignments = assignments;
      _exams = exams;
      _grades = grades;
    });
  }

  void _replaceSubjectInState(Subject subject) {
    final List<Subject> updated = List<Subject>.from(_subjects);
    final int index = updated.indexWhere(
      (Subject item) => item.id == subject.id,
    );
    if (index >= 0) {
      updated[index] = subject;
    } else {
      updated.add(subject);
    }
    updated.sort((Subject a, Subject b) => a.name.compareTo(b.name));
    if (mounted) {
      setState(() {
        _subjects = updated;
      });
    } else {
      _subjects = updated;
    }
  }

  void _removeSubjectFromState(int id) {
    final List<Subject> updated =
        _subjects.where((Subject subject) => subject.id != id).toList()
          ..sort((Subject a, Subject b) => a.name.compareTo(b.name));
    if (mounted) {
      setState(() {
        _subjects = updated;
      });
    } else {
      _subjects = updated;
    }
  }

  void _replaceAssignmentInState(Assignment assignment) {
    final List<Assignment> updated = List<Assignment>.from(_assignments);
    final int index = updated.indexWhere(
      (Assignment item) => item.id == assignment.id,
    );
    if (index >= 0) {
      updated[index] = assignment;
    } else {
      updated.add(assignment);
    }
    updated.sort(
      (Assignment a, Assignment b) => a.dueDate.compareTo(b.dueDate),
    );
    if (mounted) {
      setState(() {
        _assignments = updated;
      });
    } else {
      _assignments = updated;
    }
  }

  void _removeAssignmentFromState(int id) {
    final List<Assignment> updated =
        _assignments
            .where((Assignment assignment) => assignment.id != id)
            .toList()
          ..sort(
            (Assignment a, Assignment b) => a.dueDate.compareTo(b.dueDate),
          );
    if (mounted) {
      setState(() {
        _assignments = updated;
      });
    } else {
      _assignments = updated;
    }
  }

  void _replaceExamInState(Exam exam) {
    final List<Exam> updated = List<Exam>.from(_exams);
    final int index = updated.indexWhere((Exam item) => item.id == exam.id);
    if (index >= 0) {
      updated[index] = exam;
    } else {
      updated.add(exam);
    }
    updated.sort((Exam a, Exam b) => a.dateTime.compareTo(b.dateTime));
    if (mounted) {
      setState(() {
        _exams = updated;
      });
    } else {
      _exams = updated;
    }
  }

  void _removeExamFromState(int id) {
    final List<Exam> updated =
        _exams.where((Exam exam) => exam.id != id).toList()
          ..sort((Exam a, Exam b) => a.dateTime.compareTo(b.dateTime));
    if (mounted) {
      setState(() {
        _exams = updated;
      });
    } else {
      _exams = updated;
    }
  }

  void _replaceGradeInState(Grade grade) {
    final List<Grade> updated = List<Grade>.from(_grades)..add(grade);
    updated.sort((Grade a, Grade b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _grades = updated;
      });
    } else {
      _grades = updated;
    }
  }

  void _removeGradeFromState(int id) {
    final List<Grade> updated =
        _grades.where((Grade grade) => grade.id != id).toList()
          ..sort((Grade a, Grade b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _grades = updated;
      });
    } else {
      _grades = updated;
    }
  }

  /// Stores the student's preferred display name.
  Future<void> _saveStudentName(String name) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String sanitized = name.trim().isEmpty ? 'User' : name.trim();
    await prefs.setString('student_name', sanitized);
    await prefs.setBool('is_first_open', false);
    setState(() {
      _studentName = sanitized;
      _isFirstOpen = false;
    });
    await _refreshNotifications();
    _queueNotificationPermissionPrompt();
  }

  /// Waits until a visible screen is rendered before showing Android's permission dialog.
  void _queueNotificationPermissionPrompt() {
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoading) {
        return;
      }
      _requestNotificationPermissionIfNeeded();
    });
  }

  /// Prompts once per app data lifecycle to avoid repeated system dialogs on startup.
  /// Handles BOTH notification permission AND exact alarm permission.
  Future<void> _requestNotificationPermissionIfNeeded() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool hasPrompted =
        prefs.getBool(_notificationPermissionPromptedKey) ?? false;

    if (hasPrompted || !mounted || _isLoading) {
      // Even if we already prompted, always check exact alarm on every launch
      // because the user might have revoked it from system settings.
      await _ensureExactAlarmPermission();
      return;
    }

    // Step 1: Request POST_NOTIFICATIONS permission (system dialog)
    final bool notifGranted = await _notificationService
        .requestNotificationsPermission();

    if (notifGranted) {
      await prefs.setBool(_notificationPermissionPromptedKey, true);
    } else {
      await prefs.setBool(_notificationPermissionPromptedKey, false);
    }

    // Step 2: Request SCHEDULE_EXACT_ALARM permission
    // This is separate because on Android 12+ release builds, exact alarm
    // permission is NOT auto-granted (unlike debug builds).
    await _ensureExactAlarmPermission();

    await _refreshNotifications();

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          notifGranted
              ? 'Notifications Enabled!'
              : 'Notifications are restricted. Please check your phone settings.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Ensures exact alarm permission is granted. On Android 12+ release builds
  /// this permission is NOT automatically granted unlike debug builds.
  /// Opens the system settings page if not granted.
  Future<void> _ensureExactAlarmPermission() async {
    if (kIsWeb) return;
    await _notificationService.requestExactAlarmPermission();
  }

  /// Sends a one-tap test notification after confirming runtime access.
  Future<void> _sendTestNotification() async {
    final bool granted = await _notificationService
        .requestNotificationsPermission();

    if (!granted) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are still blocked. Please allow StudyMate in your phone settings.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _notificationService.showInstantNotification(
      title: 'Test Notification',
      body:
          'This is a test notification from StudyMate! It seems everything is working correctly.',
    );
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Test notification sent! Check your status bar.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendTestAlarm() async {
    final DateTime when = DateTime.now().add(const Duration(minutes: 1));

    await AlarmService.instance.scheduleAlarm(
      id: 9998,
      dateTime: when,
      title: 'StudyMate Test Alarm',
      body: 'If this rings, the wake-up alarm pipeline is working.',
      assetAudioPath: _alarmSoundPath,
    );

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Test alarm scheduled for ${DateFormat('hh:mm a').format(when)}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Re-requests notification access, opens exact alarm settings, and rebuilds reminders.
  Future<void> _repairNotifications() async {
    // Step 1: Request POST_NOTIFICATIONS
    final bool notifGranted = await _notificationService
        .requestNotificationsPermission();

    // Step 2: Request SCHEDULE_EXACT_ALARM (opens system settings)
    await _notificationService.requestExactAlarmPermission();

    if (notifGranted) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationPermissionPromptedKey, true);
      await _refreshNotifications();
    }

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          notifGranted
              ? 'Notifications & alarms re-enabled. Reminders were scheduled again.'
              : 'Please allow notifications AND alarms for StudyMate in your phone settings.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Polls exact reminders while the app is open to keep foreground alerts reliable.
  void _startForegroundReminderWatcher() {
    _foregroundReminderTimer?.cancel();
    _foregroundReminderTimer = Timer.periodic(
      _foregroundReminderPollInterval,
      (_) => _runForegroundReminderCheck(),
    );
  }

  /// Triggers any exact reminders whose deadline just landed while the app is active.
  Future<void> _runForegroundReminderCheck() async {
    if (!mounted || _isLoading) {
      return;
    }

    await _notificationService.deliverDueNowFallback(
      assignments: _assignments,
      exams: _exams,
      enableExactTimeReminder: _exactTimeReminderEnabled,
    );

    if (mounted) {
      setState(() {});
    }
  }

  /// Saves the current theme mode preference locally.
  Future<void> _toggleDarkMode(bool isEnabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isEnabled);
    setState(() {
      _isDarkMode = isEnabled;
    });
  }

  /// Updates notification switches and refreshes all offline reminders.
  Future<void> _updateNotificationSettings({
    bool? dailyReminder,
    bool? oneDayReminder,
    bool? oneHourReminder,
    bool? exactTimeReminder,
    TimeOfDay? classAlarmTime,
    String? alarmSoundPath,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (dailyReminder != null) {
      _dailyReminderEnabled = dailyReminder;
      await prefs.setBool('daily_reminder', dailyReminder);
    }

    if (oneDayReminder != null) {
      _dayBeforeReminderEnabled = oneDayReminder;
      await prefs.setBool('day_before_reminder', oneDayReminder);
    }

    if (oneHourReminder != null) {
      _hourBeforeReminderEnabled = oneHourReminder;
      await prefs.setBool('hour_before_reminder', oneHourReminder);
    }

    if (exactTimeReminder != null) {
      _exactTimeReminderEnabled = exactTimeReminder;
      await prefs.setBool('exact_time_reminder', exactTimeReminder);
    }

    if (classAlarmTime != null) {
      _classAlarmTime = classAlarmTime;
      await prefs.setInt('class_alarm_hour', classAlarmTime.hour);
      await prefs.setInt('class_alarm_minute', classAlarmTime.minute);
    }

    if (alarmSoundPath != null) {
      _alarmSoundPath = alarmSoundPath;
      await prefs.setString('alarm_sound_path', alarmSoundPath);
    }

    if (mounted) {
      setState(() {});
    }
    await _refreshNotifications();

    if (dailyReminder != null || classAlarmTime != null) {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Next wake-up alarm: ${_nextClassAlarmLabel()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Creates a new subject record, then syncs the UI and reminders.
  Future<void> _createSubject(Subject subject) async {
    final int id = await _databaseService.insertSubject(subject);
    _replaceSubjectInState(subject.copyWith(id: id));
    await _refreshNotifications();
  }

  /// Applies edits to an existing subject, then syncs related reminders.
  Future<void> _updateSubject(Subject subject) async {
    await _databaseService.updateSubject(subject);
    _replaceSubjectInState(subject);
    await _refreshNotifications();
  }

  /// Deletes a subject and removes any dependent assignment links by name only in the UI layer.
  Future<void> _deleteSubject(int id) async {
    await _databaseService.deleteSubject(id);
    _removeSubjectFromState(id);
    await _refreshNotifications();
  }

  /// Creates a new assignment record and schedules its due-date notifications.
  Future<void> _createAssignment(Assignment assignment) async {
    final int id = await _databaseService.insertAssignment(assignment);
    final Assignment created = assignment.copyWith(id: id);
    _replaceAssignmentInState(created);
    await _notificationService.scheduleAssignmentReminders(
      assignment: created,
      enableOneDayReminder: _dayBeforeReminderEnabled,
      enableOneHourReminder: _hourBeforeReminderEnabled,
      enableExactTimeReminder: _exactTimeReminderEnabled,
      alarmSoundPath: _alarmSoundPath,
    );
    // NOTE: Do NOT call _refreshNotifications here — it cancels what we just scheduled.
  }

  /// Updates an assignment record and reschedules notifications as needed.
  Future<void> _updateAssignment(Assignment assignment) async {
    await _databaseService.updateAssignment(assignment);
    _replaceAssignmentInState(assignment);
    await _notificationService.scheduleAssignmentReminders(
      assignment: assignment,
      enableOneDayReminder: _dayBeforeReminderEnabled,
      enableOneHourReminder: _hourBeforeReminderEnabled,
      enableExactTimeReminder: _exactTimeReminderEnabled,
      alarmSoundPath: _alarmSoundPath,
    );
  }

  /// Marks an assignment as completed or pending and keeps notifications in sync.
  Future<void> _toggleAssignmentStatus(Assignment assignment) async {
    final Assignment updated = assignment.copyWith(
      isCompleted: !assignment.isCompleted,
      completedAt: !assignment.isCompleted ? DateTime.now() : null,
    );
    await _databaseService.updateAssignment(updated);
    if (updated.isCompleted && updated.id != null) {
      await _notificationService.cancelAssignmentNotifications(updated.id!);
    }
    _replaceAssignmentInState(updated);
    if (!updated.isCompleted) {
      await _notificationService.scheduleAssignmentReminders(
        assignment: updated,
        enableOneDayReminder: _dayBeforeReminderEnabled,
        enableOneHourReminder: _hourBeforeReminderEnabled,
        enableExactTimeReminder: _exactTimeReminderEnabled,
        alarmSoundPath: _alarmSoundPath,
      );
    }
  }

  /// Removes an assignment from the database and clears its scheduled reminders.
  Future<void> _deleteAssignment(int id) async {
    await _databaseService.deleteAssignment(id);
    await _notificationService.cancelAssignmentNotifications(id);
    _removeAssignmentFromState(id);
  }

  /// Clears both app settings data and database entries after user confirmation.
  Future<void> _clearAllData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _databaseService.clearAllData();
    await _notificationService.cancelAllNotifications();
    await _notificationService.clearDeliveredReminderState();
    await prefs.remove('student_name');
    await prefs.remove('dark_mode');
    await prefs.remove('daily_reminder');
    await prefs.remove('day_before_reminder');
    await prefs.remove('hour_before_reminder');
    await prefs.remove(_notificationPermissionPromptedKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _studentName = 'User';
      _isDarkMode = false;
      _dailyReminderEnabled = true;
      _dayBeforeReminderEnabled = true;
      _hourBeforeReminderEnabled = true;
      _exactTimeReminderEnabled = true;
      _subjects = <Subject>[];
      _assignments = <Assignment>[];
      _exams = <Exam>[];
      _grades = <Grade>[];
      _selectedIndex = 0;
    });
  }

  // --- Exam Logic ---
  Future<void> _createExam(Exam exam) async {
    final int id = await _databaseService.insertExam(exam);
    final Exam created = exam.copyWith(id: id);
    _replaceExamInState(created);
    await _notificationService.scheduleExamReminders(
      exam: created,
      enableOneDayReminder: _dayBeforeReminderEnabled,
      enableOneHourReminder: _hourBeforeReminderEnabled,
      enableExactTimeReminder: _exactTimeReminderEnabled,
      alarmSoundPath: _alarmSoundPath,
    );
  }

  Future<void> _updateExam(Exam exam) async {
    await _databaseService.updateExam(exam);
    _replaceExamInState(exam);
    await _notificationService.scheduleExamReminders(
      exam: exam,
      enableOneDayReminder: _dayBeforeReminderEnabled,
      enableOneHourReminder: _hourBeforeReminderEnabled,
      enableExactTimeReminder: _exactTimeReminderEnabled,
      alarmSoundPath: _alarmSoundPath,
    );
  }

  Future<void> _deleteExam(int id) async {
    await _databaseService.deleteExam(id);
    await _notificationService.cancelExamNotifications(id);
    _removeExamFromState(id);
  }

  // --- Grade Logic ---
  Future<void> _createGrade(Grade grade) async {
    final int id = await _databaseService.insertGrade(grade);
    _replaceGradeInState(
      Grade(
        id: id,
        subject: grade.subject,
        score: grade.score,
        maxScore: grade.maxScore,
        category: grade.category,
        date: grade.date,
      ),
    );
  }

  Future<void> _deleteGrade(int id) async {
    await _databaseService.deleteGrade(id);
    _removeGradeFromState(id);
  }

  /// Rebuilds all offline reminders based on current data and settings.
  Future<void> _refreshNotifications() {
    return _notificationService.rescheduleAll(
      assignments: _assignments,
      subjects: _subjects,
      exams: _exams,
      enableDailyReminder: _dailyReminderEnabled,
      enableOneDayReminder: _dayBeforeReminderEnabled,
      enableOneHourReminder: _hourBeforeReminderEnabled,
      enableExactTimeReminder: _exactTimeReminderEnabled,
      classAlarmTime: _classAlarmTime,
      alarmSoundPath: _alarmSoundPath,
      studentName: _studentName,
    );
  }

  String _nextClassAlarmLabel({TimeOfDay? alarmTime, bool? dailyReminder}) {
    final bool isDailyReminderEnabled =
        dailyReminder ?? _dailyReminderEnabled;
    final TimeOfDay targetAlarmTime = alarmTime ?? _classAlarmTime;

    if (!isDailyReminderEnabled) {
      return 'Disabled';
    }

    final DateTime now = DateTime.now();

    for (int i = 0; i < 14; i++) {
      final DateTime candidateDate = now.add(Duration(days: i));
      final DateTime candidateAlarmTime = DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
        targetAlarmTime.hour,
        targetAlarmTime.minute,
      );

      if (candidateAlarmTime.isBefore(now)) {
        continue;
      }

      final bool hasClass = _subjects.any(
        (Subject subject) => subject.occursOn(candidateDate),
      );

      if (hasClass) {
        return DateFormat('EEE, MMM d - hh:mm a').format(candidateAlarmTime);
      }
    }

    return 'No class day found in the next 14 days';
  }

  /// Returns the daily motivational quote based on the current date.
  String _quoteForToday() {
    return 'Your journey to academic success starts here. Stay focused and keep pushing!';
  }

  /// Creates a shared Material 3 theme for light and dark modes.
  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    // TarsiWeb Palette
    const Color primaryGreen = Color(0xFF3B7A57);
    const Color secondarySage = Color(0xFF8DAA91);
    const Color backgroundBeige = Color(0xFFF7F9F2);
    const Color surfaceWhite = Color(0xFFFFFFFF);

    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFFA8D5BA) : primaryGreen,
          secondary: isDark ? const Color(0xFFC2D9C6) : secondarySage,
          surface: isDark ? const Color(0xFF1A1C19) : surfaceWhite,
          onSurface: isDark ? const Color(0xFFE2E3DD) : const Color(0xFF1A1C19),
          surfaceContainerHighest: isDark
              ? const Color(0xFF2A2D29)
              : const Color(0xFFE8ECE4),
        );

    final TextTheme textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F110E)
          : backgroundBeige,
      cardColor: isDark ? const Color(0xFF1E211D) : surfaceWhite,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1E211D) : surfaceWhite,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : primaryGreen.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2D29) : surfaceWhite,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryGreen.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryGreen.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF1A1C19) : surfaceWhite,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.4),
        elevation: 10,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1C19) : surfaceWhite,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.15),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF2A2D29) : surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  void _openSettings() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          studentName: _studentName,
          isDarkMode: _isDarkMode,
          dailyReminderEnabled: _dailyReminderEnabled,
          oneDayReminderEnabled: _dayBeforeReminderEnabled,
          oneHourReminderEnabled: _hourBeforeReminderEnabled,
          exactTimeReminderEnabled: _exactTimeReminderEnabled,
          classAlarmTime: _classAlarmTime,
          nextClassAlarmLabel: _nextClassAlarmLabel(),
          buildNextClassAlarmLabel: _nextClassAlarmLabel,
          alarmSoundPath: _alarmSoundPath,
          onSaveName: _saveStudentName,
          onToggleDarkMode: _toggleDarkMode,
          onUpdateNotifications: _updateNotificationSettings,
          onClearData: _clearAllData,
          onGrantExactAlarmPermission: () {
            _repairNotifications();
          },
          onTestAlarm: () {
            _sendTestAlarm();
          },
          onTestNotification: () {
            _sendTestNotification();
          },
        ),
      ),
    );
  }

  void _openGrades() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => GradesScreen(
          grades: _grades,
          subjects: _subjects,
          onAddGrade: _createGrade,
          onDeleteGrade: _deleteGrade,
        ),
      ),
    );
  }

  void _quickAddClass() {
    showModalBottomSheet(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubjectEditorSheet(
        onSave: (subject) async {
          Navigator.pop(context);
          await _createSubject(subject);
          setState(() => _selectedIndex = 1);
        },
      ),
    );
  }

  void _quickAddTask() {
    showModalBottomSheet(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssignmentEditorSheet(
        subjects: _subjects,
        onSave: (assignment) async {
          Navigator.pop(context);
          await _createAssignment(assignment);
          setState(() => _selectedIndex = 2);
        },
      ),
    );
  }

  void _quickAddExam() {
    showModalBottomSheet(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExamEditorSheet(
        subjects: _subjects,
        onSave: (exam) async {
          Navigator.pop(context);
          await _createExam(exam);
          setState(() => _selectedIndex = 3);
        },
      ),
    );
  }

  void _quickAddGrade() {
    showModalBottomSheet(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GradeEditorSheet(
        subjects: _subjects,
        onSave: (grade) async {
          Navigator.pop(context);
          await _createGrade(grade);
          _openGrades();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = _buildTheme(Brightness.light);
    final ThemeData darkTheme = _buildTheme(Brightness.dark);

    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      navigatorKey: _navigatorKey,
      title: 'StudyMate',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/download': (context) => const AppDownloadScreen(),
      },
      home: kIsWeb
          ? const AppDownloadScreen()
          : _isLoading
              ? const _LoadingScreen()
              : _isFirstOpen
                  ? OnboardingScreen(onFinish: _saveStudentName)
                  : MainNavigationShell(
                  selectedIndex: _selectedIndex,
                  onSelectTab: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  onOpenSettings: _openSettings,
                  onOpenGrades: _openGrades,
                  screens: <Widget>[
                    HomeScreen(
                      studentName: _studentName,
                      todaySubjects: List<Subject>.from(_subjects),
                      assignments: _assignments,
                      quote: _quoteForToday(),
                      onAddClass: _quickAddClass,
                      onAddTask: _quickAddTask,
                      onAddExam: _quickAddExam,
                      onAddGrade: _quickAddGrade,
                    ),
                    ScheduleScreen(
                      subjects: _subjects,
                      onAddSubject: _createSubject,
                      onUpdateSubject: _updateSubject,
                      onDeleteSubject: _deleteSubject,
                    ),
                    AssignmentScreen(
                      assignments: _assignments,
                      subjects: _subjects,
                      onAddAssignment: _createAssignment,
                      onUpdateAssignment: _updateAssignment,
                      onToggleStatus: _toggleAssignmentStatus,
                      onDeleteAssignment: _deleteAssignment,
                    ),
                    ExamsScreen(
                      exams: _exams,
                      subjects: _subjects,
                      onAddExam: _createExam,
                      onUpdateExam: _updateExam,
                      onDeleteExam: _deleteExam,
                    ),
                    const FocusTimerScreen(),
                  ],
                ),
    );
  }
}

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
    required this.screens,
    required this.onOpenSettings,
    required this.onOpenGrades,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final List<Widget> screens;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenGrades;

  /// Wraps tab changes in a smooth fade-and-slide transition.
  @override
  Widget build(BuildContext context) {
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          selectedIndex == 0 ? 'Dashboard' :
          selectedIndex == 1 ? 'Class Schedule' :
          selectedIndex == 2 ? 'My Tasks' :
          selectedIndex == 3 ? 'Exams' : 'Focus Timer',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: onOpenGrades,
            tooltip: 'Grades',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: onOpenSettings,
            tooltip: 'Profile',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final Animation<Offset> offsetAnimation =
                Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(selectedIndex),
            child: screens[selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelectTab,
          height: 80,
          elevation: 0,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Schedule',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_edu_outlined),
              selectedIcon: Icon(Icons.history_edu_rounded),
              label: 'Exams',
            ),
            NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer_rounded),
              label: 'Focus',
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.5 + (value * 0.5),
                  child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                );
              },
              child: const AppLogo(size: 100, isSquare: true),
            ),
            const SizedBox(height: 32),
            Text(
              'STUDYMATE',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                color: const Color(0xFF2563EB),
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
