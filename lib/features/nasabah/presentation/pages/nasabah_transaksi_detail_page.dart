import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'nasabah_payment_page.dart';

class NasabahTransaksiDetailPage extends StatelessWidget {
  final PawnTransaction transaction;
  const NasabahTransaksiDetailPage({super.key, required this.transaction});

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
    final tx = transaction;
    final today = DateTime.now();
    final daysLeft = tx.dateDue.difference(today).inDays;
    final isOverdue = daysLeft < 0;

    // Hitung jasa harian dengan formula yang benar
    final int ceilTiers = tx.principal > 0 ? ((tx.principal / 500000).ceil()) : 0;
    final int dailyFeeCalc = ceilTiers * 5000;

    Color statusColor = AppColors.primary;
    if (tx.status == 'Macet') statusColor = const Color(0xFFEF4444);
    else if (tx.status == 'Lunas') statusColor = const Color(0xFF10B981);

    final extensionHistory = mockExtensionHistory.where((e) => e.transactionId == tx.id).toList();

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
                      Text(tx.id, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
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
      // CTA Perpanjang Tenor
      bottomNavigationBar: tx.status != 'Lunas'
          ? Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.autorenew_rounded, color: Colors.white, size: 20),
                  label: const Text('Perpanjang Tenor via Midtrans', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NasabahPaymentPage(transaction: tx)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003F88),
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
