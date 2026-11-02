import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/maintenance_task_model.dart';
import '../models/task_message_model.dart';
import '../models/user_model.dart';
import '../models/contract_model.dart';
import '../models/cheque_model.dart';
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
        
    final taskData = task.toMap();
    if (isCurrentSessionDemo) {
      taskData['isDemo'] = true;
    }

    // Auto-assign default technician directly
    if (taskData['technicianId'] == null) {
      final defaultTech = await getDefaultTechnician();
      if (defaultTech != null) {
        taskData['technicianId'] = defaultTech.uid;
        taskData['technicianName'] = defaultTech.name;
        taskData['status'] = TaskStatus.assigned.value;
      }
    }

    await docRef.set(taskData);

    // Notify technician if assigned
    if (taskData['technicianId'] != null) {
      try {
        await NotificationService().sendNotification(
          userId: taskData['technicianId'],
          title: 'New Maintenance Assignment 🛠️',
          message: 'A new maintenance task "${task.title}" has been assigned to you.',
          relatedTaskId: docRef.id,
        );
      } catch (_) {}
    }

    // Notify Admins
    try {
      await NotificationService().notifyAdmins(
        senderId: task.tenantId,
        title: 'New Maintenance Request 🔔',
        message: 'A new request "${task.title}" was submitted for Apt ${task.apartmentNumber}.',
        relatedTaskId: docRef.id,
      );
    } catch (_) {}
  }

  /// Get a single task by its ID
  Future<MaintenanceTaskModel?> getTask(String taskId) async {
    try {
      final doc = await _tasksCollection.doc(taskId).get();
      if (doc.exists && doc.data() != null) {
        return MaintenanceTaskModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (_) {}
    return null;
  }

  /// Gets a stream of tasks submitted by a specific tenant.
  Stream<List<MaintenanceTaskModel>> getTasksByTenant(String tenantId, {int limit = 50}) {
    return _tasksCollection
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MaintenanceTaskModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Gets a stream of tasks assigned to a specific technician.
  Stream<List<MaintenanceTaskModel>> getAssignedTasksForTechnician(String technicianId, {int limit = 50}) {
    return _tasksCollection
        .where('technicianId', isEqualTo: technicianId)
        .limit(limit)
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
  Stream<List<MaintenanceTaskModel>> getAllTasksForAdmin({int limit = 50}) {
    if (isCurrentSessionDemo) {
      return _tasksCollection
          .where('isDemo', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) {
          return MaintenanceTaskModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    }
    return _tasksCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['isDemo'] != true)
          .map((doc) {
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
    } else if (status == TaskStatus.inProgress) {
      final doc = await _tasksCollection.doc(taskId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final tenantId = data['tenantId'];
        final title = data['title'] ?? 'your request';
        if (tenantId != null) {
          await NotificationService().sendNotification(
            userId: tenantId,
            title: 'Work In Progress 🛠️',
            message: 'Technician has started working on "$title".',
            relatedTaskId: taskId,
          );
        }
      }
    }
  }

  /// Puts a task on hold due to waiting for materials
  Future<void> holdTaskForMaterials({
    required String taskId,
    required String reason,
    String? technicianName,
  }) async {
    await _tasksCollection.doc(taskId).update({
      'status': TaskStatus.onHold.value,
      'holdReason': reason,
    });

    final task = await getTask(taskId);
    if (task != null) {
      if (task.tenantId.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: task.tenantId,
          title: 'Request On Hold ⏸️',
          message: 'Your request "${task.title}" is on hold: waiting to purchase materials ($reason).',
          relatedTaskId: taskId,
        );
      }
      await NotificationService().notifyAdmins(
        title: 'Task On Hold (Materials) ⏸️',
        message: '${technicianName ?? task.technicianName ?? "Technician"} put request "${task.title}" (Apt ${task.apartmentNumber}) on hold: $reason',
        relatedTaskId: taskId,
      );
    }
  }

  /// Resumes a task that was on hold
  Future<void> resumeTask({
    required String taskId,
    String? technicianName,
  }) async {
    await _tasksCollection.doc(taskId).update({
      'status': TaskStatus.inProgress.value,
    });

    final task = await getTask(taskId);
    if (task != null) {
      if (task.tenantId.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: task.tenantId,
          title: 'Work Resumed ▶️',
          message: 'Technician has resumed work on "${task.title}".',
          relatedTaskId: taskId,
        );
      }
      await NotificationService().notifyAdmins(
        title: 'Work Resumed ▶️',
        message: '${technicianName ?? task.technicianName ?? "Technician"} resumed work on "${task.title}".',
        relatedTaskId: taskId,
      );
    }
  }

  /// Reschedules a task to a new date and time slot
  Future<void> rescheduleTask({
    required String taskId,
    required DateTime newDate,
    required String newSlot,
    required String rescheduledByRole, // 'technician' or 'tenant'
  }) async {
    await _tasksCollection.doc(taskId).update({
      'preferredVisitDate': Timestamp.fromDate(newDate),
      'preferredVisitSlot': newSlot,
      'rescheduledBy': rescheduledByRole,
      'rescheduledAt': FieldValue.serverTimestamp(),
    });

    final task = await getTask(taskId);
    if (task == null) return;

    final dateFormatted = '${newDate.day}/${newDate.month}/${newDate.year}';
    final slotClean = newSlot.contains(':') ? newSlot.split(':').first : newSlot;

    if (rescheduledByRole == 'technician') {
      if (task.tenantId.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: task.tenantId,
          title: 'Visit Rescheduled 📅',
          message: 'Technician rescheduled visit for "${task.title}" to $dateFormatted ($slotClean).',
          relatedTaskId: taskId,
        );
      }
      await NotificationService().notifyAdmins(
        title: 'Visit Rescheduled by Tech 📅',
        message: '${task.technicianName ?? "Technician"} rescheduled "${task.title}" (Apt ${task.apartmentNumber}) to $dateFormatted ($slotClean).',
        relatedTaskId: taskId,
      );
    } else {
      if (task.technicianId != null && task.technicianId!.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: task.technicianId!,
          title: 'Visit Rescheduled by Tenant 📅',
          message: 'Tenant rescheduled visit for "${task.title}" (Apt ${task.apartmentNumber}) to $dateFormatted ($slotClean).',
          relatedTaskId: taskId,
        );
      }
      await NotificationService().notifyAdmins(
        title: 'Visit Rescheduled by Tenant 📅',
        message: 'Tenant rescheduled "${task.title}" (Apt ${task.apartmentNumber}) to $dateFormatted ($slotClean).',
        relatedTaskId: taskId,
      );
    }
  }

  /// Rejects a maintenance request
  Future<void> rejectTask({
    required String taskId,
    required String reason,
  }) async {
    await _tasksCollection.doc(taskId).update({
      'status': TaskStatus.rejected.value,
      'rejectionReason': reason,
    });

    final task = await getTask(taskId);
    if (task != null && task.tenantId.isNotEmpty) {
      await NotificationService().sendNotification(
        userId: task.tenantId,
        title: 'Request Rejected ❌',
        message: 'Your maintenance request "${task.title}" was rejected: $reason',
        relatedTaskId: taskId,
      );
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

    // Notify technician & admin
    try {
      final task = await getTask(taskId);
      if (task != null) {
        if (technicianId.isNotEmpty) {
          await NotificationService().sendNotification(
            userId: technicianId,
            title: 'Task Confirmed & Rated ⭐',
            message: 'Tenant rated your work $rating/5 on "${task.title}".',
            relatedTaskId: taskId,
          );
        }
        await NotificationService().notifyAdmins(
          title: 'Task Confirmed ⭐',
          message: 'Apt ${task.apartmentNumber} confirmed task "${task.title}" (Rating: $rating/5).',
          relatedTaskId: taskId,
        );
      }
    } catch (_) {}

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
      debugPrint('Warning: Failed to update technician rating stats: $e');
      // We don't rethrow because the task status was successfully updated.
    }
  }

  /// Gets a list of all technicians
  Future<List<UserModel>> getTechnicians() async {
    if (isCurrentSessionDemo) {
      final snapshot = await _firestore
          .collection('users')
          .where('isDemo', isEqualTo: true)
          .where('role', isEqualTo: UserRole.technician.value)
          .get();
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    }
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.technician.value)
        .get();
    
    return snapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['isDemo'] != true)
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Gets the default technician for auto-assigning tasks.
  Future<UserModel?> getDefaultTechnician() async {
    try {
      final technicians = await getTechnicians();
      if (technicians.isEmpty) return null;

      // 1. Check if any technician has isDefaultTechnician: true
      final marked = technicians.where((t) => t.isDefaultTechnician).toList();
      if (marked.isNotEmpty) return marked.first;

      // 2. Check app_settings document
      final settingsDoc = await _firestore.collection('app_settings').doc('maintenance').get();
      if (settingsDoc.exists && settingsDoc.data() != null) {
        final defaultId = settingsDoc.data()!['defaultTechnicianId'];
        if (defaultId != null && defaultId is String && defaultId.isNotEmpty) {
          final matched = technicians.where((t) => t.uid == defaultId).toList();
          if (matched.isNotEmpty) return matched.first;
        }
      }

      // 3. Fallback: return the first technician
      return technicians.first;
    } catch (e) {
      debugPrint('Error getting default technician: $e');
      return null;
    }
  }

  /// Sets the default technician in Firestore.
  Future<void> setDefaultTechnician(String technicianId) async {
    // 1. Update app_settings/maintenance
    await _firestore.collection('app_settings').doc('maintenance').set({
      'defaultTechnicianId': technicianId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Update isDefaultTechnician on technician user documents
    try {
      final technicians = await getTechnicians();
      final batch = _firestore.batch();
      for (var tech in technicians) {
        final ref = _firestore.collection('users').doc(tech.uid);
        batch.update(ref, {'isDefaultTechnician': tech.uid == technicianId});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error updating technician isDefaultTechnician flag: $e');
    }
  }

  /// Gets a list of all tenants
  Future<List<UserModel>> getTenants() async {
    if (isCurrentSessionDemo) {
      final snapshot = await _firestore
          .collection('users')
          .where('isDemo', isEqualTo: true)
          .where('role', isEqualTo: UserRole.tenant.value)
          .get();
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    }
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.tenant.value)
        .get();
    
    return snapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['isDemo'] != true)
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Gets a list of all contracts
  Future<List<ContractModel>> getContracts() async {
    if (isCurrentSessionDemo) {
      final snapshot = await _firestore
          .collection('contracts')
          .where('isDemo', isEqualTo: true)
          .get();
      final list = snapshot.docs.map((doc) => ContractModel.fromFirestore(doc)).toList();
      list.sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        if (a.endDate == null) return 1;
        if (b.endDate == null) return -1;
        if (a.isActive) {
          return a.endDate!.compareTo(b.endDate!);
        } else {
          return b.endDate!.compareTo(a.endDate!);
        }
      });
      return list;
    }
    final snapshot = await _firestore.collection('contracts').get();
    final list = snapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['isDemo'] != true)
        .map((doc) => ContractModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) {
      if (a.endDate == null) return 1;
      if (b.endDate == null) return -1;
      return a.endDate!.compareTo(b.endDate!);
    });
    return list;
  }

  /// Gets active maintenance tasks count using fast & cheap aggregation (1 read total)
  Future<int> getActiveTasksCount() async {
    try {
      if (isCurrentSessionDemo) {
        final aggregate = await _tasksCollection
            .where('isDemo', isEqualTo: true)
            .where('status', isNotEqualTo: TaskStatus.completed.value)
            .count()
            .get();
        return aggregate.count ?? 0;
      }
      final aggregate = await _tasksCollection
          .where('status', isNotEqualTo: TaskStatus.completed.value)
          .count()
          .get();
      return aggregate.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Gets total contracts count
  Future<int> getContractsCount() async {
    try {
      if (isCurrentSessionDemo) {
        final aggregate = await _firestore
            .collection('contracts')
            .where('isDemo', isEqualTo: true)
            .count()
            .get();
        return aggregate.count ?? 0;
      }
      final aggregate = await _firestore.collection('contracts').count().get();
      return aggregate.count ?? 0;
    } catch (_) {
      final snapshot = await _firestore.collection('contracts').get();
      return snapshot.docs.length;
    }
  }

  /// Gets user details by ID
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Checks if the current authenticated user is a Demo session
  bool get isCurrentSessionDemo {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    return email != null && email.startsWith('demo.');
  }

  /// Deletes a task
  Future<void> deleteTask(String taskId) async {
    throw Exception('Deleting maintenance tasks has been disabled.');
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
    if (isCurrentSessionDemo) {
      throw Exception('Demo Mode Restriction: Deleting accounts is disabled in preview mode.');
    }
    await _firestore.collection('users').doc(uid).delete();
  }

  // --- Task Chat / Comments ---

  /// Get stream of messages for a specific task
  Stream<List<TaskMessageModel>> getTaskMessages(String taskId, {int limit = 50}) {
    return _tasksCollection
        .doc(taskId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
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
    String? fileUrl,
    String? fileName,
    List<String> receiverIds = const [], // To notify them
  }) async {
    final message = TaskMessageModel(
      id: '',
      senderId: senderId,
      senderName: senderName,
      text: text,
      fileUrl: fileUrl,
      fileName: fileName,
      createdAt: DateTime.now(),
    );

    await _tasksCollection.doc(taskId).collection('messages').add(message.toMap());

    final String msgPreview = text.isNotEmpty
        ? text
        : (fileName != null ? 'Sent an attachment: $fileName' : 'Sent an attachment');

    // Collect all task participants (Tenant + assigned Technician + explicit receivers)
    final Set<String> targetUserIds = {
      ...receiverIds.where((id) => id.isNotEmpty && id != senderId),
    };

    final task = await getTask(taskId);
    if (task != null) {
      if (task.tenantId.isNotEmpty && task.tenantId != senderId) {
        targetUserIds.add(task.tenantId);
      }
      if (task.technicianId != null &&
          task.technicianId!.isNotEmpty &&
          task.technicianId != senderId) {
        targetUserIds.add(task.technicianId!);
      }
    }

    // Send notifications to Tenant / Technician participants
    for (final String receiverId in targetUserIds) {
      await NotificationService().sendNotification(
        userId: receiverId,
        senderId: senderId,
        title: 'New Message from $senderName 💬',
        message: msgPreview,
        relatedTaskId: taskId,
      );
    }

    // Also notify Admins (notifyAdmins automatically skips senderId if an Admin sent the message)
    await NotificationService().notifyAdmins(
      senderId: senderId,
      title: 'Task Chat - $senderName 💬',
      message: msgPreview,
      relatedTaskId: taskId,
    );
  }

  // --- Direct Chat ---

  /// Get stream of messages for a direct chat
  Stream<List<TaskMessageModel>> getDirectChatMessages(String chatId, {int limit = 50}) {
    return _firestore.collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TaskMessageModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Add a message to a direct chat
  Future<void> addDirectChatMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    String? fileUrl,
    String? fileName,
    List<String> receiverIds = const [], // To notify them
  }) async {
    final message = TaskMessageModel(
      id: '',
      senderId: senderId,
      senderName: senderName,
      text: text,
      fileUrl: fileUrl,
      fileName: fileName,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('direct_chats').doc(chatId).collection('messages').add(message.toMap());
    
    // Also update the parent document so it exists and has the latest timestamp
    await _firestore.collection('direct_chats').doc(chatId).set({
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessage': text.isNotEmpty ? text : (fileName != null ? 'Attachment: $fileName' : 'New Message'),
      'lastSenderName': senderName,
    }, SetOptions(merge: true));

    // Send notifications to receivers
    if (receiverIds.isEmpty) {
      // If no receivers are specified, it's a message from Tenant to Management
      await NotificationService().notifyAdmins(
        senderId: senderId,
        title: 'Management Chat - $senderName 💬',
        message: text.isNotEmpty ? text : (fileName != null ? 'Sent an attachment: $fileName' : 'New Message'),
        relatedTaskId: chatId, // Using chatId as related ID so they know who sent it
      );
    } else {
      for (String receiverId in receiverIds) {
        if (receiverId.isNotEmpty && receiverId != senderId) {
          await NotificationService().sendNotification(
            userId: receiverId,
            senderId: senderId,
            title: 'New Message from $senderName 💬',
            message: text.isNotEmpty ? text : (fileName != null ? 'Sent an attachment: $fileName' : 'New Message'),
            relatedTaskId: chatId,
          );
        }
      }
    }
  }

  // --- Cheques & Payment Dates ---

  CollectionReference get _chequesCollection => _firestore.collection('cheques');

  /// Stream of cheques for a specific tenant, sorted by due date
  Stream<List<ChequeModel>> getChequesByTenantStream(String tenantUid) {
    return _chequesCollection
        .where('tenantUid', isEqualTo: tenantUid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => ChequeModel.fromFirestore(doc)).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  /// Future list of cheques for a specific tenant
  Future<List<ChequeModel>> getChequesByTenant(String tenantUid) async {
    final snapshot = await _chequesCollection
        .where('tenantUid', isEqualTo: tenantUid)
        .get();
    final list = snapshot.docs.map((doc) => ChequeModel.fromFirestore(doc)).toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  /// Stream of all cheques (for Admin)
  Stream<List<ChequeModel>> getAllChequesStream() {
    return _chequesCollection
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => ChequeModel.fromFirestore(doc)).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  /// Future list of all cheques (for Admin)
  Future<List<ChequeModel>> getAllCheques() async {
    if (isCurrentSessionDemo) {
      final snapshot = await _chequesCollection
          .where('isDemo', isEqualTo: true)
          .get();
      final list = snapshot.docs.map((doc) => ChequeModel.fromFirestore(doc)).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    }
    final snapshot = await _chequesCollection.get();
    final list = snapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['isDemo'] != true)
        .map((doc) => ChequeModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  /// Add a new cheque
  Future<String> addCheque(ChequeModel cheque) async {
    final docRef = await _chequesCollection.add(cheque.toMap());
    return docRef.id;
  }

  /// Update cheque fields (amount, dueDate, status, notes, etc.)
  Future<void> updateCheque(String chequeId, Map<String, dynamic> data) async {
    final updateData = Map<String, dynamic>.from(data);
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    await _chequesCollection.doc(chequeId).update(updateData);
  }

  /// Delete a cheque
  Future<void> deleteCheque(String chequeId) async {
    await _chequesCollection.doc(chequeId).delete();
  }

  /// Batch add multiple cheques (useful when generating installments)
  Future<void> batchCreateCheques(List<ChequeModel> cheques) async {
    final batch = _firestore.batch();
    for (final c in cheques) {
      final docRef = _chequesCollection.doc();
      batch.set(docRef, c.toMap());
    }
    await batch.commit();
  }

  /// Get all contracts belonging to a specific tenant
  Future<List<ContractModel>> getContractsByTenant(String tenantUid) async {
    if (isCurrentSessionDemo) {
      final snapshot = await _firestore
          .collection('contracts')
          .where('isDemo', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => ContractModel.fromFirestore(doc)).toList();
    }
    final snapshot = await _firestore
        .collection('contracts')
        .where('tenantUid', isEqualTo: tenantUid)
        .get();
    final list = snapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['isDemo'] != true)
        .map((doc) => ContractModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) {
      if (a.endDate == null) return 1;
      if (b.endDate == null) return -1;
      return a.endDate!.compareTo(b.endDate!);
    });
    return list;
  }
}
