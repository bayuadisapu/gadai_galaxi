import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import '../pages/nasabah_transaksi_detail_page.dart';

class NasabahRiwayatTab extends StatefulWidget {
  final Customer customer;
  final List<PawnTransaction> transactions;
  final VoidCallback? onRefresh;
  const NasabahRiwayatTab({super.key, required this.customer, required this.transactions, this.onRefresh});

  @override
  State<NasabahRiwayatTab> createState() => _NasabahRiwayatTabState();
}

class _NasabahRiwayatTabState extends State<NasabahRiwayatTab> {
  String _filter = 'Semua';

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
    final myTxs = widget.transactions.where((tx) => tx.customerId == widget.customer.id).toList();
    final filtered = _filter == 'Semua' ? myTxs : myTxs.where((tx) => tx.status == _filter).toList();

    return Column(
      children: [
        Container(
          height: 60,
          color: Colors.transparent,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: ['Semua', 'Aktif', 'Lunas', 'Macet'].map((f) {
              final isSelected = _filter == f;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.royalBlue : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.royalBlue : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.royalBlue.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      f,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded, size: 32, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada transaksi',
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    Color statusColor = AppColors.royalBlue;
                    Color statusBg = const Color(0xFFEFF6FF);
                    if (tx.status == 'Macet') {
                      statusColor = const Color(0xFFEF4444);
                      statusBg = const Color(0xFFFEF2F2);
                    } else if (tx.status == 'Lunas') {
                      statusColor = const Color(0xFF10B981);
                      statusBg = const Color(0xFFECFDF5);
                    }

                    IconData collIcon = Icons.phone_android_rounded;
                    if (tx.collateralType == 'Laptop') collIcon = Icons.laptop_mac_rounded;
                    else if (tx.collateralType == 'Emas') collIcon = Icons.workspace_premium_outlined;
                    else if (tx.collateralType.contains('Motor') || tx.collateralType.contains('Mobil')) collIcon = Icons.two_wheeler_rounded;

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NasabahTransaksiDetailPage(transaction: tx)),
                      ).then((_) {
                        widget.onRefresh?.call();
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.royalBlue.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(collIcon, color: AppColors.royalBlue, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${tx.brand} ${tx.model}', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${tx.displayCode} • Jatuh Tempo: ${_formatDate(tx.dateDue)}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
                                  Text('Pinjaman: Rp ${_formatCurrency(tx.principal)}', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                              child: Text(tx.status, style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
