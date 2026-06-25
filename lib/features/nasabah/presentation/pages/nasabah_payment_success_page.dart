import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';

class NasabahPaymentSuccessPage extends StatefulWidget {
  final PawnTransaction transaction;
  final int jatipDibayar;
  final DateTime newDueDate;
  final String paymentMethod;

  const NasabahPaymentSuccessPage({
    super.key,
    required this.transaction,
    required this.jatipDibayar,
    required this.newDueDate,
    required this.paymentMethod,
  });

  @override
  State<NasabahPaymentSuccessPage> createState() => _NasabahPaymentSuccessPageState();
}

class _NasabahPaymentSuccessPageState extends State<NasabahPaymentSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context); // back to detail page
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
            onPressed: () => Navigator.pop(context), // kembali ke detail transaksi
          ),
          title: const Text(
            'Pembayaran Berhasil',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  // Animated checkmark
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 58),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Pembayaran Berhasil!',
                    style: TextStyle(color: AppColors.textDark, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tenor gadai Anda berhasil diperpanjang secara otomatis',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Receipt Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF003F88),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text('Bukti Pembayaran', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${_formatCurrency(widget.jatipDibayar)}',
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(widget.paymentMethod, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),

                        // Details
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _receiptRow('Order ID', 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'),
                              const SizedBox(height: 12),
                              _receiptRow('ID Transaksi Gadai', widget.transaction.id),
                              const SizedBox(height: 12),
                              _receiptRow('Barang Jaminan', '${widget.transaction.brand} ${widget.transaction.model}'),
                              const SizedBox(height: 12),
                              const Divider(color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 12),
                              _receiptRow('Tenor Diperpanjang', '${widget.transaction.periodDays} Hari'),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Jatuh Tempo Baru', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                  Text(
                                    _formatDate(widget.newDueDate),
                                    style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Tebusan Berikutnya', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                  Text(
                                    'Rp ${_formatCurrency(widget.transaction.totalRepayment)}',
                                    style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Midtrans branding
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 12),
                              const SizedBox(width: 4),
                              Text('Pembayaran diproses oleh Midtrans', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Back to Home Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        // Pop success page + detail page → kembali ke dashboard
                        Navigator.of(context)
                          ..pop() // tutup success page
                          ..pop(); // tutup detail transaksi
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Kembali ke Beranda', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context), // kembali ke detail transaksi
                    child: const Text('Lihat Detail Transaksi', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
