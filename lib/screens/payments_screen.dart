import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _filter = 'all';

  CollectionReference<Map<String, dynamic>> get _invoices =>
      _db.collection('invoices');

  String _money(num value) {
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ';
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _total(Map<String, dynamic> data) {
    return _number(data['roomPrice']) +
        _number(data['electricityCost']) +
        _number(data['waterCost']) +
        _number(data['serviceCost']) +
        _number(data['otherCost']);
  }

  double _paid(Map<String, dynamic> data) {
    return _number(data['paidAmount']);
  }

  double _remaining(Map<String, dynamic> data) {
    return (_total(data) - _paid(data)).clamp(0, double.infinity).toDouble();
  }

  String _status(Map<String, dynamic> data) {
    final total = _total(data);
    final paid = _paid(data);
    final remaining = _remaining(data);

    if (total > 0 && paid >= total) return 'paid';
    if (remaining > 0 && paid > 0) return 'partial';

    final dueDate = data['dueDate'];
    DateTime? due;

    if (dueDate is Timestamp) {
      due = dueDate.toDate();
    }

    if (due != null && DateTime.now().isAfter(due) && remaining > 0) {
      return 'overdue';
    }

    return 'unpaid';
  }

  String _statusText(String status) {
    switch (status) {
      case 'paid':
        return 'Đã thanh toán';
      case 'partial':
        return 'Thanh toán một phần';
      case 'overdue':
        return 'Quá hạn';
      default:
        return 'Chưa thanh toán';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.blue;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _message(String value) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterInvoices(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _searchText.toLowerCase();

    return docs.where((doc) {
      final data = doc.data();

      final room = (data['roomName'] ?? '').toString().toLowerCase();
      final tenant = (data['tenantName'] ?? '').toString().toLowerCase();
      final id = doc.id.toLowerCase();

      final matchesSearch =
          room.contains(query) || tenant.contains(query) || id.contains(query);

      final status = _status(data);

      bool matchesFilter;

      switch (_filter) {
        case 'unpaid':
          matchesFilter = status == 'unpaid' || status == 'overdue';
          break;
        case 'partial':
          matchesFilter = status == 'partial';
          break;
        case 'paid':
          matchesFilter = status == 'paid';
          break;
        default:
          matchesFilter = true;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _recordPayment(
    String invoiceId,
    Map<String, dynamic> invoice,
  ) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    String method = 'Tiền mặt';

    final amount = await showDialog<double?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ghi nhận thanh toán'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _informationRow(
                        'Phòng',
                        invoice['roomName']?.toString() ?? '',
                      ),
                      _informationRow(
                        'Người thuê',
                        invoice['tenantName']?.toString() ?? '',
                      ),
                      _informationRow('Tổng hóa đơn', _money(_total(invoice))),
                      _informationRow('Đã thanh toán', _money(_paid(invoice))),
                      _informationRow(
                        'Còn phải thu',
                        _money(_remaining(invoice)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số tiền thanh toán',
                          suffixText: 'VNĐ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration: const InputDecoration(
                          labelText: 'Phương thức thanh toán',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Tiền mặt',
                            child: Text('Tiền mặt'),
                          ),
                          DropdownMenuItem(
                            value: 'Chuyển khoản',
                            child: Text('Chuyển khoản'),
                          ),
                          DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => method = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(
                      amountController.text.trim().replaceAll('.', ''),
                    );

                    if (value == null || value <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập số tiền hợp lệ.'),
                        ),
                      );
                      return;
                    }

                    if (value > _remaining(invoice)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Số tiền vượt quá công nợ còn lại.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, value);
                  },
                  child: const Text('Tiếp tục'),
                ),
              ],
            );
          },
        );
      },
    );

    if (amount == null) {
      amountController.dispose();
      noteController.dispose();
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Bạn chưa đăng nhập.');
      }

      final invoiceRef = _invoices.doc(invoiceId);
      final paymentRef = invoiceRef.collection('payments').doc();

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(invoiceRef);

        if (!snapshot.exists) {
          throw Exception('Hóa đơn không còn tồn tại.');
        }

        final data = snapshot.data() ?? {};
        final total = _total(data);
        final oldPaid = _paid(data);
        final remaining = (total - oldPaid)
            .clamp(0, double.infinity)
            .toDouble();

        if (amount > remaining) {
          throw Exception('Công nợ đã thay đổi. Vui lòng tải lại hóa đơn.');
        }

        final newPaid = oldPaid + amount;
        final newStatus = newPaid >= total ? 'paid' : 'partial';

        transaction.update(invoiceRef, {
          'paidAmount': newPaid,
          'paymentStatus': newStatus,
          'lastPaymentAmount': amount,
          'lastPaymentAt': FieldValue.serverTimestamp(),
          'lastPaymentBy': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(paymentRef, {
          'invoiceId': invoiceId,
          'roomId': data['roomId'] ?? '',
          'roomName': data['roomName'] ?? '',
          'tenantId': data['tenantId'] ?? '',
          'tenantName': data['tenantName'] ?? '',
          'month': data['month'] ?? 0,
          'year': data['year'] ?? 0,
          'amount': amount,
          'method': method,
          'note': noteController.text.trim(),
          'status': 'completed',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
        });
      });

      _message('Đã ghi nhận thanh toán thành công.');
    } catch (e) {
      _message('Không thể ghi nhận thanh toán: $e');
    } finally {
      amountController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _showPaymentHistory(
    String invoiceId,
    Map<String, dynamic> invoice,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Lịch sử thanh toán - ${invoice['roomName'] ?? ''}'),
          content: SizedBox(
            width: 500,
            height: 420,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _invoices
                  .doc(invoiceId)
                  .collection('payments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Lỗi tải lịch sử: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Chưa có lịch sử thanh toán.'),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final createdAt = data['createdAt'];

                    String date = 'Đang cập nhật';

                    if (createdAt is Timestamp) {
                      final value = createdAt.toDate();
                      date =
                          '${value.day.toString().padLeft(2, '0')}/'
                          '${value.month.toString().padLeft(2, '0')}/'
                          '${value.year} '
                          '${value.hour.toString().padLeft(2, '0')}:'
                          '${value.minute.toString().padLeft(2, '0')}';
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.check, color: Colors.green),
                      ),
                      title: Text(
                        _money(_number(data['amount'])),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$date\n'
                        '${data['method'] ?? 'Không rõ'}'
                        '${(data['note'] ?? '').toString().isEmpty ? '' : '\n${data['note']}'}',
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _informationRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.black54)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7EAF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = _status(data);
    final remaining = _remaining(data);

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE7EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['roomName']?.toString() ?? 'Phòng',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${data['tenantName'] ?? 'Người thuê'} • '
              '${data['month'] ?? ''}/${data['year'] ?? ''}',
            ),
            const Divider(height: 22),
            _informationRow('Tổng hóa đơn', _money(_total(data))),
            _informationRow('Đã thu', _money(_paid(data))),
            _informationRow('Còn phải thu', _money(remaining)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showPaymentHistory(doc.id, data),
                  icon: const Icon(Icons.history),
                  label: const Text('Lịch sử'),
                ),
                if (remaining > 0)
                  FilledButton.icon(
                    onPressed: () => _recordPayment(doc.id, data),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Ghi nhận tiền'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý thanh toán')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _invoices.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Lỗi tải dữ liệu: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          final totalRevenue = docs.fold<double>(
            0,
            (total, doc) => total + _paid(doc.data()),
          );

          final totalDebt = docs.fold<double>(
            0,
            (total, doc) => total + _remaining(doc.data()),
          );

          final filtered = _filterInvoices(docs);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _summaryCard(
                    'Tổng đã thu',
                    _money(totalRevenue),
                    Icons.account_balance_wallet_outlined,
                    Colors.green,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    'Công nợ',
                    _money(totalDebt),
                    Icons.receipt_long_outlined,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchText = value);
                },
                decoration: InputDecoration(
                  hintText: 'Tìm phòng, người thuê, mã hóa đơn...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _filter,
                decoration: const InputDecoration(
                  labelText: 'Lọc hóa đơn',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                  DropdownMenuItem(
                    value: 'unpaid',
                    child: Text('Chưa thanh toán / Quá hạn'),
                  ),
                  DropdownMenuItem(
                    value: 'partial',
                    child: Text('Thanh toán một phần'),
                  ),
                  DropdownMenuItem(value: 'paid', child: Text('Đã thanh toán')),
                ],
                onChanged: (value) {
                  setState(() => _filter = value ?? 'all');
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Danh sách hóa đơn (${filtered.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Không có hóa đơn phù hợp.')),
                  ),
                )
              else
                ...filtered.map(_invoiceCard),
            ],
          );
        },
      ),
    );
  }
}