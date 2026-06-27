import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/services/gemini_taksiran_service.dart';
import 'new_pawn_shared_widgets.dart';

class Step1CollateralView extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final String selectedCollateral;
  final Function(String) onCollateralSelected;
  
  final bool barangPhotoUploaded;
  final ValueChanged<bool> onBarangPhotoUploadedChanged;

  // Barang form state & controllers
  final String selectedBarangType;
  final ValueChanged<String?> onBarangTypeChanged;
  final String? selectedBrand;
  final ValueChanged<String?> onBrandChanged;
  final TextEditingController modelController;
  final String? selectedCondition;
  final ValueChanged<String?> onConditionChanged;
  final TextEditingController noteController; 
  final int? customTaksiranOverride;
  final ValueChanged<int?>? onTaksiranOverrideChanged;
  final String deviceLock;
  final ValueChanged<String> onDeviceLockChanged;
  final bool hasCharger;
  final ValueChanged<bool> onHasChargerChanged;
  final bool hasTas;
  final ValueChanged<bool> onHasTasChanged;
  final bool hasDus;
  final ValueChanged<bool> onHasDusChanged;

  // Emas form state & controllers
  final String? selectedGoldType;
  final ValueChanged<String?> onGoldTypeChanged;
  final String? selectedKarat;
  final ValueChanged<String?> onKaratChanged;
  final TextEditingController grossWeightController;
  final TextEditingController netWeightController;
  final String? selectedCertificate;
  final ValueChanged<String?> onCertificateChanged;
  final String emasSistemTebus;
  final ValueChanged<String?> onEmasSistemTebusChanged;

  // Vehicle form state & controllers
  final TextEditingController vehicleBrandTypeController;
  final TextEditingController vehicleHargaBaruController;
  final TextEditingController vehicleYearController;
  final TextEditingController vehicleNoMesinController;
  final TextEditingController vehicleNoRangkaController;
  final TextEditingController vehicleNoPolisiController;
  final String vehicleSistemTebus;
  final ValueChanged<String?> onVehicleSistemTebusChanged;
  final String? selectedVehicleCondition;
  final ValueChanged<String?> onVehicleConditionChanged;
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
    required this.barangPhotoUploaded,
    required this.onBarangPhotoUploadedChanged,
    
    required this.selectedBarangType,
    required this.onBarangTypeChanged,
    required this.selectedBrand,
    required this.onBrandChanged,
    required this.modelController,
    required this.selectedCondition,
    required this.onConditionChanged,
    required this.noteController,
    this.customTaksiranOverride,
    this.onTaksiranOverrideChanged,
    required this.deviceLock,
    required this.onDeviceLockChanged,
    required this.hasCharger,
    required this.onHasChargerChanged,
    required this.hasTas,
    required this.onHasTasChanged,
    required this.hasDus,
    required this.onHasDusChanged,

    required this.selectedGoldType,
    required this.onGoldTypeChanged,
    required this.selectedKarat,
    required this.onKaratChanged,
    required this.grossWeightController,
    required this.netWeightController,
    required this.selectedCertificate,
    required this.onCertificateChanged,
    required this.emasSistemTebus,
    required this.onEmasSistemTebusChanged,

    required this.vehicleBrandTypeController,
    required this.vehicleHargaBaruController,
    required this.vehicleYearController,
    required this.vehicleNoMesinController,
    required this.vehicleNoRangkaController,
    required this.vehicleNoPolisiController,
    required this.vehicleSistemTebus,
    required this.onVehicleSistemTebusChanged,
    required this.selectedVehicleCondition,
    required this.onVehicleConditionChanged,
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
  bool _aiLoading = false;
  String? _aiMinPrice;
  String? _aiMaxPrice;
  String? _aiRecPawn;
  String? _aiNote;

  void _runAiTaksiran() async {
    final type = widget.selectedBarangType;
    final brand = widget.selectedBrand ?? '';
    final model = widget.modelController.text.trim();
    final condition = widget.selectedCondition ?? '';
    
    if (brand.isEmpty || model.isEmpty || condition.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih merk, tipe/model, dan kondisi terlebih dahulu untuk taksiran AI'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() => _aiLoading = true);
    try {
      final res = await GeminiTaksiranService.getTaksiran(
        jenis: type,
        merk: brand,
        model: model,
        kondisi: condition,
      );
      
      setState(() {
        _aiMinPrice = res.hargaPasarMin;
        _aiMaxPrice = res.hargaPasarMax;
        _aiRecPawn = res.rekomendasiGadai;
        _aiNote = res.catatan;
        _aiLoading = false;
      });

      final cleanVal = res.rekomendasiGadai.replaceAll(RegExp(r'[^0-9]'), '');
      final int val = int.tryParse(cleanVal) ?? 0;
      if (val > 0 && widget.onTaksiranOverrideChanged != null) {
        widget.onTaksiranOverrideChanged!(val);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI Taksiran berhasil terupdate!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal taksir AI: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  final Map<String, List<String>> _brandsPerType = {
    'Handphone': ['Apple', 'Samsung', 'Xiaomi', 'Oppo'],
    'Laptop': ['ASUS', 'Lenovo', 'HP', 'Dell', 'Acer', 'Apple'],
    'TV': ['Samsung', 'LG', 'Sony', 'Sharp', 'Panasonic', 'Xiaomi'],
    'Lainnya': ['Lainnya'],
  };

  final List<String> _barangConditions = [
    'Mulus (95%+)',
    'Lecet Pemakaian',
    'Minus Fungsi Sederhana'
  ];

  final List<String> _goldTypes = [
    'Emas Batangan / Logam Mulia',
    'Perhiasan (Cincin / Kalung / Gelang)',
    'Koin Emas'
  ];

  final List<String> _certificates = [
    'Sertifikat Antam',
    'Sertifikat UBS',
    'Non-Sertifikat / Surat Toko'
  ];

  final List<String> _vehicleConditions = [
    'Prima / Mulus',
    'Lecet Pemakaian',
    'Mesin Kasar / Modifikasi',
    'Mati / Rusak Berat'
  ];

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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: const Color(0xFF64748B).withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
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
                      icon: Icons.devices_other_rounded,
                      label: 'Barang',
                      isSelected: widget.selectedCollateral == 'Barang',
                      onTap: () => widget.onCollateralSelected('Barang'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CollateralCard(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Emas',
                      isSelected: widget.selectedCollateral == 'Emas',
                      onTap: () => widget.onCollateralSelected('Emas'),
                    ),
                  ),
                  const SizedBox(width: 12),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDynamicForm(),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 20),
                const Text(
                  'Foto Barang Gadai',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    widget.onBarangPhotoUploadedChanged(!widget.barangPhotoUploaded);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(!widget.barangPhotoUploaded ? 'Foto barang gadai berhasil diunggah' : 'Foto barang gadai dihapus'),
                        backgroundColor: !widget.barangPhotoUploaded ? Colors.green : Colors.grey,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: widget.barangPhotoUploaded ? const Color(0xFFECFDF5) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.barangPhotoUploaded ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.barangPhotoUploaded ? Icons.verified_user_rounded : Icons.camera_enhance_outlined,
                          color: widget.barangPhotoUploaded ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.barangPhotoUploaded ? 'Foto Barang Terunggah (Ketuk untuk ganti)' : 'Unggah Foto Barang Gadai',
                          style: TextStyle(
                            color: widget.barangPhotoUploaded ? const Color(0xFF047857) : const Color(0xFF64748B),
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
        ),
      ],
    );
  }

  Widget _buildDynamicForm() {
    switch (widget.selectedCollateral) {
      case 'Barang':
        return _buildBarangForm();
      case 'Emas':
        return _buildEmasForm();
      case 'Motor / Mobil':
        return _buildVehicleForm();
      default:
        return _buildBarangForm();
    }
  }

  Widget _buildBarangForm() {
    final brands = _brandsPerType[widget.selectedBarangType] ?? ['Lainnya'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Card AI Gemini Taksiran =====
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Gemini AI Taksiran',
                        style: TextStyle(color: Color(0xFF047857), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_aiLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(8)),
                      child: const Text('READY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_aiRecPawn != null) ...[
                Text(
                  'Rekomendasi Pinjaman: $_aiRecPawn',
                  style: const TextStyle(color: Color(0xFF065F46), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Harga Pasar: $_aiMinPrice - $_aiMaxPrice',
                  style: const TextStyle(color: Color(0xFF047857), fontSize: 12),
                ),
                if (_aiNote != null && _aiNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Catatan AI: $_aiNote',
                    style: const TextStyle(color: Color(0xFF065F46), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF10B981)),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _aiLoading ? null : _runAiTaksiran,
                  icon: const Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Taksir Nilai Gadai dengan Gemini AI',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Text(
          'Jenis Barang',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedBarangType,
          decoration: _getInputDecoration(),
          items: const [
            DropdownMenuItem(value: 'Handphone', child: Text('Handphone')),
            DropdownMenuItem(value: 'Laptop', child: Text('Laptop')),
            DropdownMenuItem(value: 'TV', child: Text('TV')),
            DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
          ],
          onChanged: widget.onBarangTypeChanged,
        ),
        const SizedBox(height: 20),

        const Text(
          'Merk Barang',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: brands.contains(widget.selectedBrand) ? widget.selectedBrand : null,
          hint: const Text('Pilih Merk', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: brands.map((brand) {
            return DropdownMenuItem(value: brand, child: Text(brand, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onBrandChanged,
          validator: (value) => value == null ? 'Silakan pilih merk barang' : null,
        ),
        const SizedBox(height: 20),
        
        const Text(
          'Tipe / Model',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.modelController,
          decoration: _getInputDecoration(hint: 'Contoh: iPhone 15 Pro Max / ROG Zephyrus G14'),
          style: const TextStyle(fontSize: 15),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Tipe / model tidak boleh kosong' : null,
        ),
        _buildInfoText('Jika tipe tidak tersedia anda bisa input manual...'),
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
          items: _barangConditions.map((cond) {
            return DropdownMenuItem(value: cond, child: Text(cond, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onConditionChanged,
          validator: (value) => value == null ? 'Silakan pilih kondisi barang' : null,
        ),
        const SizedBox(height: 20),
        
        const Text(
          'Keterangan Tambahan / Deskripsi Fisik',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.noteController,
          maxLines: 3,
          decoration: _getInputDecoration(hint: 'Catat keluhan fisik atau performa barang jaminan...'),
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 20),
        
        if (widget.selectedBarangType == 'Handphone') ...[
          const Text(
            'Kunci Perangkat',
            style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRadioButton('PIN/Sandi'),
              const SizedBox(width: 20),
              _buildRadioButton('Pola'),
              const SizedBox(width: 20),
              _buildRadioButton('Tanpa Kunci'),
            ],
          ),
          const SizedBox(height: 20),
        ],
        
        const Text(
          'Kelengkapan Barang',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCheckbox(label: 'Charger', value: widget.hasCharger, onChanged: (val) => widget.onHasChargerChanged(val ?? false)),
            const SizedBox(width: 20),
            _buildCheckbox(label: 'Tas', value: widget.hasTas, onChanged: (val) => widget.onHasTasChanged(val ?? false)),
            const SizedBox(width: 20),
            _buildCheckbox(label: 'Dos', value: widget.hasDus, onChanged: (val) => widget.onHasDusChanged(val ?? false)),
          ],
        ),
      ],
    );
  }

  Widget _buildEmasForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Card Kuning: Taksiran Emas =====
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E1), Color(0xFFFFF3C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFCA28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.workspace_premium_outlined, color: Color(0xFFF59E0B), size: 18),
                      SizedBox(width: 6),
                      Text('Harga Emas Murni (24K) Snapshot', style: TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(8)),
                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Rp 1.150.000 / gram', style: TextStyle(color: Color(0xFF78350F), fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('Update: Hari ini 10:00 WIB', style: TextStyle(color: Color(0xFF92400E), fontSize: 11)),
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFFFCA28)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hasil Taksiran Pasar Emas', style: TextStyle(color: Color(0xFF92400E), fontSize: 12)),
                  Builder(builder: (ctx) {
                    final gross = double.tryParse(widget.grossWeightController.text) ?? 0;
                    final Map<String, double> karatPcts = {
                      '6K': 0.250, '10K': 0.417, '14K': 0.585, '16K': 0.666,
                      '18K': 0.750, '20K': 0.833, '22K': 0.916, '24K': 0.999
                    };
                    final selectedKaratPct = karatPcts[widget.selectedKarat] ?? 0.0;
                    final taksiran = (gross * 1150000 * selectedKaratPct).toInt();
                    if (taksiran <= 0) {
                      return const Text('Isi berat & kadar karat', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12));
                    }
                    return Text('Rp ${_formatCurrency(taksiran)}', style: const TextStyle(color: Color(0xFF78350F), fontSize: 15, fontWeight: FontWeight.bold));
                  }),
                ],
              ),
            ],
          ),
        ),

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
          'Kadar Emas (Karat)',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Builder(builder: (ctx) {
          final karatOptions = [
            {'label': '6K', 'pct': '25.0%'},
            {'label': '10K', 'pct': '41.7%'},
            {'label': '14K', 'pct': '58.5%'},
            {'label': '16K', 'pct': '66.6%'},
            {'label': '18K', 'pct': '75.0%'},
            {'label': '20K', 'pct': '83.3%'},
            {'label': '22K', 'pct': '91.6%'},
            {'label': '24K', 'pct': '99.9%'},
          ];
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: karatOptions.map((k) {
              final isSelected = widget.selectedKarat == k['label'];
              return GestureDetector(
                onTap: () {
                  widget.onKaratChanged(k['label']);
                  // Trigger UI rebuild for estimated price Card
                  setState(() {});
                },
                child: Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(k['label']!, style: TextStyle(color: isSelected ? Colors.white : AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(k['pct']!, style: TextStyle(color: isSelected ? Colors.white70 : AppColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }),
        if (widget.selectedKarat == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Kadar karat wajib dipilih', style: TextStyle(color: Colors.red, fontSize: 12)),
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
                    onChanged: (val) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Berat kotor wajib diisi';
                      if (double.tryParse(value) == null) return 'Angka tidak valid';
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
                      if (double.tryParse(value) == null) return 'Angka tidak valid';
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
          validator: (value) => value == null ? 'Sertifikasi wajib dipilih' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Sistem Tebus',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.emasSistemTebus,
          decoration: _getInputDecoration(),
          items: const [
            DropdownMenuItem(value: 'Langsung Tebas', child: Text('Langsung Tebas')),
          ],
          onChanged: widget.onEmasSistemTebusChanged,
        ),
      ],
    );
  }

  Widget _buildVehicleForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Card Orange: Taksiran Kendaraan =====
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFB8C00)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.two_wheeler_rounded, color: Color(0xFFF97316), size: 18),
                  SizedBox(width: 6),
                  Text('Estimasi Nilai Kendaraan', style: TextStyle(color: Color(0xFF7C2D12), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Nilai taksiran jaminan kendaraan bermotor dihitung berdasarkan depresiasi 10% per tahun.',
                style: TextStyle(color: Color(0xFF9A3412), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFFB8C00)),
              const SizedBox(height: 4),
              Builder(builder: (ctx) {
                final yearStr = widget.vehicleYearController.text;
                final year = int.tryParse(yearStr);
                final hargaBaru = double.tryParse(
                  widget.vehicleHargaBaruController.text.replaceAll('.', '').replaceAll(',', '')
                ) ?? 0;
                
                if (year == null || hargaBaru <= 0) {
                  return const Text(
                    'Isi tahun pembelian & perkiraan harga baru untuk melihat taksiran',
                    style: TextStyle(color: Color(0xFFF97316), fontSize: 12),
                  );
                }
                
                final ageYears = (DateTime.now().year - year).clamp(0, 26);
                const depresiasi = 0.10;
                final faktor = (1 - depresiasi * ageYears).clamp(0.3, 1.0);
                final taksiran = (hargaBaru * faktor * 0.7).toInt();
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Umur $ageYears tahun (LTV 70% pasar)', style: const TextStyle(color: Color(0xFF9A3412), fontSize: 11)),
                    Text('Rp ${_formatCurrency(taksiran)}', style: const TextStyle(color: Color(0xFF7C2D12), fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                );
              }),
            ],
          ),
        ),
        // ===== End Card Orange =====

        const Text(
          'Merk / Tipe Kendaraan',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.vehicleBrandTypeController,
          decoration: _getInputDecoration(hint: 'Contoh: Honda CB150R / Toyota Avanza'),
          style: const TextStyle(fontSize: 15),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Merk & tipe kendaraan wajib diisi' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Perkiraan Harga Baru (Rp)',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.vehicleHargaBaruController,
          keyboardType: TextInputType.number,
          decoration: _getInputDecoration(hint: 'Contoh: 25.000.000'),
          style: const TextStyle(fontSize: 15),
          onChanged: (value) {
            if (value.isEmpty) return;
            final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
            final val = int.tryParse(clean) ?? 0;
            final formatted = val > 0 ? _formatCurrency(val) : '';
            widget.vehicleHargaBaruController.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
            setState(() {});
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Harga baru wajib diisi';
            final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
            if (int.tryParse(clean) == null || int.parse(clean) <= 0) return 'Harga baru tidak valid';
            return null;
          },
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tahun Pembelian',
                    style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: widget.vehicleYearController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: _getInputDecoration(hint: 'e.g. 2021'),
                    style: const TextStyle(fontSize: 15),
                    onChanged: (val) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Tahun wajib diisi';
                      final year = int.tryParse(value);
                      final currentYear = DateTime.now().year;
                      if (year == null || year < 2000 || year > currentYear) {
                        return 'Tahun tidak valid (Min 2000)';
                      }
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
                    controller: widget.vehicleNoPolisiController,
                    textCapitalization: TextCapitalization.characters,
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
          value: widget.selectedVehicleCondition,
          hint: const Text('Pilih Kondisi Fisik & Mesin', style: TextStyle(color: AppColors.textInputHint, fontSize: 15)),
          decoration: _getInputDecoration(),
          items: _vehicleConditions.map((cond) {
            return DropdownMenuItem(value: cond, child: Text(cond, style: const TextStyle(fontSize: 15)));
          }).toList(),
          onChanged: widget.onVehicleConditionChanged,
          validator: (value) => value == null ? 'Kondisi kendaraan wajib dipilih' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Nomor Identitas Kendaraan',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.vehicleNoMesinController,
          textCapitalization: TextCapitalization.characters,
          decoration: _getInputDecoration(hint: 'Nomor Mesin (auto-uppercase)'),
          style: const TextStyle(fontSize: 15),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Nomor mesin wajib diisi' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.vehicleNoRangkaController,
          textCapitalization: TextCapitalization.characters,
          decoration: _getInputDecoration(hint: 'Nomor Rangka (auto-uppercase)'),
          style: const TextStyle(fontSize: 15),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Nomor rangka wajib diisi' : null,
        ),
        const SizedBox(height: 20),

        const Text(
          'Sistem Tebus',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.vehicleSistemTebus,
          decoration: _getInputDecoration(),
          items: const [
            DropdownMenuItem(value: 'Langsung Tebas', child: Text('Langsung Tebas')),
          ],
          onChanged: widget.onVehicleSistemTebusChanged,
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
