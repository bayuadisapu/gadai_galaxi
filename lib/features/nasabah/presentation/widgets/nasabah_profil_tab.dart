import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';

class NasabahProfilTab extends StatefulWidget {
  final Customer customer;
  final VoidCallback onLogout;

  const NasabahProfilTab({super.key, required this.customer, required this.onLogout});

  @override
  State<NasabahProfilTab> createState() => _NasabahProfilTabState();
}

class _NasabahProfilTabState extends State<NasabahProfilTab> {
  final _svc = SupabaseGadaiService.instance;
  List<PawnTransaction> _myTxs = [];
  late Customer _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadTxs();
  }

  Future<void> _loadTxs() async {
    try {
      final txs = await _svc.fetchTransactions(nasabahId: _customer.id);
      if (!mounted) return;
      setState(() => _myTxs = txs);
    } catch (_) {}
  }

  // ── Dialog Ganti Password ──
  void _showGantiPasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureOld = true, obscureNew = true, obscureConfirm = true;
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.royalBlue, size: 22),
              const SizedBox(width: 10),
              Text('Ganti Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _passwordField(ctx, oldCtrl, 'Password Lama', obscureOld, () => setDialogState(() => obscureOld = !obscureOld),
                    validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
                const SizedBox(height: 12),
                _passwordField(ctx, newCtrl, 'Password Baru', obscureNew, () => setDialogState(() => obscureNew = !obscureNew),
                    validator: (v) => v == null || v.length < 6 ? 'Minimal 6 karakter' : null),
                const SizedBox(height: 12),
                _passwordField(ctx, confirmCtrl, 'Konfirmasi Password Baru', obscureConfirm, () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    validator: (v) => v != newCtrl.text ? 'Password tidak cocok' : null),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => saving = true);
                try {
                  final success = await _svc.changeNasabahPassword(
                    phone: _customer.phone,
                    oldPassword: oldCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  if (!mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  if (success) {
                    unawaited(_svc.logNasabahPasswordChange(_customer.id, _customer.name));
                  }
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Password berhasil diubah!' : 'Password lama salah!'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                } catch (e) {
                  setDialogState(() => saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Simpan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

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
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Center(
              child: Text(
                _customer.name.isNotEmpty ? _customer.name[0].toUpperCase() : 'N',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(_customer.name, style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_customer.phone, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 28),

          // Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informasi Pribadi', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),
                _infoRow(Icons.badge_outlined, 'NIK', _customer.nik.isEmpty ? '-' : _customer.nik),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.phone_outlined, 'Nomor HP', _customer.phone),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.place_outlined, 'Tempat Lahir', _customer.birthPlace.isEmpty ? '-' : _customer.birthPlace),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.cake_outlined, 'Tanggal Lahir', _customer.birthDate.isEmpty ? '-' : _customer.birthDate),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.person_outline_rounded, 'Jenis Kelamin', _customer.gender.isEmpty ? '-' : _customer.gender),
                const Divider(color: Color(0xFFF1F5F9), height: 24),
                _infoRow(Icons.home_outlined, 'Alamat', _customer.address.isEmpty ? '-' : _customer.address),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statistik Transaksi', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),
                Builder(builder: (ctx) {
                  final aktif = _myTxs.where((tx) => tx.status == 'Aktif').length;
                  final lunas = _myTxs.where((tx) => tx.status == 'Lunas').length;
                  final macet = _myTxs.where((tx) => tx.status == 'Macet').length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('$aktif', 'Aktif', AppColors.royalBlue),
                      _statItem('$lunas', 'Lunas', const Color(0xFF10B981)),
                      _statItem('$macet', 'Macet', const Color(0xFFEF4444)),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Ganti Password button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _showGantiPasswordDialog,
              icon: const Icon(Icons.lock_outline_rounded, color: AppColors.royalBlue, size: 18),
              label: Text('Ganti Password', style: GoogleFonts.inter(color: AppColors.royalBlue, fontSize: 14, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDBEAFE), width: 1.5),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Logout button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
              label: Text('Keluar Akun', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFEE2E2), width: 1.5),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.royalBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.royalBlue, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(String count, String label, Color color) {
    return Column(
      children: [
        Text(count, style: GoogleFonts.inter(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _passwordField(
    BuildContext ctx,
    TextEditingController ctrl,
    String label,
    bool obscure,
    VoidCallback onToggle, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 18),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted, size: 16),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      validator: validator,
    );
  }
}
