import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/services/gemini_taksiran_service.dart';
import 'package:galaxi_gadai/core/services/gold_price_service.dart';
import 'package:image_picker/image_picker.dart';
import 'new_pawn_shared_widgets.dart';

class Step1CollateralView extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final String selectedCollateral;
  final Function(String) onCollateralSelected;
  
  final bool barangPhotoUploaded;
  final ValueChanged<bool> onBarangPhotoUploadedChanged;
  final ValueChanged<XFile?>? onBarangPhotoChanged;  // ← expose XFile ke parent

  // Foto Dokumen (dipindah dari Step 3)
  final bool ktpUploaded;
  final ValueChanged<bool> onKtpUploadedChanged;
  final ValueChanged<XFile?>? onKtpPhotoChanged;          // ← expose XFile ke parent
  final bool customerAndBarangPhotoUploaded;
  final ValueChanged<bool> onCustomerAndBarangPhotoUploadedChanged;
  final ValueChanged<XFile?>? onNasabahPhotoChanged;      // ← expose XFile ke parent
  final ValueChanged<XFile?>? onBarangGadaiPhotoChanged;  // ← expose XFile ke parent

  // Barang form state & controllers
  final String selectedBarangType;
  final ValueChanged<String?> onBarangTypeChanged;
  final TextEditingController brandController;        // Merk (free-text)
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
  final TextEditingController storageController;      // Internal Storage
  final TextEditingController ramController;          // RAM
  final TextEditingController lockCodeController;     // PIN / kode pola kunci perangkat

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
    this.onBarangPhotoChanged,
    required this.ktpUploaded,
    required this.onKtpUploadedChanged,
    this.onKtpPhotoChanged,
    required this.customerAndBarangPhotoUploaded,
    required this.onCustomerAndBarangPhotoUploadedChanged,
    this.onNasabahPhotoChanged,
    this.onBarangGadaiPhotoChanged,
    
    required this.selectedBarangType,
    required this.onBarangTypeChanged,
    required this.brandController,
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
    required this.storageController,
    required this.ramController,
    required this.lockCodeController,

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

  // ── Harga Emas Live ──
  int _goldPricePerGram = 1_620_000;
  bool _goldPriceLoading = false;
  bool _goldPriceIsLive = false;
  String _goldPriceLabel = 'Memuat...';



  // ── Foto Dokumen (dipindah dari Step 3) ──
  XFile? _ktpPhoto;
  XFile? _nasabahBarangPhoto;
  XFile? _barangGadaiPhoto;
  bool _isPickingKtp = false;
  bool _isPickingNasabah = false;
  bool _isPickingBarangGadai = false;

  // ── Custom Storage / RAM input toggle ──
  bool _showCustomStorage = false;
  bool _showCustomRam = false;

  // ── Tambahan untuk akurasi AI ──
  // Tahun rilis/beli untuk barang — dikelola internal (tidak disimpan ke DB)
  final TextEditingController _tahunPembelianController = TextEditingController();
  // Odometer / jarak tempuh untuk kendaraan
  final TextEditingController _odometerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch harga emas jika tampilan awal adalah Emas
    if (widget.selectedCollateral == 'Emas') {
      _fetchGoldPrice();
    }
  }

  Future<void> _fetchGoldPrice() async {
    if (_goldPriceLoading) return;
    setState(() => _goldPriceLoading = true);
    try {
      final result = await GoldPriceService.fetchGoldPrice();
      if (mounted) {
        setState(() {
          _goldPricePerGram = result.pricePerGram;
          _goldPriceIsLive = result.isLive;
          _goldPriceLabel = result.lastUpdatedLabel;
          _goldPriceLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _goldPriceLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant Step1CollateralView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCollateral == 'Emas' &&
        oldWidget.selectedCollateral != 'Emas') {
      _fetchGoldPrice();
    }
    // Reset tahun & odometer saat jenis jaminan ganti
    if (widget.selectedCollateral != oldWidget.selectedCollateral) {
      _tahunPembelianController.clear();
      _odometerController.clear();
      _showCustomStorage = false;
      _showCustomRam = false;
    }
  }

  @override
  void dispose() {
    _tahunPembelianController.dispose();
    _odometerController.dispose();
    super.dispose();
  }



  /// Buka bottom sheet pilih sumber foto
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

  /// Ambil foto KTP
  Future<void> _pickKtpPhoto() async {
    if (_isPickingKtp) return;
    final ImageSource? source = await _showSourcePicker('Unggah Foto KTP');
    if (source == null || !mounted) return;
    setState(() => _isPickingKtp = true);
    try {
      final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1280);
      if (!mounted) return;
      if (picked != null) {
        setState(() => _ktpPhoto = picked);
        widget.onKtpUploadedChanged(true);
        widget.onKtpPhotoChanged?.call(picked); // ← kirim ke parent
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto KTP berhasil diambil'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
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
        widget.onNasabahPhotoChanged?.call(picked); // ← kirim ke parent
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

  /// Ambil foto barang gadai (sisi lain)
  Future<void> _pickBarangGadaiPhoto() async {
    if (_isPickingBarangGadai) return;
    final ImageSource? source = await _showSourcePicker('Foto Barang Gadai');
    if (source == null || !mounted) return;
    setState(() => _isPickingBarangGadai = true);
    try {
      final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1280);
      if (!mounted) return;
      if (picked != null) {
        setState(() => _barangGadaiPhoto = picked);
        widget.onBarangPhotoUploadedChanged(true);
        widget.onBarangPhotoChanged?.call(picked);
        widget.onBarangGadaiPhotoChanged?.call(picked); // ← kirim ke parent
      }
    } finally {
      if (mounted) setState(() => _isPickingBarangGadai = false);
    }
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

  void _runAiTaksiran() async {
    String jenis, merk, model, kondisi;
    String? storage, ram, tahunPembuatan, beratGram, kadarKarat, jenisEmas, kelengkapan;

    if (widget.selectedCollateral == 'Barang') {
      jenis = widget.selectedBarangType;
      merk = widget.brandController.text.trim();
      model = widget.modelController.text.trim();
      kondisi = widget.selectedCondition ?? '';
      storage = widget.storageController.text.trim().isNotEmpty ? widget.storageController.text.trim() : null;
      ram = widget.ramController.text.trim().isNotEmpty ? widget.ramController.text.trim() : null;
      tahunPembuatan = _tahunPembelianController.text.trim().isNotEmpty ? _tahunPembelianController.text.trim() : null;
      if (merk.isEmpty || model.isEmpty || kondisi.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Isi merk, tipe/model, dan kondisi terlebih dahulu'),
          backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    } else if (widget.selectedCollateral == 'Emas') {
      jenis = 'Emas';
      jenisEmas = widget.selectedGoldType;
      merk = widget.selectedGoldType ?? 'Emas';
      model = widget.selectedKarat ?? '';
      kondisi = widget.selectedCertificate ?? 'Tanpa Sertifikat';
      kadarKarat = widget.selectedKarat;
      beratGram = widget.grossWeightController.text.isNotEmpty
          ? '${widget.grossWeightController.text} gram' : null;
      if (widget.selectedGoldType == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih jenis emas dan isi berat terlebih dahulu'),
          backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    } else {
      // Motor / Mobil
      jenis = 'Kendaraan Bermotor';
      merk = widget.vehicleBrandTypeController.text.trim();
      model = widget.vehicleNoPolisiController.text.trim();
      kondisi = widget.selectedVehicleCondition ?? '';
      tahunPembuatan = widget.vehicleYearController.text.isNotEmpty
          ? widget.vehicleYearController.text : null;
      final docs = <String>[];
      if (widget.hasStnk) docs.add('STNK');
      if (widget.hasBpkb) docs.add('BPKB');
      if (widget.hasFaktur) docs.add('Faktur');
      kelengkapan = docs.isEmpty ? 'Tidak ada dokumen lengkap' : docs.join(', ');
      if (merk.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Isi merk/tipe kendaraan terlebih dahulu'),
          backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }

    // Keterangan / catatan tambahan — gabungkan note + status kunci + kode kunci
    final hasDeviceLock = ['Handphone', 'Laptop', 'Tablet', 'Konsol Game'].contains(widget.selectedBarangType);
    final lockInfo = hasDeviceLock && widget.selectedCollateral == 'Barang'
        ? 'Kunci perangkat: ${widget.deviceLock}'
            '${widget.lockCodeController.text.trim().isNotEmpty && widget.deviceLock != "Tanpa Kunci" ? " (kode tersedia)" : ""}'
        : null;

    String? keteranganText;
    final noteParts = <String>[];
    if (widget.noteController.text.trim().isNotEmpty) noteParts.add(widget.noteController.text.trim());
    if (lockInfo != null) noteParts.add(lockInfo);
    if (_odometerController.text.trim().isNotEmpty) noteParts.add('Odometer: ${_odometerController.text.trim()} km');
    if (noteParts.isNotEmpty) keteranganText = noteParts.join(' | ');

    setState(() => _aiLoading = true);
    try {
      final res = await GeminiTaksiranService.getTaksiran(
        jenis: jenis, merk: merk, model: model, kondisi: kondisi,
        storage: storage, ram: ram,
        tahunPembuatan: tahunPembuatan,
        jenisEmas: jenisEmas, kadarKarat: kadarKarat, beratGram: beratGram,
        odometer: _odometerController.text.trim().isNotEmpty ? _odometerController.text.trim() : null,
        kelengkapan: kelengkapan,
        keterangan: keteranganText,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ AI Taksiran berhasil terupdate!'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal taksir AI: $e'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Brand suggestions per jenis barang ──
  final Map<String, List<String>> _brandSuggestions = {
    'Handphone': ['Apple', 'Samsung', 'Xiaomi', 'Oppo', 'Vivo', 'Realme', 'OnePlus', 'Nothing', 'Infinix', 'Motorola'],
    'Laptop': ['ASUS', 'Lenovo', 'HP', 'Dell', 'Acer', 'Apple', 'MSI', 'Toshiba', 'Huawei'],
    'TV': ['Samsung', 'LG', 'Sony', 'Sharp', 'Panasonic', 'Xiaomi', 'TCL', 'Polytron', 'Hisense'],
    'Kamera': ['Canon', 'Nikon', 'Sony', 'Fujifilm', 'GoPro', 'DJI', 'Olympus', 'Panasonic'],
    'Tablet': ['Apple', 'Samsung', 'Xiaomi', 'Lenovo', 'Huawei', 'Amazon'],
    'Konsol Game': ['Sony PlayStation', 'Microsoft Xbox', 'Nintendo', 'Steam Deck', 'ASUS ROG Ally'],
    'Jam Tangan': ['Casio', 'Apple Watch', 'Samsung Watch', 'Garmin', 'Rolex', 'Omega', 'Tag Heuer'],
    'Lainnya': [],
  };

  // ── Pilihan Storage & RAM ──
  static const List<String> _storageOptions = ['32GB', '64GB', '128GB', '256GB', '512GB', '1TB', '2TB'];
  static const List<String> _ramOptions = ['2GB', '3GB', '4GB', '6GB', '8GB', '12GB', '16GB', '32GB'];

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

  /// Card AI Taksiran yang bisa digunakan di semua jenis jaminan
  Widget _buildAiTaksiranCard({
    required String buttonLabel,
    required Color accentColor,
    required Color bgStart,
    required Color bgEnd,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgStart, bgEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome_rounded, color: accentColor, size: 20),
                const SizedBox(width: 6),
                Text('Taksiran AI',
                    style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
              if (_aiLoading)
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(8)),
                  child: const Text('READY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (_aiRecPawn != null) ...[
            const SizedBox(height: 10),
            Text('Rekomendasi Pinjaman: $_aiRecPawn',
                style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Harga Pasar: $_aiMinPrice — $_aiMaxPrice',
                style: TextStyle(color: accentColor.withValues(alpha: 0.85), fontSize: 12)),
            if (_aiNote != null && _aiNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Catatan AI: $_aiNote',
                  style: TextStyle(color: accentColor.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            Divider(color: borderColor),
            const SizedBox(height: 6),
          ] else
            const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _aiLoading ? null : _runAiTaksiran,
              icon: const Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
              label: Text(buttonLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
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
                const SizedBox(height: 8),
                // ─── Foto Dokumen & Nasabah ───
                const Text(
                  'Foto KTP, Barang & Nasabah',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ambil foto KTP nasabah, foto nasabah memegang barang, dan foto tambahan barang',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),
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
                    // Kolom 3 — Foto Barang Gadai sisi lain
                    Expanded(child: _buildPhotoSlot(
                      label: 'Barang Gadai',
                      icon: Icons.camera_enhance_outlined,
                      photo: _barangGadaiPhoto,
                      isUploaded: _barangGadaiPhoto != null,
                      isPicking: _isPickingBarangGadai,
                      onTap: _pickBarangGadaiPhoto,
                    )),
                  ],
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
    final suggestions = _brandSuggestions[widget.selectedBarangType] ?? [];
    final showStorageRam = widget.selectedBarangType == 'Handphone' || widget.selectedBarangType == 'Laptop';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───── AI Taksiran Card ─────
        _buildAiTaksiranCard(
          buttonLabel: 'Taksir Nilai Gadai dengan AI',
          accentColor: const Color(0xFF047857),
          bgStart: const Color(0xFFECFDF5),
          bgEnd: const Color(0xFFD1FAE5),
          borderColor: const Color(0xFF10B981),
        ),

        // Jenis Barang
        const Text('Jenis Barang', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: widget.selectedBarangType,
          decoration: _getInputDecoration(),
          items: const [
            DropdownMenuItem(value: 'Handphone', child: Text('Handphone')),
            DropdownMenuItem(value: 'Laptop', child: Text('Laptop')),
            DropdownMenuItem(value: 'Tablet', child: Text('Tablet')),
            DropdownMenuItem(value: 'TV', child: Text('TV')),
            DropdownMenuItem(value: 'Kamera', child: Text('Kamera')),
            DropdownMenuItem(value: 'Konsol Game', child: Text('Konsol Game')),
            DropdownMenuItem(value: 'Jam Tangan', child: Text('Jam Tangan')),
            DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
          ],
          onChanged: (val) {
            widget.onBarangTypeChanged(val);
            // Reset brand suggestions when type changes
            setState(() {});
          },
        ),
        const SizedBox(height: 20),

        // Merk Barang — free-text + suggestion chips
        const Text('Merk Barang', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.brandController,
          decoration: _getInputDecoration(hint: 'Ketik merk atau pilih dari saran di bawah...'),
          style: const TextStyle(fontSize: 15),
          onChanged: (_) => setState(() {}),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Merk barang tidak boleh kosong' : null,
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((brand) {
              final isSelected = widget.brandController.text.toLowerCase() == brand.toLowerCase();
              return GestureDetector(
                onTap: () => setState(() => widget.brandController.text = brand),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(brand, style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textDark,
                    fontSize: 12, fontWeight: FontWeight.w500,
                  )),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),

        // Tipe / Model
        const Text('Tipe / Model', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.modelController,
          decoration: _getInputDecoration(hint: 'Contoh: iPhone 15 Pro Max / ROG Zephyrus G14'),
          style: const TextStyle(fontSize: 15),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Tipe / model tidak boleh kosong' : null,
        ),
        _buildInfoText('Masukkan model lengkap agar taksiran AI lebih akurat'),
        const SizedBox(height: 20),

        // Tahun Rilis / Tahun Beli (opsional, untuk akurasi AI)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('Tahun Rilis / Beli', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Opsional', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tahunPembelianController,
                    keyboardType: TextInputType.number,
                    decoration: _getInputDecoration(hint: 'e.g. 2023'),
                    style: const TextStyle(fontSize: 15),
                    onChanged: (_) => setState(() {}),
                  ),
                  _buildInfoText('Membantu AI menghitung depresiasi nilai barang'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ───── Internal Storage & RAM (hanya Handphone & Laptop) ─────
        if (showStorageRam) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Internal Storage
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Internal Storage', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ..._storageOptions.map((opt) {
                          final isSelected = widget.storageController.text == opt;
                          return GestureDetector(
                            onTap: () => setState(() {
                              widget.storageController.text = isSelected ? '' : opt;
                              if (!isSelected) _showCustomStorage = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.inputBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                              ),
                              child: Text(opt, style: TextStyle(color: isSelected ? Colors.white : AppColors.textDark, fontSize: 11, fontWeight: FontWeight.w500)),
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: () => setState(() {
                            _showCustomStorage = !_showCustomStorage;
                            if (_showCustomStorage && _storageOptions.contains(widget.storageController.text)) {
                              widget.storageController.clear();
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _showCustomStorage ? const Color(0xFF6366F1) : AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _showCustomStorage ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0)),
                            ),
                            child: Text('Lainnya', style: TextStyle(color: _showCustomStorage ? Colors.white : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                    if (_showCustomStorage) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: widget.storageController,
                        decoration: _getInputDecoration(hint: 'Contoh: 512GB'),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // RAM
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RAM', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ..._ramOptions.map((opt) {
                          final isSelected = widget.ramController.text == opt;
                          return GestureDetector(
                            onTap: () => setState(() {
                              widget.ramController.text = isSelected ? '' : opt;
                              if (!isSelected) _showCustomRam = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.inputBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                              ),
                              child: Text(opt, style: TextStyle(color: isSelected ? Colors.white : AppColors.textDark, fontSize: 11, fontWeight: FontWeight.w500)),
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: () => setState(() {
                            _showCustomRam = !_showCustomRam;
                            if (_showCustomRam && _ramOptions.contains(widget.ramController.text)) {
                              widget.ramController.clear();
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _showCustomRam ? const Color(0xFF6366F1) : AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _showCustomRam ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0)),
                            ),
                            child: Text('Lainnya', style: TextStyle(color: _showCustomRam ? Colors.white : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                    if (_showCustomRam) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: widget.ramController,
                        decoration: _getInputDecoration(hint: 'Contoh: 6GB'),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Kondisi Barang
        const Text('Kondisi Barang', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
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

        // Keterangan
        const Text('Keterangan Tambahan / Deskripsi Fisik', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.noteController,
          maxLines: 3,
          decoration: _getInputDecoration(hint: 'Catat keluhan fisik atau performa barang jaminan...'),
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 20),

        if (['Handphone', 'Laptop', 'Tablet', 'Konsol Game'].contains(widget.selectedBarangType)) ...[
          const Text('Kunci Perangkat', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            _buildRadioButton('PIN/Sandi'),
            const SizedBox(width: 20),
            _buildRadioButton('Pola'),
            const SizedBox(width: 20),
            _buildRadioButton('Tanpa Kunci'),
          ]),
          _buildInfoText(
            widget.selectedBarangType == 'Laptop'
              ? 'Apakah laptop memiliki password login atau tidak'
              : widget.selectedBarangType == 'Konsol Game'
                ? 'Apakah akun konsol game terkunci (PSN/Xbox/Nintendo account)'
                : 'Apakah perangkat memiliki kunci layar aktif',
          ),

          // Input kode PIN atau deskripsi pola (muncul saat bukan Tanpa Kunci)
          if (widget.deviceLock != 'Tanpa Kunci') ...[
            const SizedBox(height: 12),
            _PinLockInput(
              deviceLock: widget.deviceLock,
              controller: widget.lockCodeController,
            ),
          ],
          const SizedBox(height: 20),
        ],

        const Text('Kelengkapan Barang', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _buildCheckbox(label: 'Charger', value: widget.hasCharger, onChanged: (val) => widget.onHasChargerChanged(val ?? false)),
          const SizedBox(width: 20),
          _buildCheckbox(label: 'Tas', value: widget.hasTas, onChanged: (val) => widget.onHasTasChanged(val ?? false)),
          const SizedBox(width: 20),
          _buildCheckbox(label: 'Dos', value: widget.hasDus, onChanged: (val) => widget.onHasDusChanged(val ?? false)),
        ]),
      ],
    );
  }


  Widget _buildEmasForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───── AI Taksiran Emas ─────
        _buildAiTaksiranCard(
          buttonLabel: 'Taksir Nilai Gadai Emas dengan AI',
          accentColor: const Color(0xFFF59E0B),
          bgStart: const Color(0xFFFFF8E1),
          bgEnd: const Color(0xFFFFF3C0),
          borderColor: const Color(0xFFFFCA28),
        ),
        // ===== Card Kuning: Harga Emas Live =====
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.workspace_premium_outlined, color: Color(0xFFF59E0B), size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Harga Emas Murni (24K)',
                            style: TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _goldPriceIsLive ? const Color(0xFFF59E0B) : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_goldPriceLoading)
                          const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                        else
                          Icon(_goldPriceIsLive ? Icons.wifi_rounded : Icons.wifi_off_rounded, size: 10, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(_goldPriceIsLive ? 'LIVE' : 'OFFLINE', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 3),
                        GestureDetector(
                          onTap: _fetchGoldPrice,
                          child: const Icon(Icons.refresh_rounded, size: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Harga emas live
              _goldPriceLoading
                  ? const SizedBox(
                      height: 28,
                      child: Row(children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B))),
                        SizedBox(width: 8),
                        Text('Mengambil harga emas...', style: TextStyle(color: Color(0xFF92400E), fontSize: 13)),
                      ]),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rp ${_formatCurrency(_goldPricePerGram)} / gram',
                          style: const TextStyle(color: Color(0xFF78350F), fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(_goldPriceLabel, style: const TextStyle(color: Color(0xFF92400E), fontSize: 11)),
                      ],
                    ),
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
                    // Gunakan harga emas live
                    final taksiran = (gross * _goldPricePerGram * selectedKaratPct).toInt();
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
        // ───── AI Taksiran Kendaraan ─────
        _buildAiTaksiranCard(
          buttonLabel: 'Taksir Nilai Kendaraan dengan AI',
          accentColor: const Color(0xFFF97316),
          bgStart: const Color(0xFFFFF3E0),
          bgEnd: const Color(0xFFFFE0B2),
          borderColor: const Color(0xFFFB8C00),
        ),
        // ===== Card Orange: Estimasi Formula (tetap ada) =====
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
        const SizedBox(height: 16),

        // Odometer / Jarak Tempuh
        Row(children: [
          const Text('Odometer / Jarak Tempuh', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
            child: const Text('Opsional', style: TextStyle(color: Color(0xFFF97316), fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          controller: _odometerController,
          keyboardType: TextInputType.number,
          decoration: _getInputDecoration(hint: 'Jarak tempuh dalam km, contoh: 35000'),
          style: const TextStyle(fontSize: 15),
          onChanged: (_) => setState(() {}),
        ),
        _buildInfoText('Odometer rendah = nilai lebih tinggi. Sangat membantu akurasi taksiran AI.'),
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

// ═══════════════════════════════════════════════════════════
// Input kode kunci perangkat (PIN / Interactive Pattern Grid)
// ═══════════════════════════════════════════════════════════
class _PinLockInput extends StatefulWidget {
  final String deviceLock;
  final TextEditingController controller;
  const _PinLockInput({required this.deviceLock, required this.controller});
  @override
  State<_PinLockInput> createState() => _PinLockInputState();
}

class _PinLockInputState extends State<_PinLockInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    if (widget.deviceLock == 'Pola') {
      return _PatternLockInput(controller: widget.controller);
    }

    final isPIN = widget.deviceLock == 'PIN/Sandi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(
            isPIN ? Icons.pin_outlined : Icons.lock_outline,
            size: 16, color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          const Text(
            'Kode PIN / Sandi Perangkat',
            style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          keyboardType: TextInputType.number,
          obscureText: _obscure,
          maxLength: 8,
          decoration: InputDecoration(
            hintText: 'Masukkan PIN perangkat',
            hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 14),
            filled: true,
            fillColor: AppColors.inputBackground,
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          style: const TextStyle(fontSize: 15, letterSpacing: 4.0),
        ),
        const SizedBox(height: 4),
        const Text(
          '🔒 Disimpan aman — hanya untuk keperluan gadai internal',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Interactive 3x3 Pattern Lock Widget (Titik Pola Swipe/Drag)
// ═══════════════════════════════════════════════════════════
class _PatternLockInput extends StatefulWidget {
  final TextEditingController controller;
  const _PatternLockInput({required this.controller});

  @override
  State<_PatternLockInput> createState() => _PatternLockInputState();
}

class _PatternLockInputState extends State<_PatternLockInput> {
  final List<int> _selectedNodes = [];
  Offset? _currentDragPos;

  @override
  void initState() {
    super.initState();
    _parseExistingText();
  }

  void _parseExistingText() {
    final text = widget.controller.text;
    if (text.contains(RegExp(r'\d'))) {
      final matches = RegExp(r'\d').allMatches(text);
      for (final m in matches) {
        final n = int.tryParse(m.group(0)!);
        if (n != null && n >= 1 && n <= 9 && !_selectedNodes.contains(n)) {
          _selectedNodes.add(n);
        }
      }
    }
  }

  void _updateControllerText() {
    if (_selectedNodes.isEmpty) {
      widget.controller.clear();
    } else {
      widget.controller.text = 'Pola: ${_selectedNodes.join('-')}';
    }
  }

  void _clearPattern() {
    setState(() {
      _selectedNodes.clear();
      _currentDragPos = null;
      widget.controller.clear();
    });
    HapticFeedback.mediumImpact();
  }

  void _handleTouch(Offset localPos, Size size) {
    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;
    final hitRadius = cellWidth * 0.38;

    for (int i = 1; i <= 9; i++) {
      final idx = i - 1;
      final col = idx % 3;
      final row = idx ~/ 3;
      final center = Offset((col + 0.5) * cellWidth, (row + 0.5) * cellHeight);

      if ((localPos - center).distance <= hitRadius) {
        if (!_selectedNodes.contains(i)) {
          setState(() {
            _selectedNodes.add(i);
            _updateControllerText();
          });
          HapticFeedback.lightImpact();
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.gesture, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'Pola Kunci Perangkat',
                  style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (_selectedNodes.isNotEmpty)
              GestureDetector(
                onTap: _clearPattern,
                child: const Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Ulangi', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _selectedNodes.isNotEmpty ? AppColors.primary : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Visual Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _selectedNodes.isNotEmpty ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _selectedNodes.isNotEmpty ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedNodes.isNotEmpty ? Icons.check_circle_rounded : Icons.touch_app_outlined,
                      size: 16,
                      color: _selectedNodes.isNotEmpty ? Colors.green : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedNodes.isNotEmpty
                          ? 'Pola: ${_selectedNodes.join(' → ')}'
                          : 'Geser jari Anda untuk menghubungkan titik pola',
                      style: TextStyle(
                        color: _selectedNodes.isNotEmpty ? AppColors.primary : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: _selectedNodes.isNotEmpty ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive 3x3 Canvas Grid
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      return GestureDetector(
                        onPanStart: (details) {
                          _handleTouch(details.localPosition, size);
                          setState(() => _currentDragPos = details.localPosition);
                        },
                        onPanUpdate: (details) {
                          _handleTouch(details.localPosition, size);
                          setState(() => _currentDragPos = details.localPosition);
                        },
                        onPanEnd: (_) {
                          setState(() => _currentDragPos = null);
                        },
                        onPanCancel: () {
                          setState(() => _currentDragPos = null);
                        },
                        child: CustomPaint(
                          size: size,
                          painter: PatternLockPainter(
                            nodes: _selectedNodes,
                            currentDragPos: _currentDragPos,
                            primaryColor: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                _selectedNodes.isEmpty
                    ? '💡 Tarik garis dari satu titik ke titik lainnya'
                    : '✅ Pola tersimpan (${_selectedNodes.length} titik)',
                style: TextStyle(
                  color: _selectedNodes.isNotEmpty ? Colors.green.shade700 : AppColors.textMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PatternLockPainter extends CustomPainter {
  final List<int> nodes;
  final Offset? currentDragPos;
  final Color primaryColor;

  PatternLockPainter({
    required this.nodes,
    required this.currentDragPos,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;

    Offset getNodeCenter(int nodeIndex) {
      final idx = nodeIndex - 1;
      final col = idx % 3;
      final row = idx ~/ 3;
      return Offset((col + 0.5) * cellWidth, (row + 0.5) * cellHeight);
    }

    // 1. Line connections between selected nodes
    if (nodes.length > 1) {
      final linePaint = Paint()
        ..color = primaryColor
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final start = getNodeCenter(nodes.first);
      path.moveTo(start.dx, start.dy);
      for (int i = 1; i < nodes.length; i++) {
        final pt = getNodeCenter(nodes[i]);
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // 2. Drag line to active finger position
    if (nodes.isNotEmpty && currentDragPos != null) {
      final dragLinePaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.6)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      final lastPt = getNodeCenter(nodes.last);
      canvas.drawLine(lastPt, currentDragPos!, dragLinePaint);
    }

    // 3. Draw 9 dots with interactive highlights
    for (int i = 1; i <= 9; i++) {
      final center = getNodeCenter(i);
      final isSelected = nodes.contains(i);

      if (isSelected) {
        // Glowing aura
        final outerPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 26.0, outerPaint);

        // Ring
        final ringPaint = Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(center, 16.0, ringPaint);

        // Inner solid dot
        final innerPaint = Paint()
          ..color = primaryColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 7.0, innerPaint);
      } else {
        // Neutral unselected dot
        final unselectedPaint = Paint()
          ..color = const Color(0xFFCBD5E1)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 8.0, unselectedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PatternLockPainter oldDelegate) {
    return oldDelegate.nodes.length != nodes.length ||
        oldDelegate.currentDragPos != currentDragPos ||
        (nodes.isNotEmpty && oldDelegate.nodes.isNotEmpty && oldDelegate.nodes.last != nodes.last);
  }
}
