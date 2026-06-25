import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/features/dashboard/presentation/pages/branch_dashboard_page.dart';
import 'package:galaxi_gadai/features/admin_cabang/presentation/pages/admin_cabang_dashboard_page.dart';
import 'package:galaxi_gadai/features/super_admin/presentation/pages/super_admin_dashboard_page.dart';

/// Mock accounts untuk semua role staff.
/// Key: email, Value: {password, role, nama, cabang?}
const _mockStaffAccounts = {
  // Verifikator / Toko
  'verif@galaxi.id':     {'password': '1234', 'role': 'verifikator',   'nama': 'Budi Santoso',    'cabang': 'Surabaya Pusat'},
  'toko@galaxi.id':      {'password': '1234', 'role': 'verifikator',   'nama': 'Sari Indah',      'cabang': 'Sidoarjo'},
  // Admin Cabang
  'admin.surabaya@galaxi.id': {'password': 'admin123', 'role': 'admin_cabang', 'nama': 'Eko Prasetyo', 'cabang': 'Cabang Surabaya Pusat'},
  'admin.sidoarjo@galaxi.id': {'password': 'admin123', 'role': 'admin_cabang', 'nama': 'Dewi Lestari',  'cabang': 'Cabang Sidoarjo'},
  // Super Admin
  'superadmin@galaxi.id':{'password': 'super123', 'role': 'super_admin',   'nama': 'Super Admin HQ'},
};

class StaffLoginPage extends StatefulWidget {
  final String initialRole;
  const StaffLoginPage({super.key, this.initialRole = 'verifikator'});

  @override
  State<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isLoading = false);

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final account = _mockStaffAccounts[email];

    if (account == null || account['password'] != password) {
      // Demo mode — detect role dari keyword email
      _navigateByRole(email.contains('super') ? 'super_admin' : email.contains('admin') ? 'admin_cabang' : 'verifikator', {
        'nama': 'Demo User',
        'cabang': 'Cabang Demo',
      });
      return;
    }

    _navigateByRole(account['role']!, account);
  }

  void _navigateByRole(String role, Map<String, dynamic> account) {
    switch (role) {
      case 'verifikator':
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BranchDashboardPage()));
        break;
      case 'admin_cabang':
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => AdminCabangDashboardPage(
            namaAdmin: account['nama'] as String? ?? 'Admin Cabang',
            namaCabang: account['cabang'] as String? ?? '-',
          ),
        ));
        break;
      case 'super_admin':
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SuperAdminDashboardPage()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // ── Header ──
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 16,
                        bottom: 36,
                        left: 24,
                        right: 24,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0A1628), Color(0xFF1953A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.initialRole == 'super_admin'
                                  ? Icons.admin_panel_settings_rounded
                                  : widget.initialRole == 'admin_cabang'
                                      ? Icons.manage_accounts_rounded
                                      : Icons.storefront_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.initialRole == 'super_admin'
                                ? 'Login Super Admin'
                                : widget.initialRole == 'admin_cabang'
                                    ? 'Login Admin Cabang'
                                    : 'Login Verifikator / Toko',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Masukkan email & kata sandi akun Anda',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    // ── Form ──
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Email'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: AppColors.textDark, fontSize: 15),
                                decoration: _inputDeco('contoh@galaxi.id', Icons.alternate_email_rounded),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Email wajib diisi' : null,
                                onChanged: (_) => setState(() => _errorMessage = null),
                              ),
                              const SizedBox(height: 20),
                              _label('Kata Sandi'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: AppColors.textDark, fontSize: 15),
                                decoration: _inputDeco('••••••••', Icons.lock_outline_rounded).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: AppColors.textMuted, size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Kata sandi wajib diisi' : null,
                                onChanged: (_) => setState(() => _errorMessage = null),
                              ),

                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12))),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Masuk', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Info akun demo
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 15),
                                        SizedBox(width: 6),
                                        Text('Akun Demo', style: TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _demoRow(Icons.storefront_rounded, 'Verifikator', 'verif@galaxi.id', '1234'),
                                    const SizedBox(height: 6),
                                    _demoRow(Icons.manage_accounts_rounded, 'Admin Cabang', 'admin.surabaya@galaxi.id', 'admin123'),
                                    const SizedBox(height: 6),
                                    _demoRow(Icons.admin_panel_settings_rounded, 'Super Admin', 'superadmin@galaxi.id', 'super123'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(color: AppColors.textInputLabel, fontSize: 14, fontWeight: FontWeight.w600));

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 15),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 22),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
      );

  Widget _demoRow(IconData icon, String role, String email, String pass) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text('$role: ', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Expanded(
          child: Text('$email / $pass', style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
