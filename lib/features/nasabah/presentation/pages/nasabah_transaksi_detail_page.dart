import 'dart:async';
import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/config/system_config.dart';
import 'package:galaxi_gadai/core/services/perjanjian_pdf_service.dart';
import 'package:galaxi_gadai/features/nasabah/presentation/pages/nasabah_payment_page.dart';
import 'package:galaxi_gadai/core/services/fcm_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NasabahTransaksiDetailPage extends StatefulWidget {
  final PawnTransaction transaction;
  final Customer? customer;
  const NasabahTransaksiDetailPage({super.key, required this.transaction, this.customer});

  @override
  State<NasabahTransaksiDetailPage> createState() => _NasabahTransaksiDetailPageState();
}

class _NasabahTransaksiDetailPageState extends State<NasabahTransaksiDetailPage> {
  List<ExtensionHistory> _extensions = [];
  LelangHistory? _lelangHistory;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadExtensions();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToUpdates() {
    _realtimeChannel = SupabaseGadaiService.instance.subscribeToTransactionUpdates(
      txId: widget.transaction.id,
      onUpdate: (updatedTx) {
        if (!mounted) return;
        final oldStatus = widget.transaction.status;
        // Update status lokal dari Realtime
        setState(() {
          widget.transaction.status = updatedTx.status;
          widget.transaction.paymentVerifiedAt = updatedTx.paymentVerifiedAt;
          widget.transaction.paymentType = updatedTx.paymentType;
          widget.transaction.paymentPeriodDays = updatedTx.paymentPeriodDays;
          if (updatedTx.dateDue != widget.transaction.dateDue) {
            widget.transaction.dateDue = updatedTx.dateDue;
            widget.transaction.totalFee = updatedTx.totalFee;
            widget.transaction.totalRepayment = updatedTx.totalRepayment;
            widget.transaction.periodDays = updatedTx.periodDays;
          }
        });

        // Trigger Notifikasi Sistem HP jika status berubah dari Menunggu Verifikasi
        if (oldStatus == 'Menunggu Verifikasi') {
          if (updatedTx.status == 'Aktif' || updatedTx.status == 'Menunggu Pengambilan') {
            FcmService.instance.showPaymentVerifiedNotification(
              txCode: updatedTx.displayCode,
              paymentType: updatedTx.paymentType ?? (updatedTx.status == 'Menunggu Pengambilan' ? 'tebus' : 'perpanjang'),
            );
          } else if (updatedTx.paymentRejectReason != null && updatedTx.paymentRejectReason!.isNotEmpty) {
            FcmService.instance.showPaymentRejectedNotification(
              txCode: updatedTx.displayCode,
              reason: updatedTx.paymentRejectReason,
            );
          }
        }

        // Reload extension history jika perpanjang dikonfirmasi
        if (updatedTx.status == 'Aktif') _loadExtensions();
      },
    );
  }

  // ── SHARE PDF PERJANJIAN ──
  Future<void> _sharePdf(PawnTransaction tx) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏳ Membuat PDF...'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
      );
      final customer = widget.customer ?? Customer(
        id: tx.customerId, name: 'Nasabah', nik: '-',
        birthPlace: '', birthDate: '', gender: '', phone: '-', address: '',
      );
      final pdfFile = await PerjanjianPdfService.instance.generatePerjanjianPdf(
        tx: tx, customer: customer, petugasName: 'Admin',
      );
      if (!mounted) return;
      final xFile = XFile(pdfFile.path, mimeType: 'application/pdf');
      await Share.shareXFiles([xFile],
        text: 'Perjanjian Gadai - ${tx.displayCode}',
        subject: 'Perjanjian Gadai - GALAXI GADAI',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Gagal buat PDF: $e'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _loadExtensions() async {
    try {
      final svc = SupabaseGadaiService.instance;
      final ext = await svc.fetchExtensionHistory(widget.transaction.id);
      final lelangList = await svc.fetchLelangHistory();
      LelangHistory? myLelang;
      for (final h in lelangList) {
        if (h.transactionId == widget.transaction.id) {
          myLelang = h;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _extensions = ext;
        _lelangHistory = myLelang;
      });
    } catch (_) {}
  }

  // ── PERPANJANG — Navigasi ke halaman pembayaran manual ──
  Future<void> _showPerpanjangSheet() async {
    final tx = widget.transaction;
    if (tx.status == 'Lunas') return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NasabahPaymentPage(
          transaction: tx,
          isRedemption: false,
        ),
      ),
    );

    // Setelah kembali, refresh data
    if (mounted) setState(() {});
  }

  // ── TEBUS BARANG — Navigasi ke halaman pembayaran manual ──
  Future<void> _showTebusSheet() async {
    final tx = widget.transaction;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NasabahPaymentPage(
          transaction: tx,
          isRedemption: true,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _applyExtension(PawnTransaction tx, int days, int jatipBayar) async {
    final svc = SupabaseGadaiService.instance;
    final oldDueDate = tx.dateDue;
    final baseDate = tx.dateDue.isBefore(DateTime.now()) ? DateTime.now() : tx.dateDue;
    final newDueDate = baseDate.add(Duration(days: days));
    final newTotalFee = (tx.dailyFee > 0 ? tx.dailyFee : SystemConfig.calculateDailyFee(tx.principal)) * days;
    final newTotalRepayment = tx.principal + newTotalFee;

    await svc.createExtension(ExtensionHistory(
      id: '', transactionId: tx.id,
      jatipDibayar: jatipBayar,
      tglPerpanjangan: DateTime.now(),
      tglTempoLama: oldDueDate,
      tglTempoBaru: newDueDate,
    ));
    await svc.updateTransactionStatus(tx.id, 'Aktif', newDueDate: newDueDate, periodDays: days, totalFee: newTotalFee, totalRepayment: newTotalRepayment);
    unawaited(svc.logExtensionRequested(tx.customerId, tx.id));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Perpanjangan berhasil! Jatuh tempo baru: ${_formatDate(newDueDate)}'), backgroundColor: const Color(0xFF10B981)),
    );
    _loadExtensions();
  }

  String _formatCurrency(int val) {
    final s = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final today = DateTime.now();
    final daysLeft = tx.dateDue.difference(today).inDays;
    final isOverdue = daysLeft < 0;

    // Gunakan dailyFee yang tersimpan di transaksi, bukan hitung ulang dari SystemConfig
    final int dailyFeeCalc = tx.dailyFee > 0 ? tx.dailyFee : SystemConfig.calculateDailyFee(tx.principal);

    Color statusColor = AppColors.primary;
    if (tx.status == 'Macet') statusColor = const Color(0xFFEF4444);
    else if (tx.status == 'Lunas') statusColor = const Color(0xFF10B981);
    else if (tx.status == 'Menunggu Pengambilan') statusColor = const Color(0xFF059669);
    else if (tx.status == 'Lelang' || tx.status == 'Terjual') statusColor = const Color(0xFF8B5CF6);

    final extensionHistory = _extensions;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Transaksi',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
            tooltip: 'Download PDF Perjanjian',
            onPressed: () => _sharePdf(tx),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Collateral Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tx.displayCode, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tx.status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('${tx.brand} ${tx.model}', style: const TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Jenis: ${tx.collateralType} • Kondisi: ${tx.condition}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Countdown / Due Date Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOverdue ? const Color(0xFFFEF2F2) : (daysLeft <= 3 ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isOverdue ? const Color(0xFFFCA5A5) : (daysLeft <= 3 ? const Color(0xFFFED7AA) : const Color(0xFFA7F3D0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                    color: isOverdue ? const Color(0xFFEF4444) : (daysLeft <= 3 ? const Color(0xFFF97316) : const Color(0xFF10B981)),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOverdue ? 'Sudah Melewati Jatuh Tempo!' : (daysLeft == 0 ? 'Jatuh Tempo HARI INI!' : 'Jatuh tempo $daysLeft hari lagi'),
                          style: TextStyle(
                            color: isOverdue ? const Color(0xFFEF4444) : (daysLeft <= 3 ? const Color(0xFFF97316) : const Color(0xFF059669)),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tanggal Jatuh Tempo: ${_formatDate(tx.dateDue)}',
                          style: TextStyle(
                            color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF059669),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Banner Menunggu Verifikasi ──
            if (tx.status == 'Menunggu Verifikasi') ...[  
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Menunggu Verifikasi Admin',
                        style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                      'Bukti transfer Anda sudah diterima. Admin sedang memverifikasi pembayaran Anda.',
                      style: TextStyle(color: Color(0xFF78350F), fontSize: 12, height: 1.4),
                    ),
                    if (tx.paymentType != null) ...[  
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tx.paymentType == 'tebus' ? '🔓 Tebus Barang' : '🔄 Perpanjang ${tx.paymentPeriodDays ?? 15} Hari',
                          style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Financial Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💰 Rincian Keuangan', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _row('Nominal Pinjaman (N)', 'Rp ${_formatCurrency(tx.principal)}'),
                  const SizedBox(height: 10),
                  _row('Jasa Titip Harian', 'Rp ${_formatCurrency(dailyFeeCalc)} / hari'),
                  const SizedBox(height: 10),
                  _row('Periode Gadai', '${tx.periodDays} Hari'),
                  const SizedBox(height: 10),
                  _row('Total Jasa Titip (JT)', 'Rp ${_formatCurrency(tx.totalFee)}'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(color: Color(0xFFDBEAFE)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Tebusan', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('Rp ${_formatCurrency(tx.principal + tx.totalFee)}', style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Timeline Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📅 Timeline', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _row('Tanggal Pengajuan', _formatDate(tx.dateApplied)),
                  const SizedBox(height: 10),
                  _row('Jatuh Tempo', _formatDate(tx.dateDue)),
                  if (tx.status == 'Lelang' || tx.status == 'Terjual') ...[
                    const SizedBox(height: 10),
                    _row('Status', 'Dilelang / Terjual', valueColor: const Color(0xFF8B5CF6)),
                    if (_lelangHistory != null) ...[
                      const SizedBox(height: 10),
                      _row('Harga Terjual', 'Rp ${_formatCurrency(_lelangHistory!.hargaLelang)}',
                          valueColor: const Color(0xFF8B5CF6)),
                      const SizedBox(height: 10),
                      _row('Tanggal Lelang', _formatDate(_lelangHistory!.tglLelang)),
                    ],
                  ],
                ],
              ),
            ),

            // Riwayat Perpanjangan
            if (extensionHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔄 Riwayat Perpanjangan', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...extensionHistory.asMap().entries.map((entry) {
                      final i = entry.key + 1;
                      final ext = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Perpanjangan ke-$i', style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            _row('Jasa Titip Dibayar', 'Rp ${_formatCurrency(ext.jatipDibayar)}'),
                            const SizedBox(height: 4),
                            _row('Tempo Lama', _formatDateShort(ext.tglTempoLama)),
                            const SizedBox(height: 4),
                            _row('Tempo Baru', _formatDateShort(ext.tglTempoBaru)),
                            const SizedBox(height: 4),
                            _row('Tgl Perpanjangan', _formatDateShort(ext.tglPerpanjangan)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: () {
        if (tx.status == 'Lunas' || tx.status == 'Lelang' || tx.status == 'Terjual') return null;

        // Menunggu Verifikasi — hanya tampilkan info, tidak ada tombol aksi
        if (tx.status == 'Menunggu Verifikasi') {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Row(children: [
                  Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 10),
                  Flexible(child: Text(
                    '⏳ Menunggu konfirmasi admin. Harap bersabar...',
                    style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600, fontSize: 13),
                  )),
                ]),
              ),
            ),
          );
        }

        if (tx.status == 'Menunggu Pengambilan') {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.access_time_rounded, color: Color(0xFF059669), size: 20),
                  SizedBox(width: 10),
                  Flexible(child: Text(
                    '✅ Pelunasan diterima. Barang siap diambil di toko.',
                    style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600, fontSize: 13),
                  )),
                ]),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showPerpanjangSheet,
                  icon: const Icon(Icons.update_rounded, color: Colors.white, size: 18),
                  label: const Text('Perpanjang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showTebusSheet,
                  icon: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 18),
                  label: const Text('Tebus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
        );
      }(),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value,
            style: TextStyle(color: valueColor ?? AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
