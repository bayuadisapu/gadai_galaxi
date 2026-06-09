import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import '../widgets/new_pawn_shared_widgets.dart';
import '../widgets/step_1_collateral_view.dart';
import '../widgets/step_2_finance_view.dart';
import '../widgets/step_3_biodata_view.dart';
import '../widgets/success_dialog.dart';

class NewPawnPage extends StatefulWidget {
  const NewPawnPage({super.key});

  @override
  State<NewPawnPage> createState() => _NewPawnPageState();
}

class _NewPawnPageState extends State<NewPawnPage> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  int _currentStep = 1; // 1: Jaminan, 2: Keuangan, 3: Data Diri

  // --- Step 1 State ---
  String _selectedCollateral = 'Handphone';
  
  // Handphone / Laptop common state
  String? _selectedBrand;
  String? _selectedCondition;
  String _deviceLock = 'PIN/Sandi';
  bool _hasCharger = false;
  bool _hasTas = false;
  bool _hasDus = false;
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // Laptop specific state
  String? _selectedProcessor;
  String? _selectedRam;
  String? _selectedStorage;

  // Emas specific state
  String? _selectedGoldType;
  String? _selectedKarat;
  String? _selectedCertificate;
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _netWeightController = TextEditingController();

  // Vehicle specific state
  String? _selectedVehicleType;
  final TextEditingController _vehicleYearController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();
  bool _hasStnk = false;
  bool _hasBpkb = false;
  bool _hasFaktur = false;

  // --- Step 2 State ---
  final TextEditingController _pawnAmountController = TextEditingController(text: '700.000');
  String _selectedPeriod = '15 Hari';

  // --- Step 3 State ---
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

  @override
  void dispose() {
    _modelController.dispose();
    _noteController.dispose();
    _pawnAmountController.dispose();
    _nikController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthPlaceController.dispose();
    _grossWeightController.dispose();
    _netWeightController.dispose();
    _vehicleYearController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  int get _pawnAmountValue {
    final cleanString = _pawnAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleanString) ?? 0;
  }

  void _onCollateralSelected(String type) {
    setState(() {
      _selectedCollateral = type;
      _selectedBrand = null;
      _selectedCondition = null;
      _selectedProcessor = null;
      _selectedRam = null;
      _selectedStorage = null;
      _selectedGoldType = null;
      _selectedKarat = null;
      _selectedCertificate = null;
      _selectedVehicleType = null;
      
      _grossWeightController.clear();
      _netWeightController.clear();
      _vehicleYearController.clear();
      _plateNumberController.clear();
      _modelController.clear();
      _noteController.clear();
      
      _deviceLock = 'PIN/Sandi';
      _hasCharger = false;
      _hasTas = false;
      _hasDus = false;
      _hasStnk = false;
      _hasBpkb = false;
      _hasFaktur = false;
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

  void _handleNextStep() {
    if (_currentStep == 1) {
      if (_step1FormKey.currentState!.validate()) {
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

        // Save to mock database
        final newCustId = 'N${mockCustomers.length + 101}';
        final newTxId = 'TX${mockTransactions.length + 101}';
        
        final dobDay = _birthDay ?? '01';
        final dobMonth = _birthMonth ?? 'Januari';
        final dobYear = _birthYear ?? '1990';
        final birthDateStr = '$dobDay $dobMonth $dobYear';

        final newCust = Customer(
          id: newCustId,
          name: _fullNameController.text.trim(),
          nik: _nikController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          birthPlace: _birthPlaceController.text.trim().isNotEmpty ? _birthPlaceController.text.trim() : 'Surabaya',
          birthDate: birthDateStr,
          gender: _selectedGender ?? 'Laki-laki',
        );
        
        final periodDays = _selectedPeriod == '15 Hari' ? 15 : (_selectedPeriod == '30 Hari' ? 30 : 60);
        final pawnAmt = _pawnAmountValue;
        final int dailyFee = ((pawnAmt * 0.01428) / 100).round() * 100;
        final int totalFee = dailyFee * periodDays;
        final int totalRepayment = pawnAmt + totalFee;
        
        String itemModel = _modelController.text.isNotEmpty ? _modelController.text : 'Gadai $_selectedCollateral';
        
        final newTx = PawnTransaction(
          id: newTxId,
          customerId: newCustId,
          collateralType: _selectedCollateral,
          brand: _selectedBrand ?? 'Lainnya',
          model: itemModel,
          condition: _selectedCondition ?? 'Normal',
          principal: pawnAmt,
          periodDays: periodDays,
          dailyFee: dailyFee,
          totalFee: totalFee,
          totalRepayment: totalRepayment,
          dateApplied: DateTime.now(),
          dateDue: DateTime.now().add(Duration(days: periodDays)),
          status: 'Aktif',
        );
        
        mockCustomers.add(newCust);
        mockTransactions.add(newTx);

        showSuccessDialog(
          context: context,
          selectedCollateral: _selectedCollateral,
          modelName: _modelController.text,
        );
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
          modelController: _modelController,
          noteController: _noteController,
          grossWeightController: _grossWeightController,
          netWeightController: _netWeightController,
          vehicleYearController: _vehicleYearController,
          plateNumberController: _plateNumberController,
          selectedBrand: _selectedBrand,
          onBrandChanged: (val) => setState(() => _selectedBrand = val),
          selectedCondition: _selectedCondition,
          onConditionChanged: (val) => setState(() => _selectedCondition = val),
          deviceLock: _deviceLock,
          onDeviceLockChanged: (val) => setState(() => _deviceLock = val),
          hasCharger: _hasCharger,
          onHasChargerChanged: (val) => setState(() => _hasCharger = val),
          hasDus: _hasDus,
          onHasDusChanged: (val) => setState(() => _hasDus = val),
          selectedProcessor: _selectedProcessor,
          onProcessorChanged: (val) => setState(() => _selectedProcessor = val),
          selectedRam: _selectedRam,
          onRamChanged: (val) => setState(() => _selectedRam = val),
          selectedStorage: _selectedStorage,
          onStorageChanged: (val) => setState(() => _selectedStorage = val),
          hasTas: _hasTas,
          onHasTasChanged: (val) => setState(() => _hasTas = val),
          selectedGoldType: _selectedGoldType,
          onGoldTypeChanged: (val) => setState(() => _selectedGoldType = val),
          selectedKarat: _selectedKarat,
          onKaratChanged: (val) => setState(() => _selectedKarat = val),
          selectedCertificate: _selectedCertificate,
          onCertificateChanged: (val) => setState(() => _selectedCertificate = val),
          selectedVehicleType: _selectedVehicleType,
          onVehicleTypeChanged: (val) => setState(() => _selectedVehicleType = val),
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
          selectedPeriod: _selectedPeriod,
          onPeriodChanged: (val) => setState(() => _selectedPeriod = val!),
          onAmountChanged: () => setState(() {}),
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
        );
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: _handleBackNavigation,
        ),
        title: const Text(
          'Pengajuan Gadai Baru',
          style: TextStyle(
            color: AppColors.primary,
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
                onPressed: _handleNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
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
