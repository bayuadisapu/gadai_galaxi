import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/new_pawn_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/extension_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/redemption_page.dart';
import 'dashboard_shared_widgets.dart';

class HomeTabContent extends StatelessWidget {
  final Function(int index, {String? filter}) onTabChanged;
  final VoidCallback onRefresh;

  const HomeTabContent({
    super.key,
    required this.onTabChanged,
    required this.onRefresh,
  });

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

  @override
  Widget build(BuildContext context) {
    // 1. Dynamic Calculations
    final activeTxCount = mockTransactions.where((tx) => tx.status == 'Aktif').length;
    final macetTxCount = mockTransactions.where((tx) => tx.status == 'Macet').length;
    final totalOutstanding = mockTransactions
        .where((tx) => tx.status == 'Aktif' || tx.status == 'Macet')
        .fold<int>(0, (sum, tx) => sum + tx.principal);
    
    // Near due (due in <= 7 days, or overdue)
    final today = DateTime.now();
    final dueSoonTxCount = mockTransactions
        .where((tx) => tx.status == 'Aktif' && tx.dateDue.difference(today).inDays <= 7)
        .length;

    // Filter top due soon transactions for home screen listing
    final dueSoonTransactions = mockTransactions
        .where((tx) => tx.status == 'Aktif' || tx.status == 'Macet')
        .toList()
      ..sort((a, b) => a.dateDue.compareTo(b.dateDue));
    final topDueSoon = dueSoonTransactions.take(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Section
            const Text(
              'Selamat pagi, Budi 👋',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$activeTxCount transaksi aktif hari ini',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Stats Cards Grid
            // First Row: Two Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Transaksi Aktif',
                    value: '$activeTxCount',
                    accentColor: AppColors.primary,
                    valueColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Jatuh Tempo Terdekat',
                    value: '$dueSoonTxCount',
                    accentColor: const Color(0xFFF59E0B),
                    valueColor: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Second Row: Total Pinjaman
            StatCard(
              title: 'Total Pinjaman Beredar',
              value: 'Rp ${_formatCurrency(totalOutstanding)}',
              accentColor: AppColors.primary,
              valueColor: AppColors.primary,
              trailingIcon: const Icon(
                Icons.payments_outlined,
                color: Color(0xFF94A3B8),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            
            // Third Row: Transaksi Macet
            StatCard(
              title: 'Transaksi Macet',
              value: '$macetTxCount',
              accentColor: const Color(0xFFEF4444),
              valueColor: const Color(0xFFEF4444),
              trailingIcon: Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                size: 32,
              ),
            ),
            const SizedBox(height: 28),
            
            // Quick Actions (Aksi Cepat)
            const Text(
              'Aksi Cepat',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Grid of 4 actions
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ActionButton(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Ajukan Gadai Baru',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NewPawnPage()),
                          ).then((_) => onRefresh());
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ActionButton(
                        icon: Icons.person_search_outlined,
                        label: 'Cari Nasabah',
                        onTap: () {
                          onTabChanged(2);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ActionButton(
                        icon: Icons.autorenew_rounded,
                        label: 'Proses Perpanjangan',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ExtensionPage()),
                          ).then((_) => onRefresh());
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ActionButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Proses Pelunasan',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RedemptionPage()),
                          ).then((_) => onRefresh());
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            
            // Upcoming Due Dates (Jatuh Tempo Terdekat)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jatuh Tempo Terdekat',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    onTabChanged(1, filter: 'Aktif');
                  },
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Due Date List Items
            if (topDueSoon.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFF10B981)),
                    SizedBox(height: 8),
                    Text(
                      'Semua aman! Tidak ada jatuh tempo terdekat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...topDueSoon.map((tx) {
                final customer = mockCustomers.firstWhere(
                  (c) => c.id == tx.customerId,
                  orElse: () => Customer(
                    id: '',
                    name: 'Nasabah Tidak Dikenal',
                    nik: '',
                    birthPlace: '',
                    birthDate: '',
                    gender: '',
                    phone: '',
                    address: '',
                  ),
                );
                
                Color statusColor = AppColors.primary;
                Color statusBgColor = const Color(0xFFDBEAFE);
                if (tx.status == 'Macet') {
                  statusColor = const Color(0xFFEF4444);
                  statusBgColor = const Color(0xFFFEF2F2);
                }
                
                IconData collIcon = Icons.phone_android_rounded;
                if (tx.collateralType == 'Laptop') {
                  collIcon = Icons.laptop_mac_rounded;
                } else if (tx.collateralType == 'Emas') {
                  collIcon = Icons.workspace_premium_outlined;
                } else if (tx.collateralType == 'Motor / Mobil' || tx.collateralType == 'Kendaraan') {
                  collIcon = Icons.two_wheeler_rounded;
                }

                return Column(
                  children: [
                    DueItem(
                      icon: collIcon,
                      name: customer.name,
                      details: '${tx.collateralType} ${tx.brand} ${tx.model} • ${_formatIndonesianDate(tx.dateDue)}',
                      amount: 'Rp ${_formatCurrency(tx.principal)}',
                      status: tx.status.toUpperCase(),
                      statusColor: statusColor,
                      statusBgColor: statusBgColor,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}
