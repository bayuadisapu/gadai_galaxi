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
///   - metals.live   → harga XAU dalam USD
///   - open.er-api   → kurs USD/IDR
/// Hasil di-cache 1 jam agar tidak spam API.
class GoldPriceService {
  GoldPriceService._();

  // ─── Cache ───────────────────────────────────────────
  static int _cachedPriceIdr = 0;
  static DateTime? _lastFetched;
  static const _cacheDuration = Duration(hours: 1);

  /// Harga fallback jika kedua API gagal (perbarui manual tiap bulan)
  static const int _fallbackPrice = 1_620_000;

  static bool get _isCacheValid {
    if (_lastFetched == null || _cachedPriceIdr == 0) return false;
    return DateTime.now().difference(_lastFetched!) < _cacheDuration;
  }

  // ─── Public API ──────────────────────────────────────

  /// Ambil harga emas 24K dalam IDR per gram.
  /// Returns cached value jika belum 1 jam.
  static Future<GoldPriceResult> fetchGoldPrice() async {
    if (_isCacheValid) {
      return GoldPriceResult(
        pricePerGram: _cachedPriceIdr,
        isLive: true,
        lastUpdatedLabel: _formatTime(_lastFetched!),
      );
    }

    try {
      // 1. Harga XAU (troy oz) dalam USD — metals.live (free, no key)
      final goldRes = await http
          .get(
            Uri.parse('https://api.metals.live/v1/spot'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (goldRes.statusCode != 200) {
        throw Exception('metals.live: ${goldRes.statusCode}');
      }

      final goldList = jsonDecode(goldRes.body) as List<dynamic>;
      double? xauUsd;
      for (final item in goldList) {
        if (item is Map && item.containsKey('gold')) {
          xauUsd = (item['gold'] as num).toDouble();
          break;
        }
      }
      if (xauUsd == null) throw Exception('Gold price tidak ditemukan');

      // 2. Kurs USD/IDR — open.er-api.com (free, no key)
      final fxRes = await http
          .get(
            Uri.parse('https://open.er-api.com/v6/latest/USD'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (fxRes.statusCode != 200) {
        throw Exception('er-api: ${fxRes.statusCode}');
      }

      final fxData = jsonDecode(fxRes.body) as Map<String, dynamic>;
      final usdToIdr = (fxData['rates']['IDR'] as num).toDouble();

      // 3. Hitung IDR per gram (1 troy oz = 31.1035 gram)
      final priceGram = ((xauUsd * usdToIdr) / 31.1035).round();

      _cachedPriceIdr = priceGram;
      _lastFetched = DateTime.now();

      debugPrint('[GoldPrice] XAU/USD=$xauUsd | USD/IDR=$usdToIdr | IDR/g=$priceGram');

      return GoldPriceResult(
        pricePerGram: priceGram,
        isLive: true,
        lastUpdatedLabel: _formatTime(_lastFetched!),
      );
    } catch (e) {
      debugPrint('[GoldPrice] Error: $e → fallback $_fallbackPrice');
      return GoldPriceResult(
        pricePerGram: _cachedPriceIdr > 0 ? _cachedPriceIdr : _fallbackPrice,
        isLive: false,
        lastUpdatedLabel: 'Referensi offline',
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
