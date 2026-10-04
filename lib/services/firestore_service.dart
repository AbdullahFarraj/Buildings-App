import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/maintenance_task_model.dart';
import '../models/task_message_model.dart';
import '../models/user_model.dart';
import '../core/enums/task_status.dart';
import '../core/enums/user_role.dart';
import 'notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _tasksCollection => _firestore.collection('tasks');

  /// Creates a new maintenance task.
  Future<void> createTask(MaintenanceTaskModel task) async {
    DocumentReference docRef = task.id.isEmpty 
        ? _tasksCollection.doc() 
        : _tasksCollection.doc(task.id);
        
    await docRef.set(task.toMap());

    // Notify Admins
    final adminSnapshot = await _firestore.collection('users').where('role', isEqualTo: UserRole.admin.value).get();
    for (var doc in adminSnapshot.docs) {
      await NotificationService().sendNotification(
        userId: doc.id,
        title: 'New Maintenance Request 🔔',
        message: 'A new request "${task.title}" was submitted for Apt ${task.apartmentNumber}.',
        relatedTaskId: docRef.id,
      );
    }
  }

  /// Gets a stream of tasks submitted by a specific tenant.
  Stream<List<MaintenanceTaskModel>> getTasksByTenant(String tenantId) {
    return _tasksCollection
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MaintenanceTaskModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Gets a stream of tasks assigned to a specific technician.
  Stream<List<MaintenanceTaskModel>> getAssignedTasksForTechnician(String technicianId) {
    return _tasksCollection
        .where('technicianId', isEqualTo: technicianId)
        .snapshots()
        .map((snapshot) {
      final tasks = snapshot.docs.map((doc) {
        return MaintenanceTaskModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      // Sort in memory to avoid requiring a composite index in Firestore
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tasks;
    });
  }

  /// Gets a stream of all tasks for the admin dashboard.
  Stream<List<MaintenanceTaskModel>> getAllTasksForAdmin() {
    return _tasksCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MaintenanceTaskModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Assigns a task to a technician and updates status to assigned.
  Future<void> assignTask(String taskId, String technicianId, String technicianName) async {
    await _tasksCollection.doc(taskId).update({
      'technicianId': technicianId,
      'technicianName': technicianName,
      'status': TaskStatus.assigned.value,
    });
    
    // Notify the technician
    await NotificationService().sendNotification(
      userId: technicianId,
      title: 'New Task Assigned 🛠️',
      message: 'You have been assigned to a new maintenance task.',
      relatedTaskId: taskId,
    );

    // Get the task to notify the tenant
    final doc = await _tasksCollection.doc(taskId).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;
      final tenantId = data['tenantId'];
      if (tenantId != null) {
        await NotificationService().sendNotification(
          userId: tenantId,
          title: 'Technician Assigned 🧑‍🔧',
          message: '$technicianName has been assigned to your request.',
          relatedTaskId: taskId,
        );
      }
    }
  }

  /// Updates the status of a task, optionally adding a completion proof URL or notes.
  Future<void> updateTaskStatus(
    String taskId, 
    TaskStatus status, 
    {String? completionProofUrl, String? completionNotes}
  ) async {
    Map<String, dynamic> updates = {
      'status': status.value,
    };

    if (status == TaskStatus.completed || status == TaskStatus.waitingConfirmation) {
      updates['completedAt'] = FieldValue.serverTimestamp();
      if (completionProofUrl != null) {
        updates['completionProofUrl'] = completionProofUrl;
      }
      if (completionNotes != null) {
        updates['completionNotes'] = completionNotes;
      }
    }
    await _tasksCollection.doc(taskId).update(updates);

    // Notify the tenant if the status is waitingConfirmation
    if (status == TaskStatus.waitingConfirmation) {
      final doc = await _tasksCollection.doc(taskId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final tenantId = data['tenantId'];
        if (tenantId != null) {
          await NotificationService().sendNotification(
            userId: tenantId,
            title: 'Task Completed ✅',
            message: 'Your maintenance request was marked as completed by the technician. Please confirm and rate.',
            relatedTaskId: taskId,
          );
        }
      }
    }
  }

  /// Submits tenant rating and updates technician's overall rating
  Future<void> submitTenantRating(String taskId, String technicianId, int rating, String? feedback) async {
    // 1. Update Task (Always do this first to ensure status changes)
    await _tasksCollection.doc(taskId).update({
      'status': TaskStatus.completed.value,
      'rating': rating,
      'tenantFeedback': feedback,
      'completedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update Technician stats (Wrap in try-catch in case of permission issues)
    try {
      await _firestore.runTransaction((transaction) async {
        final techRef = _firestore.collection('users').doc(technicianId);
        final techDoc = await transaction.get(techRef);
        
        if (techDoc.exists && techDoc.data() != null) {
          final data = techDoc.data()!;
          final currentAverage = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
          final currentTotal = (data['totalRatings'] as num?)?.toInt() ?? 0;

          final newTotal = currentTotal + 1;
          final newAverage = ((currentAverage * currentTotal) + rating) / newTotal;

          transaction.update(techRef, {
            'averageRating': newAverage,
            'totalRatings': newTotal,
          });
        }
      });
    } catch (e) {
      print('Warning: Failed to update technician rating stats: $e');
      // We don't rethrow because the task status was successfully updated.
    }
  }

  /// Gets a list of all technicians
  Future<List<UserModel>> getTechnicians() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.technician.value)
        .get();
    
    return snapshot.docs.map((doc) {
      return UserModel.fromMap(doc.data(), doc.id);
    }).toList();
  }

  /// Gets a list of all tenants
  Future<List<UserModel>> getTenants() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.tenant.value)
        .get();
    
    return snapshot.docs.map((doc) {
      return UserModel.fromMap(doc.data(), doc.id);
    }).toList();
  }

  /// Gets user details by ID
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Deletes a task
  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }

  /// Creates a new user document
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  /// Deletes a user document
  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  // --- Task Chat / Comments ---

  /// Get stream of messages for a specific task
  Stream<List<TaskMessageModel>> getTaskMessages(String taskId) {
    return _tasksCollection
        .doc(taskId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TaskMessageModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Add a message to a task
  Future<void> addTaskMessage({
    required String taskId,
    required String senderId,
    required String senderName,
    required String text,
    List<String> receiverIds = const [], // To notify them
  }) async {
    final message = TaskMessageModel(
      id: '',
      senderId: senderId,
      senderName: senderName,
      text: text,
      createdAt: DateTime.now(),
    );

    await _tasksCollection.doc(taskId).collection('messages').add(message.toMap());

    // Send notifications to receivers (Admin, Tech, or Tenant)
    for (String receiverId in receiverIds) {
      if (receiverId.isNotEmpty && receiverId != senderId) {
        await NotificationService().sendNotification(
          userId: receiverId,
          title: 'New Message from $senderName 💬',
          message: text,
          relatedTaskId: taskId,
        );
      }
    }
  }
}
