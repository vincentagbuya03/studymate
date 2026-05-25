import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/assignment.dart';
import 'models/exam.dart';
import 'models/grade.dart';
import 'models/subject.dart';
import 'firebase_options.dart';
import 'screens/assignment_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/exams_screen.dart';
import 'screens/focus_timer_screen.dart';
import 'screens/grades_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';
import 'services/cloud_planner_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'screens/alarm_ring_screen.dart';
import 'widgets/app_logo.dart';
import 'widgets/editor_sheets.dart';
import 'web/admin_panel_screen.dart';
import 'web/app_download_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CloudPlannerService.instance.enableOfflinePersistence();
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
  final CloudPlannerService _plannerService = CloudPlannerService.instance;
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
  bool _isAdmin = false;
  String? _disabledMessage;
  bool _waitingForExactAlarmPermission = false;
  bool _notificationRefreshRunning = false;
  bool _notificationRefreshQueued = false;
  Timer? _foregroundReminderTimer;
  User? _user;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<PlannerSnapshot>? _plannerSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = AuthService.instance.authStateChanges.listen(
      _handleAuthChanged,
    );
    _listenToAlarms();
  }

  Future<void> _handleAuthChanged(User? user) async {
    _plannerSubscription?.cancel();
    _profileSubscription?.cancel();

    if (user == null) {
      _foregroundReminderTimer?.cancel();
      if (mounted) {
        setState(() {
          _user = null;
          _isAdmin = false;
          _disabledMessage = null;
          _isLoading = false;
          _subjects = <Subject>[];
          _assignments = <Assignment>[];
          _exams = <Exam>[];
          _grades = <Grade>[];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = true;
        _disabledMessage = null;
      });
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isFirstOpen = prefs.getBool('is_first_open') ?? false;

    try {
      await AuthService.instance.ensureUserProfile(
        seedDisplayNameFromEmail: !isFirstOpen,
      );
    } on FirebaseException catch (e) {
      debugPrint(
        '[Auth Bootstrap] Profile sync failed: ${e.code} ${e.message}',
      );
      if (e.code == 'permission-denied') {
        await AuthService.instance.signOut();
        if (mounted) {
          setState(() {
            _disabledMessage =
                'StudyMate could not open your profile. Please check that Firestore rules are deployed, then try again.';
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[Auth Bootstrap] Profile sync unavailable: $e');
    }

    try {
      await _loadAdminClaim(user);
    } catch (e) {
      debugPrint('[Auth Bootstrap] Admin claim unavailable offline: $e');
      _isAdmin = false;
    }

    await _bootstrap();

    try {
      _startCloudListeners();
    } catch (e) {
      debugPrint('[Auth Bootstrap] Real-time sync unavailable: $e');
    }
  }

  Future<void> _loadAdminClaim(User user) async {
    final IdTokenResult token = await user.getIdTokenResult();
    _isAdmin = token.claims?['admin'] == true;
  }

  void _startCloudListeners() {
    _profileSubscription = _plannerService.watchUserProfile().listen(
      (snapshot) async {
        final data = snapshot.data();
        if (data == null) {
          return;
        }
        if (data['disabled'] == true) {
          await _handleDisabledAccount();
          return;
        }

        final String? displayName = data['displayName'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          final String trimmedDisplayName = displayName.trim();
          if (mounted && _studentName != trimmedDisplayName) {
            setState(() {
              _studentName = trimmedDisplayName;
            });
            if (!_isFirstOpen) {
              await _refreshNotifications();
            }
          }
        }
      },
      onError: (Object error) {
        debugPrint('[Auth Profile] Listener failed: $error');
        _handleCloudPermissionError(error);
      },
    );

    _plannerSubscription = _plannerService.watchPlanner().listen(
      (PlannerSnapshot snapshot) async {
        if (!mounted) {
          _subjects = snapshot.subjects;
          _assignments = snapshot.assignments;
          _exams = snapshot.exams;
          _grades = snapshot.grades;
          return;
        }
        setState(() {
          _subjects = snapshot.subjects;
          _assignments = snapshot.assignments;
          _exams = snapshot.exams;
          _grades = snapshot.grades;
        });
        await _refreshNotifications();
      },
      onError: (Object error) {
        debugPrint('[Planner Sync] Listener failed: $error');
        _handleCloudPermissionError(error);
      },
    );
  }

  Future<void> _handleDisabledAccount() async {
    await _notificationService.cancelTrackedNotifications(
      assignments: _assignments,
      exams: _exams,
    );
    await AuthService.instance.signOut();
    if (mounted) {
      setState(() {
        _disabledMessage = 'This StudyMate account has been disabled.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCloudPermissionError(Object error) async {
    final String raw = error.toString().toLowerCase();
    if (!raw.contains('permission-denied') &&
        !raw.contains('permission_denied')) {
      if (mounted) {
        setState(() {
          _disabledMessage = error.toString();
        });
      }
      return;
    }

    await AuthService.instance.signOut();
    if (mounted) {
      setState(() {
        _disabledMessage =
            'StudyMate could not access your cloud profile. Please deploy the latest Firestore rules and sign in again.';
        _isLoading = false;
      });
    }
  }

  StreamSubscription? _ringingSubscription;

  void _listenToAlarms() {
    _ringingSubscription = AlarmService.instance.ringingStream.listen((
      alarmSet,
    ) {
      if (!mounted) return;
      for (final settings in alarmSet.alarms) {
        _showAlarmRingScreen(
          settings.id,
          settings.dateTime,
          settings.notificationSettings.title,
          settings.notificationSettings.body,
        );
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
        _showAlarmRingScreen(
          settings.id,
          settings.dateTime,
          settings.notificationSettings.title,
          settings.notificationSettings.body,
        );
      });
    }
  }

  bool _isAlarmScreenShowing = false;

  void _showAlarmRingScreen(
    int alarmId,
    DateTime alarmDateTime,
    String title,
    String body,
  ) {
    if (!mounted || _isAlarmScreenShowing) return;
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAlarmRingScreen(alarmId, alarmDateTime, title, body);
      });
      return;
    }

    _isAlarmScreenShowing = true;

    navigator
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) =>
                AlarmRingScreen(alarmId: alarmId, title: title, body: body),
          ),
        )
        .then((bool? stopped) async {
          _isAlarmScreenShowing = false;
          if (stopped == true) {
            await _notificationService.markDailyReminderHandled(
              alarmId: alarmId,
              alarmDateTime: alarmDateTime,
            );
          }
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundReminderTimer?.cancel();
    _authSubscription?.cancel();
    _plannerSubscription?.cancel();
    _profileSubscription?.cancel();
    _ringingSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startForegroundReminderWatcher();
      _runForegroundReminderCheck();
      _checkForRingingAlarms();
      _rescheduleIfExactAlarmPermissionRecovered();
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
    try {
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
    } finally {
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
  }

  Future<void> _loadPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('prompted_rating_session');
    final String? firebaseDisplayName = _user?.displayName;
    final bool hasFirebaseDisplayName =
        firebaseDisplayName?.trim().isNotEmpty == true;
    _studentName = hasFirebaseDisplayName
        ? firebaseDisplayName!.trim()
        : _user?.email?.split('@').first ?? 'User';
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    _dailyReminderEnabled = prefs.getBool('daily_reminder') ?? true;
    _dayBeforeReminderEnabled = prefs.getBool('day_before_reminder') ?? true;
    _hourBeforeReminderEnabled = prefs.getBool('hour_before_reminder') ?? true;
    _exactTimeReminderEnabled = prefs.getBool('exact_time_reminder') ?? true;
    _alarmSoundPath =
        prefs.getString('alarm_sound_path') ??
        'assets/audio/alarm_clock_old.mp3';
    final int? alarmHour = prefs.getInt('class_alarm_hour');
    final int? alarmMinute = prefs.getInt('class_alarm_minute');
    if (alarmHour != null && alarmMinute != null) {
      _classAlarmTime = TimeOfDay(hour: alarmHour, minute: alarmMinute);
    }
    _isFirstOpen = prefs.getBool('is_first_open') ?? !hasFirebaseDisplayName;
  }

  /// Fetches the latest subjects and assignments from the local database.
  Future<void> _loadPlannerData() async {
    try {
      final PlannerSnapshot snapshot = await _plannerService.loadPlannerData();
      final List<Subject> subjects = snapshot.subjects;
      final List<Assignment> assignments = snapshot.assignments;
      final List<Exam> exams = snapshot.exams;
      final List<Grade> grades = snapshot.grades;

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
    } on TimeoutException catch (e) {
      debugPrint('[Planner Bootstrap] Timed out loading cloud data: $e');
      if (!mounted) {
        _subjects = <Subject>[];
        _assignments = <Assignment>[];
        _exams = <Exam>[];
        _grades = <Grade>[];
        return;
      }

      setState(() {
        _subjects = <Subject>[];
        _assignments = <Assignment>[];
        _exams = <Exam>[];
        _grades = <Grade>[];
      });
    } catch (e) {
      debugPrint('[Planner Bootstrap] Cloud data unavailable: $e');
      if (!mounted) {
        _subjects = <Subject>[];
        _assignments = <Assignment>[];
        _exams = <Exam>[];
        _grades = <Grade>[];
        return;
      }

      setState(() {
        _subjects = <Subject>[];
        _assignments = <Assignment>[];
        _exams = <Exam>[];
        _grades = <Grade>[];
      });
    }
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
    await AuthService.instance.updateDisplayName(sanitized);
    await prefs.setBool('is_first_open', false);
    setState(() {
      _studentName = sanitized;
      _isFirstOpen = false;
    });
    await _refreshNotifications();
    _queueNotificationPermissionPrompt();
  }

  void _queueNotificationPermissionPrompt() {
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoading) {
        return;
      }
      _requestNotificationPermissionIfNeeded();
    });
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool hasPrompted =
        prefs.getBool(_notificationPermissionPromptedKey) ?? false;

    if (!mounted || _isLoading) {
      return;
    }

    if (hasPrompted) {
      // Even if we already prompted, always check exact alarm on every launch
      // because the user might have revoked it from system settings.
      await _ensureExactAlarmPermission(rescheduleIfGranted: true);
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
    final bool exactAlarmGranted = await _ensureExactAlarmPermission(
      rescheduleIfGranted: false,
    );

    await _refreshNotifications();

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          notifGranted && exactAlarmGranted
              ? 'Notifications Enabled!'
              : notifGranted
              ? 'Notifications enabled, but exact alarms still need Alarms & reminders permission.'
              : 'Notifications are restricted. Please check your phone settings.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Ensures exact alarm permission is granted. On Android 12+ release builds
  /// this permission is NOT automatically granted unlike debug builds.
  /// Opens the system settings page if not granted.
  Future<bool> _ensureExactAlarmPermission({
    bool rescheduleIfGranted = false,
  }) async {
    if (kIsWeb) return true;
    final bool alreadyGranted = await _notificationService
        .checkExactAlarmPermission();
    if (alreadyGranted) {
      _waitingForExactAlarmPermission = false;
      return true;
    }

    _waitingForExactAlarmPermission = true;
    final bool granted = await _notificationService
        .requestExactAlarmPermission();
    if (granted) {
      _waitingForExactAlarmPermission = false;
      if (rescheduleIfGranted) {
        await _refreshNotifications();
      }
      return true;
    }

    if (!granted) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Exact alarms are still blocked. Enable Alarms & reminders for StudyMate in Android settings.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  Future<void> _rescheduleIfExactAlarmPermissionRecovered() async {
    if (!_waitingForExactAlarmPermission || !mounted || _isLoading) {
      return;
    }

    final bool granted = await _notificationService.checkExactAlarmPermission();
    if (!granted) {
      return;
    }

    _waitingForExactAlarmPermission = false;
    await _refreshNotifications();
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Alarms re-enabled. Reminders were scheduled again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    final bool notifGranted = await _notificationService
        .requestNotificationsPermission();
    if (!notifGranted) {
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

    final bool exactAlarmGranted = await _ensureExactAlarmPermission();
    if (!exactAlarmGranted) {
      return;
    }

    final DateTime when = DateTime.now().add(const Duration(minutes: 1));

    final bool scheduled = await AlarmService.instance.scheduleAlarm(
      id: 9998,
      dateTime: when,
      title: 'StudyMate Test Alarm',
      body: 'If this rings, the wake-up alarm pipeline is working.',
      assetAudioPath: _alarmSoundPath,
    );

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? 'Test alarm scheduled for ${DateFormat('hh:mm a').format(when)}.'
              : 'Android did not accept the test alarm. Check Alarms & reminders permission.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAlarmDiagnostics() async {
    final bool exactAlarmGranted = await _notificationService
        .checkExactAlarmPermission();
    final List<dynamic> alarms = await AlarmService.instance
        .getScheduledAlarms();
    final String nextWakeUpAlarm = _nextClassAlarmLabel();

    if (!mounted) {
      return;
    }

    final StringBuffer details = StringBuffer()
      ..writeln(
        'Exact alarm permission: ${exactAlarmGranted ? 'granted' : 'blocked'}',
      )
      ..writeln('Wake-up setting: $nextWakeUpAlarm')
      ..writeln('Scheduled native alarms: ${alarms.length}');

    if (alarms.isNotEmpty) {
      details.writeln();
      details.writeln('Next alarms:');
      for (final dynamic alarm in alarms.take(5)) {
        details.writeln(
          '- ID ${alarm.id}: ${DateFormat('MMM d, hh:mm a').format(alarm.dateTime)}',
        );
      }
    }

    await showDialog<void>(
      context: _navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Wake-up Diagnostics'),
          content: SingleChildScrollView(child: Text(details.toString())),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Re-requests notification access, opens exact alarm settings, and rebuilds reminders.
  Future<void> _repairNotifications() async {
    // Step 1: Request POST_NOTIFICATIONS
    final bool notifGranted = await _notificationService
        .requestNotificationsPermission();

    // Step 2: Request SCHEDULE_EXACT_ALARM (opens system settings)
    final bool exactAlarmGranted = await _ensureExactAlarmPermission(
      rescheduleIfGranted: false,
    );

    if (notifGranted && exactAlarmGranted) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationPermissionPromptedKey, true);
      await _refreshNotifications();
    }

    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          notifGranted && exactAlarmGranted
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
      final String nextWakeUpAlarm = _nextClassAlarmLabel();
      final String message = switch (nextWakeUpAlarm) {
        'Disabled' => 'Wake-up alarm is disabled.',
        'No class day found in the next 14 days' =>
          'No wake-up alarm scheduled. Add a class day first, then set the wake-up time again.',
        _ => 'Next wake-up alarm: $nextWakeUpAlarm',
      };

      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Creates a new subject record, then syncs the UI and reminders.
  Future<void> _createSubject(Subject subject) async {
    final Subject created = await _plannerService.upsertSubject(subject);
    _replaceSubjectInState(created);
    await _refreshNotifications();
  }

  /// Applies edits to an existing subject, then syncs related reminders.
  Future<void> _updateSubject(Subject subject) async {
    final Subject updated = await _plannerService.upsertSubject(subject);
    _replaceSubjectInState(updated);
    await _refreshNotifications();
  }

  /// Deletes a subject and removes any dependent assignment links by name only in the UI layer.
  Future<void> _deleteSubject(int id) async {
    Subject? subject;
    for (final Subject item in _subjects) {
      if (item.id == id) {
        subject = item;
        break;
      }
    }
    if (subject != null) {
      await _plannerService.deleteSubject(subject);
    }
    _removeSubjectFromState(id);
    await _refreshNotifications();
  }

  /// Creates a new assignment record and schedules its due-date notifications.
  Future<void> _createAssignment(Assignment assignment) async {
    final Assignment created = await _plannerService.upsertAssignment(
      assignment,
    );
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
    final Assignment updated = await _plannerService.upsertAssignment(
      assignment,
    );
    _replaceAssignmentInState(updated);
    await _notificationService.scheduleAssignmentReminders(
      assignment: updated,
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
    final Assignment saved = await _plannerService.upsertAssignment(updated);
    if (saved.isCompleted && saved.id != null) {
      await _notificationService.cancelAssignmentNotifications(saved.id!);
    }
    _replaceAssignmentInState(saved);
    if (!saved.isCompleted) {
      await _notificationService.scheduleAssignmentReminders(
        assignment: saved,
        enableOneDayReminder: _dayBeforeReminderEnabled,
        enableOneHourReminder: _hourBeforeReminderEnabled,
        enableExactTimeReminder: _exactTimeReminderEnabled,
        alarmSoundPath: _alarmSoundPath,
      );
    }
  }

  /// Removes an assignment from the database and clears its scheduled reminders.
  Future<void> _deleteAssignment(int id) async {
    Assignment? assignment;
    for (final Assignment item in _assignments) {
      if (item.id == id) {
        assignment = item;
        break;
      }
    }
    if (assignment != null) {
      await _plannerService.deleteAssignment(assignment);
    }
    await _notificationService.cancelAssignmentNotifications(id);
    _removeAssignmentFromState(id);
  }

  /// Clears both app settings data and database entries after user confirmation.
  Future<void> _clearAllData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _notificationService.cancelTrackedNotifications(
      assignments: _assignments,
      exams: _exams,
    );
    await _plannerService.clearPlannerData();
    await _notificationService.cancelAllNotifications();
    await _notificationService.clearDeliveredReminderState();
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

  Future<void> _signOut() async {
    await _notificationService.cancelTrackedNotifications(
      assignments: _assignments,
      exams: _exams,
    );
    await AuthService.instance.signOut();

    if (!mounted) {
      return;
    }

    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (Route<dynamic> route) => false,
    );
  }

  // --- Exam Logic ---
  Future<void> _createExam(Exam exam) async {
    final Exam created = await _plannerService.upsertExam(exam);
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
    final Exam updated = await _plannerService.upsertExam(exam);
    _replaceExamInState(updated);
    await _notificationService.scheduleExamReminders(
      exam: updated,
      enableOneDayReminder: _dayBeforeReminderEnabled,
      enableOneHourReminder: _hourBeforeReminderEnabled,
      enableExactTimeReminder: _exactTimeReminderEnabled,
      alarmSoundPath: _alarmSoundPath,
    );
  }

  Future<void> _deleteExam(int id) async {
    Exam? exam;
    for (final Exam item in _exams) {
      if (item.id == id) {
        exam = item;
        break;
      }
    }
    if (exam != null) {
      await _plannerService.deleteExam(exam);
    }
    await _notificationService.cancelExamNotifications(id);
    _removeExamFromState(id);
  }

  // --- Grade Logic ---
  Future<void> _createGrade(Grade grade) async {
    final Grade created = await _plannerService.upsertGrade(grade);
    _replaceGradeInState(created);
  }

  Future<void> _deleteGrade(int id) async {
    Grade? grade;
    for (final Grade item in _grades) {
      if (item.id == id) {
        grade = item;
        break;
      }
    }
    if (grade != null) {
      await _plannerService.deleteGrade(grade);
    }
    _removeGradeFromState(id);
  }

  /// Rebuilds all offline reminders based on current data and settings.
  Future<void> _refreshNotifications() async {
    if (_notificationRefreshRunning) {
      _notificationRefreshQueued = true;
      return;
    }

    _notificationRefreshRunning = true;
    try {
      do {
        _notificationRefreshQueued = false;
        await _notificationService.rescheduleAll(
          assignments: List<Assignment>.from(_assignments),
          subjects: List<Subject>.from(_subjects),
          exams: List<Exam>.from(_exams),
          enableDailyReminder: _dailyReminderEnabled,
          enableOneDayReminder: _dayBeforeReminderEnabled,
          enableOneHourReminder: _hourBeforeReminderEnabled,
          enableExactTimeReminder: _exactTimeReminderEnabled,
          classAlarmTime: _classAlarmTime,
          alarmSoundPath: _alarmSoundPath,
          studentName: _studentName,
        );
      } while (_notificationRefreshQueued && mounted);
    } finally {
      _notificationRefreshRunning = false;
    }
  }

  String _nextClassAlarmLabel({TimeOfDay? alarmTime, bool? dailyReminder}) {
    final bool isDailyReminderEnabled = dailyReminder ?? _dailyReminderEnabled;
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

    final TextTheme textTheme = ThemeData(brightness: brightness).textTheme
        .apply(
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
        titleTextStyle: TextStyle(
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
        labelStyle: TextStyle(fontWeight: FontWeight.w500),
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
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
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
          onSignOut: _signOut,
          onShowAlarmDiagnostics: () {
            _showAlarmDiagnostics();
          },
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

  String _currentWebRoute() {
    if (!kIsWeb) {
      return '/';
    }

    final Uri uri = Uri.base;
    final String fragment = uri.fragment.trim();
    if (fragment.isNotEmpty) {
      return fragment.startsWith('/') ? fragment : '/$fragment';
    }

    final String path = uri.path.trim();
    if (path.isEmpty) {
      return '/';
    }

    return path.startsWith('/') ? path : '/$path';
  }

  Widget _buildAuthenticatedShell() {
    if (_isLoading) {
      return const _LoadingScreen();
    }

    if (_isFirstOpen) {
      return OnboardingScreen(onFinish: _saveStudentName);
    }

    return MainNavigationShell(
      selectedIndex: _selectedIndex,
      onSelectTab: (int index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      onOpenSettings: _openSettings,
      onOpenGrades: _openGrades,
      onOpenAdmin: kIsWeb && _isAdmin
          ? () => _navigatorKey.currentState?.pushNamed('/admin')
          : null,
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
    );
  }

  Widget _buildWebHome() {
    final String route = _currentWebRoute();

    if (route == '/admin' || route == '/admin-login') {
      if (_user == null) {
        return const AuthScreen(
          initialMessage:
              'Sign in with an admin account to open the admin panel.',
        );
      }
      if (_isLoading) {
        return const _LoadingScreen();
      }
      if (!_isAdmin) {
        return const _WebAccessDeniedScreen(
          title: 'Admin Access Required',
          message: 'This page is only available for admin accounts.',
        );
      }
      return const AdminPanelScreen();
    }

    if (route == '/app' || route == '/login') {
      if (_user == null) {
        return AuthScreen(initialMessage: _disabledMessage);
      }
      return _buildAuthenticatedShell();
    }

    return const AppDownloadScreen();
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
      routes: <String, WidgetBuilder>{
        '/download': (context) => const AppDownloadScreen(),
        '/login': (context) => AuthScreen(initialMessage: _disabledMessage),
        '/app': (context) => _user == null
            ? AuthScreen(initialMessage: _disabledMessage)
            : _buildAuthenticatedShell(),
        '/admin-login': (context) => const AuthScreen(
          initialMessage:
              'Sign in with an admin account to open the admin panel.',
        ),
        if (kIsWeb) '/admin': (context) => const AdminPanelScreen(),
      },
      home: kIsWeb
          ? _buildWebHome()
          : _user == null
          ? AuthScreen(initialMessage: _disabledMessage)
          : _buildAuthenticatedShell(),
    );
  }
}

class _WebAccessDeniedScreen extends StatelessWidget {
  const _WebAccessDeniedScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    this.onOpenAdmin,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final List<Widget> screens;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenGrades;
  final VoidCallback? onOpenAdmin;

  /// Wraps tab changes in a smooth fade-and-slide transition.
  @override
  Widget build(BuildContext context) {
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          selectedIndex == 0
              ? 'Dashboard'
              : selectedIndex == 1
              ? 'Class Schedule'
              : selectedIndex == 2
              ? 'My Tasks'
              : selectedIndex == 3
              ? 'Exams'
              : 'Focus Timer',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (onOpenAdmin != null)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: onOpenAdmin,
              tooltip: 'Admin',
            ),
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
              style: TextStyle(
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
