import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _notificationsCollection => _firestore.collection('notifications');

  bool get _isCurrentSessionDemo {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    return email != null && email.startsWith('demo.');
  }

  /// Get stream of notifications for a specific user, strictly separating demo and production
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    final isDemoSession = _isCurrentSessionDemo;
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((n) => isDemoSession ? n.isDemo : !n.isDemo)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({'isRead': true});
  }

  /// Mark all notifications as read for a user (chunked at 400 to respect Firestore 500-op batch limit)
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final isDemoSession = _isCurrentSessionDemo;
    final targetRefs = snapshot.docs.where((doc) {
      final isDemoDoc = (doc.data() as Map<String, dynamic>)['isDemo'] == true;
      return isDemoSession == isDemoDoc;
    }).map((doc) => doc.reference).toList();

    if (targetRefs.isEmpty) return;

    const int batchLimit = 400;
    for (var i = 0; i < targetRefs.length; i += batchLimit) {
      final batch = _firestore.batch();
      final chunk = targetRefs.skip(i).take(batchLimit);
      for (final ref in chunk) {
        batch.update(ref, {'isRead': true});
      }
      await batch.commit();
    }
  }

  /// Mark all notifications for a specific chat as read for a user
  Future<void> markChatNotificationsAsRead(String userId, String chatId) async {
    final snapshot = await _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('relatedTaskId', isEqualTo: chatId)
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    const int batchLimit = 400;
    for (var i = 0; i < snapshot.docs.length; i += batchLimit) {
      final batch = _firestore.batch();
      for (final doc in snapshot.docs.skip(i).take(batchLimit)) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  /// Send a notification to a specific user
  Future<void> sendNotification({
    required String userId,
    String? senderId,
    required String title,
    required String message,
    String? relatedTaskId,
    bool? isDemo,
  }) async {
    final effectiveSenderId = senderId ?? FirebaseAuth.instance.currentUser?.uid;
    // Never notify the user if they triggered the action themselves
    if (effectiveSenderId != null && effectiveSenderId == userId) return;

    final isDemoNotification = isDemo ?? _isCurrentSessionDemo;

    final notification = NotificationModel(
      id: '',
      userId: userId,
      senderId: effectiveSenderId,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      relatedTaskId: relatedTaskId,
      isDemo: isDemoNotification,
    );
    await _notificationsCollection.add(notification.toMap());
  }

  /// Send a broadcast notification to all tenants (optionally filtered by building)
  Future<void> sendBroadcastToTenants(String title, String message, {String? buildingId}) async {
    final isDemoSession = _isCurrentSessionDemo;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = isDemoSession
        ? await _firestore
            .collection('users')
            .where('isDemo', isEqualTo: true)
            .where('role', isEqualTo: 'tenant')
            .get()
        : await _firestore
            .collection('users')
            .where('role', isEqualTo: 'tenant')
            .get();

    final targetDocs = snapshot.docs.where((doc) {
      final data = doc.data();
      final isTenantDemo = data['isDemo'] == true;
      if (isDemoSession != isTenantDemo) return false;

      if (buildingId == null || buildingId.isEmpty || buildingId == 'All Buildings') {
        return true;
      }
      if (data['buildingId'] == buildingId) return true;
      final props = data['properties'];
      if (props is List) {
        return props.any((p) => p is Map && p['buildingName'] == buildingId);
      }
      return false;
    }).toList();

    const int batchLimit = 400;
    for (var i = 0; i < targetDocs.length; i += batchLimit) {
      final batch = _firestore.batch();
      final chunk = targetDocs.skip(i).take(batchLimit);
      for (var doc in chunk) {
        final docRef = _notificationsCollection.doc();
        batch.set(docRef, {
          'userId': doc.id,
          'senderId': ?currentUid,
          'title': title,
          'message': message,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          if (isDemoSession) 'isDemo': true,
        });
      }
      await batch.commit();
    }
  }

  Future<void> notifyAdmins({
    String? senderId,
    required String title,
    required String message,
    String? relatedTaskId,
    bool? isDemo,
  }) async {
    try {
      final isDemoEvent = isDemo ?? _isCurrentSessionDemo;
      final effectiveSenderId = senderId ?? FirebaseAuth.instance.currentUser?.uid;
      final adminsSnapshot = isDemoEvent
          ? await _firestore
              .collection('users')
              .where('isDemo', isEqualTo: true)
              .where('role', isEqualTo: 'admin')
              .get()
          : await _firestore
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .get();
      if (adminsSnapshot.docs.isEmpty) {
        return;
      }

      // 🛡️ Strict Isolation: Demo events only notify Demo Admins, Real events only notify Real Admins!
      final targetAdminDocs = adminsSnapshot.docs.where((doc) {
        final data = doc.data();
        final isAdminDemo = data['isDemo'] == true;
        return isDemoEvent ? isAdminDemo : !isAdminDemo;
      }).toList();

      if (targetAdminDocs.isEmpty) return;

      const int batchLimit = 400;
      for (var i = 0; i < targetAdminDocs.length; i += batchLimit) {
        final batch = _firestore.batch();
        for (var doc in targetAdminDocs.skip(i).take(batchLimit)) {
          // Never send an admin notification to the admin who triggered the action
          if (effectiveSenderId != null && doc.id == effectiveSenderId) continue;

          final docRef = _notificationsCollection.doc();
          batch.set(docRef, {
            'userId': doc.id,
            'senderId': ?effectiveSenderId,
            'title': title,
            'message': message,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'relatedTaskId': relatedTaskId,
            if (isDemoEvent) 'isDemo': true,
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error notifying admins: $e');
    }
  }

  /// Send contract expiry reminder
  Future<void> sendContractExpiryReminder(String tenantId) async {
    await sendNotification(
      userId: tenantId,
      title: 'Contract Expiring Soon ⚠️',
      message: 'Your lease contract is expiring soon. Please contact management to renew.',
    );
  }
}
