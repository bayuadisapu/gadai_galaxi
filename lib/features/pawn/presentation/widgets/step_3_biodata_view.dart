import 'dart:io';
import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:image_picker/image_picker.dart';


class Step3BiodataView extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nikController;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController birthPlaceController;

  final String? selectedGender;
  final ValueChanged<String?> onGenderChanged;

  final String? birthDay;
  final ValueChanged<String?> onBirthDayChanged;
  final String? birthMonth;
  final ValueChanged<String?> onBirthMonthChanged;
  final String? birthYear;
  final ValueChanged<String?> onBirthYearChanged;

  final bool ktpUploaded;
  final ValueChanged<bool> onKtpUploadedChanged;

  final bool customerAndBarangPhotoUploaded;
  final ValueChanged<bool> onCustomerAndBarangPhotoUploadedChanged;

  // Nasabah terdaftar
  final Customer? selectedNasabah;
  final VoidCallback onPickNasabah;

  const Step3BiodataView({
    super.key,
    required this.formKey,
    required this.nikController,
    required this.fullNameController,
    required this.phoneController,
    required this.addressController,
    required this.birthPlaceController,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.birthDay,
    required this.onBirthDayChanged,
    required this.birthMonth,
    required this.onBirthMonthChanged,
    required this.birthYear,
    required this.onBirthYearChanged,
    required this.ktpUploaded,
    required this.onKtpUploadedChanged,
    required this.customerAndBarangPhotoUploaded,
    required this.onCustomerAndBarangPhotoUploadedChanged,
    required this.selectedNasabah,
    required this.onPickNasabah,
  });

  @override
  State<Step3BiodataView> createState() => _Step3BiodataViewState();
}

class _Step3BiodataViewState extends State<Step3BiodataView> {
  // ── Foto state ──
  XFile? _ktpPhoto;
  XFile? _nasabahBarangPhoto;
  XFile? _barangGadaiPhoto;
  bool _isPickingKtp = false;
  bool _isPickingNasabah = false;
  bool _isPickingBarang = false;

  // ── Helper: bottom sheet pilih sumber foto ──
  Future<ImageSource?> _showSourcePicker(String title) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.camera_alt_rounded, color: AppColors.primary)),
              title: const Text('Ambil Foto dari Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.photo_library_rounded, color: AppColors.primary)),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Ambil foto KTP — TIDAK auto-fill data, user isi manual
  Future<void> _pickKtpPhoto() async {
    if (_isPickingKtp) return;
    // Jika sudah ada foto, tanya apakah ingin hapus
    if (widget.ktpUploaded && _ktpPhoto != null) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ganti Foto KTP?'),
          content: const Text('Foto KTP yang sudah ada akan diganti.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ganti', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    final ImageSource? source = await _showSourcePicker('Unggah Foto KTP');
    if (source == null || !mounted) return;
    setState(() => _isPickingKtp = true);
    try {
      final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1280);
      if (!mounted) return;
      if (picked != null) {
        setState(() => _ktpPhoto = picked);
        widget.onKtpUploadedChanged(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto KTP berhasil diambil. Lengkapi data di bawah.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingKtp = false);
    }
  }

  /// Ambil foto nasabah + barang jaminan
  Future<void> _pickNasabahBarangPhoto() async {
    if (_isPickingNasabah) return;
    final ImageSource? source = await _showSourcePicker('Foto Nasabah & Barang');
    if (source == null || !mounted) return;
    setState(() => _isPickingNasabah = true);
    try {
      final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1280);
      if (!mounted) return;
      if (picked != null) {
        setState(() => _nasabahBarangPhoto = picked);
        widget.onCustomerAndBarangPhotoUploadedChanged(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto nasabah & barang berhasil diambil'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingNasabah = false);
    }
  }

  /// Ambil foto barang gadai saja
  Future<void> _pickBarangGadaiPhoto() async {
    if (_isPickingBarang) return;
    final ImageSource? source = await _showSourcePicker('Foto Barang Gadai');
    if (source == null || !mounted) return;
    setState(() => _isPickingBarang = true);
    try {
      final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1280);
      if (!mounted) return;
      if (picked != null) setState(() => _barangGadaiPhoto = picked);
    } finally {
      if (mounted) setState(() => _isPickingBarang = false);
    }
  }


  InputDecoration _getInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 15),
      filled: true,
      fillColor: AppColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputFocusedBorder, width: 1.5),
      ),
    );
  }

  Widget _buildPhotoSlot({
    required String label,
    required IconData icon,
    required XFile? photo,
    required bool isUploaded,
    required bool isPicking,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isPicking ? null : onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: isUploaded ? const Color(0xFFECFDF5) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUploaded ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
          ),
          child: isPicking
              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
              : photo != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(File(photo.path), fit: BoxFit.cover),
                        ),
                        Positioned(
                          bottom: 4, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                              child: const Text('Ketuk ganti', style: TextStyle(color: Colors.white, fontSize: 9)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: const Color(0xFF94A3B8), size: 28),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        const Text('Ketuk unggah', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
                      ],
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Subtitle
            const Text(
              'Data Diri Nasabah',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lengkapi data identitas nasabah pengaju',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // ── TOMBOL PILIH NASABAH TERDAFTAR ──
            GestureDetector(
              onTap: widget.onPickNasabah,
              child: widget.selectedNasabah != null
                  // Banner nasabah terpilih
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.selectedNasabah!.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 14)),
                          Text(widget.selectedNasabah!.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ])),
                        const Text('Ganti', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    )
                  // Tombol pilih
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text('Pilih Nasabah Terdaftar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                    ),
            ),
            const SizedBox(height: 12),

            // Divider antara pick dan form manual
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('atau isi manual', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),

            // NIK KTP Input
            const Text(
              'NIK KTP',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.nikController,
              keyboardType: TextInputType.number,
              maxLength: 16,
              decoration: InputDecoration(
                hintText: 'Contoh: 357801xxxxxxxxxx',
                hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 15),
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterText: '',
              ),
              style: const TextStyle(fontSize: 15),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'NIK KTP tidak boleh kosong';
                }
                if (value.trim().length != 16) {
                  return 'NIK harus terdiri dari 16 digit';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Nama Lengkap Input
            const Text(
              'Nama Lengkap (Sesuai KTP)',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.fullNameController,
              keyboardType: TextInputType.name,
              decoration: InputDecoration(
                hintText: 'Masukkan nama lengkap nasabah',
                hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 15),
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 15),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama lengkap tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Tempat Lahir & Jenis Kelamin side-by-side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tempat Lahir',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: widget.birthPlaceController,
                        decoration: _getInputDecoration(hint: 'Contoh: Surabaya'),
                        style: const TextStyle(fontSize: 15),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Wajib diisi' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jenis Kelamin',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: widget.selectedGender,
                        hint: const Text('Pilih', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
                        decoration: _getInputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                          DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                        ],
                        onChanged: widget.onGenderChanged,
                        validator: (value) => value == null ? 'Wajib dipilih' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Split Dropdown Tanggal Lahir
            const Text(
              'Tanggal Lahir',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Dropdown
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: widget.birthDay,
                    hint: const Text('Tgl', style: TextStyle(color: AppColors.textInputHint, fontSize: 14)),
                    decoration: _getInputDecoration(),
                    items: List.generate(31, (index) => (index + 1).toString()).map((day) {
                      return DropdownMenuItem(value: day, child: Text(day, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: widget.onBirthDayChanged,
                    validator: (value) => value == null ? 'Pilih' : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Month Dropdown
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    value: widget.birthMonth,
                    hint: const Text('Bulan', style: TextStyle(color: AppColors.textInputHint, fontSize: 14)),
                    decoration: _getInputDecoration(),
                    items: const [
                      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
                      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
                    ].map((month) {
                      return DropdownMenuItem(value: month, child: Text(month, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: widget.onBirthMonthChanged,
                    validator: (value) => value == null ? 'Pilih' : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Year Dropdown
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: widget.birthYear,
                    hint: const Text('Tahun', style: TextStyle(color: AppColors.textInputHint, fontSize: 14)),
                    decoration: _getInputDecoration(),
                    items: List.generate(DateTime.now().year - 17 - 1950 + 1, (index) => (1950 + index).toString()).reversed.map((year) {
                      return DropdownMenuItem(value: year, child: Text(year, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: widget.onBirthYearChanged,
                    validator: (value) => value == null ? 'Pilih' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nomor Telepon Input
            const Text(
              'Nomor Telepon / HP',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Contoh: 08123456xxxx',
                hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 15),
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 15),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nomor telepon tidak boleh kosong';
                }
                final reg = RegExp(r'^(08|\+628)[0-9]{8,11}$');
                if (!reg.hasMatch(value.trim())) {
                  return 'Nomor HP tidak valid (Gunakan 08xx atau +628xx, 10-13 digit)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Alamat Input
            const Text(
              'Alamat Lengkap',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.addressController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Masukkan alamat lengkap domisili nasabah',
                hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 15),
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 15),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Alamat lengkap tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ─── 3-Kolom Foto ───────────────────────────────
            const Text(
              'Foto Dokumen & Jaminan',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kolom 1 — Foto KTP
                Expanded(child: _buildPhotoSlot(
                  label: 'Foto KTP',
                  icon: Icons.credit_card_rounded,
                  photo: _ktpPhoto,
                  isUploaded: widget.ktpUploaded,
                  isPicking: _isPickingKtp,
                  onTap: _pickKtpPhoto,
                )),
                const SizedBox(width: 8),
                // Kolom 2 — Foto Nasabah & Barang
                Expanded(child: _buildPhotoSlot(
                  label: 'Nasabah+Barang',
                  icon: Icons.people_alt_rounded,
                  photo: _nasabahBarangPhoto,
                  isUploaded: widget.customerAndBarangPhotoUploaded,
                  isPicking: _isPickingNasabah,
                  onTap: _pickNasabahBarangPhoto,
                )),
                const SizedBox(width: 8),
                // Kolom 3 — Foto Barang Gadai
                Expanded(child: _buildPhotoSlot(
                  label: 'Barang Gadai',
                  icon: Icons.camera_enhance_outlined,
                  photo: _barangGadaiPhoto,
                  isUploaded: _barangGadaiPhoto != null,
                  isPicking: _isPickingBarang,
                  onTap: _pickBarangGadaiPhoto,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
