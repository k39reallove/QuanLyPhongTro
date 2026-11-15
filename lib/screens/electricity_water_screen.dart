import 'package:flutter/material.dart';

import 'utility_data.dart';
import 'rental_data.dart';
import 'rooms_screen.dart';

class ElectricityWaterScreen extends StatefulWidget {
  const ElectricityWaterScreen({super.key});

  @override
  State<ElectricityWaterScreen> createState() => _ElectricityWaterScreenState();
}

class _ElectricityWaterScreenState extends State<ElectricityWaterScreen> {
  String? selectedRoom;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final oldElectricController = TextEditingController();
  final newElectricController = TextEditingController();
  final oldWaterController = TextEditingController();
  final newWaterController = TextEditingController();

  final electricPriceController = TextEditingController(text: '3500');
  final waterPriceController = TextEditingController(text: '15000');

  List<Room> get rooms => RentalData.rooms.cast<Room>();

  int _read(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  int get electricUsed {
    final difference =
        _read(newElectricController) - _read(oldElectricController);

    return difference >= 0 ? difference : 0;
  }

  int get waterUsed {
    final difference = _read(newWaterController) - _read(oldWaterController);

    return difference >= 0 ? difference : 0;
  }

  int get electricPrice => _read(electricPriceController);

  int get waterPrice => _read(waterPriceController);

  int get electricTotal => electricUsed * electricPrice;

  int get waterTotal => waterUsed * waterPrice;

  int get grandTotal => electricTotal + waterTotal;

  String get monthLabel =>
      '${selectedMonth.month.toString().padLeft(2, '0')}/${selectedMonth.year}';

  @override
  void initState() {
    super.initState();

    RentalData.version.addListener(_onRoomsChanged);
  }

  void _onRoomsChanged() {
    if (!mounted) return;

    setState(() {
      if (selectedRoom != null &&
          !rooms.any((room) => room.id == selectedRoom)) {
        selectedRoom = null;
        _clearFields();
      }
    });
  }

  void _clearFields() {
    oldElectricController.clear();
    newElectricController.clear();
    oldWaterController.clear();
    newWaterController.clear();

    electricPriceController.text = '3500';
    waterPriceController.text = '15000';
  }

  DateTime _previousMonth() {
    return DateTime(selectedMonth.year, selectedMonth.month - 1);
  }

  void loadExistingRecord() {
    if (selectedRoom == null) {
      _clearFields();
      return;
    }

    final record = UtilityData.find(
      selectedRoom!,
      selectedMonth.month,
      selectedMonth.year,
    );

    if (record != null) {
      oldElectricController.text = record.oldElectricReading.toString();

      newElectricController.text = record.newElectricReading.toString();

      oldWaterController.text = record.oldWaterReading.toString();

      newWaterController.text = record.newWaterReading.toString();

      electricPriceController.text = record.electricPrice.toString();

      waterPriceController.text = record.waterPrice.toString();

      return;
    }

    // Nếu chưa có dữ liệu tháng này, lấy chỉ số mới
    // của tháng trước làm chỉ số cũ.
    _clearFields();

    final previous = _previousMonth();

    final previousRecord = UtilityData.find(
      selectedRoom!,
      previous.month,
      previous.year,
    );

    if (previousRecord != null) {
      oldElectricController.text = previousRecord.newElectricReading.toString();

      oldWaterController.text = previousRecord.newWaterReading.toString();

      electricPriceController.text = previousRecord.electricPrice.toString();

      waterPriceController.text = previousRecord.waterPrice.toString();
    }
  }

  Future<void> chooseMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn tháng ghi chỉ số',
    );

    if (picked == null || !mounted) return;

    setState(() {
      selectedMonth = DateTime(picked.year, picked.month);
      loadExistingRecord();
    });
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  bool _validateInput() {
    if (selectedRoom == null) {
      _showMessage('Vui lòng chọn phòng trước khi lưu.', error: true);
      return false;
    }

    final oldElectric = int.tryParse(oldElectricController.text.trim());

    final newElectric = int.tryParse(newElectricController.text.trim());

    final oldWater = int.tryParse(oldWaterController.text.trim());

    final newWater = int.tryParse(newWaterController.text.trim());

    final electricPriceValue = int.tryParse(
      electricPriceController.text.trim(),
    );

    final waterPriceValue = int.tryParse(waterPriceController.text.trim());

    if (oldElectric == null ||
        newElectric == null ||
        oldWater == null ||
        newWater == null ||
        electricPriceValue == null ||
        waterPriceValue == null) {
      _showMessage('Vui lòng nhập đầy đủ thông tin hợp lệ.', error: true);
      return false;
    }

    if (oldElectric < 0 ||
        newElectric < 0 ||
        oldWater < 0 ||
        newWater < 0 ||
        electricPriceValue <= 0 ||
        waterPriceValue <= 0) {
      _showMessage(
        'Chỉ số không được âm và đơn giá phải lớn hơn 0.',
        error: true,
      );
      return false;
    }

    if (newElectric < oldElectric || newWater < oldWater) {
      _showMessage('Chỉ số mới không được nhỏ hơn chỉ số cũ.', error: true);
      return false;
    }

    return true;
  }

  void saveRecord() {
    if (!_validateInput()) return;

    final oldElectric = _read(oldElectricController);
    final newElectric = _read(newElectricController);

    final oldWater = _read(oldWaterController);
    final newWater = _read(newWaterController);

    final usedElectric = newElectric - oldElectric;
    final usedWater = newWater - oldWater;

    final totalElectric = usedElectric * electricPrice;
    final totalWater = usedWater * waterPrice;

    final record = UtilityRecord(
      room: selectedRoom!,
      month: selectedMonth.month,
      year: selectedMonth.year,
      oldElectricReading: oldElectric,
      newElectricReading: newElectric,
      oldWaterReading: oldWater,
      newWaterReading: newWater,
      electricUsed: usedElectric,
      waterUsed: usedWater,
      electricPrice: electricPrice,
      waterPrice: waterPrice,
      electricTotal: totalElectric,
      waterTotal: totalWater,
    );

    UtilityData.save(record);

    setState(() {});

    _showMessage('Đã lưu chỉ số điện nước thành công.');
  }

  String formatMoney(num value) {
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} đ';
  }

  Widget sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2459A9)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget numberField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF5F7FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget resultRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? const Color(0xFF2459A9) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget utilityCard({
    required String title,
    required IconData icon,
    required TextEditingController oldController,
    required TextEditingController newController,
    required TextEditingController priceController,
    required int used,
    required int total,
    required String unit,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(title, icon),
            const SizedBox(height: 16),
            Row(
              children: [
                numberField('Chỉ số cũ', oldController, 'Ví dụ: 100'),
                const SizedBox(width: 12),
                numberField('Chỉ số mới', newController, 'Ví dụ: 120'),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Đơn giá',
                suffixText: 'đ/$unit',
                filled: true,
                fillColor: const Color(0xFFF5F7FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  resultRow('Sử dụng', '$used $unit'),
                  resultRow('Thành tiền', formatMoney(total), bold: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteRecord(UtilityRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa dữ liệu điện nước?'),
        content: Text(
          'Bạn có chắc muốn xóa dữ liệu phòng '
          '${record.room} tháng ${record.period}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      UtilityData.delete(record);

      if (record.room == selectedRoom &&
          record.month == selectedMonth.month &&
          record.year == selectedMonth.year) {
        loadExistingRecord();
      }
    });

    _showMessage('Đã xóa dữ liệu điện nước.');
  }

  Widget historyCard(UtilityRecord record, List<Room> availableRooms) {
    Room? room;

    for (final item in availableRooms) {
      if (item.id == record.room) {
        room = item;
        break;
      }
    }

    final roomLabel = room == null ? record.room : '${room.name} (${room.id})';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          setState(() {
            selectedRoom = record.room;
            selectedMonth = DateTime(record.year, record.month);
            loadExistingRecord();
          });

          _showMessage('Đã tải dữ liệu phòng ${record.room}.');
        },
        title: Text(
          '$roomLabel - ${record.period}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Điện: ${record.oldElectricReading} → '
            '${record.newElectricReading} '
            '(${record.electricUsed} kWh)\n'
            'Nước: ${record.oldWaterReading} → '
            '${record.newWaterReading} '
            '(${record.waterUsed} m³)\n'
            'Tổng tiền: ${formatMoney(record.total)}',
          ),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Xóa dữ liệu',
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => deleteRecord(record),
        ),
      ),
    );
  }

  @override
  void dispose() {
    RentalData.version.removeListener(_onRoomsChanged);

    oldElectricController.dispose();
    newElectricController.dispose();
    oldWaterController.dispose();
    newWaterController.dispose();
    electricPriceController.dispose();
    waterPriceController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableRooms = rooms;

    final history = [...UtilityData.records];

    history.sort((a, b) {
      final dateA = DateTime(a.year, a.month);
      final dateB = DateTime(b.year, b.month);

      return dateB.compareTo(dateA);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý điện nước',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle('Thông tin ghi chỉ số', Icons.edit_note),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: selectedRoom,
                    isExpanded: true,
                    hint: const Text('Vui lòng chọn phòng'),
                    decoration: const InputDecoration(
                      labelText: 'Chọn phòng',
                      border: OutlineInputBorder(),
                    ),
                    items: availableRooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room.id,
                        child: Text('${room.name} (${room.id})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedRoom = value;
                        loadExistingRecord();
                      });
                    },
                  ),

                  if (availableRooms.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Chưa có phòng nào. '
                        'Vui lòng tạo phòng trong mục Quản lý phòng.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: selectedRoom == null ? null : chooseMonth,
                    icon: const Icon(Icons.calendar_month),
                    label: Text('Tháng ghi chỉ số: $monthLabel'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          utilityCard(
            title: 'Chỉ số điện',
            icon: Icons.electric_bolt,
            oldController: oldElectricController,
            newController: newElectricController,
            priceController: electricPriceController,
            used: electricUsed,
            total: electricTotal,
            unit: 'kWh',
          ),

          const SizedBox(height: 12),

          utilityCard(
            title: 'Chỉ số nước',
            icon: Icons.water_drop_outlined,
            oldController: oldWaterController,
            newController: newWaterController,
            priceController: waterPriceController,
            used: waterUsed,
            total: waterTotal,
            unit: 'm³',
          ),

          const SizedBox(height: 12),

          Card(
            color: const Color(0xFFEAF1FC),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TỔNG TIỀN ĐIỆN NƯỚC',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2459A9),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatMoney(grandTotal),
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2459A9),
                    ),
                  ),
                  resultRow('Tiền điện', formatMoney(electricTotal)),
                  resultRow('Tiền nước', formatMoney(waterTotal)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: selectedRoom == null ? null : saveRecord,
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'LƯU CHỈ SỐ ĐIỆN NƯỚC',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 24),

          sectionTitle('Lịch sử ghi chỉ số', Icons.history),

          const SizedBox(height: 12),

          if (history.isEmpty)
            const Card(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Chưa có dữ liệu ghi chỉ số.')),
              ),
            )
          else
            ...history.map((record) => historyCard(record, availableRooms)),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
