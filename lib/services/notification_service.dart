import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Received background notification: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'road_rescue_notifications',
    'RoadRescue notifications',
    description: 'Notifications for assistance requests and insurance claims.',
    importance: Importance.high,
  );

  bool _initialized = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _firestoreSubscription;

  Future<void> initialize() async {
    if (_initialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _messaging.onTokenRefresh.listen(_saveToken);
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _firestoreSubscription?.cancel();
      _firestoreSubscription = null;

      if (user != null) {
        await _saveToken(await _messaging.getToken());
        _listenForFirestoreNotifications(user.uid);
      }
    });

    _initialized = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _saveToken(await _messaging.getToken());
      _listenForFirestoreNotifications(user.uid);
    }
  }

  void _listenForFirestoreNotifications(String userId) {
    var isInitialSnapshot = true;

    _firestoreSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (isInitialSnapshot) {
              isInitialSnapshot = false;
              return;
            }

            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added) continue;

              final data = change.doc.data();
              if (data == null || data['isDeleted'] == true) continue;

              unawaited(_showNotificationData(change.doc.id, data));
            }
          },
          onError: (Object error) {
            debugPrint('Firestore notification listener error: $error');
          },
        );
  }

  Future<void> _saveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (token == null || token.isEmpty || user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      debugPrint(
        'Unable to save notification token: '
        '${error.code} - ${error.message}',
      );
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();

    if (title == null && body == null) return;

    await _localNotifications.show(
      id: message.hashCode,
      title: title ?? 'RoadRescue',
      body: body ?? 'You have a new notification.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'road_rescue_notifications',
          'RoadRescue notifications',
          channelDescription:
              'Notifications for assistance requests and insurance claims.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _showNotificationData(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await _localNotifications.show(
      id: documentId.hashCode,
      title: data['title']?.toString() ?? 'RoadRescue',
      body:
          data['message']?.toString() ??
          data['body']?.toString() ??
          'You have a new notification.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'road_rescue_notifications',
          'RoadRescue notifications',
          channelDescription:
              'Notifications for assistance requests and insurance claims.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('Notification opened: ${response.payload}');
  }
}
