import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/services/fcm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:galaxi_gadai/features/auth/presentation/pages/role_portal_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/transaksi_detail_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/new_pawn_page.dart';
import 'package:galaxi_gadai/core/config/system_config.dart';
import 'package:galaxi_gadai/features/dashboard/presentation/widgets/laporan_tab_content.dart';
import 'package:galaxi_gadai/features/admin_cabang/presentation/pages/lelang_page.dart';
import 'package:galaxi_gadai/features/admin_cabang/presentation/pages/barang_terjual_page.dart';
import 'package:galaxi_gadai/features/admin_cabang/presentation/pages/kas_page.dart';

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
  List<Customer> _allNasabah = [];
  List<Map<String, String>> _staffUsers = [];
  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoading = true;
  Timer? _logTimer;
  String? _lastLogId;

  // ── Tahap 1: Filter & Search ──
  final TextEditingController _mainSearchCtrl = TextEditingController();
  final TextEditingController _searchNasabahCtrl = TextEditingController();
  final TextEditingController _searchTxCtrl = TextEditingController();
  String _searchNasabah = '';
  String _searchTx = '';
  String _filterTxStatus = 'Semua'; // Semua / Aktif / Macet / Lunas
  String _filterAdminSearch = '';
  final TextEditingController _searchAdminCtrl = TextEditingController();

  // ── Tahap 5: Kas ──
  List<Map<String, dynamic>> _kasEntries = [];
  Map<String, int> _kasSaldo = {};
  Map<String, int> _walletBalances = {}; // Saldo Rekening Gadai per cabang
  String _filterKasCabang = ''; // '' = semua cabang

  // ── Rekening Pembayaran ──
  List<RekeningGadai> _adminRekeningList = [];
  String _filterRekeningCabang = 'all';

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
    _initFcm();
    _loadData().then((_) {
      if (_activityLogs.isNotEmpty) {
        _lastLogId = _activityLogs.first['id']?.toString();
      }
      _startLogPolling();
    });
  }

  Future<void> _initFcm() async {
    await FcmService.instance.initialize();
    await FcmService.instance.requestPermission();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await FcmService.instance.saveStaffFcmToken(userId);
    }
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _tariffCtrl.dispose();
    _unitAmountCtrl.dispose();
    _minTenorCtrl.dispose();
    _maxTenorCtrl.dispose();
    _alertDaysCtrl.dispose();
    _mainSearchCtrl.dispose();
    _searchNasabahCtrl.dispose();
    _searchTxCtrl.dispose();
    _searchAdminCtrl.dispose();
    super.dispose();
  }

  void _startLogPolling() {
    _logTimer?.cancel();
    _logTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final latest = await _svc.fetchActivityLogs(limit: 1);
        if (latest.isNotEmpty) {
          final newest = latest.first;
          final newestId = newest['id']?.toString();
          if (_lastLogId != null && newestId != _lastLogId) {
            _lastLogId = newestId;
            if (mounted) {
              _showNewLogNotification(newest);
              _refreshLogsOnly();
            }
          } else if (_lastLogId == null) {
            _lastLogId = newestId;
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _refreshLogsOnly() async {
    try {
      final logs = await _svc.fetchActivityLogs(limit: 300);
      if (mounted) {
        setState(() {
          _activityLogs = logs;
        });
      }
    } catch (_) {}
  }

  void _showNewLogNotification(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '-';
    final description = log['description'] as String? ?? '';
    final color = _actionColor(action);
    final icon = _actionIcon(action);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktivitas Baru: $action',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'LIHAT',
          textColor: color,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _showLogDetailDialog(context, log);
          },
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Mapping action → warna & icon
  Color _actionColor(String action) {
    switch (action) {
      case 'LOGIN_SUCCESS': return const Color(0xFF10B981);
      case 'LOGIN_FAILED': return const Color(0xFFEF4444);
      case 'LOGOUT': return const Color(0xFF64748B);
      case 'REGISTER': return const Color(0xFF3B82F6);
      case 'CHANGE_PASSWORD':
      case 'ADMIN_RESET_PASSWORD': return const Color(0xFFF59E0B);
      case 'UPDATE_PROFILE': return const Color(0xFF8B5CF6);
      case 'ADMIN_CREATE_NASABAH': return const Color(0xFF0F5A47);
      case 'ADMIN_UPDATE_NASABAH': return const Color(0xFF6366F1);
      case 'TRANSAKSI_CREATED': return const Color(0xFF1D4ED8);
      case 'EXTENSION_REQUESTED': return const Color(0xFFDB2777);
      case 'TRANSAKSI_REDEEMED': return const Color(0xFF047857);
      default: return const Color(0xFF94A3B8);
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'LOGIN_SUCCESS': return Icons.login_rounded;
      case 'LOGIN_FAILED': return Icons.block_rounded;
      case 'LOGOUT': return Icons.logout_rounded;
      case 'REGISTER': return Icons.person_add_rounded;
      case 'CHANGE_PASSWORD':
      case 'ADMIN_RESET_PASSWORD': return Icons.lock_reset_rounded;
      case 'UPDATE_PROFILE': return Icons.edit_rounded;
      case 'ADMIN_CREATE_NASABAH': return Icons.person_add_alt_1_rounded;
      case 'ADMIN_UPDATE_NASABAH': return Icons.manage_accounts_rounded;
      case 'TRANSAKSI_CREATED': return Icons.receipt_long_rounded;
      case 'EXTENSION_REQUESTED': return Icons.autorenew_rounded;
      case 'TRANSAKSI_REDEEMED': return Icons.redeem_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  String _formatLogTime(String? isoString) {
    if (isoString == null) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
      return '${dt.day.toString().padLeft(2,'0')} ${months[dt.month-1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return isoString;
    }
  }

  void _handleMainSearch() {
    final query = _mainSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return;

    final matchingBranch = _branches.where((b) => b.nama.toLowerCase().contains(query)).toList();
    final matchingNasabah = _allNasabah.where((n) => n.name.toLowerCase().contains(query)).toList();
    final matchingAdmin = _staffUsers.where((u) => (u['nama'] ?? '').toLowerCase().contains(query)).toList();

    if (matchingBranch.isNotEmpty) {
      setState(() {
        _currentIndex = 1;
        _filterTxStatus = 'Semua';
        _searchTx = '';
        _selectedCabangId = matchingBranch.first.id;
      });
    } else if (matchingAdmin.isNotEmpty) {
      setState(() {
        _currentIndex = 2;
        _filterAdminSearch = query;
        _searchAdminCtrl.text = query;
      });
    } else if (matchingNasabah.isNotEmpty) {
      setState(() {
        _currentIndex = 3;
        _searchNasabah = query;
        _searchNasabahCtrl.text = query;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasil tidak ditemukan. Coba ketik nama cabang, admin, atau nasabah.')),
      );
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'nasabah': return const Color(0xFF0F5A47);
      case 'admin': return const Color(0xFFEF4444);
      case 'super_admin': return const Color(0xFF7F1D1D);
      default: return const Color(0xFF64748B);
    }
  }

  String _getPriority(String action) {
    switch (action) {
      case 'TRANSAKSI_CREATED':
      case 'TRANSAKSI_REDEEMED':
      case 'EXTENSION_REQUESTED':
      case 'LOGIN_FAILED':
      case 'CHANGE_PASSWORD':
      case 'ADMIN_RESET_PASSWORD':
        return 'TINGGI';
      case 'UPDATE_PROFILE':
      case 'ADMIN_UPDATE_NASABAH':
      case 'ADMIN_CREATE_NASABAH':
      case 'REGISTER':
        return 'SEDANG';
      default:
        return 'RENDAH';
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'TINGGI': return const Color(0xFFEF4444);
      case 'SEDANG': return const Color(0xFFF59E0B);
      default: return const Color(0xFF10B981);
    }
  }

  void _showLogDetailDialog(BuildContext context, Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '-';
    final role = log['role'] as String? ?? 'nasabah';
    final description = log['description'] as String? ?? '';
    final createdAt = log['created_at'] as String?;
    final userId = log['user_id'] as String? ?? '-';
    final ipAddress = log['ip_address'] as String? ?? '-';
    final metadata = log['metadata'];
    final color = _actionColor(action);
    final icon = _actionIcon(action);
    final prio = _getPriority(action);
    final prioCol = _priorityColor(prio);

    String formattedMetadata = '';
    if (metadata != null) {
      try {
        formattedMetadata = const JsonEncoder.withIndent('  ').convert(metadata);
      } catch (_) {
        formattedMetadata = metadata.toString();
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action,
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _roleColor(role).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(color: _roleColor(role), fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: prioCol.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: prioCol.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 4, height: 4,
                                    decoration: BoxDecoration(color: prioCol, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PRIORITAS $prio',
                                    style: TextStyle(color: prioCol, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('KETERANGAN', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: AppColors.textDark, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('USER ID / ACTOR', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(userId, style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('IP ADDRESS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(ipAddress, style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('WAKTU AKTIVITAS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(_formatLogTime(createdAt), style: const TextStyle(color: AppColors.textDark, fontSize: 12)),
                  if (formattedMetadata.isNotEmpty && formattedMetadata != '{}') ...[
                    const SizedBox(height: 16),
                    const Text('METADATA (JSON)', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          formattedMetadata,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontFamily: 'Courier',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final branches = await _svc.fetchBranches();
      final allTx = await _svc.fetchTransactions();
      final allNasabah = await _svc.fetchNasabah();
      final staffUsers = await _svc.fetchStaffUsers();
      final activityLogs = await _svc.fetchActivityLogs(limit: 300);
      final kasEntries = await _svc.fetchKas();
      final kasSaldo = await _svc.fetchKasSaldo();
      final adminRekening = await _svc.fetchAllRekeningGadaiAdmin();
      // Fetch wallet (Saldo Rekening Gadai) per cabang secara paralel
      final walletFutures = branches.map((b) => _svc.fetchWalletBalance(b.id));
      final walletResults = await Future.wait(walletFutures);
      final walletBalances = <String, int>{};
      for (int i = 0; i < branches.length; i++) {
        walletBalances[branches[i].id] = walletResults[i];
      }

      // Load config dari Supabase dan update SystemConfig
      final config = await _svc.fetchSystemConfig();
      if (config.isNotEmpty) {
        SystemConfig.tariffPerUnit = int.tryParse(config['tariff_per_unit']?.toString() ?? '') ?? SystemConfig.tariffPerUnit;
        SystemConfig.unitAmount = int.tryParse(config['unit_amount']?.toString() ?? '') ?? SystemConfig.unitAmount;
        SystemConfig.minTenor = int.tryParse(config['min_tenor']?.toString() ?? '') ?? SystemConfig.minTenor;
        SystemConfig.maxTenor = int.tryParse(config['max_tenor']?.toString() ?? '') ?? SystemConfig.maxTenor;
        SystemConfig.alertDays = int.tryParse(config['alert_days']?.toString() ?? '') ?? SystemConfig.alertDays;
      }

      // Auto-mark transaksi overdue
      await _svc.markOverdueTransactions();

      if (!mounted) return;
      setState(() {
        _branches = branches;
        _allTx = allTx;
        _allCustomers = allNasabah;
        _allNasabah = allNasabah;
        _staffUsers = staffUsers;
        _activityLogs = activityLogs;
        _kasEntries = kasEntries;
        _kasSaldo = kasSaldo;
        _walletBalances = walletBalances;
        _adminRekeningList = adminRekening;
        // Sync controllers dengan nilai terbaru dari Supabase
        _tariffCtrl.text = SystemConfig.tariffPerUnit.toString();
        _unitAmountCtrl.text = SystemConfig.unitAmount.toString();
        _minTenorCtrl.text = SystemConfig.minTenor.toString();
        _maxTenorCtrl.text = SystemConfig.maxTenor.toString();
        _alertDaysCtrl.text = SystemConfig.alertDays.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Refresh hanya saldo wallet tanpa mengubah loading state / navigasi
  Future<void> _refreshWalletBalances() async {
    if (_branches.isEmpty) return;
    try {
      final walletFutures = _branches.map((b) => _svc.fetchWalletBalance(b.id));
      final walletResults = await Future.wait(walletFutures);
      if (!mounted) return;
      final newBalances = <String, int>{};
      for (int i = 0; i < _branches.length; i++) {
        newBalances[_branches[i].id] = walletResults[i];
      }
      setState(() => _walletBalances = newBalances);
    } catch (_) {}
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

  // ── NAVIGATE TO BRANCH PAGE (LELANG / TERJUAL) ──
  void _navigateToBranchPage(String type) {
    if (_branches.isEmpty) return;

    if (_branches.length == 1) {
      final b = _branches.first;
      if (type == 'lelang') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LelangPage(branchId: b.id)));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => BarangTerjualPage(branchId: b.id)));
      }
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(type == 'lelang' ? Icons.gavel_rounded : Icons.trending_up_rounded,
              color: AppColors.royalBlue, size: 22),
          const SizedBox(width: 8),
          Text(type == 'lelang' ? 'Pilih Cabang - Lelang' : 'Pilih Cabang - Barang Terjual',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _branches.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final b = _branches[i];
              return ListTile(
                title: Text(b.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(b.id),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  if (type == 'lelang') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LelangPage(branchId: b.id)));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BarangTerjualPage(branchId: b.id)));
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
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
                      content: Text('Akun Admin berhasil ${isEdit ? 'diperbarui' : 'dibuat'}'),
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

  // ── NASABAH CRUD DIALOGS ──
  void _showNasabahDialog({Customer? nasabah}) {
    final isEdit = nasabah != null;
    final nameCtrl = TextEditingController(text: isEdit ? nasabah.name : '');
    final phoneCtrl = TextEditingController(text: isEdit ? nasabah.phone : '');
    final nikCtrl = TextEditingController(text: isEdit ? nasabah.nik : '');
    final addressCtrl = TextEditingController(text: isEdit && nasabah.address != '-' ? nasabah.address : '');
    final passwordCtrl = TextEditingController();
    String selectedBranch = _branches.isNotEmpty ? _branches.first.id : '';
    String selectedGender = isEdit && nasabah.gender.isNotEmpty && nasabah.gender != '-' ? nasabah.gender : 'Laki-laki';
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Edit Data Nasabah' : 'Buat Akun Nasabah Baru'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogTextField(nameCtrl, 'Nama Lengkap', Icons.badge_outlined,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null),
                  const SizedBox(height: 10),
                  _dialogTextField(phoneCtrl, 'Nomor HP (untuk login)', Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'HP wajib diisi';
                        if (!RegExp(r'^08[0-9]{8,11}$').hasMatch(v.trim())) return 'Format HP tidak valid';
                        return null;
                      }),
                  const SizedBox(height: 10),
                  _dialogTextField(nikCtrl, 'NIK (16 digit)', Icons.credit_card_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'NIK wajib diisi';
                        if (v.trim().length != 16) return 'NIK harus 16 digit';
                        return null;
                      }),
                  const SizedBox(height: 10),
                  _dialogTextField(addressCtrl, 'Alamat', Icons.home_outlined, maxLines: 2),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGender,
                    decoration: const InputDecoration(labelText: 'Jenis Kelamin', border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                      DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedGender = val ?? selectedGender),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranch.isEmpty ? null : selectedBranch,
                    decoration: const InputDecoration(labelText: 'Cabang', border: OutlineInputBorder(), isDense: true),
                    items: _branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.nama))).toList(),
                    onChanged: (val) => setDialogState(() => selectedBranch = val ?? selectedBranch),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 10),
                    _dialogTextField(passwordCtrl, 'Password Awal', Icons.lock_outline_rounded,
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password wajib diisi';
                          if (v.length < 6) return 'Minimal 6 karakter';
                          return null;
                        }),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Color(0xFF0F5A47)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Password ini akan diberikan ke nasabah untuk login pertama kali.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF0F5A47)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => saving = true);

                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  if (isEdit) {
                    await _svc.updateNasabah(
                      id: nasabah.id,
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty ? '-' : addressCtrl.text.trim(),
                      gender: selectedGender,
                      nik: nikCtrl.text.trim(),
                    );
                    // Log aktivitas
                    unawaited(_svc.logAdminUpdateNasabah(
                      'super_admin',
                      nameCtrl.text.trim(),
                      phoneCtrl.text.trim(),
                    ));
                    navigator.pop();
                    _loadData();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Data nasabah berhasil diperbarui'), backgroundColor: Colors.green),
                    );
                  } else {
                    // Buat profil nasabah
                    final newNasabah = Customer(
                      id: '',
                      name: nameCtrl.text.trim(),
                      nik: nikCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty ? '-' : addressCtrl.text.trim(),
                      gender: selectedGender,
                      birthPlace: '-',
                      birthDate: '-',
                      cabangId: selectedBranch,
                    );
                    final created = await _svc.createNasabah(newNasabah);
                    // Buat akun login
                    await _svc.registerNasabahAccount(
                      phoneCtrl.text.trim(),
                      passwordCtrl.text,
                      created.id,
                    );
                    // Log aktivitas
                    unawaited(_svc.logAdminCreateNasabah(
                      'super_admin',
                      nameCtrl.text.trim(),
                      phoneCtrl.text.trim(),
                    ));
                    navigator.pop();
                    _loadData();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Akun nasabah ${nameCtrl.text.trim()} berhasil dibuat!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => saving = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Gagal: ${e.toString().contains('unique') ? 'Nomor HP sudah terdaftar' : e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5A47)),
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Simpan' : 'Buat Akun', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _resetNasabahPassword(Customer nasabah) {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Password Nasabah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nasabah: ${nasabah.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('HP: ${nasabah.phone}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'Password Baru',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (passwordCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password minimal 6 karakter'), backgroundColor: Colors.red),
                );
                return;
              }
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                // Force reset: update password dengan hash baru
                await _svc.adminResetNasabahPassword(
                  phone: nasabah.phone,
                  newPassword: passwordCtrl.text,
                );
                // Log aktivitas
                unawaited(_svc.logAdminResetPassword('super_admin', nasabah.phone));
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Password berhasil direset!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal reset: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Reset Password', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _dialogTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: validator,
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


    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.royalBlue));
    } else {
      switch (_currentIndex) {
        case 0: body = _buildOverview(); break;
        case 1: body = _selectedCabangId != null ? _buildCabangDetail(_selectedCabangId!) : _buildCabangList(); break;
        case 2: body = _buildUserList(); break;
        case 3: body = _buildNasabahList(); break;
        case 4: body = _buildKas(); break;
        case 5: body = _buildKonfigurasi(); break;
        case 6: body = _buildActivityLog(); break;
        case 7: body = const LaporanTabContent(branchId: 'all'); break;
        default: body = _buildOverview();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedCabangId != null) {
          setState(() => _selectedCabangId = null);
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // ── Navy Premium Header ──
          Container(
            padding: EdgeInsets.only(top: statusBarHeight + 16, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A1628), Color(0xFF102A4C), Color(0xFF1E3A6E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Dot motif overlay
                Positioned.fill(
                  child: CustomPaint(painter: _HeaderDotPainter()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (_currentIndex != 0 || _selectedCabangId != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_selectedCabangId != null) {
                                  _selectedCabangId = null;
                                } else {
                                  _currentIndex = 0;
                                }
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(children: [
                                const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF93C5FD), size: 12),
                                const SizedBox(width: 5),
                                Text('Super Admin HQ',
                                  style: GoogleFonts.inter(color: const Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text('Galaxi Gadai Pusat',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Text('${_branches.length} Cabang Terdaftar',
                            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w400)),
                        ]),
                      ],
                    ),
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(child: body),
        ],
      ),
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
      color: AppColors.royalBlue,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── 1. Search Bar Panel (Sama seperti Admin Cabang) ──
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A1628).withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _mainSearchCtrl,
                    style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari nama cabang, admin, atau nasabah...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _handleMainSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: Text('Cari', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 2. Grouped Grid Menu (Seperti Admin Cabang dengan Motif) ──
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: AppColors.royalBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Manajemen Galaxi',
                style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: [
              _buildGridItem('Cabang', Icons.store_mall_directory_outlined, () {
                setState(() => _currentIndex = 1);
              }),
              _buildGridItem('Admin', Icons.manage_accounts_rounded, () {
                setState(() => _currentIndex = 2);
              }),
              _buildGridItem('Nasabah', Icons.people_rounded, () {
                setState(() => _currentIndex = 3);
              }),
              _buildGridItem('Laporan', Icons.assessment_rounded, () {
                setState(() => _currentIndex = 7);
              }),
              _buildGridItem('Uang Kas', Icons.account_balance_wallet_rounded, () {
                setState(() => _currentIndex = 4);
              }),
              _buildGridItem('Config', Icons.settings_outlined, () {
                setState(() => _currentIndex = 5);
              }),
              _buildGridItem('Log', Icons.history_rounded, () {
                setState(() => _currentIndex = 6);
              }),
              _buildGridItem('Lelang', Icons.gavel_rounded, () {
                _navigateToBranchPage('lelang');
              }),
              _buildGridItem('Terjual', Icons.trending_up_rounded, () {
                _navigateToBranchPage('terjual');
              }),
            ],
          ),
          const SizedBox(height: 24),

          // ── 3. KPI Cards ──
          Row(children: [
            Expanded(child: _kpiCard('Total Cabang', '${_branches.length}', Icons.store_mall_directory_outlined, AppColors.violet)),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard('Transaksi Aktif', '$totalAktif', Icons.receipt_long_outlined, AppColors.royalBlue)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _kpiCard('Kasus Macet', '$totalMacet', Icons.warning_amber_rounded, AppColors.coral)),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard('Total Nasabah', '${_allCustomers.length}', Icons.people_outline_rounded, AppColors.emerald)),
          ]),
          const SizedBox(height: 20),

          // ── 4. Financial Summary Card (Blue Premium with Motif) ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A6E), AppColors.royalBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.royalBlue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(painter: _HeaderDotPainter()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text('Total Pinjaman Beredar',
                        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                    const SizedBox(height: 12),
                    Text('Rp ${_formatCurrency(totalPinjaman)}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Est. Pendapatan/Bulan',
                          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 3),
                        Text('Rp ${_formatCurrency(totalJasa * 30)}',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Total Transaksi',
                          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 3),
                        Text('${_allTx.length} TX ($totalLunas Lunas)',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ]),
                    ]),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 5. Branch Performance ──
          Row(children: [
            const Icon(Icons.bar_chart_rounded, color: AppColors.royalBlue, size: 20),
            const SizedBox(width: 8),
            Text('Performa Cabang',
              style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          ..._branches.map((c) {
            final cTxs = _allTx.where((t) => t.cabangId == c.id).toList();
            final cAktif = cTxs.where((t) => t.status == 'Aktif').length;
            final cMacet = cTxs.where((t) => t.status == 'Macet').length;
            return GestureDetector(
              onTap: () => setState(() { _currentIndex = 1; _selectedCabangId = c.id; }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A1628).withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.iceBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store_mall_directory_outlined, color: AppColors.royalBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.nama,
                      style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(children: [
                      _statusBadge('$cAktif aktif', AppColors.royalBlue),
                      const SizedBox(width: 6),
                      if (cMacet > 0) _statusBadge('$cMacet macet', AppColors.coral),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 11, color: Color(0xFF2563EB)),
                      const SizedBox(width: 3),
                      Text('Saldo Kas: Rp ${_formatCurrency(_walletBalances[c.id] ?? 0)}',
                        style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
                ]),
              ),
            );
          }),
          const SizedBox(height: 24),

          // ── Tahap 2: Panel Jatuh Tempo ──
          Builder(builder: (_) {
            final now = DateTime.now();
            final alertDays = SystemConfig.alertDays;
            final nearDue = _allTx.where((tx) {
              if (tx.status != 'Aktif') return false;
              final diff = tx.dateDue.difference(now).inDays;
              return diff >= 0 && diff <= alertDays;
            }).toList()
              ..sort((a, b) => a.dateDue.compareTo(b.dateDue));

            if (nearDue.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 16),
                ),
                const SizedBox(width: 8),
                Text('Segera Jatuh Tempo (${nearDue.length})',
                  style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('dalam $alertDays hari ke depan',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
              const SizedBox(height: 10),
              ...nearDue.map((tx) {
                final cust = _allCustomers.firstWhere((c) => c.id == tx.customerId,
                  orElse: () => Customer(id: '', name: 'Unknown', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: ''));
                int daysLeft = tx.dateDue.difference(DateTime.now()).inDays;
                final isUrgent = daysLeft <= 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUrgent ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isUrgent ? AppColors.coral.withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isUrgent ? AppColors.coral : const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(daysLeft == 0 ? 'Hari ini' : '${daysLeft}H',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cust.name, style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${tx.brand} ${tx.model}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Rp ${_formatCurrency(tx.principal)}',
                        style: const TextStyle(color: AppColors.textDark, fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('Jatuh tempo: ${tx.dateDue.toLocal().toString().split(' ').first}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ]),
                  ]),
                );
              }),
              const SizedBox(height: 24),
            ]);
          }),

          // ── Tahap 3: Panel Macet ──
          Builder(builder: (_) {
            final macetTx = _allTx.where((tx) => tx.status == 'Macet').toList();
            if (macetTx.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.coral, size: 16),
                ),
                const SizedBox(width: 8),
                Text('Gadai Macet (${macetTx.length})',
                  style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              ...macetTx.take(5).map((tx) {
                final cust = _allCustomers.firstWhere((c) => c.id == tx.customerId,
                  orElse: () => Customer(id: '', name: 'Unknown', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: ''));
                final cabang = _branches.firstWhere((b) => b.id == tx.cabangId,
                  orElse: () => Cabang(id: '', nama: tx.cabangId, kode: '', admin: ''));
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransaksiDetailPage(transaction: tx))).then((_) => _loadData()),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
                      boxShadow: [BoxShadow(color: AppColors.coral.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.warning_amber_rounded, color: AppColors.coral, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cust.name, style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${tx.brand} ${tx.model} • ${cabang.nama}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Rp ${_formatCurrency(tx.principal)}',
                          style: const TextStyle(color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.w700)),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 16),
                      ]),
                    ]),
                  ),
                );
              }),
              if (macetTx.length > 5)
                GestureDetector(
                  onTap: () => setState(() { _currentIndex = 1; }),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.coral.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Text('Lihat ${macetTx.length - 5} lainnya →',
                        style: const TextStyle(color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _buildGridItem(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A1628).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CustomPaint(painter: _HeaderDotPainter(color: AppColors.royalBlue, opacity: 0.04)),
                  ),
                ),
                Center(
                  child: Icon(icon, color: AppColors.royalBlue, size: 26),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
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
        backgroundColor: AppColors.royalBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCabangDetail(String cabangId) {
    final cabang = _branches.firstWhere((c) => c.id == cabangId, orElse: () => Cabang(id: cabangId, nama: cabangId, kode: cabangId, admin: ''));
    var cTxs = _allTx.where((t) => t.cabangId == cabangId).toList();

    // Filter by status
    final filteredTxs = cTxs.where((tx) {
      final matchStatus = _filterTxStatus == 'Semua' || tx.status == _filterTxStatus;
      final query = _searchTx.toLowerCase();
      if (query.isEmpty) return matchStatus;
      final cust = _allCustomers.firstWhere((c) => c.id == tx.customerId,
          orElse: () => Customer(id: '', name: '', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: ''));
      final matchSearch = cust.name.toLowerCase().contains(query) ||
          tx.brand.toLowerCase().contains(query) ||
          tx.model.toLowerCase().contains(query);
      return matchStatus && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        // Header
        Container(
          color: const Color(0xFFF0F4FF),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => setState(() { _selectedCabangId = null; _searchTx = ''; _searchTxCtrl.clear(); _filterTxStatus = 'Semua'; }),
                child: const Icon(Icons.arrow_back_rounded, color: AppColors.royalBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(cabang.nama, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold))),
              Text('${filteredTxs.length}/${cTxs.length} TX', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            // Search bar
            TextField(
              controller: _searchTxCtrl,
              onChanged: (v) => setState(() => _searchTx = v),
              decoration: InputDecoration(
                hintText: 'Cari nasabah, merek, model...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: _searchTx.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() { _searchTx = ''; _searchTxCtrl.clear(); }),
                        child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 8),
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', 'Aktif', 'Menunggu Pengambilan', 'Sudah Diambil', 'Lunas', 'Macet', 'Lelang', 'Terjual'].map((s) {
                  final active = _filterTxStatus == s;
                  Color chipColor;
                  switch (s) {
                    case 'Aktif': chipColor = AppColors.royalBlue; break;
                    case 'Menunggu Pengambilan': chipColor = const Color(0xFF059669); break;
                    case 'Sudah Diambil': chipColor = const Color(0xFF0D9488); break;
                    case 'Lunas': chipColor = AppColors.emerald; break;
                    case 'Macet': chipColor = AppColors.coral; break;
                    case 'Lelang': chipColor = const Color(0xFF8B5CF6); break;
                    case 'Terjual': chipColor = const Color(0xFFD97706); break;
                    default: chipColor = AppColors.textMuted;
                  }
                  return GestureDetector(
                    onTap: () => setState(() => _filterTxStatus = s),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? chipColor : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? chipColor : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(s,
                        style: TextStyle(color: active ? Colors.white : AppColors.textMuted,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // ── Saldo Mini Stats ──
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => KasPage(branchId: cabangId, namaCabang: cabang.nama)),
                  ).then((_) => _refreshWalletBalances()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2563EB), size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Saldo Kas', style: GoogleFonts.inter(color: const Color(0xFF2563EB), fontSize: 9, fontWeight: FontWeight.w600)),
                        Text('Rp ${_formatCurrency(_walletBalances[cabangId] ?? 0)}',
                          style: GoogleFonts.inter(color: const Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.w800)),
                      ])),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB), size: 12),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
          ]),
        ),
        // List
        Expanded(
          child: filteredTxs.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text(_searchTx.isNotEmpty || _filterTxStatus != 'Semua'
                    ? 'Tidak ada hasil yang cocok'
                    : 'Belum ada transaksi',
                    style: const TextStyle(color: AppColors.textMuted)),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filteredTxs.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final tx = filteredTxs[i];
                  final c = _allCustomers.firstWhere((c) => c.id == tx.customerId, orElse: () => Customer(id: '', name: 'Unknown', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: ''));
                  Color statusColor = AppColors.primary;
                  if (tx.status == 'Macet') { statusColor = AppColors.coral; }
                  else if (tx.status == 'Lunas') { statusColor = AppColors.emerald; }
                  else if (tx.status == 'Lelang' || tx.status == 'Terjual') { statusColor = const Color(0xFF8B5CF6); }
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransaksiDetailPage(transaction: tx))).then((_) => _loadData()),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                        boxShadow: [BoxShadow(color: const Color(0xFF0A1628).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        Container(width: 40, height: 40,
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.receipt_long_outlined, color: statusColor, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.name, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('${tx.brand} ${tx.model}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Rp ${_formatCurrency(tx.principal)}',
                            style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
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
        backgroundColor: AppColors.royalBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildUserList() {
    final filtered = _staffUsers.where((u) {
      final q = _filterAdminSearch.toLowerCase();
      if (q.isEmpty) return true;
      return (u['nama'] ?? '').toLowerCase().contains(q) ||
             (u['email'] ?? '').toLowerCase().contains(q) ||
             (u['cabang'] ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchAdminCtrl,
            onChanged: (v) => setState(() => _filterAdminSearch = v),
            decoration: InputDecoration(
              hintText: 'Cari nama, email, atau cabang...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
              suffixIcon: _filterAdminSearch.isNotEmpty
                  ? GestureDetector(
                      onTap: () => setState(() { _filterAdminSearch = ''; _searchAdminCtrl.clear(); }),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: filtered.isEmpty
              ? const Center(child: Text('Tidak ada admin ditemukan.', style: TextStyle(color: AppColors.textMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final u = filtered[i];
                    final isAdmin = u['role'] == 'admin_cabang';
                    final roleLabel = isAdmin ? 'Admin Cabang' : 'Super Admin';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [BoxShadow(color: const Color(0xFF0A1628).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(isAdmin ? Icons.manage_accounts_rounded : Icons.admin_panel_settings_rounded,
                            color: isAdmin ? AppColors.royalBlue : AppColors.coral, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u['nama']!, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(u['email']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text('🏢 ${u['cabang']!}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ])),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(roleLabel,
                                style: TextStyle(color: isAdmin ? AppColors.royalBlue : AppColors.coral,
                                    fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit
                                _adminActionBtn(Icons.edit_outlined, Colors.blueAccent,
                                    () => _showUserDialog(user: u)),
                                const SizedBox(width: 2),
                                // Reset Password
                                _adminActionBtn(Icons.lock_reset_rounded, Colors.orange,
                                    () => _showAdminResetPasswordDialog(u)),
                                const SizedBox(width: 2),
                                // Nonaktifkan
                                _adminActionBtn(Icons.block_rounded, AppColors.coral,
                                    () => _deactivateUser(u['id']!)),
                              ],
                            )
                          ],
                        ),
                      ]),
                    );
                  },
                ),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        backgroundColor: AppColors.royalBlue,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Tambah Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _adminActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }

  void _showAdminResetPasswordDialog(Map<String, String> user) {
    final pwCtrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.lock_reset_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            const Expanded(child: Text('Reset Password Admin', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Admin: ${user['nama']}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
            Text(user['email']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: pwCtrl,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Minimal 8 karakter', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final pw = pwCtrl.text.trim();
                if (pw.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password minimal 8 karakter'), backgroundColor: AppColors.coral));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _svc.updateStaffPassword(userId: user['id']!, newPassword: pw);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password ${user['nama']} berhasil direset'),
                      backgroundColor: AppColors.emerald));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal reset password: $e'), backgroundColor: AppColors.coral));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNasabahList() {
    final filtered = _allNasabah.where((n) {
      final q = _searchNasabah.toLowerCase();
      if (q.isEmpty) return true;
      return n.name.toLowerCase().contains(q) ||
             n.phone.contains(q) ||
             n.nik.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchNasabahCtrl,
            onChanged: (v) => setState(() => _searchNasabah = v),
            decoration: InputDecoration(
              hintText: 'Cari nama, NIK, atau telepon...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
              suffixIcon: _searchNasabah.isNotEmpty
                  ? GestureDetector(
                      onTap: () => setState(() { _searchNasabah = ''; _searchNasabahCtrl.clear(); }),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
        ),
        if (_allNasabah.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text('${filtered.length} dari ${_allNasabah.length} nasabah',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: filtered.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(_searchNasabah.isNotEmpty ? 'Tidak ada nasabah ditemukan' : 'Belum ada data nasabah.',
                    style: const TextStyle(color: AppColors.textMuted)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final n = filtered[i];
                    final cabang = _branches.firstWhere(
                      (b) => b.id == n.cabangId,
                      orElse: () => Cabang(id: '', nama: n.cabangId, kode: '', admin: ''),
                    );
                    // Hitung jumlah transaksi aktif nasabah ini
                    final txCount = _allTx.where((t) => t.customerId == n.id && t.status == 'Aktif').length;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [BoxShadow(color: const Color(0xFF0A1628).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.iceBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                n.name.isNotEmpty ? n.name[0].toUpperCase() : 'N',
                                style: const TextStyle(color: AppColors.royalBlue, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.name, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('📞 ${n.phone}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                Row(children: [
                                  Text('🏢 ${cabang.nama.isNotEmpty ? cabang.nama : n.cabangId}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                  if (txCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.iceBlue, borderRadius: BorderRadius.circular(4)),
                                      child: Text('$txCount aktif', style: const TextStyle(color: AppColors.royalBlue, fontSize: 9, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ]),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _adminActionBtn(Icons.edit_outlined, Colors.blueAccent, () => _showNasabahDialog(nasabah: n)),
                              const SizedBox(height: 4),
                              _adminActionBtn(Icons.lock_reset_rounded, Colors.orange, () => _resetNasabahPassword(n)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNasabahDialog(),
        backgroundColor: AppColors.royalBlue,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Buat Akun Nasabah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildActivityLog() {
    // Helpers are now defined as class-level methods

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _activityLogs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded, size: 48, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 12),
                    const Text('Belum ada log aktivitas', style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    const Text('Log akan muncul setelah ada aktivitas nasabah', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 20),
                    // Tombol Test Koneksi — membantu verifikasi tabel & policy
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await _svc.logActivity(
                          userId: 'super_admin_test',
                          role: 'super_admin',
                          action: 'TEST_CONNECTION',
                          description: 'Test koneksi log dari Super Admin Dashboard.',
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok
                              ? '✅ Log berhasil ditulis! Refresh untuk melihat.'
                              : '❌ Gagal menulis log. Cek SQL Migration & RLS Policy.'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ));
                        if (ok) _loadData();
                      },
                      icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                      label: const Text('Test Koneksi Log'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5A47),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _activityLogs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final log = _activityLogs[i];
                  final action = log['action'] as String? ?? '-';
                  final role = log['role'] as String? ?? 'nasabah';
                  final description = log['description'] as String? ?? '';
                  final createdAt = log['created_at'] as String?;
                  final color = _actionColor(action);
                  final icon = _actionIcon(action);

                  return InkWell(
                    onTap: () => _showLogDetailDialog(context, log),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon badge
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 10),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Action chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: color.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        action,
                                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Role chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _roleColor(role).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        role.toUpperCase(),
                                        style: TextStyle(color: _roleColor(role), fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Priority chip
                                    (() {
                                      final prio = _getPriority(action);
                                      final prioCol = _priorityColor(prio);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: prioCol.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: prioCol.withValues(alpha: 0.2)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: prioCol,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              prio,
                                              style: TextStyle(color: prioCol, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      );
                                    }()),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (description.isNotEmpty)
                                  Text(
                                    description,
                                    style: const TextStyle(color: AppColors.textDark, fontSize: 12),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  '🕐 ${_formatLogTime(createdAt)}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _loadData,
        backgroundColor: AppColors.royalBlue,
        tooltip: 'Refresh Log',
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }

  // ════════════════════════════════════════
  // TAHAP 5: MANAJEMEN KAS
  // ════════════════════════════════════════
  Widget _buildKas() {
    final allKas = _filterKasCabang.isEmpty
        ? _kasEntries
        : _kasEntries.where((k) => k['cabang_id'] == _filterKasCabang).toList();

    int totalMasuk = 0, totalKeluar = 0;
    for (final k in allKas) {
      final jumlah = (k['jumlah'] as num?)?.toInt() ?? 0;
      if (k['jenis'] == 'masuk') totalMasuk += jumlah;
      else totalKeluar += jumlah;
    }
    final saldo = totalMasuk - totalKeluar;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        // Header summary (Blue Premium with Motif)
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A6E), AppColors.royalBlue],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.royalBlue.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CustomPaint(painter: _HeaderDotPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF93C5FD), size: 18),
                    const SizedBox(width: 8),
                    Text('Saldo Kas', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                    const Spacer(),
                    // Filter cabang dropdown
                    if (_branches.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filterKasCabang.isEmpty ? null : _filterKasCabang,
                            hint: Text('Semua Cabang', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                            dropdownColor: const Color(0xFF102A4C),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                            icon: const Icon(Icons.expand_more_rounded, color: Colors.white, size: 16),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('Semua Cabang')),
                              ..._branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.nama))),
                            ],
                            onChanged: (v) => setState(() => _filterKasCabang = v ?? ''),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text('Rp ${_formatCurrency(saldo)}',
                    style: GoogleFonts.inter(color: saldo >= 0 ? Colors.white : AppColors.coral,
                        fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _kasStatBadge('Total Masuk', totalMasuk, const Color(0xFF34D399))),
                    const SizedBox(width: 10),
                    Expanded(child: _kasStatBadge('Total Keluar', totalKeluar, AppColors.coral)),
                    const SizedBox(width: 10),
                    Expanded(child: _kasStatBadge('Transaksi', allKas.length, const Color(0xFF93C5FD), isCount: true)),
                  ]),
                ]),
              ),
            ],
          ),
        ),
        // ── Saldo Rekening Gadai Card ──
        Builder(builder: (_) {
          final filteredWallet = _filterKasCabang.isEmpty
              ? _walletBalances
              : {_filterKasCabang: _walletBalances[_filterKasCabang] ?? 0};
          final totalWallet = filteredWallet.values.fold(0, (s, v) => s + v);
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: const Color(0xFF0A1628).withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.account_balance_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                Text('Saldo Rekening Gadai', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('Rp ${_formatCurrency(totalWallet)}',
                  style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
              if (_filterKasCabang.isEmpty && _branches.length > 1) ...[
                const Divider(height: 16),
                ...filteredWallet.entries.map((e) {
                  final cabNama = _branches.firstWhere((b) => b.id == e.key,
                    orElse: () => Cabang(id: '', nama: e.key, kode: '', admin: '')).nama;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(cabNama, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                      Text('Rp ${_formatCurrency(e.value)}',
                        style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
              ],
            ]),
          );
        }),
        // List entri
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: allKas.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('Belum ada data kas', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('Tap + untuk tambah entri kas', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 12)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: allKas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final k = allKas[i];
                    final isMasuk = k['jenis'] == 'masuk';
                    final jumlah = (k['jumlah'] as num?)?.toInt() ?? 0;
                    final tanggal = k['tanggal'] as String? ?? '';
                    final keterangan = k['keterangan'] as String? ?? '-';
                    final kategori = k['kategori'] as String? ?? 'lainnya';
                    final cabId = k['cabang_id'] as String? ?? '';
                    final cabNama = _branches.firstWhere((b) => b.id == cabId,
                      orElse: () => Cabang(id: '', nama: cabId, kode: '', admin: '')).nama;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isMasuk
                            ? const Color(0xFF34D399).withValues(alpha: 0.25)
                            : AppColors.coral.withValues(alpha: 0.25)),
                        boxShadow: [BoxShadow(color: const Color(0xFF0A1628).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: isMasuk ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: isMasuk ? const Color(0xFF059669) : AppColors.coral,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(keterangan, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.iceBlue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(kategori, style: const TextStyle(color: AppColors.royalBlue, fontSize: 9, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            Text(cabNama, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          ]),
                          Text(tanggal, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(
                            '${isMasuk ? '+' : '-'} Rp ${_formatCurrency(jumlah)}',
                            style: TextStyle(
                              color: isMasuk ? const Color(0xFF059669) : AppColors.coral,
                              fontSize: 13, fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _confirmDeleteKas(k['id'] as String),
                            child: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 16),
                          ),
                        ]),
                      ]),
                    );
                  },
                ),
          ),
        ),

        // ── Tahap 6: Panel Laporan ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          color: Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📊 Laporan Ringkasan', style: TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLaporanDialog(),
                icon: const Icon(Icons.summarize_outlined, size: 16),
                label: const Text('Lihat & Salin Laporan', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.royalBlue,
                  side: const BorderSide(color: AppColors.royalBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ]),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddKasDialog(),
        backgroundColor: AppColors.royalBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Kas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _kasStatBadge(String label, int value, Color color, {bool isCount = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 9)),
        const SizedBox(height: 3),
        Text(isCount ? '$value' : 'Rp ${_formatCurrency(value)}',
          style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  void _showAddKasDialog() {
    final ketCtrl = TextEditingController();
    final jumlahCtrl = TextEditingController();
    String jenis = 'masuk';
    String kategori = 'lainnya';
    String selectedCabang = _branches.isNotEmpty ? _branches.first.id : '';
    String tanggal = DateTime.now().toIso8601String().split('T').first;

    final List<String> kategoriList = ['gadai_baru', 'tebus', 'perpanjangan', 'operasional', 'gaji', 'lainnya'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Entri Kas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Jenis
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setS(() => jenis = 'masuk'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: jenis == 'masuk' ? const Color(0xFFECFDF5) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: jenis == 'masuk' ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.arrow_downward_rounded, color: jenis == 'masuk' ? const Color(0xFF059669) : AppColors.textMuted, size: 16),
                        const SizedBox(width: 4),
                        Text('Masuk', style: TextStyle(color: jenis == 'masuk' ? const Color(0xFF059669) : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setS(() => jenis = 'keluar'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: jenis == 'keluar' ? const Color(0xFFFFF1F2) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: jenis == 'keluar' ? AppColors.coral : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.arrow_upward_rounded, color: jenis == 'keluar' ? AppColors.coral : AppColors.textMuted, size: 16),
                        const SizedBox(width: 4),
                        Text('Keluar', style: TextStyle(color: jenis == 'keluar' ? AppColors.coral : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              // Cabang
              DropdownButtonFormField<String>(
                value: selectedCabang.isEmpty ? null : selectedCabang,
                decoration: const InputDecoration(labelText: 'Cabang', border: OutlineInputBorder(), isDense: true),
                items: _branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.nama))).toList(),
                onChanged: (v) => setS(() => selectedCabang = v ?? selectedCabang),
              ),
              const SizedBox(height: 10),
              // Kategori
              DropdownButtonFormField<String>(
                value: kategori,
                decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder(), isDense: true),
                items: kategoriList.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (v) => setS(() => kategori = v ?? kategori),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: jumlahCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah (Rp)', border: OutlineInputBorder(), isDense: true, prefixText: 'Rp '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ketCtrl,
                decoration: const InputDecoration(labelText: 'Keterangan', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              // Tanggal
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setS(() => tanggal = picked.toIso8601String().split('T').first);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(tanggal, style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final jumlah = int.tryParse(jumlahCtrl.text.replaceAll('.', '').replaceAll(',', ''));
                if (jumlah == null || jumlah <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah tidak valid'), backgroundColor: AppColors.coral));
                  return;
                }
                if (selectedCabang.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih cabang terlebih dahulu'), backgroundColor: AppColors.coral));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _svc.addKasEntry(
                    cabangId: selectedCabang,
                    jenis: jenis,
                    kategori: kategori,
                    jumlah: jumlah,
                    keterangan: ketCtrl.text.trim().isEmpty ? kategori : ketCtrl.text.trim(),
                    tanggal: tanggal,
                  );
                  await _loadData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Entri kas ${jenis} berhasil ditambahkan'), backgroundColor: AppColors.emerald));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.coral));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteKas(String kasId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Entri Kas?', style: TextStyle(fontSize: 15)),
        content: const Text('Data entri kas ini akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _svc.deleteKasEntry(kasId);
      await _loadData();
    }
  }

  // ════════════════════════════════════════
  // TAHAP 6: LAPORAN RINGKASAN
  // ════════════════════════════════════════
  void _showLaporanDialog() {
    final now = DateTime.now();
    final sb = StringBuffer();
    sb.writeln('═══════════════════════════════');
    sb.writeln('    LAPORAN GALAXI GADAI');
    sb.writeln('    ${now.day}/${now.month}/${now.year}');
    sb.writeln('═══════════════════════════════');
    sb.writeln();
    sb.writeln('📊 RINGKASAN TRANSAKSI');
    sb.writeln('Total TX    : ${_allTx.length}');
    sb.writeln('Aktif       : ${_allTx.where((t) => t.status == "Aktif").length}');
    sb.writeln('Macet       : ${_allTx.where((t) => t.status == "Macet").length}');
    sb.writeln('Lunas       : ${_allTx.where((t) => t.status == "Lunas").length}');
    sb.writeln();
    sb.writeln('💰 KEUANGAN');
    final totalPinjaman = _allTx.where((t) => t.status == 'Aktif').fold(0, (s, t) => s + t.principal);
    sb.writeln('Total Pinjaman: Rp ${_formatCurrency(totalPinjaman)}');
    sb.writeln();
    sb.writeln('🏢 PER CABANG');
    for (final c in _branches) {
      final cTxs = _allTx.where((t) => t.cabangId == c.id).toList();
      final aktif = cTxs.where((t) => t.status == 'Aktif').length;
      final macet = cTxs.where((t) => t.status == 'Macet').length;
      final kas = _kasSaldo[c.id] ?? 0;
      sb.writeln('• ${c.nama}');
      sb.writeln('  TX: ${cTxs.length} | Aktif: $aktif | Macet: $macet');
      sb.writeln('  Saldo Kas: Rp ${_formatCurrency(kas)}');
    }
    sb.writeln();
    sb.writeln('👥 NASABAH');
    sb.writeln('Total: ${_allNasabah.length}');
    sb.writeln('═══════════════════════════════');

    final laporanText = sb.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.summarize_outlined, color: AppColors.royalBlue, size: 20),
          SizedBox(width: 8),
          Text('Laporan Ringkasan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
              child: SelectableText(
                laporanText,
                style: const TextStyle(color: Color(0xFF93C5FD), fontFamily: 'Courier', fontSize: 11),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton.icon(
            onPressed: () {
              // Copy ke clipboard
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Laporan disalin! Tempel di WhatsApp atau email.'),
                  backgroundColor: AppColors.emerald, duration: Duration(seconds: 3)));
            },
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
            label: const Text('Salin', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
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
          _buildRekeningSection(),
          const SizedBox(height: 24),
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
                    onPressed: () async {
                      final newTariff = int.tryParse(_tariffCtrl.text) ?? SystemConfig.tariffPerUnit;
                      final newUnit = int.tryParse(_unitAmountCtrl.text) ?? SystemConfig.unitAmount;
                      final newMin = int.tryParse(_minTenorCtrl.text) ?? SystemConfig.minTenor;
                      final newMax = int.tryParse(_maxTenorCtrl.text) ?? SystemConfig.maxTenor;
                      final newAlert = int.tryParse(_alertDaysCtrl.text) ?? SystemConfig.alertDays;

                      // Simpan ke Supabase
                      await _svc.saveSystemConfig(
                        tariffPerUnit: newTariff,
                        unitAmount: newUnit,
                        minTenor: newMin,
                        maxTenor: newMax,
                        alertDays: newAlert,
                      );

                      setState(() {
                        SystemConfig.tariffPerUnit = newTariff;
                        SystemConfig.unitAmount = newUnit;
                        SystemConfig.minTenor = newMin;
                        SystemConfig.maxTenor = newMax;
                        SystemConfig.alertDays = newAlert;
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Konfigurasi sistem berhasil diperbarui dan disimpan!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.royalBlue,
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

  LinearGradient _getBankGradient(String bankName) {
    final upper = bankName.toUpperCase().trim();
    if (upper.contains('BCA')) {
      return const LinearGradient(
        colors: [Color(0xFF0F4C81), Color(0xFF1E3A8A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (upper.contains('BRI')) {
      return const LinearGradient(
        colors: [Color(0xFF00529C), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (upper.contains('MANDIRI')) {
      return const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (upper.contains('BNI')) {
      return const LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (upper.contains('PERMATA') || upper.contains('DANAMON')) {
      return const LinearGradient(
        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (upper.contains('CIMB')) {
      return const LinearGradient(
        colors: [Color(0xFFB91C1C), Color(0xFF991B1B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  String _formatBankAccNumber(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), '');
    if (clean.length <= 4) return clean;
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  Widget _buildRekeningSection() {
    final filtered = _filterRekeningCabang == 'all'
        ? _adminRekeningList
        : _adminRekeningList.where((r) => r.branchId == _filterRekeningCabang || (_filterRekeningCabang.isEmpty && r.branchId == null)).toList();

    final activeCount = filtered.where((r) => r.isActive).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Bar ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.royalBlue, Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.royalBlue.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Rekening Pembayaran',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Text(
                            '$activeCount Aktif',
                            style: const TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Kelola nomor rekening bank & QRIS transfer per cabang untuk penerimaan pembayaran nasabah.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Action & Filter Row ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final buttonWidget = ElevatedButton.icon(
                onPressed: () => _showRekeningDialog(),
                icon: const Icon(Icons.add_circle_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Tambah Rekening',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.royalBlue,
                  elevation: 2,
                  shadowColor: AppColors.royalBlue.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );

              final filterWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 16, color: AppColors.royalBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterRekeningCabang,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 18),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('🌐 Semua Cabang & Umum')),
                            ..._branches.map((b) => DropdownMenuItem(value: b.id, child: Text('🏢 ${b.nama}'))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _filterRekeningCabang = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: buttonWidget),
                    const SizedBox(height: 10),
                    filterWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: filterWidget),
                  const SizedBox(width: 12),
                  buttonWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Lista Card Rekening
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
              ),
              child: const Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: AppColors.textMuted, size: 44),
                  SizedBox(height: 10),
                  Text(
                    'Belum Ada Rekening Tersimpan',
                    style: TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Klik tombol "+ Tambah Rekening" untuk mendaftarkan rekening bank atau QRIS baru',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) {
                final rek = filtered[i];
                final cabang = _branches.firstWhere(
                  (b) => b.id == rek.branchId,
                  orElse: () => Cabang(id: 'all', nama: 'Semua Cabang (Umum)', kode: 'all', admin: ''),
                );
                final cabangName = rek.branchId == null || rek.branchId!.isEmpty ? 'Semua Cabang (Umum)' : cabang.nama;
                final isGeneral = rek.branchId == null || rek.branchId!.isEmpty || rek.branchId == 'all';

                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: rek.isActive ? AppColors.royalBlue.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: rek.isActive
                            ? AppColors.royalBlue.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Accent Status Bar
                        Container(
                          width: 5,
                          color: rek.isActive ? AppColors.emerald : const Color(0xFF94A3B8),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Row: Badges & Status Switch
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            gradient: _getBankGradient(rek.bankName),
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.12),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            rek.bankName.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isGeneral ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isGeneral ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isGeneral ? Icons.language_rounded : Icons.storefront_rounded,
                                                  size: 11,
                                                  color: isGeneral ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    cabangName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: isGeneral ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Status Switch Toggle
                                    InkWell(
                                      onTap: () async {
                                        await _svc.updateRekeningGadai(
                                          id: rek.id,
                                          bankName: rek.bankName,
                                          accountNumber: rek.accountNumber,
                                          accountName: rek.accountName,
                                          isActive: !rek.isActive,
                                          branchId: rek.branchId,
                                        );
                                        await _loadData();
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: rek.isActive
                                              ? AppColors.emerald.withValues(alpha: 0.1)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: rek.isActive
                                                ? AppColors.emerald.withValues(alpha: 0.4)
                                                : const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: rek.isActive ? AppColors.emerald : const Color(0xFF64748B),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              rek.isActive ? 'Aktif' : 'Nonaktif',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: rek.isActive ? AppColors.emerald : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Account Number & QRIS Preview Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: SelectableText(
                                                  _formatBankAccNumber(rek.accountNumber),
                                                  style: TextStyle(
                                                    color: rek.isActive ? AppColors.textDark : AppColors.textMuted,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                    fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: rek.accountNumber));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Nomor rekening berhasil disalin!'),
                                                      backgroundColor: AppColors.emerald,
                                                      duration: Duration(seconds: 2),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.all(4),
                                                  child: Icon(
                                                    Icons.copy_rounded,
                                                    size: 14,
                                                    color: AppColors.royalBlue.withValues(alpha: 0.8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.person_rounded, size: 13, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'a.n. ${rek.accountName}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (rek.qrisImageUrl.isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => Dialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: Image.network(rek.qrisImageUrl, fit: BoxFit.contain),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(7),
                                            child: Image.network(
                                              rek.qrisImageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.qr_code, size: 20),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Bottom Row: Action Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    InkWell(
                                      onTap: () => _showRekeningDialog(rekening: rek),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.edit_rounded, size: 14, color: AppColors.royalBlue),
                                            SizedBox(width: 4),
                                            Text(
                                              'Edit',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.royalBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _confirmDeleteRekening(rek.id),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFCA5A5)),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.coral),
                                            SizedBox(width: 4),
                                            Text(
                                              'Hapus',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.coral,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showRekeningDialog({RekeningGadai? rekening}) {
    final isEdit = rekening != null;
    final isQrisOnlyInitial = isEdit && (rekening.bankName.toUpperCase() == 'QRIS');
    
    String mode = isQrisOnlyInitial ? 'qris' : 'bank'; // 'bank' | 'qris'
    final bankCtrl = TextEditingController(text: isEdit ? rekening.bankName : '');
    final numberCtrl = TextEditingController(text: isEdit ? rekening.accountNumber : '');
    final nameCtrl = TextEditingController(text: isEdit ? rekening.accountName : '');
    String selectedBranch = isEdit ? (rekening.branchId ?? 'all') : 'all';
    bool isActive = isEdit ? rekening.isActive : true;
    XFile? qrisXFile;
    String qrisPreviewUrl = isEdit ? rekening.qrisImageUrl : '';

    final quickBanks = ['BCA', 'BRI', 'Mandiri', 'BNI', 'CIMB', 'Permata'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isMobile = MediaQuery.of(ctx).size.width < 600;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            elevation: 12,
            child: Container(
              width: isMobile ? double.infinity : 480,
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            mode == 'qris' ? Icons.qr_code_rounded : Icons.account_balance_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit
                                    ? (mode == 'qris' ? 'Edit Gambar QRIS' : 'Edit Rekening Bank')
                                    : (mode == 'qris' ? 'Tambah QRIS Baru' : 'Tambah Rekening Bank Baru'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mode == 'qris'
                                    ? 'Upload barcode QRIS untuk pembayaran nasabah'
                                    : 'Rekening ini akan ditampilkan ke nasabah saat transfer pembayaran',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Mode Selector Tabs (hanya tampil jika tambah baru)
                  if (!isEdit)
                    Container(
                      color: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setS(() => mode = 'bank'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: mode == 'bank' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: mode == 'bank'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.account_balance_rounded,
                                        size: 16,
                                        color: mode == 'bank' ? AppColors.royalBlue : AppColors.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Rekening Bank',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: mode == 'bank' ? AppColors.royalBlue : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setS(() => mode = 'qris'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: mode == 'qris' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: mode == 'qris'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.qr_code_rounded,
                                        size: 16,
                                        color: mode == 'qris' ? const Color(0xFFF59E0B) : AppColors.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Hanya Foto QRIS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: mode == 'qris' ? const Color(0xFFF59E0B) : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Dialog Form Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabang Tujuan Dropdown
                          const Text(
                            'Cabang Tujuan',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedBranch,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.storefront_rounded, size: 18, color: AppColors.royalBlue),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
                              ),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('🌐 Semua Cabang (Umum)')),
                              ..._branches.map((b) => DropdownMenuItem(value: b.id, child: Text('🏢 ${b.nama}'))),
                            ],
                            onChanged: (v) => setS(() => selectedBranch = v ?? 'all'),
                          ),
                          const SizedBox(height: 14),

                          // ── Field Rekening Bank (hanya jika mode == 'bank') ──
                          if (mode == 'bank') ...[
                            // Quick Bank Chips
                            const Text(
                              'Pilih Bank Populer:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: quickBanks.map((b) {
                                final selected = bankCtrl.text.trim().toUpperCase() == b.toUpperCase();
                                return ChoiceChip(
                                  label: Text(
                                    b,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: selected ? Colors.white : AppColors.textDark,
                                    ),
                                  ),
                                  selected: selected,
                                  selectedColor: AppColors.royalBlue,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  side: BorderSide.none,
                                  onSelected: (_) {
                                    setS(() {
                                      bankCtrl.text = b;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            // Nama Bank Input
                            const Text(
                              'Nama Bank',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: bankCtrl,
                              onChanged: (_) => setS(() {}),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.account_balance_rounded, size: 18, color: AppColors.royalBlue),
                                hintText: 'Contoh: BCA / BRI / Mandiri',
                                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
                                ),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 14),

                            // Nomor Rekening Input
                            const Text(
                              'Nomor Rekening',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: numberCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.credit_card_rounded, size: 18, color: AppColors.royalBlue),
                                hintText: 'Contoh: 1234567890',
                                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
                                ),
                                isDense: true,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Nama Pemilik Input
                            const Text(
                              'Nama Pemilik (Atas Nama)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_rounded, size: 18, color: AppColors.royalBlue),
                                hintText: 'Contoh: PT GALAXI GADAI INDONESIA',
                                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
                                ),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Status Switch Container Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.power_settings_new_rounded,
                                  color: isActive ? AppColors.emerald : const Color(0xFF64748B),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Status: ${isActive ? "Aktif" : "Nonaktif"}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isActive ? AppColors.emerald : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const Text(
                                        'Tampilkan ke pilihan nasabah',
                                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isActive,
                                  activeColor: AppColors.emerald,
                                  onChanged: (v) => setS(() => isActive = v),
                                ),
                              ],
                            ),
                          ),

                          // ── QRIS Section ──
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                mode == 'qris' ? 'Upload Gambar QRIS (Wajib)' : 'Gambar QRIS (Opsional)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                              ),
                              if (mode == 'qris') ...[
                                const SizedBox(width: 4),
                                const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mode == 'qris'
                                ? 'Pilih gambar barcode QRIS dari HP untuk ditampilkan langsung ke nasabah'
                                : 'Upload kode QRIS jika ingin menyertakan QRIS pada rekening bank ini',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: qrisPreviewUrl.isNotEmpty || qrisXFile != null
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: qrisPreviewUrl.isNotEmpty || qrisXFile != null
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Preview
                                if (qrisXFile != null)
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: FutureBuilder<Uint8List>(
                                        future: qrisXFile!.readAsBytes(),
                                        builder: (_, snap) => snap.hasData
                                            ? Image.memory(snap.data!, height: 180, fit: BoxFit.contain)
                                            : const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                                      ),
                                    ),
                                  )
                                else if (qrisPreviewUrl.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        qrisPreviewUrl,
                                        height: 180,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.broken_image_outlined,
                                          size: 60,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Column(
                                      children: const [
                                        Icon(Icons.qr_code_scanner_rounded, size: 44, color: Color(0xFFCBD5E1)),
                                        SizedBox(height: 6),
                                        Text('Belum ada gambar QRIS', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                // Upload Button
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final picker = ImagePicker();
                                        final picked = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 90,
                                          maxWidth: 1200,
                                        );
                                        if (picked != null) setS(() => qrisXFile = picked);
                                      },
                                      icon: const Icon(Icons.upload_rounded, size: 16),
                                      label: Text(
                                        qrisPreviewUrl.isNotEmpty || qrisXFile != null ? 'Ganti Gambar QRIS' : 'Pilih Gambar QRIS',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: mode == 'qris' ? const Color(0xFFD97706) : AppColors.royalBlue,
                                        side: BorderSide(color: mode == 'qris' ? const Color(0xFFF59E0B) : AppColors.royalBlue),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions Footer Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final bank = mode == 'qris' ? 'QRIS' : bankCtrl.text.trim();
                            final number = mode == 'qris' ? '-' : numberCtrl.text.trim();
                            final name = mode == 'qris' ? 'QRIS Pembayaran' : nameCtrl.text.trim();

                            if (mode == 'bank' && (bank.isEmpty || number.isEmpty || name.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Harap isi semua bidang input bank'),
                                  backgroundColor: AppColors.coral,
                                ),
                              );
                              return;
                            }

                            if (mode == 'qris' && qrisXFile == null && qrisPreviewUrl.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Harap upload gambar QRIS terlebih dahulu'),
                                  backgroundColor: AppColors.coral,
                                ),
                              );
                              return;
                            }

                            Navigator.pop(ctx);
                            try {
                              String? targetId;
                              if (isEdit) {
                                targetId = rekening.id;
                                await _svc.updateRekeningGadai(
                                  id: rekening.id,
                                  bankName: bank,
                                  accountNumber: number,
                                  accountName: name,
                                  isActive: isActive,
                                  branchId: selectedBranch == 'all' ? null : selectedBranch,
                                );
                              } else {
                                targetId = await _svc.saveRekeningGadai(
                                  bankName: bank,
                                  accountNumber: number,
                                  accountName: name,
                                  branchId: selectedBranch == 'all' ? null : selectedBranch,
                                );
                              }
                              await _loadData();

                              // Upload QRIS jika ada gambar baru dipilih
                              if (qrisXFile != null && targetId != null) {
                                final bytes = await qrisXFile!.readAsBytes();
                                await _svc.uploadQrisImage(rekeningId: targetId, imageBytes: bytes);
                                await _loadData();
                              }

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Text(mode == 'qris' ? 'Gambar QRIS berhasil disimpan!' : 'Rekening berhasil disimpan!'),
                                    ],
                                  ),
                                  backgroundColor: AppColors.emerald,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppColors.coral),
                              );
                            }
                          },
                          icon: Icon(mode == 'qris' ? Icons.qr_code_rounded : Icons.check_circle_rounded, size: 18, color: Colors.white),
                          label: Text(
                            mode == 'qris'
                                ? (isEdit ? 'Simpan Gambar QRIS' : 'Simpan QRIS Baru')
                                : (isEdit ? 'Simpan Perubahan' : 'Simpan Rekening'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mode == 'qris' ? const Color(0xFFD97706) : AppColors.royalBlue,
                            elevation: 4,
                            shadowColor: mode == 'qris'
                                ? const Color(0xFFD97706).withValues(alpha: 0.3)
                                : AppColors.royalBlue.withValues(alpha: 0.3),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteRekening(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.coral, size: 36),
            ),
            const SizedBox(height: 14),
            const Text(
              'Hapus Rekening Bank?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nomor rekening ini akan dihapus permanen dari sistem dan tidak dapat dipilih nasabah saat pembayaran.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      elevation: 4,
                      shadowColor: AppColors.coral.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Ya, Hapus',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _svc.deleteRekeningGadai(id);
      await _loadData();
    }
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1628).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
              style: GoogleFonts.inter(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label,
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
        style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Header Dot Motif Painter ──
class _HeaderDotPainter extends CustomPainter {
  final Color color;
  final double opacity;

  _HeaderDotPainter({
    this.color = const Color(0xFFFFFFFF),
    this.opacity = 0.05,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: opacity);
    const spacing = 16.0;
    for (double y = spacing; y < size.height; y += spacing) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
