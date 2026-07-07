import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Template dokumen yang tersedia untuk diunduh
  final List<Map<String, String>> _templates = [
    {'name': 'Formulir_Pengajuan_Gadai.pdf', 'size': '245 KB', 'type': 'PDF Template'},
    {'name': 'Syarat_dan_Ketentuan_Umum.pdf', 'size': '512 KB', 'type': 'PDF S&K'},
    {'name': 'Template_Surat_Kuasa.docx', 'size': '45 KB', 'type': 'Word Doc'},
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

      setState(() {
        _uploadedFiles = files.map((f) => {
          'name': f.name,
          'size': f.metadata?['size']?.toString() ?? '—',
          'type': 'Uploaded',
          'path': '$_storagePath/${f.name}',
        }).toList();
        _isLoading = false;
      });
    } catch (_) {
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
        imageQuality: 75,
        maxWidth: 1200,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final file = File(picked.path);
      final fileName = 'Jaminan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadPath = '$_storagePath/$fileName';

      await _supabase.storage
          .from('gadai-files')
          .upload(uploadPath, file,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto berhasil diunggah!'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadUploadedFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal upload: ${e.toString()}'),
          backgroundColor: Colors.red,
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
              const Text('Pilih Sumber Foto',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Kamera'),
                subtitle: const Text('Foto langsung dari kamera'),
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
                title: const Text('Galeri'),
                subtitle: const Text('Pilih dari galeri foto'),
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
        const SnackBar(content: Text('File dihapus'), backgroundColor: Colors.green),
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
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Unggah foto fisik jaminan gadai atau unduh template surat.',
                              style: TextStyle(color: Color(0xFF1E4ED8), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Upload status
                    if (_isUploading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(),
                      ),

                    // Uploaded files section
                    const Text('📎 File Terupload',
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
                      ...(_uploadedFiles.map((file) => Container(
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
                                      Text('Tersimpan di Supabase Storage',
                                          style: const TextStyle(
                                              color: AppColors.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () =>
                                      _deleteFile(file['path']!, file['name']!),
                                ),
                              ],
                            ),
                          ))),

                    const SizedBox(height: 24),

                    // Template section
                    const Text('📄 Template Dokumen',
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
                              const Icon(Icons.insert_drive_file_outlined,
                                  color: Color(0xFF2563EB), size: 28),
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
                              IconButton(
                                icon: const Icon(Icons.download_rounded,
                                    color: Color(0xFF2563EB)),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Mengunduh ${file['name']}...')),
                                  );
                                },
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
