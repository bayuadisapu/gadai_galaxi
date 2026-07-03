import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';
import 'package:galaxi_gadai/features/customer/presentation/pages/customer_search_page.dart';
import '../widgets/home_tab_content.dart';
import '../widgets/transaksi_tab_content.dart';
import '../widgets/laporan_tab_content.dart';
import '../widgets/notification_panel.dart';

class BranchDashboardPage extends StatefulWidget {
  final String cabangId;
  const BranchDashboardPage({super.key, this.cabangId = 'pusat'});

  @override
  State<BranchDashboardPage> createState() => _BranchDashboardPageState();
}

class _BranchDashboardPageState extends State<BranchDashboardPage> {
  int _currentNavigationIndex = 0;
  String _txInitialFilter = 'Semua';
  final _svc = SupabaseGadaiService.instance;

  List<PawnTransaction> _txs = [];
  List<Customer> _customers = [];
  String _branchName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Auto-mark transaksi overdue → Macet
      await _svc.markOverdueTransactions(branchId: widget.cabangId);

      final txs = await _svc.fetchTransactions(branchId: widget.cabangId);
      final customers = await _svc.fetchNasabah(branchId: widget.cabangId);
      final branchName = await _svc.getBranchName(widget.cabangId);
      if (!mounted) return;
      setState(() { _txs = txs; _customers = customers; _branchName = branchName; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatDate() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Akun'),
        content: const Text('Yakin ingin keluar dari akun toko?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _svc.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const RolePortalPage()), (route) => false);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(color: AppColors.primary),
            child: _currentNavigationIndex == 3
                ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Row(children: [Icon(Icons.menu_rounded, color: Colors.white, size: 24), SizedBox(width: 16), Text('Laporan & Rekap', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
                    const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 22),
                  ])
                : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_branchName.isNotEmpty ? _branchName : 'Cabang', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(_formatDate(), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                      ]),
                    ]),
                    Row(children: [
                      GestureDetector(
                        onTap: () => showNotificationPanel(context, transactions: _txs, customers: _customers),
                        child: Stack(children: [
                          const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
                          Positioned(right: 3, top: 3, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle))),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _logout,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5), color: Colors.white24),
                          child: const Center(child: Icon(Icons.logout_rounded, color: Colors.white, size: 18)),
                        ),
                      ),
                    ]),
                  ]),
          ),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBodyContent()),
          Container(
            padding: EdgeInsets.only(top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildNavBarItem(0, Icons.dashboard_outlined, 'Dashboard'),
              _buildNavBarItem(1, Icons.receipt_long_outlined, 'Transaksi'),
              _buildNavBarItem(2, Icons.people_outline_rounded, 'Nasabah'),
              _buildNavBarItem(3, Icons.analytics_outlined, 'Laporan'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentNavigationIndex) {
      case 0:
        return HomeTabContent(
          transactions: _txs,
          customers: _customers,
          branchId: widget.cabangId,
          onRefresh: () => _loadData(),
          onTabChanged: (index, {filter}) {
            setState(() { _currentNavigationIndex = index; _txInitialFilter = filter ?? 'Semua'; });
          },
        );
      case 1:
        return TransaksiTabContent(
          transactions: _txs,
          customers: _customers,
          initialFilter: _txInitialFilter,
          onRefreshParent: () => _loadData(),
        );
      case 2:
        return CustomerSearchPage(isTab: true, branchId: widget.cabangId);
      case 3:
        return LaporanTabContent(branchId: widget.cabangId);
      default:
        return HomeTabContent(
          transactions: _txs,
          customers: _customers,
          branchId: widget.cabangId,
          onRefresh: () => _loadData(),
          onTabChanged: (index, {filter}) {
            setState(() { _currentNavigationIndex = index; _txInitialFilter = filter ?? 'Semua'; });
          },
        );
    }
  }

  Widget _buildNavBarItem(int index, IconData icon, String label) {
    final isSelected = _currentNavigationIndex == index;
    if (isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFE6EFFD), borderRadius: BorderRadius.circular(24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );
    }
    return GestureDetector(
      onTap: () => setState(() { _currentNavigationIndex = index; _txInitialFilter = 'Semua'; }),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFF64748B), size: 22),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
