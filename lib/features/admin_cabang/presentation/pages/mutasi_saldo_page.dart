import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';

class MutasiSaldoPage extends StatefulWidget {
  final String branchId;
  const MutasiSaldoPage({super.key, required this.branchId});

  @override
  State<MutasiSaldoPage> createState() => _MutasiSaldoPageState();
}

class _MutasiSaldoPageState extends State<MutasiSaldoPage> {
  final _svc = SupabaseGadaiService.instance;
  List<Map<String, dynamic>> _mutations = [];
  int _balance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final balance = await _svc.fetchWalletBalance(widget.branchId);
      final mutations = await _svc.fetchWalletMutations(widget.branchId);
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _mutations = mutations;
        _isLoading = false;
      });
    } catch (_) {
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

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Mutasi Saldo Tenant', style: GoogleFonts.poppins(color: const Color(0xFF0A1628), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF93C5FD),
        iconTheme: const IconThemeData(color: Color(0xFF0A1628)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0A1628)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF93C5FD),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text('Saldo Saat Ini', style: GoogleFonts.poppins(color: const Color(0xFF0A1628), fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text(
                          'Rp ${_formatCurrency(_balance)}',
                          style: GoogleFonts.poppins(color: const Color(0xFF0A1628), fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _mutations.isEmpty
                        ? const Center(child: Text('Belum ada riwayat mutasi saldo.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _mutations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final item = _mutations[i];
                              final isKredit = item['type'] == 'Kredit';
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['desc'] as String,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(item['date'] as DateTime),
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${isKredit ? '+' : '-'} Rp ${_formatCurrency(item['amount'] as int)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isKredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
