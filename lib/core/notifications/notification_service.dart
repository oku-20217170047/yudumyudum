import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Android 13+ runtime permission
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  NotificationDetails _details() {
    const androidDetails = AndroidNotificationDetails(
      'habits_channel',
      'Habits',
      channelDescription: 'Habit reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    return const NotificationDetails(android: androidDetails);
  }

  Future<void> showNow({
    required String title,
    required String body,
    int id = 10,
  }) async {
    await _plugin.show(id, title, body, _details());
  }

  /// X dakika sonra tek seferlik bildirim
  /// - Exact izin yoksa inexact'e düşer
  /// - App açıkken garanti olsun diye Timer fallback da var
  Future<void> scheduleOnceAfterMinutes({
    required int id,
    required int minutes,
    required String title,
    required String body,
  }) async {
    final safeMinutes = minutes <= 0 ? 1 : minutes;

    // App açıkken garanti tetik (arka planda garanti değil)
    Timer(Duration(minutes: safeMinutes), () async {
      try {
        await showNow(id: id, title: title, body: body);
      } catch (_) {}
    });

    final scheduled =
        tz.TZDateTime.now(tz.local).add(Duration(minutes: safeMinutes));

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (e) {
      final msg = (e.message ?? '').toLowerCase();
      final code = e.code.toLowerCase();

      final notPermitted = msg.contains('exact_alarms_not_permitted') ||
          msg.contains('exact alarms are not permitted') ||
          code.contains('exact');

      if (notPermitted) {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        return;
      }

      rethrow;
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
