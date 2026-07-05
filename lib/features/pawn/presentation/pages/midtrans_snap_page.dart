import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';

enum MidtransResult { success, pending, failed, cancelled }

class MidtransSnapPage extends StatefulWidget {
  final String snapUrl;
  final String orderId;

  const MidtransSnapPage({super.key, required this.snapUrl, required this.orderId});

  @override
  State<MidtransSnapPage> createState() => _MidtransSnapPageState();
}

class _MidtransSnapPageState extends State<MidtransSnapPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  MidtransResult? _result;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onNavigationRequest: (req) {
          final url = req.url.toLowerCase();

          // Deteksi hasil pembayaran dari URL callback
          if (url.contains('transaction_status=capture') ||
              url.contains('transaction_status=settlement') ||
              url.contains('/finish') && !url.contains('error')) {
            _handleResult(MidtransResult.success);
            return NavigationDecision.prevent;
          }
          if (url.contains('transaction_status=pending') || url.contains('/pending')) {
            _handleResult(MidtransResult.pending);
            return NavigationDecision.prevent;
          }
          if (url.contains('transaction_status=deny') ||
              url.contains('transaction_status=cancel') ||
              url.contains('transaction_status=expire') ||
              url.contains('/error')) {
            _handleResult(MidtransResult.failed);
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
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

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
      ),
    );
  }
}
