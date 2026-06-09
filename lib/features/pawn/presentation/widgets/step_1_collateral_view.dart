import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'new_pawn_shared_widgets.dart';

class Step1CollateralView extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final String selectedCollateral;
  final Function(String) onCollateralSelected;
  
  // Controllers
  final TextEditingController modelController;
  final TextEditingController noteController;
  final TextEditingController grossWeightController;
  final TextEditingController netWeightController;
  final TextEditingController vehicleYearController;
  final TextEditingController plateNumberController;

  // Selected Options & State getters/setters
  final String? selectedBrand;
  final ValueChanged<String?> onBrandChanged;
  final String? selectedCondition;
  final ValueChanged<String?> onConditionChanged;

  // HP specific
  final String deviceLock;
  final ValueChanged<String> onDeviceLockChanged;
  final bool hasCharger;
  final ValueChanged<bool> onHasChargerChanged;
  final bool hasDus;
  final ValueChanged<bool> onHasDusChanged;

  // Laptop specific
  final String? selectedProcessor;
  final ValueChanged<String?> onProcessorChanged;
  final String? selectedRam;
  final ValueChanged<String?> onRamChanged;
  final String? selectedStorage;
  final ValueChanged<String?> onStorageChanged;
  final bool hasTas;
  final ValueChanged<bool> onHasTasChanged;

  // Emas specific
  final String? selectedGoldType;
  final ValueChanged<String?> onGoldTypeChanged;
  final String? selectedKarat;
  final ValueChanged<String?> onKaratChanged;
  final String? selectedCertificate;
  final ValueChanged<String?> onCertificateChanged;

  // Vehicle specific
  final String? selectedVehicleType;
  final ValueChanged<String?> onVehicleTypeChanged;
  final bool hasStnk;
  final ValueChanged<bool> onHasStnkChanged;
  final bool hasBpkb;
  final ValueChanged<bool> onHasBpkbChanged;
  final bool hasFaktur;
  final ValueChanged<bool> onHasFakturChanged;

  const Step1CollateralView({
    super.key,
    required this.formKey,
    required this.selectedCollateral,
    required this.onCollateralSelected,
    required this.modelController,
    required this.noteController,
    required this.grossWeightController,
    required this.netWeightController,
    required this.vehicleYearController,
    required this.plateNumberController,
    required this.selectedBrand,
    required this.onBrandChanged,
    required this.selectedCondition,
    required this.onConditionChanged,
    required this.deviceLock,
    required this.onDeviceLockChanged,
    required this.hasCharger,
    required this.onHasChargerChanged,
    required this.hasDus,
    required this.onHasDusChanged,
    required this.selectedProcessor,
    required this.onProcessorChanged,
    required this.selectedRam,
    required this.onRamChanged,
    required this.selectedStorage,
    required this.onStorageChanged,
    required this.hasTas,
    required this.onHasTasChanged,
    required this.selectedGoldType,
    required this.onGoldTypeChanged,
    required this.selectedKarat,
    required this.onKaratChanged,
    required this.selectedCertificate,
    required this.onCertificateChanged,
    required this.selectedVehicleType,
    required this.onVehicleTypeChanged,
    required this.hasStnk,
    required this.onHasStnkChanged,
    required this.hasBpkb,
    required this.onHasBpkbChanged,
    required this.hasFaktur,
    required this.onHasFakturChanged,
  });

  @override
  State<Step1CollateralView> createState() => _Step1CollateralViewState();
}

class _Step1CollateralViewState extends State<Step1CollateralView> {
  final List<String> _hpBrands = ['Apple', 'Samsung', 'Oppo', 'Vivo', 'Xiaomi', 'Realme', 'Infinix'];
  final List<String> _laptopBrands = ['ASUS', 'Lenovo', 'HP', 'Dell', 'Acer', 'Apple (MacBook)', 'MSI'];
  final List<String> _hpConditions = ['Mulus / Seperti Baru', 'Normal / Lecet Pemakaian', 'Layar Gores / Retak', 'Mati Total / Rusak'];
  final List<String> _laptopConditions = ['Mulus / Seperti Baru', 'Normal / Lecet Pemakaian', 'Keyboard Mati / Rusak', 'Layar Bergaris / Jamur', 'Mati Total'];

  final List<String> _processors = ['Intel Core i3 / Ryzen 3', 'Intel Core i5 / Ryzen 5', 'Intel Core i7 / Ryzen 7', 'Intel Core i9 / Ryzen 9', 'Apple M1/M2/M3 Series'];
  final List<String> _ramOptions = ['4 GB', '8 GB', '16 GB', '32 GB'];
  final List<String> _storageOptions = ['256 GB SSD', '512 GB SSD', '1 TB SSD', '1 TB HDD'];

  final List<String> _goldTypes = ['Emas Batangan / Logam Mulia', 'Perhiasan (Cincin / Kalung / Gelang)', 'Koin Emas'];
  final List<String> _goldKarats = ['24 Karat', '22 Karat', '18 Karat', '16 Karat', '14 Karat'];
  final List<String> _certificates = ['Sertifikat Antam', 'Sertifikat UBS', 'Non-Sertifikat / Surat Toko'];

  final List<String> _vehicleTypes = ['Sepeda Motor', 'Mobil'];
  final List<String> _vehicleBrands = ['Honda', 'Yamaha', 'Suzuki', 'Kawasaki', 'Toyota', 'Daihatsu', 'Mitsubishi', 'Nissan'];
  final List<String> _vehicleConditions = ['Prima / Mulus', 'Lecet Pemakaian', 'Mesin Kasar / Modifikasi', 'Mati / Rusak Berat'];

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

  Widget _buildInfoText(String msg) {
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 14),
        const SizedBox(width: 6),
        Text(
          msg,
          style: TextStyle(
            color: const Color(0xFF64748B).withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRadioButton(String value) {
    final isSelected = widget.deviceLock == value;
    return GestureDetector(
      onTap: () => widget.onDeviceLockChanged(value),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: isSelected
                ? Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 16),
          child: Text(
            'Pilih Jenis Jaminan',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: CollateralCard(
                      icon: Icons.phone_android_rounded,
                      label: 'Handphone',
                      isSelected: widget.selectedCollateral == 'Handphone',
                      onTap: () => widget.onCollateralSelected('Handphone'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CollateralCard(
                      icon: Icons.laptop_mac_rounded,
                      label: 'Laptop',
                      isSelected: widget.selectedCollateral == 'Laptop',
                      onTap: () => widget.onCollateralSelected('Laptop'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CollateralCard(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Emas',
                      isSelected: widget.selectedCollateral == 'Emas',
                      onTap: () => widget.onCollateralSelected('Emas'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CollateralCard(
                      icon: Icons.two_wheeler_rounded,
                      label: 'Motor / Mobil',
                      isSelected: widget.selectedCollateral == 'Motor / Mobil',
                      onTap: () => widget.onCollateralSelected('Motor / Mobil'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Form(
            key: widget.formKey,
            child: _buildDynamicForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicForm() {
    switch (widget.selectedCollateral) {
      case 'Handphone':
        return _buildHandphoneForm();
      case 'Laptop':
        return _buildLaptopForm();
      case 'Emas':
        return _buildEmasForm();
      case 'Motor / Mobil':
        return _buildVehicleForm();
      default:
        return _buildHandphoneForm();
    }
  }

  Widget _buildHandphoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Merk Handphone',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedBrand,
          hint: const Text('Pilih Merk', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _hpBrands.map((brand) {
            return DropdownMenuItem(value: brand, child: Text(brand, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onBrandChanged,
          validator: (value) => value == null ? 'Silakan pilih merk handphone' : null,
        ),
        const SizedBox(height: 20),
        
        const Text(
          'Tipe / Model',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.modelController,
          decoration: _getInputDecoration(hint: 'Contoh: iPhone 15 Pro Max'),
          style: const TextStyle(fontSize: 15),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Tipe / model tidak boleh kosong' : null,
        ),
        const SizedBox(height: 6),
        _buildInfoText('Ikut petunjuk penulisan tipe hp yang lengkap'),
        const SizedBox(height: 20),
        
        const Text(
          'Kondisi Barang',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedCondition,
          hint: const Text('Pilih Kondisi', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _hpConditions.map((cond) {
            return DropdownMenuItem(value: cond, child: Text(cond, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onConditionChanged,
          validator: (value) => value == null ? 'Silakan pilih kondisi handphone' : null,
        ),
        const SizedBox(height: 20),
        
        const Text(
          'Keterangan Tambahan',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.noteController,
          maxLines: 3,
          decoration: _getInputDecoration(hint: 'Contoh: Layar terpasang TG, kamera jernih...'),
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 20),
        
        const Text(
          'Kunci Perangkat',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildRadioButton('PIN/Sandi'),
            const SizedBox(width: 16),
            _buildRadioButton('Pola'),
            const SizedBox(width: 16),
            _buildRadioButton('Tanpa Kunci'),
          ],
        ),
        const SizedBox(height: 20),
        
        const Text(
          'Kelengkapan',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCheckbox(label: 'Charger', value: widget.hasCharger, onChanged: (val) => widget.onHasChargerChanged(val ?? false)),
            const SizedBox(width: 16),
            _buildCheckbox(label: 'Dus', value: widget.hasDus, onChanged: (val) => widget.onHasDusChanged(val ?? false)),
          ],
        ),
      ],
    );
  }

  Widget _buildLaptopForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Merk Laptop',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedBrand,
          hint: const Text('Pilih Merk Laptop', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _laptopBrands.map((brand) {
            return DropdownMenuItem(value: brand, child: Text(brand, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onBrandChanged,
          validator: (value) => value == null ? 'Silakan pilih merk laptop' : null,
        ),
        const SizedBox(height: 20),
        
        const Text(
          'Tipe / Model',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.modelController,
          decoration: _getInputDecoration(hint: 'Contoh: ThinkPad L14 Gen 3 / ROG G14'),
          style: const TextStyle(fontSize: 15),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Tipe laptop tidak boleh kosong' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Prosesor',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedProcessor,
          hint: const Text('Pilih Tipe CPU', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _processors.map((cpu) {
            return DropdownMenuItem(value: cpu, child: Text(cpu, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onProcessorChanged,
          validator: (value) => value == null ? 'Silakan pilih prosesor' : null,
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RAM',
                    style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: widget.selectedRam,
                    hint: const Text('Pilih RAM', style: TextStyle(color: AppColors.textInputHint, fontSize: 14)),
                    decoration: _getInputDecoration(),
                    items: _ramOptions.map((ram) {
                      return DropdownMenuItem(value: ram, child: Text(ram, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: widget.onRamChanged,
                    validator: (value) => value == null ? 'RAM wajib dipilih' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Penyimpanan',
                    style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: widget.selectedStorage,
                    hint: const Text('Pilih Storage', style: TextStyle(color: AppColors.textInputHint, fontSize: 14)),
                    decoration: _getInputDecoration(),
                    items: _storageOptions.map((stg) {
                      return DropdownMenuItem(value: stg, child: Text(stg, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: widget.onStorageChanged,
                    validator: (value) => value == null ? 'Storage wajib dipilih' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text(
          'Kondisi Barang',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedCondition,
          hint: const Text('Pilih Kondisi Laptop', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _laptopConditions.map((cond) {
            return DropdownMenuItem(value: cond, child: Text(cond, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onConditionChanged,
          validator: (value) => value == null ? 'Kondisi barang wajib dipilih' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Keterangan Tambahan',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.noteController,
          maxLines: 3,
          decoration: _getInputDecoration(hint: 'Contoh: Layar ada white spot kecil, baterai awet 3 jam...'),
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 20),

        const Text(
          'Kelengkapan',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCheckbox(label: 'Charger Adaptor', value: widget.hasCharger, onChanged: (val) => widget.onHasChargerChanged(val ?? false)),
            const SizedBox(width: 16),
            _buildCheckbox(label: 'Tas Laptop', value: widget.hasTas, onChanged: (val) => widget.onHasTasChanged(val ?? false)),
            const SizedBox(width: 16),
            _buildCheckbox(label: 'Dus Box', value: widget.hasDus, onChanged: (val) => widget.onHasDusChanged(val ?? false)),
          ],
        ),
      ],
    );
  }

  Widget _buildEmasForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jenis Jaminan Emas',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedGoldType,
          hint: const Text('Pilih Jenis Emas', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _goldTypes.map((type) {
            return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onGoldTypeChanged,
          validator: (value) => value == null ? 'Silakan pilih jenis emas' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Kadar Karat Emas',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedKarat,
          hint: const Text('Pilih Karat', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _goldKarats.map((krt) {
            return DropdownMenuItem(value: krt, child: Text(krt, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onKaratChanged,
          validator: (value) => value == null ? 'Kadar karat emas wajib dipilih' : null,
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Berat Kotor / Gross (gram)',
                    style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: widget.grossWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _getInputDecoration(hint: 'e.g. 10.45'),
                    style: const TextStyle(fontSize: 15),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Berat kotor wajib diisi';
                      if (double.tryParse(value) == null) return 'Input angka tidak valid';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Berat Bersih / Net (gram)',
                    style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: widget.netWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _getInputDecoration(hint: 'e.g. 10.00'),
                    style: const TextStyle(fontSize: 15),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Berat bersih wajib diisi';
                      if (double.tryParse(value) == null) return 'Input angka tidak valid';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text(
          'Sertifikasi / Kelengkapan Surat',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedCertificate,
          hint: const Text('Pilih Jenis Sertifikat', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _certificates.map((cert) {
            return DropdownMenuItem(value: cert, child: Text(cert, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onCertificateChanged,
          validator: (value) => value == null ? 'Keterangan sertifikasi emas wajib dipilih' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Catatan / Deskripsi Fisik',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.noteController,
          maxLines: 3,
          decoration: _getInputDecoration(hint: 'Contoh: Ada goresan sedikit di permukaan logam mulia...'),
          style: const TextStyle(fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildVehicleForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jenis Kendaraan',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedVehicleType,
          hint: const Text('Pilih Jenis Kendaraan', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _vehicleTypes.map((vType) {
            return DropdownMenuItem(value: vType, child: Text(vType, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onVehicleTypeChanged,
          validator: (value) => value == null ? 'Jenis kendaraan wajib dipilih' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Merk Kendaraan',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedBrand,
          hint: const Text('Pilih Merk Kendaraan', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _vehicleBrands.map((vBrand) {
            return DropdownMenuItem(value: vBrand, child: Text(vBrand, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onBrandChanged,
          validator: (value) => value == null ? 'Merk kendaraan wajib dipilih' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Tipe / Model',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.modelController,
          decoration: _getInputDecoration(hint: 'Contoh: Honda PCX 160 ABS / Toyota Avanza G'),
          style: const TextStyle(fontSize: 15),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Tipe kendaraan wajib diisi' : null,
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tahun Pembuatan',
                    style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: widget.vehicleYearController,
                    keyboardType: TextInputType.number,
                    decoration: _getInputDecoration(hint: 'e.g. 2021'),
                    style: const TextStyle(fontSize: 15),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Tahun wajib diisi';
                      final year = int.tryParse(value);
                      if (year == null || year < 1990 || year > DateTime.now().year + 1) return 'Tahun tidak valid';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nomor Polisi (Plat)',
                    style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: widget.plateNumberController,
                    decoration: _getInputDecoration(hint: 'Contoh: L 1234 ABC'),
                    style: const TextStyle(fontSize: 15),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Nomor plat wajib diisi' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text(
          'Kondisi Kendaraan',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedCondition,
          hint: const Text('Pilih Kondisi Fisik & Mesin', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _vehicleConditions.map((cond) {
            return DropdownMenuItem(value: cond, child: Text(cond, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onConditionChanged,
          validator: (value) => value == null ? 'Kondisi kendaraan wajib dipilih' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Kelengkapan Dokumen',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCheckbox(label: 'STNK Aktif', value: widget.hasStnk, onChanged: (val) => widget.onHasStnkChanged(val ?? false)),
            const SizedBox(width: 16),
            _buildCheckbox(label: 'BPKB Asli', value: widget.hasBpkb, onChanged: (val) => widget.onHasBpkbChanged(val ?? false)),
            const SizedBox(width: 16),
            _buildCheckbox(label: 'Faktur', value: widget.hasFaktur, onChanged: (val) => widget.onHasFakturChanged(val ?? false)),
          ],
        ),
      ],
    );
  }
}
