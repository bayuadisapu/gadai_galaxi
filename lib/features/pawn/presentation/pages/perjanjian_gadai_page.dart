import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:galaxi_gadai/core/services/perjanjian_pdf_service.dart';
import 'package:share_plus/share_plus.dart';

class PerjanjianGadaiPage extends StatefulWidget {
  final PawnTransaction transaction;
  final Customer customer;
  final String petugasName;

  const PerjanjianGadaiPage({
    super.key,
    required this.transaction,
    required this.customer,
    required this.petugasName,
  });

  @override
  State<PerjanjianGadaiPage> createState() => _PerjanjianGadaiPageState();
}

class _PerjanjianGadaiPageState extends State<PerjanjianGadaiPage> {
  bool _sendingWA = false;
  bool _downloadingPdf = false;

  Future<void> _downloadPdf() async {
    if (_downloadingPdf) return;
    setState(() => _downloadingPdf = true);
    try {
      final pdfFile = await PerjanjianPdfService.instance.generatePerjanjianPdf(
        tx: widget.transaction,
        customer: widget.customer,
        petugasName: widget.petugasName,
      );
      final displayCode = widget.transaction.transactionCode.isNotEmpty
          ? widget.transaction.transactionCode
          : widget.transaction.id.substring(0, 10).toUpperCase();
      final xFile = XFile(pdfFile.path, mimeType: 'application/pdf');
      await Share.shareXFiles(
        [xFile],
        subject: 'Perjanjian Gadai $displayCode - GALAXI GADAI',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal generate PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  String _formatCurrency(int val) {
    final s = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  String _formatIndonesianLongDate(DateTime date) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[date.weekday % 7];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  Future<void> _sendToWhatsApp() async {
    if (_sendingWA) return;
    setState(() => _sendingWA = true);
    try {
      final tx = widget.transaction;
      final cust = widget.customer;

      // 1. Generate PDF
      final pdfFile = await PerjanjianPdfService.instance.generatePerjanjianPdf(
        tx: tx,
        customer: cust,
        petugasName: widget.petugasName,
      );

      final displayCode = tx.transactionCode.isNotEmpty
          ? tx.transactionCode
          : tx.id.substring(0, 10).toUpperCase();

      // 2. Caption ringkasan
      final caption =
          'Halo *${cust.name}* 👋\n\n'
          'Terlampir *Surat Perjanjian Gadai* Anda dari GALAXI GADAI.\n\n'
          '📄 No. Kontrak : $displayCode\n'
          '📅 Tgl. Gadai  : ${_formatDateShort(tx.dateApplied)}\n'
          '⏰ Jatuh Tempo : ${_formatDateShort(tx.dateDue)}\n\n'
          'Simpan dokumen ini sebagai bukti perjanjian Anda.\n\n'
          '_GALAXI GADAI | Jl. Mt Haryono no 29, Buol_';

      // 3. Share via share_plus (user pilih WhatsApp dari share sheet)
      final xFile = XFile(pdfFile.path, mimeType: 'application/pdf');
      await Share.shareXFiles(
        [xFile],
        text: caption,
        subject: 'Perjanjian Gadai $displayCode - GALAXI GADAI',
      );
    } catch (e) {
      // Fallback ke wa.me teks biasa
      try {
        final tx = widget.transaction;
        final cust = widget.customer;
        final phone = cust.phone.replaceAll(RegExp(r'[^0-9]'), '');
        if (phone.isNotEmpty) {
          final waNum = phone.startsWith('0')
              ? '62${phone.substring(1)}'
              : phone.startsWith('62') ? phone : '62$phone';
          final displayCode = tx.transactionCode.isNotEmpty
              ? tx.transactionCode
              : tx.id.substring(0, 10).toUpperCase();
          final msg = Uri.encodeComponent(
              '📋 *Perjanjian Gadai $displayCode* dari GALAXI GADAI\n'
              'Tgl: ${_formatDateShort(tx.dateApplied)}\n'
              'JT : ${_formatDateShort(tx.dateDue)}\n'
              '_GALAXI GADAI_');
          final uri = Uri.parse('https://wa.me/$waNum?text=$msg');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _sendingWA = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final cust = widget.customer;
    final displayTxCode = tx.transactionCode.isNotEmpty ? tx.transactionCode : tx.id.substring(0, 10).toUpperCase();
    final petugasName = widget.petugasName;

    // Spec calculations
    final dateAppliedStr = _formatIndonesianLongDate(tx.dateApplied);
    final dateDueStr = _formatIndonesianLongDate(tx.dateDue);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light slate document background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Surat Perjanjian Gadai',
          style: GoogleFonts.inter(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: AppColors.primary),
            tooltip: 'Cetak Dokumen',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Menghubungkan ke printer...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Quick action panel
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionBtn(
                    context: context,
                    icon: Icons.print_outlined,
                    label: 'Cetak',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur cetak dokumen berhasil dipicu.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  // ── Kirim ke WA ──
                  _sendingWA
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                          ),
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        )
                      : _actionBtn(
                          context: context,
                          icon: Icons.send_rounded,
                          label: 'Kirim ke WA',
                          color: const Color(0xFF25D366),
                          onTap: _sendToWhatsApp,
                        ),
                  // ── Download PDF ──
                  _downloadingPdf
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                          ),
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                          ),
                        )
                      : _actionBtn(
                          context: context,
                          icon: Icons.picture_as_pdf_rounded,
                          label: 'Download PDF',
                          color: const Color(0xFF4F46E5),
                          onTap: _downloadPdf,
                        ),
                ],
              ),
            ),

            // Document body
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document Header
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'PERJANJIAN GADAI BARANG',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 80,
                          height: 1.5,
                          color: const Color(0xFF0F172A),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),

                  Text(
                    'Pada hari ini $dateAppliedStr telah dibuat dan disepakati Perjanjian Gadai Barang dengan nomor kontrak $displayTxCode antara:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF1E293B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pihak Pertama
                  Text(
                    'Pihak Pertama (Penggadai)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _docRow('Nama Outlet', 'GALAXI GADAI'),
                  _docRow('Alamat Outlet', 'Jl. Mt Haryono no 29 Samping gereja Imanuel buol. WA : 085181582929/082291211990'),
                  _docRow('Petugas', petugasName),
                  const SizedBox(height: 16),

                  // Pihak Kedua
                  Text(
                    'Pihak Kedua (Nasabah)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _docRow('Nama Nasabah', cust.name),
                  _docRow('Tempat/Tgl. Lahir', cust.birthPlace.isNotEmpty ? '${cust.birthPlace}, ${cust.birthDate}' : cust.birthDate),
                  _docRow('Jenis Kelamin', cust.gender),
                  _docRow('Alamat', cust.address),
                  const SizedBox(height: 24),

                  // Pasal 1
                  _pasalTitle('Pasal 1 — Barang Gadai'),
                  _docRow('Jenis Barang', tx.collateralType),
                  _docRow('Merk / Tipe', '${tx.brand} / ${tx.model}'),
                  _docRow('Kelengkapan', '-'),
                  _docRow('Kondisi Barang', tx.condition.isNotEmpty ? tx.condition : 'Sangat Baik'),
                  _docRow('Nilai Gadai', 'Rp. ${_formatCurrency(tx.principal)}'),
                  const SizedBox(height: 16),

                  // Pasal 2
                  _pasalTitle('Pasal 2 — Nilai Gadai'),
                  Text(
                    'Pihak Pertama memberikan pinjaman kepada Pihak Kedua sebesar Rp. ${_formatCurrency(tx.principal)}, dengan biaya jasa titip sebesar Rp. ${_formatCurrency(tx.dailyFee)} per hari.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Pada saat penebusan, Pihak Kedua wajib membayar sebesar Rp. ${_formatCurrency(tx.principal)} + Rp. ${_formatCurrency(tx.dailyFee)} x Jumlah Hari Gadai.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '2. Apabila penebusan dilakukan setelah melewati jatuh tempo, maka akan dikenakan biaya tambahan sesuai ketentuan yang berlaku.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // Pasal 3
                  _pasalTitle('Pasal 3 — Jangka Waktu'),
                  Text(
                    'Perjanjian berlaku sejak $dateAppliedStr\nJatuh Tempo tanggal $dateDueStr',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Apabila dalam waktu 5 hari setelah tanggal jatuh tempo barang belum diperpanjang atau ditebus, maka barang akan dilelang sesuai ketentuan yang berlaku.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // Pasal 4
                  _pasalTitle('Pasal 4 — Tanggung Jawab'),
                  Text(
                    '1. Barang menjadi tanggungan GALAXI GADAI selama masa gadai.\n'
                    '2. Pihak Kedua (Nasabah) menjamin bahwa barang tersebut bukan hasil tindak kejahatan dan merupakan milik pribadi.\n'
                    '3. Barang yang telah dilelang tidak dapat diklaim kembali oleh nasabah.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // Pasal 5
                  _pasalTitle('Pasal 5 — Penyelesaian Sengketa'),
                  Text(
                    'Apabila terjadi perselisihan, kedua pihak sepakat untuk menyelesaikan secara musyawarah. Jika tidak tercapai kesepakatan, maka diselesaikan sesuai hukum yang berlaku di Republik Indonesia.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // Pasal 6
                  _pasalTitle('Pasal 6 — Penutup'),
                  Text(
                    'Perjanjian ini dibuat secara sah dan mengikat kedua belah pihak tanpa paksaan dari pihak manapun.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dokumen ini dibuat secara elektronik dan memiliki kekuatan hukum yang sama dengan dokumen fisik berdasarkan Undang-Undang Nomor 11 Tahun 2008 tentang Informasi dan Transaksi Elektronik (UU ITE).',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.5),
                  ),
                  const SizedBox(height: 36),

                  // Signatures
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PIHAK PERTAMA',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                          ),
                          const SizedBox(height: 54),
                          Text(
                            petugasName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'PIHAK KEDUA',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                          ),
                          const SizedBox(height: 54),
                          Text(
                            cust.name,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pasalTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _docRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ),
          const Text(' : ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}
