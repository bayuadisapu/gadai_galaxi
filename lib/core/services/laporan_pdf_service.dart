import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';

class LaporanPdfService {
  static final LaporanPdfService instance = LaporanPdfService._();
  LaporanPdfService._();

  String _fmt(int val) {
    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _fmtDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<File> generateLaporanPdf({
    required String title,
    required String periodeLabel,
    required String namaCabang,
    required String statusFilter,
    required List<PawnTransaction> transactions,
    required Map<String, String> customerNames,
    required Map<String, String> branchNames,
  }) async {
    final pdf = pw.Document();

    const primaryColor = PdfColor.fromInt(0xFF1E3A6E);
    const accentColor = PdfColor.fromInt(0xFF2563EB);
    const darkColor = PdfColor.fromInt(0xFF0F172A);
    const mutedColor = PdfColor.fromInt(0xFF64748B);
    const headerBg = PdfColor.fromInt(0xFFF1F5F9);
    const rowAltBg = PdfColor.fromInt(0xFFF8FAFC);

    final totalPokok = transactions.fold(0, (s, tx) => s + tx.principal);
    final totalJasa = transactions.fold(0, (s, tx) => s + tx.totalFee);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('GALAXI GADAI',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor)),
                    pw.Text(title.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: darkColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Cabang: $namaCabang',
                        style: pw.TextStyle(fontSize: 10, color: darkColor)),
                    pw.Text('Periode: $periodeLabel',
                        style: pw.TextStyle(fontSize: 10, color: darkColor)),
                    pw.Text('Filter Status: $statusFilter',
                        style: pw.TextStyle(fontSize: 10, color: mutedColor)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(color: primaryColor, thickness: 1.5),
            pw.SizedBox(height: 12),

            // Summary Cards Row
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: headerBg,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL TRANSAKSI',
                            style: pw.TextStyle(fontSize: 8, color: mutedColor)),
                        pw.Text('${transactions.length} Transaksi',
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: darkColor)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: headerBg,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL POKOK GADAI',
                            style: pw.TextStyle(fontSize: 8, color: mutedColor)),
                        pw.Text('Rp ${_fmt(totalPokok)}',
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: accentColor)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: headerBg,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL JASA TITIP',
                            style: pw.TextStyle(fontSize: 8, color: mutedColor)),
                        pw.Text('Rp ${_fmt(totalJasa)}',
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Table of Transactions
            pw.Table(
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(28),  // No
                1: pw.FixedColumnWidth(65),  // Tgl
                2: pw.FixedColumnWidth(85),  // No Kontrak
                3: pw.FixedColumnWidth(80),  // Cabang
                4: pw.FixedColumnWidth(90),  // Nasabah
                5: pw.FlexColumnWidth(2),    // Barang
                6: pw.FixedColumnWidth(80),  // Pokok
                7: pw.FixedColumnWidth(70),  // Jasa
                8: pw.FixedColumnWidth(55),  // Status
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: primaryColor),
                  children: [
                    'NO', 'TANGGAL', 'NO KONTRAK', 'CABANG', 'NASABAH', 'BARANG', 'POKOK (RP)', 'JASA (RP)', 'STATUS'
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: pw.Text(
                      h,
                      textAlign: (h.contains('POKOK') || h.contains('JASA')) ? pw.TextAlign.right : pw.TextAlign.left,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  )).toList(),
                ),
                // Data Rows
                ...transactions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final tx = entry.value;
                  final custName = customerNames[tx.customerId] ?? '-';
                  final branchName = branchNames[tx.cabangId] ?? tx.cabangId;
                  final isEven = idx % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : rowAltBg),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_fmtDateShort(tx.dateApplied), style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx.displayCode, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(branchName, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(custName, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${tx.brand} ${tx.model}', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rp ${_fmt(tx.principal)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rp ${_fmt(tx.totalFee)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx.status, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    ],
                  );
                }),
                // Total Summary Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: headerBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Rp ${_fmt(totalPokok)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accentColor)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Rp ${_fmt(totalJasa)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File('${outputDir.path}/laporan_gadai_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
