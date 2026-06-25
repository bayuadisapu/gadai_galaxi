import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';
import 'package:galaxi_gadai/features/customer/presentation/pages/customer_search_page.dart';
import '../widgets/home_tab_content.dart';
import '../widgets/transaksi_tab_content.dart';
import '../widgets/laporan_tab_content.dart';
import '../widgets/notification_panel.dart';

class BranchDashboardPage extends StatefulWidget {
  const BranchDashboardPage({super.key});

  @override
  State<BranchDashboardPage> createState() => _BranchDashboardPageState();
}

class _BranchDashboardPageState extends State<BranchDashboardPage> {
  int _currentNavigationIndex = 0; // 0: Dashboard, 1: Transaksi, 2: Nasabah, 3: Laporan
  String _txInitialFilter = 'Semua';

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
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const RolePortalPage()),
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
    
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      body: Column(
        children: [
          // 1. Header Section
          Container(
            padding: EdgeInsets.only(
              top: statusBarHeight + 16,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: _currentNavigationIndex == 3
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Laporan & Rekap',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Location Info
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cabang Surabaya Pusat',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Selasa, 24 Oktober 2023',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // Notifications & Profile
                      Row(
                        children: [
                          // Bell Notification Icon with Badge
                          GestureDetector(
                            onTap: () => showNotificationPanel(context),
                            child: Stack(
                              children: [
                                const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                Positioned(
                                  right: 3,
                                  top: 3,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Profile Photo with Logout
                          GestureDetector(
                            onTap: _logout,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                color: Colors.white24,
                              ),
                              child: const ClipOval(
                                child: Center(
                                  child: Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          
          // 2. Main Scrollable Content
          Expanded(
            child: _buildBodyContent(),
          ),
          
          // 3. Custom Bottom Navigation Bar
          Container(
            padding: EdgeInsets.only(
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavBarItem(0, Icons.dashboard_outlined, 'Dashboard'),
                _buildNavBarItem(1, Icons.receipt_long_outlined, 'Transaksi'),
                _buildNavBarItem(2, Icons.people_outline_rounded, 'Nasabah'),
                _buildNavBarItem(3, Icons.analytics_outlined, 'Laporan'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentNavigationIndex) {
      case 0:
        return HomeTabContent(
          onRefresh: () {
            setState(() {});
          },
          onTabChanged: (index, {filter}) {
            setState(() {
              _currentNavigationIndex = index;
              if (filter != null) {
                _txInitialFilter = filter;
              } else {
                _txInitialFilter = 'Semua';
              }
            });
          },
        );
      case 1:
        return TransaksiTabContent(
          initialFilter: _txInitialFilter,
          onRefreshParent: () {
            setState(() {});
          },
        );
      case 2:
        return const CustomerSearchPage(isTab: true);
      case 3:
        return const LaporanTabContent();
      default:
        return HomeTabContent(
          onRefresh: () {
            setState(() {});
          },
          onTabChanged: (index, {filter}) {
            setState(() {
              _currentNavigationIndex = index;
              if (filter != null) {
                _txInitialFilter = filter;
              } else {
                _txInitialFilter = 'Semua';
              }
            });
          },
        );
    }
  }

  // Helper to build Navigation Bar Item
  Widget _buildNavBarItem(int index, IconData icon, String label) {
    final isSelected = _currentNavigationIndex == index;
    
    if (isSelected) {
      // Selected visual: Blue pill shape containing icon & label side-by-side
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE6EFFD),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    // Unselected visual: vertical icon + label in grey
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentNavigationIndex = index;
          _txInitialFilter = 'Semua'; // reset filter when switching manually
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: const Color(0xFF64748B),
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
