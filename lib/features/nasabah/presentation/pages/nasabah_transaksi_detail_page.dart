import 'dart:async';
import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/services/midtrans_service.dart';
import 'package:galaxi_gadai/core/config/system_config.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/midtrans_snap_page.dart';

class NasabahTransaksiDetailPage extends StatefulWidget {
  final PawnTransaction transaction;
  const NasabahTransaksiDetailPage({super.key, required this.transaction});

  @override
  State<NasabahTransaksiDetailPage> createState() => _NasabahTransaksiDetailPageState();
}

class _NasabahTransaksiDetailPageState extends State<NasabahTransaksiDetailPage> {
  List<ExtensionHistory> _extensions = [];

  @override
  void initState() {
    super.initState();
    _loadExtensions();
  }

  Future<void> _loadExtensions() async {
    try {
      final ext = await SupabaseGadaiService.instance.fetchExtensionHistory(widget.transaction.id);
      if (!mounted) return;
      setState(() => _extensions = ext);
    } catch (_) {}
  }

  // ── PERPANJANG VIA MIDTRANS ──
  Future<void> _showPerpanjangSheet() async {
    final tx = widget.transaction;
    if (tx.status == 'Lunas') return;

    int selectedDays = 15;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final int dailyFee = tx.dailyFee > 0 ? tx.dailyFee : SystemConfig.calculateDailyFee(tx.principal);
          final int jatipBayar = dailyFee * selectedDays;
          final baseDate = tx.dateDue.isBefore(DateTime.now()) ? DateTime.now() : tx.dateDue;
          final newDue = baseDate.add(Duration(days: selectedDays));
          final months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
          final newDueFmt = '${newDue.day.toString().padLeft(2,'0')} ${months[newDue.month-1]} ${newDue.year}';

          String fmt(int v) { final s=v.toString(); final b=StringBuffer(); for(int i=0;i<s.length;i++){if(i>0&&(s.length-i)%3==0)b.write('.');b.write(s[i]);}return b.toString(); }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  const Row(children: [
                    Icon(Icons.update_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Text('Perpanjang Tenor Gadai', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  ]),
                  const SizedBox(height: 18),

                  // Pilih durasi
                  const Text('Pilih Durasi Perpanjangan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(children: [15, 30].map((d) => Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => selectedDays = d),
                      child: Container(
                        margin: EdgeInsets.only(right: d == 15 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedDays == d ? AppColors.primary : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedDays == d ? AppColors.primary : const Color(0xFFCBD5E1)),
                        ),
                        child: Column(children: [
                          Text('$d Hari', style: TextStyle(fontWeight: FontWeight.bold, color: selectedDays == d ? Colors.white : AppColors.textDark, fontSize: 15)),
                          Text('Rp ${fmt(dailyFee * d)}', style: TextStyle(color: selectedDays == d ? Colors.white70 : AppColors.textMuted, fontSize: 12)),
                        ]),
                      ),
                    ),
                  )).toList()),
                  const SizedBox(height: 20),

                  // Ringkasan
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Jasa Titip dibayar', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text('Rp ${fmt(jatipBayar)}', style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Jatuh tempo baru', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(newDueFmt, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Tombol Bayar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _processMidtransPayment(tx, selectedDays, jatipBayar);
                      },
                      icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                      label: Text('Bayar Rp ${fmt(jatipBayar)} via Midtrans', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _processMidtransPayment(PawnTransaction tx, int days, int amount) async {
    // Tampilkan loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final orderId = 'GADAI-EXT-${tx.id}-${DateTime.now().millisecondsSinceEpoch}';
      final snap = await MidtransService.createSnapToken(
        orderId: orderId,
        grossAmount: amount,
        customerName: 'Nasabah ${tx.displayCode}',
        customerPhone: '',
        itemName: 'Perpanjang Gadai ${tx.displayCode} ($days Hari)',
      );

      if (!mounted) return;
      Navigator.pop(context); // tutup loading

      final result = await Navigator.push<MidtransResult>(
        context,
        MaterialPageRoute(
          builder: (_) => MidtransSnapPage(snapUrl: snap['redirect_url']!, orderId: orderId),
        ),
      );

      if (!mounted) return;

      if (result == MidtransResult.success) {
        await _applyExtension(tx, days, amount);
      } else if (result == MidtransResult.pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏳ Pembayaran sedang diproses. Tenor akan diperbarui otomatis.'), backgroundColor: Colors.orange),
        );
      } else if (result == MidtransResult.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Pembayaran gagal atau dibatalkan.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // tutup loading jika masih ada
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses pembayaran: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _applyExtension(PawnTransaction tx, int days, int jatipBayar) async {
    final svc = SupabaseGadaiService.instance;
    final oldDueDate = tx.dateDue;
    final baseDate = tx.dateDue.isBefore(DateTime.now()) ? DateTime.now() : tx.dateDue;
    final newDueDate = baseDate.add(Duration(days: days));
    final newTotalFee = (tx.dailyFee > 0 ? tx.dailyFee : SystemConfig.calculateDailyFee(tx.principal)) * days;
    final newTotalRepayment = tx.principal + newTotalFee;

    await svc.createExtension(ExtensionHistory(
      id: '', transactionId: tx.id,
      jatipDibayar: jatipBayar,
      tglPerpanjangan: DateTime.now(),
      tglTempoLama: oldDueDate,
      tglTempoBaru: newDueDate,
    ));
    await svc.updateTransactionStatus(tx.id, 'Aktif', newDueDate: newDueDate, periodDays: days, totalFee: newTotalFee, totalRepayment: newTotalRepayment);
    unawaited(svc.logExtensionRequested(tx.customerId, tx.id));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Perpanjangan berhasil! Jatuh tempo baru: ${_formatDate(newDueDate)}'), backgroundColor: const Color(0xFF10B981)),
    );
    _loadExtensions();
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
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final today = DateTime.now();
    final daysLeft = tx.dateDue.difference(today).inDays;
    final isOverdue = daysLeft < 0;

    // Gunakan dailyFee yang tersimpan di transaksi, bukan hitung ulang dari SystemConfig
    final int dailyFeeCalc = tx.dailyFee > 0 ? tx.dailyFee : SystemConfig.calculateDailyFee(tx.principal);

    Color statusColor = AppColors.primary;
    if (tx.status == 'Macet') statusColor = const Color(0xFFEF4444);
    else if (tx.status == 'Lunas') statusColor = const Color(0xFF10B981);

    final extensionHistory = _extensions;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Transaksi',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Collateral Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tx.displayCode, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tx.status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('${tx.brand} ${tx.model}', style: const TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Jenis: ${tx.collateralType} • Kondisi: ${tx.condition}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Countdown / Due Date Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOverdue ? const Color(0xFFFEF2F2) : (daysLeft <= 3 ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isOverdue ? const Color(0xFFFCA5A5) : (daysLeft <= 3 ? const Color(0xFFFED7AA) : const Color(0xFFA7F3D0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                    color: isOverdue ? const Color(0xFFEF4444) : (daysLeft <= 3 ? const Color(0xFFF97316) : const Color(0xFF10B981)),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOverdue ? 'Sudah Melewati Jatuh Tempo!' : (daysLeft == 0 ? 'Jatuh Tempo HARI INI!' : 'Jatuh tempo $daysLeft hari lagi'),
                          style: TextStyle(
                            color: isOverdue ? const Color(0xFFEF4444) : (daysLeft <= 3 ? const Color(0xFFF97316) : const Color(0xFF059669)),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tanggal Jatuh Tempo: ${_formatDate(tx.dateDue)}',
                          style: TextStyle(
                            color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF059669),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Financial Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💰 Rincian Keuangan', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _row('Nominal Pinjaman (N)', 'Rp ${_formatCurrency(tx.principal)}'),
                  const SizedBox(height: 10),
                  _row('Jasa Titip Harian', 'Rp ${_formatCurrency(dailyFeeCalc)} / hari'),
                  const SizedBox(height: 10),
                  _row('Periode Gadai', '${tx.periodDays} Hari'),
                  const SizedBox(height: 10),
                  _row('Total Jasa Titip (JT)', 'Rp ${_formatCurrency(tx.totalFee)}'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(color: Color(0xFFDBEAFE)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Tebusan', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('Rp ${_formatCurrency(tx.principal + tx.totalFee)}', style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Timeline Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📅 Timeline', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _row('Tanggal Pengajuan', _formatDate(tx.dateApplied)),
                  const SizedBox(height: 10),
                  _row('Jatuh Tempo', _formatDate(tx.dateDue)),
                ],
              ),
            ),

            // Riwayat Perpanjangan
            if (extensionHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔄 Riwayat Perpanjangan', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...extensionHistory.asMap().entries.map((entry) {
                      final i = entry.key + 1;
                      final ext = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Perpanjangan ke-$i', style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            _row('Jasa Titip Dibayar', 'Rp ${_formatCurrency(ext.jatipDibayar)}'),
                            const SizedBox(height: 4),
                            _row('Tempo Lama', _formatDateShort(ext.tglTempoLama)),
                            const SizedBox(height: 4),
                            _row('Tempo Baru', _formatDateShort(ext.tglTempoBaru)),
                            const SizedBox(height: 4),
                            _row('Tgl Perpanjangan', _formatDateShort(ext.tglPerpanjangan)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: widget.transaction.status != 'Lunas'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: ElevatedButton.icon(
                  onPressed: _showPerpanjangSheet,
                  icon: const Icon(Icons.update_rounded, color: Colors.white, size: 20),
                  label: const Text('Perpanjang Tenor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
