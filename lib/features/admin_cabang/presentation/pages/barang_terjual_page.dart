import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';

class BarangTerjualPage extends StatefulWidget {
  final String branchId;
  const BarangTerjualPage({super.key, required this.branchId});

  @override
  State<BarangTerjualPage> createState() => _BarangTerjualPageState();
}

class _BarangTerjualPageState extends State<BarangTerjualPage> {
  final _svc = SupabaseGadaiService.instance;
  final _searchCtrl = TextEditingController();

  List<PawnTransaction> _allTxs = [];
  List<PawnTransaction> _filtered = [];
  List<Customer> _customers = [];
  bool _isLoading = true;
  Map<String, int> _actualPrices = {};

  int _hargaJual(PawnTransaction tx) =>
      _actualPrices[tx.id] ?? ((tx.principal + tx.totalFee) * 1.1).round();
  int _keuntungan(PawnTransaction tx) => _hargaJual(tx) - tx.principal;

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
      final lelangHistory = await _svc.fetchLelangHistory();

      final Map<String, int> actualPrices = {};
      for (final h in lelangHistory) {
        actualPrices[h.transactionId] = h.hargaLelang;
      }

      if (!mounted) return;
      setState(() {
        _customers = customers;
        _actualPrices = actualPrices;
        _allTxs = txs
            .where((t) => t.status == 'Lelang' || t.status == 'Terjual')
            .toList()
          ..sort((a, b) => b.dateApplied.compareTo(a.dateApplied));
        _filtered = List.from(_allTxs);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applySearch(String q) {
    q = q.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_allTxs);
      } else {
        _filtered = _allTxs.where((tx) {
          final c = _getCustomer(tx.customerId);
          return tx.transactionCode.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q) ||
              tx.collateralType.toLowerCase().contains(q) ||
              tx.brand.toLowerCase().contains(q) ||
              tx.model.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Customer _getCustomer(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return Customer(
          id: '',
          name: 'Tidak Dikenal',
          nik: '',
          phone: '',
          address: '',
          birthPlace: '',
          birthDate: '',
          gender: '');
    }
  }

  String _fmt(int val) {
    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _fmtDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  IconData _itemIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('laptop') || t.contains('komputer')) return Icons.laptop_rounded;
    if (t.contains('kamera')) return Icons.camera_alt_rounded;
    if (t.contains('jam')) return Icons.watch_rounded;
    if (t.contains('emas') || t.contains('perhiasan')) return Icons.diamond_outlined;
    return Icons.phone_android_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final totalPenjualan = _filtered.fold(0, (s, tx) => s + _hargaJual(tx));
    final totalKeuntungan = _filtered.fold(0, (s, tx) => s + _keuntungan(tx));

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Column(
        children: [
          _buildHeader(totalPenjualan, totalKeuntungan),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF059669)))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF059669),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildSearchBar()),
                        if (_filtered.isEmpty)
                          const SliverFillRemaining(child: _EmptyState())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _buildCard(_filtered[i], i),
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

  Widget _buildHeader(int totalPenjualan, int totalKeuntungan) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Subtle dot pattern
          Positioned.fill(child: CustomPaint(painter: _DotPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '${_filtered.length} Item',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.trending_up_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Barang Terjual',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Riwayat hasil lelang barang gadai',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          label: 'Total Penjualan',
                          value: 'Rp ${_fmt(totalPenjualan)}',
                          icon: Icons.payments_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          label: 'Total Keuntungan',
                          value: 'Rp ${_fmt(_filtered.fold(0, (s, tx) => s + _keuntungan(tx)))}',
                          icon: Icons.show_chart_rounded,
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

  Widget _statCard({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10)),
                Text(value,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          style: GoogleFonts.inter(fontSize: 13),
          onChanged: _applySearch,
          decoration: InputDecoration(
            hintText: 'Cari nasabah, barang, nomor kontrak...',
            hintStyle: GoogleFonts.inter(
                fontSize: 12, color: const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0xFF059669), size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        color: Color(0xFF94A3B8), size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _applySearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(PawnTransaction tx, int index) {
    final customer = _getCustomer(tx.customerId);
    final hargaJual = _hargaJual(tx);
    final untung = _keuntungan(tx);
    final profitPct = tx.principal > 0
        ? ((untung / tx.principal) * 100).toStringAsFixed(1)
        : '0.0';
    final profitPositif = untung >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top accent bar
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: icon + item info + profit badge
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_itemIcon(tx.collateralType),
                            color: const Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tx.brand} ${tx.model}',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              tx.collateralType,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: profitPositif
                                ? [const Color(0xFF059669), const Color(0xFF10B981)]
                                : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$profitPct%',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nasabah info
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          customer.name,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.phone_outlined,
                          size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        customer.phone,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Divider
                  Container(height: 1, color: const Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // Price info row
                  Row(
                    children: [
                      Expanded(
                          child: _priceItem(
                              'Nilai Gadai',
                              'Rp ${_fmt(tx.principal)}',
                              const Color(0xFF64748B))),
                      Container(
                          width: 1,
                          height: 36,
                          color: const Color(0xFFF1F5F9)),
                      Expanded(
                          child: _priceItem(
                              'Harga Jual',
                              'Rp ${_fmt(hargaJual)}',
                              const Color(0xFF2563EB))),
                      Container(
                          width: 1,
                          height: 36,
                          color: const Color(0xFFF1F5F9)),
                      Expanded(
                          child: _priceItem(
                              'Keuntungan',
                              '${profitPositif ? '+' : ''}Rp ${_fmt(untung)}',
                              profitPositif
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Footer: kontrak + tanggal
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          tx.transactionCode.isNotEmpty
                              ? tx.transactionCode
                              : tx.id.substring(0, 10).toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569)),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.calendar_today_rounded,
                          size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        _fmtDate(tx.dateApplied),
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
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
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.trending_up_outlined,
                size: 44, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum Ada Barang Terjual',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            'Barang yang sudah dilelang\nakan muncul di sini',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    const spacing = 22.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
