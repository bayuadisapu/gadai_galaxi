import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/extension_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/redemption_page.dart';

class TransaksiDetailPage extends StatefulWidget {
  final PawnTransaction transaction;
  const TransaksiDetailPage({super.key, required this.transaction});

  @override
  State<TransaksiDetailPage> createState() => _TransaksiDetailPageState();
}

class _TransaksiDetailPageState extends State<TransaksiDetailPage> {
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

    final customer = mockCustomers.firstWhere(
      (c) => c.id == tx.customerId,
      orElse: () => Customer(id: '', name: 'Tidak Dikenal', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: ''),
    );

    final int ceilTiers = tx.principal > 0 ? ((tx.principal / 500000).ceil()) : 0;
    final int dailyFeeCalc = ceilTiers * 5000;

    Color statusColor = AppColors.primary;
    Color statusBg = const Color(0xFFEFF6FF);
    if (tx.status == 'Macet') { statusColor = const Color(0xFFEF4444); statusBg = const Color(0xFFFEF2F2); }
    else if (tx.status == 'Lunas') { statusColor = const Color(0xFF10B981); statusBg = const Color(0xFFECFDF5); }
    else if (tx.status == 'Perlu_Bayar_Jatip') { statusColor = const Color(0xFFF59E0B); statusBg = const Color(0xFFFFF7ED); }

    final extensionHistory = mockExtensionHistory.where((e) => e.transactionId == tx.id).toList();

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
        title: Text(tx.id, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
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
                        Text(customer.name, style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(customer.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text('NIK: ${customer.nik}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                    child: Text(tx.status.replaceAll('_', ' '), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Collateral Card
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
                  const Text('🏷️ Data Jaminan', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
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

            // Financial Card
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
                  const Text('💰 Rincian Keuangan', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
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
                      const Text('Total Tebusan', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('Rp ${_formatCurrency(tx.principal + tx.totalFee)}', style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.bold)),
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
                  const Text('📅 Timeline', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row('Tanggal Pengajuan', _formatDate(tx.dateApplied)),
                  const SizedBox(height: 8),
                  _row(
                    'Jatuh Tempo',
                    _formatDate(tx.dateDue),
                    valueColor: isOverdue ? const Color(0xFFEF4444) : AppColors.textDark,
                  ),
                  if (isOverdue) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'Sudah melewati jatuh tempo ${daysLeft.abs()} hari',
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
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
                    Text('🔄 Riwayat Perpanjangan (${extensionHistory.length}x)', style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...extensionHistory.asMap().entries.map((entry) {
                      final i = entry.key + 1;
                      final ext = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Perpanjangan ke-$i • ${_formatDateShort(ext.tglPerpanjangan)}', style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.bold)),
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

            // Action Buttons
            if (tx.status != 'Lunas') ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ExtensionPage(prefilledTxId: tx.id)),
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
                        MaterialPageRoute(builder: (context) => RedemptionPage(prefilledTxId: tx.id)),
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
        Text(value, style: TextStyle(color: valueColor ?? AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
