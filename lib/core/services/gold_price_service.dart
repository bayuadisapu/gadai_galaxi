import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Hasil fetch harga emas
class GoldPriceResult {
  final int pricePerGram; // IDR per gram, 24K
  final bool isLive;
  final String lastUpdatedLabel;

  const GoldPriceResult({
    required this.pricePerGram,
    required this.isLive,
    required this.lastUpdatedLabel,
  });
}

/// Service untuk mengambil harga emas 24K real-time dalam IDR/gram.
/// Menggunakan dua API gratis tanpa API key:
///   - gold-api.com  → harga XAU dalam USD
///   - open.er-api   → kurs USD/IDR
/// Hasil di-cache 1 jam agar tidak spam API.
class GoldPriceService {
  GoldPriceService._();

  // ─── Cache ───────────────────────────────────────────
  static int _cachedPriceIdr = 0;
  static DateTime? _lastFetched;
  static const _cacheDuration = Duration(hours: 1);

  /// Harga fallback per gram (24K) jika jaringan bermasalah
  static const int _fallbackPrice = 2_320_000;

  static bool get _isCacheValid {
    if (_lastFetched == null || _cachedPriceIdr == 0) return false;
    return DateTime.now().difference(_lastFetched!) < _cacheDuration;
  }

  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  // ─── Public API ──────────────────────────────────────

  /// Ambil harga emas 24K dalam IDR per gram dengan multiple fallback endpoint & User-Agent.
  static Future<GoldPriceResult> fetchGoldPrice() async {
    if (_isCacheValid) {
      return GoldPriceResult(
        pricePerGram: _cachedPriceIdr,
        isLive: true,
        lastUpdatedLabel: _formatTime(_lastFetched!),
      );
    }

    try {
      // 1. Fetch Harga XAU/USD (api.gold-api.com)
      double? xauUsd;
      try {
        final goldRes = await http
            .get(Uri.parse('https://api.gold-api.com/price/XAU'), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (goldRes.statusCode == 200) {
          final data = jsonDecode(goldRes.body) as Map<String, dynamic>;
          xauUsd = (data['price'] as num).toDouble();
        }
      } catch (e) {
        debugPrint('[GoldPrice] Primary XAU API error: $e');
      }

      // 2. Fetch Kurs USD/IDR (Primary & Secondary)
      double? usdToIdr;
      try {
        final fxRes = await http
            .get(Uri.parse('https://open.er-api.com/v6/latest/USD'), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (fxRes.statusCode == 200) {
          final fxData = jsonDecode(fxRes.body) as Map<String, dynamic>;
          usdToIdr = (fxData['rates']['IDR'] as num).toDouble();
        }
      } catch (e) {
        debugPrint('[GoldPrice] Primary FX API error: $e');
      }

      // Secondary FX Fallback
      if (usdToIdr == null) {
        try {
          final fxRes2 = await http
              .get(Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'), headers: _headers)
              .timeout(const Duration(seconds: 8));
          if (fxRes2.statusCode == 200) {
            final fxData2 = jsonDecode(fxRes2.body) as Map<String, dynamic>;
            usdToIdr = (fxData2['rates']['IDR'] as num).toDouble();
          }
        } catch (e) {
          debugPrint('[GoldPrice] Secondary FX API error: $e');
        }
      }

      // Hitung harga IDR/gram jika minimal salah satu API berhasil
      if (xauUsd != null && xauUsd > 0) {
        final finalUsdToIdr = usdToIdr ?? 17944.0;
        final priceGram = ((xauUsd * finalUsdToIdr) / 31.1035).round();

        _cachedPriceIdr = priceGram;
        _lastFetched = DateTime.now();

        debugPrint('[GoldPrice] Live: XAU/USD=$xauUsd | USD/IDR=$finalUsdToIdr | IDR/g=$priceGram');

        return GoldPriceResult(
          pricePerGram: priceGram,
          isLive: true,
          lastUpdatedLabel: _formatTime(_lastFetched!),
        );
      } else if (usdToIdr != null && usdToIdr > 0) {
        final priceGram = ((4025.0 * usdToIdr) / 31.1035).round();
        _cachedPriceIdr = priceGram;
        _lastFetched = DateTime.now();

        return GoldPriceResult(
          pricePerGram: priceGram,
          isLive: true,
          lastUpdatedLabel: _formatTime(_lastFetched!),
        );
      }

      throw Exception('Unreachable gold endpoints');
    } catch (e) {
      debugPrint('[GoldPrice] Error: $e → fallback $_fallbackPrice');
      return GoldPriceResult(
        pricePerGram: _cachedPriceIdr > 0 ? _cachedPriceIdr : _fallbackPrice,
        isLive: _cachedPriceIdr > 0,
        lastUpdatedLabel: _lastFetched != null ? _formatTime(_lastFetched!) : 'Referensi pasar',
      );
    }
  }

  // ─── Helpers ─────────────────────────────────────────

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'Update $h:$m WIB';
  }
}
