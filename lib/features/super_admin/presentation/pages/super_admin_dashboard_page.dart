import 'dart:async';
import 'dart:convert';
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
  List<Customer> _allNasabah = [];
  List<Map<String, String>> _staffUsers = [];
  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoading = true;
  Timer? _logTimer;
  String? _lastLogId;

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
    _loadData().then((_) {
      if (_activityLogs.isNotEmpty) {
        _lastLogId = _activityLogs.first['id'] as String?;
      }
      _startLogPolling();
    });
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _tariffCtrl.dispose();
    _unitAmountCtrl.dispose();
    _minTenorCtrl.dispose();
    _maxTenorCtrl.dispose();
    _alertDaysCtrl.dispose();
    super.dispose();
  }

  void _startLogPolling() {
    _logTimer?.cancel();
    _logTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final latest = await _svc.fetchActivityLogs(limit: 1);
        if (latest.isNotEmpty) {
          final newest = latest.first;
          final newestId = newest['id'] as String?;
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
          onPressed: () => _showLogDetailDialog(context, log),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
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
      final allCustomers = await _svc.fetchNasabah();
      final allNasabah = await _svc.fetchNasabah();
      final staffUsers = await _svc.fetchStaffUsers();
      final activityLogs = await _svc.fetchActivityLogs(limit: 300);

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
        _allCustomers = allCustomers;
        _allNasabah = allNasabah;
        _staffUsers = staffUsers;
        _activityLogs = activityLogs;
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
    final tabs = ['Overview', 'Cabang', 'Admin', 'Nasabah', 'Config', 'Log'];
    final icons = [Icons.dashboard_rounded, Icons.store_mall_directory_outlined, Icons.manage_accounts_rounded, Icons.people_rounded, Icons.settings_outlined, Icons.history_rounded];

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      switch (_currentIndex) {
        case 0: body = _buildOverview(); break;
        case 1: body = _selectedCabangId != null ? _buildCabangDetail(_selectedCabangId!) : _buildCabangList(); break;
        case 2: body = _buildUserList(); break;
        case 3: body = _buildNasabahList(); break;
        case 4: body = _buildKonfigurasi(); break;
        case 5: body = _buildActivityLog(); break;
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

  Widget _buildNasabahList() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _allNasabah.isEmpty
            ? const Center(child: Text('Belum ada data nasabah.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _allNasabah.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = _allNasabah[i];
                  final cabang = _branches.firstWhere(
                    (b) => b.id == n.cabangId,
                    orElse: () => Cabang(id: '', nama: n.cabangId, kode: '', admin: ''),
                  );
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
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4EA),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              n.name.isNotEmpty ? n.name[0].toUpperCase() : 'N',
                              style: const TextStyle(color: Color(0xFF137333), fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.name, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                              Text('📞 ${n.phone}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              Text('🏢 ${cabang.nama.isNotEmpty ? cabang.nama : n.cabangId}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 18),
                              onPressed: () => _showNasabahDialog(nasabah: n),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(height: 6),
                            IconButton(
                              icon: const Icon(Icons.lock_reset_rounded, color: Colors.orange, size: 18),
                              onPressed: () => _resetNasabahPassword(n),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Reset Password',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNasabahDialog(),
        backgroundColor: const Color(0xFF0F5A47),
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
        backgroundColor: const Color(0xFF0F5A47),
        tooltip: 'Refresh Log',
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
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
