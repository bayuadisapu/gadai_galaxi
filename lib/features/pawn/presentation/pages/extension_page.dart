import 'dart:async';
import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/services/gadai_thermal_print_service.dart';
import 'package:galaxi_gadai/core/widgets/gadai_print_settings_page.dart';

class ExtensionPage extends StatefulWidget {
  final String? prefilledTxId;

  const ExtensionPage({super.key, this.prefilledTxId});

  @override
  State<ExtensionPage> createState() => _ExtensionPageState();
}

class _ExtensionPageState extends State<ExtensionPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedTxId;
  int _extensionDays = 15;
  final _customDaysController = TextEditingController(text: '15');
  bool _isPaymentConfirmed = false;
  final _svc = SupabaseGadaiService.instance;
  List<PawnTransaction> _allTxs = [];
  List<Customer> _allCustomers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _customDaysController.addListener(() {
      final val = int.tryParse(_customDaysController.text);
      if (val != null && val > 0 && val != _extensionDays) {
        setState(() => _extensionDays = val);
      }
    });
  }

  @override
  void dispose() {
    _customDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final txs = await _svc.fetchTransactions();
      final customers = await _svc.fetchNasabah();
      if (!mounted) return;
      setState(() { _allTxs = txs; _allCustomers = customers; _isLoading = false; });
      final activeTxs = _getActiveTransactions();
      if (widget.prefilledTxId != null) {
        // Pastikan prefilledTxId ada di dalam daftar aktif
        final exists = activeTxs.any((tx) => tx.id == widget.prefilledTxId);
        if (exists) {
          setState(() => _selectedTxId = widget.prefilledTxId);
        } else if (activeTxs.isNotEmpty) {
          // Fallback ke item pertama jika tidak ditemukan di daftar
          setState(() => _selectedTxId = activeTxs.first.id);
        }
      } else {
        if (activeTxs.isNotEmpty) setState(() => _selectedTxId = activeTxs.first.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<PawnTransaction> _getActiveTransactions() {
    // Hanya tampilkan transaksi yang masih bisa diperpanjang
    return _allTxs.where((tx) =>
        tx.status == 'Aktif' ||
        tx.status == 'Macet' ||
        tx.status == 'Perlu_Bayar_Jatip'
    ).toList();
  }

  PawnTransaction? _getSelectedTransaction() {
    if (_selectedTxId == null) return null;
    try { return _allTxs.firstWhere((tx) => tx.id == _selectedTxId); } catch (_) { return null; }
  }

  Customer? _getCustomerForTx(PawnTransaction? tx) {
    if (tx == null) return null;
    try { return _allCustomers.firstWhere((c) => c.id == tx.customerId); } catch (_) { return null; }
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

  String _formatIndonesianDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  void _processExtension(PawnTransaction tx) async {
    final days = _extensionDays;
    final oldDueDate = tx.dateDue;
    // Bug Fix: jatipDibayar = dailyFee * days (biaya tenor baru)
    // bukan tx.totalFee yang merupakan akumulasi fee sebelumnya
    final newTotalFee = tx.dailyFee * days;
    final jatipDibayar = newTotalFee;
    // Jika macet, hitung dari hari ini (bukan dari dateDue yang sudah lewat)
    final baseDate = tx.dateDue.isBefore(DateTime.now()) ? DateTime.now() : tx.dateDue;
    final newDueDate = baseDate.add(Duration(days: days));
    final newTotalRepayment = tx.principal + newTotalFee;

    try {
      await _svc.createExtension(
        ExtensionHistory(id: '', transactionId: tx.id, jatipDibayar: jatipDibayar, tglPerpanjangan: DateTime.now(), tglTempoLama: oldDueDate, tglTempoBaru: newDueDate),
      );
      await _svc.updateTransactionStatus(tx.id, 'Aktif', newDueDate: newDueDate, periodDays: days, totalFee: newTotalFee, totalRepayment: newTotalRepayment);

      setState(() {
        tx.dateDue = newDueDate;
        tx.status = 'Aktif';
        // dateApplied TIDAK diubah — tetap tanggal gadai pertama kali
        tx.periodDays = days;
        tx.totalFee = newTotalFee;
        tx.totalRepayment = newTotalRepayment;
      });

      // Log perpanjangan tenor
      unawaited(_svc.logExtensionRequested(tx.customerId, tx.id));

      // Perpanjangan cash — tambah saldo kas/rekening cabang
      unawaited(_svc.walletTopUp(tx.cabangId, jatipDibayar, 'Jatip Perpanjangan - ${tx.brand} ${tx.model} (${tx.displayCode}) Cash'));

      if (!mounted) return;
      _showSuccessDialog(tx, days);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  void _showSuccessDialog(PawnTransaction tx, int days) {
    // Buat ExtensionHistory sementara untuk struk (sudah disimpan ke DB)
    final extForPrint = ExtensionHistory(
      id: '',
      transactionId: tx.id,
      jatipDibayar: tx.dailyFee * days,
      tglPerpanjangan: DateTime.now(),
      tglTempoLama: tx.dateDue.subtract(Duration(days: days)),
      tglTempoBaru: tx.dateDue,
    );
    final txCustomer = _getCustomerForTx(tx);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isPrinting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Perpanjangan Sukses!',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tenor transaksi ${tx.displayCode} berhasil diperpanjang +$days hari.\nJatuh tempo baru: ${_formatIndonesianDate(tx.dateDue)}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tombol cetak struk perpanjangan
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: isPrinting
                            ? null
                            : () async {
                                final printSvc = GadaiThermalPrintService.instance;
                                final isConnected = await printSvc.ensureConnected();
                                if (!isConnected) {
                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  Navigator.pop(context);
                                  if (mounted) {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const GadaiPrintSettingsPage()),
                                    );
                                  }
                                  return;
                                }
                                setDialogState(() => isPrinting = true);
                                final customer = txCustomer ??
                                    Customer(
                                        id: '', name: tx.brand, nik: '-',
                                        birthPlace: '', birthDate: '',
                                        gender: '', phone: '-', address: '');
                                final ok = await printSvc.printPerpanjangan(
                                    tx, customer, extForPrint);
                                setDialogState(() => isPrinting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                      ok
                                          ? '🖨️ Struk perpanjangan dicetak!'
                                          : '❌ Gagal cetak struk.',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: ok
                                        ? AppColors.primary
                                        : const Color(0xFFEF4444),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ));
                                }
                              },
                        icon: isPrinting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.print_rounded,
                                size: 18, color: AppColors.primary),
                        label: Text(
                          isPrinting ? 'Mencetak...' : 'Cetak Struk Perpanjangan',
                          style: const TextStyle(
                              color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close Dialog
                          Navigator.pop(context); // Back to previous page
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Selesai',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTxs = _getActiveTransactions();
    final currentTx = _getSelectedTransaction();
    final customer = _getCustomerForTx(currentTx);

    // Business calculations
    int dueFee = 0;
    DateTime newDueDate = DateTime.now();
    if (currentTx != null) {
      final days = _extensionDays;
      // Konsisten dengan _processExtension: jatip yg dibayar = dailyFee × hari tenor baru
      dueFee = currentTx.dailyFee * days;
      // Jika macet (dateDue sudah lewat), hitung dari hari ini — konsisten dengan _processExtension
      final baseDate = currentTx.dateDue.isBefore(DateTime.now()) ? DateTime.now() : currentTx.dateDue;
      newDueDate = baseDate.add(Duration(days: days));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Proses Perpanjangan Tenor',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeTxs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 64, color: Color(0xFF94A3B8)),
                  SizedBox(height: 16),
                  Text(
                    'Tidak ada transaksi aktif yang perlu diperpanjang.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction selector dropdown (if not prefilled)
                    const Text(
                      'Pilih Transaksi Gadai',
                      style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: activeTxs.any((tx) => tx.id == _selectedTxId) ? _selectedTxId : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      items: activeTxs.map((tx) {
                        return DropdownMenuItem(
                          value: tx.id,
                          child: Text('${tx.displayCode} - ${tx.brand} ${tx.model}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTxId = val;
                          _isPaymentConfirmed = false;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    if (currentTx != null && customer != null) ...[
                      // Customer & Collateral Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF), // soft blue
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  customer.name,
                                  style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: currentTx.status == 'Macet' ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    currentTx.status,
                                    style: TextStyle(
                                      color: currentTx.status == 'Macet' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Jenis Jaminan', currentTx.collateralType),
                            _buildInfoRow('Merk / Model', '${currentTx.brand} ${currentTx.model}'),
                            _buildInfoRow('Nominal Pinjaman', 'Rp ${_formatCurrency(currentTx.principal)}'),
                            _buildInfoRow('Jatuh Tempo Saat Ini', _formatIndonesianDate(currentTx.dateDue)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Business Rollover Calculations Box
                      const Text(
                        'Kalkulasi Perpanjangan Tenor',
                        style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Required payment label
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Jasa Titip Tenor Baru',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                                Text(
                                  'Rp ${_formatCurrency(dueFee)}',
                                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '* Biaya Jasa Titip untuk tenor perpanjangan yang dipilih. Wajib dilunasi saat proses perpanjangan.',
                              style: TextStyle(color: const Color(0xFFEF4444).withValues(alpha: 0.8), fontSize: 11),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(color: Color(0xFFE2E8F0)),
                            ),

                            // Input: Tenor perpanjangan bebas
                            const Text(
                              'Tenor Perpanjangan (Hari)',
                              style: TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            // Pilihan cepat
                            Row(
                              children: [7, 15, 30].map((d) {
                                final isSelected = _extensionDays == d &&
                                    _customDaysController.text == d.toString();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _extensionDays = d);
                                      _customDaysController.text = d.toString();
                                      _customDaysController.selection = TextSelection.collapsed(
                                        offset: _customDaysController.text.length,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        '$d Hari',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.white : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            // Input angka bebas
                            TextFormField(
                              controller: _customDaysController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                ),
                                suffixText: 'hari',
                                suffixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                hintText: 'Masukkan jumlah hari',
                                hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                              ),
                              validator: (val) {
                                final n = int.tryParse(val ?? '');
                                if (n == null || n <= 0) return 'Masukkan jumlah hari yang valid';
                                return null;
                              },
                              onChanged: (val) {
                                final n = int.tryParse(val);
                                if (n != null && n > 0) setState(() => _extensionDays = n);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Display new due date
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tanggal Jatuh Tempo Baru', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                Text(
                                  _formatIndonesianDate(newDueDate),
                                  style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Confirmation payment checkbox
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isPaymentConfirmed ? const Color(0xFFECFDF5) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isPaymentConfirmed ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _isPaymentConfirmed,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                setState(() {
                                  _isPaymentConfirmed = val ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                'Saya mengonfirmasi bahwa nasabah telah membayar Jasa Titip sebesar Rp ${_formatCurrency(dueFee)} secara tunai/transfer.',
                                style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isPaymentConfirmed
                              ? () {
                                  if (_formKey.currentState!.validate()) {
                                    _processExtension(currentTx);
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Proses & Perbarui Jatuh Tempo',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
