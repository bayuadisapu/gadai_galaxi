import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/services/laporan_pdf_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  String _selectedStatusFilter = 'Semua';
  String _selectedBranchFilter = 'all';

  // Data real dari Supabase
  List<PawnTransaction> _allTransactions = [];
  List<PawnTransaction> _filtered = [];
  List<Cabang> _branches = [];
  final Map<String, String> _custNames = {};
  final Map<String, String> _branchNames = {};

  // Stats yang dihitung dari data real
  int _totalJasaTitip = 0;
  int _totalPokok = 0;
  int _lunasCount = 0;
  int _aktifCount = 0;
  int _macetCount = 0;
  int _lelangCount = 0;
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
      final svc = SupabaseGadaiService.instance;
      final branches = await svc.fetchBranches();
      _branches = branches;
      _branchNames.clear();
      for (final b in branches) {
        _branchNames[b.id] = b.nama;
      }

      final customers = await svc.fetchNasabah();
      _custNames.clear();
      for (final c in customers) {
        _custNames[c.id] = c.name;
      }

      final txs = await svc.fetchTransactions();
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

    var list = _allTransactions;
    if (widget.branchId != 'all') {
      list = list.where((tx) => tx.cabangId == widget.branchId).toList();
    } else if (_selectedBranchFilter != 'all') {
      list = list.where((tx) => tx.cabangId == _selectedBranchFilter).toList();
    }

    final monthlyList = list.where((tx) {
      return tx.dateApplied.year == y && tx.dateApplied.month == m;
    }).toList();

    if (_selectedStatusFilter == 'Lelang') {
      _filtered = monthlyList.where((tx) => tx.status == 'Lelang' || tx.status == 'Terjual').toList();
    } else if (_selectedStatusFilter != 'Semua') {
      _filtered = monthlyList.where((tx) => tx.status == _selectedStatusFilter).toList();
    } else {
      _filtered = monthlyList;
    }

    _totalJasaTitip = _filtered.fold(0, (s, tx) => s + tx.totalFee);
    _totalPokok = _filtered.fold(0, (s, tx) => s + tx.principal);

    _lunasCount = monthlyList.where((tx) => tx.status == 'Lunas').length;
    _aktifCount = monthlyList.where((tx) => tx.status == 'Aktif').length;
    _macetCount = monthlyList.where((tx) => tx.status == 'Macet').length;
    _lelangCount = monthlyList.where((tx) => tx.status == 'Lelang' || tx.status == 'Terjual').length;

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

  Future<void> _exportPdf() async {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor ke PDF'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final monthLabel = '${_months[_selectedMonthIndex]} $_selectedYear';
      String branchTitle = widget.branchId != 'all'
          ? (_branchNames[widget.branchId] ?? widget.branchId)
          : (_selectedBranchFilter == 'all' ? 'Semua Cabang' : (_branchNames[_selectedBranchFilter] ?? _selectedBranchFilter));

      final pdfFile = await LaporanPdfService.instance.generateLaporanPdf(
        title: 'Laporan Transaksi Gadai',
        periodeLabel: monthLabel,
        namaCabang: branchTitle,
        statusFilter: _selectedStatusFilter,
        transactions: _filtered,
        customerNames: _custNames,
        branchNames: _branchNames,
      );

      if (!mounted) return;
      setState(() => _isExporting = false);

      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF Laporan berhasil dibuat!'), backgroundColor: Colors.green),
        );
      } else {
        await Share.shareXFiles(
          [XFile(pdfFile.path, mimeType: 'application/pdf')],
          text: 'Laporan Gadai PDF - $monthLabel ($branchTitle)',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ekspor PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportExcel() async {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor ke Excel'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final monthLabel = '${_months[_selectedMonthIndex]}_$_selectedYear';
      final statusSuffix = _selectedStatusFilter == 'Semua' ? '' : '_${_selectedStatusFilter.toLowerCase()}';
      final fileName = 'laporan_gadai_${monthLabel.toLowerCase()}$statusSuffix.csv';

      final buf = StringBuffer();
      buf.writeln('No,Tanggal,No Kontrak,Cabang,Nasabah,Kategori,Merk,Model,Pokok,Jasa Titip,Jatuh Tempo,Status');

      for (int i = 0; i < _filtered.length; i++) {
        final tx = _filtered[i];
        final d = tx.dateApplied;
        final due = tx.dateDue;
        final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final dueStr = '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
        final custName = _custNames[tx.customerId] ?? '-';
        final branchName = _branchNames[tx.cabangId] ?? tx.cabangId;

        buf.writeln(
          '${i + 1},$dateStr,${tx.displayCode},"$branchName","$custName",${tx.collateralType},"${tx.brand}","${tx.model}",${tx.principal},${tx.totalFee},$dueStr,${tx.status}',
        );
      }

      if (kIsWeb) {
        _showWebExportDialog(buf.toString(), fileName);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(buf.toString());
        await Share.shareXFiles([XFile(file.path)], text: 'Laporan Gadai Excel/CSV - $fileName');
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
        SnackBar(content: Text('Gagal ekspor Excel: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showWebExportDialog(String csvContent, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.download_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Ekspor Excel (CSV)', style: TextStyle(fontSize: 16)),
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
                padding: const EdgeInsets.all(10),
                child: SelectableText(csvContent, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header navy gradient
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF93C5FD),
          ),
          padding: const EdgeInsets.only(bottom: 24, left: 20, right: 20, top: 12),
          child: Column(
            children: [
              // Date switcher
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0A1628).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF0A1628), size: 20),
                      onPressed: () => _onMonthChanged(-1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Text(
                      '${_months[_selectedMonthIndex]} $_selectedYear',
                      style: const TextStyle(color: Color(0xFF0A1628), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0A1628), size: 20),
                      onPressed: () => _onMonthChanged(1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                            color: isSelected ? const Color(0xFF0A1628) : const Color(0xFF0A1628).withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isSelected)
                          Container(width: 56, height: 3, decoration: BoxDecoration(color: const Color(0xFF0A1628), borderRadius: BorderRadius.circular(1.5)))
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
                      // Filter Cabang (jika Super Admin / branchId == 'all')
                      if (widget.branchId == 'all') ...[
                        const Text(
                          'Filter Cabang',
                          style: TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildBranchChip('all', 'Semua Cabang'),
                              ..._branches.map((b) => _buildBranchChip(b.id, b.nama)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Filter Status Laporan
                      const Text(
                        'Kategori Laporan Status',
                        style: TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Semua', 'Aktif', 'Menunggu Pengambilan', 'Sudah Diambil', 'Lunas', 'Macet', 'Lelang', 'Terjual'].map((s) {
                            final active = _selectedStatusFilter == s;
                            Color chipColor;
                            switch (s) {
                              case 'Aktif': chipColor = AppColors.primary; break;
                              case 'Menunggu Pengambilan': chipColor = const Color(0xFF059669); break;
                              case 'Sudah Diambil': chipColor = const Color(0xFF0D9488); break;
                              case 'Lunas': chipColor = const Color(0xFF10B981); break;
                              case 'Macet': chipColor = const Color(0xFFEF4444); break;
                              case 'Lelang': chipColor = const Color(0xFF8B5CF6); break;
                              case 'Terjual': chipColor = const Color(0xFFD97706); break;
                              default: chipColor = const Color(0xFF64748B);
                            }
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedStatusFilter = s;
                                  _computeStats();
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: active ? chipColor : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: active ? chipColor : const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    color: active ? Colors.white : const Color(0xFF475569),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tombol Ekspor PDF & Excel
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _exportPdf,
                              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
                              label: const Text('Export PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _exportExcel,
                              icon: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 18),
                              label: const Text('Export Excel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Metric Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard('Total Jasa Titip', 'Rp ${_fmtCurrency(_totalJasaTitip)}', const Color(0xFF10B981), Icons.payments_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard('Total Pokok Gadai', 'Rp ${_fmtCurrency(_totalPokok)}', AppColors.primary, Icons.account_balance_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status Distribution Row
                      Row(
                        children: [
                          Expanded(child: _buildMiniStat('Lunas', '$_lunasCount', const Color(0xFF10B981))),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMiniStat('Aktif', '$_aktifCount', AppColors.primary)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMiniStat('Macet', '$_macetCount', const Color(0xFFEF4444))),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMiniStat('Lelang', '$_lelangCount', const Color(0xFF8B5CF6))),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tren Mingguan
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
                            const Text('Tren Transaksi Mingguan', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            SizedBox(height: 140, child: _buildBarChart()),
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
                          'Transaksi ${_selectedStatusFilter == 'Semua' ? '' : '($_selectedStatusFilter) '}${_months[_selectedMonthIndex]} $_selectedYear (${_filtered.length})',
                          style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ..._filtered.take(15).map((tx) => _buildTxRow(tx)),
                        if (_filtered.length > 15)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: Text('+${_filtered.length - 15} transaksi lainnya (ekspor PDF/Excel untuk lihat semua)',
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

  Widget _buildBranchChip(String id, String name) {
    final active = _selectedBranchFilter == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBranchFilter = id;
          _computeStats();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E3A6E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFF1E3A6E) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color col, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: col, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 10),
          Text(val, style: TextStyle(color: col, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
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
    else if (tx.status == 'Lelang' || tx.status == 'Terjual') statusColor = const Color(0xFF8B5CF6);
    else statusColor = AppColors.primary;

    final custName = _custNames[tx.customerId] ?? '';
    final branchName = _branchNames[tx.cabangId] ?? tx.cabangId;

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
                Row(
                  children: [
                    Text(tx.displayCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                      child: Text(branchName, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${tx.brand} ${tx.model}${custName.isNotEmpty ? " • $custName" : ""}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
