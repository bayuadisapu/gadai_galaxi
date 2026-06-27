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
        backgroundColor: Color(0xFF071120),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF071120), Color(0xFF0D1F45), Color(0xFF1953A6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 44),

                // Brand
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Galaxi Gadai',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sistem Manajemen Gadai Terpadu',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
                ),

                const SizedBox(height: 40),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Silakan pilih akses Anda',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3),
                  ),
                ),
                const SizedBox(height: 12),

                // Nasabah
                _RoleCard(
                  icon: Icons.person_rounded,
                  title: 'Nasabah',
                  subtitle: 'Lihat transaksi & perpanjang tenor',
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const NasabahLoginPage(),
                  )),
                ),
                const SizedBox(height: 10),

                // Admin Cabang
                _RoleCard(
                  icon: Icons.manage_accounts_rounded,
                  title: 'Admin Cabang',
                  subtitle: 'Laporan & manajemen cabang',
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const StaffLoginPage(initialRole: 'admin_cabang'),
                  )),
                ),
                const SizedBox(height: 10),

                // Super Admin
                _RoleCard(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Super Admin',
                  subtitle: 'Kontrol penuh seluruh sistem',
                  color: const Color(0xFFEF4444),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const StaffLoginPage(initialRole: 'super_admin'),
                  )),
                ),

                const Spacer(),

                Text(
                  'v2.3 • Galaxi Gadai © 2026',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
                ),
                const SizedBox(height: 20),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }
}
