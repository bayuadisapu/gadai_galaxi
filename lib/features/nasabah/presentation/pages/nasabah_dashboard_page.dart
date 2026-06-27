import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';
import '../widgets/nasabah_home_tab.dart';
import '../widgets/nasabah_riwayat_tab.dart';
import '../widgets/nasabah_kalkulator_tab.dart';
import '../widgets/nasabah_profil_tab.dart';

class NasabahDashboardPage extends StatefulWidget {
  final Customer customer;
  const NasabahDashboardPage({super.key, required this.customer});

  @override
  State<NasabahDashboardPage> createState() => _NasabahDashboardPageState();
}

class _NasabahDashboardPageState extends State<NasabahDashboardPage> {
  int _currentIndex = 0;
  final _svc = SupabaseGadaiService.instance;
  List<PawnTransaction> _txs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final txs = await _svc.fetchTransactions(nasabahId: widget.customer.id);
      if (!mounted) return;
      setState(() { _txs = txs; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Akun'),
        content: const Text('Yakin ingin keluar dari akun nasabah?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Log aktivitas logout
              await _svc.logNasabahLogout(widget.customer.id, widget.customer.name);
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
    final tabs = ['Beranda', 'Riwayat', 'Kalkulator', 'Profil'];
    final icons = [Icons.home_rounded, Icons.receipt_long_outlined, Icons.calculate_outlined, Icons.person_outline_rounded];

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      switch (_currentIndex) {
        case 0:
          body = NasabahHomeTab(customer: widget.customer, transactions: _txs, onTabChanged: (i) => setState(() => _currentIndex = i));
          break;
        case 1:
          body = NasabahRiwayatTab(customer: widget.customer, transactions: _txs);
          break;
        case 2:
          body = const NasabahKalkulatorTab();
          break;
        case 3:
          body = NasabahProfilTab(customer: widget.customer, onLogout: _logout);
          break;
        default:
          body = NasabahHomeTab(customer: widget.customer, transactions: _txs, onTabChanged: (i) => setState(() => _currentIndex = i));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Center(child: Text(widget.customer.name.isNotEmpty ? widget.customer.name[0].toUpperCase() : 'N', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Halo, ${widget.customer.name.split(' ').first} 👋', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Nasabah Galaxi Gadai', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                  ]),
                ]),
                IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white), onPressed: _logout),
              ],
            ),
          ),
          Expanded(child: RefreshIndicator(onRefresh: _loadData, child: body)),
          Container(
            padding: EdgeInsets.only(top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(4, (index) {
                final isSelected = _currentIndex == index;
                if (isSelected) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFE6EFFD), borderRadius: BorderRadius.circular(24)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icons[index], color: AppColors.primary, size: 20),
                      const SizedBox(width: 6),
                      Text(tabs[index], style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  );
                }
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = index),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icons[index], color: const Color(0xFF64748B), size: 22),
                    const SizedBox(height: 4),
                    Text(tabs[index], style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500)),
                  ]),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
