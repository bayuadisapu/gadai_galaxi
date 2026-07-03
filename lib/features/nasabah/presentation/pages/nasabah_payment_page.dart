import 'dart:async';
import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'nasabah_payment_success_page.dart';

class NasabahPaymentPage extends StatefulWidget {
  final PawnTransaction transaction;
  final bool isRedemption; // true = tebus barang (lunas), false = perpanjang tenor

  const NasabahPaymentPage({super.key, required this.transaction, this.isRedemption = false});

  @override
  State<NasabahPaymentPage> createState() => _NasabahPaymentPageState();
}

class _NasabahPaymentPageState extends State<NasabahPaymentPage>
    with TickerProviderStateMixin {
  String _selectedPeriod = '15 Hari';
  String? _selectedMethod;
  bool _isProcessing = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const _methods = [
    {'id': 'bca_va', 'label': 'BCA Virtual Account', 'icon': 'assets/bca.png', 'emoji': '🏦', 'color': 0xFF003F88},
    {'id': 'bni_va', 'label': 'BNI Virtual Account', 'icon': '', 'emoji': '🏦', 'color': 0xFF0B5CA6},
    {'id': 'mandiri_va', 'label': 'Mandiri Virtual Account', 'icon': '', 'emoji': '🏦', 'color': 0xFF003D6E},
    {'id': 'qris', 'label': 'QRIS', 'icon': '', 'emoji': '📱', 'color': 0xFF10B981},
    {'id': 'gopay', 'label': 'GoPay', 'icon': '', 'emoji': '💚', 'color': 0xFF00AED6},
    {'id': 'ovo', 'label': 'OVO', 'icon': '', 'emoji': '💜', 'color': 0xFF4C3494},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  int get _periodDays => _selectedPeriod == '15 Hari' ? 15 : 30;
  int get _jatipDibayar => widget.transaction.totalFee;
  // Jika transaksi macet, hitung dari hari ini bukan dari dateDue yang sudah lewat
  DateTime get _baseDate => widget.transaction.dateDue.isBefore(DateTime.now())
      ? DateTime.now()
      : widget.transaction.dateDue;
  DateTime get _newDueDate => _baseDate.add(Duration(days: _periodDays));

  // Total tebusan untuk mode redeem
  int get _totalRedemption => widget.transaction.principal + widget.transaction.totalFee;

  // Jumlah yang harus dibayar tergantung mode
  int get _amountToPay => widget.isRedemption ? _totalRedemption : _jatipDibayar;

  void _processPayment() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih metode pembayaran terlebih dahulu'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    final svc = SupabaseGadaiService.instance;
    final tx = widget.transaction;
    final methodLabel = _methods.firstWhere((m) => m['id'] == _selectedMethod)['label'] as String;

    try {
      // Simulate Midtrans processing delay
      await Future.delayed(const Duration(milliseconds: 2800));
      if (!mounted) return;

      if (widget.isRedemption) {
        // ── TEBUS BARANG (LUNAS) ──
        await svc.updateTransactionStatus(tx.id, 'Lunas');
        tx.redeem();
        // Log tebus barang
        unawaited(svc.logNasabahRedeemed(tx.customerId, tx.id, '${tx.brand} ${tx.model}', _amountToPay));
      } else {
        // ── PERPANJANG TENOR ──
        final oldDueDate = tx.dateDue;
        final jatipDibayar = _jatipDibayar;
        final days = _periodDays;
        final newDueDate = oldDueDate.add(Duration(days: days));
        final newTotalFee = tx.dailyFee * days;
        final newTotalRepayment = tx.principal + newTotalFee;

        await svc.createExtension(
          ExtensionHistory(
            id: '',
            transactionId: tx.id,
            jatipDibayar: jatipDibayar,
            tglPerpanjangan: DateTime.now(),
            tglTempoLama: oldDueDate,
            tglTempoBaru: newDueDate,
          ),
          paymentMethod: methodLabel,
        );

        await svc.updateTransactionStatus(
          tx.id, 'Aktif',
          newDueDate: newDueDate,
          periodDays: days,
          totalFee: newTotalFee,
          totalRepayment: newTotalRepayment,
        );

        tx.dateDue = newDueDate;
        tx.status = 'Aktif';
        // dateApplied TIDAK diubah — tetap tanggal gadai pertama kali
        tx.periodDays = days;
        tx.totalFee = newTotalFee;
        tx.totalRepayment = newTotalRepayment;
        
        // Log perpanjangan tenor
        unawaited(svc.logExtensionRequested(tx.customerId, tx.id));
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NasabahPaymentSuccessPage(
            transaction: tx,
            jatipDibayar: _amountToPay,
            newDueDate: widget.isRedemption ? DateTime.now() : tx.dateDue,
            paymentMethod: methodLabel,
            isRedemption: widget.isRedemption,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pembayaran gagal: $e'), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isRedemption ? 'Tebus Barang Jaminan' : 'Bayar Jasa Titip';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _isProcessing
            ? const SizedBox()
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF003F88),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'midtrans',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(title, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: _isProcessing ? _buildProcessingView() : _buildPaymentForm(),
      bottomNavigationBar: _isProcessing ? null : _buildPayButton(),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF003F88).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF003F88),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text('Memproses Pembayaran...', style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Mohon tunggu, jangan tutup aplikasi', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 6),
                Text('Terhubung ke Midtrans Secure Payment', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isRedemption
                    ? [const Color(0xFF065F46), const Color(0xFF10B981)]
                    : [const Color(0xFF003F88), const Color(0xFF0057BE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isRedemption ? 'Total Tebusan (Pokok + Jasa)' : 'Jasa Titip Wajib Dibayar',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(widget.transaction.id, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Rp ${_formatCurrency(_amountToPay)}',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jaminan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('${widget.transaction.brand} ${widget.transaction.model}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (widget.isRedemption) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pokok Pinjaman', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Rp ${_formatCurrency(widget.transaction.principal)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jasa Titip', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Rp ${_formatCurrency(widget.transaction.totalFee)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jatuh Tempo Saat Ini', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_formatDate(widget.transaction.dateDue), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tenor Selection — ONLY for perpanjang, not redeem
          if (!widget.isRedemption) ...[
            const Text('Tenor Perpanjangan', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: ['15 Hari', '30 Hari'].map((p) {
                final selected = _selectedPeriod == p;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPeriod = p),
                    child: Container(
                      margin: EdgeInsets.only(right: p == '15 Hari' ? 10 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Text(p, style: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Tempo baru: ${_formatDate(_newDueDate)}', style: TextStyle(color: selected ? Colors.white70 : AppColors.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Redemption info box
          if (widget.isRedemption) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Setelah pembayaran berhasil, barang jaminan Anda siap diambil di cabang.',
                      style: TextStyle(color: Color(0xFF065F46), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Payment Methods
          const Text('Metode Pembayaran', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          // Group: Virtual Account
          _buildMethodGroupLabel('Virtual Account'),
          const SizedBox(height: 8),
          ..._methods.where((m) => (m['id'] as String).contains('_va')).map(_buildMethodTile),
          const SizedBox(height: 14),

          // Group: Dompet Digital
          _buildMethodGroupLabel('Dompet Digital & QRIS'),
          const SizedBox(height: 8),
          ..._methods.where((m) => !(m['id'] as String).contains('_va')).map(_buildMethodTile),
          const SizedBox(height: 20),

          // Security badge
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981), size: 14),
                const SizedBox(width: 4),
                Text('Transaksi aman dienkripsi SSL 256-bit oleh Midtrans', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMethodGroupLabel(String label) {
    return Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600));
  }

  Widget _buildMethodTile(Map<String, Object> method) {
    final isSelected = _selectedMethod == method['id'];
    final color = Color(method['color'] as int);
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method['id'] as String),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(method['emoji'] as String, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(method['label'] as String, style: TextStyle(color: isSelected ? color : AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600))),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20)
            else
              const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    final buttonColor = widget.isRedemption ? const Color(0xFF065F46) : const Color(0xFF003F88);
    final buttonText = widget.isRedemption
        ? 'Tebus Rp ${_formatCurrency(_amountToPay)}'
        : 'Bayar Rp ${_formatCurrency(_amountToPay)}';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.isRedemption ? Icons.redeem_rounded : Icons.lock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                buttonText,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
