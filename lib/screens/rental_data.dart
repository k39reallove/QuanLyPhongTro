
import 'package:flutter/foundation.dart';

class RentalData {
  RentalData._();

  static final List<dynamic> rooms = [];
  static final List<dynamic> tenants = [];

  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static bool initialized = false;

  static void initialize({
    required List<dynamic> initialRooms,
  }) {
    if (initialized) return;

    rooms.addAll(initialRooms);
    initialized = true;
    notify();
  }

  static void notify() {
    version.value++;
  }

  static dynamic findRoom(String roomId) {
    for (final room in rooms) {
      if (room.id.toString() == roomId) {
        return room;
      }
    }
    return null;
  }

  static dynamic findTenant(String tenantId) {
    for (final tenant in tenants) {
      if (tenant.id.toString() == tenantId) {
        return tenant;
      }
    }
    return null;
  }

  static dynamic activeTenantOfRoom(String roomId) {
    for (final tenant in tenants) {
      if (tenant.roomId.toString() == roomId &&
          tenant.isActive == true) {
        return tenant;
      }
    }
    return null;
  }

  static bool isRoomAssigned(
    String roomId, {
    String? exceptTenantId,
  }) {
    return tenants.any(
      (tenant) =>
          tenant.roomId.toString() == roomId &&
          tenant.isActive == true &&
          tenant.id.toString() != exceptTenantId,
    );
  }

  static bool assignTenant({
    required dynamic tenant,
    required String roomId,
  }) {
    final room = findRoom(roomId);

    if (room == null) return false;

    if (room.status.toString().contains('maintenance')) {
      return false;
    }

    if (isRoomAssigned(
      roomId,
      exceptTenantId: tenant.id.toString(),
    )) {
      return false;
    }

    tenant.roomId = roomId;
    tenant.roomName = room.name;
    tenant.rent = (room.price as num).toDouble();
    tenant.isActive = true;

    final existingIndex = tenants.indexWhere(
      (item) => item.id.toString() == tenant.id.toString(),
    );

    if (existingIndex >= 0) {
      tenants[existingIndex] = tenant;
    } else {
      tenants.add(tenant);
    }

    room.rentStartDate = tenant.startDate;
    room.rentEndDate = tenant.endDate;

    notify();
    return true;
  }

  static void terminateTenant(dynamic tenant) {
    tenant.isActive = false;

    final room = findRoom(tenant.roomId.toString());

    if (room != null) {
      room.rentStartDate = null;
      room.rentEndDate = null;
    }

    notify();
  }

  static bool removeTenantPermanently(dynamic tenant) {
    if (tenant.isActive == true) {
      return false;
    }

    tenants.removeWhere(
      (item) => item.id.toString() == tenant.id.toString(),
    );

    notify();
    return true;
  }
}
