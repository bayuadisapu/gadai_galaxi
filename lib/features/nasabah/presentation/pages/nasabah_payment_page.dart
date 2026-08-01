import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';

/// Halaman pembayaran manual: nasabah lihat nomor rekening & upload bukti transfer
class NasabahPaymentPage extends StatefulWidget {
  final PawnTransaction transaction;
  final bool isRedemption; // true = tebus barang (lunas), false = perpanjang tenor

  const NasabahPaymentPage({
    super.key,
    required this.transaction,
    this.isRedemption = false,
  });

  @override
  State<NasabahPaymentPage> createState() => _NasabahPaymentPageState();
}

class _NasabahPaymentPageState extends State<NasabahPaymentPage>
    with TickerProviderStateMixin {
  // ── State ──
  String _selectedPeriod = '15 Hari';
  XFile? _proofImage;
  bool _isUploading = false;
  bool _isSubmitted = false;
  List<RekeningGadai> _rekeningList = [];
  RekeningGadai? _selectedRekening;
  bool _loadingRekening = true;

  // ── Metode Pembayaran ──
  String _paymentMethod = 'transfer'; // 'transfer' | 'qris'
  RekeningGadai? _qrisRekening;       // rekening yang punya QRIS

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _successController;
  late Animation<double> _successAnim;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnim = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _loadRekening();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _loadRekening() async {
    try {
      final list = await SupabaseGadaiService.instance.fetchRekeningGadai(
        branchId: widget.transaction.cabangId,
      );
      if (!mounted) return;
      // Cari rekening yang punya QRIS
      final withQris = list.where((r) => r.qrisImageUrl.isNotEmpty).toList();
      setState(() {
        _rekeningList = list;
        _selectedRekening = list.isNotEmpty ? list.first : null;
        _qrisRekening = withQris.isNotEmpty ? withQris.first : null;
        _loadingRekening = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRekening = false);
    }
  }

  // ── Helpers ──
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

  int get _periodDays => _selectedPeriod == '15 Hari' ? 15 : 30;
  int get _jatipDibayar => widget.transaction.dailyFee * _periodDays;
  DateTime get _baseDate => widget.transaction.dateDue.isBefore(DateTime.now())
      ? DateTime.now()
      : widget.transaction.dateDue;
  DateTime get _newDueDate => _baseDate.add(Duration(days: _periodDays));

  int get _totalRedemption =>
      widget.transaction.principal + widget.transaction.totalFee;

  int get _amountToPay =>
      widget.isRedemption ? _totalRedemption : _jatipDibayar;

  // Biaya admin QRIS 0,7% hanya jika nominal >= 500.000
  int get _qrisFee {
    if (_paymentMethod != 'qris') return 0;
    if (_amountToPay < 500000) return 0;
    return (_amountToPay * 0.007).ceil();
  }

  // Total yang harus dibayar nasabah (sudah termasuk biaya QRIS jika ada)
  int get _totalDibayar => _amountToPay + _qrisFee;

  // ── Pick Image ──
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked == null) return;
      setState(() => _proofImage = picked);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal memilih gambar: $e', isError: true);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Pilih Sumber Foto', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _sourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Kamera',
                  color: const Color(0xFF2563EB),
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                )),
                const SizedBox(width: 12),
                Expanded(child: _sourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galeri',
                  color: const Color(0xFF7C3AED),
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Submit Bukti Pembayaran ──
  Future<void> _submitProof() async {
    if (_proofImage == null) {
      _showSnack('Upload bukti pembayaran terlebih dahulu', isError: true);
      return;
    }
    if (_paymentMethod == 'transfer' && _selectedRekening == null) {
      _showSnack('Belum ada rekening tujuan tersedia', isError: true);
      return;
    }
    if (_paymentMethod == 'qris' && _qrisRekening == null) {
      _showSnack('QRIS tidak tersedia untuk cabang ini', isError: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final bytes = await _proofImage!.readAsBytes(); // XFile.readAsBytes() — aman di semua platform
      final svc = SupabaseGadaiService.instance;
      final tx = widget.transaction;

      await svc.submitPaymentProof(
        txId: tx.id,
        proofImageBytes: bytes,
        paymentType: widget.isRedemption ? 'tebus' : 'perpanjang',
        periodDays: widget.isRedemption ? null : _periodDays,
      );

      // Update status lokal
      tx.status = 'Menunggu Verifikasi';
      tx.paymentType = widget.isRedemption ? 'tebus' : 'perpanjang';

      // Log aktivitas
      unawaited(svc.logPaymentSubmitted(
        tx.customerId,
        tx.id,
        widget.isRedemption ? 'tebus' : 'perpanjang',
      ));

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _isSubmitted = true;
      });
      _successController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showSnack('Gagal mengirim bukti: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('$label berhasil disalin!');
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isRedemption ? 'Tebus Barang Jaminan' : 'Bayar Jasa Titip';
    final accentColor = widget.isRedemption
        ? const Color(0xFF059669)
        : const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _isUploading
            ? const SizedBox()
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _paymentMethod == 'qris' ? Icons.qr_code_rounded : Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _paymentMethod == 'qris' ? 'QRIS' : 'Transfer Manual',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _isUploading
          ? _buildUploadingView(accentColor)
          : _isSubmitted
              ? _buildSuccessView(accentColor)
              : _buildPaymentForm(accentColor),
      bottomNavigationBar: (!_isUploading && !_isSubmitted)
          ? _buildSubmitButton(accentColor)
          : null,
    );
  }

  // ── Uploading View ──
  Widget _buildUploadingView(Color accent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(color: accent, strokeWidth: 3),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Mengirim Bukti Transfer...', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Mohon tunggu, jangan tutup aplikasi', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Success View ──
  // ── Success View ──
  Widget _buildSuccessView(Color accent) {
    final tx = widget.transaction;
    final formattedAmount = 'Rp ${_formatCurrency(_amountToPay)}';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // ── Hero Check Circle ──
          ScaleTransition(
            scale: _successAnim,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isRedemption
                      ? [const Color(0xFF059669), const Color(0xFF10B981)]
                      : [AppColors.royalBlue, const Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRedemption ? const Color(0xFF10B981) : AppColors.royalBlue).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
            ),
          ),
          const SizedBox(height: 20),

          // Title & Subtitle
          Text(
            'Bukti Transfer Terkirim!',
            style: GoogleFonts.inter(
              color: AppColors.textDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Pembayaran Anda sedang dalam proses verifikasi oleh tim admin Galaxi Gadai.',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // ── Progress Steps Indicator ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _buildStepItem('1', 'Terkirim', true, true),
                _buildStepLine(true),
                _buildStepItem('2', 'Verifikasi', true, false),
                _buildStepLine(false),
                _buildStepItem('3', 'Selesai', false, false),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Digital Receipt Summary Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isRedemption ? 'Rincian Tebusan' : 'Rincian Perpanjangan',
                          style: GoogleFonts.inter(
                            color: AppColors.textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tx.displayCode,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1D4ED8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                _buildReceiptRow('Nominal Pembayaran', formattedAmount, isBold: true, valueColor: AppColors.royalBlue),
                const SizedBox(height: 10),
                _buildReceiptRow('Barang Jaminan', '${tx.brand} ${tx.model}'),
                const SizedBox(height: 10),
                _buildReceiptRow('Metode Transfer', _selectedRekening != null ? _selectedRekening!.bankName.toUpperCase() : 'Transfer Bank'),
                const SizedBox(height: 10),
                _buildReceiptRow('Waktu Pengiriman', _formatDate(DateTime.now())),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Estimasi Info Box ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimasi Verifikasi 1×24 Jam Kerja',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF92400E),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Notifikasi akan otomatis masuk ke HP Anda begitu admin selesai memverifikasi pembayaran.',
                        style: GoogleFonts.inter(color: const Color(0xFFB45309), fontSize: 11, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Action Buttons ──
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
              label: Text(
                'Kembali ke Detail Transaksi',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                elevation: 4,
                shadowColor: accent.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepItem(String step, String label, bool isDone, bool isCurrent) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDone ? (isCurrent ? AppColors.emerald : const Color(0xFF10B981)) : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone && !isCurrent
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text(
                    step,
                    style: TextStyle(
                      color: isDone ? Colors.white : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
            color: isDone ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isDone) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildReceiptRow(String title, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: valueColor ?? AppColors.textDark,
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Payment Form ──
  Widget _buildPaymentForm(Color accent) {
    final tx = widget.transaction;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Nominal Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isRedemption
                    ? [const Color(0xFF065F46), const Color(0xFF10B981)]
                    : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isRedemption ? 'Total Tebusan' : 'Jasa Titip',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(tx.displayCode, style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Nominal utama
                Text(
                  'Rp ${_formatCurrency(_amountToPay)}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    decoration: _qrisFee > 0 ? TextDecoration.none : null,
                  ),
                ),
                // Biaya QRIS (hanya tampil jika ada)
                if (_qrisFee > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+ Rp ${_formatCurrency(_qrisFee)} biaya QRIS (0,7%)',
                          style: GoogleFonts.inter(color: Colors.orange.shade200, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Total Bayar: ', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                      Text(
                        'Rp ${_formatCurrency(_totalDibayar)}',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Jaminan', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    Text('${tx.brand} ${tx.model}', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (widget.isRedemption) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pokok + Jasa', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                      Text('Rp ${_formatCurrency(tx.principal)} + Rp ${_formatCurrency(tx.totalFee)}',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Jatuh Tempo Saat Ini', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                      Text(_formatDate(tx.dateDue), style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Pilih Metode Pembayaran ──
          Text('Metode Pembayaran', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              // Transfer Bank
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'transfer'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'transfer' ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _paymentMethod == 'transfer' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: _paymentMethod == 'transfer' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_rounded,
                            color: _paymentMethod == 'transfer' ? const Color(0xFF2563EB) : AppColors.textMuted,
                            size: 24),
                        const SizedBox(height: 4),
                        Text('Transfer Bank',
                            style: GoogleFonts.inter(
                              color: _paymentMethod == 'transfer' ? const Color(0xFF2563EB) : AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // QRIS
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'qris'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'qris'
                          ? const Color(0xFFFFF7ED)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _paymentMethod == 'qris'
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFE2E8F0),
                        width: _paymentMethod == 'qris' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_rounded,
                          color: _paymentMethod == 'qris'
                              ? const Color(0xFFF59E0B)
                              : AppColors.textMuted,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'QRIS',
                          style: GoogleFonts.inter(
                            color: _paymentMethod == 'qris'
                                ? const Color(0xFFF59E0B)
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (_qrisFee > 0 && _paymentMethod == 'qris')
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '+0,7% fee',
                              style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),


          // ── Pilih Tenor (hanya untuk perpanjang) ──
          if (!widget.isRedemption) ...[
            Text('Tenor Perpanjangan', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: ['15 Hari', '30 Hari'].map((p) {
                final sel = _selectedPeriod == p;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPeriod = p),
                    child: Container(
                      margin: EdgeInsets.only(right: p == '15 Hari' ? 10 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? accent : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? accent : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Text(p, style: GoogleFonts.inter(color: sel ? Colors.white : AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Tempo: ${_formatDate(_newDueDate)}',
                              style: GoogleFonts.inter(color: sel ? Colors.white70 : AppColors.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // ── Rekening Transfer (hanya jika metode transfer) ──
          if (_paymentMethod == 'transfer') ...[
            Text('Transfer ke Rekening', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (_loadingRekening)
              const Center(child: CircularProgressIndicator())
            else if (_rekeningList.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Rekening belum tersedia. Hubungi admin.', style: GoogleFonts.inter(color: const Color(0xFF991B1B), fontSize: 13))),
                  ],
                ),
              )
            else
              ...(_rekeningList.map((rek) => _buildRekeningCard(rek)).toList()),
            const SizedBox(height: 20),
          ],

          // ── QRIS Section (hanya jika metode QRIS) ──
          if (_paymentMethod == 'qris') ...[
            Text('Scan QRIS untuk Bayar', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (_qrisFee == 0)
              Text('Tidak ada biaya tambahan (nominal di bawah Rp 500.000)',
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12))
            else
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                  children: [
                    const TextSpan(text: 'Biaya admin QRIS '),
                    TextSpan(
                      text: 'Rp ${_formatCurrency(_qrisFee)} (0,7%)',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' sudah termasuk dalam total Rp ${_formatCurrency(_totalDibayar)}'),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (_qrisRekening != null && _qrisRekening!.qrisImageUrl.isNotEmpty)
              GestureDetector(
                onTap: () => _showQrisFullscreen(_qrisRekening!.qrisImageUrl),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: Image.network(
                          _qrisRekening!.qrisImageUrl,
                          width: double.infinity,
                          height: 280,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, loading) => loading == null
                              ? child
                              : SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: const Color(0xFFF59E0B),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(40),
                            child: Icon(Icons.qr_code_rounded, size: 100, color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.zoom_in_rounded, size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 4),
                            Text(
                              'Tap untuk perbesar',
                              style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFD97706), size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kode QRIS Belum Belum Diunggah',
                      style: GoogleFonts.inter(color: const Color(0xFF92400E), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Super Admin belum mengunggah gambar QRIS untuk cabang ini. Silakan gunakan metode Transfer Bank.',
                      style: GoogleFonts.inter(color: const Color(0xFFB45309), fontSize: 12, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _paymentMethod = 'transfer'),
                      icon: const Icon(Icons.account_balance_rounded, size: 16),
                      label: const Text('Gunakan Transfer Bank'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB45309),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
          ],



          // ── Upload Bukti Pembayaran ──
          Text(
            _paymentMethod == 'qris' ? 'Upload Bukti QRIS' : 'Upload Bukti Transfer',
            style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _paymentMethod == 'qris'
                ? 'Screenshot konfirmasi pembayaran QRIS'
                : 'Foto struk transfer atau screenshot konfirmasi pembayaran',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _buildImagePicker(accent),
          const SizedBox(height: 20),

          // ── Info Box ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Setelah bukti dikirim, admin akan memverifikasi pembayaran Anda. Status transaksi akan diperbarui secara otomatis.',
                    style: GoogleFonts.inter(color: const Color(0xFF1E40AF), fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  LinearGradient _getNasabahBankGradient(String bankName) {
    final upper = bankName.toUpperCase().trim();
    if (upper.contains('BCA')) {
      return const LinearGradient(colors: [Color(0xFF0F4C81), Color(0xFF1E3A8A)]);
    } else if (upper.contains('BRI')) {
      return const LinearGradient(colors: [Color(0xFF00529C), Color(0xFF0284C7)]);
    } else if (upper.contains('MANDIRI')) {
      return const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]);
    } else if (upper.contains('BNI')) {
      return const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFC2410C)]);
    } else if (upper.contains('SPAY') || upper.contains('SHOPEE')) {
      return const LinearGradient(colors: [Color(0xFFEE4D2D), Color(0xFFFF7337)]);
    } else if (upper.contains('PERMATA') || upper.contains('DANAMON')) {
      return const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0F766E)]);
    } else if (upper.contains('CIMB')) {
      return const LinearGradient(colors: [Color(0xFFB91C1C), Color(0xFF991B1B)]);
    }
    return const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]);
  }

  Widget _buildRekeningCard(RekeningGadai rek) {
    final isSelected = _selectedRekening?.id == rek.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedRekening = rek),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: _getNasabahBankGradient(rek.bankName),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                rek.bankName.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'a.n. ${rek.accountName}',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      SelectableText(
                        rek.accountNumber,
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _copyToClipboard(rek.accountNumber, 'Nomor rekening'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.copy_rounded, size: 11, color: Color(0xFF1D4ED8)),
                              const SizedBox(width: 4),
                              Text(
                                'Salin',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1D4ED8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF10B981) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(Color accent) {
    if (_proofImage != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FutureBuilder<Uint8List>(
              future: _proofImage!.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                return Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                  ),
                  child: Image.memory(snapshot.data!, fit: BoxFit.cover),
                );
              },
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _proofImage = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 8, right: 8,
            child: GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('Ganti', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          // Checkmark
          Positioned(
            top: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      );
    }

    // Tombol upload
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.upload_rounded, color: accent, size: 28),
            ),
            const SizedBox(height: 12),
            Text('Tap untuk upload bukti transfer', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text('JPG, PNG — max 5MB', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── Submit Button ──
  Widget _buildSubmitButton(Color accent) {
    final hasProof = _proofImage != null;
    final effectiveAccent = _paymentMethod == 'qris' ? const Color(0xFFF59E0B) : accent;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: hasProof ? _submitProof : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasProof ? effectiveAccent : const Color(0xFFCBD5E1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasProof
                    ? (_paymentMethod == 'qris' ? Icons.qr_code_rounded : Icons.send_rounded)
                    : Icons.upload_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                hasProof
                    ? (_paymentMethod == 'qris' ? 'Kirim Bukti QRIS' : 'Kirim Bukti Pembayaran')
                    : 'Upload Bukti Dahulu',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── QRIS Fullscreen Viewer ──
  void _showQrisFullscreen(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scan QRIS', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.error_outline, color: Colors.white, size: 60),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan kode QR di atas menggunakan aplikasi m-banking atau e-wallet Anda',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
