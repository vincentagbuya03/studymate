import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  Future<void> initialize() async {
    await Alarm.init();
  }

  Future<bool> scheduleAlarm({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
    String assetAudioPath = 'assets/audio/alarm_clock_old.mp3',
    bool loopAudio = true,
    bool vibrate = true,
    double? volume,
    bool fadeDuration = true,
    bool warningNotificationOnKill = true,
  }) async {
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: dateTime,
      assetAudioPath: assetAudioPath,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volumeSettings: volume != null
          ? VolumeSettings.fade(
              volume: volume,
              fadeDuration: fadeDuration
                  ? const Duration(seconds: 10)
                  : Duration.zero,
            )
          : const VolumeSettings.fixed(),
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Stop',
        icon: 'notification_icon',
      ),
      warningNotificationOnKill: warningNotificationOnKill,
    );

    try {
      final bool scheduled = await Alarm.set(alarmSettings: alarmSettings);
      if (scheduled) {
        debugPrint('[AlarmService] Alarm scheduled for $dateTime with ID $id');
      } else {
        debugPrint(
          '[AlarmService] Alarm $id was not accepted by the platform.',
        );
      }
      return scheduled;
    } catch (e) {
      debugPrint('[AlarmService] ERROR scheduling alarm $id: $e');
      debugPrint(
        '[AlarmService] This may be caused by missing SCHEDULE_EXACT_ALARM permission in release builds.',
      );
      return false;
    }
  }

  Future<void> stopAlarm(int id) async {
    await stopAlarms(<int>[id]);
  }

  Future<void> stopAlarms(Iterable<int> ids) async {
    final Set<int> requestedIds = ids.toSet();
    if (requestedIds.isEmpty) {
      return;
    }

    final alarms = await Alarm.getAlarms();
    for (final alarm in alarms) {
      if (!requestedIds.contains(alarm.id)) {
        continue;
      }

      await Alarm.stop(alarm.id);
      debugPrint('[AlarmService] Alarm stopped for ID ${alarm.id}');
    }
  }

  Future<void> stopAllAlarms() async {
    final alarms = await Alarm.getAlarms();
    for (final alarm in alarms) {
      await Alarm.stop(alarm.id);
    }
    debugPrint('[AlarmService] All alarms stopped');
  }

  Future<bool> isRinging([int? id]) async {
    return await Alarm.isRinging(id);
  }

  Future<List<AlarmSettings>> getScheduledAlarms() async {
    final alarms = await Alarm.getAlarms();
    return alarms.toList()..sort(
      (AlarmSettings a, AlarmSettings b) => a.dateTime.compareTo(b.dateTime),
    );
  }

  ValueStream<AlarmSet> get ringingStream => Alarm.ringing;

  Set<AlarmSettings> get currentlyRinging => Alarm.ringing.value.alarms;
}
