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
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // On iOS, APNs token MUST be registered with Apple before fetching FCM token
          String? apnsToken = await _messaging.getAPNSToken();
          int retries = 0;
          while (apnsToken == null && retries < 10) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await _messaging.getAPNSToken();
            retries++;
          }
          debugPrint('APNs token status on iOS: ${apnsToken != null ? "Acquired" : "Not set"}');
        }
        token = await _messaging.getToken();
      }

      if (token != null) {
        await FirebaseFirestore.instance.collection('user_tokens').doc(userId).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
          await FirebaseFirestore.instance.collection('user_tokens').doc(userId).set({
            'fcmToken': newToken,
            'updatedAt': FieldValue.serverTimestamp(),
          });
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

  /// Clears the user's FCM token from Firestore and deletes local token upon logout
  static Future<void> clearUserToken([String? userId]) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;

      if (uid != null) {
        await FirebaseFirestore.instance.collection('user_tokens').doc(uid).delete().catchError((_) {});
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM Token deleted from Firestore for user $uid');
      }

      // Delete the FCM token locally so this device receives zero notifications while logged out
      await _messaging.deleteToken();
      debugPrint('Local FCM token deleted successfully');
    } catch (e) {
      debugPrint('Error clearing FCM token on logout: $e');
    }
  }
}
