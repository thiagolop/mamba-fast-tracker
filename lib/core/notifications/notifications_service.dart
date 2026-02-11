import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../storage/hive_boxes.dart';

class NotificationsService {
  NotificationsService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? local,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _local = local ?? FlutterLocalNotificationsPlugin();

  static const String tokenStorageKey = 'fcm_token';

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  bool _initialized = false;
  String? _memoryToken;

  String? get cachedToken {
    try {
      return HiveBoxes.settings.get(tokenStorageKey) ?? _memoryToken;
    } catch (_) {
      return _memoryToken;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.local);

      await _initLocalNotifications();
      await _requestPermissions();
      await _fetchAndStoreToken();
      _listenTokenRefresh();
      _listenFcmMessages();
      await _handleInitialMessage();
    } catch (_) {}
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (_) {},
    );

    const channel = AndroidNotificationChannel(
      'fasting_channel',
      'Fasting',
      description: 'Notificações de jejum',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    await _local
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final android = _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.requestNotificationsPermission();
      } catch (_) {}
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}
    }
  }

  Future<void> _fetchAndStoreToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(token);
      }
    } catch (_) {}
  }

  void _listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      if (token.isNotEmpty) {
        await _saveToken(token);
      }
    });
  }

  void _listenFcmMessages() {
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title;
      final body = message.notification?.body;
      if (title != null || body != null) {
        showNow(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title ?? 'Notificação',
          body: body ?? '',
          payload: message.data.isEmpty
              ? null
              : message.data.toString(),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // no-op
    });
  }

  Future<void> _handleInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (message == null) return;
    } catch (_) {}
  }

  Future<void> _saveToken(String token) async {
    try {
      await HiveBoxes.settings.put(tokenStorageKey, token);
    } catch (_) {
      _memoryToken = token;
    }
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'fasting_channel',
        'Fasting',
        channelDescription: 'Notificações de jejum',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    await _local.cancel(id: id);
  }

  Future<void> scheduleFastingEnd({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    final now = DateTime.now();
    if (!when.isAfter(now)) return;

    final scheduled = tz.TZDateTime.from(when, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'fasting_channel',
        'Fasting',
        channelDescription: 'Notificações de jejum',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _local.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }
}

final notificationsServiceProvider = Provider<NotificationsService>((
  ref,
) {
  return NotificationsService();
});

final fcmTokenProvider = StreamProvider<String?>((ref) async* {
  ref.read(notificationsServiceProvider);

  String? readToken() {
    try {
      return HiveBoxes.settings.get(
        NotificationsService.tokenStorageKey,
      );
    } catch (_) {
      return null;
    }
  }

  yield readToken();

  try {
    await for (final event in HiveBoxes.settings.watch(
      key: NotificationsService.tokenStorageKey,
    )) {
      yield event.value as String?;
    }
  } catch (_) {
    yield readToken();
  }
});
