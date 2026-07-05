import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _RolePortalPageState extends State<RolePortalPage>
    with SingleTickerProviderStateMixin {
  bool _checkingAuth = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _checkExistingSession();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
          setState(() => _checkingAuth = false);
          _animController.forward();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checkingAuth = false);
        _animController.forward();
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
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SuperAdminDashboardPage()));
        break;
      default:
        setState(() => _checkingAuth = false);
        _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.account_balance_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ──
          CustomPaint(
            size: Size.infinite,
            painter: _NavyPortalPainter(),
          ),

          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 56),

                    // Brand Logo
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Galaxi Gadai',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0F172A),
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sistem Manajemen Gadai Terpadu',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Blue divider accent
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PILIH PORTAL AKSES',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Nasabah ──
                    _ElegantRoleCard(
                      icon: Icons.person_rounded,
                      title: 'Nasabah',
                      subtitle: 'Lihat transaksi & perpanjang tenor',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const NasabahLoginPage(),
                      )),
                    ),
                    const SizedBox(height: 14),

                    // ── Admin Cabang ──
                    _ElegantRoleCard(
                      icon: Icons.manage_accounts_rounded,
                      title: 'Admin Cabang',
                      subtitle: 'Laporan & manajemen cabang',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      iconBg: const Color(0xFFDBEAFE),
                      iconColor: const Color(0xFF1E40AF),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const StaffLoginPage(initialRole: 'admin_cabang'),
                      )),
                    ),
                    const SizedBox(height: 14),

                    // ── Super Admin ──
                    _ElegantRoleCard(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Super Admin',
                      subtitle: 'Kontrol penuh seluruh sistem',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A1628), Color(0xFF102A4C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      iconBg: const Color(0xFFE0E7FF),
                      iconColor: const Color(0xFF312E81),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const StaffLoginPage(initialRole: 'super_admin'),
                      )),
                    ),

                    const SizedBox(height: 48),

                    Text(
                      'v2.3 • Galaxi Gadai © 2026',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ELEGANT ROLE CARD ──
class _ElegantRoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _ElegantRoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_ElegantRoleCard> createState() => _ElegantRoleCardState();
}

class _ElegantRoleCardState extends State<_ElegantRoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E293B).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: widget.iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 26),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── NAVY BACKGROUND PAINTER ──
class _NavyPortalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient background
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

    // ── Top right arc decoration ──
    _drawTopArc(canvas, size);

    // ── Bottom left arc decoration ──
    _drawBottomArc(canvas, size);

    // ── Dot pattern ──
    _drawDotPattern(canvas, size);
  }

  void _drawTopArc(Canvas canvas, Size size) {
    final path1 = Path()
      ..moveTo(size.width * 0.25, 0)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.18, size.width, size.height * 0.10)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      path1,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(Rect.fromLTWH(size.width * 0.25, 0, size.width * 0.75, size.height * 0.18)),
    );

    final path2 = Path()
      ..moveTo(size.width * 0.48, 0)
      ..quadraticBezierTo(size.width * 0.80, size.height * 0.22, size.width, size.height * 0.17)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      path2,
      Paint()
        ..color = const Color(0xFF3B82F6).withValues(alpha: 0.18),
    );
  }

  void _drawBottomArc(Canvas canvas, Size size) {
    final path1 = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.82, size.width * 0.65, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path1,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, size.height * 0.78, size.width * 0.65, size.height * 0.22)),
    );

    final path2 = Path()
      ..moveTo(0, size.height * 0.71)
      ..quadraticBezierTo(size.width * 0.38, size.height * 0.76, size.width * 0.78, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path2,
      Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.12),
    );
  }

  void _drawDotPattern(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.05);
    const spacing = 32.0;
    const radius = 1.6;

    for (double y = spacing; y < size.height - spacing * 2; y += spacing) {
      for (double x = spacing; x < size.width - spacing; x += spacing) {
        // Skip corners where arcs are drawn
        if (y < size.height * 0.25 && x > size.width * 0.4) continue;
        if (y > size.height * 0.65 && x < size.width * 0.45) continue;
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore_for_file: unused_import
// dart:math is used via math.pi etc.
