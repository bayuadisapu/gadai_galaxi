import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';

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

  // Simulasi harga jual lelang (bisa diganti dari database)
  // Untuk sementara: harga jual = principal + totalFee + margin 10%
  int _hargaJual(PawnTransaction tx) => ((tx.principal + tx.totalFee) * 1.1).round();
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
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _allTxs = txs.where((t) => t.status == 'Terjual').toList()
          ..sort((a, b) => b.dateApplied.compareTo(a.dateApplied));
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
      return Customer(id: '', name: 'Tidak Dikenal', nik: '', phone: '', address: '', birthPlace: '', birthDate: '', gender: '');
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final totalPenjualan = _filtered.fold(0, (s, tx) => s + _hargaJual(tx));
    final totalKeuntungan = _filtered.fold(0, (s, tx) => s + _keuntungan(tx));
    final rataKeuntungan = _filtered.isEmpty ? 0 : (totalKeuntungan / _filtered.length).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // ── HEADER TEAL ─────────────────────────────────
          _buildHeader(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F5A47)))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF0F5A47),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // ── TITLE CARD ─────────────────────────
                          _buildTitleCard(),

                          // ── STATS 2x2 ──────────────────────────
                          _buildStatsCard(
                            barangCount: _filtered.length,
                            totalPenjualan: totalPenjualan,
                            totalKeuntungan: totalKeuntungan,
                            rataKeuntungan: rataKeuntungan,
                          ),

                          // ── SEARCH ─────────────────────────────
                          _buildSearchSection(),

                          // ── TABLE ──────────────────────────────
                          if (_filtered.isEmpty)
                            _buildEmptyState()
                          else
                            _buildTable(),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    final dateStr = '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2A1E), Color(0xFF0F5A47)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('S', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const Expanded(
                child: Column(
                  children: [
                    Text('GALAXI GADAI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(dateStr, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.trending_up_rounded, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Barang Terjual', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              Text('Laporan dan data barang gadai yang telah terjual', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required int barangCount,
    required int totalPenjualan,
    required int totalKeuntungan,
    required int rataKeuntungan,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _statItem('$barangCount', 'Barang Terjual', const Color(0xFF0F5A47)),
              _verticalDivider(),
              _statItem('Rp\n${_fmt(totalPenjualan)}', 'Total Penjualan', const Color(0xFF2563EB)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            children: [
              _statItem('Rp ${_fmt(totalKeuntungan)}', 'Total Keuntungan', const Color(0xFF0F5A47)),
              _verticalDivider(),
              _statItem('Rp ${_fmt(rataKeuntungan)}', 'Rata-rata\nKeuntungan', const Color(0xFF0F5A47)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(color: color, fontSize: 18, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 48, color: const Color(0xFFF1F5F9), margin: const EdgeInsets.symmetric(horizontal: 12));
  }

  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Search field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan nama nasabah, nomor kontrak, atau jenis barang',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              ),
              onSubmitted: (_) => _applySearch(),
            ),
          ),
          const SizedBox(height: 12),
          // Cari button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _applySearch,
              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
              label: Text('Cari', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 900),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF2563EB)),
              headingRowHeight: 48,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 80,
              columnSpacing: 20,
              horizontalMargin: 16,
              dividerThickness: 1,
              columns: [
                _col('No. Kontrak'),
                _col('Nasabah'),
                _col('Barang'),
                _col('Nilai Gadai'),
                _col('Harga Jual'),
                _col('Keuntungan'),
                _col('Tanggal Jual'),
                _col('Profit %'),
              ],
              rows: _filtered.asMap().entries.map((e) {
                final i = e.key;
                final tx = e.value;
                final customer = _getCustomer(tx.customerId);
                final hargaJual = _hargaJual(tx);
                final untung = _keuntungan(tx);
                final profitPct = tx.principal > 0 ? ((untung / tx.principal) * 100).toStringAsFixed(1) : '0.0';
                final isEven = i % 2 == 0;

                return DataRow(
                  color: WidgetStateProperty.all(isEven ? Colors.white : const Color(0xFFF8FAFC)),
                  cells: [
                    // No. Kontrak
                    DataCell(
                      Text(
                        tx.transactionCode.isNotEmpty ? tx.transactionCode : tx.id.substring(0, 10).toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                      ),
                    ),
                    // Nasabah
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(customer.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          Text(customer.phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    // Barang
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(tx.collateralType, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          Text('${tx.brand} ${tx.model}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    // Nilai Gadai
                    DataCell(
                      Text('Rp ${_fmt(tx.principal)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                    ),
                    // Harga Jual
                    DataCell(
                      Text(
                        'Rp ${_fmt(hargaJual)}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F5A47)),
                      ),
                    ),
                    // Keuntungan
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Rp ${_fmt(untung)}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                        ),
                      ),
                    ),
                    // Tanggal Jual
                    DataCell(
                      Text(_fmtDate(tx.dateApplied), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ),
                    // Profit %
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$profitPct%',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _col(String label) {
    return DataColumn(
      label: Text(
        label,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up_outlined, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Belum ada barang terjual', style: GoogleFonts.inter(fontSize: 15, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Data akan muncul setelah proses lelang selesai', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
