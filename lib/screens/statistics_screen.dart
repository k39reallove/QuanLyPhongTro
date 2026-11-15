
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'rental_data.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    RentalData.version.addListener(_onRentalDataChanged);
  }

  @override
  void dispose() {
    RentalData.version.removeListener(_onRentalDataChanged);
    super.dispose();
  }

  void _onRentalDataChanged() {
    if (mounted) setState(() {});
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(num value) {
    return '${value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    )} đ';
  }

  int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }


  List<_MonthlyRevenue> _buildMonthlyRevenue(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final now = DateTime.now();
    final months = List.generate(6, (index) {
      final date = DateTime(now.year, now.month - (5 - index));
      return _MonthlyRevenue(
        month: date.month,
        year: date.year,
        revenue: 0,
      );
    });

    for (final doc in documents) {
      final data = doc.data();
      final month = _intValue(data['month']);
      final year = _intValue(data['year']);
      final paid = _number(data['paidAmount']);

      final index = months.indexWhere(
        (item) => item.month == month && item.year == year,
      );

      if (index >= 0) {
        months[index].revenue += paid;
      }
    }

    return months;
  }

  Widget _sectionTitle(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: const Color(0xFF2459A9)),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up,
                color: color.withValues(alpha: 0.7),
                size: 19,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _roomStatistics() {
    final rooms = RentalData.rooms;
    final tenants = RentalData.tenants;

    final totalRooms = rooms.length;

    final maintenanceRooms = rooms.where((room) {
      return room.status.toString().split('.').last == 'maintenance';
    }).length;

    final occupiedRooms = rooms.where((room) {
      return RentalData.activeTenantOfRoom(room.id.toString()) != null;
    }).length;

    final vacantRooms = totalRooms - occupiedRooms - maintenanceRooms;

    final activeTenants = tenants.where((tenant) {
      return tenant.isActive == true;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Tình hình phòng trọ',
          icon: Icons.apartment,
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.65,
          children: [
            _statCard(
              title: 'Tổng số phòng',
              value: '$totalRooms',
              icon: Icons.home_work_outlined,
              color: const Color(0xFF2459A9),
            ),
            _statCard(
              title: 'Đang cho thuê',
              value: '$occupiedRooms',
              icon: Icons.people_alt_outlined,
              color: Colors.green,
            ),
            _statCard(
              title: 'Phòng trống',
              value: '${vacantRooms < 0 ? 0 : vacantRooms}',
              icon: Icons.meeting_room_outlined,
              color: Colors.orange,
            ),
            _statCard(
              title: 'Đang bảo trì',
              value: '$maintenanceRooms',
              icon: Icons.build_outlined,
              color: Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7EAF0)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FE),
                child: Icon(
                  Icons.groups_outlined,
                  color: Color(0xFF2459A9),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Người thuê đang hoạt động',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$activeTenants người',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2459A9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _revenueChart(List<_MonthlyRevenue> months) {
    final maxRevenue = months.fold<double>(
      0,
      (maxValue, item) =>
          item.revenue > maxValue ? item.revenue : maxValue,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Doanh thu theo tháng',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Số tiền đã ghi nhận thanh toán trên hóa đơn',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: months.map((item) {
                final height = maxRevenue <= 0
                    ? 0.0
                    : (item.revenue / maxRevenue * 115)
                        .clamp(0.0, 115.0)
                        .toDouble();

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          item.revenue == 0
                              ? '0'
                              : _compactMoney(item.revenue),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: height == 0 ? 3 : height,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3978D4),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'T${item.month}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF3978D4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'Doanh thu đã thu',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _compactMoney(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)} tỷ';
    }

    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} tr';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)} k';
    }

    return value.toStringAsFixed(0);
  }

  Widget _invoiceStatistics({
    required int total,
    required int paid,
    required int pending,
    required int overdue,
    required int waiting,
  }) {
    final items = [
      _InvoiceStat(
        title: 'Đã thanh toán',
        count: paid,
        color: Colors.green,
        icon: Icons.check_circle_outline,
      ),
      _InvoiceStat(
        title: 'Chưa thanh toán',
        count: pending,
        color: Colors.orange,
        icon: Icons.pending_actions,
      ),
      _InvoiceStat(
        title: 'Quá hạn',
        count: overdue,
        color: Colors.red,
        icon: Icons.warning_amber,
      ),
      _InvoiceStat(
        title: 'Chờ xác nhận',
        count: waiting,
        color: Colors.deepPurple,
        icon: Icons.hourglass_top,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tình trạng hóa đơn',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$total hóa đơn',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  Icon(item.icon, color: item.color, size: 21),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${item.count}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialSummary({
    required double revenue,
    required double debt,
    required double invoiceTotal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Tổng quan tài chính',
          icon: Icons.account_balance_wallet_outlined,
        ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF2459A9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TỔNG DOANH THU ĐÃ THU',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _money(revenue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white30, height: 28),
              Row(
                children: [
                  Expanded(
                    child: _financialItem(
                      'Công nợ còn lại',
                      _money(debt),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _financialItem(
                      'Tổng giá trị hóa đơn',
                      _money(invoiceTotal),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _financialItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatistics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    double revenue = 0;
    double debt = 0;
    double invoiceTotal = 0;

    int paid = 0;
    int pending = 0;
    int overdue = 0;
    int waiting = 0;

    final now = DateTime.now();

    for (final doc in documents) {
      final data = doc.data();

      final roomPrice = _number(data['roomPrice']);
      final electricity = _number(data['electricityCost']);
      final water = _number(data['waterCost']);
      final service = _number(data['serviceCost']);
      final other = _number(data['otherCost']);

      final total = roomPrice + electricity + water + service + other;
      final paidAmount = _number(data['paidAmount']);
      final remaining =
          (total - paidAmount).clamp(0, total).toDouble();

      final paymentStatus = data['paymentStatus']?.toString() ?? '';
      final month = _intValue(data['month']);
      final year = _intValue(data['year']);

      revenue += paidAmount;
      debt += remaining;
      invoiceTotal += total;

      if (paidAmount >= total && total > 0) {
        paid++;
      } else if (paymentStatus == 'pending') {
        waiting++;
      } else if (year < now.year ||
          (year == now.year && month < now.month)) {
        if (remaining > 0) {
          overdue++;
        } else {
          pending++;
        }
      } else {
        pending++;
      }
    }

    final monthlyRevenue = _buildMonthlyRevenue(documents);

    return RefreshIndicator(
      onRefresh: () async {
        await _db.collection('invoices').get(
          const GetOptions(source: Source.server),
        );
        if (mounted) setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _roomStatistics(),
          const SizedBox(height: 24),
          _financialSummary(
            revenue: revenue,
            debt: debt,
            invoiceTotal: invoiceTotal,
          ),
          const SizedBox(height: 24),
          _sectionTitle(
            'Biểu đồ doanh thu',
            icon: Icons.bar_chart_rounded,
          ),
          _revenueChart(monthlyRevenue),
          const SizedBox(height: 24),
          _sectionTitle(
            'Hóa đơn',
            icon: Icons.receipt_long_outlined,
          ),
          _invoiceStatistics(
            total: documents.length,
            paid: paid,
            pending: pending,
            overdue: overdue,
            waiting: waiting,
          ),
          const SizedBox(height: 20),
          const Text(
            'Số liệu được tổng hợp từ dữ liệu phòng, người thuê '
            'và collection invoices trên Firestore.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thống kê',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('invoices').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Không thể tải dữ liệu thống kê.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return _buildStatistics(snapshot.data?.docs ?? []);
        },
      ),
    );
  }
}

class _MonthlyRevenue {
  final int month;
  final int year;
  double revenue;

  _MonthlyRevenue({
    required this.month,
    required this.year,
    required this.revenue,
  });
}

class _InvoiceStat {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _InvoiceStat({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });
}
