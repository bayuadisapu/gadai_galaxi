import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';

class KasPage extends StatefulWidget {
  final String branchId;
  final String namaCabang;
  const KasPage({super.key, required this.branchId, required this.namaCabang});

  @override
  State<KasPage> createState() => _KasPageState();
}

class _KasPageState extends State<KasPage> {
  final _svc = SupabaseGadaiService.instance;
  int _balance = 0;
  List<Map<String, dynamic>> _mutations = [];
  bool _isLoading = true;

  static const _green = Color(0xFF0F5A47);

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(int val) {
    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _fmtDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
    return '${dt.day.toString().padLeft(2,'0')} ${months[dt.month-1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  // ── Hitung ringkasan bulan ini ──
  int get _totalMasukBulanIni {
    final now = DateTime.now();
    return _mutations
        .where((m) {
          final d = m['date'] as DateTime;
          return d.year == now.year && d.month == now.month && m['type'] == 'Kredit';
        })
        .fold(0, (s, m) => s + (m['amount'] as int));
  }

  int get _totalKeluarBulanIni {
    final now = DateTime.now();
    return _mutations
        .where((m) {
          final d = m['date'] as DateTime;
          return d.year == now.year && d.month == now.month && m['type'] == 'Debit';
        })
        .fold(0, (s, m) => s + (m['amount'] as int));
  }

  // ── Bottom Sheet: Masuk / Keluar ──
  void _showTransaksiSheet({required bool isKasuk}) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),

                // Title
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isKasuk ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isKasuk ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                      color: isKasuk ? const Color(0xFF10B981) : Colors.red,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isKasuk ? 'Kas Masuk' : 'Kas Keluar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isKasuk ? const Color(0xFF065F46) : Colors.red.shade700,
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // Nominal
                const Text('Nominal (Rp)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Contoh: 500000',
                    prefixText: 'Rp ',
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isKasuk ? const Color(0xFF10B981) : Colors.red, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Keterangan
                const Text('Keterangan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: isKasuk ? 'Contoh: Setoran modal awal' : 'Contoh: Beli ATK, bayar listrik...',
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isKasuk ? const Color(0xFF10B981) : Colors.red, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final amount = int.tryParse(amountCtrl.text) ?? 0;
                            final desc = descCtrl.text.trim();
                            if (amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Masukkan nominal yang valid'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            if (desc.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Keterangan tidak boleh kosong'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            setSheet(() => isLoading = true);
                            if (isKasuk) {
                              await _svc.walletTopUp(widget.branchId, amount, desc);
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✅ Kas Masuk Rp ${_fmt(amount)} dicatat'), backgroundColor: const Color(0xFF10B981)),
                              );
                            } else {
                              final err = await _svc.walletDebit(widget.branchId, amount, desc);
                              if (!mounted) return;
                              if (err != null) {
                                setSheet(() => isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('❌ $err'), backgroundColor: Colors.red),
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✅ Kas Keluar Rp ${_fmt(amount)} dicatat'), backgroundColor: Colors.orange),
                              );
                            }
                            _loadData();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isKasuk ? const Color(0xFF10B981) : Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            isKasuk ? 'Simpan Kas Masuk' : 'Simpan Kas Keluar',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F0),
      body: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _green,
              child: CustomScrollView(
                slivers: [
                  // ── App Bar + Saldo Header ──
                  SliverAppBar(
                    expandedHeight: 240,
                    pinned: true,
                    backgroundColor: _green,
                    iconTheme: const IconThemeData(color: Colors.white),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0F5A47), Color(0xFF137333)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Uang Kas — ${widget.namaCabang}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Rp ${_fmt(_balance)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                // Ringkasan bulan ini
                                Row(children: [
                                  _summaryChip('↑ Masuk', _totalMasukBulanIni, const Color(0xFF10B981)),
                                  const SizedBox(width: 10),
                                  _summaryChip('↓ Keluar', _totalKeluarBulanIni, Colors.red.shade300),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: const Text('Uang Kas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    actions: [
                      IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _loadData),
                    ],
                  ),

                  // ── Tombol Aksi ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(children: [
                        Expanded(
                          child: _actionBtn(
                            label: '+ Kas Masuk',
                            icon: Icons.add_circle_outline_rounded,
                            color: const Color(0xFF10B981),
                            onTap: () => _showTransaksiSheet(isKasuk: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _actionBtn(
                            label: '- Kas Keluar',
                            icon: Icons.remove_circle_outline_rounded,
                            color: Colors.red,
                            onTap: () => _showTransaksiSheet(isKasuk: false),
                          ),
                        ),
                      ]),
                    ),
                  ),

                  // ── Header Riwayat ──
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                      child: Text(
                        'Riwayat Mutasi',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ),
                  ),

                  // ── Daftar Mutasi ──
                  _mutations.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined, size: 60, color: Color(0xFFCBD5E1)),
                                SizedBox(height: 12),
                                Text('Belum ada mutasi kas', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final item = _mutations[i];
                                final isKredit = item['type'] == 'Kredit';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 42, height: 42,
                                      decoration: BoxDecoration(
                                        color: isKredit ? const Color(0xFFECFDF5) : Colors.red.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isKredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                        color: isKredit ? const Color(0xFF10B981) : Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(item['desc'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13)),
                                      const SizedBox(height: 3),
                                      Text(_fmtDate(item['date'] as DateTime), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ])),
                                    Text(
                                      '${isKredit ? '+' : '-'} Rp ${_fmt(item['amount'] as int)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isKredit ? const Color(0xFF10B981) : Colors.red,
                                      ),
                                    ),
                                  ]),
                                );
                              },
                              childCount: _mutations.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _summaryChip(String label, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        Text('Rp ${_fmt(amount)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _actionBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
    );
  }
}
