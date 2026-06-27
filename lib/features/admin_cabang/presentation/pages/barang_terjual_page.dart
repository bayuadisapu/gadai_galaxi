import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';

class BarangTerjualPage extends StatefulWidget {
  final String branchId;
  const BarangTerjualPage({super.key, required this.branchId});

  @override
  State<BarangTerjualPage> createState() => _BarangTerjualPageState();
}

class _BarangTerjualPageState extends State<BarangTerjualPage> {
  final _svc = SupabaseGadaiService.instance;
  List<PawnTransaction> _terjualTxs = [];
  List<Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final txs = await _svc.fetchTransactions(branchId: widget.branchId);
      final customers = await _svc.fetchNasabah(branchId: widget.branchId);
      if (!mounted) return;
      setState(() {
        _terjualTxs = txs.where((t) => t.status == 'Terjual').toList();
        _customers = customers;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F0),
      appBar: AppBar(
        title: const Text('Barang Terjual / Laku', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F5A47),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _terjualTxs.isEmpty
              ? const Center(child: Text('Tidak ada barang terjual.'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _terjualTxs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final tx = _terjualTxs[i];
                      final c = _customers.firstWhere((cust) => cust.id == tx.customerId,
                          orElse: () => Customer(id: '', name: 'Tidak Dikenal', nik: '', phone: '', address: '', birthPlace: '', birthDate: '', gender: ''));
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFFECFDF5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.trending_up_rounded, color: Color(0xFF10B981), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${tx.brand} ${tx.model}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Nasabah Asal: ${c.name}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                  Text(
                                    'Jenis: ${tx.collateralType}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Terjual / Lunas',
                                  style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rp ${_formatCurrency(tx.principal + tx.totalFee)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
