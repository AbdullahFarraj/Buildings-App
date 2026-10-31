import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/maintenance_task_model.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/enums/task_status.dart';
import '../../services/notification_service.dart';
import 'admin_contracts_view.dart';

class AdminOverviewTab extends StatefulWidget {
  final FirestoreService firestoreService;
  final Function(int) onNavigate;

  const AdminOverviewTab({
    super.key,
    required this.firestoreService,
    required this.onNavigate,
  });

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  bool _isLoading = true;
  List<UserModel> _tenants = [];
  List<UserModel> _technicians = [];
  List<MaintenanceTaskModel> _recentTasks = [];
  int _activeRequests = 0;
  int _contractsCount = 0;
  StreamSubscription<List<MaintenanceTaskModel>>? _tasksSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _tasksSub = widget.firestoreService.getAllTasksForAdmin().listen((tasksList) {
      if (mounted) {
        setState(() {
          _recentTasks = tasksList.take(5).toList();
          _activeRequests = tasksList.where((t) => t.status != TaskStatus.completed).length;
        });
      }
    });
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    List<UserModel> tenants = [];
    List<UserModel> technicians = [];
    int contractsCount = 0;
    List<MaintenanceTaskModel> recentTasks = [];
    int activeRequests = 0;

    try {
      tenants = await widget.firestoreService.getTenants();
    } catch (e) {
      debugPrint('Error loading tenants: $e');
    }

    try {
      technicians = await widget.firestoreService.getTechnicians();
    } catch (e) {
      debugPrint('Error loading technicians: $e');
    }

    try {
      contractsCount = await widget.firestoreService.getContractsCount();
    } catch (e) {
      debugPrint('Error loading contracts count: $e');
    }

    try {
      final tasksStream = widget.firestoreService.getAllTasksForAdmin();
      final tasksList = await tasksStream.first;
      recentTasks = tasksList.take(5).toList();
      activeRequests = tasksList.where((t) => t.status != TaskStatus.completed).length;
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }

    if (mounted) {
      setState(() {
        _tenants = tenants;
        _technicians = technicians;
        _contractsCount = contractsCount;
        _recentTasks = recentTasks;
        _activeRequests = activeRequests;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _expiringContracts {
    final now = DateTime.now();
    final List<Map<String, dynamic>> list = [];
    for (final t in _tenants) {
      for (final prop in t.allProperties) {
        final end = prop.endDate ?? t.contractEndDate;
        if (end != null) {
          final diff = end.difference(now).inDays;
          if (diff >= 0 && diff <= 60) {
            list.add({
              'tenant': t,
              'tenantName': t.name,
              'buildingName': prop.buildingName,
              'unitNumber': prop.unitNumber,
              'endDate': end,
              'daysRemaining': diff,
            });
          }
        }
      }
    }
    list.sort((a, b) => (a['endDate'] as DateTime).compareTo(b['endDate'] as DateTime));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            if (_expiringContracts.isNotEmpty) ...[
              _buildSectionTitle('Expiring Contracts (Next 60 Days)', Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(height: 12),
              _buildExpiringList(),
              const SizedBox(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Recent Requests', Icons.build_circle_outlined),
                TextButton(
                  onPressed: () => widget.onNavigate(1), // Go to requests tab
                  child: const Text('See All'),
                )
              ],
            ),
            const SizedBox(height: 12),
            _buildRecentTasks(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Tenants',
                _tenants.length.toString(),
                Icons.group,
                AppColors.primary,
                onTap: () => widget.onNavigate(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Contracts',
                _contractsCount.toString(),
                Icons.assignment_outlined,
                const Color(0xFF6C5CE7),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminContractsView()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active Tasks',
                _activeRequests.toString(),
                Icons.engineering,
                AppColors.accent,
                isDark: true,
                onTap: () => widget.onNavigate(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Techs',
                _technicians.length.toString(),
                Icons.handyman,
                Colors.teal,
                onTap: () => widget.onNavigate(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color, {bool isDark = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isDark ? Colors.black87 : Colors.white, size: 28),
          const SizedBox(height: 16),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.black87 : Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Quick Actions', Icons.flash_on),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildActionChip('Manage Tenants', Icons.manage_accounts, () => widget.onNavigate(2)),
              const SizedBox(width: 12),
              _buildActionChip('All Contracts', Icons.assignment_outlined, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminContractsView()),
                );
              }),
              const SizedBox(width: 12),
              _buildActionChip('Manage Techs', Icons.engineering, () => widget.onNavigate(3)),
              const SizedBox(width: 12),
              _buildActionChip('Broadcast Message', Icons.campaign, () {
                _showBroadcastSheet();
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, {Color color = AppColors.primary}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _expiringContracts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _expiringContracts[index];
        final days = item['daysRemaining'] as int;
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['tenantName'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      '${item['buildingName']} - Apt ${item['unitNumber']}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$days Days',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text('Remaining', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final tenant = item['tenant'] as UserModel;
                      await NotificationService().sendContractExpiryReminder(tenant.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reminder sent to ${tenant.name}')),
                        );
                      }
                    },
                    child: const Icon(Icons.notification_add, color: Colors.orange, size: 20),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTasks() {
    if (_recentTasks.isEmpty) {
      return const Center(child: Text('No recent requests.', style: TextStyle(color: AppColors.textHint)));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentTasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = _recentTasks[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${task.buildingId} - Apt ${task.apartmentNumber}',
              style: const TextStyle(fontSize: 13),
            ),
            trailing: _buildStatusChip(task.status),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(TaskStatus status) {
    Color color;
    switch (status) {
      case TaskStatus.pending: color = Colors.orange; break;
      case TaskStatus.assigned: color = Colors.blue; break;
      case TaskStatus.inProgress: color = Colors.purple; break;
      case TaskStatus.onHold: color = Colors.amber; break;
      case TaskStatus.waitingConfirmation: color = Colors.teal; break;
      case TaskStatus.completed: color = Colors.green; break;
      case TaskStatus.rejected: color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showBroadcastSheet() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isSending = false;
    
    // Extract unique buildings from tenants (including multi-property tenants)
    final Set<String> buildingsSet = {'All Buildings'};
    for (var tenant in _tenants) {
      if (tenant.buildingId != null && tenant.buildingId!.trim().isNotEmpty) {
        buildingsSet.add(tenant.buildingId!.trim());
      }
      for (var prop in tenant.allProperties) {
        if (prop.buildingName.trim().isNotEmpty) {
          buildingsSet.add(prop.buildingName.trim());
        }
      }
    }
    final List<String> availableBuildings = buildingsSet.toList()..sort();
    String selectedBuilding = 'All Buildings';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Broadcast Announcement',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  const Text('Send a message to all tenants in the system.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBuilding,
                    decoration: const InputDecoration(
                      labelText: 'Target Building',
                      prefixIcon: Icon(Icons.apartment),
                    ),
                    items: availableBuildings.map((building) {
                      return DropdownMenuItem(
                        value: building,
                        child: Text(building),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedBuilding = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Water Maintenance Tomorrow',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Enter your announcement here...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSending ? null : () async {
                      if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                        return;
                      }
                      setState(() => isSending = true);
                      await NotificationService().sendBroadcastToTenants(
                        titleController.text.trim(),
                        messageController.text.trim(),
                        buildingId: selectedBuilding,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Broadcast sent to $selectedBuilding successfully!')),
                        );
                      }
                    },
                    child: isSending
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Send Broadcast'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

