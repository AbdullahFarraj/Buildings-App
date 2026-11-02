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

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final isDemoSession = _isCurrentSessionDemo;
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      final isDemoDoc = (doc.data() as Map<String, dynamic>)['isDemo'] == true;
      if (isDemoSession == isDemoDoc) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  /// Mark all notifications for a specific chat as read for a user
  Future<void> markChatNotificationsAsRead(String userId, String chatId) async {
    final snapshot = await _notificationsCollection
        .where('userId', isEqualTo: userId)
        .where('relatedTaskId', isEqualTo: chatId)
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
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
    // Never notify the user if they triggered the action themselves
    if (senderId != null && senderId == userId) return;

    final isDemoNotification = isDemo ?? _isCurrentSessionDemo;

    final notification = NotificationModel(
      id: '',
      userId: userId,
      senderId: senderId,
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
    final snapshot = await _firestore
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

    const int batchLimit = 450;
    for (var i = 0; i < targetDocs.length; i += batchLimit) {
      final batch = _firestore.batch();
      final chunk = targetDocs.skip(i).take(batchLimit);
      for (var doc in chunk) {
        final docRef = _notificationsCollection.doc();
        batch.set(docRef, {
          'userId': doc.id,
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
      final adminsSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'admin').get();
      if (adminsSnapshot.docs.isEmpty) {
        return;
      }

      // 🛡️ Strict Isolation: Demo events only notify Demo Admins, Real events only notify Real Admins!
      final targetAdminDocs = adminsSnapshot.docs.where((doc) {
        final data = doc.data();
        final isAdminDemo = data['isDemo'] == true;
        return isDemoEvent ? isAdminDemo : !isAdminDemo;
      }).toList();

      final batch = _firestore.batch();
      for (var doc in targetAdminDocs) {
        // Never send an admin notification to the admin who triggered the action
        if (senderId != null && doc.id == senderId) continue;

        final docRef = _notificationsCollection.doc();
        batch.set(docRef, {
          'userId': doc.id,
          if (senderId != null) 'senderId': senderId,
          'title': title,
          'message': message,
          'isRead': false,
          'createdAt': Timestamp.now(),
          'relatedTaskId': relatedTaskId,
          if (isDemoEvent) 'isDemo': true,
        });
      }
      await batch.commit();
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
