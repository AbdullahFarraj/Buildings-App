import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/user_model.dart';
import '../../models/contract_model.dart';
import '../../models/cheque_model.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../utils/contact_helper.dart';
import '../shared/chat_sheet.dart';
import 'tenant_requests_view.dart';

class AdminTenantDetailsView extends StatefulWidget {
  final UserModel tenant;

  const AdminTenantDetailsView({super.key, required this.tenant});

  @override
  State<AdminTenantDetailsView> createState() => _AdminTenantDetailsViewState();
}

class _AdminTenantDetailsViewState extends State<AdminTenantDetailsView> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late UserModel _tenant;
  late TabController _tabController;

  bool _isLoading = false;
  String _chequeFilter = 'all'; // all, pending, due_soon, paid, overdue, bounced

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _tenant = widget.tenant;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshTenant() async {
    try {
      final updated = await _firestoreService.getUser(_tenant.uid);
      if (updated != null && mounted) {
        setState(() {
          _tenant = updated;
        });
      }
    } catch (_) {}
  }

  // ==========================================
  // 💳 CHEQUE ACTIONS
  // ==========================================

  void _showAddChequeDialog({ContractModel? preselectedContract}) {
    final chequeNumCtrl = TextEditingController();
    final bankCtrl = TextEditingController(text: 'Emirates NBD');
    final amountCtrl = TextEditingController(
      text: preselectedContract != null && preselectedContract.rentAmount > 0
          ? (preselectedContract.rentAmount / 4).toStringAsFixed(0)
          : '',
    );
    final notesCtrl = TextEditingController();
    
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    String selectedStatus = 'pending';
    String? selectedBuilding = preselectedContract?.buildingName ?? 
        (_tenant.allProperties.isNotEmpty ? _tenant.allProperties.first.buildingName : null);
    String? selectedUnit = preselectedContract?.unitNumber ?? 
        (_tenant.allProperties.isNotEmpty ? _tenant.allProperties.first.unitNumber : null);
    String? selectedContractCode = preselectedContract?.contractCode ?? 
        (_tenant.allProperties.isNotEmpty ? _tenant.allProperties.first.contractCode : null);

    final List<String> popularBanks = [
      'Emirates NBD',
      'Abu Dhabi Commercial Bank (ADCB)',
      'First Abu Dhabi Bank (FAB)',
      'Dubai Islamic Bank (DIB)',
      'Mashreq Bank',
      'RAKBANK',
      'Commercial Bank of Dubai (CBD)',
      'Sharjah Islamic Bank (SIB)',
      'Ajman Bank',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.payment, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('إضافة شيك جديد / Add Cheque', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: chequeNumCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الشيك * (Cheque Number)',
                        hintText: 'e.g. 000142',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ بالدرهم * (Amount AED)',
                        hintText: 'e.g. 15000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: popularBanks.contains(bankCtrl.text) ? bankCtrl.text : 'Other',
                      decoration: const InputDecoration(
                        labelText: 'اسم البنك (Bank Name)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      items: popularBanks.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            bankCtrl.text = val;
                          });
                        }
                      },
                    ),
                    if (bankCtrl.text == 'Other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: bankCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اكتب اسم البنك (Enter Bank)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Due Date Picker (وقت الدفع)
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تاريخ ووقت الاستحقاق للدفع * (Due Date)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(_dateFormat.format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.edit, size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'حالة الشيك (Status)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.check_circle_outline),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار (Pending)')),
                        DropdownMenuItem(value: 'paid', child: Text('مدفوع / تم الصرف (Paid)')),
                        DropdownMenuItem(value: 'bounced', child: Text('مرتجع (Bounced)')),
                        DropdownMenuItem(value: 'cancelled', child: Text('ملغي (Cancelled)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedStatus = val);
                      },
                    ),
                    if (_tenant.allProperties.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'العقار المرتبط (Property / Unit)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.apartment),
                        ),
                        items: _tenant.allProperties.map((p) {
                          return DropdownMenuItem(
                            value: p.unitNumber,
                            child: Text('${p.buildingName} - شقة ${p.unitNumber}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final matched = _tenant.allProperties.firstWhere((p) => p.unitNumber == val);
                            setDialogState(() {
                              selectedUnit = matched.unitNumber;
                              selectedBuilding = matched.buildingName;
                              selectedContractCode = matched.contractCode;
                            });
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات إضافية (Notes)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء / Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final numStr = chequeNumCtrl.text.trim();
                    final amt = double.tryParse(amountCtrl.text.trim());
                    if (numStr.isEmpty || amt == null || amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء إدخال رقم الشيك ومبلغ صحيح')),
                      );
                      return;
                    }

                    final newCheque = ChequeModel(
                      id: '',
                      tenantUid: _tenant.uid,
                      tenantName: _tenant.name,
                      chequeNumber: numStr,
                      bankName: bankCtrl.text.trim().isNotEmpty ? bankCtrl.text.trim() : 'Bank',
                      amount: amt,
                      dueDate: selectedDate,
                      status: selectedStatus,
                      buildingName: selectedBuilding,
                      unitNumber: selectedUnit,
                      contractCode: selectedContractCode,
                      notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                    );

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      await _firestoreService.addCheque(newCheque);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تمت إضافة الشيك بنجاح ✅')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ أثناء إضافة الشيك: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('حفظ الشيك / Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditChequeDialog(ChequeModel cheque) {
    final chequeNumCtrl = TextEditingController(text: cheque.chequeNumber);
    final bankCtrl = TextEditingController(text: cheque.bankName);
    final amountCtrl = TextEditingController(text: cheque.amount.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: cheque.notes ?? '');
    
    DateTime selectedDate = cheque.dueDate;
    String selectedStatus = cheque.status;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.edit, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('تعديل بيانات الشيك / Edit Cheque', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: chequeNumCtrl,
                      decoration: const InputDecoration(labelText: 'رقم الشيك (Cheque Number)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(labelText: 'المبلغ بالدرهم (Amount AED)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bankCtrl,
                      decoration: const InputDecoration(labelText: 'اسم البنك (Bank Name)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تاريخ ووقت الاستحقاق (Due Date)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(_dateFormat.format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.edit, size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'حالة الشيك (Status)', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار (Pending)')),
                        DropdownMenuItem(value: 'paid', child: Text('مدفوع / تم الصرف (Paid)')),
                        DropdownMenuItem(value: 'bounced', child: Text('مرتجع (Bounced)')),
                        DropdownMenuItem(value: 'cancelled', child: Text('ملغي (Cancelled)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedStatus = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'ملاحظات (Notes)', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? cheque.amount;
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      await _firestoreService.updateCheque(cheque.id, {
                        'chequeNumber': chequeNumCtrl.text.trim(),
                        'bankName': bankCtrl.text.trim(),
                        'amount': amt,
                        'dueDate': Timestamp.fromDate(selectedDate),
                        'status': selectedStatus,
                        'notes': notesCtrl.text.trim(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تحديث الشيك بنجاح ✅')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ أثناء تحديث الشيك: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('تحديث / Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleChequePaid(ChequeModel cheque) async {
    final newStatus = cheque.isPaid ? 'pending' : 'paid';
    setState(() => _isLoading = true);
    try {
      await _firestoreService.updateCheque(cheque.id, {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'paid' ? 'تم تسجيل الشيك كـ (مدفوع / تم الصرف) ✅' : 'تمت إعادة الشيك لـ (قيد الانتظار) ⏳'),
            backgroundColor: newStatus == 'paid' ? Colors.green.shade800 : Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCheque(ChequeModel cheque) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الشيك'),
        content: Text('هل أنت متأكد من حذف الشيك رقم ${cheque.chequeNumber} بمبلغ ${_currencyFormat.format(cheque.amount)} درهم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _firestoreService.deleteCheque(cheque.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الشيك بنجاح')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// Automated installment generator for tenant contracts (e.g. 1, 2, 4, 6 cheques)
  void _showGenerateInstallmentsDialog() {
    if (_tenant.allProperties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد عقارات أو عقود مسجلة لهذا المستأجر لتوليد الشيكات')),
      );
      return;
    }

    final property = _tenant.allProperties.first;
    final totalRent = property.rentAmount ?? 0.0;
    int installmentsCount = 4;
    DateTime startDate = property.startDate ?? DateTime.now();
    final bankCtrl = TextEditingController(text: 'Emirates NBD');
    final baseChequeNumCtrl = TextEditingController(text: '100001');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final perInstallment = totalRent > 0 ? (totalRent / installmentsCount) : 0.0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.auto_awesome, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text('توليد دفعات الشيكات تلقائياً', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🏢 ${property.buildingName} - شقة ${property.unitNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('إجمالي القيمة الإيجارية: ${_currencyFormat.format(totalRent)} د.إ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          if (property.startDate != null)
                            Text('تاريخ البداية: ${_dateFormat.format(property.startDate!)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: installmentsCount,
                      decoration: const InputDecoration(
                        labelText: 'عدد الدفعات / الشيكات (Installments)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pie_chart),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('دفعة واحدة (1 Cheque / Year)')),
                        DropdownMenuItem(value: 2, child: Text('دفعتان (2 Cheques / Every 6 Mos)')),
                        DropdownMenuItem(value: 3, child: Text('3 دفعات (3 Cheques / Every 4 Mos)')),
                        DropdownMenuItem(value: 4, child: Text('4 دفعات (4 Cheques / Quarterly)')),
                        DropdownMenuItem(value: 6, child: Text('6 دفعات (6 Cheques / Bi-Monthly)')),
                        DropdownMenuItem(value: 12, child: Text('12 دفعة (12 Cheques / Monthly)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => installmentsCount = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseChequeNumCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم أول شيك كبداية تسلسل (Starting Cheque #)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bankCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم البنك (Bank Name)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('مبلغ كل شيك:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${_currencyFormat.format(perInstallment)} د.إ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                          const Divider(),
                          const Text('مواعيد الدفع المتوقعة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          ...List.generate(installmentsCount, (i) {
                            final monthsToAdd = ((12 / installmentsCount) * i).round();
                            final due = DateTime(startDate.year, startDate.month + monthsToAdd, startDate.day);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Text('شيك ${i + 1}: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text(_dateFormat.format(due), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  const Spacer(),
                                  Text('${_currencyFormat.format(perInstallment)} د.إ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    try {
                      final startNum = int.tryParse(baseChequeNumCtrl.text.trim()) ?? 100001;
                      final List<ChequeModel> generated = [];

                      for (int i = 0; i < installmentsCount; i++) {
                        final monthsToAdd = ((12 / installmentsCount) * i).round();
                        final due = DateTime(startDate.year, startDate.month + monthsToAdd, startDate.day);
                        final chqNum = (startNum + i).toString().padLeft(6, '0');

                        generated.add(ChequeModel(
                          id: '',
                          tenantUid: _tenant.uid,
                          tenantName: _tenant.name,
                          chequeNumber: chqNum,
                          bankName: bankCtrl.text.trim().isNotEmpty ? bankCtrl.text.trim() : 'Bank',
                          amount: perInstallment,
                          dueDate: due,
                          status: 'pending',
                          contractCode: property.contractCode,
                          buildingName: property.buildingName,
                          unitNumber: property.unitNumber,
                          notes: 'الدفعة ${i + 1} من أصل $installmentsCount',
                        ));
                      }

                      await _firestoreService.batchCreateCheques(generated);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم توليد $installmentsCount شيكات بنجاح في جدول المواعيد ✅')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء التوليد: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('تأكيد وتوليد الشيكات'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 📄 DOCUMENT & CONTRACT ACTIONS
  // ==========================================

  Future<void> _openUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
      }
    }
  }

  Future<void> _uploadContractFile() async {
    final platformFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (platformFile != null) {
      setState(() => _isLoading = true);
      final ext = platformFile.extension ?? 'pdf';
      final fileName = 'contract_${const Uuid().v4()}.$ext';
      final path = 'contracts/${_tenant.uid}/$fileName';

      try {
        final ref = FirebaseStorage.instance.ref().child(path);
        UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await platformFile.readAsBytes();
          uploadTask = ref.putData(bytes);
        } else if (platformFile.path != null) {
          uploadTask = ref.putFile(File(platformFile.path!));
        } else {
          final bytes = await platformFile.readAsBytes();
          uploadTask = ref.putData(bytes);
        }
        final snap = await uploadTask;
        final url = await snap.ref.getDownloadURL();

        await _firestoreService.updateUser(_tenant.uid, {'contractUrl': url});
        await _refreshTenant();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع ملف العقد بنجاح')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الرفع: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendAlertNotification() async {
    final titleCtrl = TextEditingController(text: 'تذكير بموعد استحقاق دفعة الشيك 🔔');
    final msgCtrl = TextEditingController(
      text: 'عزيزي ${_tenant.name}، نود تذكيركم بموعد استحقاق دفعة الإيجار القادمة. يرجى التأكد من توفر الرصيد الكافي.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إرسال إشعار / تنبيه للمستأجر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'عنوان الإشعار', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: msgCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'نص الرسالة', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await FirebaseFirestore.instance.collection('notifications').add({
                  'userId': _tenant.uid,
                  'title': titleCtrl.text.trim(),
                  'message': msgCtrl.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'isRead': false,
                });
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الإشعار بنجاح')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('إرسال الآن'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🎨 UI BUILDERS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tenant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              _tenant.allProperties.isNotEmpty
                  ? '${_tenant.allProperties.length} عقارات مؤجرة'
                  : 'مستأجر',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.blue),
            tooltip: 'Call Phone',
            onPressed: () => ContactHelper.launchCall(_tenant.phone),
          ),
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.green),
            tooltip: 'WhatsApp',
            onPressed: () => ContactHelper.launchWhatsApp(_tenant.phone),
          ),
          IconButton(
            icon: const Icon(Icons.message, color: AppColors.primary),
            tooltip: 'Direct Chat',
            onPressed: () async {
              final currentAdmin = FirebaseAuth.instance.currentUser;
              if (currentAdmin == null) return;
              final adminModel = await _firestoreService.getUser(currentAdmin.uid);
              if (adminModel == null || !mounted) return;

              ChatSheet.show(
                context: context,
                chatId: _tenant.uid,
                chatTitle: _tenant.name,
                currentUserId: adminModel.uid,
                currentUserName: adminModel.name,
                isDirectChat: true,
                receiverIds: [_tenant.uid],
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.payment), text: 'الشيكات والدفع'),
            Tab(icon: Icon(Icons.description), text: 'العقود والعقارات'),
            Tab(icon: Icon(Icons.folder_shared), text: 'المستندات والتنبيهات'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildChequesTab(),
              _buildContractsTab(),
              _buildManagementTab(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: 💳 CHEQUES TAB
  // ==========================================

  Widget _buildChequesTab() {
    return StreamBuilder<List<ChequeModel>>(
      stream: _firestoreService.getChequesByTenantStream(_tenant.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCheques = snapshot.data ?? [];

        // Calculate statistics
        final totalCount = allCheques.length;
        final totalAmount = allCheques.fold<double>(0, (acc, c) => acc + c.amount);
        final paidAmount = allCheques.where((c) => c.isPaid).fold<double>(0, (acc, c) => acc + c.amount);
        final pendingAmount = allCheques.where((c) => !c.isPaid && !c.isCancelled).fold<double>(0, (acc, c) => acc + c.amount);
        final overdueCount = allCheques.where((c) => c.isOverdue).length;

        // Find nearest upcoming or overdue check
        ChequeModel? nextDueCheque;
        final unpaidCheques = allCheques.where((c) => !c.isPaid && !c.isCancelled).toList();
        if (unpaidCheques.isNotEmpty) {
          unpaidCheques.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          nextDueCheque = unpaidCheques.first;
        }

        // Apply filter
        List<ChequeModel> filteredCheques = allCheques.where((c) {
          if (_chequeFilter == 'pending') return c.isPending && !c.isOverdue;
          if (_chequeFilter == 'due_soon') return c.isDueSoon;
          if (_chequeFilter == 'paid') return c.isPaid;
          if (_chequeFilter == 'overdue') return c.isOverdue;
          if (_chequeFilter == 'bounced') return c.isBounced;
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: _refreshTenant,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Banner
              _buildChequeSummaryStats(
                totalCount: totalCount,
                totalAmount: totalAmount,
                paidAmount: paidAmount,
                pendingAmount: pendingAmount,
                overdueCount: overdueCount,
              ),
              const SizedBox(height: 16),

              // Highlight next due check if any
              if (nextDueCheque != null) ...[
                _buildNextDueChequeAlert(nextDueCheque),
                const SizedBox(height: 16),
              ],

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showAddChequeDialog(),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('إضافة شيك جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _showGenerateInstallmentsDialog,
                      icon: const Icon(Icons.auto_awesome, size: 20, color: AppColors.accent),
                      label: const Text('توليد الدفعات تلقائياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('الكل ($totalCount)', 'all'),
                    _buildFilterChip('قيد الانتظار', 'pending'),
                    _buildFilterChip('مستحق قريباً', 'due_soon'),
                    _buildFilterChip('مدفوع', 'paid'),
                    _buildFilterChip('متأخر ($overdueCount)', 'overdue', isAlert: overdueCount > 0),
                    _buildFilterChip('مرتجع', 'bounced'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // List of Cheques
              if (filteredCheques.isEmpty)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.payment_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('لا توجد شيكات تطابق هذا التصنيف', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showAddChequeDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('أضف أول شيك الآن'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredCheques.map((c) => _buildChequeCard(c)),
              
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isAlert = false}) {
    final isSelected = _chequeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _chequeFilter = value;
          });
        },
        selectedColor: isAlert ? Colors.red.shade700 : AppColors.primary,
        backgroundColor: isAlert ? Colors.red.shade50 : Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isAlert ? Colors.red.shade900 : AppColors.textPrimary),
          fontWeight: isSelected || isAlert ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
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

  Widget _buildChequeSummaryStats({
    required int totalCount,
    required double totalAmount,
    required double paidAmount,
    required double pendingAmount,
    required int overdueCount,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('إجمالي الشيكات', '$totalCount شيك', AppColors.primary, Icons.receipt_long),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: _buildStatItem('إجمالي القيمة', '${_currencyFormat.format(totalAmount)} د.إ', Colors.blue.shade800, Icons.monetization_on),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('تم الصرف / مدفوع', '${_currencyFormat.format(paidAmount)} د.إ', Colors.green.shade700, Icons.check_circle),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: _buildStatItem(
                    'المتبقي للدفع',
                    '${_currencyFormat.format(pendingAmount)} د.إ',
                    overdueCount > 0 ? Colors.red.shade700 : Colors.orange.shade800,
                    Icons.schedule,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNextDueChequeAlert(ChequeModel cheque) {
    final days = cheque.daysUntilDue;
    String timingText;
    Color alertBg;
    Color alertBorder;
    Color alertText;

    if (cheque.isOverdue) {
      timingText = '⚠️ متأخر عن موعد الدفع بـ ${-days} يوماً!';
      alertBg = Colors.red.shade50;
      alertBorder = Colors.red.shade400;
      alertText = Colors.red.shade900;
    } else if (days == 0) {
      timingText = '🔔 موعد الدفع مستحق اليوم!';
      alertBg = Colors.amber.shade50;
      alertBorder = Colors.amber.shade500;
      alertText = Colors.amber.shade900;
    } else {
      timingText = '⏳ أقرب موعد دفع قادم: متبقي $days يوماً (${_dateFormat.format(cheque.dueDate)})';
      alertBg = Colors.blue.shade50;
      alertBorder = Colors.blue.shade300;
      alertText = Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.notification_important, color: alertText, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timingText,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: alertText),
                ),
                const SizedBox(height: 2),
                Text(
                  'شيك #${cheque.chequeNumber} (${cheque.bankName}) - بمبلغ ${_currencyFormat.format(cheque.amount)} د.إ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _toggleChequePaid(cheque),
            child: const Text('صرف الشيك', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildChequeCard(ChequeModel cheque) {
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
      badgeText = 'قيد الانتظار (${cheque.daysUntilDue} يوم)';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cheque.isOverdue ? Colors.red.shade300 : AppColors.border,
          width: cheque.isOverdue ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Bank & Cheque No + Status Badge
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cheque.isPaid ? Colors.green.shade50 : (cheque.isOverdue ? Colors.red.shade50 : AppColors.primaryLight.withValues(alpha: 0.15)),
                  child: Icon(
                    Icons.account_balance,
                    color: cheque.isPaid ? Colors.green.shade700 : (cheque.isOverdue ? Colors.red.shade700 : AppColors.primary),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cheque.bankName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'شيك رقم: ${cheque.chequeNumber}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Middle Row: Amount & Due Date (وقت الدفع)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المبلغ (Amount)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      '${_currencyFormat.format(cheque.amount)} د.إ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cheque.isPaid ? Colors.green.shade700 : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('وقت وتاريخ الاستحقاق (Due Date)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 16, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          _dateFormat.format(cheque.dueDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            if (cheque.buildingName != null || cheque.unitNumber != null || (cheque.notes != null && cheque.notes!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    if (cheque.unitNumber != null) ...[
                      const Icon(Icons.apartment, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${cheque.buildingName ?? ""} - شقة ${cheque.unitNumber}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (cheque.notes != null && cheque.notes!.isNotEmpty)
                      Expanded(
                        child: Text(
                          '📝 ${cheque.notes!}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bottom Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cheque.isPaid ? Colors.orange.shade800 : Colors.green.shade700,
                    side: BorderSide(color: cheque.isPaid ? Colors.orange.shade300 : Colors.green.shade400),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _toggleChequePaid(cheque),
                  icon: Icon(cheque.isPaid ? Icons.undo : Icons.check_circle, size: 16),
                  label: Text(cheque.isPaid ? 'إعادة كغير مدفوع' : 'صرف الشيك (مدفوع)'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                  tooltip: 'تعديل',
                  onPressed: () => _showEditChequeDialog(cheque),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  tooltip: 'حذف',
                  onPressed: () => _deleteCheque(cheque),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: 📄 CONTRACTS TAB
  // ==========================================

  Widget _buildContractsTab() {
    return FutureBuilder<List<ContractModel>>(
      future: _firestoreService.getContractsByTenant(_tenant.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final contracts = snapshot.data ?? [];
        final properties = _tenant.allProperties;

        return RefreshIndicator(
          onRefresh: _refreshTenant,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Banner
              Card(
                elevation: 0,
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.apartment, color: AppColors.accent),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'العقارات المؤجرة: ${properties.length} وحدة',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'العقود المسجلة في النظام: ${contracts.isNotEmpty ? contracts.length : properties.length} عقد',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (contracts.isNotEmpty) ...[
                ...contracts.map((c) => _buildContractCard(c)),
              ] else if (properties.isNotEmpty) ...[
                ...properties.map((p) => _buildPropertyCard(p)),
              ] else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('لا توجد عقود مسجلة لهذا المستأجر', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContractCard(ContractModel contract) {
    final now = DateTime.now();
    final isExpired = contract.endDate != null && contract.endDate!.isBefore(now);
    final daysRemaining = contract.endDate != null ? contract.endDate!.difference(now).inDays : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_work, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contract.buildingName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'شقة ${contract.unitNumber} ${contract.unitType.isNotEmpty ? "(${contract.unitType})" : ""}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isExpired ? Colors.red.shade300 : Colors.green.shade300),
                  ),
                  child: Text(
                    isExpired ? 'منتهي' : 'ساري النشاط',
                    style: TextStyle(
                      color: isExpired ? Colors.red.shade900 : Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Contract Info Grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('رمز / رقم العقد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        contract.contractCode.isNotEmpty ? contract.contractCode : (contract.contractNumber?.toString() ?? 'N/A'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('قيمة الإيجار السنوي', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        '${_currencyFormat.format(contract.rentAmount > 0 ? contract.rentAmount : contract.yearValue)} د.إ',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dates
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تاريخ بداية العقد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        contract.startDate != null ? _dateFormat.format(contract.startDate!) : 'غير محدد',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تاريخ نهاية العقد (الانتهاء)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        contract.endDate != null ? _dateFormat.format(contract.endDate!) : 'غير محدد',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isExpired ? Colors.red : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (daysRemaining != null && !isExpired) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_bottom, size: 14, color: Colors.amber.shade900),
                    const SizedBox(width: 4),
                    Text(
                      'متبقي على نهاية العقد: $daysRemaining يوماً',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showAddChequeDialog(preselectedContract: contract),
                  icon: const Icon(Icons.add_card, size: 18),
                  label: const Text('إضافة شيك لهذا العقد'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(TenantProperty prop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.apartment, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${prop.buildingName} - شقة ${prop.unitNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (prop.rentAmount != null && prop.rentAmount! > 0)
                  Text('${_currencyFormat.format(prop.rentAmount!)} د.إ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('البداية: ${prop.startDate != null ? _dateFormat.format(prop.startDate!) : "N/A"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                Expanded(
                  child: Text('الانتهاء: ${prop.endDate != null ? _dateFormat.format(prop.endDate!) : "N/A"}', style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: ⚙️ MANAGEMENT TAB
  // ==========================================

  Widget _buildManagementTab() {
    return RefreshIndicator(
      onRefresh: _refreshTenant,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic Info Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بيانات المستأجر والاتصال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.person, 'الاسم الكامل', _tenant.name),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.phone, 'رقم الهاتف', _tenant.phone),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.email, 'البريد الإلكتروني', _tenant.email ?? 'غير محدد'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.fingerprint, 'معرف المستخدم (UID)', _tenant.uid),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contract File Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
              title: const Text('نسخة العقد الممسوحة ضوئياً (PDF)'),
              subtitle: Text(_tenant.contractUrl != null ? 'تم رفع العقد (اضغط للعرض)' : 'لم يتم رفع ملف العقد حتى الآن'),
              onTap: _tenant.contractUrl != null ? () => _openUrl(_tenant.contractUrl) : null,
              trailing: ElevatedButton(
                onPressed: _uploadContractFile,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('رفع عقد'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Send In-App Alert
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
            child: ListTile(
              leading: const Icon(Icons.notifications_active, color: AppColors.accent, size: 32),
              title: const Text('إرسال تنبيه / تذكير بالدفع للمستأجر'),
              subtitle: const Text('إشعار فوري يظهر في تطبيق المستأجر مباشرة'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _sendAlertNotification,
            ),
          ),
          const SizedBox(height: 16),

          // View Maintenance History
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
            child: ListTile(
              leading: const Icon(Icons.build_circle, color: Colors.blue, size: 32),
              title: const Text('سجل طلبات الصيانة السابقة'),
              subtitle: const Text('عرض جميع طلبات الصيانة المقدمة من هذا المستأجر'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TenantRequestsView(
                      tenantId: _tenant.uid,
                      tenantName: _tenant.name,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Delete Account
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.red.shade200)),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red, size: 32),
              title: const Text('حذف حساب المستأجر', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('إلغاء وصول المستأجر وحذف بياناته من النظام'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تأكيد حذف المستأجر'),
                    content: Text('هل أنت متأكد من حذف ${_tenant.name}؟ هذا الإجراء سيوقف قدرته على استخدام التطبيق.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await _firestoreService.deleteUser(_tenant.uid);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف حساب المستأجر بنجاح')));
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

