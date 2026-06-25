import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/login_page.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/nasabah_login_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/transaksi_detail_page.dart';

class AdminCabangDashboardPage extends StatefulWidget {
  final String namaAdmin;
  final String namaCabang;

  const AdminCabangDashboardPage({
    super.key,
    required this.namaAdmin,
    required this.namaCabang,
  });

  @override
  State<AdminCabangDashboardPage> createState() => _AdminCabangDashboardPageState();
}

class _AdminCabangDashboardPageState extends State<AdminCabangDashboardPage> {
  int _currentIndex = 0;

  String _formatCurrency(int val) {
    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Akun'),
        content: const Text('Yakin ingin keluar dari akun Admin Cabang?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RolePortalPage()),
                (route) => false,
              );
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txs = mockTransactions;
    final aktif = txs.where((t) => t.status == 'Aktif').length;
    final lunas = txs.where((t) => t.status == 'Lunas').length;
    final macet = txs.where((t) => t.status == 'Macet').length;
    final totalPinjaman = txs.where((t) => t.status == 'Aktif').fold(0, (s, t) => s + t.principal);
    final totalJasa = txs.where((t) => t.status == 'Aktif').fold(0, (s, t) => s + t.dailyFee);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    final tabs = ['Ringkasan', 'Transaksi', 'Nasabah'];
    final icons = [Icons.bar_chart_rounded, Icons.receipt_long_outlined, Icons.people_outline_rounded];

    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildRingkasan(aktif, lunas, macet, totalPinjaman, totalJasa, txs);
        break;
      case 1:
        body = _buildTransaksiList(txs);
        break;
      case 2:
        body = _buildNasabahList();
        break;
      default:
        body = _buildRingkasan(aktif, lunas, macet, totalPinjaman, totalJasa, txs);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F0),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text('Admin Cabang', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(widget.namaAdmin, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(widget.namaCabang, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  ],
                ),
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Nav Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: List.generate(tabs.length, (i) {
                final isSelected = _currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icons[i], size: 16, color: isSelected ? const Color(0xFFF59E0B) : AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            tabs[i],
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFF59E0B) : AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildRingkasan(int aktif, int lunas, int macet, int totalPinjaman, int totalJasa, List<PawnTransaction> txs) {
    final today = DateTime.now();
    final nearDue = txs.where((t) => t.status == 'Aktif' && t.dateDue.difference(today).inDays <= 3 && t.dateDue.isAfter(today)).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards
          Row(
            children: [
              Expanded(child: _statCard('Transaksi Aktif', '$aktif', Icons.receipt_long_outlined, const Color(0xFF1953A6))),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Sudah Lunas', '$lunas', Icons.check_circle_outline_rounded, const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('Macet', '$macet', Icons.warning_amber_rounded, const Color(0xFFEF4444))),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Total Nasabah', '${mockCustomers.length}', Icons.people_outline_rounded, const Color(0xFFF59E0B))),
            ],
          ),
          const SizedBox(height: 20),

          // Financial Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFFF3C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFCA28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💰 Ringkasan Keuangan Cabang', style: TextStyle(color: Color(0xFF92400E), fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _finRow('Total Pinjaman Beredar', 'Rp ${_formatCurrency(totalPinjaman)}'),
                const SizedBox(height: 8),
                _finRow('Est. Pendapatan Jasa/Hari', 'Rp ${_formatCurrency(totalJasa)}'),
                const SizedBox(height: 8),
                _finRow('Est. Pendapatan Bulan Ini', 'Rp ${_formatCurrency(totalJasa * 30)}'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Akses Cepat Portal (Verifikator & Nasabah)
          const Text('🔗 Akses Portal Lain', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _quickAccessCard(
                  title: 'Portal Verifikator',
                  subtitle: 'Masuk ke dashboard toko/verifikasi',
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAccessCard(
                  title: 'Portal Nasabah',
                  subtitle: 'Simulasi dashboard nasabah gadai',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NasabahLoginPage()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Near Due Warning
          if (nearDue.isNotEmpty) ...[
            const Text('⚠️ Jatuh Tempo dalam 3 Hari', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...nearDue.map((tx) {
              final c = mockCustomers.firstWhere((c) => c.id == tx.customerId, orElse: () => mockCustomers.first);
              final days = tx.dateDue.difference(today).inDays;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: Color(0xFFFFF7ED), shape: BoxShape.circle),
                      child: const Icon(Icons.timer_outlined, color: Color(0xFFF97316), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('${tx.brand} ${tx.model} • $days hari lagi', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('Rp ${_formatCurrency(tx.principal)}', style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTransaksiList(List<PawnTransaction> txs) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: txs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final tx = txs[i];
        final c = mockCustomers.firstWhere((c) => c.id == tx.customerId, orElse: () => mockCustomers.first);
        Color statusColor = AppColors.primary;
        if (tx.status == 'Macet') statusColor = const Color(0xFFEF4444);
        else if (tx.status == 'Lunas') statusColor = const Color(0xFF10B981);

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransaksiDetailPage(transaction: tx))).then((_) => setState(() {})),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.receipt_long_outlined, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('${tx.brand} ${tx.model}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text('Jatuh Tempo: ${_formatDate(tx.dateDue)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rp ${_formatCurrency(tx.principal)}', style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(tx.status.replaceAll('_', ' '), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNasabahList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: mockCustomers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final c = mockCustomers[i];
        final txCount = mockTransactions.where((t) => t.customerId == c.id).length;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFFFF7ED), shape: BoxShape.circle),
                child: Center(
                  child: Text(c.name[0], style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(c.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Text('NIK: ${c.nik}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$txCount transaksi', style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF92400E), fontSize: 13)),
        Text(value, style: const TextStyle(color: Color(0xFF78350F), fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _quickAccessCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
