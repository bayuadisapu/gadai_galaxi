import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TaksiranResult {
  final String hargaPasarMin;
  final String hargaPasarMax;
  final String rekomendasiGadai;
  final String catatan;

  TaksiranResult({
    required this.hargaPasarMin,
    required this.hargaPasarMax,
    required this.rekomendasiGadai,
    required this.catatan,
  });
}

class GeminiTaksiranService {
  static String get _apiKey => dotenv.get('GEMINI_API_KEY', fallback: '');
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static Future<TaksiranResult> getTaksiran({
    required String jenis,
    required String merk,
    required String model,
    required String kondisi,
  }) async {
    final prompt = '''
Kamu adalah asisten ahli gadai elektronik di Indonesia. 
Berikan estimasi harga pasar bekas dan rekomendasi taksiran gadai untuk barang berikut:

Jenis Barang: $jenis
Merk: $merk
Model/Tipe: $model
Kondisi: $kondisi

Jawab HANYA dalam format JSON berikut (tanpa markdown, tanpa teks lain):
{
  "harga_pasar_min": "Rp X.XXX.XXX",
  "harga_pasar_max": "Rp X.XXX.XXX",
  "rekomendasi_gadai": "Rp X.XXX.XXX",
  "catatan": "penjelasan singkat max 1 kalimat"
}

Rekomendasi gadai adalah 65-75% dari harga pasar tengah.
Sesuaikan dengan kondisi pasar Indonesia terkini.
''';

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 256,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal menghubungi AI: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

    // Bersihkan jika ada sisa markdown
    final cleaned = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final json = jsonDecode(cleaned);

    return TaksiranResult(
      hargaPasarMin: json['harga_pasar_min'] ?? '-',
      hargaPasarMax: json['harga_pasar_max'] ?? '-',
      rekomendasiGadai: json['rekomendasi_gadai'] ?? '-',
      catatan: json['catatan'] ?? '',
    );
  }
}
