
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Lưu ảnh tạm trong bộ nhớ của phiên chạy ứng dụng.
/// Không tải ảnh lên Firebase Storage và không lưu ảnh vào Firestore.
class PaymentProofDemoStore {
  PaymentProofDemoStore._();

  static final Map<String, DemoPaymentProof> proofs = {};
}

class DemoPaymentProof {
  final String invoiceId;
  final Uint8List bytes;
  final String note;
  final DateTime submittedAt;
  String status;

  DemoPaymentProof({
    required this.invoiceId,
    required this.bytes,
    required this.note,
    required this.submittedAt,
    this.status = 'pending',
  });
}

class PaymentProofDemoScreen extends StatefulWidget {
  const PaymentProofDemoScreen({super.key});

  @override
  State<PaymentProofDemoScreen> createState() =>
      _PaymentProofDemoScreenState();
}

class _PaymentProofDemoScreenState extends State<PaymentProofDemoScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _noteController = TextEditingController();

  bool _loading = true;
  bool _busy = false;

  String _role = '';
  String _roomId = '';
  String? _selectedInvoiceId;

  Uint8List? _selectedImage;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Bạn chưa đăng nhập.');
      }

      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        throw Exception('Không tìm thấy thông tin tài khoản.');
      }

      final data = doc.data() ?? {};

      if (!mounted) return;

      setState(() {
        _role = (data['role'] ?? '').toString().toLowerCase();
        _roomId = (data['roomId'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Query<Map<String, dynamic>> _invoiceQuery() {
    Query<Map<String, dynamic>> query = _db.collection('invoices');

    if (_role == 'tenant') {
      query = query.where('roomId', isEqualTo: _roomId);
    }

    return query;
  }

  String _money(dynamic value) {
    final amount = value is num ? value : 0;

    return '${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
        )} đ';
  }

  Future<void> _chooseImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 65,
        maxWidth: 1200,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImage = bytes;
      });
    } catch (e) {
      _message('Không thể chọn ảnh: $e', error: true);
    }
  }

  Future<void> _submitProof(String invoiceId) async {
    if (_selectedImage == null) {
      _message('Bạn hãy chọn ảnh biên lai trước.', error: true);
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      PaymentProofDemoStore.proofs[invoiceId] = DemoPaymentProof(
        invoiceId: invoiceId,
        bytes: _selectedImage!,
        note: _noteController.text.trim(),
        submittedAt: DateTime.now(),
      );

      if (!mounted) return;

      setState(() {
        _selectedImage = null;
        _noteController.clear();
        _selectedInvoiceId = null;
        _busy = false;
      });

      _message(
        'Đã gửi chứng từ demo. Chủ trọ có thể xem trên cùng phiên ứng dụng.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }

      _message('Không thể gửi chứng từ: $e', error: true);
    }
  }

  Future<void> _reviewProof(
    QueryDocumentSnapshot<Map<String, dynamic>> invoiceDoc, {
    required bool approve,
  }) async {
    final proof = PaymentProofDemoStore.proofs[invoiceDoc.id];

    if (proof == null) return;

    setState(() {
      _busy = true;
    });

    try {
      final data = invoiceDoc.data();

      if (approve) {
        final total = data['totalAmount'] is num
            ? (data['totalAmount'] as num).toDouble()
            : 0.0;

        await invoiceDoc.reference.update({
          'paymentStatus': 'paid',
          'paidAmount': total,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        proof.status = 'approved';
      } else {
        await invoiceDoc.reference.update({
          'paymentStatus': 'unpaid',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        proof.status = 'rejected';
      }

      if (!mounted) return;

      setState(() {
        _busy = false;
      });

      _message(
        approve ? 'Đã duyệt chứng từ.' : 'Đã từ chối chứng từ.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }

      _message('Không thể cập nhật hóa đơn: $e', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _tenantInvoiceCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final proof = PaymentProofDemoStore.proofs[doc.id];
    final expanded = _selectedInvoiceId == doc.id;
    final status = (data['paymentStatus'] ?? 'unpaid').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phòng ${data['roomName'] ?? data['roomId'] ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hóa đơn: ${data['month'] ?? ''}/${data['year'] ?? ''}',
            ),
            Text('Tổng tiền: ${_money(data['totalAmount'])}'),
            Text('Trạng thái: $status'),
            if (proof != null) ...[
              const SizedBox(height: 8),
              Text(
                'Chứng từ đã gửi: ${proof.status == 'pending' ? 'Chờ duyệt' : proof.status == 'approved' ? 'Đã duyệt' : 'Bị từ chối'}',
                style: TextStyle(
                  color: proof.status == 'approved'
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (expanded) ...[
              if (_selectedImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _selectedImage!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: _busy ? null : _chooseImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Chọn ảnh biên lai'),
              ),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : () => _submitProof(doc.id),
                icon: const Icon(Icons.send),
                label: const Text('Gửi chứng từ'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedInvoiceId = doc.id;
                    _selectedImage = null;
                    _noteController.clear();
                  });
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Gửi ảnh biên lai'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _managerInvoiceCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final proof = PaymentProofDemoStore.proofs[doc.id];

    if (proof == null) return const SizedBox.shrink();

    final data = doc.data();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phòng ${data['roomName'] ?? data['roomId'] ?? ''} · Hóa đơn ${data['month'] ?? ''}/${data['year'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Người thuê: ${data['tenantName'] ?? 'Chưa có thông tin'}',
            ),
            Text('Tổng tiền: ${_money(data['totalAmount'])}'),
            Text(
              'Ghi chú: ${proof.note.isEmpty ? 'Không có' : proof.note}',
            ),
            Text(
              'Thời gian gửi: ${proof.submittedAt.day}/${proof.submittedAt.month}/${proof.submittedAt.year} ${proof.submittedAt.hour.toString().padLeft(2, '0')}:${proof.submittedAt.minute.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                proof.bytes,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trạng thái chứng từ: ${proof.status == 'pending' ? 'Chờ duyệt' : proof.status == 'approved' ? 'Đã duyệt' : 'Đã từ chối'}',
            ),
            if (proof.status == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _reviewProof(doc, approve: false),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'Từ chối',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _reviewProof(doc, approve: true),
                    icon: const Icon(Icons.check),
                    label: const Text('Duyệt thanh toán'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chứng từ thanh toán')),
        body: Center(child: Text(_error)),
      );
    }

    if (_role != 'tenant' && _role != 'manager') {
      return const Scaffold(
        body: Center(
          child: Text('Tài khoản không có quyền truy cập.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _role == 'tenant'
              ? 'Gửi chứng từ thanh toán'
              : 'Duyệt chứng từ thanh toán',
        ),
      ),
      body: _role == 'tenant' && _roomId.isEmpty
          ? const Center(
              child: Text('Tài khoản chưa được gán phòng.'),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _invoiceQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi tải hóa đơn: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (_role == 'manager') {
                  final withProofs = docs
                      .where(
                        (doc) => PaymentProofDemoStore.proofs
                            .containsKey(doc.id),
                      )
                      .toList();

                  if (withProofs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Chưa có chứng từ nào trong phiên demo này.',
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: withProofs.map(_managerInvoiceCard).toList(),
                  );
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Phòng của bạn chưa có hóa đơn.'),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: docs.map(_tenantInvoiceCard).toList(),
                );
              },
            ),
    );
  }
}
