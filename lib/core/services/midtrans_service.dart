import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MidtransService {
  static String get _serverKey => dotenv.get('MIDTRANS_SERVER_KEY', fallback: '');
  static String get _env => dotenv.get('MIDTRANS_ENV', fallback: 'sandbox');

  static String get _snapBaseUrl => _env == 'production'
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

  static String get _statusBaseUrl => _env == 'production'
      ? 'https://api.midtrans.com/v2'
      : 'https://api.sandbox.midtrans.com/v2';

  static String get _authHeader {
    final encoded = base64Encode(utf8.encode('$_serverKey:'));
    return 'Basic $encoded';
  }

  /// Buat Snap Token untuk pembayaran perpanjangan gadai
  static Future<Map<String, String>> createSnapToken({
    required String orderId,
    required int grossAmount,
    required String customerName,
    required String customerPhone,
    required String itemName,
  }) async {
    final body = jsonEncode({
      'transaction_details': {
        'order_id': orderId,
        'gross_amount': grossAmount,
      },
      'customer_details': {
        'first_name': customerName,
        'phone': customerPhone,
      },
      'item_details': [
        {
          'id': orderId,
          'price': grossAmount,
          'quantity': 1,
          'name': itemName,
        }
      ],
      'callbacks': {
        'finish': 'galaxigadai://payment/finish',
        'error': 'galaxigadai://payment/error',
        'pending': 'galaxigadai://payment/pending',
      },
    });

    final response = await http.post(
      Uri.parse(_snapBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': _authHeader,
      },
      body: body,
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'token': data['token'] as String? ?? '',
        'redirect_url': data['redirect_url'] as String? ?? '',
      };
    } else {
      throw Exception('Midtrans error ${response.statusCode}: ${response.body}');
    }
  }

  /// Cek status pembayaran berdasarkan order_id
  static Future<String> checkPaymentStatus(String orderId) async {
    final response = await http.get(
      Uri.parse('$_statusBaseUrl/$orderId/status'),
      headers: {'Authorization': _authHeader},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final txStatus = data['transaction_status'] as String? ?? 'unknown';
      final fraudStatus = data['fraud_status'] as String? ?? '';

      // Midtrans status mapping
      if (txStatus == 'capture' && fraudStatus == 'accept') return 'success';
      if (txStatus == 'settlement') return 'success';
      if (txStatus == 'pending') return 'pending';
      if (txStatus == 'deny' || txStatus == 'cancel' || txStatus == 'expire') return 'failed';
      return 'pending';
    }
    return 'unknown';
  }
}
