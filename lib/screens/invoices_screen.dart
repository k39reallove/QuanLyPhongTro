import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


import 'rental_data.dart';
import 'utility_data.dart';

enum InvoiceStatus {
  unpaid,
  partial,
  paid,
  overdue,
  waiting,
}

class Invoice {
  final String id;
  final String roomId;
  final String roomName;
  final String tenantId;
  final String tenantName;
  final String tenantPhone;
  final int month;
  final int year;
  final double roomPrice;
  final double electricityCost;
  final double waterCost;
  final double serviceCost;
  final double otherCost;
  final double paidAmount;
  final String paymentStatus;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final String? paymentProofUrl;
  final String? paymentNote;

  Invoice({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.tenantId,
    required this.tenantName,
    required this.tenantPhone,
    required this.month,
    required this.year,
    required this.roomPrice,
    required this.electricityCost,
    required this.waterCost,
    required this.serviceCost,
    required this.otherCost,
    required this.paidAmount,
    required this.paymentStatus,
    this.dueDate,
    this.createdAt,
    this.paymentProofUrl,
    this.paymentNote,
  });

  double get totalAmount =>
      roomPrice +
      electricityCost +
      waterCost +
      serviceCost +
      otherCost;

  double get remainingAmount =>
      (totalAmount - paidAmount).clamp(0, totalAmount).toDouble();

  InvoiceStatus get status {
    if (paymentStatus == 'pending') {
      return InvoiceStatus.waiting;
    }

    if (remainingAmount <= 0) {
      return InvoiceStatus.paid;
    }

    if (paidAmount > 0) {
      return InvoiceStatus.partial;
    }

    if (dueDate != null && DateTime.now().isAfter(dueDate!)) {
      return InvoiceStatus.overdue;
    }

    return InvoiceStatus.unpaid;
  }

  factory Invoice.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    double readNumber(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return Invoice(
      id: doc.id,
      roomId: (data['roomId'] ?? '').toString(),
      roomName: (data['roomName'] ?? '').toString(),
      tenantId: (data['tenantId'] ?? '').toString(),
      tenantName: (data['tenantName'] ?? '').toString(),
      tenantPhone: (data['tenantPhone'] ?? '').toString(),
      month: (data['month'] as num?)?.toInt() ?? 0,
      year: (data['year'] as num?)?.toInt() ?? 0,
      roomPrice: readNumber(data['roomPrice']),
      electricityCost: readNumber(data['electricityCost']),
      waterCost: readNumber(data['waterCost']),
      serviceCost: readNumber(data['serviceCost']),
      otherCost: readNumber(data['otherCost']),
      paidAmount: readNumber(data['paidAmount']),
      paymentStatus: (data['paymentStatus'] ?? 'unpaid').toString(),
      dueDate: readDate(data['dueDate']),
      createdAt: readDate(data['createdAt']),
      paymentProofUrl: data['paymentProofUrl']?.toString(),
      paymentNote: data['paymentNote']?.toString(),
    );
  }
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _searchText = '';
  String _statusFilter = 'all';

  CollectionReference<Map<String, dynamic>> get _invoices =>
      _db.collection('invoices');

  String _money(num value) {
    return '${value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
        )} đ';
  }

  Color _statusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.partial:
        return Colors.blue;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.waiting:
        return Colors.orange;
      case InvoiceStatus.unpaid:
        return Colors.grey;
    }
  }

  String _statusText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return 'Đã thanh toán';
      case InvoiceStatus.partial:
        return 'Thanh toán một phần';
      case InvoiceStatus.overdue:
        return 'Quá hạn';
      case InvoiceStatus.waiting:
        return 'Chờ xác nhận';
      case InvoiceStatus.unpaid:
        return 'Chưa thanh toán';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa hóa đơn'),
        content: Text(
          'Bạn có chắc muốn xóa hóa đơn phòng ${invoice.roomName} '
          'tháng ${invoice.month}/${invoice.year} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _invoices.doc(invoice.id).delete();
      _showMessage('Đã xóa hóa đơn.');
    } catch (e) {
      _showMessage('Không thể xóa hóa đơn: $e');
    }
  }

  Future<void> _approvePayment(Invoice invoice) async {
    try {
      await _invoices.doc(invoice.id).update({
        'paymentStatus': invoice.remainingAmount <= 0
            ? 'paid'
            : invoice.paidAmount > 0
                ? 'partial'
                : 'unpaid',
        'updatedAt': FieldValue.serverTimestamp(),
        'paymentApprovedAt': FieldValue.serverTimestamp(),
        'paymentApprovedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      _showMessage('Đã xác nhận thanh toán.');
    } catch (e) {
      _showMessage('Không thể xác nhận thanh toán: $e');
    }
  }

  Future<void> _rejectPayment(Invoice invoice) async {
    final noteController = TextEditingController();

    final note = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Từ chối thanh toán'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Lý do từ chối',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              noteController.text.trim(),
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    noteController.dispose();

    if (note == null) return;

    try {
      await _invoices.doc(invoice.id).update({
        'paymentStatus': 'unpaid',
        'paymentNote': note,
        'paymentProofUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Đã từ chối thanh toán.');
    } catch (e) {
      _showMessage('Không thể từ chối thanh toán: $e');
    }
  }

  Future<void> _showInvoiceDetail(Invoice invoice) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hóa đơn phòng ${invoice.roomName}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Người thuê', invoice.tenantName),
                _detailRow('Số điện thoại', invoice.tenantPhone),
                _detailRow(
                  'Kỳ hóa đơn',
                  '${invoice.month}/${invoice.year}',
                ),
                const Divider(height: 24),
                _detailRow('Tiền phòng', _money(invoice.roomPrice)),
                _detailRow(
                  'Tiền điện',
                  _money(invoice.electricityCost),
                ),
                _detailRow(
                  'Tiền nước',
                  _money(invoice.waterCost),
                ),
                _detailRow(
                  'Phí dịch vụ',
                  _money(invoice.serviceCost),
                ),
                _detailRow(
                  'Chi phí khác',
                  _money(invoice.otherCost),
                ),
                const Divider(height: 24),
                _detailRow(
                  'Tổng cộng',
                  _money(invoice.totalAmount),
                  isBold: true,
                ),
                _detailRow(
                  'Đã thanh toán',
                  _money(invoice.paidAmount),
                ),
                _detailRow(
                  'Còn phải thu',
                  _money(invoice.remainingAmount),
                  isBold: true,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(_statusText(invoice.status)),
                    backgroundColor:
                        _statusColor(invoice.status).withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: _statusColor(invoice.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (invoice.paymentProofUrl != null &&
                    invoice.paymentProofUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ảnh minh chứng thanh toán',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Image.network(
                    invoice.paymentProofUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text('Không thể tải ảnh minh chứng.');
                    },
                  ),
                ],
                if (invoice.paymentNote != null &&
                    invoice.paymentNote!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ghi chú: ${invoice.paymentNote}'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (invoice.paymentStatus == 'pending') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _rejectPayment(invoice);
              },
              child: const Text('Từ chối'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _approvePayment(invoice);
              },
              child: const Text('Xác nhận thanh toán'),
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String title,
    String value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<Invoice> invoices) {
    final total = invoices.fold<double>(
      0,
      (totalAmount, invoice) => totalAmount + invoice.totalAmount,
    );

    final paid = invoices.fold<double>(
      0,
      (totalPaid, invoice) => totalPaid + invoice.paidAmount,
    );

    final waiting = invoices
        .where((invoice) => invoice.status == InvoiceStatus.waiting)
        .length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _summaryCard(
          'Tổng hóa đơn',
          _money(total),
          Icons.receipt_long_outlined,
          Colors.blue,
        ),
        _summaryCard(
          'Đã thu',
          _money(paid),
          Icons.account_balance_wallet_outlined,
          Colors.green,
        ),
        _summaryCard(
          'Còn phải thu',
          _money(total - paid),
          Icons.money_off_outlined,
          Colors.orange,
        ),
        _summaryCard(
          'Chờ xác nhận',
          waiting.toString(),
          Icons.pending_actions,
          Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final statusColor = _statusColor(invoice.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8EAF0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showInvoiceDetail(invoice),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Phòng ${invoice.roomName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText(invoice.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${invoice.tenantName} • '
                '${invoice.month}/${invoice.year}',
                style: const TextStyle(color: Colors.black54),
              ),
              const Divider(height: 22),
              _detailRow('Tổng hóa đơn', _money(invoice.totalAmount)),
              _detailRow('Đã thanh toán', _money(invoice.paidAmount)),
              _detailRow(
                'Còn phải thu',
                _money(invoice.remainingAmount),
                isBold: true,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showInvoiceDetail(invoice),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Chi tiết'),
                  ),
                  if (invoice.paymentStatus == 'pending')
                    FilledButton.icon(
                      onPressed: () => _approvePayment(invoice),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Xác nhận'),
                    ),
                  IconButton(
                    tooltip: 'Xóa hóa đơn',
                    onPressed: () => _deleteInvoice(invoice),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Invoice> _filterInvoices(List<Invoice> invoices) {
    final query = _searchText.toLowerCase();

    return invoices.where((invoice) {
      final matchesSearch =
          invoice.roomName.toLowerCase().contains(query) ||
          invoice.tenantName.toLowerCase().contains(query) ||
          invoice.tenantPhone.toLowerCase().contains(query);

      bool matchesStatus;

      switch (_statusFilter) {
        case 'unpaid':
          matchesStatus = invoice.status == InvoiceStatus.unpaid ||
              invoice.status == InvoiceStatus.overdue;
          break;
        case 'partial':
          matchesStatus = invoice.status == InvoiceStatus.partial;
          break;
        case 'paid':
          matchesStatus = invoice.status == InvoiceStatus.paid;
          break;
        case 'waiting':
          matchesStatus = invoice.status == InvoiceStatus.waiting;
          break;
        default:
          matchesStatus = true;
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý hóa đơn'),
        actions: [
          IconButton(
            tooltip: 'Tạo hóa đơn',
            onPressed: () async {
              final result = await showDialog<Map<String, dynamic>?>(
                context: context,
                builder: (context) => const _CreateInvoiceDialog(),
              );

              if (result == null) return;

              try {
                await _invoices.add({
                  ...result,
                  'paidAmount': 0,
                  'paymentStatus': 'unpaid',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser?.uid,
                });

                _showMessage('Đã tạo hóa đơn thành công.');
              } catch (e) {
                _showMessage('Không thể tạo hóa đơn: $e');
              }
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F7FB),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _invoices
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Lỗi tải hóa đơn: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final invoices = snapshot.data?.docs
                  .map(Invoice.fromFirestore)
                  .toList() ??
              [];

          final filtered = _filterInvoices(invoices);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummary(invoices),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) {
                  setState(() => _searchText = value);
                },
                decoration: InputDecoration(
                  hintText: 'Tìm phòng, người thuê, số điện thoại...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Lọc trạng thái',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Tất cả hóa đơn'),
                  ),
                  DropdownMenuItem(
                    value: 'unpaid',
                    child: Text('Chưa thanh toán / Quá hạn'),
                  ),
                  DropdownMenuItem(
                    value: 'partial',
                    child: Text('Thanh toán một phần'),
                  ),
                  DropdownMenuItem(
                    value: 'paid',
                    child: Text('Đã thanh toán'),
                  ),
                  DropdownMenuItem(
                    value: 'waiting',
                    child: Text('Chờ xác nhận'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _statusFilter = value ?? 'all');
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Danh sách hóa đơn (${filtered.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Chưa có hóa đơn phù hợp.'),
                    ),
                  ),
                )
              else
                ...filtered.map(_buildInvoiceCard),
            ],
          );
        },
      ),
    );
  }
}

class _CreateInvoiceDialog extends StatefulWidget {
  const _CreateInvoiceDialog();

  @override
  State<_CreateInvoiceDialog> createState() =>
      _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends State<_CreateInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _roomPriceController =
      TextEditingController();
  final TextEditingController _electricityController =
      TextEditingController();
  final TextEditingController _waterController =
      TextEditingController();
  final TextEditingController _serviceController =
      TextEditingController();
  final TextEditingController _otherController =
      TextEditingController();

  List<dynamic> _rooms = [];

  String? _selectedRoomId;
  String _selectedRoomName = '';
  String _selectedTenantId = '';
  String _selectedTenantName = '';
  String _selectedTenantPhone = '';

  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  DateTime? _dueDate;

  bool _loadingRooms = true;
  bool _loadingUtility = false;

  String _utilityMessage = '';

  double _number(String value) {
    return double.tryParse(value.trim().replaceAll('.', '')) ?? 0;
  }

  double get _total {
    return _number(_roomPriceController.text) +
        _number(_electricityController.text) +
        _number(_waterController.text) +
        _number(_serviceController.text) +
        _number(_otherController.text);
  }

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime(_year, _month + 1, 5);
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = RentalData.rooms;

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _loadingRooms = false;
      });

      if (_rooms.isNotEmpty) {
        final firstRoom = _rooms.first;
        _selectRoom(firstRoom.id.toString());
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingRooms = false;
      });

      _showMessage('Không thể tải danh sách phòng: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectRoom(String roomId) async {
    setState(() {
      _selectedRoomId = roomId;
      _loadingUtility = true;
      _utilityMessage = '';
    });

    try {
      final room = RentalData.findRoom(roomId);
      final tenant = RentalData.activeTenantOfRoom(roomId);

      if (room != null) {
        _selectedRoomName = room.name.toString();
        _roomPriceController.text = room.price.toString();
      } else {
        _selectedRoomName = '';
        _roomPriceController.text = '0';
      }

      if (tenant != null) {
        _selectedTenantId = tenant.id.toString();
        _selectedTenantName = tenant.name.toString();
        _selectedTenantPhone = tenant.phone.toString();
      } else {
        _selectedTenantId = '';
        _selectedTenantName = '';
        _selectedTenantPhone = '';
      }

      await _loadUtility();

      if (!mounted) return;

      setState(() {
        _loadingUtility = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingUtility = false;
        _utilityMessage = 'Không thể tải dữ liệu điện nước.';
      });

      _showMessage('Lỗi chọn phòng: $e');
    }
  }

  Future<void> _loadUtility() async {
    if (_selectedRoomId == null) return;

    final record = UtilityData.find(
      _selectedRoomId!,
      _month,
      _year,
    );

    if (record != null) {
      _electricityController.text = record.electricTotal.toString();
      _waterController.text = record.waterTotal.toString();

      _utilityMessage = 'Đã tải dữ liệu điện nước.';
    } else {
      _electricityController.text = '0';
      _waterController.text = '0';
      _utilityMessage = 'Chưa có dữ liệu điện nước cho kỳ này.';
    }
  }

  void _changePeriod({
    int? month,
    int? year,
  }) {
    setState(() {
      _month = month ?? _month;
      _year = year ?? _year;
      _dueDate = DateTime(_year, _month + 1, 5);
    });

    _loadUtility().then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildMoneyField(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'VNĐ',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Vui lòng nhập $label';
        }

        if (value != null &&
            value.trim().isNotEmpty &&
            _number(value) < 0) {
          return 'Giá trị không hợp lệ';
        }

        return null;
      },
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn hạn thanh toán',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (selected == null) return;

    setState(() {
      _dueDate = selected;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoomId == null || _selectedRoomId!.isEmpty) {
      _showMessage('Vui lòng chọn phòng.');
      return;
    }

    if (_selectedTenantId.isEmpty) {
      _showMessage('Phòng này chưa có người thuê đang hoạt động.');
      return;
    }

    if (_dueDate == null) {
      _showMessage('Vui lòng chọn hạn thanh toán.');
      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection('invoices')
        .where('roomId', isEqualTo: _selectedRoomId)
        .where('month', isEqualTo: _month)
        .where('year', isEqualTo: _year)
        .get();

    if (existing.docs.isNotEmpty) {
      _showMessage('Phòng này đã có hóa đơn trong tháng đã chọn.');
      return;
    }

    final result = <String, dynamic>{
      'roomId': _selectedRoomId,
      'roomName': _selectedRoomName,
      'tenantId': _selectedTenantId,
      'tenantName': _selectedTenantName,
      'tenantPhone': _selectedTenantPhone,
      'month': _month,
      'year': _year,
      'roomPrice': _number(_roomPriceController.text),
      'electricityCost': _number(_electricityController.text),
      'waterCost': _number(_waterController.text),
      'serviceCost': _number(_serviceController.text),
      'otherCost': _number(_otherController.text),
      'dueDate': Timestamp.fromDate(_dueDate!),
    };

    if (!mounted) return;

    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _roomPriceController.dispose();
    _electricityController.dispose();
    _waterController.dispose();
    _serviceController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;

    return AlertDialog(
      title: const Text('Tạo hóa đơn'),
      content: SizedBox(
        width: 520,
        child: _loadingRooms
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : _rooms.isEmpty
                ? const SizedBox(
                    height: 160,
                    child: Center(
                      child: Text('Chưa có phòng trọ để tạo hóa đơn.'),
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRoomId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Chọn phòng',
                              border: OutlineInputBorder(),
                            ),
                            items: _rooms.map((room) {
                              return DropdownMenuItem<String>(
                                value: room.id.toString(),
                                child: Text(room.name.toString()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _selectRoom(value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          if (_selectedTenantName.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F6FA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Người thuê: $_selectedTenantName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Số điện thoại: $_selectedTenantPhone'),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _month,
                                  decoration: const InputDecoration(
                                    labelText: 'Tháng',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: List.generate(12, (index) {
                                    final month = index + 1;
                                    return DropdownMenuItem(
                                      value: month,
                                      child: Text('Tháng $month'),
                                    );
                                  }),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _changePeriod(month: value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _year,
                                  decoration: const InputDecoration(
                                    labelText: 'Năm',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: List.generate(8, (index) {
                                    final year = DateTime.now().year - 2 + index;
                                    return DropdownMenuItem(
                                      value: year,
                                      child: Text(year.toString()),
                                    );
                                  }),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _changePeriod(year: value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildMoneyField(
                            'Tiền phòng',
                            _roomPriceController,
                            required: true,
                          ),
                          const SizedBox(height: 12),
                          _buildMoneyField(
                            'Tiền điện',
                            _electricityController,
                          ),
                          const SizedBox(height: 12),
                          _buildMoneyField(
                            'Tiền nước',
                            _waterController,
                          ),
                          if (_loadingUtility) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(),
                          ],
                          if (_utilityMessage.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _utilityMessage,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildMoneyField(
                            'Phí dịch vụ',
                            _serviceController,
                          ),
                          const SizedBox(height: 12),
                          _buildMoneyField(
                            'Chi phí khác',
                            _otherController,
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: _pickDueDate,
                            borderRadius: BorderRadius.circular(10),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Hạn thanh toán',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_month),
                              ),
                              child: Text(
                                _dueDate == null
                                    ? 'Chưa chọn'
                                    : '${_dueDate!.day.toString().padLeft(2, '0')}/'
                                        '${_dueDate!.month.toString().padLeft(2, '0')}/'
                                        '${_dueDate!.year}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng tiền hóa đơn',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${total.toStringAsFixed(0)} đ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Color(0xFF2457A7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Tạo hóa đơn'),
        ),
      ],
    );
  }
}