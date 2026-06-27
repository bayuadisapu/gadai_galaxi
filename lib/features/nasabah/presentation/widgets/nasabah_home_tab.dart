import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import '../pages/nasabah_transaksi_detail_page.dart';
import '../pages/nasabah_payment_page.dart';

class NasabahHomeTab extends StatelessWidget {
  final Customer customer;
  final List<PawnTransaction> transactions;
  final Function(int) onTabChanged;

  const NasabahHomeTab({super.key, required this.customer, required this.transactions, required this.onTabChanged});

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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final myTxs = transactions.where((tx) => tx.customerId == customer.id).toList();
    final activeTxs = myTxs.where((tx) => tx.status == 'Aktif' || tx.status == 'Perlu_Bayar_Jatip').toList();
    final today = DateTime.now();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activeTxs.length} Gadai Aktif',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  activeTxs.isNotEmpty
                      ? 'Rp ${_formatCurrency(activeTxs.fold(0, (sum, tx) => sum + tx.principal))}'
                      : 'Rp 0',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total pinjaman beredar',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions
          const Text('Aksi Cepat', style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.calculate_outlined,
                  label: 'Kalkulator\nGadai',
                  color: AppColors.primary,
                  onTap: () => onTabChanged(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Riwayat\nTransaksi',
                  color: const Color(0xFF10B981),
                  onTap: () => onTabChanged(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.person_outline_rounded,
                  label: 'Profil\nSaya',
                  color: const Color(0xFFF59E0B),
                  onTap: () => onTabChanged(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Active Transactions
          const Text('Transaksi Aktif', style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          if (activeTxs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                  SizedBox(height: 12),
                  Text('Tidak ada transaksi aktif', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ],
              ),
            )
          else
            ...activeTxs.map((tx) {
              final daysLeft = tx.dateDue.difference(today).inDays;
              final isOverdue = daysLeft < 0;
              final isNearDue = daysLeft <= 3 && !isOverdue;
              Color statusColor = AppColors.primary;
              String statusLabel = 'Aktif';
              if (isOverdue) {
                statusColor = const Color(0xFFEF4444);
                statusLabel = 'Jatuh Tempo!';
              } else if (isNearDue) {
                statusColor = const Color(0xFFF59E0B);
                statusLabel = '$daysLeft hari lagi';
              } else {
                statusLabel = '$daysLeft hari lagi';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NasabahTransaksiDetailPage(transaction: tx)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${tx.brand} ${tx.model}',
                              style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pinjaman', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                Text('Rp ${_formatCurrency(tx.principal)}', style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Jatuh Tempo', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                Text(_formatDate(tx.dateDue), style: TextStyle(color: isOverdue ? const Color(0xFFEF4444) : AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        if (isOverdue || isNearDue) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.autorenew_rounded, size: 14, color: Colors.white),
                                    label: Text(
                                      isOverdue ? 'Perpanjang' : 'Perpanjang Tenor',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => NasabahPaymentPage(transaction: tx)),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF003F88),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.redeem_rounded, size: 14, color: Colors.white),
                                    label: const Text(
                                      'Tebus Barang',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => NasabahPaymentPage(transaction: tx, isRedemption: true)),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF065F46),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (isOverdue) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Sudah lewat ${daysLeft.abs()} hari dari jatuh tempo!',
                                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDark, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
