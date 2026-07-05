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

  // Urutan: pakai model dengan free tier limit TINGGI dulu (1500 RPD)
  // Hindari gemini-3.5-flash / gemini-flash-latest (hanya 20 RPD)
  static const List<String> _models = [
    'gemini-2.5-flash-lite',   // ✓ bekerja, free tier luas
    'gemini-2.5-flash',        // fallback — lebih besar
    'gemini-2.0-flash-lite',   // fallback
    'gemini-2.0-flash',        // fallback
  ];

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static Future<TaksiranResult> getTaksiran({
    required String jenis,
    required String merk,
    required String model,
    required String kondisi,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY belum dikonfigurasi di file .env');
    }

    final prompt = '''
Kamu adalah asisten ahli gadai di Indonesia. 
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

    final body = jsonEncode({
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
    });

    Exception? lastError;
    for (final modelName in _models) {
      try {
        final url = '$_baseUrl/$modelName:generateContent';
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': _apiKey,
          },
          body: body,
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 401) {
          throw Exception(
            'API Key tidak valid atau sudah expired.\n'
            'Dapatkan API Key baru di: aistudio.google.com/apikey',
          );
        }

        if (response.statusCode == 429) {
          // Rate limit pada model ini — coba model berikutnya
          lastError = Exception('Rate limit pada model $modelName, mencoba model lain...');
          continue;
        }

        if (response.statusCode != 200) {
          if (response.statusCode == 404) {
            lastError = Exception('Model $modelName tidak tersedia');
            continue;
          }
          // Coba model berikutnya untuk error server lainnya
          lastError = Exception('Error ${response.statusCode} dari model $modelName');
          continue;
        }


        final data = jsonDecode(response.body);
        
        // Validasi response structure
        if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
          throw Exception('Respons AI kosong — coba lagi.');
        }

        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

        // Bersihkan jika ada sisa markdown
        final cleaned = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        // Cari JSON object di dalam teks jika ada teks lain
        final jsonStart = cleaned.indexOf('{');
        final jsonEnd = cleaned.lastIndexOf('}');
        if (jsonStart == -1 || jsonEnd == -1) {
          throw Exception('Format respons AI tidak valid — coba lagi.');
        }
        final jsonStr = cleaned.substring(jsonStart, jsonEnd + 1);
        final json = jsonDecode(jsonStr);

        return TaksiranResult(
          hargaPasarMin: json['harga_pasar_min'] ?? '-',
          hargaPasarMax: json['harga_pasar_max'] ?? '-',
          rekomendasiGadai: json['rekomendasi_gadai'] ?? '-',
          catatan: json['catatan'] ?? '',
        );
      } catch (e) {
        if (e.toString().contains('API Key') || 
            e.toString().contains('Rate limit') ||
            e.toString().contains('Error dari server')) {
          rethrow; // Error fatal, tidak perlu coba model lain
        }
        lastError = e is Exception ? e : Exception(e.toString());
        continue; // Coba model berikutnya
      }
    }

    throw lastError ?? Exception('Semua model Gemini gagal dipanggil');
  }
}
