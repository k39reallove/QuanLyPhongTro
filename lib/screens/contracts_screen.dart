import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import 'rental_data.dart';
import 'tenants_screen.dart' show Tenant;

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _keyword = '';
  String _filter = 'Tất cả';

  List<Tenant> get _tenants => RentalData.tenants.cast<Tenant>();

  @override
  void initState() {
    super.initState();
    RentalData.version.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RentalData.version.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  String _money(num value) {
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ';
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _contractStatus(Tenant tenant) {
    if (!tenant.isActive) return 'Đã kết thúc';

    if (tenant.endDate.isBefore(DateTime.now())) {
      return 'Đã hết hạn';
    }

    if (tenant.isSigned) return 'Đã ký';

    return 'Chờ ký';
  }

  Color _statusColor(Tenant tenant) {
    if (!tenant.isActive) return Colors.grey;

    if (tenant.endDate.isBefore(DateTime.now())) {
      return Colors.red;
    }

    if (tenant.isSigned) return Colors.green;

    return Colors.orange;
  }

  List<Tenant> get _filteredTenants {
    final keyword = _keyword.toLowerCase().trim();

    return _tenants.where((tenant) {
      final matchesKeyword =
          tenant.name.toLowerCase().contains(keyword) ||
          tenant.roomName.toLowerCase().contains(keyword) ||
          tenant.roomId.toLowerCase().contains(keyword) ||
          tenant.phone.toLowerCase().contains(keyword) ||
          tenant.identityNumber.toLowerCase().contains(keyword);

      final matchesFilter = switch (_filter) {
        'Đang hiệu lực' =>
          tenant.isActive && !tenant.endDate.isBefore(DateTime.now()),
        'Đã ký' => tenant.isActive && tenant.isSigned,
        'Chờ ký' => tenant.isActive && !tenant.isSigned,
        'Đã kết thúc' => !tenant.isActive,
        'Đã hết hạn' =>
          tenant.isActive && tenant.endDate.isBefore(DateTime.now()),
        _ => true,
      };

      return matchesKeyword && matchesFilter;
    }).toList();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openContract(Tenant tenant) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContractDetailDialog(tenant: tenant),
    );

    if (mounted) setState(() {});
  }

  Future<void> _terminateContract(Tenant tenant) async {
    if (!tenant.isActive) {
      _message('Hợp đồng này đã kết thúc.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chấm dứt hợp đồng'),
        content: Text(
          'Bạn có chắc muốn chấm dứt hợp đồng của '
          '${tenant.name} tại ${tenant.roomName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Chấm dứt hợp đồng'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    RentalData.terminateTenant(tenant);
    RentalData.notify();

    setState(() {});
    _message('Đã chấm dứt hợp đồng.');
  }

  Widget _summaryCard(String title, int value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE7EAF0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 9),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterButton(String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(value),
        selected: _filter == value,
        onSelected: (_) {
          setState(() => _filter = value);
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contractCard(Tenant tenant) {
    final color = _statusColor(tenant);
    final status = _contractStatus(tenant);

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFE7EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF2459A9),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tenant.roomName} • ${tenant.roomId}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            _infoRow('Tiền thuê', '${_money(tenant.rent)}/tháng'),
            _infoRow('Tiền đặt cọc', _money(tenant.deposit)),
            _infoRow('Ngày bắt đầu', _date(tenant.startDate)),
            _infoRow('Ngày kết thúc', _date(tenant.endDate)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openContract(tenant),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Chi tiết'),
                  ),
                ),
                const SizedBox(width: 8),
                if (tenant.isActive)
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _terminateContract(tenant),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Kết thúc'),
                    ),
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
    final activeCount = _tenants.where((e) => e.isActive).length;

    final signedCount = _tenants.where((e) => e.isActive && e.isSigned).length;

    final waitingCount = _tenants
        .where((e) => e.isActive && !e.isSigned)
        .length;

    final endedCount = _tenants.where((e) => !e.isActive).length;

    final contracts = _filteredTenants;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý hợp đồng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Tổng quan hợp đồng',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryCard(
                  'Đang hiệu lực',
                  activeCount,
                  Icons.description,
                  Colors.blue,
                ),
                const SizedBox(width: 9),
                _summaryCard(
                  'Đã ký',
                  signedCount,
                  Icons.verified,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _summaryCard(
                  'Chờ ký',
                  waitingCount,
                  Icons.pending_actions,
                  Colors.orange,
                ),
                const SizedBox(width: 9),
                _summaryCard(
                  'Đã kết thúc',
                  endedCount,
                  Icons.event_busy,
                  Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Danh sách hợp đồng',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _keyword = value);
              },
              decoration: InputDecoration(
                hintText: 'Tìm tên, số điện thoại, phòng...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _keyword = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: Colors.white,
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
                children: [
                  _filterButton('Tất cả'),
                  _filterButton('Đang hiệu lực'),
                  _filterButton('Đã ký'),
                  _filterButton('Chờ ký'),
                  _filterButton('Đã hết hạn'),
                  _filterButton('Đã kết thúc'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (contracts.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 55,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Chưa có hợp đồng',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Hãy thêm người thuê và gán phòng '
                      'trong chức năng Thành viên. '
                      'Hợp đồng sẽ xuất hiện tại đây.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...contracts.map(_contractCard),
          ],
        ),
      ),
    );
  }
}

// CHI TIẾT VÀ KÝ HỢP ĐỒNG

class ContractDetailDialog extends StatefulWidget {
  final Tenant tenant;

  const ContractDetailDialog({super.key, required this.tenant});

  @override
  State<ContractDetailDialog> createState() => _ContractDetailDialogState();
}

class _ContractDetailDialogState extends State<ContractDetailDialog> {
  late final SignatureController _signatureController;

  String _signer = 'landlord';
  bool _saving = false;

  Tenant get tenant => widget.tenant;

  @override
  void initState() {
    super.initState();

    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _money(num value) {
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ';
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _saveSignature() async {
    if (_saving) return;

    if (!tenant.isActive) {
      _message('Không thể ký hợp đồng đã kết thúc.');
      return;
    }

    if (_signatureController.isEmpty) {
      _message('Vui lòng ký vào khung chữ ký.');
      return;
    }

    setState(() => _saving = true);

    try {
      final Uint8List? bytes = await _signatureController.toPngBytes();

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Không thể lấy dữ liệu chữ ký.');
      }

      if (_signer == 'tenant') {
        tenant.tenantSignature = bytes;
        tenant.tenantSignedAt = DateTime.now();
      } else {
        tenant.landlordSignature = bytes;
        tenant.landlordSignedAt = DateTime.now();
      }

      RentalData.notify();

      if (!mounted) return;

      _signatureController.clear();

      setState(() => _saving = false);

      _message(
        _signer == 'tenant'
            ? 'Đã lưu chữ ký người thuê.'
            : 'Đã lưu chữ ký chủ nhà.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Không thể lưu chữ ký: $e');
      }
    }
  }

  Widget _info(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signatureStatus(
    String title,
    Uint8List? signature,
    DateTime? signedAt,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: signature == null
            ? const Color(0xFFFFF5E8)
            : const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            signature == null ? Icons.pending_actions : Icons.verified,
            color: signature == null ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  signature == null
                      ? 'Chưa ký'
                      : 'Đã ký ${signedAt == null ? '' : _date(signedAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (signature != null)
            const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSigned = tenant.isSigned;

    final alreadySigned = _signer == 'tenant'
        ? tenant.tenantSignature != null
        : tenant.landlordSignature != null;

    return AlertDialog(
      title: const Text('Chi tiết hợp đồng thuê phòng'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THÔNG TIN NGƯỜI THUÊ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2459A9),
                ),
              ),
              const SizedBox(height: 10),
              _info('Họ và tên', tenant.name),
              _info('Số điện thoại', tenant.phone),
              _info('Email', tenant.email.isEmpty ? 'Chưa có' : tenant.email),
              _info('CCCD/CMND', tenant.identityNumber),

              const Divider(height: 25),

              const Text(
                'THÔNG TIN THUÊ PHÒNG',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2459A9),
                ),
              ),
              const SizedBox(height: 10),
              _info('Phòng thuê', '${tenant.roomName} (${tenant.roomId})'),
              _info('Tiền thuê', '${_money(tenant.rent)}/tháng'),
              _info('Tiền đặt cọc', _money(tenant.deposit)),
              _info('Ngày bắt đầu', _date(tenant.startDate)),
              _info('Ngày kết thúc', _date(tenant.endDate)),
              _info(
                'Trạng thái',
                tenant.isActive ? 'Đang hiệu lực' : 'Đã kết thúc',
              ),

              const Divider(height: 25),

              const Text(
                'ĐIỀU KHOẢN HỢP ĐỒNG',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2459A9),
                ),
              ),
              const SizedBox(height: 10),

              const Text(
                '1. Người thuê có trách nhiệm thanh toán tiền thuê '
                'đúng thời hạn theo thỏa thuận giữa hai bên.\n\n'
                '2. Người thuê có trách nhiệm sử dụng phòng đúng mục '
                'đích, giữ gìn tài sản và vệ sinh khu vực thuê.\n\n'
                '3. Chi phí điện, nước và dịch vụ được thanh toán '
                'theo chỉ số sử dụng và đơn giá do hai bên thống nhất.\n\n'
                '4. Tiền đặt cọc được xử lý khi kết thúc hợp đồng '
                'theo thỏa thuận và tình trạng thực tế của phòng.\n\n'
                '5. Việc chấm dứt hợp đồng cần được thông báo và '
                'thực hiện theo thỏa thuận.\n\n'
                '6. Hai bên xác nhận đã đọc và đồng ý với các thông '
                'tin và điều khoản được ghi nhận trong hợp đồng.',
                style: TextStyle(height: 1.5, fontSize: 13),
              ),

              const Divider(height: 28),

              const Text(
                'XÁC NHẬN CHỮ KÝ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2459A9),
                ),
              ),
              const SizedBox(height: 12),

              _signatureStatus(
                'Chữ ký người thuê',
                tenant.tenantSignature,
                tenant.tenantSignedAt,
              ),
              _signatureStatus(
                'Chữ ký chủ nhà',
                tenant.landlordSignature,
                tenant.landlordSignedAt,
              ),

              if (!allSigned && tenant.isActive) ...[
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _signer,
                  decoration: const InputDecoration(
                    labelText: 'Người thực hiện ký',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'tenant',
                      child: Text('Người thuê'),
                    ),
                    DropdownMenuItem(
                      value: 'landlord',
                      child: Text('Chủ nhà / Quản lý'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _signer = value);
                  },
                ),

                const SizedBox(height: 12),

                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: alreadySigned
                      ? const Center(child: Text('Bên này đã ký hợp đồng.'))
                      : Signature(
                          controller: _signatureController,
                          backgroundColor: Colors.white,
                        ),
                ),

                Row(
                  children: [
                    TextButton.icon(
                      onPressed: alreadySigned || _saving
                          ? null
                          : () => _signatureController.clear(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Xóa chữ ký'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: alreadySigned || _saving
                          ? null
                          : _saveSignature,
                      icon: const Icon(Icons.draw),
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu chữ ký'),
                    ),
                  ],
                ),
              ],

              if (allSigned)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Hai bên đã hoàn tất chữ ký.',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              if (!tenant.isActive)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Hợp đồng đã kết thúc. Chữ ký và thông tin '
                    'được giữ lại để tra cứu.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
