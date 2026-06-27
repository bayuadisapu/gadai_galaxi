import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';

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
  });

  @override
  State<Step3BiodataView> createState() => _Step3BiodataViewState();
}

class _Step3BiodataViewState extends State<Step3BiodataView> {
  bool _isOcrRunning = false;

  void _runOcrSimulation() async {
    if (widget.ktpUploaded) {
      widget.onKtpUploadedChanged(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto KTP dihapus')),
      );
      return;
    }

    setState(() => _isOcrRunning = true);
    
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (!mounted) return;
    setState(() => _isOcrRunning = false);
    
    widget.onKtpUploadedChanged(true);
    
    widget.nikController.text = '3174092408930005';
    widget.fullNameController.text = 'Budi Santoso';
    widget.phoneController.text = '081298765432';
    widget.addressController.text = 'Jl. Kemang Raya No. 45, Jakarta Selatan';
    widget.birthPlaceController.text = 'Jakarta';
    
    widget.onGenderChanged('Laki-laki');
    widget.onBirthDayChanged('24');
    widget.onBirthMonthChanged('Agustus');
    widget.onBirthYearChanged('1993');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OCR Berhasil: Data KTP berhasil diekstrak!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            const SizedBox(height: 28),

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

            // Upload KTP Section
            const Text(
              'Foto KTP Nasabah',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isOcrRunning ? null : _runOcrSimulation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: widget.ktpUploaded ? const Color(0xFFECFDF5) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.ktpUploaded ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _isOcrRunning
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 12),
                          Text('Mengekstrak data KTP menggunakan AI...', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.ktpUploaded ? Icons.verified_user_rounded : Icons.camera_enhance_outlined,
                            color: widget.ktpUploaded ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.ktpUploaded ? 'KTP Terunggah (Ketuk untuk ganti)' : 'Unggah Foto KTP & Ekstrak Data Otomatis',
                            style: TextStyle(
                              color: widget.ktpUploaded ? const Color(0xFF047857) : const Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Foto Nasabah & Barang Jaminan
            const Text(
              'Foto Nasabah & Barang Jaminan',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                widget.onCustomerAndBarangPhotoUploadedChanged(!widget.customerAndBarangPhotoUploaded);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(!widget.customerAndBarangPhotoUploaded ? 'Foto nasabah & barang jaminan berhasil diunggah' : 'Foto nasabah & barang jaminan dihapus'),
                    backgroundColor: !widget.customerAndBarangPhotoUploaded ? Colors.green : Colors.grey,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: widget.customerAndBarangPhotoUploaded ? const Color(0xFFECFDF5) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.customerAndBarangPhotoUploaded ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.customerAndBarangPhotoUploaded ? Icons.verified_user_rounded : Icons.camera_enhance_outlined,
                      color: widget.customerAndBarangPhotoUploaded ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.customerAndBarangPhotoUploaded ? 'Foto Nasabah & Barang Terunggah (Ketuk untuk ganti)' : 'Unggah Foto Nasabah & Barang Jaminan',
                      style: TextStyle(
                        color: widget.customerAndBarangPhotoUploaded ? const Color(0xFF047857) : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
