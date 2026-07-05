import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/dashboard/presentation/pages/branch_dashboard_page.dart';
import 'package:galaxi_gadai/features/admin_cabang/presentation/pages/admin_cabang_dashboard_page.dart';
import 'package:galaxi_gadai/features/super_admin/presentation/pages/super_admin_dashboard_page.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/staff_login_page.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/nasabah_login_page.dart';

class RolePortalPage extends StatefulWidget {
  const RolePortalPage({super.key});

  @override
  State<RolePortalPage> createState() => _RolePortalPageState();
}

class _RolePortalPageState extends State<RolePortalPage> {
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final svc = SupabaseGadaiService.instance;
      final staff = await svc.getCurrentStaff();
      if (staff != null) {
        final role = staff['role']!;
        final branchId = staff['cabangId']!;
        final branchName = await svc.getBranchName(branchId);
        if (!mounted) return;
        _navigateByRole(role, staff, branchName);
      } else {
        if (mounted) {
          setState(() {
            _checkingAuth = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingAuth = false;
        });
      }
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
      default:
        setState(() {
          _checkingAuth = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1953A6)),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomPaint(
        painter: _ElegantMotifPainter(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 48),

                // Brand Logo
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1953A6).withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Color(0xFF1953A6),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Galaxi Gadai',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sistem Manajemen Gadai Terpadu',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 48),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'SILAKAN PILIH AKSES ANDA',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nasabah Card
                _RoleCard(
                  icon: Icons.person_rounded,
                  title: 'Nasabah',
                  subtitle: 'Lihat transaksi & perpanjang tenor',
                  color: const Color(0xFF1953A6),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const NasabahLoginPage(),
                  )),
                ),
                const SizedBox(height: 14),

                // Admin Cabang Card
                _RoleCard(
                  icon: Icons.manage_accounts_rounded,
                  title: 'Admin Cabang',
                  subtitle: 'Laporan & manajemen cabang',
                  color: const Color(0xFF0369A1),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const StaffLoginPage(initialRole: 'admin_cabang'),
                  )),
                ),
                const SizedBox(height: 14),

                // Super Admin Card
                _RoleCard(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Super Admin',
                  subtitle: 'Kontrol penuh seluruh sistem',
                  color: const Color(0xFF0F172A),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const StaffLoginPage(initialRole: 'super_admin'),
                  )),
                ),

                const Spacer(),

                const Text(
                  'v2.3 • Galaxi Gadai © 2026',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color.withValues(alpha: 0.4),
              size: 16,
            ),
          ],
        ),
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

    // Top Right Abstract Shapes
    final topPath = Path();
    topPath.moveTo(size.width * 0.3, 0);
    topPath.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.2,
      size.width,
      size.height * 0.12,
    );
    topPath.lineTo(size.width, 0);
    topPath.close();

    final topPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1953A6), Color(0xFF3B82F6)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Offset(size.width * 0.3, 0) & Size(size.width * 0.7, size.height * 0.2));
    canvas.drawPath(topPath, topPaint);

    final topPath2 = Path();
    topPath2.moveTo(size.width * 0.5, 0);
    topPath2.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.24,
      size.width,
      size.height * 0.18,
    );
    topPath2.lineTo(size.width, 0);
    topPath2.close();

    final topPaint2 = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF60A5FA).withValues(alpha: 0.25),
          const Color(0xFF3B82F6).withValues(alpha: 0.25),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Offset(size.width * 0.5, 0) & Size(size.width * 0.5, size.height * 0.24));
    canvas.drawPath(topPath2, topPaint2);

    // Bottom Left Abstract Shapes
    final bottomPath = Path();
    bottomPath.moveTo(0, size.height * 0.75);
    bottomPath.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.78,
      size.width * 0.7,
      size.height,
    );
    bottomPath.lineTo(0, size.height);
    bottomPath.close();

    final bottomPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF1953A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset(0, size.height * 0.75) & Size(size.width * 0.7, size.height * 0.25));
    canvas.drawPath(bottomPath, bottomPaint);

    final bottomPath2 = Path();
    bottomPath2.moveTo(0, size.height * 0.68);
    bottomPath2.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.72,
      size.width * 0.82,
      size.height,
    );
    bottomPath2.lineTo(0, size.height);
    bottomPath2.close();

    final bottomPaint2 = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF3B82F6).withValues(alpha: 0.2),
          const Color(0xFF60A5FA).withValues(alpha: 0.2),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset(0, size.height * 0.68) & Size(size.width * 0.82, size.height * 0.32));
    canvas.drawPath(bottomPath2, bottomPaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

