import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_colors.dart';
import 'tenant_requests_view.dart';

class AdminTechniciansView extends StatefulWidget {
  const AdminTechniciansView({super.key});

  @override
  State<AdminTechniciansView> createState() => _AdminTechniciansViewState();
}

class _AdminTechniciansViewState extends State<AdminTechniciansView> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _allTenants = [];
  List<UserModel> _filteredTenants = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTechnicians() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final technicians = await _firestoreService.getTechnicians();
      setState(() {
        _allTenants = technicians;
        _filteredTenants = technicians;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredTenants = _allTenants;
      } else {
        _filteredTenants = _allTenants.where((t) {
          final nameMatch = t.name.toLowerCase().contains(query);
          final profMatch = (t.profession ?? '').toLowerCase().contains(query);
          return nameMatch || profMatch;
        }).toList();
      }
    });
  }

  void _showEditTechnicianDialog(UserModel technician) {
    final nameController = TextEditingController(text: technician.name);
    final phoneController = TextEditingController(text: technician.phone);
    String selectedProfession = technician.profession ?? 'Plumber';
    final professions = [
      'Plumber',
      'Electrician',
      'HVAC Technician',
      'Carpenter',
      'General Maintenance',
    ];
    if (!professions.contains(selectedProfession)) {
      professions.add(selectedProfession);
    }
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Technician'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedProfession,
                    decoration: const InputDecoration(labelText: 'Profession'),
                    items: professions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => selectedProfession = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fields cannot be empty')));
                            return;
                          }
                          setStateDialog(() => isSubmitting = true);
                          try {
                            await _firestoreService.updateUser(technician.uid, {
                              'name': nameController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'profession': selectedProfession,
                            });
                            if (mounted) {
                              Navigator.pop(ctx);
                              _fetchTechnicians();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Technician updated successfully')));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                            setStateDialog(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Name or Profession...',
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
              onPressed: _fetchTechnicians,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredTenants.isEmpty) {
      return const Center(
        child: Text(
          'No technicians found.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTechnicians,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredTenants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final technician = _filteredTenants[index];
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
                          technician.name.isNotEmpty ? technician.name[0].toUpperCase() : 'T',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              technician.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Profession: ${technician.profession ?? 'Not Set'}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (technician.totalRatings != null && technician.totalRatings! > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${technician.averageRating?.toStringAsFixed(1)} (${technician.totalRatings} ratings)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 16, color: AppColors.textHint),
                      const SizedBox(width: 8),
                      Text(
                        technician.phone,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Technician'),
                                content: Text('Are you sure you want to delete ${technician.name}? This will remove their access to the application.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await _firestoreService.deleteUser(technician.uid);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Technician deleted successfully.')));
                                  _fetchTechnicians(); // Refresh list
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
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _showEditTechnicianDialog(technician),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
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

class CreateTechnicianSheet extends StatefulWidget {
  const CreateTechnicianSheet({super.key});

  @override
  State<CreateTechnicianSheet> createState() => _CreateTechnicianSheetState();
}

class _CreateTechnicianSheetState extends State<CreateTechnicianSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedProfession = 'Plumber';
  final List<String> _professions = [
    'Plumber',
    'Electrician',
    'HVAC Technician',
    'Carpenter',
    'General Maintenance',
  ];

  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createTechnician');
      await callable.call({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'phone': _phoneController.text.trim(),
        'profession': _selectedProfession,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Technician registered successfully.')),
        );
        // We would ideally call _fetchTechnicians here, but because this sheet is rendered from 
        // admin_dashboard_view, we can just rely on the admin to refresh, or we can use an event bus/callback.
        // For now, the user can pull to refresh the technician list.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Register New Technician',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
              validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
              validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedProfession,
              decoration: const InputDecoration(labelText: 'Profession', prefixIcon: Icon(Icons.build)),
              items: _professions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedProfession = val);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: _isSubmitting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Register Technician'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

