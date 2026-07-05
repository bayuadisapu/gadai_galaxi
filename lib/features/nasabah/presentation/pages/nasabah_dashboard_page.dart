import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';
import '../widgets/nasabah_home_tab.dart';
import '../widgets/nasabah_riwayat_tab.dart';
import '../widgets/nasabah_kalkulator_tab.dart';
import '../widgets/nasabah_profil_tab.dart';

class NasabahDashboardPage extends StatefulWidget {
  final Customer customer;
  const NasabahDashboardPage({super.key, required this.customer});

  @override
  State<NasabahDashboardPage> createState() => _NasabahDashboardPageState();
}

class _NasabahDashboardPageState extends State<NasabahDashboardPage> {
  int _currentIndex = 0;
  final _svc = SupabaseGadaiService.instance;
  List<PawnTransaction> _txs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final txs = await _svc.fetchTransactions(nasabahId: widget.customer.id);
      if (!mounted) return;
      setState(() { _txs = txs; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Keluar Akun', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin keluar dari akun nasabah?', style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Log aktivitas logout
              await _svc.logNasabahLogout(widget.customer.id, widget.customer.name);
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const RolePortalPage()), (route) => false);
            },
            child: Text('Keluar', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final tabs = ['Beranda', 'Riwayat', 'Kalkulator', 'Profil'];
    final icons = [Icons.home_rounded, Icons.receipt_long_rounded, Icons.calculate_rounded, Icons.person_rounded];

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.royalBlue));
    } else {
      switch (_currentIndex) {
        case 0:
          body = NasabahHomeTab(customer: widget.customer, transactions: _txs, onTabChanged: (i) => setState(() => _currentIndex = i));
          break;
        case 1:
          body = NasabahRiwayatTab(customer: widget.customer, transactions: _txs, onRefresh: _loadData);
          break;
        case 2:
          body = const NasabahKalkulatorTab();
          break;
        case 3:
          body = NasabahProfilTab(customer: widget.customer, onLogout: _logout);
          break;
        default:
          body = NasabahHomeTab(customer: widget.customer, transactions: _txs, onTabChanged: (i) => setState(() => _currentIndex = i));
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Painter
          Positioned.fill(
            child: CustomPaint(
              painter: _NasabahDashboardBackgroundPainter(),
            ),
          ),
          // Content
          Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: 12, left: 20, right: 20),
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Center(
                            child: Text(
                              widget.customer.name.isNotEmpty ? widget.customer.name[0].toUpperCase() : 'N',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halo, ${widget.customer.name.split(' ').first} 👋',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Nasabah Galaxi Gadai',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                        onPressed: _logout,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.royalBlue,
                  onRefresh: _loadData,
                  child: body,
                ),
              ),
              // Floating Bottom Navigation Bar
              Container(
                margin: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                  top: 8,
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(4, (index) {
                    final isSelected = _currentIndex == index;
                    if (isSelected) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icons[index], color: AppColors.royalBlue, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              tabs[index],
                              style: GoogleFonts.inter(
                                color: AppColors.royalBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return GestureDetector(
                      onTap: () => setState(() => _currentIndex = index),
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icons[index], color: const Color(0xFF94A3B8), size: 20),
                            const SizedBox(height: 3),
                            Text(
                              tabs[index],
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── NASABAH DASHBOARD BACKGROUND PAINTER ──
class _NasabahDashboardBackgroundPainter extends CustomPainter {
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

    // Subtle top right decoration arc
    final path = Path()
      ..moveTo(size.width * 0.4, 0)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.12, size.width, size.height * 0.08)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(Rect.fromLTWH(size.width * 0.4, 0, size.width * 0.6, size.height * 0.12)),
    );

    // Dot pattern
    final dotPaint = Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.04);
    const spacing = 28.0;
    for (double y = spacing; y < size.height; y += spacing) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

