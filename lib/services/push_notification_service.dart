import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  debugPrint('Handling a background message: ${message.messageId} - ${message.notification?.title}');
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;

  /// Initialize listeners and request permissions
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM permission status: ${settings.authorizationStatus}');

      // 2. Set presentation options for foreground messages (iOS & web)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.notification?.title}');
      });

      // 4. Listen when user taps on notification while app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Notification tapped from background: ${message.data}');
      });

      // 5. Check if app was opened from a terminated state notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM App opened from terminated state via notification: ${initialMessage.data}');
      }
    } catch (e) {
      debugPrint('PushNotificationService initialization error: $e');
    }
  }

  /// Register current logged in user's token in Firestore
  static Future<void> syncUserToken(String userId) async {
    try {
      String? token;
      if (kIsWeb) {
        token = await _messaging.getToken(
          vapidKey: 'BGnIO1ERLemsFNKnTY1llGzc4PC31FmTMM8WfeRn_WprktMZflSSNo1ZXKtLE_COANWPW7tJhOUZ9WBCYp1pZ9s',
        );
      } else {
        token = await _messaging.getToken();
      }

      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM Token synced for user $userId: ${token.substring(0, 10)}...');
      }

      // Listen for token refreshes without leaking duplicate subscriptions
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        try {
          if (FirebaseAuth.instance.currentUser?.uid != userId) return;
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'fcmToken': newToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('FCM Token refreshed and synced for user $userId');
        } catch (e) {
          debugPrint('Error updating refreshed token: $e');
        }
      });
    } catch (e) {
      debugPrint('Error syncing FCM token for user $userId: $e');
    }
  }
}
