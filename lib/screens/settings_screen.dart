import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.studentName,
    required this.isDarkMode,
    required this.dailyReminderEnabled,
    required this.oneDayReminderEnabled,
    required this.oneHourReminderEnabled,
    required this.exactTimeReminderEnabled,
    required this.onSaveName,
    required this.onToggleDarkMode,
    required this.onUpdateNotifications,
    required this.onClearData,
    required this.onTestNotification,
    required this.onGrantExactAlarmPermission,
  });

  final String studentName;
  final bool isDarkMode;
  final bool dailyReminderEnabled;
  final bool oneDayReminderEnabled;
  final bool oneHourReminderEnabled;
  final bool exactTimeReminderEnabled;
  final Future<void> Function(String name) onSaveName;
  final Future<void> Function(bool value) onToggleDarkMode;
  final Future<void> Function({
    bool? dailyReminder,
    bool? oneDayReminder,
    bool? oneHourReminder,
    bool? exactTimeReminder,
  })
  onUpdateNotifications;
  final Future<void> Function() onClearData;
  final VoidCallback onTestNotification;
  final VoidCallback onGrantExactAlarmPermission;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.studentName);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentName != widget.studentName &&
        _nameController.text != widget.studentName) {
      _nameController.text = widget.studentName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Confirms before permanently clearing all locally saved planner data.
  Future<void> _confirmClearData() async {
    final bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear all data?'),
          content: const Text(
            'This will delete your subjects, assignments, and saved preferences on this device.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      await widget.onClearData();
      if (mounted) {
        _nameController.text = 'Iskolar';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: <Widget>[
        const SizedBox(height: 12),
        _ProfileHeader(studentName: widget.studentName),
        const SizedBox(height: 32),
        _SectionCard(
          title: 'Student Profile',
          child: Column(
            children: <Widget>[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Student name',
                  hintText: 'Enter your name',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => widget.onSaveName(_nameController.text),
                  child: const Text('Save Name'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Notifications',
          child: Column(
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily 7:00 AM schedule reminder'),
                subtitle: const Text('Starts your morning with class updates'),
                value: widget.dailyReminderEnabled,
                onChanged: (bool value) =>
                    widget.onUpdateNotifications(dailyReminder: value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('1 day before due date'),
                subtitle: const Text('Advance reminder for assignments'),
                value: widget.oneDayReminderEnabled,
                onChanged: (bool value) =>
                    widget.onUpdateNotifications(oneDayReminder: value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('1 hour before due date'),
                subtitle: const Text('Last-minute deadline reminder'),
                value: widget.oneHourReminderEnabled,
                onChanged: (bool value) =>
                    widget.onUpdateNotifications(oneHourReminder: value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Exact due time'),
                subtitle: const Text('Notify when the deadline is reached'),
                value: widget.exactTimeReminderEnabled,
                onChanged: (bool value) =>
                    widget.onUpdateNotifications(exactTimeReminder: value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onTestNotification,
                    icon: const Icon(Icons.notification_important_rounded),
                    label: const Text('Test Notification'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onGrantExactAlarmPermission,
                    icon: const Icon(Icons.alarm_on_rounded),
                    label: const Text('Fix Reminders'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Appearance',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dark mode'),
            subtitle: const Text(
              'Easy on the eyes during late-night study sessions',
            ),
            value: widget.isDarkMode,
            onChanged: widget.onToggleDarkMode,
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'App Actions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Reset everything stored on this device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _confirmClearData,
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Clear All Data'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionCard(
          title: 'About StudyMate',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'StudyMate is a fully offline student planner designed for learners who want a simple, beautiful way to manage class schedules and deadlines.',
              ),
              SizedBox(height: 10),
              Text(
                'Built with Flutter, SQLite, local notifications, and zero internet dependency.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.studentName});

  final String studentName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          studentName,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          'Iskolar ng Bayan',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
