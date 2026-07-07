import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/new_pawn_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/transaksi_detail_page.dart';
import 'package:galaxi_gadai/features/customer/presentation/pages/customer_search_page.dart';
import 'package:galaxi_gadai/features/dashboard/presentation/widgets/laporan_tab_content.dart';
import 'mutasi_saldo_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/data_gadai_barang_page.dart';
import 'lelang_page.dart';
import 'barang_terjual_page.dart';
import 'history_transaksi_page.dart';
import 'file_pendukung_page.dart';
import 'kas_page.dart';

class AdminCabangDashboardPage extends StatefulWidget {
  final String namaAdmin;
  final String namaCabang;
  final String cabangId;

  const AdminCabangDashboardPage({
    super.key,
    required this.namaAdmin,
    required this.namaCabang,
    required this.cabangId,
  });

  @override
  State<AdminCabangDashboardPage> createState() => _AdminCabangDashboardPageState();
}

class _AdminCabangDashboardPageState extends State<AdminCabangDashboardPage> {
  final _svc = SupabaseGadaiService.instance;
  final _searchController = TextEditingController();

  List<PawnTransaction> _txs = [];
  List<Customer> _customers = [];
  bool _isLoading = true;
  int _walletBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Auto-mark transaksi Aktif yang sudah lewat jatuh tempo → Macet
      await _svc.markOverdueTransactions(branchId: widget.cabangId);

      final txs = await _svc.fetchTransactions(branchId: widget.cabangId);
      final customers = await _svc.fetchNasabah(branchId: widget.cabangId);
      final walletBalance = await _svc.fetchWalletBalance(widget.cabangId);
      if (!mounted) return;
      setState(() {
        _txs = txs;
        _customers = customers;
        _walletBalance = walletBalance;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(int val) {
    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Akun'),
        content: const Text('Yakin ingin keluar dari akun Admin Cabang?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _svc.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RolePortalPage()), (route) => false);
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── WALLET TOPUP DIALOG ──
  void _showTopUpDialog() {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Top Up Saldo Tenant'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nominal TopUp (Rp)',
            border: OutlineInputBorder(),
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final amt = int.tryParse(amountCtrl.text) ?? 0;
              if (amt > 0) {
                Navigator.pop(ctx);
                await _svc.walletTopUp(widget.cabangId, amt, 'Top Up Saldo Tenant');
                await _loadData(); // refresh saldo dari Supabase
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Top Up Rp ${_formatCurrency(amt)} Berhasil!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
  }

  // ── WHATSAPP GROUP DIALOG ──
  void _showWhatsAppDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 24),
            SizedBox(width: 10),
            Text('Gabung Grup Tenant'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gabung ke grup WhatsApp Tenant Galaxi Gadai untuk koordinasi harian dan update info penting.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.qr_code_2_rounded, size: 110, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Scan QR Code untuk Gabung', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Membuka WhatsApp...'), backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
            label: const Text('Buka WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── SEARCH HANDLER ──
  void _handleSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Cari nasabah yang cocok
    final matchingCust = _customers.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();
    
    // Cari transaksi yang cocok
    final matchingTx = _txs.where((t) => t.id.toLowerCase().contains(query.toLowerCase())).toList();

    if (matchingTx.isNotEmpty) {
      // Jika nomor kontrak langsung ketemu
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TransaksiDetailPage(transaction: matchingTx.first)),
      ).then((_) => _loadData());
    } else if (matchingCust.isNotEmpty) {
      // Buka pencarian nasabah yang di-filter
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CustomerSearchPage(isTab: false, branchId: widget.cabangId)),
      ).then((_) => _loadData());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nasabah atau nomor kontrak tidak ditemukan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1628),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final today = DateTime.now();
    // Hitung stats
    final totalGadaiHariIni = _txs
        .where((t) => t.dateApplied.day == today.day && t.dateApplied.month == today.month && t.dateApplied.year == today.year)
        .fold(0, (s, t) => s + t.principal);
    
    final totalTebusHariIni = _txs
        .where((t) => t.status == 'Lunas' && t.dateApplied.day == today.day && t.dateApplied.month == today.month && t.dateApplied.year == today.year)
        .fold(0, (s, t) => s + (t.principal + t.totalFee));

    final totalNasabah = _customers.length;
    final siapLelang = _txs.where((t) => t.status == 'Macet').length;

    // Formatting date: Jumat, 26 Juni 2026
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    final formattedDate = '${days[today.weekday % 7]}, ${today.day} ${months[today.month - 1]} ${today.year}';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Navy Blue Top Panel with Geometric Motif
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 24,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A1628), Color(0xFF102A4C), Color(0xFF1E3A6E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _DashboardDotPainter()),
                  ),
                  Column(
                    children: [
                      // Top Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // S Logo inside rounded rect
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.namaCabang.isNotEmpty ? widget.namaCabang[0].toUpperCase() : 'G',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          // App title & date
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'GALAXI GADAI',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDate,
                                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Stats Panel list (White text stats)
                      _buildTopStatRow(Icons.monetization_on_outlined, 'Gadai Hari ini', 'Rp ${_formatCurrency(totalGadaiHariIni)}'),
                      const SizedBox(height: 12),
                      _buildTopStatRow(Icons.check_circle_outline_rounded, 'Ditebus Hari ini', 'Rp ${_formatCurrency(totalTebusHariIni)}'),
                      const SizedBox(height: 12),
                      _buildTopStatRow(Icons.people_outline_rounded, 'Total Nasabah', '$totalNasabah'),
                      const SizedBox(height: 12),
                      _buildTopStatRow(Icons.gavel_rounded, 'Siap Lelang', '$siapLelang'),
                      const SizedBox(height: 24),

                      // 2. Saldo Tenant Card (Glassmorphic Blue Accent)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wallet_rounded, color: Color(0xFF93C5FD), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Saldo Tenant',
                                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rp ${_formatCurrency(_walletBalance)}',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: _showTopUpDialog,
                                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                    label: Text('TopUp', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                    style: TextButton.styleFrom(
                                      backgroundColor: AppColors.royalBlue,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => MutasiSaldoPage(branchId: widget.cabangId)));
                                    },
                                    icon: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 16),
                                    label: Text('Mutasi', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Search Bar Panel
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A1628).withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Cari nama nasabah atau nomor kontrak...',
                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _handleSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.royalBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: Text('Cari', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Pegadaian Grid Header & Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.balance_rounded, color: AppColors.royalBlue, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Pegadaian',
                        style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 9-Button Grid Layout
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: [
                      _buildGridItem('Gadai', Icons.monetization_on_outlined, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => NewPawnPage(branchId: widget.cabangId))).then((_) => _loadData());
                      }),
                      _buildGridItem('Barang', Icons.inventory_2_outlined, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DataGadaiBarangPage(branchId: widget.cabangId, namaCabang: widget.namaCabang))).then((_) => _loadData());
                      }),
                      _buildGridItem('Nasabah', Icons.people_outline_rounded, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSearchPage(isTab: false, branchId: widget.cabangId)));
                      }),
                      _buildGridItem('Laporan', Icons.analytics_outlined, () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Laporan Cabang'), backgroundColor: const Color(0xFF0F5A47), iconTheme: const IconThemeData(color: Colors.white)),
                            body: LaporanTabContent(branchId: widget.cabangId),
                          ),
                        ));
                      }),
                      _buildGridItem('Uang Kas', Icons.account_balance_wallet_rounded, () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => KasPage(branchId: widget.cabangId, namaCabang: widget.namaCabang),
                        )).then((_) => _loadData());
                      }),
                      _buildGridItem('Lelang', Icons.gavel_rounded, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => LelangPage(branchId: widget.cabangId)));
                      }),
                      _buildGridItem('Barang Terjual', Icons.trending_up_rounded, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => BarangTerjualPage(branchId: widget.cabangId)));
                      }),
                      _buildGridItem('History', Icons.list_alt_rounded, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryTransaksiPage(branchId: widget.cabangId)));
                      }),
                      _buildGridItem('File Pendukung', Icons.folder_open_rounded, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FilePendukungPage(branchId: widget.cabangId)));
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // WhatsApp Group button in its own card
                  GestureDetector(
                    onTap: _showWhatsAppDialog,
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Gabung Group Tenant',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildGridItem(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A1628).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Center(
              child: Icon(icon, color: AppColors.royalBlue, size: 26),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Dot Painter ──
class _DashboardDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.05);
    const spacing = 20.0;
    for (double y = spacing; y < size.height; y += spacing) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

