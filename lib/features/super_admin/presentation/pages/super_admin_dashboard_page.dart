import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/transaksi_detail_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/new_pawn_page.dart';
import 'package:galaxi_gadai/core/config/system_config.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});
  @override
  State<SuperAdminDashboardPage> createState() => _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  int _currentIndex = 0;
  String? _selectedCabangId;
  final _svc = SupabaseGadaiService.instance;

  List<Cabang> _branches = [];
  List<PawnTransaction> _allTx = [];
  List<Customer> _allCustomers = [];
  List<Map<String, String>> _staffUsers = [];
  bool _isLoading = true;

  late TextEditingController _tariffCtrl;
  late TextEditingController _unitAmountCtrl;
  late TextEditingController _minTenorCtrl;
  late TextEditingController _maxTenorCtrl;
  late TextEditingController _alertDaysCtrl;

  @override
  void initState() {
    super.initState();
    _tariffCtrl = TextEditingController(text: SystemConfig.tariffPerUnit.toString());
    _unitAmountCtrl = TextEditingController(text: SystemConfig.unitAmount.toString());
    _minTenorCtrl = TextEditingController(text: SystemConfig.minTenor.toString());
    _maxTenorCtrl = TextEditingController(text: SystemConfig.maxTenor.toString());
    _alertDaysCtrl = TextEditingController(text: SystemConfig.alertDays.toString());
    _loadData();
  }

  @override
  void dispose() {
    _tariffCtrl.dispose();
    _unitAmountCtrl.dispose();
    _minTenorCtrl.dispose();
    _maxTenorCtrl.dispose();
    _alertDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final branches = await _svc.fetchBranches();
      final allTx = await _svc.fetchTransactions();
      final allCustomers = await _svc.fetchNasabah();
      final staffUsers = await _svc.fetchStaffUsers();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _allTx = allTx;
        _allCustomers = allCustomers;
        _staffUsers = staffUsers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

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
            onPressed: () async {
              Navigator.pop(ctx);
              await _svc.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RolePortalPage()), (route) => false);
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── BRANCH CRUD DIALOGS ──
  void _showBranchDialog({Cabang? branch}) {
    final isEdit = branch != null;
    final nameCtrl = TextEditingController(text: isEdit ? branch.nama : '');
    final codeCtrl = TextEditingController(text: isEdit ? branch.id : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Ubah Nama Cabang' : 'Tambah Cabang Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEdit)
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kode Cabang (ID)',
                  hintText: 'Contoh: jkt, bdg, sby',
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Cabang',
                hintText: 'Contoh: Galaxi Cell Jakarta',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final code = codeCtrl.text.trim().toLowerCase();
              if (name.isEmpty || code.isEmpty) return;

              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);

              try {
                if (isEdit) {
                  await _svc.updateBranch(branch.id, name);
                } else {
                  await _svc.createBranch(code, name);
                }
                navigator.pop();
                _loadData();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Cabang berhasil ${isEdit ? 'diperbarui' : 'ditambahkan'}'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteBranch(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Cabang'),
        content: const Text('Apakah Anda yakin ingin menghapus cabang ini dari database?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _svc.deleteBranch(id);
                navigator.pop();
                _loadData();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Cabang berhasil dihapus'), backgroundColor: Colors.green),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── ADMIN USER CRUD DIALOGS ──
  void _showUserDialog({Map<String, String>? user}) {
    final isEdit = user != null;
    final usernameCtrl = TextEditingController(text: isEdit ? user['username'] : '');
    final nameCtrl = TextEditingController(text: isEdit ? user['nama'] : '');
    final emailCtrl = TextEditingController(text: isEdit ? user['email'] : '');
    String selectedBranch = isEdit ? (user['cabang'] ?? '') : (_branches.isNotEmpty ? _branches.first.id : '');
    String selectedRole = isEdit ? (user['role'] ?? 'admin_cabang') : 'admin_cabang';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Ubah Akun Admin' : 'Tambah Admin Cabang'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  enabled: !isEdit,
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedBranch.isEmpty ? null : selectedBranch,
                  decoration: const InputDecoration(labelText: 'Penugasan Cabang'),
                  items: _branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.nama))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedBranch = val);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Peran'),
                  items: const [
                    DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                    DropdownMenuItem(value: 'admin_cabang', child: Text('Admin Cabang')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final username = usernameCtrl.text.trim();
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                if (username.isEmpty || name.isEmpty || email.isEmpty || selectedBranch.isEmpty) return;

                String dbRole = selectedRole == 'super_admin' ? 'superadmin' : 'admin';

                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  if (isEdit) {
                    await _svc.updateProfile(
                      id: user['id']!,
                      username: username,
                      fullName: name,
                      email: email,
                      role: dbRole,
                      branchId: selectedBranch,
                    );
                  } else {
                    final newId = 'ADMIN-${DateTime.now().millisecondsSinceEpoch}';
                    await _svc.createProfile(
                      id: newId,
                      username: username,
                      fullName: name,
                      email: email,
                      role: dbRole,
                      branchId: selectedBranch,
                    );
                  }
                  navigator.pop();
                  _loadData();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Akun Admin berhasil ${isEdit ? 'diperbarui' : 'dibuat'} (Mode Demo/Bypass)'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _deactivateUser(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Admin'),
        content: const Text('Apakah Anda yakin ingin menonaktifkan akun admin ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _svc.deactivateProfile(id);
                navigator.pop();
                _loadData();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Akun berhasil dinonaktifkan'), backgroundColor: Colors.green),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Nonaktifkan', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final tabs = ['Overview', 'Cabang', 'Admin Cabang', 'Konfigurasi'];
    final icons = [Icons.dashboard_rounded, Icons.store_mall_directory_outlined, Icons.manage_accounts_rounded, Icons.settings_outlined];

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      switch (_currentIndex) {
        case 0: body = _buildOverview(); break;
        case 1: body = _selectedCabangId != null ? _buildCabangDetail(_selectedCabangId!) : _buildCabangList(); break;
        case 2: body = _buildUserList(); break;
        case 3: body = _buildKonfigurasi(); break;
        default: body = _buildOverview();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Super Admin HQ', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Galaxi Gadai Pusat', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${_branches.length} Cabang Terdaftar', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                ]),
                GestureDetector(
                  onTap: _logout,
                  child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20)),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: Row(
              children: List.generate(tabs.length, (i) {
                final isSelected = _currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _currentIndex = i; if (i != 1) _selectedCabangId = null; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFFEF4444) : Colors.transparent, width: 2.5))),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icons[i], size: 18, color: isSelected ? const Color(0xFFEF4444) : AppColors.textMuted),
                        const SizedBox(height: 3),
                        Text(tabs[i], style: TextStyle(color: isSelected ? const Color(0xFFEF4444) : AppColors.textMuted, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                      ]),
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
    final totalAktif = _allTx.where((t) => t.status == 'Aktif').length;
    final totalMacet = _allTx.where((t) => t.status == 'Macet').length;
    final totalPinjaman = _allTx.where((t) => t.status == 'Aktif').fold(0, (s, t) => s + t.principal);
    final totalJasa = _allTx.where((t) => t.status == 'Aktif').fold(0, (s, t) => s + t.dailyFee);
    final totalLunas = _allTx.where((t) => t.status == 'Lunas').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _kpiCard('Total Cabang', '${_branches.length}', Icons.store_mall_directory_outlined, const Color(0xFF7C3AED))),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard('Transaksi Aktif', '$totalAktif', Icons.receipt_long_outlined, AppColors.primary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _kpiCard('Kasus Macet', '$totalMacet', Icons.warning_amber_rounded, const Color(0xFFEF4444))),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard('Total Nasabah', '${_allCustomers.length}', Icons.people_outline_rounded, const Color(0xFF10B981))),
          ]),
          const SizedBox(height: 20),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('💰 Total Pinjaman Beredar', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Text('Rp ${_formatCurrency(totalPinjaman)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white24)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Est. Pendapatan/Bulan', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  Text('Rp ${_formatCurrency(totalJasa * 30)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Total Transaksi', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  Text('${_allTx.length} TX ($totalLunas Lunas)', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ]),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('📊 Performa Cabang', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._branches.map((c) {
            final cTxs = _allTx.where((t) => t.cabangId == c.id).toList();
            final cAktif = cTxs.where((t) => t.status == 'Aktif').length;
            final cMacet = cTxs.where((t) => t.status == 'Macet').length;
            final cPendapatan = cTxs.where((t) => t.status == 'Aktif').fold(0, (s, t) => s + t.dailyFee) * 30;
            return GestureDetector(
              onTap: () => setState(() { _currentIndex = 1; _selectedCabangId = c.id; }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(children: [
                  Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle), child: const Icon(Icons.store_mall_directory_outlined, color: AppColors.primary, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.nama, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('$cAktif aktif • $cMacet macet', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Rp ${_formatCurrency(cPendapatan)}', style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildCabangList() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.separated(
          padding: const EdgeInsets.all(20), physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _branches.length, separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final c = _branches[i];
            final cTxs = _allTx.where((t) => t.cabangId == c.id).toList();
            final cAktif = cTxs.where((t) => t.status == 'Aktif').length;
            final cMacet = cTxs.where((t) => t.status == 'Macet').length;
            final cPendapatan = cTxs.where((t) => t.status == 'Aktif').fold(0, (s, t) => s + t.dailyFee) * 30;
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDBEAFE))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCabangId = c.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.nama, style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('ID Cabang: ${c.id}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                          onPressed: () => _showBranchDialog(branch: c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteBranch(c.id),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _miniStat('Aktif', '$cAktif', AppColors.primary)),
                  Expanded(child: _miniStat('Macet', '$cMacet', const Color(0xFFEF4444))),
                  Expanded(child: _miniStat('Pendapatan/bln', 'Rp ${_formatCurrency(cPendapatan)}', const Color(0xFF10B981))),
                ]),
              ]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBranchDialog(),
        backgroundColor: const Color(0xFFEF4444),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCabangDetail(String cabangId) {
    final cabang = _branches.firstWhere((c) => c.id == cabangId, orElse: () => Cabang(id: cabangId, nama: cabangId, kode: cabangId, admin: ''));
    final cTxs = _allTx.where((t) => t.cabangId == cabangId).toList();
    final cCustomers = _allCustomers.where((c) => c.cabangId == cabangId).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        Container(
          color: const Color(0xFFFEF2F2), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            GestureDetector(onTap: () => setState(() => _selectedCabangId = null), child: const Icon(Icons.arrow_back_rounded, color: Color(0xFFEF4444), size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(cabang.nama, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14, fontWeight: FontWeight.bold))),
            Text('${cTxs.length} TX • ${cCustomers.length} Nasabah', style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12)),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20), physics: const AlwaysScrollableScrollPhysics(),
            itemCount: cTxs.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final tx = cTxs[i];
              final c = _allCustomers.firstWhere((c) => c.id == tx.customerId, orElse: () => Customer(id: '', name: 'Unknown', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: ''));
              Color statusColor = AppColors.primary;
              if (tx.status == 'Macet') { statusColor = const Color(0xFFEF4444); }
              else if (tx.status == 'Lunas') { statusColor = const Color(0xFF10B981); }
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransaksiDetailPage(transaction: tx))).then((_) => _loadData()),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.receipt_long_outlined, color: statusColor, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('${tx.brand} ${tx.model}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Rp ${_formatCurrency(tx.principal)}', style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(tx.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => NewPawnPage(branchId: cabangId))).then((_) => _loadData());
        },
        backgroundColor: const Color(0xFFEF4444),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildUserList() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.separated(
          padding: const EdgeInsets.all(20), physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _staffUsers.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final u = _staffUsers[i];
            final isAdmin = u['role'] == 'admin_cabang';
            final roleLabel = isAdmin ? 'Admin Cabang' : 'Super Admin';
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: isAdmin ? const Color(0xFFFFF7ED) : const Color(0xFFFEF2F2), shape: BoxShape.circle),
                  child: Icon(isAdmin ? Icons.manage_accounts_rounded : Icons.admin_panel_settings_rounded, color: isAdmin ? const Color(0xFFF59E0B) : const Color(0xFFEF4444), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u['nama']!, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(u['email']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Text('Cabang: ${u['cabang']!}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ])),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: isAdmin ? const Color(0xFFFFF7ED) : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                      child: Text(roleLabel, style: TextStyle(color: isAdmin ? const Color(0xFFF59E0B) : const Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 16),
                          onPressed: () => _showUserDialog(user: u),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.lock_person_outlined, color: Colors.redAccent, size: 16),
                          onPressed: () => _deactivateUser(u['id']!),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    )
                  ],
                ),
              ]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        backgroundColor: const Color(0xFFEF4444),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildKonfigurasi() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚙️ Konfigurasi Tarif & Aturan Gadai', style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Parameter Jasa Titip Harian', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _tariffCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tarif Jasa per Unit (Rp)', border: OutlineInputBorder(), hintText: 'Contoh: 5000'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _unitAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nominal Unit Kelipatan (Rp)', border: OutlineInputBorder(), hintText: 'Contoh: 500000'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _minTenorCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tenor Minimum (Hari)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _maxTenorCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tenor Maksimum (Hari)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _alertDaysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Notifikasi Jatuh Tempo (H- Hari)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        SystemConfig.tariffPerUnit = int.tryParse(_tariffCtrl.text) ?? SystemConfig.tariffPerUnit;
                        SystemConfig.unitAmount = int.tryParse(_unitAmountCtrl.text) ?? SystemConfig.unitAmount;
                        SystemConfig.minTenor = int.tryParse(_minTenorCtrl.text) ?? SystemConfig.minTenor;
                        SystemConfig.maxTenor = int.tryParse(_maxTenorCtrl.text) ?? SystemConfig.maxTenor;
                        SystemConfig.alertDays = int.tryParse(_alertDaysCtrl.text) ?? SystemConfig.alertDays;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Konfigurasi sistem berhasil diperbarui secara global!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan Konfigurasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ]);
  }
}
