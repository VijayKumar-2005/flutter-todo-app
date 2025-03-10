import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz1;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifyPlugin = FlutterLocalNotificationsPlugin();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  Future<void> init() async {
    tz1.initializeTimeZones();
    await Permission.notification.request();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifyPlugin.initialize(settings);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final bool hasExactAlarmPermission = await _checkExactAlarmPermission();
      if (!hasExactAlarmPermission) {
        throw Exception('Exact alarm permission not granted');
      }

      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
        scheduledDate.isUtc ? scheduledDate.toLocal() : scheduledDate,
        tz.local,
      );

      if (tzScheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        throw Exception('Scheduled time must be in the future.');
      }

      await _notifyPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            channelDescription: 'channel_description',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await openAppSettings();
      }
      rethrow;
    }
  }

  Future<bool> _checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        final status = await Permission.scheduleExactAlarm.status;
        if (!status.isGranted) {
          final result = await Permission.scheduleExactAlarm.request();
          return result.isGranted;
        }
        return true;
      }
    }
    return true;
  }
}