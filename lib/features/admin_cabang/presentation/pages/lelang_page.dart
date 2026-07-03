import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';

class LelangPage extends StatefulWidget {
  final String branchId;
  const LelangPage({super.key, required this.branchId});

  @override
  State<LelangPage> createState() => _LelangPageState();
}

class _LelangPageState extends State<LelangPage> {
  final _svc = SupabaseGadaiService.instance;
  List<PawnTransaction> _macetTxs = [];
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
        _macetTxs = txs.where((t) => t.status == 'Macet').toList();
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

  void _processLelang(PawnTransaction tx) {
    final priceCtrl = TextEditingController(text: (tx.principal + tx.totalFee).toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Proses Lelang Barang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barang: ${tx.brand} ${tx.model}'),
            const SizedBox(height: 8),
            Text('Pinjaman Pokok: Rp ${_formatCurrency(tx.principal)}'),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga Jual Lelang (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final price = int.tryParse(priceCtrl.text) ?? 0;
              if (price <= 0) return;

              try {
                // Update status di Supabase
                await _svc.updateTransactionStatus(tx.id, 'Terjual');

                // Tambahkan uang masuk ke Wallet Tenant (Supabase)
                await _svc.walletTopUp(
                  widget.branchId,
                  price,
                  'Hasil Lelang ${tx.brand} ${tx.model}',
                );

                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Barang berhasil dilelang seharga Rp ${_formatCurrency(price)}. Saldo Tenant bertambah!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal lelang: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Konfirmasi Jual'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F0),
      appBar: AppBar(
        title: const Text('Barang Siap Lelang (Macet)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F5A47),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _macetTxs.isEmpty
              ? const Center(child: Text('Tidak ada barang berstatus macet (siap lelang).'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _macetTxs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final tx = _macetTxs[i];
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
                                color: Color(0xFFFEF2F2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.gavel_rounded, color: Color(0xFFEF4444), size: 22),
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
                                    'Nasabah: ${c.name}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                  Text(
                                    'Pinjaman: Rp ${_formatCurrency(tx.principal)}',
                                    style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _processLelang(tx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Lelang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
