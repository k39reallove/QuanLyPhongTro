
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class TenantAccountService {
  static const String _secondaryAppName = 'TenantAccountApp';
  static const String _usersCollection = 'users';

  /// Tạo Firebase App phụ để đăng ký tài khoản người thuê.
  /// Việc này giúp không đăng xuất tài khoản quản lý đang sử dụng.
  static Future<FirebaseApp> _getSecondaryApp() async {
    try {
      return Firebase.app(_secondaryAppName);
    } catch (_) {
      return Firebase.initializeApp(
        name: _secondaryAppName,
        options: Firebase.app().options,
      );
    }
  }

  /// Tạo tài khoản đăng nhập cho người thuê.
  ///
  /// Trả về Firebase UID để tenants_screen.dart lưu vào firebaseUid.
  static Future<String> createTenantAccount({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String roomId,
    required String roomName,
    required String tenantId,
  }) async {
    final FirebaseApp secondaryApp = await _getSecondaryApp();

    final FirebaseAuth secondaryAuth =
        FirebaseAuth.instanceFor(app: secondaryApp);

    User? createdUser;

    try {
      final UserCredential credential =
          await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception('Không thể tạo tài khoản người thuê.');
      }

      await createdUser.updateDisplayName(name.trim());

      await FirebaseFirestore.instance
          .collection(_usersCollection)
          .doc(createdUser.uid)
          .set({
        'uid': createdUser.uid,
        'email': email.trim(),
        'name': name.trim(),
        'phone': phone.trim(),
        'role': 'tenant',
        'isActive': true,
        'roomId': roomId,
        'roomName': roomName,
        'tenantId': tenantId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return createdUser.uid;
    } catch (e) {
      // Nếu lưu thông tin Firestore thất bại,
      // xóa tài khoản vừa tạo để tránh tài khoản rác.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          // Giữ lại lỗi ban đầu để hiển thị cho người dùng.
        }
      }

      rethrow;
    } finally {
      await secondaryAuth.signOut();
    }
  }

  /// Cập nhật trạng thái tài khoản người thuê.
  ///
  /// isActive = true  : Mở tài khoản.
  /// isActive = false : Khóa tài khoản.
  static Future<void> updateTenantStatus({
    required String uid,
    required bool isActive,
  }) async {
    final String userId = uid.trim();

    if (userId.isEmpty) {
      throw Exception('Không tìm thấy UID của người thuê.');
    }

    await FirebaseFirestore.instance
        .collection(_usersCollection)
        .doc(userId)
        .set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
