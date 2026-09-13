import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/maintenance_task_model.dart';
import '../models/user_model.dart';
import '../core/enums/task_status.dart';
import '../core/enums/user_role.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _tasksCollection => _firestore.collection('tasks');

  /// Creates a new maintenance task.
  Future<void> createTask(MaintenanceTaskModel task) async {
    // If task.id is empty, Firestore will generate an ID.
    // However, since MaintenanceTaskModel expects an ID, it's better to 
    // generate a document reference first if the ID is meant to be new.
    DocumentReference docRef = task.id.isEmpty 
        ? _tasksCollection.doc() 
        : _tasksCollection.doc(task.id);
        
    await docRef.set(task.toMap());
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

  /// Assigns a task to a technician and updates status to approved.
  Future<void> assignTask(String taskId, String technicianId) async {
    await _tasksCollection.doc(taskId).update({
      'technicianId': technicianId,
      'status': TaskStatus.approved.value,
    });
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

    if (status == TaskStatus.completed) {
      updates['completedAt'] = FieldValue.serverTimestamp();
      if (completionProofUrl != null) {
        updates['completionProofUrl'] = completionProofUrl;
      }
      if (completionNotes != null) {
        updates['completionNotes'] = completionNotes;
      }
    }

    await _tasksCollection.doc(taskId).update(updates);
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
}
