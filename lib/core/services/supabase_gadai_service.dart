import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';

/// Singleton service for all Supabase gadai operations.
class SupabaseGadaiService {
  SupabaseGadaiService._();
  static final SupabaseGadaiService instance = SupabaseGadaiService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════
  // BRANCHES (shared with servis HP)
  // ═══════════════════════════════════

  Future<List<Cabang>> fetchBranches() async {
    final data = await _client.from('branches').select().order('id');
    return data.map<Cabang>((row) => Cabang(
      id: row['id'] as String,
      nama: row['name'] as String,
      kode: row['id'] as String,
      admin: '', // will be filled from profiles
      status: 'Aktif',
    )).toList();
  }

  // ═══════════════════════════════════
  // STAFF AUTH (via profiles table)
  // ═══════════════════════════════════

  /// Login staff by authenticating using Supabase Auth (email/password) and mapping profiles.
  /// Returns profile map or null.
  Future<Map<String, String>?> loginStaff(String usernameOrEmail, String password) async {
    try {
      String email = usernameOrEmail.trim();

      // Jika input tidak mengandung '@', cari email yang sesuai dari kolom username di tabel profiles secara dinamis.
      if (!email.contains('@')) {
        try {
          final res = await _client
              .from('profiles')
              .select('email')
              .ilike('username', email)
              .limit(1);
          if (res.isNotEmpty && res.first['email'] != null) {
            email = res.first['email'] as String;
          } else {
            // Fallback ke pola username@gadai.com jika profile tidak ditemukan
            email = '$email@gadai.com';
          }
        } catch (e) {
          // Jika RLS memblokir/gagal query, gunakan fallback pola username@gadai.com
          print('Gagal mengambil email dari username: $e');
          email = '$email@gadai.com';
        }
      }

      // Melakukan autentikasi menggunakan Supabase Auth
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) return null;

      // Setelah berhasil login, ambil detail profile (RLS mengizinkan user membaca data profilenya sendiri)
      final profiles = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .limit(1);

      if (profiles.isEmpty) return null;

      final profile = profiles.first;
      final branchId = profile['branch_id'] as String? ?? 'all';

      // Map supabase role ke gadai role
      String gadaiRole;
      switch (profile['role'] as String? ?? '') {
        case 'superadmin':
          gadaiRole = 'super_admin';
          break;
        case 'admin':
          gadaiRole = 'admin_cabang';
          break;
        default:
          gadaiRole = 'verifikator';
      }

      return {
        'nama': profile['full_name'] as String? ?? profile['username'] as String? ?? 'Staff',
        'role': gadaiRole,
        'cabangId': branchId,
        'cabang': '',
      };
    } catch (e) {
      print('loginStaff error: $e');
      return null;
    }
  }

  /// Get current staff details if already logged in via Supabase Auth
  Future<Map<String, String>?> getCurrentStaff() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final profiles = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .limit(1);

      if (profiles.isEmpty) return null;

      final profile = profiles.first;
      final branchId = profile['branch_id'] as String? ?? 'all';

      String gadaiRole;
      switch (profile['role'] as String? ?? '') {
        case 'superadmin':
          gadaiRole = 'super_admin';
          break;
        case 'admin':
          gadaiRole = 'admin_cabang';
          break;
        default:
          gadaiRole = 'verifikator';
      }

      return {
        'nama': profile['full_name'] as String? ?? profile['username'] as String? ?? 'Staff',
        'role': gadaiRole,
        'cabangId': branchId,
        'cabang': '',
      };
    } catch (e) {
      print('getCurrentStaff error: $e');
      return null;
    }
  }

  /// Fetch branch name by id
  Future<String> getBranchName(String branchId) async {
    final data = await _client
        .from('branches')
        .select('name')
        .eq('id', branchId)
        .limit(1);
    if (data.isEmpty) return branchId;
    return data.first['name'] as String;
  }

  // ═══════════════════════════════════
  // NASABAH
  // ═══════════════════════════════════

  Future<List<Customer>> fetchNasabah({String? branchId}) async {
    var query = _client.from('gadai_nasabah').select();
    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }
    final data = await query.order('created_at', ascending: false);
    return data.map<Customer>((row) => _customerFromRow(row)).toList();
  }

  Future<Customer?> fetchNasabahById(String id) async {
    final data = await _client.from('gadai_nasabah').select().eq('id', id).limit(1);
    if (data.isEmpty) return null;
    return _customerFromRow(data.first);
  }

  Future<Customer> createNasabah(Customer c) async {
    final row = await _client.from('gadai_nasabah').insert({
      'branch_id': c.cabangId,
      'name': c.name,
      'nik': c.nik,
      'phone': c.phone,
      'address': c.address,
      'birth_place': c.birthPlace,
      'birth_date': c.birthDate,
      'gender': c.gender,
    }).select().single();
    return _customerFromRow(row);
  }

  Customer _customerFromRow(Map<String, dynamic> row) => Customer(
    id: row['id'] as String,
    name: row['name'] as String,
    nik: row['nik'] as String? ?? '',
    phone: row['phone'] as String? ?? '',
    address: row['address'] as String? ?? '',
    birthPlace: row['birth_place'] as String? ?? '',
    birthDate: row['birth_date'] as String? ?? '',
    gender: row['gender'] as String? ?? 'Laki-laki',
    cabangId: row['branch_id'] as String? ?? '',
  );

  // ═══════════════════════════════════
  // NASABAH AUTH
  // ═══════════════════════════════════

  Future<Customer?> loginNasabah(String phone, String password) async {
    final accounts = await _client
        .from('gadai_nasabah_accounts')
        .select()
        .eq('phone', phone)
        .eq('password', password)
        .limit(1);

    if (accounts.isEmpty) return null;

    final nasabahId = accounts.first['nasabah_id'] as String;
    return fetchNasabahById(nasabahId);
  }

  Future<void> registerNasabahAccount(String phone, String password, String nasabahId) async {
    await _client.from('gadai_nasabah_accounts').insert({
      'phone': phone,
      'password': password,
      'nasabah_id': nasabahId,
    });
  }

  // ═══════════════════════════════════
  // TRANSACTIONS
  // ═══════════════════════════════════

  Future<List<PawnTransaction>> fetchTransactions({String? branchId, String? nasabahId}) async {
    var query = _client.from('gadai_transactions').select();
    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }
    if (nasabahId != null) {
      query = query.eq('nasabah_id', nasabahId);
    }
    final data = await query.order('created_at', ascending: false);
    return data.map<PawnTransaction>((row) => _txFromRow(row)).toList();
  }

  Future<PawnTransaction?> fetchTransactionById(String id) async {
    final data = await _client.from('gadai_transactions').select().eq('id', id).limit(1);
    if (data.isEmpty) return null;
    return _txFromRow(data.first);
  }

  Future<PawnTransaction> createTransaction(PawnTransaction tx) async {
    final row = await _client.from('gadai_transactions').insert({
      'nasabah_id': tx.customerId,
      'branch_id': tx.cabangId,
      'collateral_type': tx.collateralType,
      'brand': tx.brand,
      'model': tx.model,
      'condition': tx.condition,
      'principal': tx.principal,
      'period_days': tx.periodDays,
      'daily_fee': tx.dailyFee,
      'total_fee': tx.totalFee,
      'total_repayment': tx.totalRepayment,
      'date_applied': tx.dateApplied.toIso8601String(),
      'date_due': tx.dateDue.toIso8601String(),
      'status': tx.status,
    }).select().single();
    return _txFromRow(row);
  }

  Future<void> updateTransactionStatus(String txId, String status, {DateTime? newDueDate, int? periodDays, int? totalFee, int? totalRepayment}) async {
    final updates = <String, dynamic>{'status': status};
    if (newDueDate != null) updates['date_due'] = newDueDate.toIso8601String();
    if (periodDays != null) updates['period_days'] = periodDays;
    if (totalFee != null) updates['total_fee'] = totalFee;
    if (totalRepayment != null) updates['total_repayment'] = totalRepayment;
    updates['date_applied'] = DateTime.now().toIso8601String();

    await _client.from('gadai_transactions').update(updates).eq('id', txId);
  }

  PawnTransaction _txFromRow(Map<String, dynamic> row) => PawnTransaction(
    id: row['id'] as String,
    customerId: row['nasabah_id'] as String,
    cabangId: row['branch_id'] as String? ?? '',
    collateralType: row['collateral_type'] as String,
    brand: row['brand'] as String? ?? '',
    model: row['model'] as String? ?? '',
    condition: row['condition'] as String? ?? '',
    principal: row['principal'] as int? ?? 0,
    periodDays: row['period_days'] as int? ?? 15,
    dailyFee: row['daily_fee'] as int? ?? 0,
    totalFee: row['total_fee'] as int? ?? 0,
    totalRepayment: row['total_repayment'] as int? ?? 0,
    dateApplied: DateTime.parse(row['date_applied'] as String),
    dateDue: DateTime.parse(row['date_due'] as String),
    status: row['status'] as String? ?? 'Aktif',
  );

  // ═══════════════════════════════════
  // EXTENSION HISTORY
  // ═══════════════════════════════════

  Future<List<ExtensionHistory>> fetchExtensions(String txId) async {
    final data = await _client
        .from('gadai_extension_history')
        .select()
        .eq('transaction_id', txId)
        .order('created_at', ascending: false);
    return data.map<ExtensionHistory>((row) => ExtensionHistory(
      id: row['id'] as String,
      transactionId: row['transaction_id'] as String,
      jatipDibayar: row['jatip_dibayar'] as int? ?? 0,
      tglPerpanjangan: DateTime.parse(row['tgl_perpanjangan'] as String),
      tglTempoLama: DateTime.parse(row['tgl_tempo_lama'] as String),
      tglTempoBaru: DateTime.parse(row['tgl_tempo_baru'] as String),
    )).toList();
  }

  Future<void> createExtension(ExtensionHistory ext, {String paymentMethod = ''}) async {
    await _client.from('gadai_extension_history').insert({
      'transaction_id': ext.transactionId,
      'jatip_dibayar': ext.jatipDibayar,
      'tgl_perpanjangan': ext.tglPerpanjangan.toIso8601String(),
      'tgl_tempo_lama': ext.tglTempoLama.toIso8601String(),
      'tgl_tempo_baru': ext.tglTempoBaru.toIso8601String(),
      'payment_method': paymentMethod,
    });
  }

  // ═══════════════════════════════════
  // STAFF USERS (for super admin)
  // ═══════════════════════════════════

  Future<List<Map<String, String>>> fetchStaffUsers() async {
    final data = await _client
        .from('profiles')
        .select('id, username, full_name, role, branch_id, email')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return data.map<Map<String, String>>((row) {
      String gadaiRole;
      switch (row['role'] as String? ?? '') {
        case 'superadmin':
          gadaiRole = 'super_admin';
          break;
        case 'admin':
          gadaiRole = 'admin_cabang';
          break;
        default:
          gadaiRole = 'verifikator';
      }
      return {
        'id': row['id'] as String? ?? '',
        'username': row['username'] as String? ?? '',
        'email': row['email'] as String? ?? row['username'] as String? ?? '',
        'nama': row['full_name'] as String? ?? '',
        'role': gadaiRole,
        'cabang': row['branch_id'] as String? ?? '',
      };
    }).toList();
  }

  // ═══════════════════════════════════
  // BRANCH & PROFILE CRUD OPERATIONS
  // ═══════════════════════════════════

  Future<void> createBranch(String id, String name) async {
    await _client.from('branches').insert({
      'id': id,
      'name': name,
    });
  }

  Future<void> updateBranch(String id, String name) async {
    await _client.from('branches').update({
      'name': name,
    }).eq('id', id);
  }

  Future<void> deleteBranch(String id) async {
    await _client.from('branches').delete().eq('id', id);
  }

  Future<void> createProfile({
    required String id,
    required String username,
    required String fullName,
    required String email,
    required String role,
    required String branchId,
  }) async {
    await _client.from('profiles').insert({
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'role': role,
      'branch_id': branchId,
      'is_active': true,
    });
  }

  Future<void> updateProfile({
    required String id,
    required String username,
    required String fullName,
    required String email,
    required String role,
    required String branchId,
  }) async {
    await _client.from('profiles').update({
      'username': username,
      'full_name': fullName,
      'email': email,
      'role': role,
      'branch_id': branchId,
    }).eq('id', id);
  }

  Future<void> deactivateProfile(String id) async {
    await _client.from('profiles').update({
      'is_active': false,
    }).eq('id', id);
  }

  /// Alias for backward compat
  Future<List<ExtensionHistory>> fetchExtensionHistory(String txId) => fetchExtensions(txId);

  // ═══════════════════════════════════
  // UPDATE TRANSACTION DETAILS
  // ═══════════════════════════════════

  Future<void> updateTransactionDetails(
    String txId, {
    String? brand,
    String? model,
    String? condition,
    int? principal,
    int? periodDays,
    int? dailyFee,
    int? totalFee,
    int? totalRepayment,
    DateTime? dateDue,
  }) async {
    final updates = <String, dynamic>{};
    if (brand != null) updates['brand'] = brand;
    if (model != null) updates['model'] = model;
    if (condition != null) updates['condition'] = condition;
    if (principal != null) updates['principal'] = principal;
    if (periodDays != null) updates['period_days'] = periodDays;
    if (dailyFee != null) updates['daily_fee'] = dailyFee;
    if (totalFee != null) updates['total_fee'] = totalFee;
    if (totalRepayment != null) updates['total_repayment'] = totalRepayment;
    if (dateDue != null) updates['date_due'] = dateDue.toIso8601String();
    if (updates.isNotEmpty) {
      await _client.from('gadai_transactions').update(updates).eq('id', txId);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
