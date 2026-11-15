
import 'package:flutter/material.dart';
import 'rental_data.dart';

enum RoomStatus { vacant, occupied, maintenance }

class Room {
  final String id;
  String name;
  double price;
  double area;
  int maxPeople;
  RoomStatus status;

  DateTime? rentStartDate;
  DateTime? rentEndDate;
  DateTime? maintenanceStartDate;
  DateTime? maintenanceExpectedEndDate;

  Room({
    required this.id,
    required this.name,
    required this.price,
    required this.area,
    required this.maxPeople,
    required this.status,
    this.rentStartDate,
    this.rentEndDate,
    this.maintenanceStartDate,
    this.maintenanceExpectedEndDate,
  });
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Chưa thiết lập';

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String _formatPrice(double price) {
  return '${price.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  )} đ/tháng';
}

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  String _searchText = '';

  List<Room> get _rooms => RentalData.rooms.cast<Room>();

  @override
  void initState() {
    super.initState();

    RentalData.initialize(
      initialRooms: [
        Room(
          id: 'P101',
          name: 'Phòng 101',
          price: 2500000,
          area: 20,
          maxPeople: 2,
          status: RoomStatus.vacant,
        ),
        Room(
          id: 'P102',
          name: 'Phòng 102',
          price: 3000000,
          area: 25,
          maxPeople: 3,
          status: RoomStatus.vacant,
        ),
      ],
    );

    RentalData.version.addListener(_onDataChanged);
    _syncRoomStatuses();
  }

  void _onDataChanged() {
    if (!mounted) return;

    setState(() {
      _syncRoomStatuses();
    });
  }

  @override
  void dispose() {
    RentalData.version.removeListener(_onDataChanged);
    super.dispose();
  }

  void _syncRoomStatuses() {
    for (final room in _rooms) {
      if (room.status == RoomStatus.maintenance) {
        continue;
      }

      final tenant = RentalData.activeTenantOfRoom(room.id);

      if (tenant != null) {
        room.status = RoomStatus.occupied;
        room.rentStartDate = tenant.startDate;
        room.rentEndDate = tenant.endDate;
      } else {
        room.status = RoomStatus.vacant;
        room.rentStartDate = null;
        room.rentEndDate = null;
      }
    }
  }

  List<Room> get _filteredRooms {
    final keyword = _searchText.toLowerCase().trim();

    return _rooms.where((room) {
      return room.name.toLowerCase().contains(keyword) ||
          room.id.toLowerCase().contains(keyword);
    }).toList();
  }

  String _statusText(RoomStatus status) {
    switch (status) {
      case RoomStatus.vacant:
        return 'Phòng trống';
      case RoomStatus.occupied:
        return 'Đang thuê';
      case RoomStatus.maintenance:
        return 'Bảo trì';
    }
  }

  Color _statusColor(RoomStatus status) {
    switch (status) {
      case RoomStatus.vacant:
        return Colors.green;
      case RoomStatus.occupied:
        return Colors.blue;
      case RoomStatus.maintenance:
        return Colors.orange;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showRoomForm({Room? room}) async {
    final result = await showDialog<Room>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RoomFormDialog(room: room),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (room == null) {
        RentalData.rooms.add(result);
      } else {
        final index = _rooms.indexWhere(
          (item) => item.id == room.id,
        );

        if (index != -1) {
          final existing = _rooms[index];

          existing.name = result.name;
          existing.price = result.price;
          existing.area = result.area;
          existing.maxPeople = result.maxPeople;

          if (existing.status != RoomStatus.maintenance ||
              result.status == RoomStatus.maintenance) {
            existing.status = result.status;
          }

          existing.maintenanceStartDate =
              result.maintenanceStartDate;
          existing.maintenanceExpectedEndDate =
              result.maintenanceExpectedEndDate;

          if (result.status == RoomStatus.maintenance) {
            existing.status = RoomStatus.maintenance;
          }
        }
      }

      _syncRoomStatuses();
    });

    RentalData.notify();

    _showMessage(
      room == null
          ? 'Đã thêm phòng thành công.'
          : 'Đã cập nhật phòng thành công.',
    );
  }

  Future<void> _deleteRoom(Room room) async {
    final tenant = RentalData.activeTenantOfRoom(room.id);

    if (tenant != null) {
      _showMessage(
        'Phòng vẫn có người thuê chính. '
        'Hãy kết thúc hợp đồng trước khi xóa.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa phòng'),
        content: Text('Bạn có chắc muốn xóa ${room.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    RentalData.rooms.removeWhere(
      (item) => item.id == room.id,
    );

    RentalData.notify();

    setState(() {});

    _showMessage('Đã xóa phòng thành công.');
  }

  void _showTenantInfo(Room room) {
    final tenant = RentalData.activeTenantOfRoom(room.id);

    if (tenant == null) {
      _showMessage('Phòng hiện chưa có người thuê chính.');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Người thuê chính • ${room.name}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(
                  tenant.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(tenant.phone),
              ),
              const Divider(),
              _infoRow('Mã phòng', room.id),
              _infoRow('Tiền thuê', _formatPrice(room.price)),
              _infoRow(
                'Tiền đặt cọc',
                '${tenant.deposit.toStringAsFixed(0)} VNĐ',
              ),
              _infoRow(
                'Ngày bắt đầu',
                _formatDate(tenant.startDate),
              ),
              _infoRow(
                'Ngày kết thúc',
                _formatDate(tenant.endDate),
              ),
              _infoRow(
                'Chữ ký',
                tenant.isSigned
                    ? 'Đã ký đủ hai bên'
                    : 'Chưa ký đủ hai bên',
              ),
              const SizedBox(height: 8),
              const Text(
                'Người này là người đứng tên hợp đồng '
                'và chịu trách nhiệm chính với phòng.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    final color = _statusColor(room.status);
    final tenant = RentalData.activeTenantOfRoom(room.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.meeting_room,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Mã phòng: ${room.id}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showRoomForm(room: room);
                    } else if (value == 'delete') {
                      _deleteRoom(room);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Sửa phòng'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Xóa phòng'),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              _formatPrice(room.price),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Diện tích: ${room.area} m²'),
                Text('Tối đa: ${room.maxPeople} người'),
              ],
            ),
            if (room.status == RoomStatus.occupied) ...[
              const SizedBox(height: 12),
              _infoRow(
                'Người thuê chính',
                tenant?.name ?? 'Chưa có thông tin',
              ),
              _infoRow(
                'Số điện thoại',
                tenant?.phone ?? 'Chưa có',
              ),
              _infoRow(
                'Bắt đầu thuê',
                _formatDate(room.rentStartDate),
              ),
              _infoRow(
                'Kết thúc thuê',
                _formatDate(room.rentEndDate),
              ),
            ],
            if (room.status == RoomStatus.maintenance) ...[
              const SizedBox(height: 12),
              _infoRow(
                'Bắt đầu bảo trì',
                _formatDate(room.maintenanceStartDate),
              ),
              _infoRow(
                'Dự kiến hoàn thành',
                _formatDate(room.maintenanceExpectedEndDate),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusText(room.status),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: tenant == null
                    ? () => _showMessage(
                          'Phòng chưa có người thuê chính.',
                        )
                    : () => _showTenantInfo(room),
                icon: const Icon(Icons.person_outline),
                label: Text(
                  tenant == null
                      ? 'Chưa có người thuê chính'
                      : 'Xem người thuê chính',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _filteredRooms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý phòng trọ'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc mã phòng...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Danh sách phòng (${_rooms.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showRoomForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm phòng'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: rooms.isEmpty
                ? const Center(
                    child: Text('Không tìm thấy phòng nào'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      return _buildRoomCard(rooms[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoomFormDialog extends StatefulWidget {
  const _RoomFormDialog({this.room});

  final Room? room;

  @override
  State<_RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends State<_RoomFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _area;
  late final TextEditingController _people;

  late RoomStatus _status;

  DateTime? _maintenanceStart;
  DateTime? _maintenanceEnd;

  String? _dateError;

  Room? get room => widget.room;

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(text: room?.name ?? '');
    _price = TextEditingController(
      text: room?.price.toStringAsFixed(0) ?? '',
    );
    _area = TextEditingController(
      text: room?.area.toString() ?? '',
    );
    _people = TextEditingController(
      text: room?.maxPeople.toString() ?? '2',
    );

    _status = room?.status ?? RoomStatus.vacant;
    _maintenanceStart = room?.maintenanceStartDate;
    _maintenanceEnd = room?.maintenanceExpectedEndDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _area.dispose();
    _people.dispose();
    super.dispose();
  }

  double? _parsePrice(String value) {
    return double.tryParse(
      value.trim().replaceAll(RegExp(r'[.,\s]'), ''),
    );
  }

  double? _parseArea(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  Future<void> _pickMaintenanceDate(bool isStart) async {
    final now = DateTime.now();

    final firstDate = isStart
        ? DateTime(2000)
        : (_maintenanceStart ?? DateTime(2000));

    DateTime initial = isStart
        ? (_maintenanceStart ?? now)
        : (_maintenanceEnd ?? now);

    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(DateTime(2100))) {
      initial = DateTime(2100);
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      helpText: isStart
          ? 'Chọn ngày bắt đầu bảo trì'
          : 'Chọn ngày dự kiến hoàn thành',
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _maintenanceStart = selected;

        if (_maintenanceEnd != null &&
            _maintenanceEnd!.isBefore(selected)) {
          _maintenanceEnd = null;
        }
      } else {
        _maintenanceEnd = selected;
      }

      _dateError = null;
    });
  }

  void _save() {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = _parsePrice(_price.text);
    final area = _parseArea(_area.text);
    final people = int.tryParse(_people.text.trim());

    if (price == null || area == null || people == null) return;

    final hasActiveTenant =
        room != null && RentalData.activeTenantOfRoom(room!.id) != null;

    if (_status == RoomStatus.vacant && hasActiveTenant) {
      setState(() {
        _dateError =
            'Phòng đang có người thuê. Hãy kết thúc hợp đồng trước.';
      });
      return;
    }

    if (_status == RoomStatus.maintenance && hasActiveTenant) {
      setState(() {
        _dateError =
            'Phòng đang có người thuê. Hãy kết thúc hợp đồng trước khi bảo trì.';
      });
      return;
    }

    if (_status == RoomStatus.maintenance) {
      if (_maintenanceStart == null || _maintenanceEnd == null) {
        setState(() {
          _dateError = 'Vui lòng chọn đầy đủ ngày bảo trì.';
        });
        return;
      }

      if (_maintenanceEnd!.isBefore(_maintenanceStart!)) {
        setState(() {
          _dateError =
              'Ngày hoàn thành không được trước ngày bắt đầu bảo trì.';
        });
        return;
      }
    }

    // Tạo mã phòng theo số ở cuối tên phòng.
    // Ví dụ: Phòng 103 -> P103.
    final roomName = _name.text.trim();

    String? roomCode;

    if (room != null) {
      roomCode = room!.id;
    } else {
      final match = RegExp(r'(\d+)\s*$').firstMatch(roomName);

      if (match == null) {
        setState(() {
          _dateError =
              'Tên phòng phải có số, ví dụ: Phòng 103.';
        });
        return;
      }

      roomCode = 'P${match.group(1)}';
    }

    // Kiểm tra mã phòng trùng.
    final duplicate = RentalData.rooms.any(
      (item) =>
          item.id.toString().toUpperCase() ==
              roomCode!.toUpperCase() &&
          item.id.toString() != room?.id,
    );

    if (duplicate) {
      setState(() {
        _dateError = 'Mã phòng $roomCode đã tồn tại.';
      });
      return;
    }

    final result = Room(
      id: roomCode,
      name: roomName,
      price: price,
      area: area,
      maxPeople: people,
      status: _status,
      rentStartDate: room?.rentStartDate,
      rentEndDate: room?.rentEndDate,
      maintenanceStartDate: _maintenanceStart,
      maintenanceExpectedEndDate: _maintenanceEnd,
    );

    Navigator.pop(context, result);
  }

  String _statusText(RoomStatus status) {
    switch (status) {
      case RoomStatus.vacant:
        return 'Phòng trống';
      case RoomStatus.occupied:
        return 'Đang thuê';
      case RoomStatus.maintenance:
        return 'Bảo trì';
    }
  }

  Widget _dateRow(
    String label,
    DateTime? value,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_month),
          ),
          child: Text(_formatDate(value)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        room == null ? 'Thêm phòng mới' : 'Sửa thông tin phòng',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Tên phòng',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập tên phòng'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá thuê (VNĐ/tháng)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = _parsePrice(value ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Nhập giá thuê hợp lệ'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _area,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Diện tích (m²)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = _parseArea(value ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Nhập diện tích hợp lệ'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _people,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số người tối đa',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(
                      (value ?? '').trim(),
                    );

                    return parsed == null || parsed < 1
                        ? 'Số người phải từ 1 trở lên'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái phòng',
                    border: OutlineInputBorder(),
                  ),
                  items: RoomStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(_statusText(status)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _status = value;
                      _dateError = null;
                    });
                  },
                ),
                if (_status == RoomStatus.maintenance) ...[
                  const SizedBox(height: 16),
                  _dateRow(
                    'Ngày bắt đầu bảo trì',
                    _maintenanceStart,
                    () => _pickMaintenanceDate(true),
                  ),
                  _dateRow(
                    'Dự kiến hoàn thành',
                    _maintenanceEnd,
                    () => _pickMaintenanceDate(false),
                  ),
                ],
                if (_dateError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
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
          child: const Text('Lưu phòng'),
        ),
      ],
    );
  }
}
