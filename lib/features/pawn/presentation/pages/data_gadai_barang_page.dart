import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/extension_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/redemption_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/riwayat_transaksi_gadai_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/perjanjian_gadai_page.dart';
import 'package:galaxi_gadai/core/services/gadai_thermal_print_service.dart';
import 'package:galaxi_gadai/core/widgets/gadai_print_settings_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
    'Menunggu Pengambilan',
    'Sudah Diambil',
    'Lunas',
    'Macet',
    'Lelang',
    'Terjual',
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
      case 'Menunggu Pengambilan': return const Color(0xFF059669);
      case 'Perlu_Bayar_Jatip': return const Color(0xFFF59E0B);
      default: return const Color(0xFF64748B);
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'Aktif': return const Color(0xFFDCFCE7);
      case 'Lunas': return const Color(0xFFF1F5F9);
      case 'Macet': return const Color(0xFFFEE2E2);
      case 'Menunggu Pengambilan': return const Color(0xFFD1FAE5);
      case 'Perlu_Bayar_Jatip': return const Color(0xFFFEF3C7);
      default: return const Color(0xFFF1F5F9);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Perlu_Bayar_Jatip': return 'Jatuh Tempo';
      case 'Menunggu Pengambilan': return 'Siap Diambil';
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: const Color(0xFF2563EB),
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
        color: Color(0xFF93C5FD),
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
                    color: const Color(0xFF0A1628).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0A1628), size: 20),
                ),
              ),
              // Logo / icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 26),
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
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF0A1628),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1628).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.namaCabang,
                            style: GoogleFonts.poppins(color: const Color(0xFF0A1628), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      today,
                      style: GoogleFonts.inter(color: const Color(0xFF0A1628).withValues(alpha: 0.8), fontSize: 12),
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
                    color: const Color(0xFF2563EB),
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
                    if (val != null) {
                      setState(() {
                        _selectedStatus = val;
                        _applyFilter();
                      });
                    }
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
                color: const Color(0xFF2563EB),
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
        return _DetailGadaiSheet(
          tx: tx,
          customer: customer,
          onRefresh: _loadData,
        );
      },
    ).then((_) => _loadData());
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
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
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
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Icon(
                  tx.collateralType == 'Emas'
                      ? Icons.workspace_premium_outlined
                      : tx.collateralType == 'Motor / Mobil'
                          ? Icons.two_wheeler_rounded
                          : Icons.phone_android_rounded,
                  color: const Color(0xFF2563EB),
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
                      color: const Color(0xFF0F172A),
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

class _DetailGadaiSheet extends StatefulWidget {
  final PawnTransaction tx;
  final Customer customer;
  final VoidCallback onRefresh;

  const _DetailGadaiSheet({
    required this.tx,
    required this.customer,
    required this.onRefresh,
  });

  @override
  State<_DetailGadaiSheet> createState() => _DetailGadaiSheetState();
}

class _DetailGadaiSheetState extends State<_DetailGadaiSheet> {
  // ── Foto dikelompokkan: nasabah/ dan barang/ ──
  Map<String, String> _photos = {
    'barang'         : '', // barang/utama.jpg
    'barangTambahan' : '', // barang/tambahan.jpg
    'ktp'            : '', // nasabah/ktp.jpg
    'nasabah'        : '', // nasabah/foto_diri.jpg
  };
  String _petugasName = 'Adit';
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadSheetData();
  }

  Future<void> _loadSheetData() async {
    try {
      final client = Supabase.instance.client;

      // ── Ambil URL foto langsung dari kolom database ──
      // Lebih andal daripada listing bucket karena tidak bergantung
      // pada nama file dan sudah merefleksikan struktur subfolder terbaru.
      final rows = await client
          .from('gadai_transactions')
          .select('foto_barang_url, foto_ktp_url, foto_nasabah_barang_url, foto_barang_gadai_url')
          .eq('id', widget.tx.id)
          .limit(1);

      String barangUrl          = '';
      String barangTambahanUrl  = '';
      String ktpUrl             = '';
      String nasabahUrl         = '';

      if (rows.isNotEmpty) {
        final row = rows.first;
        barangUrl         = row['foto_barang_url']         as String? ?? '';
        ktpUrl            = row['foto_ktp_url']            as String? ?? '';
        nasabahUrl        = row['foto_nasabah_barang_url'] as String? ?? '';
        barangTambahanUrl = row['foto_barang_gadai_url']   as String? ?? '';
      }

      // ── Ambil nama petugas dari activity log ──
      String fetchedPetugas = 'Petugas';
      try {
        final logs = await SupabaseGadaiService.instance
            .fetchActivityLogsByTransaction(widget.tx.id);
        if (logs.isNotEmpty) {
          final createLog = logs.firstWhere(
            (log) => log['action'] == 'TRANSAKSI_CREATED',
            orElse: () => logs.last,
          );
          final userVal = createLog['user_id'] as String?;
          if (userVal != null && userVal.isNotEmpty) {
            fetchedPetugas = userVal;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _photos = {
            'barang'         : barangUrl,
            'barangTambahan' : barangTambahanUrl,
            'ktp'            : ktpUrl,
            'nasabah'        : nasabahUrl,
          };
          _petugasName = fetchedPetugas;
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingData = false);
      }
    }
  }

  Future<void> _downloadFile(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto belum diunggah untuk transaksi ini'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final uri = Uri.parse(url);
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = await launchUrl(uri);
      }
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka foto di browser'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh foto: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _doPrintStruk(PawnTransaction tx, Customer customer) async {
    final printSvc = GadaiThermalPrintService.instance;
    final isConnected = await printSvc.ensureConnected();
    if (!mounted) return;

    if (!isConnected) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.print_disabled_rounded, color: Color(0xFF94A3B8), size: 22),
              SizedBox(width: 8),
              Text('Printer Belum Terhubung',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Printer thermal belum terhubung. Buka pengaturan untuk menghubungkan printer Bluetooth terlebih dahulu.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GadaiPrintSettingsPage()),
        );
      }
      return;
    }

    try {
      final ok = await printSvc.printPerjanjianGadai(tx, customer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '🖨️ Struk berhasil dicetak!' : '❌ Gagal cetak struk'),
          backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error cetak: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatCurrency(int val) {
    final s = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day-$month-$year';
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final customer = widget.customer;

    final stableHash = tx.id.hashCode.abs();
    final mockPin = (stableHash % 900000 + 100000).toString();
    final mockImei = (stableHash % 90000000000 + 10000000000).toString();

    final keteranganText = tx.collateralType.toLowerCase().contains('handphone') ||
                            tx.collateralType.toLowerCase().contains('smartphone')
        ? '${tx.condition.isNotEmpty ? tx.condition : "HP saja"}\nIMEI :$mockImei'
        : (tx.condition.isNotEmpty ? tx.condition : '-');

    final displayTxCode = tx.transactionCode.isNotEmpty ? tx.transactionCode : tx.id.substring(0, 10).toUpperCase();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Gadai',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$displayTxCode · ${customer.name}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _loadingData
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── GRUP FOTO NASABAH ──
                        _buildSectionLabel('📋 Foto Nasabah'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _photoColumn('KTP Nasabah', _photos['ktp'] ?? '', Icons.badge_outlined)),
                            const SizedBox(width: 12),
                            Expanded(child: _photoColumn('Foto Diri', _photos['nasabah'] ?? '', Icons.person_outline_rounded)),
                            const Spacer(), // simetris jika hanya 2 kolom
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── GRUP FOTO BARANG GADAI ──
                        _buildSectionLabel('📦 Foto Barang Gadai'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _photoColumn('Barang Utama', _photos['barang'] ?? '',
                              tx.collateralType == 'Emas'
                                  ? Icons.workspace_premium_outlined
                                  : tx.collateralType == 'Motor / Mobil'
                                      ? Icons.two_wheeler_rounded
                                      : Icons.phone_android_rounded,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _photoColumn('Barang Tambahan', _photos['barangTambahan'] ?? '', Icons.photo_library_outlined)),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSectionLabel('Kelengkapan Barang'),
                        const SizedBox(height: 6),
                        _buildSectionBox(
                          text: '-',
                          textStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionLabel('Keterangan'),
                        const SizedBox(height: 6),
                        _buildSectionBox(
                          text: keteranganText,
                          textStyle: GoogleFonts.inter(color: const Color(0xFF1E293B), fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionLabel('Kunci Barang'),
                        const SizedBox(height: 6),
                        _buildKunciBarangBox(mockPin),
                        const SizedBox(height: 20),
                        _infoRow('Nomor WA:', customer.phone, valueColor: const Color(0xFF10B981)),
                        _infoRow('Jenis Barang:', tx.collateralType),
                        _infoRow('Merk & Tipe/Model:', '${tx.brand} ${tx.model}'),
                        _infoRow('Nominal Gadai:', 'Rp ${_formatCurrency(tx.principal)}', valueColor: const Color(0xFF0F766E), isBold: true),
                        _infoRow('Tanggal Gadai:', _formatDate(tx.dateApplied)),
                        _infoRow('Jatuh Tempo:', _formatDate(tx.dateDue)),
                        _infoRow('Petugas:', _petugasName),
                        _infoRow('Status:', tx.status.toLowerCase()),
                        const SizedBox(height: 24),
                        _actionButton(
                          label: 'Lihat History',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RiwayatTransaksiGadaiPage(transaction: tx),
                              ),
                            ).then((_) => widget.onRefresh());
                          },
                        ),
                        const SizedBox(height: 10),
                        _actionButton(
                          label: 'Lihat Perjanjian',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PerjanjianGadaiPage(
                                  transaction: tx,
                                  customer: customer,
                                  petugasName: _petugasName,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _actionButton(
                          label: 'Cetak Struk',
                          onTap: () {
                            _doPrintStruk(tx, customer);
                          },
                        ),

                        // Perpanjangan & Pelunasan hanya tampil jika transaksi masih aktif
                        if (tx.status != 'Lunas' && tx.status != 'Menunggu Pengambilan') ...
                          [
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ExtensionPage(prefilledTxId: tx.id),
                                    ),
                                  ).then((_) => widget.onRefresh());
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Perpanjangan',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
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
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RedemptionPage(prefilledTxId: tx.id),
                                      ),
                                    ).then((_) => widget.onRefresh());
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Pelunasan',
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ], // end Perpanjangan & Pelunasan block

                        // ── Tombol Konfirmasi Pengambilan (tampil jika Menunggu Pengambilan) ──
                        if (tx.status == 'Menunggu Pengambilan') ...
                          [
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 14),
                                const SizedBox(width: 6),
                                const Flexible(child: Text(
                                  'Nasabah telah melunasi via transfer. Serahkan barang jaminan.',
                                  style: TextStyle(color: Color(0xFF059669), fontSize: 11),
                                )),
                              ]),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Konfirmasi Pengambilan'),
                                      content: Text('Konfirmasi barang ${tx.brand} ${tx.model} sudah diambil oleh nasabah?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                                          child: const Text('Konfirmasi', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final svc = SupabaseGadaiService.instance;
                                    await svc.updateTransactionStatus(tx.id, 'Lunas');
                                    if (context.mounted) Navigator.pop(context);
                                    widget.onRefresh();
                                  }
                                },
                                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                label: Text('Konfirmasi Barang Diambil', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],

                        // ── Tombol Lelang (tampil jika bukan Lunas/Lelang/Menunggu Pengambilan) ──
                        if (tx.status != 'Lunas' && tx.status != 'Lelang' && tx.status != 'Menunggu Pengambilan') ...
                          [
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () => _processLelang(tx),
                                icon: const Icon(Icons.gavel_rounded, size: 18, color: Color(0xFFEF4444)),
                                label: Text(
                                  'Proses Lelang',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFEF4444),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Proses lelang barang — bisa dipicu kapanpun nasabah meminta
  void _processLelang(PawnTransaction tx) {
    final priceCtrl = TextEditingController(
      text: (tx.principal + tx.totalFee).toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.gavel_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Proses Lelang',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tx.brand} ${tx.model}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nasabah: ${widget.customer.name}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pinjaman: Rp ${_formatCurrency(tx.principal)}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Harga Jual Lelang (Rp)',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = int.tryParse(priceCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
              if (price <= 0) return;
              try {
                final svc = SupabaseGadaiService.instance;
                // 1. Catat history lelang dulu
                await svc.createLelangHistory(tx.id, price);
                // 2. Update status ke 'Lelang' (= sudah terjual via lelang)
                await svc.updateTransactionStatus(tx.id, 'Lelang');
                // 3. Top up saldo rekening
                await svc.walletTopUp(
                  tx.cabangId,
                  price,
                  'Hasil Lelang ${tx.brand} ${tx.model} (${widget.customer.name})',
                );
                // 4. Log activity
                try {
                  final staff = await svc.getCurrentStaff();
                  final staffName = staff?['nama'] ?? 'Admin';
                  final staffRole = staff?['role'] ?? 'admin_cabang';
                  await svc.logTransaksiLelang(
                    userId: staffName,
                    role: staffRole,
                    txId: tx.id,
                    brandModel: '${tx.brand} ${tx.model}',
                    price: price,
                  );
                } catch (_) {}

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                Navigator.pop(context); // tutup sheet
                widget.onRefresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Berhasil dijual Rp ${_formatCurrency(price)}. Saldo bertambah!',
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              'Konfirmasi Jual',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Buka foto fullscreen dengan gesture tap
  void _openPhotoViewer(String title, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Foto fullscreen + pinch zoom
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 5.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                        const SizedBox(height: 12),
                        Text('Gagal memuat foto',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Header bar atas
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Tombol download di viewer
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _downloadFile(url);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text('Download',
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      // Tombol tutup
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Hint pinch-to-zoom di bawah
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pinch_outlined, color: Colors.white60, size: 14),
                      const SizedBox(width: 6),
                      Text('Pinch untuk zoom',
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoColumn(String title, String url, IconData placeholderIcon) {
    final bool hasPhoto = url.isNotEmpty;
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: hasPhoto ? () => _openPhotoViewer(title, url) : null,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 95,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasPhoto
                        ? const Color(0xFF14B8A6).withValues(alpha: 0.5)
                        : const Color(0xFFE2E8F0),
                    width: hasPhoto ? 1.5 : 1,
                  ),
                ),
                child: hasPhoto
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  color: const Color(0xFF14B8A6),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(placeholderIcon),
                        ),
                      )
                    : _buildPhotoPlaceholder(placeholderIcon),
              ),
              // Icon view di pojok kanan atas jika ada foto
              if (hasPhoto)
                Positioned(
                  top: 4, right: 4,
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 28,
          child: ElevatedButton(
            onPressed: () => _downloadFile(url),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPhoto
                  ? const Color(0xFF14B8A6)
                  : const Color(0xFF94A3B8),
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.download_rounded, color: Colors.white, size: 12),
                const SizedBox(width: 3),
                Text(
                  'Download',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder(IconData icon) {
    return Center(
      child: Icon(
        icon,
        color: const Color(0xFF94A3B8),
        size: 32,
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildSectionBox({required String text, required TextStyle textStyle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: textStyle,
      ),
    );
  }

  Widget _buildKunciBarangBox(String mockPin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              'PIN/Sandi',
              style: GoogleFonts.inter(
                color: const Color(0xFF2563EB),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mockPin,
            style: GoogleFonts.inter(
              color: const Color(0xFF1E293B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                color: valueColor ?? const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }
}
