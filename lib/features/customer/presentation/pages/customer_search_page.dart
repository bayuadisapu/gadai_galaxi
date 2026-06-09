import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import '../widgets/customer_list_item.dart';
import '../widgets/customer_details_sheet.dart';

class CustomerSearchPage extends StatefulWidget {
  final bool isTab;
  const CustomerSearchPage({super.key, this.isTab = false});

  @override
  State<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends State<CustomerSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'Semua'; // 'Semua', 'Aktif', 'Jatuh Tempo', 'Macet'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to filter customers based on search and active tab filter
  List<Customer> _getFilteredCustomers() {
    return mockCustomers.where((customer) {
      // 1. Search Query Filter
      final nameMatch = customer.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final nikMatch = customer.nik.contains(_searchQuery);
      final phoneMatch = customer.phone.contains(_searchQuery);
      final matchesSearch = nameMatch || nikMatch || phoneMatch;

      if (!matchesSearch) return false;

      // 2. Tab Filter based on customer's transaction statuses
      final txs = mockTransactions.where((tx) => tx.customerId == customer.id).toList();
      
      if (_activeFilter == 'Semua') {
        return true;
      } else if (_activeFilter == 'Aktif') {
        return txs.any((tx) => tx.status == 'Aktif');
      } else if (_activeFilter == 'Jatuh Tempo') {
        // Due in less than 7 days
        return txs.any((tx) => tx.status == 'Aktif' && tx.dateDue.difference(DateTime.now()).inDays <= 7);
      } else if (_activeFilter == 'Macet') {
        return txs.any((tx) => tx.status == 'Macet');
      }
      return true;
    }).toList();
  }

  // Get active pawn summary count
  int _getActiveCount(Customer c) {
    return mockTransactions.where((tx) => tx.customerId == c.id && (tx.status == 'Aktif' || tx.status == 'Macet')).length;
  }

  void _showCustomerDetailsSheet(Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CustomerDetailsSheet(customer: customer);
      },
    ).then((value) {
      // Re-trigger layout updates on close in case state changed
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustomers = _getFilteredCustomers();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.isTab
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Cari & Kelola Nasabah',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
      body: Column(
        children: [
          // 1. Search Bar Container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama, NIK, atau nomor HP...',
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

          // 2. Filter Tabs Horizontal List
          Container(
            height: 54,
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _buildFilterTab('Semua'),
                _buildFilterTab('Aktif'),
                _buildFilterTab('Jatuh Tempo'),
                _buildFilterTab('Macet'),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 3. Customer List
          Expanded(
            child: filteredCustomers.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 64, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 16),
                        Text(
                          'Nasabah tidak ditemukan',
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
                    itemCount: filteredCustomers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      final activeCount = _getActiveCount(customer);

                      return CustomerListItem(
                        customer: customer,
                        activeCount: activeCount,
                        onTap: () => _showCustomerDetailsSheet(customer),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label) {
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
}
