import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/transaksi_detail_page.dart';
import 'package:galaxi_gadai/features/admin_cabang/presentation/pages/barang_terjual_page.dart';

class LelangPage extends StatefulWidget {
  final String branchId;
  const LelangPage({super.key, required this.branchId});

  @override
  State<LelangPage> createState() => _LelangPageState();
}

class _LelangPageState extends State<LelangPage> {
  final _svc = SupabaseGadaiService.instance;
  final _searchCtrl = TextEditingController();

  List<PawnTransaction> _allTxs = [];
  List<PawnTransaction> _filtered = [];
  List<Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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
        _customers = customers;
        // Barang lelang: Macet atau Perlu_Bayar_Jatip yang sudah lewat >= 5 hari
        _allTxs = txs.where((t) {
          if (t.status == 'Macet') return true;
          if (t.status == 'Perlu_Bayar_Jatip') {
            final overdue = DateTime.now().difference(t.dateDue).inDays;
            return overdue >= 5;
          }
          return false;
        }).toList()
          ..sort((a, b) => a.dateDue.compareTo(b.dateDue));
        _filtered = List.from(_allTxs);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_allTxs);
      } else {
        _filtered = _allTxs.where((tx) {
          final c = _getCustomer(tx.customerId);
          return tx.transactionCode.toLowerCase().contains(q) ||
              tx.collateralType.toLowerCase().contains(q) ||
              tx.brand.toLowerCase().contains(q) ||
              tx.model.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Customer _getCustomer(String customerId) {
    try {
      return _customers.firstWhere((c) => c.id == customerId);
    } catch (_) {
      return Customer(id: '', name: 'Tidak Dikenal', nik: '', phone: '', address: '', birthPlace: '', birthDate: '', gender: '');
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

  String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day.toString().padLeft(2, '0')}/${months[d.month - 1]}/${d.year}';
  }

  int _overdayCount(DateTime dateDue) {
    return max(0, DateTime.now().difference(dateDue).inDays);
  }

  void _processLelang(PawnTransaction tx) {
    final priceCtrl = TextEditingController(text: (tx.principal + tx.totalFee).toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.gavel_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Proses Lelang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${tx.brand} ${tx.model}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Pinjaman Pokok: Rp ${_formatCurrency(tx.principal)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Harga Jual Lelang (Rp)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () async {
              final price = int.tryParse(priceCtrl.text) ?? 0;
              if (price <= 0) return;
              try {
                await _svc.updateTransactionStatus(tx.id, 'Terjual');
                await _svc.walletTopUp(widget.branchId, price, 'Hasil Lelang ${tx.brand} ${tx.model}');
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Berhasil dilelang Rp ${_formatCurrency(price)}. Saldo Tenant bertambah!'),
                  backgroundColor: Colors.green,
                ));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Konfirmasi Jual', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalNilai = _filtered.fold(0, (s, tx) => s + tx.principal);
    final pageCount = (_filtered.length / 10).ceil();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ─── HEADER ───────────────────────────────────────────
          _buildHeader(),

          // ─── BODY ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF2563EB),
                    child: CustomScrollView(
                      slivers: [
                        // Info banner
                        SliverToBoxAdapter(child: _buildInfoBanner()),

                        // Stats row
                        SliverToBoxAdapter(
                          child: _buildStatsRow(
                            barangCount: _filtered.length,
                            totalNilai: totalNilai,
                            pageCount: pageCount,
                          ),
                        ),

                        // Search
                        SliverToBoxAdapter(child: _buildSearchBar()),

                        // Grid or empty
                        if (_filtered.isEmpty)
                          const SliverFillRemaining(child: _EmptyState())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.52,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _buildCard(_filtered[i]),
                                childCount: _filtered.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF93C5FD),
      ),
      child: Stack(
        children: [
          // Dot motif
          Positioned.fill(child: CustomPaint(painter: _LelangDotPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1628).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0A1628), size: 20),
                        ),
                      ),
                      const Spacer(),
                      // Tombol Riwayat
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BarangTerjualPage(branchId: widget.branchId))).then((_) => _loadData()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1628).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF0A1628).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.history_rounded, color: Color(0xFF0A1628), size: 13),
                              const SizedBox(width: 4),
                              Text('Riwayat', style: GoogleFonts.inter(color: Color(0xFF0A1628), fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.gavel_rounded, color: Color(0xFFB91C1C), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '${_filtered.length} Barang',
                              style: GoogleFonts.inter(color: Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('🔨', style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lelang Barang Gadai',
                              style: GoogleFonts.poppins(color: const Color(0xFF0A1628), fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kelola dan jual barang gadai yang sudah masa lelang',
                              style: GoogleFonts.poppins(color: const Color(0xFF0A1628).withValues(alpha: 0.7), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Barang akan masuk masa lelang setelah 5 hari dari tanggal jatuh tempo',
              style: GoogleFonts.inter(color: const Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({required int barangCount, required int totalNilai, required int pageCount}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          _statChip(
            label: 'Barang',
            value: '$barangCount',
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _statChip(
              label: 'Nilai',
              value: 'Rp ${_formatCurrency(totalNilai)}',
              icon: Icons.monetization_on_outlined,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 10),
          _statChip(
            label: 'Halaman',
            value: '$pageCount',
            icon: Icons.pages_outlined,
            color: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  Widget _statChip({required String label, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 5),
            Text(
              value,
              style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
              ),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari berdasarkan nomor kontrak, jenis barang, merk, tipe',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onSubmitted: (_) => _applySearch(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _applySearch,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('🔍 Cari', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(PawnTransaction tx) {
    final customer = _getCustomer(tx.customerId);
    final overdays = _overdayCount(tx.dateDue);
    final masaLelang = max(0, 30 - overdays);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Foto + badge ──────────────────────────────
            Stack(
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  color: const Color(0xFFEFF6FF),
                  child: Icon(
                    _itemIcon(tx.collateralType),
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    size: 56,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Siap Lelang', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),

            // ── Info barang ────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.collateralType.toLowerCase(),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    Text(
                      '${tx.brand} ${tx.model}',
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecond),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(customer.name, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(customer.phone, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),

                    const SizedBox(height: 6),
                    // Lewat X hari
                    if (overdays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 10),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'Lewat $overdays hari dari jatuh tempo',
                                style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.w600),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 6),
                    // Detail rows
                    _detailRow('Kondisi', tx.condition.isNotEmpty ? tx.condition : 'Baik'),
                    _detailRow('Jatuh Tempo', _formatDate(tx.dateDue)),
                    _detailRow('Masa Lelang', '$masaLelang hari'),

                    const SizedBox(height: 6),
                    // Nilai gadai box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nilai Gadai', style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontSize: 9, fontWeight: FontWeight.w500)),
                          Text(
                            'Rp\n${_formatCurrency(tx.principal)}',
                            style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w800, height: 1.2),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),
                    // Nomor kontrak
                    Text(
                      tx.transactionCode.isNotEmpty ? tx.transactionCode : tx.id.substring(0, 12).toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted),
                    ),

                    const SizedBox(height: 8),
                    // Action buttons
                    Row(
                      children: [
                        // Detail button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransaksiDetailPage(transaction: tx))).then((_) => _loadData()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Center(child: Icon(Icons.description_outlined, size: 14, color: Color(0xFF475569))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Jual button
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () => _processLelang(tx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text('🔨 Jual', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text('$label: ', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  IconData _itemIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('laptop') || t.contains('komputer')) return Icons.laptop_rounded;
    if (t.contains('kamera')) return Icons.camera_alt_rounded;
    if (t.contains('jam')) return Icons.watch_rounded;
    if (t.contains('emas') || t.contains('perhiasan')) return Icons.diamond_outlined;
    return Icons.phone_android_rounded;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gavel_rounded, size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Tidak ada barang siap lelang', style: GoogleFonts.inter(fontSize: 15, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Barang macet > 5 hari dari jatuh tempo\nakan muncul di sini', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class _LelangDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    const spacing = 20.0;
    const radius = 2.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
