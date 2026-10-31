import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/maintenance_task_model.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/status_badge.dart';
import '../../core/enums/task_status.dart';
import '../../core/enums/user_role.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/maintenance_task_card.dart';

import 'admin_tenants_view.dart';
import 'admin_technicians_view.dart';
import 'admin_inbox_view.dart';
import 'admin_overview_tab.dart';
import '../../widgets/notifications_bell.dart';
import '../../widgets/app_notification_toast.dart';
import '../../widgets/task_photos_widget.dart';
import '../../utils/contact_helper.dart';
import '../shared/chat_sheet.dart';
import '../../services/push_notification_service.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int _selectedIndex = 0;
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Pending',
    'Assigned',
    'In Progress',
    'On Hold',
    'Waiting Confirmation',
    'Completed',
    'Rejected',
  ];
  
  UserModel? _adminUser;
  bool _isLoadingUser = true;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<NotificationModel>>? _notificationSub;
  final Set<String> _seenNotificationIds = {};
  bool _isInitialNotificationLoad = true;

  @override
  void initState() {
    super.initState();
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _loadAdminData(user.uid);
        _startForegroundNotificationListener(user.uid);
      }
    });

    final current = _auth.currentUser;
    if (current != null) {
      _loadAdminData(current.uid);
      _startForegroundNotificationListener(current.uid);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }

  void _startForegroundNotificationListener(String uid) {
    _notificationSub?.cancel();
    _notificationSub = NotificationService().getUserNotifications(uid).listen((notifications) {
      if (_isInitialNotificationLoad) {
        for (var n in notifications) {
          _seenNotificationIds.add(n.id);
        }
        _isInitialNotificationLoad = false;
        return;
      }

      for (var n in notifications) {
        if (!_seenNotificationIds.contains(n.id)) {
          _seenNotificationIds.add(n.id);
          if (!n.isRead && mounted) {
            _showForegroundNotificationBanner(n);
            break;
          }
        }
      }
    });
  }

  void _showForegroundNotificationBanner(NotificationModel notification) {
    if (!mounted) return;
    AppNotificationToast.show(
      context,
      title: notification.title,
      message: notification.message,
      onTap: () {
        NotificationService().markAsRead(notification.id);
        if (notification.title.contains('Chat') || notification.title.contains('Message')) {
          setState(() => _selectedIndex = 4);
        } else {
          setState(() => _selectedIndex = 1);
        }
      },
    );
  }

  Future<void> _loadAdminData([String? directUid]) async {
    final uid = directUid ?? _auth.currentUser?.uid;
    if (uid != null) {
      final user = await _firestoreService.getUser(uid);
      if (mounted) {
        setState(() {
          _adminUser = user;
          _isLoadingUser = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    }
  }

  void _showAssignBottomSheet(BuildContext context, MaintenanceTaskModel task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return AssignTechnicianSheet(
          task: task,
          firestoreService: _firestoreService,
        );
      },
    );
  }

  void _showTenantDetails(BuildContext context, String tenantId) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<UserModel?>(
          future: _firestoreService.getUser(tenantId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              );
            }
            final tenant = snapshot.data;
            if (tenant == null) {
              return AlertDialog(
                title: const Text('Tenant Details'),
                content: const Text('Tenant not found.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
              );
            }
            return AlertDialog(
              title: const Text('Tenant Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${tenant.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Phone: ${tenant.phone}'),
                  if (tenant.email != null && tenant.email!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Email: ${tenant.email}'),
                  ],
                  const SizedBox(height: 8),
                  Text('Building: ${tenant.buildingId ?? 'Not Set'}'),
                  const SizedBox(height: 8),
                  Text('Apartment: ${tenant.apartmentId ?? 'Not Set'}'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => ContactHelper.launchCall(tenant.phone),
                        icon: const Icon(Icons.phone),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => ContactHelper.launchWhatsApp(tenant.phone),
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleLogout() async {
    await PushNotificationService.clearUserToken(_auth.currentUser?.uid);
    await _auth.signOut();
  }

  void _handleAdminReject(MaintenanceTaskModel task) {
    MaintenanceTaskCard.showRejectDialog(
      context: context,
      task: task,
      onConfirm: (reason) async {
        await _firestoreService.rejectTask(taskId: task.id, reason: reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request rejected successfully / تم رفض الطلب بنجاح')),
          );
        }
      },
    );
  }

  void _handleAdminDelete(MaintenanceTaskModel task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text('Are you sure you want to delete this maintenance request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestoreService.deleteTask(task.id);
    }
  }

  void _openChat(MaintenanceTaskModel task) {
    if (_adminUser == null) return;
    ChatSheet.show(
      context: context,
      chatId: task.id,
      chatTitle: task.title,
      currentUserId: _adminUser!.uid,
      currentUserName: _adminUser!.name,
      isDirectChat: false,
      receiverIds: [
        task.tenantId,
        if (task.technicianId != null) task.technicianId!,
      ],
    );
  }

  Widget _buildRequestsView() {
    return StreamBuilder<List<MaintenanceTaskModel>>(
      stream: _firestoreService.getAllTasksForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonLoader(itemCount: 5);
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var tasks = snapshot.data ?? [];

        // Client-side filtering
        if (_selectedFilter != 'All') {
          final statusMap = {
            'Pending': TaskStatus.pending,
            'Assigned': TaskStatus.assigned,
            'In Progress': TaskStatus.inProgress,
            'On Hold': TaskStatus.onHold,
            'Waiting Confirmation': TaskStatus.waitingConfirmation,
            'Completed': TaskStatus.completed,
            'Rejected': TaskStatus.rejected,
          };
          final targetStatus = statusMap[_selectedFilter];
          tasks = tasks.where((t) => t.status == targetStatus).toList();
        }

        if (tasks.isEmpty) {
          return const Center(
            child: Text(
              'No tasks found.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final task = tasks[index];

            return MaintenanceTaskCard(
              task: task,
              userRole: UserRole.admin,
              onTap: (task.status == TaskStatus.pending ||
                      task.status == TaskStatus.assigned ||
                      task.status == TaskStatus.onHold)
                  ? () => _showAssignBottomSheet(context, task)
                  : null,
              onRejectTap: () => _handleAdminReject(task),
              onDeleteTap: () => _handleAdminDelete(task),
              onTenantInfoTap: () => _showTenantDetails(context, task.tenantId),
              onCommentsTap: () => _openChat(task),
              onCallTechnician: task.technicianId != null
                  ? () async {
                      final tech = await _firestoreService.getUser(task.technicianId!);
                      if (tech != null && tech.phone.isNotEmpty) {
                        ContactHelper.launchCall(tech.phone);
                      }
                    }
                  : null,
              onWhatsAppTechnician: task.technicianId != null
                  ? () async {
                      final tech = await _firestoreService.getUser(task.technicianId!);
                      if (tech != null && tech.phone.isNotEmpty) {
                        ContactHelper.launchWhatsApp(tech.phone);
                      }
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedIndex == 0 
                  ? 'Overview'
                  : _selectedIndex == 1 
                      ? 'Maintenance Requests' 
                      : _selectedIndex == 2
                          ? 'Tenant Directory' 
                          : _selectedIndex == 3
                              ? 'Technicians'
                              : 'Inbox / Messages',
            ),
            if (!_isLoadingUser && _adminUser != null)
              Text(
                'Welcome, ${_adminUser!.name}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          const NotificationsBell(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
        bottom: _selectedIndex == 1 
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = filter == _selectedFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedFilter = filter);
                        },
                        selectedColor: AppColors.primaryLight,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            )
          : null,
      ),
      body: _selectedIndex == 0
          ? AdminOverviewTab(
              firestoreService: _firestoreService,
              onNavigate: (index) => setState(() => _selectedIndex = index),
            )
          : _selectedIndex == 1 
              ? _buildRequestsView() 
              : _selectedIndex == 2 
                  ? const AdminTenantsView()
                  : _selectedIndex == 3
                      ? const AdminTechniciansView()
                      : const AdminInboxView(),
      floatingActionButton: _selectedIndex == 3
          ? FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (context) => Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: const CreateTechnicianSheet(),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Add Technician',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<List<MaintenanceTaskModel>>(
              stream: _firestoreService.getAllTasksForAdmin(),
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];
                final pendingCount = tasks.where((t) => t.status == TaskStatus.pending).length;
                return Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text(pendingCount.toString()),
                  child: const Icon(Icons.build),
                );
              },
            ),
            label: 'Requests',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Tenants',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.engineering),
            label: 'Technicians',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<List<NotificationModel>>(
              stream: NotificationService().getUserNotifications(FirebaseAuth.instance.currentUser?.uid ?? ''),
              builder: (context, snapshot) {
                final notifications = snapshot.data ?? [];
                // Only count unread messages/chats notifications for the Inbox badge
                final unreadChats = notifications.where((n) => !n.isRead && (n.title.contains('Chat') || n.title.contains('Message'))).length;
                return Badge(
                  isLabelVisible: unreadChats > 0,
                  label: Text(unreadChats.toString()),
                  child: const Icon(Icons.mail),
                );
              }
            ),
            label: 'Inbox',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textHint,
      ),
    );
  }
}

class AssignTechnicianSheet extends StatefulWidget {
  final MaintenanceTaskModel task;
  final FirestoreService firestoreService;

  const AssignTechnicianSheet({
    super.key,
    required this.task,
    required this.firestoreService,
  });

  @override
  State<AssignTechnicianSheet> createState() => _AssignTechnicianSheetState();
}

class _AssignTechnicianSheetState extends State<AssignTechnicianSheet> {
  List<UserModel>? _technicians;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTechnicians();
  }

  Future<void> _loadTechnicians() async {
    try {
      final techs = await widget.firestoreService.getTechnicians();
      if (mounted) {
        setState(() {
          // Sort technicians: matches first
          techs.sort((a, b) {
            final aMatch = _isMatch(a.profession, widget.task.category);
            final bMatch = _isMatch(b.profession, widget.task.category);
            if (aMatch && !bMatch) return -1;
            if (!aMatch && bMatch) return 1;
            return a.name.compareTo(b.name);
          });
          _technicians = techs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isMatch(String? profession, String category) {
    if (profession == null) return false;
    final p = profession.toLowerCase();
    final c = category.toLowerCase();
    if (c.contains('plumb') && p.contains('plumb')) return true;
    if (c.contains('elect') && p.contains('elect')) return true;
    if (c.contains('ac') && p.contains('ac')) return true;
    if (c.contains('hvac') && p.contains('hvac')) return true;
    if ((c.contains('carpet') || c.contains('carpent')) && p.contains('carpent')) return true;
    if (p.contains(c) || c.contains(p)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Assign Technician',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Task: ${widget.task.title}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_technicians == null || _technicians!.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No technicians found.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _technicians!.length,
                itemBuilder: (context, index) {
                  final tech = _technicians![index];
                  final isAssigned = widget.task.technicianId == tech.uid;
                  return Card(
                    elevation: 0,
                    color: isAssigned ? AppColors.statusApprovedBg : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isAssigned ? AppColors.statusApprovedText : AppColors.border,
                      ),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAssigned ? AppColors.statusApprovedText : AppColors.primaryLight,
                        child: Text(
                          tech.name.isNotEmpty ? tech.name[0].toUpperCase() : 'T',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        tech.name.isNotEmpty ? tech.name : 'Unknown Tech',
                        style: TextStyle(
                          fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal,
                          color: isAssigned ? AppColors.statusApprovedText : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${tech.profession ?? 'No profession'} • ${tech.phone}',
                        style: TextStyle(
                          color: isAssigned ? AppColors.statusApprovedText.withValues(alpha: 0.8) : AppColors.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.phone, color: AppColors.primary, size: 20),
                            onPressed: () => ContactHelper.launchCall(tech.phone),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                            onPressed: () => ContactHelper.launchWhatsApp(tech.phone),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          if (_isMatch(tech.profession, widget.task.category))
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.star, color: Colors.amber, size: 20),
                            ),
                          if (isAssigned)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.check_circle, color: AppColors.statusApprovedText),
                            ),
                        ],
                      ),
                      onTap: () async {
                        if (!isAssigned) {
                          // Show a loading indicator on the tile or just let it close
                          await widget.firestoreService.assignTask(widget.task.id, tech.uid, tech.name);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
