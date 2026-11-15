class UtilityRecord {
  final String room;
  final int month;
  final int year;

  final int oldElectricReading;
  final int newElectricReading;
  final int oldWaterReading;
  final int newWaterReading;

  final int electricUsed;
  final int waterUsed;
  final int electricPrice;
  final int waterPrice;
  final int electricTotal;
  final int waterTotal;

  UtilityRecord({
    required this.room,
    required this.month,
    required this.year,
    required this.oldElectricReading,
    required this.newElectricReading,
    required this.oldWaterReading,
    required this.newWaterReading,
    required this.electricUsed,
    required this.waterUsed,
    required this.electricPrice,
    required this.waterPrice,
    required this.electricTotal,
    required this.waterTotal,
  });

  int get total => electricTotal + waterTotal;

  String get period =>
      '${month.toString().padLeft(2, '0')}/$year';
}

class UtilityData {
  UtilityData._();

  static final List<UtilityRecord> records = [];

  static UtilityRecord? find(String room, int month, int year) {
    for (final record in records) {
      if (record.room.trim().toUpperCase() == room.trim().toUpperCase() &&
          record.month == month &&
          record.year == year) {
        return record;
      }
    }
    return null;
  }

  static void save(UtilityRecord record) {
    final index = records.indexWhere(
      (item) =>
          item.room.trim().toUpperCase() ==
              record.room.trim().toUpperCase() &&
          item.month == record.month &&
          item.year == record.year,
    );

    if (index >= 0) {
      records[index] = record;
    } else {
      records.insert(0, record);
    }
  }

  static void delete(UtilityRecord record) {
    records.removeWhere(
      (item) =>
          item.room.trim().toUpperCase() ==
              record.room.trim().toUpperCase() &&
          item.month == record.month &&
          item.year == record.year,
    );
  }
}