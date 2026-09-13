import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/maintenance_task_model.dart';
import '../../models/user_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/status_badge.dart';
import '../../core/enums/task_status.dart';
import '../../core/theme/app_colors.dart';

import 'admin_tenants_view.dart';
import 'admin_technicians_view.dart';

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
  final List<String> _filters = ['All', 'Pending', 'Assigned', 'In Progress', 'Completed'];
  
  UserModel? _adminUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final uid = _auth.currentUser?.uid;
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
    await _auth.signOut();
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
            'Assigned': TaskStatus.approved,
            'In Progress': TaskStatus.inProgress,
            'Completed': TaskStatus.completed,
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
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
            final formattedDate = dateFormat.format(task.createdAt);

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border, width: 1),
              ),
              child: InkWell(
                onTap: (task.status == TaskStatus.pending || task.status == TaskStatus.approved)
                    ? () => _showAssignBottomSheet(context, task)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${task.buildingId ?? 'Building'} - Apt ${task.apartmentNumber}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                                  onPressed: () => _showTenantDetails(context, task.tenantId),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Tenant Details',
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: task.status),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Request'),
                                  content: const Text('Are you sure you want to delete this maintenance request?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _firestoreService.deleteTask(task.id);
                              }
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            tooltip: 'Delete Request',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.category, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            task.category,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                      if (task.status == TaskStatus.pending || task.status == TaskStatus.approved) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.assignment_ind, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.status == TaskStatus.pending ? 'Tap to assign technician' : 'Tap to reassign technician',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
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
                  ? 'Admin Dashboard' 
                  : _selectedIndex == 1 
                      ? 'Tenant Directory' 
                      : 'Technicians',
            ),
            if (!_isLoadingUser && _adminUser != null)
              Text(
                'Welcome, ${_adminUser!.name}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
        bottom: _selectedIndex == 0 
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
          ? _buildRequestsView() 
          : _selectedIndex == 1 
              ? const AdminTenantsView()
              : const AdminTechniciansView(),
      floatingActionButton: _selectedIndex == 2
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Tenants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.engineering),
            label: 'Technicians',
          ),
        ],
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
                        tech.phone,
                        style: TextStyle(
                          color: isAssigned ? AppColors.statusApprovedText.withOpacity(0.8) : AppColors.textSecondary,
                        ),
                      ),
                      trailing: isAssigned 
                          ? const Icon(Icons.check_circle, color: AppColors.statusApprovedText)
                          : null,
                      onTap: () async {
                        if (!isAssigned) {
                          // Show a loading indicator on the tile or just let it close
                          await widget.firestoreService.assignTask(widget.task.id, tech.uid);
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
