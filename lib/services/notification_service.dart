import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _notificationsCollection => _firestore.collection('notifications');

  /// Get stream of notifications for a specific user
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return NotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
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

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
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
    required String title,
    required String message,
    String? relatedTaskId,
  }) async {
    final notification = NotificationModel(
      id: '',
      userId: userId,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      relatedTaskId: relatedTaskId,
    );
    await _notificationsCollection.add(notification.toMap());
  }

  /// Send a broadcast notification to all tenants (optionally filtered by building)
  Future<void> sendBroadcastToTenants(String title, String message, {String? buildingId}) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'tenant')
        .get();

    final targetDocs = snapshot.docs.where((doc) {
      if (buildingId == null || buildingId.isEmpty || buildingId == 'All Buildings') {
        return true;
      }
      final data = doc.data();
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
        });
      }
      await batch.commit();
    }
  }

  Future<void> notifyAdmins({
    required String title,
    required String message,
    String? relatedTaskId,
  }) async {
    try {
      final adminsSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'admin').get();
      if (adminsSnapshot.docs.isEmpty) {
        // Fallback: search without role filter if needed or log
        return;
      }

      final batch = _firestore.batch();
      for (var doc in adminsSnapshot.docs) {
        final docRef = _notificationsCollection.doc();
        batch.set(docRef, {
          'userId': doc.id,
          'title': title,
          'message': message,
          'isRead': false,
          'createdAt': Timestamp.now(),
          'relatedTaskId': relatedTaskId,
        });
      }
      await batch.commit();
    } catch (e) {
      // Don't let notification failure break parent operation
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
