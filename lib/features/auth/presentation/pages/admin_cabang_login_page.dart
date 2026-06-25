import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/features/admin_cabang/presentation/pages/admin_cabang_dashboard_page.dart';

class AdminCabangLoginPage extends StatefulWidget {
  const AdminCabangLoginPage({super.key});

  @override
  State<AdminCabangLoginPage> createState() => _AdminCabangLoginPageState();
}

class _AdminCabangLoginPageState extends State<AdminCabangLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Mock accounts admin cabang
  static const _mockAccounts = {
    'admin.surabaya@galaxi.id': {'password': 'admin123', 'cabang': 'Cabang Surabaya Pusat', 'nama': 'Eko Prasetyo'},
    'admin.sidoarjo@galaxi.id': {'password': 'admin123', 'cabang': 'Cabang Sidoarjo', 'nama': 'Dewi Lestari'},
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isLoading = false);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final account = _mockAccounts[email];

    if (account != null && account['password'] == password) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminCabangDashboardPage(
            namaAdmin: account['nama']!,
            namaCabang: account['cabang']!,
          ),
        ),
      );
    } else {
      // Demo mode
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminCabangDashboardPage(
            namaAdmin: 'Eko Prasetyo',
            namaCabang: 'Cabang Surabaya Pusat',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Header Amber
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 36,
                        bottom: 36,
                        left: 24,
                        right: 24,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
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
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 14),
                          const Text('Login Admin Cabang', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Akses laporan & manajemen cabang Anda', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                        ],
                      ),
                    ),

                    // Form Card
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Email Admin'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDecoration('admin@galaxi.id', Icons.alternate_email_rounded),
                                style: const TextStyle(color: AppColors.textDark, fontSize: 15),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Email tidak boleh kosong' : null,
                              ),
                              const SizedBox(height: 20),
                              _buildLabel('Kata Sandi'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: _inputDecoration('••••••••', Icons.lock_outline_rounded).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted, size: 20),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                style: const TextStyle(color: AppColors.textDark, fontSize: 15),
                                validator: (v) => v == null || v.isEmpty ? 'Kata sandi tidak boleh kosong' : null,
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Masuk', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Demo info
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFED7AA)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: Color(0xFFF97316), size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Demo: Tekan "Masuk" untuk masuk sebagai Admin Cabang Surabaya Pusat.',
                                        style: TextStyle(color: Color(0xFFC2410C), fontSize: 12),
                                      ),
                                    ),
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

  Widget _buildLabel(String text) =>
      Text(text, style: const TextStyle(color: AppColors.textInputLabel, fontSize: 14, fontWeight: FontWeight.w600));

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 15),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 22),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
      );
}
