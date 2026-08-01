import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class FilePendukungPage extends StatefulWidget {
  final String branchId;
  final String? transactionId;
  const FilePendukungPage({super.key, required this.branchId, this.transactionId});

  @override
  State<FilePendukungPage> createState() => _FilePendukungPageState();
}

class _FilePendukungPageState extends State<FilePendukungPage> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  // Template dokumen yang tersedia untuk diunduh / diprint
  final List<Map<String, String>> _templates = [
    {'name': 'Formulir_Pengajuan_Gadai.pdf', 'size': 'Dokumen cetak PDF', 'type': 'PDF Form'},
    {'name': 'Syarat_dan_Ketentuan_Umum.pdf', 'size': 'Dokumen cetak PDF', 'type': 'PDF S&K'},
    {'name': 'Template_Surat_Kuasa.pdf', 'size': 'Dokumen cetak PDF', 'type': 'PDF Form'},
  ];

  // File yang sudah diupload dari Supabase Storage
  List<Map<String, String>> _uploadedFiles = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
  }

  String get _storagePath {
    final txPart = widget.transactionId != null ? '/${widget.transactionId}' : '';
    return '${widget.branchId}$txPart';
  }

  Future<void> _loadUploadedFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _supabase.storage
          .from('gadai-files')
          .list(path: _storagePath);

      if (!mounted) return;
      setState(() {
        _uploadedFiles = files.map((f) => {
          'name': f.name,
          'size': f.metadata?['size'] != null ? '${((f.metadata!['size'] as num) / 1024).toStringAsFixed(1)} KB' : 'Gambar',
          'type': 'Uploaded',
          'path': '$_storagePath/${f.name}',
        }).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadedFiles = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final file = File(picked.path);
      final fileName = 'Jaminan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadPath = '$_storagePath/$fileName';

      await _supabase.storage
          .from('gadai-files')
          .upload(uploadPath, file, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto berhasil diunggah ke Supabase Storage!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadUploadedFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal upload: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showUploadDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unggah Foto Dokumen / Jaminan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Ambil Foto dari Kamera'),
                subtitle: const Text('Foto dokumen / barang fisik langsung'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.photo_library_rounded, color: Color(0xFF1D4ED8)),
                ),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Pilih foto dari penyimpanan HP'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilePreviewModal(Map<String, String> fileMap) {
    final name = fileMap['name'] ?? 'File';
    final path = fileMap['path'] ?? '';
    final url = _supabase.storage.from('gadai-files').getPublicUrl(path);
    final isImage = name.toLowerCase().endsWith('.jpg') ||
        name.toLowerCase().endsWith('.jpeg') ||
        name.toLowerCase().endsWith('.png') ||
        name.toLowerCase().endsWith('.webp');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Container
            if (isImage)
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                width: double.infinity,
                color: Colors.black,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: Colors.white)));
                  },
                  errorBuilder: (ctx, err, stack) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, color: Colors.white70, size: 48),
                          SizedBox(height: 8),
                          Text('Gagal memuat gambar', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                color: const Color(0xFFEFF6FF),
                child: const Center(
                  child: Icon(Icons.insert_drive_file_rounded, size: 48, color: AppColors.primary),
                ),
              ),

            // Metadata & Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Path: $path', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final uri = Uri.parse(url);
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal membuka URL: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Buka URL'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteFile(path, name);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                        label: const Text('Hapus', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  Future<void> _downloadTemplate(Map<String, String> template) async {
    final name = template['name'] ?? 'Dokumen.pdf';
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.showSnackBar(
        SnackBar(content: Text('Memproses $name...'), duration: const Duration(seconds: 2)),
      );

      final pdf = pw.Document();
      final title = name.replaceAll('_', ' ').replaceAll('.pdf', '');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('GALAXI GADAI', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF2563EB))),
                      pw.Text('DOKUMEN RESMI', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF64748B))),
                    ],
                  ),
                  pw.Divider(thickness: 1.5, color: PdfColor.fromInt(0xFF2563EB)),
                  pw.SizedBox(height: 16),

                  // Title
                  pw.Center(
                    child: pw.Text(
                      title.toUpperCase(),
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Content
                  if (name.contains('Formulir')) ...[
                    pw.Text('I. DATA NASABAH', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD5E1))),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Nama Lengkap : ________________________________________', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 8),
                          pw.Text('NIK KTP       : ________________________________________', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 8),
                          pw.Text('No. HP / WA   : ________________________________________', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 8),
                          pw.Text('Alamat        : ________________________________________', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 14),
                    pw.Text('II. DATA BARANG JAMINAN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD5E1))),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Jenis Barang  : [ ] HP / Laptop   [ ] Emas   [ ] Kendaraan', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 8),
                          pw.Text('Merk & Tipe   : ________________________________________', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 8),
                          pw.Text('Kelengkapan   : [ ] Charger   [ ] Dus/Box   [ ] STNK/BPKB', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 8),
                          pw.Text('Nilai Pinjaman: Rp _____________________________________', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(children: [
                          pw.Text('Petugas Cabang', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 40),
                          pw.Text('( _________________ )', style: const pw.TextStyle(fontSize: 10)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Pemohon / Nasabah', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 40),
                          pw.Text('( _________________ )', style: const pw.TextStyle(fontSize: 10)),
                        ]),
                      ],
                    ),
                  ] else if (name.contains('Syarat')) ...[
                    pw.Text('SYARAT & KETENTUAN UMUM GADAI GALAXI', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('1. Jaminan gadai yang diserahkan merupakan milik sah nasabah.', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 6),
                    pw.Text('2. Perhitungan jasa titip dihitung berdasarkan harian per kelipatan plafon pinjaman.', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 6),
                    pw.Text('3. Pelunasan atau perpanjangan dilakukan sebelum atau pada tanggal jatuh tempo.', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 6),
                    pw.Text('4. Barang gadai yang lewat jatuh tempo lebih dari 7 hari tanpa perpanjangan akan masuk proses lelang.', style: const pw.TextStyle(fontSize: 10)),
                  ] else ...[
                    pw.Text('SURAT KUASA PELUNASAN / PENGAMBILAN BARANG GADAI', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 14),
                    pw.Text('Yang bertanda tangan di bawah ini:', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 6),
                    pw.Text('Nama    : ________________________________________', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text('NIK     : ________________________________________', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 10),
                    pw.Text('MEMBERIKAN KUASA KEPADA:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text('Nama    : ________________________________________', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text('NIK     : ________________________________________', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 10),
                    pw.Text('Untuk melakukan pelunasan dan/atau pengambilan barang gadai atas nomor transaksi ________________.', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 40),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Penerima Kuasa\n\n\n( ______________ )', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Pemberi Kuasa\n\n\n( ______________ )', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final targetFile = File('${dir.path}/$name');
      await targetFile.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(targetFile.path)], text: 'Dokumen $title — Galaxi Gadai');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal membuat dokumen: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteFile(String filePath, String fileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus File'),
        content: Text('Hapus file "$fileName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.storage.from('gadai-files').remove([filePath]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File berhasil dihapus'), backgroundColor: Colors.green),
      );
      await _loadUploadedFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('File Pendukung',
            style: GoogleFonts.poppins(color: const Color(0xFF0A1628), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF93C5FD),
        iconTheme: const IconThemeData(color: Color(0xFF0A1628)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0A1628)),
            onPressed: _loadUploadedFiles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUploadedFiles,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Unggah foto fisik jaminan gadai ke cloud atau unduh template surat resmi.',
                              style: TextStyle(color: Color(0xFF1E4ED8), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Upload progress indicator
                    if (_isUploading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(),
                      ),

                    // Uploaded files section
                    const Text('📎 File Terupload (Cloud Storage)',
                        style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    if (_uploadedFiles.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(children: [
                          Icon(Icons.cloud_upload_outlined, size: 40, color: Color(0xFF94A3B8)),
                          SizedBox(height: 8),
                          Text('Belum ada file yang diunggah',
                              style: TextStyle(color: AppColors.textMuted)),
                        ]),
                      )
                    else
                      ...(_uploadedFiles.map((file) => GestureDetector(
                            onTap: () => _showFilePreviewModal(file),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.image_outlined,
                                      color: Color(0xFF2563EB), size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          file['name']!,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textDark,
                                              fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text('Supabase Storage • ${file['size']}',
                                            style: const TextStyle(
                                                color: AppColors.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined,
                                        color: Color(0xFF2563EB), size: 20),
                                    onPressed: () => _showFilePreviewModal(file),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        color: Colors.redAccent, size: 20),
                                    onPressed: () =>
                                        _deleteFile(file['path']!, file['name']!),
                                  ),
                                ],
                              ),
                            ),
                          ))),

                    const SizedBox(height: 24),

                    // Template section
                    const Text('📄 Template Dokumen Resmi',
                        style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    ..._templates.map((file) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_rounded,
                                  color: Color(0xFFEF4444), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(file['name']!,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                    Text('${file['type']} • ${file['size']}',
                                        style: const TextStyle(
                                            color: AppColors.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _downloadTemplate(file),
                                icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                                label: const Text('Cetak / Bagikan', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        )),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _showUploadDialog,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: const Text('Unggah Foto',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
