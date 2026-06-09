import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/extension_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/redemption_page.dart';

class TransaksiTabContent extends StatefulWidget {
  final String initialFilter;
  final VoidCallback onRefreshParent;

  const TransaksiTabContent({
    super.key,
    this.initialFilter = 'Semua',
    required this.onRefreshParent,
  });

  @override
  State<TransaksiTabContent> createState() => _TransaksiTabContentState();
}

class _TransaksiTabContentState extends State<TransaksiTabContent> {
  late TextEditingController _searchController;
  late String _activeFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _activeFilter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(covariant TransaksiTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() {
        _activeFilter = widget.initialFilter;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(int val) {
    final s = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  String _formatIndonesianDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filteredTxs = mockTransactions.where((tx) {
      final customer = mockCustomers.firstWhere(
        (c) => c.id == tx.customerId,
        orElse: () => Customer(
          id: '',
          name: '',
          nik: '',
          birthPlace: '',
          birthDate: '',
          gender: '',
          phone: '',
          address: '',
        ),
      );
      final query = _searchQuery.toLowerCase();
      final nameMatch = customer.name.toLowerCase().contains(query);
      final idMatch = tx.id.toLowerCase().contains(query);
      final brandMatch = tx.brand.toLowerCase().contains(query);
      final modelMatch = tx.model.toLowerCase().contains(query);
      final matchesSearch = nameMatch || idMatch || brandMatch || modelMatch;

      if (!matchesSearch) return false;

      if (_activeFilter == 'Semua') {
        return true;
      } else {
        return tx.status.toLowerCase() == _activeFilter.toLowerCase();
      }
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari ID Transaksi, Nama, atau Model Barang...',
              hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),

        Container(
          height: 54,
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              _buildTxFilterTab('Semua'),
              _buildTxFilterTab('Aktif'),
              _buildTxFilterTab('Lunas'),
              _buildTxFilterTab('Macet'),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        Expanded(
          child: filteredTxs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_late_outlined, size: 64, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 16),
                      Text(
                        'Transaksi tidak ditemukan',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredTxs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final tx = filteredTxs[index];
                    final customer = mockCustomers.firstWhere(
                      (c) => c.id == tx.customerId,
                      orElse: () => Customer(
                        id: '',
                        name: 'Nasabah Tidak Dikenal',
                        nik: '',
                        birthPlace: '',
                        birthDate: '',
                        gender: '',
                        phone: '',
                        address: '',
                      ),
                    );

                    Color statusColor = AppColors.primary;
                    Color statusBg = const Color(0xFFEFF6FF);
                    if (tx.status == 'Macet') {
                      statusColor = const Color(0xFFEF4444);
                      statusBg = const Color(0xFFFEF2F2);
                    } else if (tx.status == 'Lunas') {
                      statusColor = const Color(0xFF10B981);
                      statusBg = const Color(0xFFECFDF5);
                    }

                    IconData collIcon = Icons.phone_android_rounded;
                    if (tx.collateralType == 'Laptop') {
                      collIcon = Icons.laptop_mac_rounded;
                    } else if (tx.collateralType == 'Emas') {
                      collIcon = Icons.workspace_premium_outlined;
                    } else if (tx.collateralType == 'Motor / Mobil' || tx.collateralType == 'Kendaraan') {
                      collIcon = Icons.two_wheeler_rounded;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(collIcon, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${tx.brand} ${tx.model}',
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    tx.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                _buildTxSummaryRow('ID Transaksi', tx.id),
                                _buildTxSummaryRow('Nasabah', customer.name),
                                _buildTxSummaryRow('Nominal Pinjaman', 'Rp ${_formatCurrency(tx.principal)}'),
                                _buildTxSummaryRow('Jasa Titip Harian', 'Rp ${_formatCurrency(tx.dailyFee)} / hari'),
                                _buildTxSummaryRow('Jatuh Tempo', _formatIndonesianDate(tx.dateDue)),
                              ],
                            ),
                          ),
                          if (tx.status != 'Lunas') ...[
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            Container(
                              color: const Color(0xFFFAFAFA),
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ExtensionPage(prefilledTxId: tx.id),
                                          ),
                                        ).then((_) {
                                          setState(() {});
                                          widget.onRefreshParent();
                                        });
                                      },
                                      icon: const Icon(Icons.autorenew_rounded, size: 16),
                                      label: const Text('Perpanjang', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(color: AppColors.primary),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RedemptionPage(prefilledTxId: tx.id),
                                          ),
                                        ).then((_) {
                                          setState(() {});
                                          widget.onRefreshParent();
                                        });
                                      },
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                                      label: const Text('Lunasi / Tebus', style: TextStyle(fontSize: 12, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTxFilterTab(String label) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTxSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
