import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';

class LaporanTabContent extends StatefulWidget {
  final String branchId;
  const LaporanTabContent({super.key, required this.branchId});

  @override
  State<LaporanTabContent> createState() => _LaporanTabContentState();
}

class _LaporanTabContentState extends State<LaporanTabContent> {
  String _selectedRange = 'Bulanan';
  int _selectedMonthIndex = DateTime.now().month - 1;
  int _selectedYear = DateTime.now().year;
  bool _isExporting = false;
  bool _isLoading = true;

  // Data real dari Supabase
  List<PawnTransaction> _allTransactions = [];
  List<PawnTransaction> _filtered = [];

  // Stats yang dihitung dari data real
  int _totalJasaTitip = 0;
  int _totalPokok = 0;
  int _lunasCount = 0;
  int _aktifCount = 0;
  int _macetCount = 0;
  Map<String, int> _jenisCount = {};
  List<int> _weeklyCount = [0, 0, 0, 0, 0];

  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final branchId = widget.branchId == 'all' ? null : widget.branchId;
      final txs = await SupabaseGadaiService.instance.fetchTransactions(branchId: branchId);
      if (!mounted) return;
      _allTransactions = txs;
      _computeStats();
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _computeStats() {
    final m = _selectedMonthIndex + 1;
    final y = _selectedYear;

    _filtered = _allTransactions.where((tx) {
      return tx.dateApplied.year == y && tx.dateApplied.month == m;
    }).toList();

    _totalJasaTitip = _filtered.fold(0, (s, tx) => s + tx.totalFee);
    _totalPokok = _filtered.fold(0, (s, tx) => s + tx.principal);
    _lunasCount = _filtered.where((tx) => tx.status == 'Lunas').length;
    _aktifCount = _filtered.where((tx) => tx.status == 'Aktif').length;
    _macetCount = _filtered.where((tx) => tx.status == 'Macet').length;

    // Distribusi jenis jaminan
    _jenisCount = {};
    for (final tx in _filtered) {
      _jenisCount[tx.collateralType] = (_jenisCount[tx.collateralType] ?? 0) + 1;
    }

    // Tren mingguan (max 5 minggu)
    _weeklyCount = [0, 0, 0, 0, 0];
    for (final tx in _filtered) {
      final week = ((tx.dateApplied.day - 1) / 7).floor().clamp(0, 4);
      _weeklyCount[week]++;
    }
  }

  void _onMonthChanged(int delta) {
    setState(() {
      _selectedMonthIndex += delta;
      if (_selectedMonthIndex < 0) { _selectedMonthIndex = 11; _selectedYear--; }
      if (_selectedMonthIndex > 11) { _selectedMonthIndex = 0; _selectedYear++; }
      _computeStats();
    });
  }

  String _fmtCurrency(int val) {
    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _exportLaporan() async {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final monthLabel = '${_months[_selectedMonthIndex]}_$_selectedYear';
      final fileName = 'laporan_gadai_${monthLabel.toLowerCase()}.csv';

      final buf = StringBuffer();
      buf.writeln('Tanggal,No Kontrak,Kategori,Merk,Model,Pokok,Jasa Titip,Status');

      for (final tx in _filtered) {
        final d = tx.dateApplied;
        final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        buf.writeln(
          '$date,${tx.displayCode},${tx.collateralType},"${tx.brand}","${tx.model}",${tx.principal},${tx.totalFee},${tx.status}',
        );
      }

      if (kIsWeb) {
        // Flutter Web: trigger download via browser
        await _webDownloadCsv(buf.toString(), fileName);
      } else {
        // Mobile/Desktop: simpan ke dokumen lokal
        await _nativeWriteCsv(buf.toString(), fileName);
      }

      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_filtered.length} transaksi diekspor ke $fileName'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ekspor: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Download CSV di browser (Flutter Web) — tampilkan dialog untuk copy-paste
  Future<void> _webDownloadCsv(String content, String fileName) async {
    _showWebExportDialog(content, fileName);
  }

  void _showWebExportDialog(String csvContent, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.download_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Ekspor CSV', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: $fileName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Salin data CSV berikut ke file spreadsheet Anda:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  csvContent,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  /// Simpan CSV ke filesystem lokal (mobile/desktop) — fallback ke dialog
  Future<void> _nativeWriteCsv(String content, String fileName) async {
    // Fallback: tampilkan dialog copy-paste karena path_provider tidak dikonfigurasi
    _showWebExportDialog(content, fileName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header biru
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(color: AppColors.primary),
          padding: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
          child: Column(
            children: [
              // Date switcher
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                      onPressed: () => _onMonthChanged(-1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Text(
                      '${_months[_selectedMonthIndex]} $_selectedYear',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                      onPressed: () => _onMonthChanged(1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Harian', 'Mingguan', 'Bulanan'].map((range) {
                  final isSelected = _selectedRange == range;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRange = range),
                    child: Column(
                      children: [
                        Text(
                          range,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isSelected)
                          Container(width: 56, height: 3, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1.5)))
                        else
                          const SizedBox(height: 3),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tombol Ekspor CSV
                      ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportLaporan,
                        icon: _isExporting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download_rounded, color: Colors.white),
                        label: Text(
                          _isExporting ? 'Mengekspor...' : 'Ekspor Laporan Bulanan (CSV)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Kartu Ringkasan Jasa Titip
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF1D4ED8).withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Jasa Titip Terkumpul', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Text(
                              _filtered.isEmpty ? 'Rp 0' : 'Rp ${_fmtCurrency(_totalJasaTitip)}',
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_filtered.length} Transaksi · Pokok: Rp ${_fmtCurrency(_totalPokok)}',
                              style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildSummaryBadge(const Color(0xFF10B981), '$_lunasCount Lunas'),
                                _buildSummaryBadge(const Color(0xFFF59E0B), '$_aktifCount Aktif'),
                                _buildSummaryBadge(const Color(0xFFEF4444), '$_macetCount Macet'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tren Transaksi (Bar Chart Mingguan)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tren Transaksi per Minggu', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                                Icon(Icons.trending_up_rounded, color: const Color(0xFF1D4ED8).withValues(alpha: 0.8), size: 20),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _filtered.isEmpty
                                ? const Center(child: Text('Belum ada data bulan ini', style: TextStyle(color: AppColors.textMuted)))
                                : _buildBarChart(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Distribusi Jenis Jaminan (real)
                      if (_filtered.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ringkasan Jenis Jaminan', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              ..._buildJenisRows(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Daftar Transaksi Bulan Ini
                      if (_filtered.isNotEmpty) ...[
                        Text(
                          'Transaksi ${_months[_selectedMonthIndex]} $_selectedYear (${_filtered.length})',
                          style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ..._filtered.take(10).map((tx) => _buildTxRow(tx)),
                        if (_filtered.length > 10)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: Text('+${_filtered.length - 10} transaksi lainnya (ekspor CSV untuk lihat semua)',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                const Icon(Icons.inbox_rounded, color: AppColors.textMuted, size: 48),
                                const SizedBox(height: 12),
                                Text('Tidak ada transaksi di ${_months[_selectedMonthIndex]} $_selectedYear',
                                    style: const TextStyle(color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildJenisRows() {
    final total = _filtered.length;
    if (total == 0) return [];

    final jenisColors = {
      'Barang': const Color(0xFF1E3A8A),
      'Emas': const Color(0xFFF59E0B),
      'Motor / Mobil': const Color(0xFF10B981),
      'Handphone': const Color(0xFF1D4ED8),
    };

    final sorted = _jenisCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final rows = <Widget>[];

    for (int i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      final pct = e.value / total;
      final color = jenisColors[e.key] ?? const Color(0xFF94A3B8);
      if (i > 0) rows.add(const SizedBox(height: 16));
      rows.add(_buildProgressRow(e.key, pct, '${(pct * 100).round()}% (${e.value})', color));
    }
    return rows;
  }

  Widget _buildTxRow(PawnTransaction tx) {
    Color statusColor;
    if (tx.status == 'Lunas') statusColor = const Color(0xFF10B981);
    else if (tx.status == 'Macet') statusColor = const Color(0xFFEF4444);
    else statusColor = AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.displayCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                Text('${tx.brand} ${tx.model}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rp ${_fmtCurrency(tx.principal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(tx.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final maxVal = _weeklyCount.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) {
        final val = _weeklyCount[i];
        final height = maxVal > 0 ? (val / maxVal * 100).clamp(8.0, 100.0) : 8.0;
        final isHighest = val == maxVal && val > 0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (val > 0) Text('$val', style: TextStyle(color: isHighest ? const Color(0xFF1E3A8A) : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold))
            else const SizedBox(height: 14),
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: height,
              decoration: BoxDecoration(
                color: isHighest ? const Color(0xFF1E3A8A) : const Color(0xFF94A3B8).withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Mg ${i + 1}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        );
      }),
    );
  }

  Widget _buildSummaryBadge(Color dotColor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double value, String percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(percentage, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: const Color(0xFFEFF6FF),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
