import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/extension_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/redemption_page.dart';
import 'package:galaxi_gadai/core/config/system_config.dart';
import 'package:galaxi_gadai/core/services/gadai_thermal_print_service.dart';
import 'package:galaxi_gadai/core/services/perjanjian_pdf_service.dart';
import 'package:galaxi_gadai/core/widgets/gadai_print_settings_page.dart';
import 'package:share_plus/share_plus.dart';

class TransaksiDetailPage extends StatefulWidget {
  final PawnTransaction transaction;
  const TransaksiDetailPage({super.key, required this.transaction});

  @override
  State<TransaksiDetailPage> createState() => _TransaksiDetailPageState();
}

class _TransaksiDetailPageState extends State<TransaksiDetailPage> {
  Customer? _customer;
  List<ExtensionHistory> _extensions = [];
  LelangHistory? _lelangHistory;
  late PawnTransaction _tx;

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
    _loadRelatedData();
  }

  Future<void> _loadRelatedData() async {
    final svc = SupabaseGadaiService.instance;
    try {
      final customer = await svc.fetchNasabahById(widget.transaction.customerId);
      final extensions = await svc.fetchExtensionHistory(widget.transaction.id);
      final lelangList = await svc.fetchLelangHistory();
      LelangHistory? myLelang;
      for (final h in lelangList) {
        if (h.transactionId == widget.transaction.id) {
          myLelang = h;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _customer = customer ?? Customer(id: '', name: 'Tidak Dikenal', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: '');
        _extensions = extensions;
        _lelangHistory = myLelang;
      });
    } catch (_) {}
  }

  String _formatCurrency(int val) {
    final s = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    final months = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    final months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  // ── THERMAL PRINT & PDF SHARE ──
  Future<void> _showPrintOptions() async {
    if (!mounted) return;
    // Langsung tampilkan pilihan — tidak perlu cek printer dulu
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.print_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Cetak / Bagikan Struk',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                ],
              ),
              const SizedBox(height: 16),
              // Opsi 1: Share PDF
              _PrintOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFEF4444),
                title: 'Bagikan PDF',
                subtitle: 'Generate PDF lalu share ke WhatsApp / email',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _doSharePdf();
                },
              ),
              const SizedBox(height: 8),
              // Opsi 2: Cetak Bluetooth
              _PrintOptionTile(
                icon: Icons.assignment_rounded,
                color: AppColors.primary,
                title: 'Cetak ke Printer Bluetooth',
                subtitle: 'Struk thermal (hubungkan printer dulu)',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _doPrintBluetooth('perjanjian');
                },
              ),
              const SizedBox(height: 8),
              _PrintOptionTile(
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF8B5CF6),
                title: 'Cetak Salinan (Copy)',
                subtitle: 'Struk thermal dengan label SALINAN',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _doPrintBluetooth('salinan');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SHARE PDF ──
  Future<void> _doSharePdf() async {
    final customer = _customer ?? Customer(
      id: '', name: 'Nasabah', nik: '-', birthPlace: '', birthDate: '',
      gender: '', phone: '-', address: '');
    try {
      // Ambil nama petugas
      final staff = await SupabaseGadaiService.instance.getCurrentStaff();
      final petugasName = staff?['nama'] ?? 'Admin';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⏳ Membuat PDF...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));

      final pdfFile = await PerjanjianPdfService.instance.generatePerjanjianPdf(
        tx: _tx,
        customer: customer,
        petugasName: petugasName,
      );

      if (!mounted) return;
      final xFile = XFile(pdfFile.path, mimeType: 'application/pdf');
      await Share.shareXFiles(
        [xFile],
        text: 'Perjanjian Gadai - ${_tx.transactionCode.isNotEmpty ? _tx.transactionCode : _tx.id.substring(0, 10).toUpperCase()}',
        subject: 'Perjanjian Gadai - GALAXI GADAI',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Gagal buat PDF: $e'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── BLUETOOTH PRINT ──
  Future<void> _doPrintBluetooth(String type) async {
    final printSvc = GadaiThermalPrintService.instance;
    final isConnected = await printSvc.ensureConnected();
    if (!mounted) return;

    if (!isConnected) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.print_disabled_rounded, color: Color(0xFF94A3B8), size: 22),
              SizedBox(width: 8),
              Text('Printer Belum Terhubung',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Printer thermal belum terhubung. Buka pengaturan untuk menghubungkan printer Bluetooth terlebih dahulu.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GadaiPrintSettingsPage()),
        );
      }
      return;
    }

    final customer = _customer ?? Customer(
      id: '', name: 'Nasabah', nik: '-', birthPlace: '', birthDate: '',
      gender: '', phone: '-', address: '');
    bool ok = false;
    try {
      switch (type) {
        case 'perjanjian':
          ok = await printSvc.printPerjanjianGadai(_tx, customer);
          break;
        case 'salinan':
          ok = await printSvc.printPerjanjianGadai(_tx, customer, copyLabel: 'Salinan');
          break;
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        ok ? '🖨️ Struk berhasil dicetak!' : '❌ Gagal cetak. Cek koneksi printer.',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: ok ? AppColors.primary : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── CANCEL GADAI ──
  void _showCancelDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Batalkan Gadai',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
              child: const Text(
                '⚠️ Transaksi yang dibatalkan tidak dapat dikembalikan. '
                'Pastikan barang jaminan sudah dikembalikan kepada nasabah.',
                style: TextStyle(color: Color(0xFF991B1B), fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Alasan Pembatalan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Contoh: Nasabah mengundurkan diri...',
                hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              try {
                await SupabaseGadaiService.instance.updateTransactionStatus(widget.transaction.id, 'Dibatalkan');
                
                final staff = await SupabaseGadaiService.instance.getCurrentStaff();
                final staffId = staff?['nama'] ?? 'Admin';
                final staffRole = staff?['role'] ?? 'admin_cabang';
                await SupabaseGadaiService.instance.logTransaksiCancelled(
                  userId: staffId,
                  role: staffRole,
                  txId: widget.transaction.id,
                  reason: reason.isNotEmpty ? reason : 'Tidak ada alasan khusus',
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                setState(() => _tx.status = 'Dibatalkan');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaksi berhasil dibatalkan'),
                    backgroundColor: Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.pop(context);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal membatalkan: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  // ── EDIT DATA & NILAI GADAI ──
  void _showEditSheet() {
    final tx = _tx; // gunakan _tx yang sudah refreshed, bukan widget.transaction

    String fmtNum(int v) {
      final s = v.toString();
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
        buf.write(s[i]);
      }
      return buf.toString();
    }

    final nominalCtrl = TextEditingController(text: fmtNum(tx.principal));
    final kondisiCtrl = TextEditingController(text: tx.condition);
    final merkCtrl = TextEditingController(text: tx.brand);
    final modelCtrl = TextEditingController(text: tx.model);
    final periodCtrl = TextEditingController(text: tx.periodDays.toString());

    InputDecoration dec(String hint, {String? suffix, String? prefix}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 13),
      suffixText: suffix,
      prefixText: prefix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text('Ubah Data & Nilai Gadai',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Perubahan langsung tersimpan ke data transaksi',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 20),

              // Merk
              const Text('Merk Barang',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(controller: merkCtrl, decoration: dec('Merk barang jaminan'), style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 14),

              // Model
              const Text('Tipe / Model',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(controller: modelCtrl, decoration: dec('Tipe/model barang'), style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 14),

              // Kondisi
              const Text('Kondisi',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(controller: kondisiCtrl, decoration: dec('Kondisi barang'), style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 14),

              // Nominal
              const Text('Nominal Gadai (Rp)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: nominalCtrl,
                keyboardType: TextInputType.number,
                decoration: dec('Contoh: 1.000.000', prefix: 'Rp '),
                style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
                onChanged: (v) {
                  final cleanVal = v.replaceAll('.', '');
                  final val = int.tryParse(cleanVal) ?? 0;
                  final formatted = fmtNum(val);
                  nominalCtrl.value = TextEditingValue(
                      text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                },
              ),
              const SizedBox(height: 14),

              // Periode
              const Text('Periode Gadai',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: periodCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: dec('Jumlah hari', suffix: 'hari'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final cleanNominal = nominalCtrl.text.replaceAll('.', '');
                    final newPrincipal = int.tryParse(cleanNominal) ?? tx.principal;
                    final newDays = int.tryParse(periodCtrl.text) ?? tx.periodDays;

                    final int daily = SystemConfig.calculateDailyFee(newPrincipal);
                    final int newTotalFee = daily * newDays;
                    // Hitung newDue dari dateApplied + newDays agar jatuh tempo
                    // selalu dihitung dari tanggal gadai pertama kali
                    final newDue = tx.dateApplied.add(Duration(days: newDays));

                    final newBrand = merkCtrl.text.trim().isNotEmpty ? merkCtrl.text.trim() : tx.brand;
                    final newModel = modelCtrl.text.trim().isNotEmpty ? modelCtrl.text.trim() : tx.model;
                    final newCondition = kondisiCtrl.text.trim().isNotEmpty ? kondisiCtrl.text.trim() : tx.condition;

                    try {
                      // Hitung perubahan untuk log
                      final Map<String, dynamic> changes = {};
                      final List<String> descriptions = [];
                      if (newBrand != tx.brand) {
                        changes['brand'] = {'old': tx.brand, 'new': newBrand};
                        descriptions.add('Merk: ${tx.brand} ➔ $newBrand');
                      }
                      if (newModel != tx.model) {
                        changes['model'] = {'old': tx.model, 'new': newModel};
                        descriptions.add('Model: ${tx.model} ➔ $newModel');
                      }
                      if (newCondition != tx.condition) {
                        changes['condition'] = {'old': tx.condition, 'new': newCondition};
                        descriptions.add('Kondisi: ${tx.condition} ➔ $newCondition');
                      }
                      if (newPrincipal != tx.principal) {
                        changes['principal'] = {'old': tx.principal, 'new': newPrincipal};
                        descriptions.add('Nominal: Rp ${fmtNum(tx.principal)} ➔ Rp ${fmtNum(newPrincipal)}');
                      }
                      if (newDays != tx.periodDays) {
                        changes['periodDays'] = {'old': tx.periodDays, 'new': newDays};
                        descriptions.add('Tenor: ${tx.periodDays} Hari ➔ $newDays Hari');
                      }

                      await SupabaseGadaiService.instance.updateTransactionDetails(
                        tx.id,
                        brand: newBrand,
                        model: newModel,
                        condition: newCondition,
                        principal: newPrincipal,
                        periodDays: newDays,
                        dailyFee: daily,
                        totalFee: newTotalFee,
                        totalRepayment: newPrincipal + newTotalFee,
                        dateDue: newDue,
                      );

                      if (changes.isNotEmpty) {
                        final desc = 'Ubah data: ${descriptions.join(", ")}';
                        final staff = await SupabaseGadaiService.instance.getCurrentStaff();
                        final staffId = staff?['nama'] ?? 'Admin';
                        final staffRole = staff?['role'] ?? 'admin_cabang';
                        await SupabaseGadaiService.instance.logTransaksiUpdated(
                          userId: staffId,
                          role: staffRole,
                          txId: tx.id,
                          description: desc,
                          changes: changes,
                        );
                      }

                      // Reload data dari Supabase agar UI update
                      final refreshed = await SupabaseGadaiService.instance.fetchTransactionById(tx.id);
                      if (refreshed != null && mounted) setState(() => _tx = refreshed);

                      // Bug Fix: pop + snackbar hanya jika berhasil (masuk di dalam try)
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Data transaksi berhasil diperbarui'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal memperbarui: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                  label: const Text('Simpan Perubahan',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = _tx; // gunakan mutable local state agar update setelah edit
    final today = DateTime.now();
    final daysLeft = tx.dateDue.difference(today).inDays;
    final isOverdue = daysLeft < 0;
    final isActive = tx.status != 'Lunas' && tx.status != 'Dibatalkan';

    final customer = _customer ?? Customer(id: '', name: 'Tidak Dikenal', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: '');

    final int dailyFeeCalc = SystemConfig.calculateDailyFee(tx.principal);

    Color statusColor = AppColors.primary;
    Color statusBg = const Color(0xFFEFF6FF);
    if (tx.status == 'Macet') {
      statusColor = const Color(0xFFEF4444); statusBg = const Color(0xFFFEF2F2);
    } else if (tx.status == 'Lunas') {
      statusColor = const Color(0xFF10B981); statusBg = const Color(0xFFECFDF5);
    } else if (tx.status == 'Dibatalkan') {
      statusColor = const Color(0xFF6B7280); statusBg = const Color(0xFFF3F4F6);
    } else if (tx.status == 'Perlu_Bayar_Jatip') {
      statusColor = const Color(0xFFF59E0B); statusBg = const Color(0xFFFFF7ED);
    } else if (tx.status == 'Lelang' || tx.status == 'Terjual') {
      statusColor = const Color(0xFF8B5CF6); statusBg = const Color(0xFFF5F3FF);
    }

    final extensionHistory = _extensions;

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
        title: Text(tx.displayCode,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: AppColors.primary),
            tooltip: 'Cetak Struk',
            onPressed: _showPrintOptions,
          ),
          if (isActive)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
              tooltip: 'Ubah Data & Nilai Gadai',
              onPressed: _showEditSheet,
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Dibatalkan
            if (tx.status == 'Dibatalkan') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9CA3AF)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.block_rounded, color: Color(0xFF6B7280), size: 20),
                    SizedBox(width: 10),
                    Text('Transaksi ini sudah dibatalkan',
                        style: TextStyle(color: Color(0xFF4B5563), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],

            // Nasabah Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0] : 'N',
                        style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name,
                            style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(customer.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text('NIK: ${customer.nik}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                    child: Text(tx.status.replaceAll('_', ' '),
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Data Jaminan Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏷️ Data Jaminan',
                      style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row('Jenis Jaminan', tx.collateralType),
                  const SizedBox(height: 8),
                  _row('Merk', tx.brand),
                  const SizedBox(height: 8),
                  _row('Model', tx.model),
                  const SizedBox(height: 8),
                  _row('Kondisi', tx.condition),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Rincian Keuangan Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💰 Rincian Keuangan',
                      style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row('Nominal Pinjaman (N)', 'Rp ${_formatCurrency(tx.principal)}'),
                  const SizedBox(height: 8),
                  _row('Jasa Titip Harian', 'Rp ${_formatCurrency(dailyFeeCalc)} / hari'),
                  const SizedBox(height: 8),
                  _row('Periode Gadai', '${tx.periodDays} Hari'),
                  const SizedBox(height: 8),
                  _row('Total Jasa Titip (JT)', 'Rp ${_formatCurrency(tx.totalFee)}'),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Color(0xFFDBEAFE))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Tebusan',
                          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('Rp ${_formatCurrency(tx.principal + tx.totalFee)}',
                          style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Timeline
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📅 Timeline',
                      style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row('Tanggal Pengajuan', _formatDate(tx.dateApplied)),
                  const SizedBox(height: 8),
                  _row('Jatuh Tempo', _formatDate(tx.dateDue),
                      valueColor: isOverdue ? const Color(0xFFEF4444) : AppColors.textDark),
                  if (tx.status == 'Lelang' || tx.status == 'Terjual') ...[
                    const SizedBox(height: 8),
                    _row('Status', 'Dilelang / Terjual', valueColor: const Color(0xFF8B5CF6)),
                    if (_lelangHistory != null) ...[
                      const SizedBox(height: 8),
                      _row('Harga Terjual', 'Rp ${_formatCurrency(_lelangHistory!.hargaLelang)}',
                          valueColor: const Color(0xFF8B5CF6)),
                      const SizedBox(height: 8),
                      _row('Tanggal Lelang', _formatDate(_lelangHistory!.tglLelang)),
                    ],
                  ],
                  if (isOverdue) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                      child: Text('Sudah melewati jatuh tempo ${daysLeft.abs()} hari',
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ],
              ),
            ),

            // Riwayat Perpanjangan
            if (extensionHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔄 Riwayat Perpanjangan (${extensionHistory.length}x)',
                        style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...extensionHistory.asMap().entries.map((entry) {
                      final i = entry.key + 1;
                      final ext = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Perpanjangan ke-$i • ${_formatDateShort(ext.tglPerpanjangan)}',
                                style: const TextStyle(
                                    color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            _row('Jasa Titip Dibayar', 'Rp ${_formatCurrency(ext.jatipDibayar)}'),
                            const SizedBox(height: 4),
                            _row('Tempo ${_formatDateShort(ext.tglTempoLama)} → ${_formatDateShort(ext.tglTempoBaru)}', ''),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // ── Action Buttons ──
            if (isActive) ...[
              const SizedBox(height: 24),

              // Row 1: Perpanjang + Lunasi
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ExtensionPage(prefilledTxId: tx.id)),
                      ).then((_) => setState(() {})),
                      icon: const Icon(Icons.autorenew_rounded, size: 18),
                      label: const Text('Perpanjang'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RedemptionPage(prefilledTxId: tx.id)),
                      ).then((_) => setState(() {})),
                      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                      label: const Text('Lunasi / Tebus', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 1.5: Cetak Struk
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showPrintOptions,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Cetak Struk Gadai'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Row 2: Ubah Data + Batalkan
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showEditSheet,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Ubah Data & Nilai'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED),
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showCancelDialog,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Batalkan Gadai'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

}

// Helper widget untuk opsi cetak di bottom sheet
class _PrintOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrintOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

extension _TransaksiDetailPageExt on _TransaksiDetailPageState {
  Widget _row(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
        const SizedBox(width: 8),
        Text(value,
            style: TextStyle(color: valueColor ?? AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
