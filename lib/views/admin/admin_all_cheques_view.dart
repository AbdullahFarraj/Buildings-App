import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cheque_model.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import 'admin_tenant_details_view.dart';

class AdminAllChequesView extends StatefulWidget {
  const AdminAllChequesView({super.key});

  @override
  State<AdminAllChequesView> createState() => _AdminAllChequesViewState();
}

class _AdminAllChequesViewState extends State<AdminAllChequesView> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<ChequeModel> _allCheques = [];
  List<ChequeModel> _filteredCheques = [];
  bool _isLoading = true;
  String? _error;

  String _statusFilter = 'all'; // all, pending, due_soon, paid, overdue, bounced
  String _selectedBuilding = 'All Buildings';
  List<String> _buildings = ['All Buildings'];

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _fetchCheques();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCheques() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final cheques = await _firestoreService.getAllCheques();

      final dynamicBuildings = cheques
          .map((c) => c.buildingName ?? '')
          .where((b) => b.trim().isNotEmpty)
          .toSet()
          .toList()..sort();

      setState(() {
        _allCheques = cheques;
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
      _filteredCheques = _allCheques.where((c) {
        final matchesQuery = query.isEmpty ||
            c.chequeNumber.toLowerCase().contains(query) ||
            c.tenantName.toLowerCase().contains(query) ||
            c.bankName.toLowerCase().contains(query) ||
            (c.unitNumber ?? '').toLowerCase().contains(query) ||
            (c.buildingName ?? '').toLowerCase().contains(query) ||
            (c.contractCode ?? '').toLowerCase().contains(query);

        final matchesBuilding = _selectedBuilding == 'All Buildings' ||
            (c.buildingName ?? '') == _selectedBuilding;

        bool matchesStatus = true;
        if (_statusFilter == 'pending') matchesStatus = c.isPending && !c.isOverdue;
        if (_statusFilter == 'due_soon') matchesStatus = c.isDueSoon;
        if (_statusFilter == 'paid') matchesStatus = c.isPaid;
        if (_statusFilter == 'overdue') matchesStatus = c.isOverdue;
        if (_statusFilter == 'bounced') matchesStatus = c.isBounced;

        return matchesQuery && matchesBuilding && matchesStatus;
      }).toList();
    });
  }

  Future<void> _toggleChequePaid(ChequeModel cheque) async {
    final newStatus = cheque.isPaid ? 'pending' : 'paid';
    try {
      await _firestoreService.updateCheque(cheque.id, {'status': newStatus});
      _fetchCheques();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stats calculation
    final totalCount = _allCheques.length;
    final totalAmount = _allCheques.fold<double>(0, (acc, c) => acc + c.amount);
    final paidAmount = _allCheques.where((c) => c.isPaid).fold<double>(0, (acc, c) => acc + c.amount);
    final pendingAmount = _allCheques.where((c) => !c.isPaid && !c.isCancelled).fold<double>(0, (acc, c) => acc + c.amount);
    final overdueCount = _allCheques.where((c) => c.isOverdue).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('شيكات الإيجار والدفعات / Cheques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(width: 8),
            if (!_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_allCheques.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _fetchCheques,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث باسم المستأجر، رقم الشيك، البنك، الشقة...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Buildings Filter Chips
                if (_buildings.length > 2)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _buildings.map((b) {
                        final isSel = b == _selectedBuilding;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(b, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : AppColors.textPrimary)),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.grey.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onSelected: (val) {
                              setState(() => _selectedBuilding = b);
                              _applyFilters();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 8),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('الكل ($totalCount)', 'all'),
                      _buildStatusChip('قيد الانتظار', 'pending'),
                      _buildStatusChip('مستحق قريباً', 'due_soon'),
                      _buildStatusChip('مدفوع', 'paid'),
                      _buildStatusChip('متأخر ($overdueCount)', 'overdue', isAlert: overdueCount > 0),
                      _buildStatusChip('مرتجع', 'bounced'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Overview Stats Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildMiniStat('إجمالي المبلغ', '${_currencyFormat.format(totalAmount)} د.إ', AppColors.primary),
                ),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                Expanded(
                  child: _buildMiniStat('المدفوع', '${_currencyFormat.format(paidAmount)} د.إ', Colors.green.shade700),
                ),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                Expanded(
                  child: _buildMiniStat('المتبقي', '${_currencyFormat.format(pendingAmount)} د.إ', overdueCount > 0 ? Colors.red.shade700 : Colors.orange.shade800),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Cheques List
          Expanded(
            child: _buildChequesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, {bool isAlert = false}) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() => _statusFilter = value);
          _applyFilters();
        },
        selectedColor: isAlert ? Colors.red.shade700 : AppColors.primary,
        backgroundColor: isAlert ? Colors.red.shade50 : Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isAlert ? Colors.red.shade900 : AppColors.textPrimary),
          fontWeight: isSelected || isAlert ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.transparent : (isAlert ? Colors.red.shade300 : AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 1),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }

  Widget _buildChequesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('خطأ: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchCheques, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }

    if (_filteredCheques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.payment_outlined, size: 50, color: Colors.grey),
            SizedBox(height: 12),
            Text('لا توجد شيكات تطابق معايير البحث', style: TextStyle(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCheques,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredCheques.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final cheque = _filteredCheques[index];

          Color badgeColor;
          String badgeText;
          if (cheque.isPaid) {
            badgeColor = Colors.green;
            badgeText = 'تم الصرف ✅';
          } else if (cheque.isBounced) {
            badgeColor = Colors.red;
            badgeText = 'مرتجع ❌';
          } else if (cheque.isOverdue) {
            badgeColor = Colors.red.shade900;
            badgeText = 'متأخر (${-cheque.daysUntilDue} يوم)';
          } else if (cheque.isDueSoon) {
            badgeColor = Colors.amber.shade900;
            badgeText = 'مستحق قريباً (${cheque.daysUntilDue} يوم)';
          } else {
            badgeColor = Colors.blueGrey;
            badgeText = 'قيد الانتظار';
          }

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cheque.isOverdue ? Colors.red.shade300 : AppColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                if (cheque.tenantUid.isNotEmpty) {
                  final tenant = await _firestoreService.getUser(cheque.tenantUid);
                  if (tenant != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminTenantDetailsView(tenant: tenant),
                      ),
                    ).then((_) => _fetchCheques());
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: cheque.isPaid ? Colors.green.shade50 : AppColors.primaryLight.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.account_balance,
                            size: 18,
                            color: cheque.isPaid ? Colors.green.shade700 : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cheque.tenantName.isNotEmpty ? cheque.tenantName : 'مستأجر',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${cheque.bankName} - شيك #${cheque.chequeNumber}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('المبلغ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text(
                              '${_currencyFormat.format(cheque.amount)} د.إ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: cheque.isPaid ? Colors.green.shade700 : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('تاريخ ووقت الاستحقاق للدفع', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Row(
                              children: [
                                const Icon(Icons.event, size: 14, color: AppColors.accent),
                                const SizedBox(width: 4),
                                Text(
                                  _dateFormat.format(cheque.dueDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (cheque.buildingName != null || cheque.unitNumber != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '🏢 ${cheque.buildingName ?? ""} - شقة ${cheque.unitNumber ?? ""}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cheque.isPaid ? Colors.orange.shade800 : Colors.green.shade700,
                            side: BorderSide(color: cheque.isPaid ? Colors.orange.shade300 : Colors.green.shade400),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _toggleChequePaid(cheque),
                          icon: Icon(cheque.isPaid ? Icons.undo : Icons.check_circle, size: 14),
                          label: Text(cheque.isPaid ? 'إعادة كغير مدفوع' : 'صرف الشيك', style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            if (cheque.tenantUid.isNotEmpty) {
                              final tenant = await _firestoreService.getUser(cheque.tenantUid);
                              if (tenant != null && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminTenantDetailsView(tenant: tenant),
                                  ),
                                ).then((_) => _fetchCheques());
                              }
                            }
                          },
                          icon: const Icon(Icons.person, size: 14),
                          label: const Text('المستأجر', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
