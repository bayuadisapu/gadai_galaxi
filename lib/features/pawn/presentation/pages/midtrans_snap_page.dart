import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/services/midtrans_service.dart';

enum MidtransResult { success, pending, failed, cancelled }

class MidtransSnapPage extends StatefulWidget {
  final String snapUrl;
  final String orderId;

  const MidtransSnapPage({super.key, required this.snapUrl, required this.orderId});

  @override
  State<MidtransSnapPage> createState() => _MidtransSnapPageState();
}

class _MidtransSnapPageState extends State<MidtransSnapPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  MidtransResult? _result;

  @override
  void initState() {
    super.initState();
    _initController();
    if (kIsWeb) {
      _isLoading = false;
      _launchPaymentUrl();
    }
  }

  void _initController() {
    if (kIsWeb) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onNavigationRequest: (req) {
          final url = req.url.toLowerCase();

          // Deteksi hasil pembayaran dari URL callback
          // Bug Fix: tambah kurung agar operator precedence benar
          // Cek FAILED lebih dulu agar '/finish?error=...' tidak salah masuk success
          if (url.contains('transaction_status=deny') ||
              url.contains('transaction_status=cancel') ||
              url.contains('transaction_status=expire') ||
              url.contains('/error')) {
            _handleResult(MidtransResult.failed);
            return NavigationDecision.prevent;
          }
          if (url.contains('transaction_status=pending') || url.contains('/pending')) {
            _handleResult(MidtransResult.pending);
            return NavigationDecision.prevent;
          }
          if (url.contains('transaction_status=capture') ||
              url.contains('transaction_status=settlement') ||
              (url.contains('/finish') && !url.contains('error'))) {
            _handleResult(MidtransResult.success);
            return NavigationDecision.prevent;
          }

          // Izinkan navigasi normal dalam Snap
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          // Ignore SSL/resource error minor — Snap kadang load banyak asset
        },
      ))
      ..loadRequest(Uri.parse(widget.snapUrl));
  }

  Future<void> _launchPaymentUrl() async {
    final url = Uri.parse(widget.snapUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Tidak bisa membuka URL pembayaran';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka link pembayaran otomatis: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyPayment() async {
    if (_isCheckingStatus) return;
    setState(() => _isCheckingStatus = true);

    try {
      final status = await MidtransService.checkPaymentStatus(widget.orderId);
      if (status == 'success') {
        _handleResult(MidtransResult.success);
      } else if (status == 'failed') {
        _handleResult(MidtransResult.failed);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏳ Pembayaran belum terdeteksi. Silakan selesaikan pembayaran Anda di tab baru.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengecek status pembayaran: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  void _handleResult(MidtransResult result) {
    if (_result != null) return; // Jangan handle 2x
    setState(() => _result = result);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  String _resultLabel() {
    switch (_result) {
      case MidtransResult.success: return 'Pembayaran Berhasil!';
      case MidtransResult.pending: return 'Menunggu Pembayaran...';
      case MidtransResult.failed: return 'Pembayaran Gagal';
      default: return '';
    }
  }

  Color _resultColor() {
    switch (_result) {
      case MidtransResult.success: return const Color(0xFF10B981);
      case MidtransResult.pending: return Colors.orange;
      case MidtransResult.failed: return Colors.red;
      default: return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Pembayaran Midtrans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(MidtransResult.cancelled),
        ),
      ),
      body: kIsWeb ? _buildWebUI() : _buildMobileWebView(),
    );
  }

  Widget _buildMobileWebView() {
    return Stack(
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Memuat halaman pembayaran...', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),

        // Result banner
        if (_result != null)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              color: _resultColor(),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_resultLabel(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
      ],
    );
  }

  Widget _buildWebUI() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cardBorder, width: 1),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon header with glow effect
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Gerbang Pembayaran Aman',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kami telah membuka halaman pembayaran Midtrans di tab baru browser Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecond,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Order info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.iceBlue,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'KODE TRANSAKSI (ORDER ID)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          widget.orderId,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFD0E1FD)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Menunggu Pembayaran',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecond,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isCheckingStatus ? null : _verifyPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isCheckingStatus
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Saya Sudah Membayar (Verifikasi)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _launchPaymentUrl,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Buka Ulang Halaman Pembayaran',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(MidtransResult.cancelled),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                    ),
                    child: const Text('Batalkan Transaksi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
