import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';

class NasabahPaymentSuccessPage extends StatefulWidget {
  final PawnTransaction transaction;
  final int jatipDibayar;
  final DateTime newDueDate;
  final String paymentMethod;
  final bool isRedemption;

  const NasabahPaymentSuccessPage({
    super.key,
    required this.transaction,
    required this.jatipDibayar,
    required this.newDueDate,
    required this.paymentMethod,
    this.isRedemption = false,
  });

  @override
  State<NasabahPaymentSuccessPage> createState() => _NasabahPaymentSuccessPageState();
}

class _NasabahPaymentSuccessPageState extends State<NasabahPaymentSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _headerSlideAnim;
  late Animation<Offset> _cardSlideAnim;
  late Animation<Offset> _buttonSlideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );
    
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    
    _headerSlideAnim = Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.6, curve: Curves.easeOutQuad)),
    );
    
    _cardSlideAnim = Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.8, curve: Curves.easeOutQuad)),
    );
    
    _buttonSlideAnim = Tween<Offset>(begin: const Offset(0.0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeOutQuad)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label berhasil disalin ke papan klip', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: AppColors.emerald,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRedeem = widget.isRedemption;
    final themeGradient = isRedeem
        ? const LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [AppColors.navyMid, AppColors.royalBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isRedeem ? 'Tebusan Berhasil' : 'Pembayaran Berhasil',
            style: GoogleFonts.outfit(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Animated checkmark
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isRedeem 
                                ? [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)]
                                : [AppColors.iceBlue, const Color(0xFFDBEAFE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isRedeem ? AppColors.emerald : AppColors.primary).withOpacity(0.15),
                                blurRadius: 24,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            isRedeem ? Icons.check_circle_rounded : Icons.offline_pin_rounded,
                            color: isRedeem ? const Color(0xFF059669) : AppColors.primary,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Status Header Text
                      SlideTransition(
                        position: _headerSlideAnim,
                        child: Column(
                          children: [
                            Text(
                              isRedeem ? 'Tebusan Berhasil!' : 'Pembayaran Berhasil!',
                              style: GoogleFonts.outfit(
                                color: AppColors.textDark, 
                                fontSize: 24, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                isRedeem
                                    ? 'Barang jaminan Anda siap diambil di cabang terdaftar.'
                                    : 'Tenor gadai Anda berhasil diperpanjang secara otomatis.',
                                style: GoogleFonts.inter(
                                  color: AppColors.textMuted, 
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Pickup notice for redemption
                      if (isRedeem) ...[
                        const SizedBox(height: 20),
                        SlideTransition(
                          position: _headerSlideAnim,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded, color: Color(0xFF047857), size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Silakan datang ke cabang dengan membawa bukti tebusan ini untuk mengambil barang jaminan Anda.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF065F46), 
                                      fontSize: 12, 
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Receipt Card (Physical Ticket Design)
                      SlideTransition(
                        position: _cardSlideAnim,
                        child: Column(
                          children: [
                            // Ticket Top Header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: themeGradient,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, -4),
                                  )
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    isRedeem ? 'BUKTI PELUNASAN TEBUSAN' : 'BUKTI PERPANJANGAN GADAI',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.7), 
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Rp ${_formatCurrency(widget.jatipDibayar)}',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white, 
                                      fontSize: 32, 
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.payment_rounded, color: Colors.white, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          widget.paymentMethod.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            color: Colors.white, 
                                            fontSize: 11, 
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Ticket Separator (Notches + Dash Line)
                            _buildTicketSeparator(),

                            // Ticket Bottom Body
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                                    child: Column(
                                      children: [
                                        _receiptRow(
                                          icon: Icons.tag_rounded,
                                          label: 'Order ID', 
                                          value: 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                          enableCopy: true,
                                        ),
                                        const SizedBox(height: 12),
                                        _receiptRow(
                                          icon: Icons.receipt_long_outlined,
                                          label: 'ID Transaksi', 
                                          value: widget.transaction.id,
                                          enableCopy: true,
                                        ),
                                        const SizedBox(height: 12),
                                        _receiptRow(
                                          icon: Icons.inventory_2_outlined,
                                          label: 'Barang Jaminan', 
                                          value: '${widget.transaction.brand} ${widget.transaction.model}',
                                        ),
                                        const SizedBox(height: 14),
                                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                                        const SizedBox(height: 14),
                                        if (isRedeem) ...[
                                          _receiptRow(
                                            icon: Icons.check_circle_outline_rounded,
                                            label: 'Status Pelunasan', 
                                            value: 'LUNAS',
                                            valueColor: const Color(0xFF059669),
                                          ),
                                          const SizedBox(height: 12),
                                          _receiptRow(
                                            icon: Icons.calendar_today_outlined,
                                            label: 'Tgl Pelunasan', 
                                            value: _formatDate(DateTime.now()),
                                          ),
                                        ] else ...[
                                          _receiptRow(
                                            icon: Icons.timer_outlined,
                                            label: 'Tenor Ditambahkan', 
                                            value: '${widget.transaction.periodDays} Hari',
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.event_available_outlined, color: AppColors.textMuted, size: 16),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Jatuh Tempo Baru', 
                                                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                _formatDate(widget.newDueDate),
                                                style: GoogleFonts.inter(
                                                  color: AppColors.primary, 
                                                  fontSize: 13, 
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.payments_outlined, color: AppColors.textMuted, size: 16),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Total Tebusan Berikutnya', 
                                                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                'Rp ${_formatCurrency(widget.transaction.totalRepayment)}',
                                                style: GoogleFonts.outfit(
                                                  color: AppColors.textDark, 
                                                  fontSize: 14, 
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Midtrans secure verification banner inside ticket
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.verified_user_outlined, color: Color(0xFF059669), size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Transaksi aman diproses oleh Midtrans', 
                                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Back to Home & Details Buttons
                      SlideTransition(
                        position: _buttonSlideAnim,
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.25),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context)
                                      ..pop() // tutup success page
                                      ..pop(); // tutup detail transaksi
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Kembali ke Beranda', 
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  backgroundColor: Colors.white,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.receipt_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Lihat Detail Transaksi', 
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketSeparator() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          // Left Notch
          Container(
            width: 12,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.surface, // Blends with background to create punch-hole illusion
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ),
          // Dashed Line
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boxWidth = constraints.constrainWidth();
                const dashWidth = 6.0;
                const dashHeight = 1.2;
                final dashCount = (boxWidth / (2 * dashWidth)).floor();
                return Flex(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  direction: Axis.horizontal,
                  children: List.generate(dashCount, (_) {
                    return const SizedBox(
                      width: dashWidth,
                      height: dashHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xFFE2E8F0)),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          // Right Notch
          Container(
            width: 12,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.surface, // Blends with background to create punch-hole illusion
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow({
    required IconData icon,
    required String label, 
    required String value,
    Color? valueColor,
    bool enableCopy = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 16),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value, 
                  style: GoogleFonts.inter(
                    color: valueColor ?? AppColors.textDark, 
                    fontSize: 13, 
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (enableCopy) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: () => _copyToClipboard(value, label),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
