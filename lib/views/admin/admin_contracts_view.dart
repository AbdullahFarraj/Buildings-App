import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/contract_model.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../utils/contact_helper.dart';

class AdminContractsView extends StatefulWidget {
  const AdminContractsView({super.key});

  @override
  State<AdminContractsView> createState() => _AdminContractsViewState();
}

class _AdminContractsViewState extends State<AdminContractsView> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<ContractModel> _allContracts = [];
  List<ContractModel> _filteredContracts = [];
  bool _isLoading = true;
  String? _error;

  String _selectedBuilding = 'All Buildings';
  List<String> _buildings = ['All Buildings'];

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _fetchContracts();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContracts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final contracts = await _firestoreService.getContracts();

      final dynamicBuildings = contracts
          .map((c) => c.buildingName)
          .where((b) => b.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _allContracts = contracts;
        _buildings = ['All Buildings', ...dynamicBuildings];
        if (!_buildings.contains(_selectedBuilding)) {
          _selectedBuilding = 'All Buildings';
        }
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

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredContracts = _allContracts.where((c) {
        final matchesQuery = query.isEmpty ||
            c.tenantName.toLowerCase().contains(query) ||
            c.mobileNumber.contains(query) ||
            c.unitNumber.toLowerCase().contains(query) ||
            c.contractCode.toLowerCase().contains(query) ||
            c.buildingName.toLowerCase().contains(query);

        final matchesBuilding = _selectedBuilding == 'All Buildings' ||
            c.buildingName == _selectedBuilding;

        return matchesQuery && matchesBuilding;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Lease Contracts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (!_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_allContracts.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Tenant, Unit, Phone, or Code...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: AppColors.background,
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
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Body List
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
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
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchContracts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredContracts.isEmpty) {
      return const Center(
        child: Text(
          'No contracts found.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchContracts,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredContracts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final contract = _filteredContracts[index];
          return _buildContractCard(contract);
        },
      ),
    );
  }

  Widget _buildContractCard(ContractModel contract) {
    final now = DateTime.now();
    int? daysRemaining;
    if (contract.endDate != null) {
      daysRemaining = contract.endDate!.difference(now).inDays;
    }

    Color badgeColor = Colors.green;
    String badgeText = 'ACTIVE';

    if (daysRemaining != null) {
      if (daysRemaining < 0) {
        badgeColor = Colors.red;
        badgeText = 'EXPIRED';
      } else if (daysRemaining <= 60) {
        badgeColor = Colors.orange;
        badgeText = '$daysRemaining Days Left';
      }
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code & Badge
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contract #${contract.contractCode.isNotEmpty ? contract.contractCode : contract.contractNumber?.toString() ?? '-'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Unit: ${contract.unitNumber} (${contract.unitType.isNotEmpty ? contract.unitType : "Flat"})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // Tenant Name & Building
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    contract.tenantName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.apartment_outlined, size: 16, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    contract.buildingName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (contract.customerEmail != null && contract.customerEmail!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      contract.customerEmail!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Dates Row (Start -> End)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                      const SizedBox(height: 2),
                      Text(
                        contract.startDate != null ? _dateFormat.format(contract.startDate!) : '-',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, size: 16, color: AppColors.textHint),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('End Date', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                      const SizedBox(height: 2),
                      Text(
                        contract.endDate != null ? _dateFormat.format(contract.endDate!) : '-',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: (daysRemaining != null && daysRemaining <= 60) ? Colors.orange.shade800 : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Footer: Rent Amount & Phone action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Annual Rent', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                    Text(
                      '${contract.yearValue > 0 ? contract.yearValue.toStringAsFixed(0) : contract.rentAmount.toStringAsFixed(0)} AED',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (contract.mobileNumber.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                        tooltip: 'Call Tenant',
                        onPressed: () => ContactHelper.launchCall(contract.mobileNumber),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_outlined, color: Colors.green, size: 20),
                        tooltip: 'WhatsApp',
                        onPressed: () => ContactHelper.launchWhatsApp(contract.mobileNumber),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
