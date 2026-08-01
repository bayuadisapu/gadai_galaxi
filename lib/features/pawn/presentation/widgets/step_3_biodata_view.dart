import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';



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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

