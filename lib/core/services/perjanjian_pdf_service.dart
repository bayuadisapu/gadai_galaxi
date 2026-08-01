import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';

class PerjanjianPdfService {
  static final PerjanjianPdfService instance = PerjanjianPdfService._();
  PerjanjianPdfService._();

  // ── Helpers ──────────────────────────────────────────────────
  String _fmt(int val) {
    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _fmtDateLong(DateTime d) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ];
    final dayName = days[d.weekday - 1];
    return '$dayName, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _fmtDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.year}';

  // ── Main: Generate PDF ───────────────────────────────────────
  Future<File> generatePerjanjianPdf({
    required PawnTransaction tx,
    required Customer customer,
    required String petugasName,
  }) async {
    final pdf = pw.Document();

    final displayCode = tx.transactionCode.isNotEmpty
        ? tx.transactionCode
        : tx.id.substring(0, 10).toUpperCase();

    final dateAppliedLong  = _fmtDateLong(tx.dateApplied);
    final dateDueLong      = _fmtDateLong(tx.dateDue);
    final dateAppliedShort = _fmtDateShort(tx.dateApplied);
    final dateDueShort     = _fmtDateShort(tx.dateDue);

    // ── Color palette ──
    const primaryColor = PdfColor.fromInt(0xFF2563EB);
    const darkColor    = PdfColor.fromInt(0xFF0F172A);
    const mutedColor   = PdfColor.fromInt(0xFF64748B);
    const lightBlue    = PdfColor.fromInt(0xFFEFF6FF);
    const borderColor  = PdfColor.fromInt(0xFFCBD5E1);
    const redColor     = PdfColor.fromInt(0xFFDC2626);

    // ── Text styles ──
    final headStyle  = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkColor);
    final bold11     = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkColor);
    final regular10  = pw.TextStyle(fontSize: 10, color: darkColor);
    final mutedStyle = pw.TextStyle(fontSize: 9, color: mutedColor);
    final titleStyle = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkColor, letterSpacing: 1.5);

    // ── Label-value row helper ──
    pw.Widget docRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 130,
                child: pw.Text(label, style: mutedStyle),
              ),
              pw.Text(': ', style: mutedStyle),
              pw.Expanded(child: pw.Text(value, style: bold11)),
            ],
          ),
        );

    // ── Pasal title ──
    pw.Widget pasalTitle(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
        );

    // ── Keuangan key-value row ──
    pw.Widget kRow(String label, String value, {bool isTotal = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: isTotal ? bold11 : mutedStyle),
              pw.Text(
                value,
                style: isTotal
                    ? pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)
                    : bold11,
              ),
            ],
          ),
        );

    // ══ ADD PAGE ══
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Dokumen digenerate otomatis oleh sistem GALAXI GADAI | $dateAppliedShort | Hal ${ctx.pageNumber}/${ctx.pagesCount}',
            style: mutedStyle,
          ),
        ),
        build: (pw.Context context) => [

          // ── HEADER ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('GALAXI GADAI',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 18,
                          fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                  pw.SizedBox(height: 3),
                  pw.Text('Jl. Mt Haryono no 29, Samping Gereja Imanuel Buol',
                      style: pw.TextStyle(color: const PdfColor(1, 1, 1, 0.75), fontSize: 8.5)),
                  pw.Text('WA: 085181582929 / 082291211990',
                      style: pw.TextStyle(color: const PdfColor(1, 1, 1, 0.75), fontSize: 8.5)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('No. Kontrak',
                      style: pw.TextStyle(color: const PdfColor(1, 1, 1, 0.75), fontSize: 9)),
                  pw.Text(displayCode,
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── JUDUL DOKUMEN ──
          pw.Center(
            child: pw.Column(children: [
              pw.Text('PERJANJIAN GADAI BARANG', style: titleStyle),
              pw.SizedBox(height: 4),
              pw.Container(width: 80, height: 1.5, color: darkColor),
            ]),
          ),
          pw.SizedBox(height: 12),

          // ── INFO CHIPS ──
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBlue,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Tgl. Gadai', style: mutedStyle),
                  pw.Text(dateAppliedShort, style: bold11),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                  pw.Text('Petugas', style: mutedStyle),
                  pw.Text(petugasName, style: bold11),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Jatuh Tempo', style: mutedStyle),
                  pw.Text(dateDueShort,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: redColor)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ── OPENING ──
          pw.Text(
            'Pada hari ini $dateAppliedLong telah dibuat dan disepakati Perjanjian Gadai Barang '
            'dengan nomor kontrak $displayCode antara:',
            style: regular10,
          ),
          pw.SizedBox(height: 14),

          // ── PIHAK PERTAMA ──
          pw.Text('Pihak Pertama (Penggadai)', style: headStyle),
          pw.SizedBox(height: 6),
          docRow('Nama Outlet', 'GALAXI GADAI'),
          docRow('Alamat Outlet',
              'Jl. Mt Haryono no 29 Samping gereja Imanuel Buol\nWA: 085181582929 / 082291211990'),
          docRow('Petugas', petugasName),
          pw.SizedBox(height: 14),

          // ── PIHAK KEDUA ──
          pw.Text('Pihak Kedua (Nasabah)', style: headStyle),
          pw.SizedBox(height: 6),
          docRow('Nama Nasabah', customer.name),
          docRow('Tempat/Tgl. Lahir',
              customer.birthPlace.isNotEmpty
                  ? '${customer.birthPlace}, ${customer.birthDate}'
                  : customer.birthDate.isNotEmpty ? customer.birthDate : '-'),
          docRow('Jenis Kelamin', customer.gender.isNotEmpty ? customer.gender : '-'),
          docRow('Alamat', customer.address.isNotEmpty ? customer.address : '-'),
          docRow('No. HP / WA', customer.phone.isNotEmpty ? customer.phone : '-'),
          pw.SizedBox(height: 14),
          pw.Divider(color: borderColor, thickness: 0.6),
          pw.SizedBox(height: 10),

          // ── PASAL 1 ──
          pasalTitle('Pasal 1 — Barang Gadai'),
          docRow('Jenis Barang', tx.collateralType),
          docRow('Merk / Tipe', '${tx.brand} / ${tx.model}'),
          docRow('Kondisi Barang', tx.condition.isNotEmpty ? tx.condition : 'Sangat Baik'),
          docRow('Nilai Gadai', 'Rp ${_fmt(tx.principal)}'),
          pw.SizedBox(height: 14),

          // ── PASAL 2 ──
          pasalTitle('Pasal 2 — Nilai Gadai & Biaya'),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBlue,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Column(children: [
              kRow('Nominal Pinjaman (N)', 'Rp ${_fmt(tx.principal)}'),
              kRow('Jasa Titip Harian', 'Rp ${_fmt(tx.dailyFee)} / hari'),
              kRow('Periode Gadai', '${tx.periodDays} hari'),
              kRow('Total Jasa Titip', 'Rp ${_fmt(tx.totalFee)}'),
              pw.Divider(color: borderColor, thickness: 0.4),
              kRow('TOTAL TEBUSAN', 'Rp ${_fmt(tx.principal + tx.totalFee)}', isTotal: true),
            ]),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '1. Pada saat penebusan, Pihak Kedua wajib membayar: '
            'Rp ${_fmt(tx.principal)} + Rp ${_fmt(tx.dailyFee)} × Jumlah Hari Gadai.',
            style: regular10,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '2. Apabila penebusan dilakukan setelah melewati jatuh tempo, '
            'dikenakan biaya tambahan sesuai ketentuan yang berlaku.',
            style: regular10,
          ),
          pw.SizedBox(height: 14),

          // ── PASAL 3 ──
          pasalTitle('Pasal 3 — Jangka Waktu'),
          pw.Text('Perjanjian berlaku sejak $dateAppliedLong', style: regular10),
          pw.Text('Jatuh Tempo tanggal $dateDueLong', style: regular10),
          pw.SizedBox(height: 4),
          pw.Text(
            'Apabila dalam 5 hari setelah tanggal jatuh tempo barang belum diperpanjang '
            'atau ditebus, maka barang akan DILELANG sesuai ketentuan yang berlaku.',
            style: regular10,
          ),
          pw.SizedBox(height: 14),

          // ── PASAL 4 ──
          pasalTitle('Pasal 4 — Tanggung Jawab'),
          pw.Text(
            '1. Barang menjadi tanggungan GALAXI GADAI selama masa gadai.\n'
            '2. Pihak Kedua menjamin bahwa barang bukan hasil tindak kejahatan dan merupakan milik pribadi.\n'
            '3. Barang yang telah dilelang tidak dapat diklaim kembali oleh nasabah.',
            style: regular10,
          ),
          pw.SizedBox(height: 14),

          // ── PASAL 5 ──
          pasalTitle('Pasal 5 — Penyelesaian Sengketa'),
          pw.Text(
            'Apabila terjadi perselisihan, kedua pihak sepakat menyelesaikan secara musyawarah. '
            'Jika tidak tercapai, diselesaikan sesuai hukum yang berlaku di Republik Indonesia.',
            style: regular10,
          ),
          pw.SizedBox(height: 14),

          // ── PASAL 6 ──
          pasalTitle('Pasal 6 — Penutup'),
          pw.Text(
            'Perjanjian ini dibuat secara sah dan mengikat kedua belah pihak tanpa paksaan. '
            'Dokumen elektronik ini memiliki kekuatan hukum yang sama dengan dokumen fisik '
            'berdasarkan UU ITE No. 11 Tahun 2008.',
            style: regular10,
          ),
          pw.SizedBox(height: 36),

          // ── TANDA TANGAN ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('PIHAK PERTAMA', style: mutedStyle),
                pw.SizedBox(height: 44),
                pw.Container(width: 110, height: 0.8, color: borderColor),
                pw.SizedBox(height: 4),
                pw.Text(petugasName, style: bold11),
                pw.Text('(GALAXI GADAI)', style: mutedStyle),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('PIHAK KEDUA', style: mutedStyle),
                pw.SizedBox(height: 44),
                pw.Container(width: 110, height: 0.8, color: borderColor),
                pw.SizedBox(height: 4),
                pw.Text(customer.name, style: bold11),
                pw.Text('(Nasabah)', style: mutedStyle),
              ]),
            ],
          ),
        ],
      ),
    );

    // ── Simpan ke temp directory ──
    final dir = await getTemporaryDirectory();
    final safeCode = displayCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${dir.path}/Perjanjian_$safeCode.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
