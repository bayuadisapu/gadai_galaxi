import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/extension_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/redemption_page.dart';
import 'package:galaxi_gadai/core/config/system_config.dart';

class TransaksiDetailPage extends StatefulWidget {
  final PawnTransaction transaction;
  const TransaksiDetailPage({super.key, required this.transaction});

  @override
  State<TransaksiDetailPage> createState() => _TransaksiDetailPageState();
}

class _TransaksiDetailPageState extends State<TransaksiDetailPage> {
  Customer? _customer;
  List<ExtensionHistory> _extensions = [];

  @override
  void initState() {
    super.initState();
    _loadRelatedData();
  }

  Future<void> _loadRelatedData() async {
    final svc = SupabaseGadaiService.instance;
    try {
      final customers = await svc.fetchNasabah();
      final extensions = await svc.fetchExtensionHistory(widget.transaction.id);
      if (!mounted) return;
      setState(() {
        _customer = customers.firstWhere((c) => c.id == widget.transaction.customerId,
          orElse: () => Customer(id: '', name: 'Tidak Dikenal', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: ''));
        _extensions = extensions;
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
              try {
                await SupabaseGadaiService.instance.updateTransactionStatus(widget.transaction.id, 'Dibatalkan');
              } catch (_) {}
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaksi berhasil dibatalkan'),
                  backgroundColor: Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pop(context);
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
    final tx = widget.transaction;

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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: dec('Contoh: 1.000.000', prefix: 'Rp '),
                style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
                onChanged: (v) {
                  final val = int.tryParse(v) ?? 0;
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
                    final newDue = tx.dateApplied.add(Duration(days: newDays));

                    try {
                      await SupabaseGadaiService.instance.updateTransactionDetails(
                        tx.id,
                        brand: merkCtrl.text.trim().isNotEmpty ? merkCtrl.text.trim() : tx.brand,
                        model: modelCtrl.text.trim().isNotEmpty ? modelCtrl.text.trim() : tx.model,
                        condition: kondisiCtrl.text.trim().isNotEmpty ? kondisiCtrl.text.trim() : tx.condition,
                        principal: newPrincipal,
                        periodDays: newDays,
                        dailyFee: daily,
                        totalFee: newTotalFee,
                        totalRepayment: newPrincipal + newTotalFee,
                        dateDue: newDue,
                      );
                    } catch (_) {}
                    Navigator.pop(ctx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data transaksi berhasil diperbarui'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
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
    final tx = widget.transaction;
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
        title: Text(tx.id,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
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
