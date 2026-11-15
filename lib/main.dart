import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/tenants_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/electricity_water_screen.dart';
import 'screens/contracts_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/payment_proof_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const RoomRentalApp());
}

class RoomRentalApp extends StatelessWidget {
  const RoomRentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản lý phòng trọ',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2459A9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/manager': (context) =>
            const RoleGate(requiredRole: 'manager'),
        '/tenant': (context) =>
            const RoleGate(requiredRole: 'tenant'),
      },
    );
  }
}

// ============================================================
// KIỂM TRA ĐĂNG NHẬP
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        return UserAccessGate(user: user);
      },
    );
  }
}

// ============================================================
// KIỂM TRA QUYỀN TRUY CẬP
// ============================================================

class UserAccessGate extends StatelessWidget {
  final User user;

  const UserAccessGate({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasError) {
          return AccessDeniedScreen(
            message: 'Không thể kiểm tra quyền truy cập: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const AccessDeniedScreen(
            message: 'Không tìm thấy thông tin tài khoản.',
          );
        }

        final data = snapshot.data!.data() ?? {};

        final role = (data['role'] ?? '')
            .toString()
            .toLowerCase();

        final isActive = data['isActive'] == true;

        if (!isActive) {
          return const AccessDeniedScreen(
            message: 'Tài khoản của bạn đã bị vô hiệu hóa.',
          );
        }

        if (role == 'manager') {
          return const RoleGate(requiredRole: 'manager');
        }

        if (role == 'tenant') {
          return const RoleGate(requiredRole: 'tenant');
        }

        return const AccessDeniedScreen(
          message: 'Vai trò tài khoản không hợp lệ.',
        );
      },
    );
  }
}

// ============================================================
// ROLE GATE
// ============================================================

class RoleGate extends StatelessWidget {
  final String? requiredRole;

  const RoleGate({
    super.key,
    this.requiredRole,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasError) {
          return AccessDeniedScreen(
            message: 'Lỗi kiểm tra quyền: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const AccessDeniedScreen(
            message: 'Không tìm thấy thông tin tài khoản.',
          );
        }

        final data = snapshot.data!.data() ?? {};

        final role = (data['role'] ?? '')
            .toString()
            .toLowerCase();

        final isActive = data['isActive'] == true;

        if (!isActive) {
          return const AccessDeniedScreen(
            message: 'Tài khoản đã bị vô hiệu hóa.',
          );
        }

        if (role == 'manager') {
          if (requiredRole != null && requiredRole != 'manager') {
            return const AccessDeniedScreen(
              message: 'Bạn không có quyền truy cập khu vực này.',
            );
          }

          return const DashboardScreen();
        }

        if (role == 'tenant') {
          if (requiredRole != null && requiredRole != 'tenant') {
            return const AccessDeniedScreen(
              message: 'Bạn không có quyền truy cập khu vực này.',
            );
          }

          return const TenantHomeScreen();
        }

        return const AccessDeniedScreen(
          message: 'Vai trò tài khoản không hợp lệ.',
        );
      },
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F7FB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF2459A9),
            ),
            SizedBox(height: 16),
            Text('Đang kiểm tra tài khoản...'),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TỪ CHỐI TRUY CẬP
// ============================================================

class AccessDeniedScreen extends StatelessWidget {
  final String message;

  const AccessDeniedScreen({
    super.key,
    required this.message,
  });

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: Colors.red,
                    size: 55,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Không thể truy cập',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DASHBOARD QUẢN LÝ
// ============================================================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const List<Map<String, dynamic>> modules = [
    {
      'title': 'Quản lý phòng',
      'icon': Icons.apartment,
      'color': Color(0xFF2459A9),
    },
    {
      'title': 'Thành viên',
      'icon': Icons.people_alt_outlined,
      'color': Color(0xFF16866D),
    },
    {
      'title': 'Hợp đồng',
      'icon': Icons.description_outlined,
      'color': Color(0xFF8B5CF6),
    },
    {
      'title': 'Điện nước',
      'icon': Icons.electric_bolt_outlined,
      'color': Color(0xFFE69A18),
    },
    {
      'title': 'Hóa đơn',
      'icon': Icons.receipt_long_outlined,
      'color': Color(0xFFDB5A42),
    },
    {
      'title': 'Thanh toán',
      'icon': Icons.account_balance_wallet_outlined,
      'color': Color(0xFF16866D),
    },
    {
      'title': 'Tin nhắn',
      'icon': Icons.chat_bubble_outline,
      'color': Color(0xFF3978D4),
    },
    {
      'title': 'Chứng từ thanh toán',
      'icon': Icons.receipt_long,
      'color': Color(0xFF0F9D78),
    },
  ];

  void _openModule(BuildContext context, String title) {
    Widget? screen;

    switch (title) {
      case 'Quản lý phòng':
        screen = const RoomsScreen();
        break;

      case 'Thành viên':
        screen = const TenantsScreen();
        break;

      case 'Hợp đồng':
        screen = const ContractsScreen();
        break;

      case 'Hóa đơn':
        screen = const InvoicesScreen();
        break;

      case 'Điện nước':
        screen = const ElectricityWaterScreen();
        break;

      case 'Thanh toán':
        screen = const PaymentsScreen();
        break;

      case 'Tin nhắn':
        screen = const MessagesScreen();
        break;

      case 'Chứng từ thanh toán':
        screen = const PaymentProofDemoScreen();
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tìm thấy chức năng "$title".'),
          ),
        );
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen!,
      ),
    );
  }

  Future<void> _handleAccountAction(
    BuildContext context,
    String action,
  ) async {
    if (action == 'logout') {
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        await FirebaseAuth.instance.signOut();

        if (!context.mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Quản lý phòng trọ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            onSelected: (value) => _handleAccountAction(
              context,
              value,
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: CircleAvatar(
                backgroundColor: Color(0xFFE8EFFB),
                child: Icon(
                  Icons.person,
                  color: Color(0xFF2459A9),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xin chào, người quản lý!',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D2939),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tổng quan hoạt động nhà trọ của bạn',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 22),
            _buildSummary(context),
            const SizedBox(height: 28),
            const Text(
              'Chức năng quản lý',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: modules.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.35,
              ),
              itemBuilder: (context, index) {
                final module = modules[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openModule(
                    context,
                    module['title'] as String,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE7EAF0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          module['icon'] as IconData,
                          color: module['color'] as Color,
                          size: 32,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          module['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .snapshots(),
      builder: (context, roomSnapshot) {
        final roomCount = roomSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('tenants')
              .snapshots(),
          builder: (context, tenantSnapshot) {
            final tenantCount =
                tenantSnapshot.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('invoices')
                  .snapshots(),
              builder: (context, invoiceSnapshot) {
                final invoiceCount =
                    invoiceSnapshot.data?.docs.length ?? 0;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    SummaryCard(
                      title: 'Tổng số phòng',
                      value: roomSnapshot.hasError
                          ? '--'
                          : roomCount.toString(),
                      icon: Icons.apartment,
                    ),
                    SummaryCard(
                      title: 'Người thuê',
                      value: tenantSnapshot.hasError
                          ? '--'
                          : tenantCount.toString(),
                      icon: Icons.people_alt_outlined,
                    ),
                    SummaryCard(
                      title: 'Hóa đơn',
                      value: invoiceSnapshot.hasError
                          ? '--'
                          : invoiceCount.toString(),
                      icon: Icons.receipt_long,
                    ),
                    SummaryCard(
                      title: 'Tổng thu',
                      value: invoiceSnapshot.hasError
                          ? '--'
                          : _calculateTotal(invoiceSnapshot.data?.docs ?? []),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String _calculateTotal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double total = 0;

    for (final doc in docs) {
      final data = doc.data();
      final amount = data['paidAmount'];

      if (amount is num) {
        total += amount.toDouble();
      }
    }

    return '${total.toStringAsFixed(0)} đ';
  }
}

// ============================================================
// KHU VỰC NGƯỜI THUÊ
// ============================================================

class TenantHomeScreen extends StatelessWidget {
  const TenantHomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  void _openMessages(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MessagesScreen(),
      ),
    );
  }

  void _openPaymentProof(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PaymentProofDemoScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khu vực người thuê'),
        actions: [
          IconButton(
            tooltip: 'Đổi mật khẩu',
            onPressed: () => _changePassword(context),
            icon: const Icon(Icons.lock_reset),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person,
                size: 64,
                color: Color(0xFF2459A9),
              ),
              const SizedBox(height: 12),
              const Text(
                'Xin chào chủ Phòng',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(user?.email ?? ''),
              const SizedBox(height: 24),
              SizedBox(
                width: 260,
                child: FilledButton.icon(
                  onPressed: () => _openMessages(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Tin nhắn với quản lý'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: FilledButton.icon(
                  onPressed: () => _openPaymentProof(context),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Gửi chứng từ thanh toán'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  onPressed: () => _changePassword(context),
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Đổi mật khẩu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ĐỔI MẬT KHẨU
// ============================================================

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState
    extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mật khẩu hiện tại không chính xác.';
      case 'weak-password':
        return 'Mật khẩu mới quá yếu.';
      case 'requires-recent-login':
        return 'Vui lòng đăng nhập lại trước khi đổi mật khẩu.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'network-request-failed':
        return 'Không có kết nối mạng.';
      case 'too-many-requests':
        return 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.';
      default:
        return e.message ?? 'Không thể đổi mật khẩu.';
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      _showMessage('Không tìm thấy tài khoản đăng nhập.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage(_getFirebaseErrorMessage(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Có lỗi xảy ra: $e');
      }
    }
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        enabled: !_isLoading,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            onPressed: _isLoading ? null : onToggle,
            icon: Icon(
              obscureText
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(
            Icons.lock_reset,
            color: Color(0xFF2459A9),
          ),
          SizedBox(width: 10),
          Expanded(child: Text('Đổi mật khẩu')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vui lòng nhập mật khẩu hiện tại và tạo mật khẩu mới.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                _passwordField(
                  label: 'Mật khẩu hiện tại',
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  onToggle: () {
                    setState(() {
                      _obscureCurrent = !_obscureCurrent;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu hiện tại.';
                    }
                    return null;
                  },
                ),
                _passwordField(
                  label: 'Mật khẩu mới',
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  onToggle: () {
                    setState(() {
                      _obscureNew = !_obscureNew;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu mới.';
                    }

                    if (value.length < 6) {
                      return 'Mật khẩu phải có ít nhất 6 ký tự.';
                    }

                    if (value == _currentPasswordController.text) {
                      return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
                    }

                    return null;
                  },
                ),
                _passwordField(
                  label: 'Xác nhận mật khẩu mới',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  onToggle: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng xác nhận mật khẩu mới.';
                    }

                    if (value != _newPasswordController.text) {
                      return 'Mật khẩu xác nhận không khớp.';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Cập nhật'),
        ),
      ],
    );
  }
}

// ============================================================
// SUMMARY CARD
// ============================================================

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE7EAF0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF2459A9),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}