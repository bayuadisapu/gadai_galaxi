import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import '../widgets/new_pawn_shared_widgets.dart';
import '../widgets/step_1_collateral_view.dart';
import '../widgets/step_2_finance_view.dart';
import '../widgets/step_3_biodata_view.dart';
import '../widgets/success_dialog.dart';
import 'package:galaxi_gadai/core/config/system_config.dart';

class NewPawnPage extends StatefulWidget {
  final String branchId;
  const NewPawnPage({super.key, required this.branchId});

  @override
  State<NewPawnPage> createState() => _NewPawnPageState();
}

class _NewPawnPageState extends State<NewPawnPage> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  int _currentStep = 1; // 1: Jaminan, 2: Keuangan, 3: Data Diri
  bool _isLoading = false;

  // --- Step 1 State ---
  String _selectedCollateral = 'Barang'; // 'Barang', 'Emas', 'Motor / Mobil'
  
  // Barang form specific state
  String _selectedBarangType = 'Handphone';
  String? _selectedBrand;
  String _deviceLock = 'PIN/Sandi';
  bool _hasCharger = false;
  bool _hasTas = false;
  bool _hasDus = false;
  String? _selectedCondition;
  final TextEditingController _modelController = TextEditingController(); // Tipe / Model
  final TextEditingController _noteController = TextEditingController(); // Keterangan

  // Emas form specific state
  String? _selectedGoldType;
  String? _selectedKarat;
  String? _selectedCertificate;
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _netWeightController = TextEditingController();
  String _emasSistemTebus = 'Langsung Tebas';

  // Vehicle form specific state
  final TextEditingController _vehicleBrandTypeController = TextEditingController();
  final TextEditingController _vehicleHargaBaruController = TextEditingController();
  final TextEditingController _vehicleYearController = TextEditingController();
  final TextEditingController _vehicleNoMesinController = TextEditingController();
  final TextEditingController _vehicleNoRangkaController = TextEditingController();
  final TextEditingController _vehicleNoPolisiController = TextEditingController();
  String _vehicleSistemTebus = 'Langsung Tebas';
  String? _selectedVehicleCondition;
  bool _hasStnk = false;
  bool _hasBpkb = false;
  bool _hasFaktur = false;
  bool _barangPhotoUploaded = false;

  // --- Step 2 State ---
  final TextEditingController _pawnAmountController = TextEditingController(text: '700.000');
  final TextEditingController _periodController = TextEditingController(text: '15');
  String _adminFeePaymentMethod = 'Potong Pinjaman';

  // --- Step 3 State ---
  Customer? _selectedNasabah; // nasabah yang dipilih dari daftar
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _birthPlaceController = TextEditingController();
  String? _selectedGender;
  String? _birthDay;
  String? _birthMonth;
  String? _birthYear;
  bool _ktpUploaded = false;
  bool _customerAndBarangPhotoUploaded = false;
  int? _customTaksiranOverride;

  @override
  void dispose() {
    _modelController.dispose();
    _noteController.dispose();
    _grossWeightController.dispose();
    _netWeightController.dispose();
    _vehicleBrandTypeController.dispose();
    _vehicleHargaBaruController.dispose();
    _vehicleYearController.dispose();
    _vehicleNoMesinController.dispose();
    _vehicleNoRangkaController.dispose();
    _vehicleNoPolisiController.dispose();
    _pawnAmountController.dispose();
    _periodController.dispose();
    _nikController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthPlaceController.dispose();
    super.dispose();
  }

  int get _pawnAmountValue {
    final cleanString = _pawnAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleanString) ?? 0;
  }

  int get _collateralTaksiranValue {
    if (_customTaksiranOverride != null) {
      return _customTaksiranOverride!;
    }
    if (_selectedCollateral == 'Barang') {
      double basePrice = 3000000;
      if (_selectedBrand == 'Apple') basePrice = 12000000;
      else if (_selectedBrand == 'Samsung') basePrice = 8000000;
      else if (_selectedBrand == 'Xiaomi') basePrice = 4000000;
      else if (_selectedBrand == 'Oppo') basePrice = 3500000;
      
      double multiplier = 0.5;
      if (_selectedCondition == 'Mulus (95%+)') multiplier = 0.85;
      else if (_selectedCondition == 'Lecet Pemakaian') multiplier = 0.65;
      else if (_selectedCondition == 'Minus Fungsi Sederhana') multiplier = 0.45;
      
      return (basePrice * multiplier).toInt();
    } else if (_selectedCollateral == 'Emas') {
      final gross = double.tryParse(_grossWeightController.text) ?? 0;
      final Map<String, double> karatPcts = {
        '6K': 0.250, '10K': 0.417, '14K': 0.585, '16K': 0.666,
        '18K': 0.750, '20K': 0.833, '22K': 0.916, '24K': 0.999
      };
      final selectedKaratPct = karatPcts[_selectedKarat] ?? 0.0;
      return (gross * 1150000 * selectedKaratPct).toInt();
    } else {
      // Vehicle
      final yearStr = _vehicleYearController.text;
      final year = int.tryParse(yearStr) ?? DateTime.now().year;
      final hargaBaru = double.tryParse(_vehicleHargaBaruController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
      final ageYears = (DateTime.now().year - year).clamp(0, 26);
      const depresiasi = 0.10;
      final faktor = (1 - depresiasi * ageYears).clamp(0.3, 1.0);
      return (hargaBaru * faktor * 0.7).toInt();
    }
  }

  void _onCollateralSelected(String type) {
    setState(() {
      _selectedCollateral = type;
      _selectedBrand = null;
      _selectedCondition = null;
      _selectedGoldType = null;
      _selectedKarat = null;
      _selectedCertificate = null;
      
      _grossWeightController.clear();
      _netWeightController.clear();
      _vehicleBrandTypeController.clear();
      _vehicleHargaBaruController.clear();
      _vehicleYearController.clear();
      _vehicleNoMesinController.clear();
      _vehicleNoRangkaController.clear();
      _vehicleNoPolisiController.clear();
      _modelController.clear();
      _noteController.clear();
      
      _deviceLock = 'PIN/Sandi';
      _hasCharger = false;
      _hasTas = false;
      _hasDus = false;
      _hasStnk = false;
      _hasBpkb = false;
      _hasFaktur = false;
      _emasSistemTebus = 'Langsung Tebas';
      _vehicleSistemTebus = 'Langsung Tebas';
      _selectedVehicleCondition = null;
    });
  }

  // ── PILIH NASABAH TERDAFTAR ──
  void _pickNasabahTerdaftar() async {
    final svc = SupabaseGadaiService.instance;
    // Ambil semua nasabah di cabang ini
    final list = await svc.fetchNasabah(branchId: widget.branchId);
    if (!mounted) return;

    final Customer? picked = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NasabahPickerSheet(nasabahList: list),
    );

    if (picked == null) return;

    // Auto-fill semua field dari nasabah terpilih
    setState(() {
      _selectedNasabah = picked;
      _nikController.text = picked.nik;
      _fullNameController.text = picked.name;
      _phoneController.text = picked.phone;
      _addressController.text = picked.address;
      _birthPlaceController.text = picked.birthPlace;
      _selectedGender = picked.gender;

      // Parse birthDate: contoh "12 Maret 1995"
      final parts = picked.birthDate.split(' ');
      if (parts.length >= 3) {
        _birthDay = parts[0];
        _birthMonth = parts[1];
        _birthYear = parts[2];
      }
    });
  }

  void _handleBackNavigation() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleNextStep() async {
    if (_currentStep == 1) {
      if (_step1FormKey.currentState!.validate()) {
        if (!_barangPhotoUploaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silakan unggah foto barang jaminan terlebih dahulu'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Prefill pawn amount dynamically to maximum estimate for high-fidelity flow
        final taksiranVal = _collateralTaksiranValue;
        // format and display in pawn amount controller
        final s = taksiranVal.toString();
        final buffer = StringBuffer();
        for (int i = 0; i < s.length; i++) {
          if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
          buffer.write(s[i]);
        }
        _pawnAmountController.text = buffer.toString();
        
        setState(() {
          _currentStep = 2;
        });
      }
    } else if (_currentStep == 2) {
      if (_step2FormKey.currentState!.validate()) {
        setState(() {
          _currentStep = 3;
        });
      }
    } else if (_currentStep == 3) {
      if (_step3FormKey.currentState!.validate()) {
        if (!_ktpUploaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silakan unggah foto KTP nasabah terlebih dahulu'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        if (!_customerAndBarangPhotoUploaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silakan unggah foto nasabah & barang jaminan terlebih dahulu'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final dobDay = _birthDay ?? '01';
        final dobMonth = _birthMonth ?? 'Januari';
        final dobYear = _birthYear ?? '1990';
        final birthDateStr = '$dobDay $dobMonth $dobYear';

        final newCust = Customer(
          id: '',
          name: _fullNameController.text.trim(),
          nik: _nikController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          birthPlace: _birthPlaceController.text.trim().isNotEmpty ? _birthPlaceController.text.trim() : '-',
          birthDate: birthDateStr,
          gender: _selectedGender ?? 'Laki-laki',
          cabangId: widget.branchId,
        );
        
        final periodDays = int.tryParse(_periodController.text) ?? 15;
        final pawnAmt = _pawnAmountValue;
        final int dailyFee = SystemConfig.calculateDailyFee(pawnAmt);
        final int totalFee = dailyFee * periodDays;
        final int totalRepayment = pawnAmt + totalFee;
        
        String txBrand = '';
        String txModel = '';
        String txCondition = '';
        
        if (_selectedCollateral == 'Barang') {
          txBrand = _selectedBrand ?? 'Lainnya';
          txModel = _modelController.text.isNotEmpty ? _modelController.text : 'Gadai Barang';
          txCondition = _selectedCondition ?? 'Normal';
        } else if (_selectedCollateral == 'Emas') {
          txBrand = _selectedGoldType ?? 'Emas';
          txModel = '${_selectedKarat ?? "24K"} (Gross: ${_grossWeightController.text}g)';
          txCondition = _selectedCertificate ?? 'Tanpa Sertifikat';
        } else {
          // Vehicle
          txBrand = _vehicleBrandTypeController.text.isNotEmpty ? _vehicleBrandTypeController.text : 'Motor/Mobil';
          txModel = '${_vehicleNoPolisiController.text} (Tahun: ${_vehicleYearController.text})';
          txCondition = _selectedVehicleCondition ?? 'Prima';
        }

        final svc = SupabaseGadaiService.instance;
        setState(() => _isLoading = true);

        try {
          final Customer createdCust;
          if (_selectedNasabah != null) {
            // Nasabah dipilih dari picker — pakai ID langsung (sudah pasti benar)
            createdCust = _selectedNasabah!;
          } else {
            // Input manual — cek apakah nomor HP sudah terdaftar
            Customer? existingCust = await svc.fetchNasabahByPhone(newCust.phone);
            if (existingCust != null) {
              createdCust = existingCust;
            } else {
              // Nasabah benar-benar baru — buat ke DB
              createdCust = await svc.createNasabah(newCust);
            }
          }

          final newTx = PawnTransaction(
            id: '',
            customerId: createdCust.id,
            cabangId: widget.branchId,
            collateralType: _selectedCollateral,
            brand: txBrand,
            model: txModel,
            condition: txCondition,
            principal: pawnAmt,
            periodDays: periodDays,
            dailyFee: dailyFee,
            totalFee: totalFee,
            totalRepayment: totalRepayment,
            dateApplied: DateTime.now(),
            dateDue: DateTime.now().add(Duration(days: periodDays)),
            status: 'Aktif',
          );

          final createdTx = await svc.createTransaction(newTx);

          // Record admin fee to Tenant Wallet (Supabase — fire-and-forget)
          unawaited(svc.walletTopUp(widget.branchId, 10000, 'Admin Fee Gadai - $txModel ($_adminFeePaymentMethod)'));

          // Log transaksi baru
          unawaited(svc.logTransaksiCreated(createdCust.id, createdTx.id, '$txBrand $txModel', pawnAmt));

          if (!mounted) return;
          setState(() => _isLoading = false);

          showSuccessDialog(
            context: context,
            selectedCollateral: _selectedCollateral,
            modelName: txModel,
          );
        } catch (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan transaksi: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return Step1CollateralView(
          formKey: _step1FormKey,
          selectedCollateral: _selectedCollateral,
          onCollateralSelected: _onCollateralSelected,
          barangPhotoUploaded: _barangPhotoUploaded,
          onBarangPhotoUploadedChanged: (val) => setState(() => _barangPhotoUploaded = val),
          
          selectedBarangType: _selectedBarangType,
          onBarangTypeChanged: (val) => setState(() => _selectedBarangType = val ?? 'Handphone'),
          selectedBrand: _selectedBrand,
          onBrandChanged: (val) => setState(() => _selectedBrand = val),
          modelController: _modelController,
          selectedCondition: _selectedCondition,
          onConditionChanged: (val) => setState(() => _selectedCondition = val),
          noteController: _noteController,
          customTaksiranOverride: _customTaksiranOverride,
          onTaksiranOverrideChanged: (val) => setState(() => _customTaksiranOverride = val),
          deviceLock: _deviceLock,
          onDeviceLockChanged: (val) => setState(() => _deviceLock = val),
          hasCharger: _hasCharger,
          onHasChargerChanged: (val) => setState(() => _hasCharger = val),
          hasTas: _hasTas,
          onHasTasChanged: (val) => setState(() => _hasTas = val),
          hasDus: _hasDus,
          onHasDusChanged: (val) => setState(() => _hasDus = val),

          selectedGoldType: _selectedGoldType,
          onGoldTypeChanged: (val) => setState(() => _selectedGoldType = val),
          selectedKarat: _selectedKarat,
          onKaratChanged: (val) => setState(() => _selectedKarat = val),
          grossWeightController: _grossWeightController,
          netWeightController: _netWeightController,
          selectedCertificate: _selectedCertificate,
          onCertificateChanged: (val) => setState(() => _selectedCertificate = val),
          emasSistemTebus: _emasSistemTebus,
          onEmasSistemTebusChanged: (val) => setState(() => _emasSistemTebus = val ?? 'Langsung Tebas'),

          vehicleBrandTypeController: _vehicleBrandTypeController,
          vehicleHargaBaruController: _vehicleHargaBaruController,
          vehicleYearController: _vehicleYearController,
          vehicleNoMesinController: _vehicleNoMesinController,
          vehicleNoRangkaController: _vehicleNoRangkaController,
          vehicleNoPolisiController: _vehicleNoPolisiController,
          vehicleSistemTebus: _vehicleSistemTebus,
          onVehicleSistemTebusChanged: (val) => setState(() => _vehicleSistemTebus = val ?? 'Langsung Tebas'),
          selectedVehicleCondition: _selectedVehicleCondition,
          onVehicleConditionChanged: (val) => setState(() => _selectedVehicleCondition = val),
          hasStnk: _hasStnk,
          onHasStnkChanged: (val) => setState(() => _hasStnk = val),
          hasBpkb: _hasBpkb,
          onHasBpkbChanged: (val) => setState(() => _hasBpkb = val),
          hasFaktur: _hasFaktur,
          onHasFakturChanged: (val) => setState(() => _hasFaktur = val),
        );
      case 2:
        return Step2FinanceView(
          formKey: _step2FormKey,
          pawnAmountController: _pawnAmountController,
          periodController: _periodController,
          adminFeePaymentMethod: _adminFeePaymentMethod,
          onAdminFeePaymentMethodChanged: (val) => setState(() => _adminFeePaymentMethod = val!),
          onAmountChanged: () => setState(() {}),
          maxTaksiran: _collateralTaksiranValue,
        );
      case 3:
        return Step3BiodataView(
          formKey: _step3FormKey,
          nikController: _nikController,
          fullNameController: _fullNameController,
          phoneController: _phoneController,
          addressController: _addressController,
          birthPlaceController: _birthPlaceController,
          selectedGender: _selectedGender,
          onGenderChanged: (val) => setState(() => _selectedGender = val),
          birthDay: _birthDay,
          onBirthDayChanged: (val) => setState(() => _birthDay = val),
          birthMonth: _birthMonth,
          onBirthMonthChanged: (val) => setState(() => _birthMonth = val),
          birthYear: _birthYear,
          onBirthYearChanged: (val) => setState(() => _birthYear = val),
          ktpUploaded: _ktpUploaded,
          onKtpUploadedChanged: (val) => setState(() => _ktpUploaded = val),
          customerAndBarangPhotoUploaded: _customerAndBarangPhotoUploaded,
          onCustomerAndBarangPhotoUploadedChanged: (val) => setState(() => _customerAndBarangPhotoUploaded = val),
          selectedNasabah: _selectedNasabah,
          onPickNasabah: _pickNasabahTerdaftar,
        );
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF93C5FD),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0A1628)),
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          'Pengajuan Gadai Baru',
          style: GoogleFonts.poppins(
            color: const Color(0xFF0A1628),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 1. Stepper Header Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: NewPawnStepperIndicator(currentStep: _currentStep),
          ),
          
          // 2. Scrollable Content Body based on step
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildStepContent(),
            ),
          ),
          
          // 3. Footer Action Button
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == 1
                                ? 'Lanjut ke Keuangan'
                                : (_currentStep == 2 ? 'Lanjut ke Data Diri' : 'Simpan & Proses'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// NASABAH PICKER BOTTOM SHEET
// ═══════════════════════════════════════════════════════

class _NasabahPickerSheet extends StatefulWidget {
  final List<Customer> nasabahList;
  const _NasabahPickerSheet({required this.nasabahList});

  @override
  State<_NasabahPickerSheet> createState() => _NasabahPickerSheetState();
}

class _NasabahPickerSheetState extends State<_NasabahPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Customer> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.nasabahList;
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = widget.nasabahList.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.phone.contains(q) ||
        c.nik.contains(q)
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text('Pilih Nasabah Terdaftar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ]),
          ),
          const SizedBox(height: 14),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari nama, nomor HP, atau NIK...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Divider
          const Divider(height: 1),

          // List nasabah
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        widget.nasabahList.isEmpty ? 'Belum ada nasabah terdaftar' : 'Nasabah tidak ditemukan',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ]),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (ctx, i) {
                      final c = _filtered[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14)),
                        subtitle: Text('${c.phone}  •  NIK: ${c.nik.isNotEmpty ? c.nik : '-'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        onTap: () => Navigator.pop(ctx, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
