import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/dashboard/presentation/pages/branch_dashboard_page.dart';
import 'package:galaxi_gadai/features/admin_cabang/presentation/pages/admin_cabang_dashboard_page.dart';
import 'package:galaxi_gadai/features/super_admin/presentation/pages/super_admin_dashboard_page.dart';

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

  final _svc = SupabaseGadaiService.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() => _errorMessage = null);
    
    final username = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final account = await _svc.loginStaff(username, password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (account == null) {
        setState(() => _errorMessage = 'Username atau kata sandi salah');
        return;
      }

      // Pastikan role akun sesuai dengan portal yang dipilih
      final accountRole = account['role']!;
      if (accountRole != widget.initialRole) {
        setState(() => _errorMessage = 'Akun ini bukan untuk role ${_roleLabel(widget.initialRole)}');
        return;
      }

      // Get branch name
      final branchName = await _svc.getBranchName(account['cabangId']!);

      if (!mounted) return;
      _navigateByRole(accountRole, account, branchName);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      });
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin_cabang': return 'Admin Cabang';
      case 'super_admin': return 'Super Admin';
      default: return 'Verifikator';
    }
  }

  void _navigateByRole(String role, Map<String, String> account, String branchName) {
    switch (role) {
      case 'verifikator':
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => BranchDashboardPage(cabangId: account['cabangId']!),
        ));
        break;
      case 'admin_cabang':
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => AdminCabangDashboardPage(
            namaAdmin: account['nama']!,
            namaCabang: branchName,
            cabangId: account['cabangId']!,
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
      body: CustomPaint(
        painter: _ElegantMotifPainter(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          // Back Button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1953A6), size: 20),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Login Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E293B).withValues(alpha: 0.04),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1953A6).withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        widget.initialRole == 'super_admin'
                                            ? Icons.admin_panel_settings_rounded
                                            : widget.initialRole == 'admin_cabang'
                                                ? Icons.manage_accounts_rounded
                                                : Icons.storefront_rounded,
                                        color: const Color(0xFF1953A6),
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Center(
                                    child: Text(
                                      'Login ${_roleLabel(widget.initialRole)}',
                                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Center(
                                    child: Text(
                                      'Masukkan username dan password Anda',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  if (_errorMessage != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  const Text('Username', style: TextStyle(color: Color(0xFF334155), fontSize: 14, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.text,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                                    decoration: _inputDecoration('Username Anda', Icons.person_outline_rounded),
                                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Username wajib diisi' : null,
                                    onChanged: (_) => setState(() => _errorMessage = null),
                                  ),
                                  const SizedBox(height: 20),

                                  const Text('Password', style: TextStyle(color: Color(0xFF334155), fontSize: 14, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                                    decoration: _inputDecoration('••••••••', Icons.lock_outline_rounded).copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: const Color(0xFF64748B),
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    validator: (val) => (val == null || val.isEmpty) ? 'Password wajib diisi' : null,
                                    onChanged: (_) => setState(() => _errorMessage = null),
                                  ),
                                  const SizedBox(height: 32),

                                  // Login Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1953A6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                          : const Text('Masuk', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1953A6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }
}

// ── CUSTOM BACKGROUND PAINTER ──
class _ElegantMotifPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Gradient Background (White to soft blue)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF8FAFC),
          Color(0xFFF1F5F9),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Subtle Grid Pattern
    final gridPaint = Paint()
      ..color = const Color(0xFF1953A6).withValues(alpha: 0.02)
      ..strokeWidth = 1.0;
    
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Top Right Abstract Waves
    final topPath = Path();
    topPath.moveTo(size.width * 0.4, 0);
    topPath.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.18,
      size.width,
      size.height * 0.1,
    );
    topPath.lineTo(size.width, 0);
    topPath.close();

    final topPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1953A6), Color(0xFF3B82F6)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Offset(size.width * 0.4, 0) & Size(size.width * 0.6, size.height * 0.18));
    canvas.drawPath(topPath, topPaint);

    // Bottom Left Abstract Waves
    final bottomPath = Path();
    bottomPath.moveTo(0, size.height * 0.8);
    bottomPath.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.82,
      size.width * 0.6,
      size.height,
    );
    bottomPath.lineTo(0, size.height);
    bottomPath.close();

    final bottomPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF1953A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset(0, size.height * 0.8) & Size(size.width * 0.6, size.height * 0.2));
    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

