import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/login_page.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/nasabah_login_page.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() => _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  int _currentIndex = 0;

  // Mock data cabang
  final List<Map<String, dynamic>> _cabangList = [
    {'nama': 'Cabang Surabaya Pusat', 'kode': 'CBG-001', 'admin': 'Eko Prasetyo', 'txAktif': 12, 'txMacet': 2, 'pendapatan': 18500000, 'status': 'Aktif'},
    {'nama': 'Cabang Sidoarjo', 'kode': 'CBG-002', 'admin': 'Dewi Lestari', 'txAktif': 8, 'txMacet': 1, 'pendapatan': 11200000, 'status': 'Aktif'},
    {'nama': 'Cabang Gresik', 'kode': 'CBG-003', 'admin': 'Rudi Hartono', 'txAktif': 5, 'txMacet': 0, 'pendapatan': 7400000, 'status': 'Aktif'},
    {'nama': 'Cabang Mojokerto', 'kode': 'CBG-004', 'admin': '-', 'txAktif': 0, 'txMacet': 0, 'pendapatan': 0, 'status': 'Tidak Aktif'},
  ];

  final List<Map<String, dynamic>> _userList = [
    {'nama': 'Eko Prasetyo', 'role': 'Admin Cabang', 'cabang': 'Surabaya Pusat', 'email': 'admin.surabaya@galaxi.id', 'status': 'Aktif'},
    {'nama': 'Dewi Lestari', 'role': 'Admin Cabang', 'cabang': 'Sidoarjo', 'email': 'admin.sidoarjo@galaxi.id', 'status': 'Aktif'},
    {'nama': 'Budi Santoso', 'role': 'Verifikator', 'cabang': 'Surabaya Pusat', 'email': 'verif.budi@galaxi.id', 'status': 'Aktif'},
    {'nama': 'Sari Indah', 'role': 'Verifikator', 'cabang': 'Sidoarjo', 'email': 'verif.sari@galaxi.id', 'status': 'Aktif'},
  ];

  String _formatCurrency(int val) {
    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Akun'),
        content: const Text('Yakin ingin keluar dari Super Admin?'),
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
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final tabs = ['Overview', 'Cabang', 'Pengguna', 'Konfigurasi'];
    final icons = [Icons.dashboard_rounded, Icons.store_mall_directory_outlined, Icons.group_outlined, Icons.settings_outlined];

    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildOverview();
        break;
      case 1:
        body = _buildCabangList();
        break;
      case 2:
        body = _buildUserList();
        break;
      case 3:
        body = _buildKonfigurasi();
        break;
      default:
        body = _buildOverview();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          // Header Super Admin
          Container(
            padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFEF4444)],
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
                        const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('Super Admin', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Galaxi Gadai HQ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${_cabangList.where((c) => c['status'] == 'Aktif').length} Cabang Aktif', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  ],
                ),
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Navigation Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: List.generate(tabs.length, (i) {
                final isSelected = _currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFFEF4444) : Colors.transparent, width: 2.5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icons[i], size: 18, color: isSelected ? const Color(0xFFEF4444) : AppColors.textMuted),
                          const SizedBox(height: 3),
                          Text(tabs[i], style: TextStyle(color: isSelected ? const Color(0xFFEF4444) : AppColors.textMuted, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
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

  Widget _buildOverview() {
    final totalTx = mockTransactions.length;
    final totalAktif = mockTransactions.where((t) => t.status == 'Aktif').length;
    final totalMacet = mockTransactions.where((t) => t.status == 'Macet').length;
    final totalPinjaman = mockTransactions.where((t) => t.status == 'Aktif').fold(0, (s, t) => s + t.principal);
    final totalPendapatan = _cabangList.fold<int>(0, (s, c) => s + (c['pendapatan'] as int));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards Grid
          Row(
            children: [
              Expanded(child: _kpiCard('Total Cabang', '${_cabangList.length}', Icons.store_mall_directory_outlined, const Color(0xFF7C3AED))),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Transaksi Aktif', '$totalAktif', Icons.receipt_long_outlined, AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _kpiCard('Kasus Macet', '$totalMacet', Icons.warning_amber_rounded, const Color(0xFFEF4444))),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Total Nasabah', '${mockCustomers.length}', Icons.people_outline_rounded, const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 20),

          // Financial Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7F1D1D), Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💰 Total Pinjaman Beredar (Konsolidasi)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                Text('Rp ${_formatCurrency(totalPinjaman)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white24)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Est. Pendapatan/Bulan', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        Text('Rp ${_formatCurrency(totalPendapatan)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total Transaksi', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        Text('$totalTx Transaksi', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
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

          // Cabang Performance
          const Text('📊 Performa Cabang', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._cabangList.map((c) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c['status'] == 'Aktif' ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.store_mall_directory_outlined, color: c['status'] == 'Aktif' ? AppColors.primary : AppColors.textMuted, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['nama'], style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('${c['txAktif']} aktif • ${c['txMacet']} macet', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rp ${_formatCurrency(c['pendapatan'] as int)}', style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c['status'] == 'Aktif' ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(c['status'], style: TextStyle(color: c['status'] == 'Aktif' ? const Color(0xFF10B981) : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCabangList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: _cabangList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final c = _cabangList[i];
        final isAktif = c['status'] == 'Aktif';
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isAktif ? const Color(0xFFDBEAFE) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c['nama'], style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAktif ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(c['status'], style: TextStyle(color: isAktif ? const Color(0xFF10B981) : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${c['kode']} • Admin: ${c['admin']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _miniStat('Aktif', '${c['txAktif']}', AppColors.primary)),
                  Expanded(child: _miniStat('Macet', '${c['txMacet']}', const Color(0xFFEF4444))),
                  Expanded(child: _miniStat('Pendapatan/bln', 'Rp ${_formatCurrency(c['pendapatan'] as int)}', const Color(0xFF10B981))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: _userList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final u = _userList[i];
        final isAdmin = u['role'] == 'Admin Cabang';
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
                decoration: BoxDecoration(
                  color: isAdmin ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAdmin ? Icons.manage_accounts_rounded : Icons.storefront_rounded,
                  color: isAdmin ? const Color(0xFFF59E0B) : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['nama'], style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(u['email'], style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    Text('${u['cabang']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(u['role'], style: TextStyle(color: isAdmin ? const Color(0xFFF59E0B) : AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKonfigurasi() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚙️ Konfigurasi Sistem', style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          _configSection('Tarif Jasa Titip', [
            _configItem('Tarif per Unit (Rp 500.000)', 'Rp 5.000 / hari'),
            _configItem('Periode Minimum', '15 Hari'),
            _configItem('Periode Maksimum', '30 Hari'),
          ]),
          const SizedBox(height: 16),

          _configSection('Batas Taksiran', [
            _configItem('Taksiran Emas (maks.)', '60% dari nilai pasar'),
            _configItem('Taksiran Kendaraan (maks.)', '70% setelah depresiasi'),
            _configItem('Taksiran Elektronik (maks.)', '60% nilai pasar'),
          ]),
          const SizedBox(height: 16),

          _configSection('Notifikasi', [
            _configItem('Peringatan Jatuh Tempo', '3 hari sebelumnya'),
            _configItem('Status Auto Macet', 'H+1 setelah jatuh tempo'),
          ]),
          const SizedBox(height: 16),

          _configSection('Harga Referensi Emas (Mock)', [
            _configItem('Emas 24K', 'Rp 1.150.000 / gram'),
            _configItem('Sumber Data', 'Server Galaxi HQ'),
          ]),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Color(0xFFEF4444), size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Perubahan konfigurasi memerlukan konfirmasi 2FA Super Admin.', style: TextStyle(color: Color(0xFF991B1B), fontSize: 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _configSection(String title, List<Widget> items) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ...items,
        ],
      ),
    );
  }

  Widget _configItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
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
