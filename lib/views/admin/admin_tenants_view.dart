import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_colors.dart';
import 'tenant_requests_view.dart';
import 'admin_tenant_manage_view.dart';

class AdminTenantsView extends StatefulWidget {
  const AdminTenantsView({super.key});

  @override
  State<AdminTenantsView> createState() => _AdminTenantsViewState();
}

class _AdminTenantsViewState extends State<AdminTenantsView> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _allTenants = [];
  List<UserModel> _filteredTenants = [];
  bool _isLoading = true;
  String? _error;

  String _selectedBuilding = 'All Buildings';
  final List<String> _buildings = [
    'All Buildings',
    'Al nahda Building',
    'Al barsha Building',
    '77A Building',
    'Al warsan #80 Building',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTenants();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTenants() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final tenants = await _firestoreService.getTenants();
      setState(() {
        _allTenants = tenants;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredTenants = _allTenants.where((t) {
        final nameMatch = t.name.toLowerCase().contains(query);
        final aptMatch = (t.apartmentId ?? '').toLowerCase().contains(query);
        final searchMatch = query.isEmpty || nameMatch || aptMatch;
        
        final buildingMatch = _selectedBuilding == 'All Buildings' || t.buildingId == _selectedBuilding;

        return searchMatch && buildingMatch;
      }).toList();
    });
  }

  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Name or Apartment...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: _buildings.map((building) {
              final isSelected = building == _selectedBuilding;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(building),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedBuilding = building;
                    });
                    _applyFilters();
                  },
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  backgroundColor: Colors.white,
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
        const SizedBox(height: 8),
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchTenants,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredTenants.isEmpty) {
      return const Center(
        child: Text(
          'No tenants found.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTenants,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredTenants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final tenant = _filteredTenants[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : 'T',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenant.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tenant.buildingId ?? 'Building Not Set'} - Apt: ${tenant.apartmentId ?? 'Not Set'}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 16, color: AppColors.textHint),
                      const SizedBox(width: 8),
                      Text(
                        tenant.phone,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                      if (tenant.email != null && tenant.email!.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        const Icon(Icons.email_outlined, size: 16, color: AppColors.textHint),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tenant.email!,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                        TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Tenant'),
                                content: Text('Are you sure you want to delete ${tenant.name}? This will remove their access to the application.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await _firestoreService.deleteUser(tenant.uid);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenant deleted successfully.')));
                                  _fetchTenants(); // Refresh list
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),

                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminTenantManageView(tenant: tenant),
                              ),
                            ).then((_) => _fetchTenants()); // refresh on return
                          },
                          icon: const Icon(Icons.manage_accounts, size: 18),
                          label: const Text('Manage'),
                        ),

                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TenantRequestsView(
                                  tenantId: tenant.uid,
                                  tenantName: tenant.name,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('View History'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
