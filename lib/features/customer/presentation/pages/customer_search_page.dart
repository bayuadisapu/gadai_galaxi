import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import '../widgets/customer_list_item.dart';
import '../widgets/customer_details_sheet.dart';

class CustomerSearchPage extends StatefulWidget {
  final bool isTab;
  final String branchId;
  const CustomerSearchPage({super.key, this.isTab = false, this.branchId = 'pusat'});

  @override
  State<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends State<CustomerSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'Semua';
  final _svc = SupabaseGadaiService.instance;
  List<Customer> _customers = [];
  List<PawnTransaction> _txs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _svc.fetchNasabah(branchId: widget.branchId);
      final txs = await _svc.fetchTransactions(branchId: widget.branchId);
      if (!mounted) return;
      setState(() { _customers = customers; _txs = txs; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _getFilteredCustomers() {
    return _customers.where((customer) {
      final nameMatch = customer.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final nikMatch = customer.nik.contains(_searchQuery);
      final phoneMatch = customer.phone.contains(_searchQuery);
      final matchesSearch = nameMatch || nikMatch || phoneMatch;

      if (!matchesSearch) return false;

      final txs = _txs.where((tx) => tx.customerId == customer.id).toList();

      if (_activeFilter == 'Semua') return true;
      else if (_activeFilter == 'Aktif') return txs.any((tx) => tx.status == 'Aktif');
      else if (_activeFilter == 'Jatuh Tempo') return txs.any((tx) => tx.status == 'Aktif' && tx.dateDue.difference(DateTime.now()).inDays <= 7);
      else if (_activeFilter == 'Macet') return txs.any((tx) => tx.status == 'Macet');
      return true;
    }).toList();
  }

  int _getActiveCount(Customer c) {
    return _txs.where((tx) => tx.customerId == c.id && (tx.status == 'Aktif' || tx.status == 'Macet')).length;
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

  void _showAddCustomerDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final nikCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String gender = 'Laki-laki';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Tambah Nasabah Baru', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nikCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'NIK'),
                        validator: (v) => (v == null || v.length != 16) ? 'NIK harus 16 digit' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Nomor HP'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(labelText: 'Alamat Lengkap'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: gender,
                        decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
                        items: const [
                          DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                          DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => gender = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    
                    final newCust = Customer(
                      id: '',
                      name: nameCtrl.text.trim(),
                      nik: nikCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      birthPlace: 'Surabaya',
                      birthDate: '01 Jan 1990',
                      gender: gender,
                      cabangId: widget.branchId,
                    );

                    final navigator = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      await _svc.createNasabah(newCust);
                      navigator.pop();
                      _loadData();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Nasabah baru berhasil ditambahkan!'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Gagal menambahkan: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCustomers.isEmpty
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
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
