import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/services/fcm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Halaman admin untuk melihat dan memverifikasi pembayaran nasabah
class VerifikasiPembayaranPage extends StatefulWidget {
  final String cabangId;
  final String namaAdmin;

  const VerifikasiPembayaranPage({
    super.key,
    required this.cabangId,
    required this.namaAdmin,
  });

  @override
  State<VerifikasiPembayaranPage> createState() => _VerifikasiPembayaranPageState();
}

class _VerifikasiPembayaranPageState extends State<VerifikasiPembayaranPage> {
  final _svc = SupabaseGadaiService.instance;

  List<PawnTransaction> _pendingTxs = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadPending();
    _initFcm();
    _subscribeRealtime();
  }

  /// Pastikan FCM sudah di-initialize sebelum subscribe realtime
  Future<void> _initFcm() async {
    await FcmService.instance.initialize();
    await FcmService.instance.requestPermission();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await FcmService.instance.saveStaffFcmToken(userId);
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final list = await _svc.fetchPendingPayments(
        branchId: widget.cabangId == 'all' ? null : widget.cabangId,
      );
      if (!mounted) return;
      setState(() {
        _pendingTxs = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime() {
    _realtimeChannel = _svc.subscribeToPaymentRequests(
      branchId: widget.cabangId == 'all' ? '' : widget.cabangId,
      onNewPayment: (tx) async {
        if (!mounted) return;
        // Reload daftar dulu agar nasabahName ter-join dari DB
        await _loadPending();
        // Ambil nama nasabah dari daftar yang sudah di-load (sudah ada join)
        final nama = _pendingTxs
            .where((t) => t.id == tx.id)
            .map((t) => t.nasabahName)
            .firstWhere((n) => n.isNotEmpty, orElse: () => 'Nasabah');
        // Tampilkan local notification
        FcmService.instance.showPaymentRequestNotification(
          nasabahName: nama,
          txCode: tx.displayCode,
          paymentType: tx.paymentType ?? 'perpanjang',
        );
        // Tampilkan snackbar
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔔 Permintaan pembayaran baru: ${tx.displayCode}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Lihat',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      },
      onPaymentUpdated: (_) => _loadPending(),
    );
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

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} WIB';
  }

  // ── Verifikasi Pembayaran ──
  Future<void> _verifyPayment(PawnTransaction tx) async {
    final adminId = Supabase.instance.client.auth.currentUser?.id ?? widget.namaAdmin;
    final paymentType = tx.paymentType ?? 'perpanjang';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
    );

    try {
      if (paymentType == 'tebus') {
        await _svc.verifyTebusPayment(txId: tx.id, adminId: adminId);
      } else {
        // Hitung perpanjangan
        final periodDays = tx.paymentPeriodDays ?? 15;
        final dailyFee = tx.dailyFee;
        final baseDate = tx.dateDue.isBefore(DateTime.now()) ? DateTime.now() : tx.dateDue;
        final newDueDate = baseDate.add(Duration(days: periodDays));
        final newTotalFee = dailyFee * periodDays;
        final newTotalRepayment = tx.principal + newTotalFee;

        await _svc.verifyPerpanjangPayment(
          txId: tx.id,
          adminId: adminId,
          newDueDate: newDueDate,
          periodDays: periodDays,
          totalFee: newTotalFee,
          totalRepayment: newTotalRepayment,
        );
      }

      unawaited(_svc.logPaymentVerified(adminId, tx.id, paymentType));

      if (!mounted) return;
      Navigator.pop(context); // tutup loading

      // Remove dari list
      setState(() => _pendingTxs.removeWhere((t) => t.id == tx.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Pembayaran ${tx.displayCode} berhasil dikonfirmasi!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            )),
          ]),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // tutup loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal konfirmasi: $e', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Tolak Pembayaran ──
  Future<void> _rejectPayment(PawnTransaction tx) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text('Tolak Pembayaran', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaksi: ${tx.displayCode}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Text('Alasan penolakan:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Contoh: Foto bukti tidak jelas, nominal tidak sesuai...',
                hintStyle: GoogleFonts.inter(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: GoogleFonts.inter())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Tolak', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final reason = reasonCtrl.text.trim().isEmpty ? 'Tidak ada keterangan' : reasonCtrl.text.trim();
    final adminId = Supabase.instance.client.auth.currentUser?.id ?? widget.namaAdmin;
    final previousStatus = tx.paymentType == 'tebus' ? 'Aktif' : 'Aktif';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFEF4444))),
    );

    try {
      await _svc.rejectPayment(txId: tx.id, reason: reason, previousStatus: previousStatus);
      unawaited(_svc.logPaymentRejected(adminId, tx.id, reason));

      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _pendingTxs.removeWhere((t) => t.id == tx.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pembayaran ${tx.displayCode} ditolak.', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    }
  }

  // ── Lihat Bukti ──
  void _showProofDialog(PawnTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(
                    'Bukti Transfer — ${tx.displayCode}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  )),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            // Image
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
                maxWidth: double.infinity,
              ),
              color: Colors.black,
              child: tx.paymentProofUrl != null
                  ? InteractiveViewer(
                      child: Image.network(
                        tx.paymentProofUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                              SizedBox(height: 8),
                              Text('Gagal memuat gambar', style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text('Tidak ada bukti', style: TextStyle(color: Colors.white54)),
                    ),
            ),
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _rejectPayment(tx);
                      },
                      icon: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18),
                      label: Text('Tolak', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _verifyPayment(tx);
                      },
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      label: Text('Konfirmasi Pembayaran', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verifikasi Pembayaran', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
            if (_pendingTxs.isNotEmpty)
              Text('${_pendingTxs.length} menunggu', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadPending,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _pendingTxs.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 48),
          ),
          const SizedBox(height: 20),
          Text('Semua Pembayaran Terverifikasi', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tidak ada pembayaran yang menunggu verifikasi.', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _loadPending,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            label: Text('Refresh', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadPending,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _pendingTxs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _buildCard(_pendingTxs[i]),
      ),
    );
  }

  Widget _buildCard(PawnTransaction tx) {
    final paymentType = tx.paymentType ?? 'perpanjang';
    final isTebus = paymentType == 'tebus';
    final accentColor = isTebus ? const Color(0xFF059669) : const Color(0xFF2563EB);
    final amount = isTebus
        ? tx.principal + tx.totalFee
        : tx.dailyFee * (tx.paymentPeriodDays ?? 15);

    return GestureDetector(
      onTap: () => _showProofDialog(tx),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTebus ? Icons.lock_open_rounded : Icons.update_rounded,
                      color: accentColor, size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tx.brand} ${tx.model}',
                          style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(tx.displayCode, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isTebus ? 'Tebus' : 'Perpanjang',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            // ── Body ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow('Nominal', 'Rp ${_formatCurrency(amount)}', valueStyle: GoogleFonts.inter(color: accentColor, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (!isTebus)
                    _infoRow('Durasi', '${tx.paymentPeriodDays ?? 15} Hari'),
                  if (!isTebus) const SizedBox(height: 8),
                  if (tx.paymentRequestedAt != null)
                    _infoRow('Dikirim', _formatDate(tx.paymentRequestedAt!)),
                  const SizedBox(height: 16),
                  // Bukti transfer preview
                  if (tx.paymentProofUrl != null)
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        color: const Color(0xFFF8FAFC),
                        image: DecorationImage(
                          image: NetworkImage(tx.paymentProofUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text('Lihat penuh', style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectPayment(tx),
                          icon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFEF4444)),
                          label: Text('Tolak', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _verifyPayment(tx),
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                          label: Text('Konfirmasi', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
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
      ),
    );
  }

  Widget _infoRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: valueStyle ?? GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
