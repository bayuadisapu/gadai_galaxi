import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';

class FilePendukungPage extends StatefulWidget {
  const FilePendukungPage({super.key});

  @override
  State<FilePendukungPage> createState() => _FilePendukungPageState();
}

class _FilePendukungPageState extends State<FilePendukungPage> {
  final List<Map<String, String>> _files = [
    {'name': 'Formulir_Pengajuan_Gadai.pdf', 'size': '245 KB', 'type': 'PDF Template'},
    {'name': 'Syarat_dan_Ketentuan_Umum.pdf', 'size': '512 KB', 'type': 'PDF S&K'},
    {'name': 'Template_Surat_Kuasa.docx', 'size': '45 KB', 'type': 'Word Doc'},
  ];

  void _simulateUpload() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unggah Berkas Pendukung'),
        content: const Text('Simulasi: Pilih file dari galeri atau kamera.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _files.add({
                  'name': 'Upload_Fisik_Jaminan_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  'size': '1.2 MB',
                  'type': 'Image JPG',
                });
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Berkas berhasil diunggah!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Pilih Berkas'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F0),
      appBar: AppBar(
        title: const Text('File Pendukung', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F5A47),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFE6F4EA),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF137333)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Anda dapat mengunduh berkas template surat kuasa dan surat pernyataan gadai, atau mengunggah berkas fisik jaminan di sini.',
                    style: TextStyle(color: Color(0xFF137333), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _files.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final file = _files[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF0F5A47), size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file['name']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${file['type']} • ${file['size']}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Color(0xFF0F5A47)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Mengunduh ${file['name']}...')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _simulateUpload,
        backgroundColor: const Color(0xFF0F5A47),
        child: const Icon(Icons.upload_file_rounded, color: Colors.white),
      ),
    );
  }
}
