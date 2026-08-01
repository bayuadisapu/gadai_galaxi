import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';

class RiwayatTransaksiGadaiPage extends StatefulWidget {
  final PawnTransaction transaction;
  const RiwayatTransaksiGadaiPage({super.key, required this.transaction});

  @override
  State<RiwayatTransaksiGadaiPage> createState() => _RiwayatTransaksiGadaiPageState();
}

class _RiwayatTransaksiGadaiPageState extends State<RiwayatTransaksiGadaiPage> {
  final _svc = SupabaseGadaiService.instance;
  Customer? _customer;
  List<ExtensionHistory> _extensions = [];
  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final customer = await _svc.fetchNasabahById(widget.transaction.customerId);
      final extensions = await _svc.fetchExtensionHistory(widget.transaction.id);
      final logs = await _svc.fetchActivityLogsByTransaction(widget.transaction.id);

      if (!mounted) return;
      setState(() {
        _customer = customer;
        _extensions = extensions;
        _activityLogs = logs;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d-$m-${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $timeStr';
  }

  String _todayHeaderLabel() {
    final now = DateTime.now();
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month]} ${now.year}';
  }

  List<_TimelineEvent> _compileTimeline() {
    final List<_TimelineEvent> list = [];

    // 1. Creation Event
    final createdLog = _activityLogs.firstWhere(
      (l) => l['action'] == 'TRANSAKSI_CREATED',
      orElse: () => {},
    );
    final createdTime = createdLog.isNotEmpty
        ? DateTime.parse(createdLog['created_at'] as String)
        : widget.transaction.dateApplied;

    final createdDesc = createdLog.isNotEmpty
        ? (createdLog['description'] as String)
        : 'Gadai ${widget.transaction.collateralType} ${widget.transaction.brand}/${widget.transaction.model} sebesar Rp. ${_formatCurrency(widget.transaction.principal)} Biaya Admin / Jasa Titip ${_formatCurrency(widget.transaction.totalFee)} uang diterima Rp. ${_formatCurrency(widget.transaction.principal)} (Jasa Titip dibayar saat penebusan)';

    list.add(_TimelineEvent(
      dateTime: createdTime,
      statusLabel: 'Gadai',
      description: createdDesc,
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFF2DA59E),
    ));

    // 2. Edits
    for (final log in _activityLogs) {
      if (log['action'] == 'TRANSAKSI_UPDATED') {
        final tStr = log['created_at'] as String;
        final t = DateTime.parse(tStr);
        list.add(_TimelineEvent(
          dateTime: t,
          statusLabel: 'Ubah Data',
          description: log['description'] as String? ?? 'Perubahan data barang jaminan.',
          icon: Icons.edit_note_rounded,
          color: const Color(0xFF7C3AED),
        ));
      }
    }

    // 3. Extensions
    for (final ext in _extensions) {
      final desc = 'Perpanjangan tenor dari jatuh tempo lama ${_formatDate(ext.tglTempoLama)} menjadi ${_formatDate(ext.tglTempoBaru)}. Jasa titip dibayar sebesar Rp. ${_formatCurrency(ext.jatipDibayar)}.';
      list.add(_TimelineEvent(
        dateTime: ext.tglPerpanjangan,
        statusLabel: 'Perpanjang',
        description: desc,
        icon: Icons.autorenew_rounded,
        color: const Color(0xFFF59E0B),
      ));
    }

    // 4. Cancellations
    final cancelledLog = _activityLogs.firstWhere(
      (l) => l['action'] == 'TRANSAKSI_CANCELLED',
      orElse: () => {},
    );
    if (cancelledLog.isNotEmpty) {
      list.add(_TimelineEvent(
        dateTime: DateTime.parse(cancelledLog['created_at'] as String),
        statusLabel: 'Dibatalkan',
        description: cancelledLog['description'] as String? ?? 'Transaksi gadai dibatalkan.',
        icon: Icons.cancel_rounded,
        color: const Color(0xFFEF4444),
      ));
    } else if (widget.transaction.status == 'Dibatalkan') {
      list.add(_TimelineEvent(
        dateTime: DateTime.now(),
        statusLabel: 'Dibatalkan',
        description: 'Transaksi gadai dibatalkan.',
        icon: Icons.cancel_rounded,
        color: const Color(0xFFEF4444),
      ));
    }

    // 5. Redemption (Lunas)
    final redeemedLog = _activityLogs.firstWhere(
      (l) => l['action'] == 'TRANSAKSI_REDEEMED',
      orElse: () => {},
    );
    if (redeemedLog.isNotEmpty) {
      list.add(_TimelineEvent(
        dateTime: DateTime.parse(redeemedLog['created_at'] as String),
        statusLabel: 'Lunas / Tebus',
        description: redeemedLog['description'] as String? ?? 'Penebusan barang jaminan (Lunas).',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
      ));
    } else if (widget.transaction.status == 'Lunas') {
      list.add(_TimelineEvent(
        dateTime: DateTime.now(),
        statusLabel: 'Lunas / Tebus',
        description: 'Penebusan barang jaminan (Lunas) sebesar Rp. ${_formatCurrency(widget.transaction.principal + widget.transaction.totalFee)}.',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
      ));
    }

    // 6. Lelang / Terjual
    final lelangLog = _activityLogs.firstWhere(
      (l) => l['action'] == 'TRANSAKSI_LELANG',
      orElse: () => {},
    );
    if (lelangLog.isNotEmpty) {
      list.add(_TimelineEvent(
        dateTime: DateTime.parse(lelangLog['created_at'] as String),
        statusLabel: 'Dilelang / Terjual',
        description: lelangLog['description'] as String? ?? 'Barang jaminan berhasil dilelang.',
        icon: Icons.gavel_rounded,
        color: const Color(0xFF8B5CF6),
      ));
    } else if (widget.transaction.status == 'Lelang' || widget.transaction.status == 'Terjual') {
      list.add(_TimelineEvent(
        dateTime: DateTime.now(),
        statusLabel: 'Dilelang / Terjual',
        description: 'Barang jaminan telah masuk masa lelang dan terjual.',
        icon: Icons.gavel_rounded,
        color: const Color(0xFF8B5CF6),
      ));
    }

    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final customer = _customer ?? Customer(id: '', name: 'Loading...', nik: '', phone: 'Loading...', address: '', birthPlace: '', birthDate: '', gender: '');
    
    final contractNo = tx.displayCode.replaceAll('GDI-', '');
    final headerContractCode = contractNo.length > 5 ? contractNo.substring(0, 5) : contractNo;

    final events = _compileTimeline();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2DA59E)))
          : Column(
              children: [
                _buildTealHeader(headerContractCode),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Riwayat Transaksi Gadai',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Detail lengkap transaksi dan perubahan status',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildDetailsCard(tx, customer),

                          const SizedBox(height: 24),

                          if (events.isEmpty)
                            const Center(child: Text('Tidak ada riwayat aktivitas.'))
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: events.length,
                              itemBuilder: (context, idx) {
                                final ev = events[idx];
                                return _buildTimelineItem(ev, idx == events.length - 1);
                              },
                            ),

                          const SizedBox(height: 32),

                          _buildBackButton(),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTealHeader(String contractCode) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: 20, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF2DA59E),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Center(
              child: Text(
                'S',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2DA59E),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GALAXI GADAI',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'ID-$contractCode',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _todayHeaderLabel(),
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(PawnTransaction tx, Customer customer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldRow('NOMOR KONTRAK', tx.displayCode.replaceAll('GDI-', ''), isBoldValue: true, valueColor: const Color(0xFF0F766E)),
          const SizedBox(height: 14),
          _buildFieldRow('TANGGAL GADAI', _formatDate(tx.dateApplied)),
          const SizedBox(height: 14),
          _buildFieldRow('NAMA NASABAH', customer.name, isBoldValue: true),
          const SizedBox(height: 14),
          _buildFieldRow('NO. HP', customer.phone, isBoldValue: true),
          const SizedBox(height: 14),
          _buildFieldRow('BARANG', '${tx.collateralType} ${tx.brand} ${tx.model}', isBoldValue: true),
          const SizedBox(height: 14),
          _buildFieldRow('NOMINAL GADAI', 'Rp ${_formatCurrency(tx.principal)}', isBoldValue: true, valueColor: const Color(0xFF0F766E)),
          const SizedBox(height: 14),
          _buildFieldRow('STATUS', tx.status, isBoldValue: true),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String label, String value, {bool isBoldValue = false, Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: valueColor ?? const Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(_TimelineEvent ev, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 22),
                Container(
                  width: 11,
                  height: 11,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2DA59E),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox()
                      : Container(
                          width: 2.2,
                          color: const Color(0xFF2DA59E).withValues(alpha: 0.3),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateTime(ev.dateTime),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ev.statusLabel,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF0F766E),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ev.description,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF334155),
                      fontSize: 13,
                      height: 1.45,
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

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F766E), size: 18),
        label: Text(
          'Kembali ke Data Gadai',
          style: GoogleFonts.poppins(
            color: const Color(0xFF0F766E),
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCCFBF1), width: 1.5),
          backgroundColor: const Color(0xFFF0FDFA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _TimelineEvent {
  final DateTime dateTime;
  final String statusLabel;
  final String description;
  final IconData icon;
  final Color color;

  _TimelineEvent({
    required this.dateTime,
    required this.statusLabel,
    required this.description,
    required this.icon,
    required this.color,
  });
}
