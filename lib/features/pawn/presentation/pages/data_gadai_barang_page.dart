import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/transaksi_detail_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/extension_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/redemption_page.dart';

class DataGadaiBarangPage extends StatefulWidget {
  final String branchId;
  final String namaCabang;

  const DataGadaiBarangPage({
    super.key,
    required this.branchId,
    required this.namaCabang,
  });

  @override
  State<DataGadaiBarangPage> createState() => _DataGadaiBarangPageState();
}

class _DataGadaiBarangPageState extends State<DataGadaiBarangPage> {
  final _svc = SupabaseGadaiService.instance;
  final _searchCtrl = TextEditingController();

  List<PawnTransaction> _allTxs = [];
  List<PawnTransaction> _filtered = [];
  List<Customer> _customers = [];
  bool _isLoading = true;
  String _selectedStatus = 'Semua Status';

  static const List<String> _statusOptions = [
    'Semua Status',
    'Aktif',
    'Lunas',
    'Macet',
    'Perlu_Bayar_Jatip',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final txs = await _svc.fetchTransactions(branchId: widget.branchId);
      final customers = await _svc.fetchNasabah(branchId: widget.branchId);
      if (!mounted) return;
      setState(() {
        _allTxs = txs;
        _customers = customers;
        _isLoading = false;
      });
      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _allTxs.where((tx) {
        // Filter status
        final statusMatch = _selectedStatus == 'Semua Status' || tx.status == _selectedStatus;

        // Filter search
        final customer = _customers.firstWhere(
          (c) => c.id == tx.customerId,
          orElse: () => Customer(id: '', name: '', nik: '', phone: '', address: '', birthPlace: '', birthDate: '', gender: ''),
        );
        final searchMatch = query.isEmpty ||
            tx.id.toLowerCase().contains(query) ||
            tx.transactionCode.toLowerCase().contains(query) ||
            tx.brand.toLowerCase().contains(query) ||
            tx.model.toLowerCase().contains(query) ||
            tx.collateralType.toLowerCase().contains(query) ||
            customer.name.toLowerCase().contains(query);

        return statusMatch && searchMatch;
      }).toList();
    });
  }

  String _formatCurrency(int val) {
    final s = val.toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d-$m-${dt.year}';
  }

  String _todayString() {
    final now = DateTime.now();
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    final dayName = days[now.weekday - 1];
    return '$dayName, ${now.day} ${months[now.month]} ${now.year}';
  }

  Customer _getCustomer(String customerId) {
    return _customers.firstWhere(
      (c) => c.id == customerId,
      orElse: () => Customer(id: '', name: 'Tidak Dikenal', nik: '', phone: '', address: '', birthPlace: '', birthDate: '', gender: ''),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Aktif': return const Color(0xFF22C55E);
      case 'Lunas': return const Color(0xFF64748B);
      case 'Macet': return const Color(0xFFEF4444);
      case 'Perlu_Bayar_Jatip': return const Color(0xFFF59E0B);
      default: return const Color(0xFF64748B);
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'Aktif': return const Color(0xFFDCFCE7);
      case 'Lunas': return const Color(0xFFF1F5F9);
      case 'Macet': return const Color(0xFFFEE2E2);
      case 'Perlu_Bayar_Jatip': return const Color(0xFFFEF3C7);
      default: return const Color(0xFFF1F5F9);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Perlu_Bayar_Jatip': return 'Jatuh Tempo';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayString();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // ── Header Teal ──
          _buildHeader(today),

          // ── Search Bar ──
          _buildSearchBar(),

          // ── Filter Status ──
          _buildFilterRow(),

          // ── Content ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F7A6B)))
                : _filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: const Color(0xFF0F7A6B),
                        onRefresh: _loadData,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _buildCard(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String today) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: 20, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D6B5E), Color(0xFF0F8A77), Color(0xFF18A896)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Dot motif decorative
          Positioned.fill(
            child: CustomPaint(painter: _DotPainter()),
          ),
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              // Logo / icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0F7A6B), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'GALAXI GADAI  ',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.namaCabang,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      today,
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Gadai Barang',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari nama, Nomor kontrak, merk, tipe...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) => _applyFilter(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _applyFilter,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F7A6B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Cari',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Text(
            'Status',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecond),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 20),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                    _applyFilter();
                  },
                  items: _statusOptions.map((s) {
                    return DropdownMenuItem<String>(
                      value: s,
                      child: Text(
                        s == 'Perlu_Bayar_Jatip' ? 'Jatuh Tempo' : s,
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _applyFilter,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F7A6B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Terapkan', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionSheet(PawnTransaction tx, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Tombol tutup & Info barang
              Stack(
                children: [
                  // Info barang
                  Row(
                    children: [
                      // Foto barang
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F7F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFB2E4DB)),
                        ),
                        child: const Icon(Icons.phone_android_rounded, color: Color(0xFF0F7A6B), size: 36),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.transactionCode.isNotEmpty ? tx.transactionCode : tx.id.substring(0, 10).toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0D6B5E)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${customer.name} · ${tx.collateralType}',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecond),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency(tx.principal),
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40), // space for close button
                    ],
                  ),
                  // Tombol X tutup
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Tombol aksi: Lihat History
              _actionButton(
                label: 'Lihat History',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TransaksiDetailPage(transaction: tx))).then((_) => _loadData());
                },
              ),
              const SizedBox(height: 10),

              // Detail Gadai
              _actionButton(
                label: 'Detail Gadai',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TransaksiDetailPage(transaction: tx))).then((_) => _loadData());
                },
              ),
              const SizedBox(height: 10),

              // Lihat Perjanjian
              _actionButton(
                label: 'Lihat Perjanjian',
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fitur Perjanjian akan segera hadir'), duration: Duration(seconds: 2)),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Cetak Struk
              _actionButton(
                label: 'Cetak Struk',
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fitur Cetak Struk akan segera hadir'), duration: Duration(seconds: 2)),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Perpanjang — indigo/blue solid
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ExtensionPage(prefilledTxId: tx.id))).then((_) => _loadData());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B5FC7),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Perpanjang', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),

              // Pelunasan — amber/orange gradient
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RedemptionPage(prefilledTxId: tx.id))).then((_) => _loadData());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Pelunasan', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => _loadData());
  }

  Widget _actionButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(PawnTransaction tx) {
    final customer = _getCustomer(tx.customerId);
    final statusColor = _statusColor(tx.status);
    final statusBg = _statusBgColor(tx.status);

    return GestureDetector(
      onTap: () => _showActionSheet(tx, customer),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F7F4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB2E4DB), width: 1),
        ),
        child: Row(
          children: [
            // Foto Barang (placeholder)
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFB2E4DB)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: Color(0xFF0F7A6B),
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info Transaksi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nomor Kontrak
                  Text(
                    tx.transactionCode.isNotEmpty ? tx.transactionCode : tx.id.substring(0, 10).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D6B5E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Nama Nasabah + Jenis Barang
                  Text(
                    '${customer.name} · ${tx.collateralType}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecond),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Nominal + Tanggal Jatuh Tempo
                  Text(
                    '${_formatCurrency(tx.principal)} · ${_formatDate(tx.dateDue)}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Badge Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Text(
                _statusLabel(tx.status),
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Tidak ada transaksi ditemukan',
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Coba ubah filter atau kata kunci pencarian',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// Dot motif painter for header decoration
class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    const spacing = 18.0;
    const radius = 1.8;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
