import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/admin_cabang/presentation/pages/admin_cabang_dashboard_page.dart';
import 'package:galaxi_gadai/features/super_admin/presentation/pages/super_admin_dashboard_page.dart';
import 'package:galaxi_gadai/features/nasabah/presentation/pages/nasabah_dashboard_page.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';

class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage> {
  @override
  void initState() {
    super.initState();
    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    final minDelayFuture = Future.delayed(const Duration(milliseconds: 2000));
    final authResultFuture = _determineNextRoute();

    final results = await Future.wait([minDelayFuture, authResultFuture]);
    final Widget destination = results[1] as Widget;

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }

  Future<Widget> _determineNextRoute() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final svc = SupabaseGadaiService.instance;

      final staff = await svc.getCurrentStaff();
      if (staff != null) {
        final role = staff['role']!;
        final branchId = staff['cabangId'] ?? 'all';

        String branchName = '';
        if (role != 'super_admin' && branchId != 'all') {
          try {
            branchName = await svc.getBranchName(branchId);
          } catch (_) {
            branchName = branchId;
          }
        }

        if (role == 'admin_cabang') {
          return AdminCabangDashboardPage(
            namaAdmin: staff['nama'] ?? 'Admin',
            namaCabang: branchName,
            cabangId: branchId,
          );
        } else if (role == 'super_admin') {
          return const SuperAdminDashboardPage();
        }
      }

      final nasabah = await svc.getCurrentNasabah();
      if (nasabah != null) {
        return NasabahDashboardPage(customer: nasabah);
      }
    } catch (e) {
      debugPrint('Error checking auth in splash: $e');
    }

    return const RolePortalPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Brand Logo (Bulat) ──
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.royalBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'GALAXI GADAI',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sistem Manajemen Gadai',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Simple & Clean Footer ──
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'powered by',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RYNZ DIGITAL CREATIVE',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
