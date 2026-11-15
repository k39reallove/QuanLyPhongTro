import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'rental_data.dart';
import 'rooms_screen.dart';
import '../services/tenant_account_service.dart';

class Tenant {
  final String id;
  String name;
  String phone;
  String email;
  String identityNumber;

  String roomId;
  String roomName;

  double rent;
  double deposit;

  DateTime startDate;
  DateTime endDate;

  bool isActive;

  String? firebaseUid;
  String? accountEmail;
  bool accountActive;

  Uint8List? tenantSignature;
  Uint8List? landlordSignature;

  DateTime? tenantSignedAt;
  DateTime? landlordSignedAt;

  Tenant({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.identityNumber,
    required this.roomId,
    required this.roomName,
    required this.rent,
    required this.deposit,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.firebaseUid,
    this.accountEmail,
    this.accountActive = true,
    this.tenantSignature,
    this.landlordSignature,
    this.tenantSignedAt,
    this.landlordSignedAt,
  });

  bool get isSigned =>
      tenantSignature != null && landlordSignature != null;

  bool get hasAccount =>
      firebaseUid != null && firebaseUid!.isNotEmpty;
}

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchText = '';

  List<Tenant> get _tenants =>
      RentalData.tenants.cast<Tenant>();

  @override
  void initState() {
    super.initState();
    RentalData.version.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RentalData.version.removeListener(_onDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<Tenant> get _filteredTenants {
    final keyword = _searchText.toLowerCase().trim();

    if (keyword.isEmpty) return _tenants;

    return _tenants.where((tenant) {
      return tenant.name.toLowerCase().contains(keyword) ||
          tenant.phone.toLowerCase().contains(keyword) ||
          tenant.roomName.toLowerCase().contains(keyword) ||
          tenant.roomId.toLowerCase().contains(keyword) ||
          tenant.email.toLowerCase().contains(keyword);
    }).toList();
  }

  Future<void> _openTenantForm({Tenant? tenant}) async {
    final result = await showDialog<Tenant>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TenantFormDialog(tenant: tenant),
    );

    if (result == null || !mounted) return;

    final success = RentalData.assignTenant(
      tenant: result,
      roomId: result.roomId,
    );

    if (!success) {
      _showMessage(
        'Không thể gán người thuê. Phòng có thể đã có người thuê '
        'hoặc đang bảo trì.',
      );
      return;
    }

    RentalData.notify();
    setState(() {});

    _showMessage(
      tenant == null
          ? 'Đã thêm người thuê thành công.'
          : 'Đã cập nhật hồ sơ người thuê.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleTenantAccount(Tenant tenant) async {
    if (!tenant.hasAccount) {
      _showMessage('Người thuê chưa có tài khoản đăng nhập.');
      return;
    }

    final nextStatus = !tenant.accountActive;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          nextStatus ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
        ),
        content: Text(
          nextStatus
              ? 'Cho phép ${tenant.name} đăng nhập lại?'
              : 'Ngăn ${tenant.name} đăng nhập vào ứng dụng?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await TenantAccountService.updateTenantStatus(
        uid: tenant.firebaseUid!,
        isActive: nextStatus,
      );

      tenant.accountActive = nextStatus;
      RentalData.notify();

      if (mounted) setState(() {});

      _showMessage(
        nextStatus
            ? 'Đã mở khóa tài khoản người thuê.'
            : 'Đã khóa tài khoản người thuê.',
      );
    } catch (e) {
      _showMessage('Không thể cập nhật tài khoản: $e');
    }
  }

  Future<void> _terminateTenant(Tenant tenant) async {
    if (!tenant.isActive) {
      _showMessage('Hợp đồng này đã kết thúc.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kết thúc hợp đồng'),
        content: Text(
          'Bạn có chắc muốn kết thúc hợp đồng của '
          '${tenant.name} tại ${tenant.roomName}?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Kết thúc hợp đồng'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    RentalData.terminateTenant(tenant);
    RentalData.notify();

    setState(() {});

    _showMessage(
      'Đã kết thúc hợp đồng. Hồ sơ và chữ ký vẫn được lưu.',
    );
  }

  Future<void> _deleteTenant(Tenant tenant) async {
    if (tenant.isActive) {
      _showMessage(
        'Không thể xóa hồ sơ đang có hợp đồng hiệu lực. '
        'Hãy kết thúc hợp đồng trước.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa hồ sơ người thuê?'),
        content: Text(
          'Bạn có chắc muốn xóa vĩnh viễn hồ sơ của ${tenant.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    RentalData.removeTenantPermanently(tenant);
    RentalData.notify();

    setState(() {});

    _showMessage('Đã xóa hồ sơ người thuê.');
  }

  Future<void> _openContract(Tenant tenant) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ContractDialog(tenant: tenant),
    );

    if (mounted) setState(() {});
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenants = _filteredTenants;

    final activeCount =
        _tenants.where((tenant) => tenant.isActive).length;

    final accountCount =
        _tenants.where((tenant) => tenant.hasAccount).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý người thuê'),
        actions: [
          IconButton(
            tooltip: 'Thêm người thuê',
            onPressed: () => _openTenantForm(),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTenantForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm người thuê'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm tên, số điện thoại, mã phòng...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchText = '');
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchText = value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Tổng hồ sơ',
                    '${_tenants.length}',
                    Icons.people_alt_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    'Đang thuê',
                    '$activeCount',
                    Icons.meeting_room_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    'Đã có tài khoản',
                    '$accountCount',
                    Icons.account_circle_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: tenants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _tenants.isEmpty
                                ? 'Chưa có người thuê nào'
                                : 'Không tìm thấy người thuê',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nhấn Thêm người thuê để bắt đầu.',
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: tenants.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tenant = tenants[index];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      child: Text(
                                        tenant.name.isEmpty
                                            ? '?'
                                            : tenant.name[0]
                                                .toUpperCase(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tenant.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          Text(
                                            '${tenant.roomName} '
                                            '(${tenant.roomId})',
                                          ),
                                          Text(tenant.phone),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _openTenantForm(
                                            tenant: tenant,
                                          );
                                        } else if (value ==
                                            'terminate') {
                                          _terminateTenant(tenant);
                                        } else if (value ==
                                            'delete') {
                                          _deleteTenant(tenant);
                                        } else if (value ==
                                            'account') {
                                          _toggleTenantAccount(tenant);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        if (tenant.isActive)
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Sửa hồ sơ'),
                                          ),
                                        if (tenant.isActive)
                                          const PopupMenuItem(
                                            value: 'terminate',
                                            child: Text(
                                              'Kết thúc hợp đồng',
                                            ),
                                          ),
                                        if (tenant.hasAccount)
                                          PopupMenuItem(
                                            value: 'account',
                                            child: Text(
                                              tenant.accountActive
                                                  ? 'Khóa tài khoản'
                                                  : 'Mở khóa tài khoản',
                                            ),
                                          ),
                                        if (!tenant.isActive)
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Xóa hồ sơ'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Text(
                                  'Tiền thuê: '
                                  '${_money(tenant.rent)} đ/tháng',
                                ),
                                Text(
                                  'Đặt cọc: '
                                  '${_money(tenant.deposit)} đ',
                                ),
                                Text(
                                  'Thời hạn: ${_date(tenant.startDate)}'
                                  ' – ${_date(tenant.endDate)}',
                                ),
                                if (tenant.hasAccount) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tài khoản: ${tenant.accountEmail ?? tenant.email}',
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Chip(
                                      avatar: Icon(
                                        tenant.isActive
                                            ? Icons.check_circle
                                            : Icons.history,
                                        size: 18,
                                      ),
                                      label: Text(
                                        tenant.isActive
                                            ? 'Đang thuê'
                                            : 'Đã kết thúc',
                                      ),
                                    ),
                                    Chip(
                                      avatar: Icon(
                                        tenant.isSigned
                                            ? Icons.verified
                                            : Icons.pending_actions,
                                        size: 18,
                                      ),
                                      label: Text(
                                        tenant.isSigned
                                            ? 'Đã ký hai bên'
                                            : 'Chưa ký đủ',
                                      ),
                                    ),
                                    if (tenant.hasAccount)
                                      Chip(
                                        avatar: Icon(
                                          tenant.accountActive
                                              ? Icons.lock_open
                                              : Icons.lock,
                                          size: 18,
                                        ),
                                        label: Text(
                                          tenant.accountActive
                                              ? 'Tài khoản hoạt động'
                                              : 'Tài khoản bị khóa',
                                        ),
                                      )
                                    else
                                      const Chip(
                                        label: Text('Chưa có tài khoản'),
                                      ),
                                  ],
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _openContract(tenant),
                                    icon: const Icon(
                                      Icons.description_outlined,
                                    ),
                                    label: const Text(
                                      'Hợp đồng / Chữ ký',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantFormDialog extends StatefulWidget {
  final Tenant? tenant;

  const _TenantFormDialog({this.tenant});

  @override
  State<_TenantFormDialog> createState() =>
      _TenantFormDialogState();
}

class _TenantFormDialogState extends State<_TenantFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _identity;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;

  final TextEditingController _password =
      TextEditingController();

  final TextEditingController _confirmPassword =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _selectedRoomId;

  late DateTime _startDate;
  late DateTime _endDate;

  bool _createAccount = false;
  bool _saving = false;

  List<Room> get _rooms =>
      RentalData.rooms.cast<Room>();

  List<Room> get _availableRooms {
    return _rooms.where((room) {
      if (room.status == RoomStatus.maintenance) {
        return false;
      }

      return !RentalData.isRoomAssigned(
        room.id,
        exceptTenantId: widget.tenant?.id,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    final tenant = widget.tenant;

    _name = TextEditingController(text: tenant?.name ?? '');
    _phone = TextEditingController(text: tenant?.phone ?? '');
    _email = TextEditingController(text: tenant?.email ?? '');
    _identity =
        TextEditingController(text: tenant?.identityNumber ?? '');

    _rent = TextEditingController(
      text: tenant == null
          ? ''
          : tenant.rent.toStringAsFixed(0),
    );

    _deposit = TextEditingController(
      text: tenant == null
          ? ''
          : tenant.deposit.toStringAsFixed(0),
    );

    _selectedRoomId = tenant?.roomId;

    _startDate = tenant?.startDate ?? DateTime.now();

    _endDate = tenant?.endDate ??
        DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _identity.dispose();
    _rent.dispose();
    _deposit.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _onRoomChanged(String? roomId) {
    if (roomId == null) return;

    final room = RentalData.findRoom(roomId);

    if (room == null) return;

    setState(() {
      _selectedRoomId = roomId;
      _rent.text = room.price.toStringAsFixed(0);
    });
  }

  Future<void> _chooseDate(bool isStart) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = selected;

        if (!_endDate.isAfter(_startDate)) {
          _endDate = _startDate.add(
            const Duration(days: 1),
          );
        }
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoomId == null) {
      _showError('Vui lòng chọn phòng.');
      return;
    }

    if (!_endDate.isAfter(_startDate)) {
      _showError('Ngày kết thúc phải sau ngày bắt đầu.');
      return;
    }

    final room = RentalData.findRoom(_selectedRoomId!);

    if (room == null) {
      _showError('Phòng đã bị xóa. Vui lòng chọn phòng khác.');
      return;
    }

    if (room.status == RoomStatus.maintenance) {
      _showError('Phòng đang bảo trì, không thể cho thuê.');
      return;
    }

    if (RentalData.isRoomAssigned(
      room.id,
      exceptTenantId: widget.tenant?.id,
    )) {
      _showError('Phòng này đã có người thuê chính.');
      return;
    }

    final rent = double.tryParse(
      _rent.text.trim().replaceAll(RegExp(r'[.,\s]'), ''),
    );

    final deposit = double.tryParse(
      _deposit.text.trim().replaceAll(RegExp(r'[.,\s]'), ''),
    );

    if (rent == null ||
        rent <= 0 ||
        deposit == null ||
        deposit < 0) {
      _showError('Vui lòng nhập tiền thuê và tiền cọc hợp lệ.');
      return;
    }

    final email = _email.text.trim();

    if (_createAccount) {
      if (email.isEmpty || !email.contains('@')) {
        _showError('Vui lòng nhập email hợp lệ để tạo tài khoản.');
        return;
      }

      if (_password.text.length < 6) {
        _showError('Mật khẩu phải có ít nhất 6 ký tự.');
        return;
      }

      if (_password.text != _confirmPassword.text) {
        _showError('Mật khẩu xác nhận không khớp.');
        return;
      }
    }

    setState(() => _saving = true);

    final old = widget.tenant;

    String? firebaseUid = old?.firebaseUid;
    String? accountEmail = old?.accountEmail;
    bool accountActive = old?.accountActive ?? true;

    try {
      if (_createAccount && old?.hasAccount != true) {
        firebaseUid = await TenantAccountService.createTenantAccount(
          email: email,
          password: _password.text,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          roomId: room.id,
          roomName: room.name,
          tenantId: old?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
        );

        accountEmail = email;
        accountActive = true;
      }

      final tenant = Tenant(
        id: old?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: email,
        identityNumber: _identity.text.trim(),
        roomId: room.id,
        roomName: room.name,
        rent: rent,
        deposit: deposit,
        startDate: _startDate,
        endDate: _endDate,
        isActive: true,
        firebaseUid: firebaseUid,
        accountEmail: accountEmail,
        accountActive: accountActive,
        tenantSignature: old?.tenantSignature,
        landlordSignature: old?.landlordSignature,
        tenantSignedAt: old?.tenantSignedAt,
        landlordSignedAt: old?.landlordSignedAt,
      );

      if (!mounted) return;

      Navigator.pop(context, tenant);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Không thể lưu người thuê: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = true,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (required &&
              (value == null || value.trim().isEmpty)) {
            return 'Vui lòng nhập $label';
          }

          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _availableRooms;

    final selectedExists = rooms.any(
      (room) => room.id == _selectedRoomId,
    );

    return AlertDialog(
      title: Text(
        widget.tenant == null
            ? 'Thêm người thuê'
            : 'Sửa hồ sơ người thuê',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field('Họ và tên', _name),
                _field(
                  'Số điện thoại',
                  _phone,
                  keyboardType: TextInputType.phone,
                ),
                _field(
                  'Email',
                  _email,
                  required: false,
                  keyboardType: TextInputType.emailAddress,
                ),
                _field('Số CCCD/CMND', _identity),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue:
                      selectedExists ? _selectedRoomId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Chọn phòng thuê',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Vui lòng chọn phòng'),
                  items: rooms.map((room) {
                    return DropdownMenuItem<String>(
                      value: room.id,
                      child: Text(
                        '${room.name} (${room.id})',
                      ),
                    );
                  }).toList(),
                  onChanged: _onRoomChanged,
                  validator: (value) {
                    if (value == null) {
                      return 'Vui lòng chọn phòng';
                    }
                    return null;
                  },
                ),
                if (rooms.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Không có phòng trống để cho thuê. '
                      'Vui lòng tạo phòng hoặc kết thúc hợp đồng cũ.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 12),
                _field(
                  'Tiền thuê/tháng (VNĐ)',
                  _rent,
                  keyboardType: TextInputType.number,
                ),
                _field(
                  'Tiền đặt cọc (VNĐ)',
                  _deposit,
                  keyboardType: TextInputType.number,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ngày bắt đầu thuê'),
                  subtitle: Text(_date(_startDate)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () => _chooseDate(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ngày kết thúc thuê'),
                  subtitle: Text(_date(_endDate)),
                  trailing: const Icon(Icons.event),
                  onTap: () => _chooseDate(false),
                ),
                if (widget.tenant?.hasAccount != true) ...[
                  const Divider(height: 24),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _createAccount,
                    onChanged: (value) {
                      setState(() {
                        _createAccount = value ?? false;
                      });
                    },
                    title: const Text(
                      'Tạo tài khoản đăng nhập cho người thuê',
                    ),
                    subtitle: const Text(
                      'Người thuê có thể đăng nhập vào ứng dụng.',
                    ),
                  ),
                  if (_createAccount) ...[
                    _field(
                      'Email đăng nhập',
                      _email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu đăng nhập',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu đăng nhập';
                          }
                          if (value.length < 6) {
                            return 'Mật khẩu phải có ít nhất 6 ký tự';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _confirmPassword,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng xác nhận mật khẩu';
                          }
                          if (value != _password.text) {
                            return 'Mật khẩu xác nhận không khớp';
                          }
                          return null;
                        },
                      ),
                    ),
                    const Text(
                      'Mật khẩu tối thiểu 6 ký tự. Hãy gửi thông tin '
                      'đăng nhập cho người thuê một cách an toàn.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ] else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Đã có tài khoản đăng nhập'),
                    subtitle: Text(
                      widget.tenant!.accountEmail ??
                          widget.tenant!.email,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ||
                  (rooms.isEmpty && widget.tenant == null)
              ? null
              : _save,
          child: Text(
            _saving ? 'Đang xử lý...' : 'Lưu hồ sơ',
          ),
        ),
      ],
    );
  }
}

class _ContractDialog extends StatefulWidget {
  final Tenant tenant;

  const _ContractDialog({required this.tenant});

  @override
  State<_ContractDialog> createState() =>
      _ContractDialogState();
}

class _ContractDialogState extends State<_ContractDialog> {
  late final SignatureController _signatureController;

  String _signer = 'tenant';
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    if (widget.tenant.tenantSignature != null) {
      _signer = 'landlord';
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng ký trước khi xác nhận.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);

    final bytes = await _signatureController.toPngBytes();

    if (!mounted) return;

    if (bytes == null) {
      setState(() => _busy = false);
      return;
    }

    setState(() {
      if (_signer == 'tenant') {
        widget.tenant.tenantSignature = bytes;
        widget.tenant.tenantSignedAt = DateTime.now();
        _signer = 'landlord';
      } else {
        widget.tenant.landlordSignature = bytes;
        widget.tenant.landlordSignedAt = DateTime.now();
      }

      _signatureController.clear();
      _busy = false;
    });

    RentalData.notify();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _signer == 'landlord'
              ? 'Người thuê đã ký. Mời chủ nhà ký tiếp.'
              : 'Đã lưu chữ ký chủ nhà.',
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final tenant = widget.tenant;
    final pdf = pw.Document();

    pw.Widget signatureBlock(
      String title,
      Uint8List? bytes,
    ) {
      return pw.Column(
        children: [
          pw.Text(title),
          pw.SizedBox(height: 8),
          if (bytes != null)
            pw.Image(
              pw.MemoryImage(bytes),
              width: 150,
              height: 65,
              fit: pw.BoxFit.contain,
            )
          else
            pw.Container(
              width: 150,
              height: 65,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
              ),
              child: pw.Text('Chưa ký'),
            ),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Center(
            child: pw.Text(
              'HỢP ĐỒNG THUÊ PHÒNG',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            '1. THÔNG TIN NGƯỜI THUÊ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Họ tên: ${tenant.name}'),
          pw.Text('Số điện thoại: ${tenant.phone}'),
          pw.Text('Email: ${tenant.email}'),
          pw.Text('CCCD/CMND: ${tenant.identityNumber}'),
          pw.SizedBox(height: 16),
          pw.Text(
            '2. THÔNG TIN THUÊ PHÒNG',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Phòng: ${tenant.roomName} (${tenant.roomId})',
          ),
          pw.Text(
            'Tiền thuê: ${_money(tenant.rent)} VNĐ/tháng',
          ),
          pw.Text(
            'Tiền đặt cọc: ${_money(tenant.deposit)} VNĐ',
          ),
          pw.Text(
            'Ngày bắt đầu: ${_date(tenant.startDate)}',
          ),
          pw.Text(
            'Ngày kết thúc: ${_date(tenant.endDate)}',
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            '3. ĐIỀU KHOẢN',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Hai bên xác nhận thông tin thuê phòng nêu trên. '
            'Các điều khoản cụ thể về thanh toán, điện, nước, '
            'tiền phạt, chấm dứt hợp đồng và trách nhiệm của các bên '
            'cần được bổ sung, thống nhất trước khi ký chính thức.',
          ),
          pw.SizedBox(height: 30),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: signatureBlock(
                  'NGƯỜI THUÊ',
                  tenant.tenantSignature,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: signatureBlock(
                  'CHỦ NHÀ',
                  tenant.landlordSignature,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Lưu ý: Đây là mẫu thử nghiệm. Vui lòng hoàn thiện và '
            'kiểm tra điều khoản pháp lý trước khi sử dụng chính thức.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;
    final allSigned = tenant.isSigned;

    final alreadySigned = _signer == 'tenant'
        ? tenant.tenantSignature != null
        : tenant.landlordSignature != null;

    return AlertDialog(
      title: const Text('Hợp đồng thuê phòng'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THÔNG TIN HỢP ĐỒNG',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Người thuê: ${tenant.name}'),
              Text(
                'Phòng: ${tenant.roomName} (${tenant.roomId})',
              ),
              Text('Số điện thoại: ${tenant.phone}'),
              Text(
                'Tiền thuê: ${_money(tenant.rent)} VNĐ/tháng',
              ),
              Text(
                'Đặt cọc: ${_money(tenant.deposit)} VNĐ',
              ),
              Text('Bắt đầu: ${_date(tenant.startDate)}'),
              Text('Kết thúc: ${_date(tenant.endDate)}'),
              const Divider(height: 28),
              const Text(
                'TRẠNG THÁI CHỮ KÝ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: tenant.tenantSignature != null,
                onChanged: null,
                title: const Text('Người thuê đã ký'),
                subtitle: tenant.tenantSignedAt == null
                    ? null
                    : Text(_dateTime(tenant.tenantSignedAt!)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: tenant.landlordSignature != null,
                onChanged: null,
                title: const Text('Chủ nhà đã ký'),
                subtitle: tenant.landlordSignedAt == null
                    ? null
                    : Text(_dateTime(tenant.landlordSignedAt!)),
              ),
              const Divider(height: 28),
              if (!allSigned) ...[
                Text(
                  _signer == 'tenant'
                      ? 'Chữ ký người thuê'
                      : 'Chữ ký chủ nhà',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 170,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: alreadySigned
                      ? const Center(
                          child: Text(
                            'Bên này đã ký. Không thể ký lại '
                            'ở bản thử nghiệm.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Signature(
                          controller: _signatureController,
                          backgroundColor: Colors.white,
                        ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: alreadySigned
                          ? null
                          : () => _signatureController.clear(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Xóa chữ ký'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: alreadySigned || _busy
                          ? null
                          : _saveSignature,
                      icon: const Icon(Icons.draw),
                      label: Text(
                        _busy ? 'Đang lưu...' : 'Xác nhận ký',
                      ),
                    ),
                  ],
                ),
              ] else
                const ListTile(
                  leading: Icon(
                    Icons.verified,
                    color: Colors.green,
                  ),
                  title: Text('Hai bên đã ký'),
                  subtitle: Text(
                    'Chữ ký đang được lưu trong bộ nhớ ứng dụng.',
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Bản thử nghiệm: chữ ký chưa được đồng bộ lên máy chủ. '
                'Hãy chỉ ký khi đã kiểm tra nội dung hợp đồng.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
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
        FilledButton.icon(
          onPressed: _exportPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Xuất PDF'),
        ),
      ],
    );
  }
}

String _date(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

String _dateTime(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '${_date(date)} $h:$m';
}

String _money(double value) {
  return value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
      );
}