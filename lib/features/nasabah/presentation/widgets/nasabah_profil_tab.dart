import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';

class NasabahProfilTab extends StatelessWidget {
  final Customer customer;
  final VoidCallback onLogout;

  const NasabahProfilTab({super.key, required this.customer, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'N',
                style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(customer.name, style: const TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(customer.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 24),

          // Info Card
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
                const Text('Informasi Pribadi', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _infoRow(Icons.badge_outlined, 'NIK', customer.nik.isEmpty ? '-' : customer.nik),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.phone_outlined, 'Nomor HP', customer.phone),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.place_outlined, 'Tempat Lahir', customer.birthPlace.isEmpty ? '-' : customer.birthPlace),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.cake_outlined, 'Tanggal Lahir', customer.birthDate.isEmpty ? '-' : customer.birthDate),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.person_outline_rounded, 'Jenis Kelamin', customer.gender.isEmpty ? '-' : customer.gender),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.home_outlined, 'Alamat', customer.address.isEmpty ? '-' : customer.address),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats Card
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
                const Text('Statistik Transaksi', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Builder(builder: (ctx) {
                  final myTxs = mockTransactions.where((tx) => tx.customerId == customer.id).toList();
                  final aktif = myTxs.where((tx) => tx.status == 'Aktif').length;
                  final lunas = myTxs.where((tx) => tx.status == 'Lunas').length;
                  final macet = myTxs.where((tx) => tx.status == 'Macet').length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('$aktif', 'Aktif', AppColors.primary),
                      _statItem('$lunas', 'Lunas', const Color(0xFF10B981)),
                      _statItem('$macet', 'Macet', const Color(0xFFEF4444)),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              label: const Text('Keluar Akun', style: TextStyle(color: Color(0xFFEF4444), fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(String count, String label, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    );
  }
}
