import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.studentName,
    required this.isDarkMode,
    required this.dailyReminderEnabled,
    required this.oneDayReminderEnabled,
    required this.oneHourReminderEnabled,
    required this.exactTimeReminderEnabled,
    required this.classAlarmTime,
    required this.nextClassAlarmLabel,
    required this.buildNextClassAlarmLabel,
    required this.alarmSoundPath,
    required this.onSaveName,
    required this.onToggleDarkMode,
    required this.onUpdateNotifications,
    required this.onClearData,
    required this.onTestNotification,
    required this.onTestAlarm,
    required this.onShowAlarmDiagnostics,
    required this.onGrantExactAlarmPermission,
  });

  final String studentName;
  final bool isDarkMode;
  final bool dailyReminderEnabled;
  final bool oneDayReminderEnabled;
  final bool oneHourReminderEnabled;
  final bool exactTimeReminderEnabled;
  final TimeOfDay classAlarmTime;
  final String nextClassAlarmLabel;
  final String Function({TimeOfDay? alarmTime, bool? dailyReminder})
  buildNextClassAlarmLabel;
  final String alarmSoundPath;
  final Future<void> Function(String name) onSaveName;
  final Future<void> Function(bool value) onToggleDarkMode;
  final Future<void> Function({
    bool? dailyReminder,
    bool? oneDayReminder,
    bool? oneHourReminder,
    bool? exactTimeReminder,
    TimeOfDay? classAlarmTime,
    String? alarmSoundPath,
  })
  onUpdateNotifications;
  final Future<void> Function() onClearData;
  final VoidCallback onTestNotification;
  final VoidCallback onTestAlarm;
  final VoidCallback onShowAlarmDiagnostics;
  final VoidCallback onGrantExactAlarmPermission;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  late bool _dailyReminderEnabled;
  late TimeOfDay _classAlarmTime;
  late String _nextClassAlarmLabel;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.studentName);
    _dailyReminderEnabled = widget.dailyReminderEnabled;
    _classAlarmTime = widget.classAlarmTime;
    _nextClassAlarmLabel = widget.nextClassAlarmLabel;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentName != widget.studentName &&
        _nameController.text != widget.studentName) {
      _nameController.text = widget.studentName;
    }
    if (oldWidget.dailyReminderEnabled != widget.dailyReminderEnabled) {
      _dailyReminderEnabled = widget.dailyReminderEnabled;
    }
    if (oldWidget.classAlarmTime != widget.classAlarmTime) {
      _classAlarmTime = widget.classAlarmTime;
    }
    if (oldWidget.nextClassAlarmLabel != widget.nextClassAlarmLabel) {
      _nextClassAlarmLabel = widget.nextClassAlarmLabel;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAlarmSound() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        final File selectedFile = File(result.files.single.path!);
        final Directory appDocsDir = await getApplicationDocumentsDirectory();
        final String newFileName =
            'custom_alarm_${DateTime.now().millisecondsSinceEpoch}${p.extension(selectedFile.path)}';
        final String newFilePath = p.join(appDocsDir.path, newFileName);

        await selectedFile.copy(newFilePath);

        await widget.onUpdateNotifications(alarmSoundPath: newFilePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alarm sound updated!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  Future<void> _confirmClearData() async {
    final bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Destructive Action',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.redAccent,
            ),
          ),
          content: const Text(
            'Are you absolutely sure? This will permanently delete your subjects, assignments, and saved preferences.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Clear Everything'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        children: <Widget>[
          _ProfileHeader(studentName: widget.studentName),
          const SizedBox(height: 32),

          _SectionTitle(title: 'PERSONAL INFO'),
          _SectionCard(
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save_rounded),
                      onPressed: () {
                        if (_nameController.text.trim().isNotEmpty) {
                          widget.onSaveName(_nameController.text.trim());
                        }
                      },
                    ),
                  ),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle(title: 'DAILY WAKE-UP ALARM'),
          _SectionCard(
            child: Column(
              children: <Widget>[
                _SettingsTile(
                  title: 'Class Day Wake-up',
                  subtitle: 'Rings only on days you have classes',
                  trailing: Switch(
                    value: _dailyReminderEnabled,
                    onChanged: (bool v) {
                      setState(() {
                        _dailyReminderEnabled = v;
                        _nextClassAlarmLabel = widget.buildNextClassAlarmLabel(
                          dailyReminder: v,
                        );
                      });
                      widget.onUpdateNotifications(dailyReminder: v);
                    },
                  ),
                  icon: Icons.auto_awesome_rounded,
                  iconColor: Colors.amber,
                ),
                if (_dailyReminderEnabled) ...[
                  const _CustomDivider(),
                  _ActionTile(
                    title: 'Wake-up Time',
                    subtitle:
                        'Current: ${_classAlarmTime.format(context)}\nNext: $_nextClassAlarmLabel',
                    icon: Icons.access_time_filled_rounded,
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _classAlarmTime,
                      );
                      if (picked != null) {
                        setState(() {
                          _classAlarmTime = picked;
                          _nextClassAlarmLabel = widget
                              .buildNextClassAlarmLabel(alarmTime: picked);
                        });
                        widget.onUpdateNotifications(classAlarmTime: picked);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle(title: 'TASK & EXAM REMINDERS'),
          _SectionCard(
            child: Column(
              children: <Widget>[
                _SettingsTile(
                  title: '24h Advance Warning',
                  subtitle: 'Rings 1 day before due date',
                  trailing: Switch(
                    value: widget.oneDayReminderEnabled,
                    onChanged: (bool v) =>
                        widget.onUpdateNotifications(oneDayReminder: v),
                  ),
                  icon: Icons.event_note_rounded,
                  iconColor: Colors.blue,
                ),
                const _CustomDivider(),
                _SettingsTile(
                  title: 'Final Hour Alert',
                  subtitle: 'Rings 1 hour before deadline',
                  trailing: Switch(
                    value: widget.oneHourReminderEnabled,
                    onChanged: (bool v) =>
                        widget.onUpdateNotifications(oneHourReminder: v),
                  ),
                  icon: Icons.notification_important_rounded,
                  iconColor: Colors.orange,
                ),
                const _CustomDivider(),
                _SettingsTile(
                  title: 'Class/Exam Start',
                  subtitle: 'Rings exactly when starting',
                  trailing: Switch(
                    value: widget.exactTimeReminderEnabled,
                    onChanged: (bool v) =>
                        widget.onUpdateNotifications(exactTimeReminder: v),
                  ),
                  icon: Icons.alarm_on_rounded,
                  iconColor: Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle(title: 'PREFERENCES'),
          _SectionCard(
            child: Column(
              children: <Widget>[
                _ActionTile(
                  title: 'Alarm Sound',
                  subtitle: widget.alarmSoundPath.contains('/')
                      ? p.basename(widget.alarmSoundPath)
                      : 'System Default',
                  icon: Icons.music_note_rounded,
                  onTap: _pickAlarmSound,
                ),
                const _CustomDivider(),
                _SettingsTile(
                  title: 'Dark Theme',
                  subtitle: 'Night-friendly interface',
                  trailing: Switch(
                    value: widget.isDarkMode,
                    onChanged: widget.onToggleDarkMode,
                  ),
                  icon: Icons.dark_mode_rounded,
                  iconColor: Colors.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle(title: 'MAINTENANCE'),
          _SectionCard(
            child: Column(
              children: <Widget>[
                _ActionTile(
                  title: 'Repair Permissions',
                  subtitle: 'Fix notification scheduling',
                  icon: Icons.build_circle_rounded,
                  onTap: widget.onGrantExactAlarmPermission,
                ),
                const _CustomDivider(),
                _ActionTile(
                  title: 'Test Alarm in 1 Minute',
                  subtitle: 'Verify ringing wake-up alarm',
                  icon: Icons.alarm_rounded,
                  onTap: widget.onTestAlarm,
                ),
                const _CustomDivider(),
                _ActionTile(
                  title: 'Send Test Alert',
                  subtitle: 'Verify notifications work',
                  icon: Icons.radar_rounded,
                  onTap: widget.onTestNotification,
                ),
                const _CustomDivider(),
                _ActionTile(
                  title: 'Wake-up Diagnostics',
                  subtitle: 'See what Android scheduled',
                  icon: Icons.rule_folder_rounded,
                  onTap: widget.onShowAlarmDiagnostics,
                ),
                const _CustomDivider(),
                _ActionTile(
                  title: 'Reset App Data',
                  subtitle: 'Clear all local storage',
                  icon: Icons.delete_forever_rounded,
                  onTap: _confirmClearData,
                  isDestructive: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'StudyMate Premium v1.2.5',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crafted for Excellence',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.studentName});
  final String studentName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
              ),
              child: CircleAvatar(
                radius: 48,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          studentName,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Academic Scholar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E211E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.icon,
    this.iconColor,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (iconColor ?? Theme.of(context).colorScheme.primary)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor ?? Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Colors.redAccent
        : Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDestructive ? Colors.redAccent : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomDivider extends StatelessWidget {
  const _CustomDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      ),
    );
  }
}
