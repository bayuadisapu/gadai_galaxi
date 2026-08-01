import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      // Jika input bukan email, lookup via RPC (security definer — bypass RLS)
      // sama persis dengan cara servis HP
      if (!email.contains('@')) {
        try {
          final dynamic rawEmail = await _client
              .rpc('get_email_by_username', params: {'p_username': email.toLowerCase()});
          final String? foundEmail = rawEmail as String?;
          if (foundEmail != null && foundEmail.isNotEmpty) {
            email = foundEmail;
          } else {
            debugPrint('Username tidak ditemukan: $email');
            return null;
          }
        } catch (e) {
          debugPrint('Gagal lookup email via RPC: $e');
          return null;
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
        default:
          gadaiRole = 'admin_cabang';
      }

      return {
        'nama': profile['full_name'] as String? ?? profile['username'] as String? ?? 'Admin',
        'role': gadaiRole,
        'cabangId': branchId,
        'cabang': '',
      };
    } catch (e) {
      debugPrint('loginStaff error: $e');
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
        default:
          gadaiRole = 'admin_cabang';
      }

      return {
        'nama': profile['full_name'] as String? ?? profile['username'] as String? ?? 'Admin',
        'role': gadaiRole,
        'cabangId': branchId,
        'cabang': '',
      };
    } catch (e) {
      debugPrint('getCurrentStaff error: $e');
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

  Future<Customer?> fetchNasabahByPhone(String phone) async {
    try {
      final data = await _client.from('gadai_nasabah').select().eq('phone', phone.trim()).limit(1);
      if (data.isEmpty) return null;
      return _customerFromRow(data.first);
    } catch (_) {
      return null;
    }
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
    ktpPhotoUrl: row['ktp_photo_url'] as String? ?? '',
  );

  /// Update data profil nasabah
  Future<Customer> updateNasabah({
    required String id,
    required String name,
    required String phone,
    required String address,
    String? birthPlace,
    String? birthDate,
    String? gender,
    String? nik,
  }) async {
    final row = await _client.from('gadai_nasabah').update({
      'name': name,
      'phone': phone,
      'address': address,
      if (birthPlace != null) 'birth_place': birthPlace,
      if (birthDate != null) 'birth_date': birthDate,
      if (gender != null) 'gender': gender,
      if (nik != null) 'nik': nik,
    }).eq('id', id).select().single();
    return _customerFromRow(row);
  }

  /// Upload foto KTP nasabah ke storage & simpan URL ke tabel gadai_nasabah.
  /// Path storage: nasabah/{nasabahId}/ktp.jpg
  Future<String?> uploadNasabahKtp({
    required String nasabahId,
    required List<int> imageBytes,
  }) async {
    try {
      final path = 'nasabah/$nasabahId/ktp.jpg';
      await _client.storage.from('gadai-files').uploadBinary(
        path,
        Uint8List.fromList(imageBytes),
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final url = _client.storage.from('gadai-files').getPublicUrl(path);
      await _client.from('gadai_nasabah').update({
        'ktp_photo_url': url,
      }).eq('id', nasabahId);
      debugPrint('[uploadNasabahKtp] OK — $url');
      return url;
    } catch (e) {
      debugPrint('[uploadNasabahKtp ERROR] $e');
      return null;
    }
  }

  /// Ganti password nasabah (verifikasi password lama dulu)
  Future<bool> changeNasabahPassword({
    required String phone,
    required String oldPassword,
    required String newPassword,
  }) async {
    final oldHash = _hashPassword(oldPassword);
    final newHash = _hashPassword(newPassword);

    // Cek password lama (hash dulu, fallback plaintext)
    var accounts = await _client
        .from('gadai_nasabah_accounts')
        .select('id')
        .eq('phone', phone)
        .eq('password', oldHash)
        .limit(1);

    if (accounts.isEmpty) {
      // Fallback plaintext
      accounts = await _client
          .from('gadai_nasabah_accounts')
          .select('id')
          .eq('phone', phone)
          .eq('password', oldPassword)
          .limit(1);
    }

    if (accounts.isEmpty) return false;

    await _client
        .from('gadai_nasabah_accounts')
        .update({'password': newHash})
        .eq('phone', phone);

    return true;
  }

  // ═══════════════════════════════════
  // NASABAH AUTH
  // ═══════════════════════════════════

  // ── Password Hashing ──
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Customer?> loginNasabah(String phone, String password) async {
    final hashedPassword = _hashPassword(password);

    // Coba login dengan password yang sudah di-hash (akun baru)
    var accounts = await _client
        .from('gadai_nasabah_accounts')
        .select()
        .eq('phone', phone)
        .eq('password', hashedPassword)
        .limit(1);

    // Fallback: coba plaintext untuk akun lama (backward compat)
    if (accounts.isEmpty) {
      accounts = await _client
          .from('gadai_nasabah_accounts')
          .select()
          .eq('phone', phone)
          .eq('password', password)
          .limit(1);

      // Jika login plaintext berhasil, migrasi ke hashed
      if (accounts.isNotEmpty) {
        try {
          await _client
              .from('gadai_nasabah_accounts')
              .update({'password': hashedPassword})
              .eq('phone', phone);
        } catch (_) {}
      }
    }

    if (accounts.isEmpty) return null;

    final nasabahId = accounts.first['nasabah_id'] as String;
    return fetchNasabahById(nasabahId);
  }

  Future<void> registerNasabahAccount(String phone, String password, String nasabahId) async {
    final hashedPassword = _hashPassword(password);
    await _client.from('gadai_nasabah_accounts').insert({
      'phone': phone,
      'password': hashedPassword,
      'nasabah_id': nasabahId,
    });
  }

  /// Reset password nasabah oleh Admin (tanpa verifikasi password lama)
  Future<void> adminResetNasabahPassword({
    required String phone,
    required String newPassword,
  }) async {
    final newHash = _hashPassword(newPassword);
    await _client
        .from('gadai_nasabah_accounts')
        .update({'password': newHash})
        .eq('phone', phone);
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
    // Catatan: date_applied TIDAK di-reset di sini — hanya diset saat transaksi dibuat.

    await _client.from('gadai_transactions').update(updates).eq('id', txId);
  }

  /// Upload foto-foto transaksi ke bucket 'gadai-files' dengan struktur folder:
  ///   {txId}/nasabah/ktp.jpg       ← KTP nasabah
  ///   {txId}/nasabah/foto_diri.jpg ← foto nasabah bersama barang
  ///   {txId}/barang/utama.jpg      ← foto barang gadai utama
  ///   {txId}/barang/tambahan.jpg   ← foto barang sudut lain
  ///   {txId}/perjanjian.pdf        ← surat perjanjian (via uploadPerjanjianPdf)
  Future<void> uploadTransactionPhotos({
    required String txId,
    List<int>? fotoBarang,
    List<int>? fotoKtp,
    List<int>? fotoNasabah,
    List<int>? fotoBarangGadai,
    String? note,
  }) async {
    final updates = <String, dynamic>{};

    Future<String?> _uploadFile(String folder, String filename, List<int> bytes) async {
      try {
        final path = '$txId/$folder/$filename';
        await _client.storage.from('gadai-files').uploadBinary(
          path, Uint8List.fromList(bytes),
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
        return _client.storage.from('gadai-files').getPublicUrl(path);
      } catch (e) {
        debugPrint('uploadTransactionPhotos: gagal upload $folder/$filename — $e');
        return null;
      }
    }

    // ── Folder: barang/ ──
    if (fotoBarang != null) {
      final url = await _uploadFile('barang', 'utama.jpg', fotoBarang);
      if (url != null) updates['foto_barang_url'] = url;
    }
    if (fotoBarangGadai != null) {
      final url = await _uploadFile('barang', 'tambahan.jpg', fotoBarangGadai);
      if (url != null) updates['foto_barang_gadai_url'] = url;
    }

    // ── Folder: nasabah/ ──
    if (fotoKtp != null) {
      final url = await _uploadFile('nasabah', 'ktp.jpg', fotoKtp);
      if (url != null) updates['foto_ktp_url'] = url;
    }
    if (fotoNasabah != null) {
      final url = await _uploadFile('nasabah', 'foto_diri.jpg', fotoNasabah);
      if (url != null) updates['foto_nasabah_barang_url'] = url;
    }

    if (note != null && note.trim().isNotEmpty) {
      updates['note'] = note.trim();
    }

    if (updates.isNotEmpty) {
      await _client.from('gadai_transactions').update(updates).eq('id', txId);
    }
  }

  /// Upload PDF perjanjian gadai ke bucket 'gadai-files' dan simpan URL ke DB.
  /// Path: {txId}/perjanjian.pdf
  /// Return: public URL PDF jika berhasil, null jika gagal.
  Future<String?> uploadPerjanjianPdf({
    required String txId,
    required List<int> pdfBytes,
  }) async {
    try {
      const path_in_bucket = 'perjanjian.pdf'; // ignore: non_constant_identifier_names
      final storagePath = '$txId/$path_in_bucket';

      await _client.storage.from('gadai-files').uploadBinary(
        storagePath,
        Uint8List.fromList(pdfBytes),
        fileOptions: const FileOptions(
          contentType: 'application/pdf',
          upsert: true,
        ),
      );

      final publicUrl =
          _client.storage.from('gadai-files').getPublicUrl(storagePath);

      // Simpan URL ke kolom perjanjian_pdf_url (jika kolom ada di tabel)
      try {
        await _client
            .from('gadai_transactions')
            .update({'perjanjian_pdf_url': publicUrl})
            .eq('id', txId);
      } catch (_) {
        // Kolom mungkin belum ada — tidak masalah, tetap return URL
      }

      return publicUrl;
    } catch (e) {
      debugPrint('uploadPerjanjianPdf error: $e');
      return null;
    }
  }

  PawnTransaction _txFromRow(Map<String, dynamic> row) => PawnTransaction(
    id: row['id'] as String,
    transactionCode: row['transaction_code'] as String? ?? '',
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
    dateApplied: row['date_applied'] != null
        ? DateTime.tryParse(row['date_applied'] as String) ?? DateTime.now()
        : DateTime.now(),
    dateDue: row['date_due'] != null
        ? DateTime.tryParse(row['date_due'] as String) ?? DateTime.now()
        : DateTime.now(),
    status: row['status'] as String? ?? 'Aktif',
    // ── Pembayaran Manual ──
    paymentProofUrl: row['payment_proof_url'] as String?,
    paymentRequestedAt: row['payment_requested_at'] != null
        ? DateTime.tryParse(row['payment_requested_at'] as String)
        : null,
    paymentVerifiedAt: row['payment_verified_at'] != null
        ? DateTime.tryParse(row['payment_verified_at'] as String)
        : null,
    paymentVerifiedBy: row['payment_verified_by'] as String?,
    paymentType: row['payment_type'] as String?,
    paymentPeriodDays: row['payment_period_days'] as int?,
    paymentRejectReason: row['payment_reject_reason'] as String?,
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
        .inFilter('role', ['admin', 'superadmin'])
        .order('created_at', ascending: false);

    return data.map<Map<String, String>>((row) {
      final gadaiRole = (row['role'] as String? ?? '') == 'superadmin'
          ? 'super_admin'
          : 'admin_cabang';
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
  // REKENING GADAI (persisten ke Supabase)
  // ═══════════════════════════════════

  /// Ambil saldo wallet dari tabel gadai_wallet berdasarkan branchId
  Future<int> fetchWalletBalance(String branchId) async {
    try {
      final data = await _client
          .from('gadai_wallet')
          .select('balance')
          .eq('branch_id', branchId)
          .limit(1);
      if (data.isEmpty) return 0;
      return (data.first['balance'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Top up saldo wallet cabang
  Future<void> walletTopUp(String branchId, int amount, String description) async {
    try {
      // Upsert balance
      await _client.rpc('gadai_wallet_topup', params: {
        'p_branch_id': branchId,
        'p_amount': amount,
      });
      // Insert mutasi
      await _client.from('gadai_wallet_mutations').insert({
        'branch_id': branchId,
        'type': 'Kredit',
        'amount': amount,
        'description': description,
      });
    } catch (_) {}
  }

  /// Debit / keluar kas cabang — kurangi saldo, tolak jika saldo tidak cukup
  Future<String?> walletDebit(String branchId, int amount, String description) async {
    try {
      // Cek saldo terlebih dahulu
      final currentBalance = await fetchWalletBalance(branchId);
      if (currentBalance < amount) {
        return 'Saldo kas tidak cukup (Saldo: Rp ${_formatCurrencySvc(currentBalance)})';
      }
      // Kurangi saldo
      await _client.rpc('gadai_wallet_topup', params: {
        'p_branch_id': branchId,
        'p_amount': -amount, // negatif = debit
      });
      // Insert mutasi
      await _client.from('gadai_wallet_mutations').insert({
        'branch_id': branchId,
        'type': 'Debit',
        'amount': amount,
        'description': description,
      });
      return null; // sukses
    } catch (e) {
      return 'Gagal: $e';
    }
  }

  String _formatCurrencySvc(int val) {
    final s = val.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }


  /// Ambil riwayat mutasi wallet
  Future<List<Map<String, dynamic>>> fetchWalletMutations(String branchId) async {
    try {
      final data = await _client
          .from('gadai_wallet_mutations')
          .select()
          .eq('branch_id', branchId)
          .order('created_at', ascending: false)
          .limit(50);
      return data.map<Map<String, dynamic>>((row) => {
        'date': DateTime.parse(row['created_at'] as String),
        'type': row['type'] as String,
        'amount': (row['amount'] as num).toInt(),
        'desc': row['description'] as String? ?? '',
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════
  // SYSTEM CONFIG (persisten ke Supabase)
  // ═══════════════════════════════════

  /// Load konfigurasi sistem dari tabel gadai_config
  Future<Map<String, dynamic>> fetchSystemConfig() async {
    try {
      final data = await _client.from('gadai_config').select();
      final Map<String, dynamic> config = {};
      for (final row in data) {
        final key = row['key'] as String;
        final value = row['value'];
        config[key] = value;
      }
      return config;
    } catch (_) {
      return {};
    }
  }

  /// Simpan satu parameter konfigurasi
  Future<void> saveConfigParam(String key, String value) async {
    try {
      await _client.from('gadai_config').upsert({
        'key': key,
        'value': value,
      }, onConflict: 'key');
    } catch (_) {}
  }

  /// Simpan semua parameter konfigurasi sekaligus
  Future<void> saveSystemConfig({
    required int tariffPerUnit,
    required int unitAmount,
    required int minTenor,
    required int maxTenor,
    required int alertDays,
  }) async {
    try {
      final configs = [
        {'key': 'tariff_per_unit', 'value': tariffPerUnit.toString()},
        {'key': 'unit_amount', 'value': unitAmount.toString()},
        {'key': 'min_tenor', 'value': minTenor.toString()},
        {'key': 'max_tenor', 'value': maxTenor.toString()},
        {'key': 'alert_days', 'value': alertDays.toString()},
      ];
      for (final cfg in configs) {
        await _client.from('gadai_config').upsert(cfg, onConflict: 'key');
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════
  // AUTO MARK OVERDUE TRANSACTIONS
  // ═══════════════════════════════════

  /// Update transaksi Aktif yang sudah lewat jatuh tempo menjadi Macet
  Future<void> markOverdueTransactions({String? branchId}) async {
    try {
      final now = DateTime.now().toIso8601String();
      var query = _client
          .from('gadai_transactions')
          .update({'status': 'Macet'})
          .lt('date_due', now)
          .eq('status', 'Aktif');
      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }
      await query;
    } catch (_) {}
  }

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

  Future<void> saveNasabahSession(String nasabahId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_nasabah_id', nasabahId);
    } catch (e) {
      debugPrint('saveNasabahSession error: $e');
    }
  }

  Future<Customer?> getCurrentNasabah() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nasabahId = prefs.getString('saved_nasabah_id');
      if (nasabahId == null || nasabahId.isEmpty) return null;
      return await fetchNasabahById(nasabahId);
    } catch (e) {
      debugPrint('getCurrentNasabah error: $e');
      return null;
    }
  }

  Future<void> clearNasabahSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_nasabah_id');
    } catch (e) {
      debugPrint('clearNasabahSession error: $e');
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await clearNasabahSession();
  }

  // ═══════════════════════════════════════════════════════
  // ACTIVITY LOG
  // ═══════════════════════════════════════════════════════

  /// Tulis satu entri log ke Supabase. Fire-and-forget — error diabaikan agar
  /// tidak mengganggu alur utama.
  Future<bool> logActivity({
    required String userId,
    required String role,
    required String action,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.from('gadai_activity_logs').insert({
        'user_id': userId,
        'role': role,
        'action': action,
        'description': description,
        if (metadata != null) 'metadata': metadata,
      });
      return true;
    } catch (e) {
      // Tampilkan error agar bisa didiagnosis lewat flutter run console
      debugPrint('[ActivityLog ERROR] action=$action userId=$userId → $e');
      return false;
    }
  }

  // ── Convenience wrappers ─────────────────────────────────

  Future<bool> logNasabahLogin(String nasabahId, String name) => logActivity(
        userId: nasabahId,
        role: 'nasabah',
        action: 'LOGIN_SUCCESS',
        description: 'Nasabah "$name" berhasil login.',
      );

  Future<bool> logNasabahLoginFailed(String phone) => logActivity(
        userId: phone,
        role: 'nasabah',
        action: 'LOGIN_FAILED',
        description: 'Percobaan login gagal untuk nomor HP: $phone.',
      );

  Future<bool> logNasabahLogout(String nasabahId, String name) => logActivity(
        userId: nasabahId,
        role: 'nasabah',
        action: 'LOGOUT',
        description: 'Nasabah "$name" logout.',
      );

  Future<bool> logNasabahRegister(String nasabahId, String name, String phone) =>
      logActivity(
        userId: nasabahId,
        role: 'nasabah',
        action: 'REGISTER',
        description: 'Akun nasabah baru dibuat: "$name" (HP: $phone).',
      );

  Future<bool> logNasabahPasswordChange(String nasabahId, String name) =>
      logActivity(
        userId: nasabahId,
        role: 'nasabah',
        action: 'CHANGE_PASSWORD',
        description: 'Nasabah "$name" mengganti password.',
      );

  Future<bool> logNasabahProfileUpdate(
          String nasabahId, String name, List<String> changedFields) =>
      logActivity(
        userId: nasabahId,
        role: 'nasabah',
        action: 'UPDATE_PROFILE',
        description: 'Nasabah "$name" memperbarui profil: ${changedFields.join(", ")}.',
        metadata: {'changed_fields': changedFields},
      );

  Future<bool> logAdminCreateNasabah(
          String adminId, String nasabahName, String phone) =>
      logActivity(
        userId: adminId,
        role: 'admin',
        action: 'ADMIN_CREATE_NASABAH',
        description: 'Admin membuat akun nasabah baru: "$nasabahName" (HP: $phone).',
        metadata: {'nasabah_name': nasabahName, 'phone': phone},
      );

  Future<bool> logAdminUpdateNasabah(
          String adminId, String nasabahName, String phone) =>
      logActivity(
        userId: adminId,
        role: 'admin',
        action: 'ADMIN_UPDATE_NASABAH',
        description: 'Admin memperbarui profil nasabah: "$nasabahName" (HP: $phone).',
        metadata: {'nasabah_name': nasabahName, 'phone': phone},
      );

  Future<bool> logAdminResetPassword(String adminId, String nasabahPhone) =>
      logActivity(
        userId: adminId,
        role: 'admin',
        action: 'ADMIN_RESET_PASSWORD',
        description: 'Admin mereset password nasabah HP: $nasabahPhone.',
        metadata: {'target_phone': nasabahPhone},
      );

  Future<bool> logTransaksiCreated(
          String userId, String txId, String namaJaminan, int principal) =>
      logActivity(
        userId: userId,
        role: 'nasabah',
        action: 'TRANSAKSI_CREATED',
        description:
            'Gadai baru dibuat: TX-$txId, jaminan "$namaJaminan", pokok Rp $principal.',
        metadata: {'tx_id': txId, 'principal': principal},
      );

  Future<bool> logExtensionRequested(String nasabahId, String txId) =>
      logActivity(
        userId: nasabahId,
        role: 'nasabah',
        action: 'EXTENSION_REQUESTED',
        description: 'Nasabah mengajukan perpanjangan untuk transaksi TX-$txId.',
        metadata: {'tx_id': txId},
      );

  Future<bool> logNasabahRedeemed(String nasabahId, String txId, String brandModel, int totalPay) =>
      logActivity(
        userId: nasabahId,
        role: 'nasabah',
        action: 'TRANSAKSI_REDEEMED',
        description: 'Nasabah menebus jaminan "$brandModel" sebesar Rp $totalPay (Lunas).',
        metadata: {'tx_id': txId, 'amount': totalPay},
      );

  Future<bool> logTransaksiUpdated({
    required String userId,
    required String role,
    required String txId,
    required String description,
    required Map<String, dynamic> changes,
  }) =>
      logActivity(
        userId: userId,
        role: role,
        action: 'TRANSAKSI_UPDATED',
        description: description,
        metadata: {'tx_id': txId, 'changes': changes},
      );

  Future<bool> logTransaksiCancelled({
    required String userId,
    required String role,
    required String txId,
    required String reason,
  }) =>
      logActivity(
        userId: userId,
        role: role,
        action: 'TRANSAKSI_CANCELLED',
        description: 'Transaksi gadai dibatalkan. Alasan: $reason',
        metadata: {'tx_id': txId, 'reason': reason},
      );

  Future<bool> logTransaksiLelang({
    required String userId,
    required String role,
    required String txId,
    required String brandModel,
    required int price,
  }) =>
      logActivity(
        userId: userId,
        role: role,
        action: 'TRANSAKSI_LELANG',
        description: 'Barang jaminan "$brandModel" berhasil dilelang seharga Rp $price.',
        metadata: {'tx_id': txId, 'amount': price},
      );

  Future<List<Map<String, dynamic>>> fetchLelangLogs() async {
    try {
      final data = await _client
          .from('gadai_activity_logs')
          .select()
          .eq('action', 'TRANSAKSI_LELANG');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[ActivityLog FETCH LELANG ERROR] $e');
      return [];
    }
  }

  Future<void> createLelangHistory(String transactionId, int hargaLelang) async {
    await _client.from('gadai_lelang_history').insert({
      'transaction_id': transactionId,
      'harga_lelang': hargaLelang,
    });
  }

  Future<List<LelangHistory>> fetchLelangHistory() async {
    try {
      final data = await _client.from('gadai_lelang_history').select();
      return data.map<LelangHistory>((row) => LelangHistory(
        id: row['id'] as String,
        transactionId: row['transaction_id'] as String,
        hargaLelang: (row['harga_lelang'] as num).toInt(),
        tglLelang: DateTime.parse(row['tgl_lelang'] as String),
      )).toList();
    } catch (e) {
      debugPrint('[LelangHistory FETCH ERROR] $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchActivityLogsByTransaction(String txId) async {
    try {
      // Bug Fix: gunakan filter server-side (contains) daripada fetch semua lalu filter di client
      final data = await _client
          .from('gadai_activity_logs')
          .select()
          .contains('metadata', {'tx_id': txId})
          .order('created_at', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[ActivityLog FETCH BY TX ERROR] $e');
      return [];
    }
  }

  // ── Fetch log entries ────────────────────────────────────

  /// Ambil semua log aktivitas, terbaru dulu
  Future<List<Map<String, dynamic>>> fetchActivityLogs({int limit = 200}) async {
    try {
      final data = await _client
          .from('gadai_activity_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      debugPrint('[ActivityLog] Fetched ${data.length} log entries');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[ActivityLog FETCH ERROR] $e');
      return [];
    }
  }

  /// Ambil log aktivitas untuk user tertentu (nasabahId)
  Future<List<Map<String, dynamic>>> fetchActivityLogsByUser(
      String userId, {int limit = 100}) async {
    try {
      final data = await _client
          .from('gadai_activity_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════
  // ADMIN PASSWORD MANAGEMENT (Tahap 4)
  // ═══════════════════════════════════

  /// Super admin reset password staff/admin via Supabase RPC.
  Future<void> updateStaffPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await _client.rpc('admin_reset_password', params: {
        'p_user_id': userId,
        'p_new_password': newPassword,
      });
    } catch (e) {
      throw Exception('Gagal reset password: ${e}\nPastikan RPC admin_reset_password sudah dibuat di Supabase.');
    }
  }

  // ═══════════════════════════════════
  // KAS MANAGEMENT (Tahap 5)
  // ═══════════════════════════════════

  /// Ambil semua entri kas, opsional filter per cabang
  Future<List<Map<String, dynamic>>> fetchKas({String? cabangId}) async {
    try {
      if (cabangId != null && cabangId.isNotEmpty) {
        final data = await _client
            .from('gadai_kas')
            .select()
            .eq('cabang_id', cabangId)
            .order('tanggal', ascending: false)
            .order('created_at', ascending: false)
            .limit(500);
        return List<Map<String, dynamic>>.from(data);
      } else {
        final data = await _client
            .from('gadai_kas')
            .select()
            .order('tanggal', ascending: false)
            .order('created_at', ascending: false)
            .limit(500);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('[Kas FETCH ERROR] $e');
      return [];
    }
  }

  /// Tambah entri kas baru
  Future<void> addKasEntry({
    required String cabangId,
    required String jenis, // 'masuk' atau 'keluar'
    required String kategori,
    required int jumlah,
    required String keterangan,
    required String tanggal, // format: 'YYYY-MM-DD'
    String? createdBy,
  }) async {
    await _client.from('gadai_kas').insert({
      'cabang_id': cabangId,
      'jenis': jenis,
      'kategori': kategori,
      'jumlah': jumlah,
      'keterangan': keterangan,
      'tanggal': tanggal,
      'created_by': createdBy ?? 'super_admin',
    });
  }

  /// Hapus entri kas
  Future<void> deleteKasEntry(String kasId) async {
    await _client.from('gadai_kas').delete().eq('id', kasId);
  }

  /// Hitung saldo kas per cabang (total masuk - total keluar)
  Future<Map<String, int>> fetchKasSaldo() async {
    try {
      final data = await _client.from('gadai_kas').select('cabang_id, jenis, jumlah');
      final Map<String, int> saldo = {};
      for (final row in data) {
        final cabId = row['cabang_id'] as String;
        final jenis = row['jenis'] as String;
        final jumlah = (row['jumlah'] as num).toInt();
        saldo[cabId] = (saldo[cabId] ?? 0) + (jenis == 'masuk' ? jumlah : -jumlah);
      }
      return saldo;
    } catch (e) {
      debugPrint('[Kas SALDO ERROR] $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════
  // REKENING GADAI
  // ═══════════════════════════════════════════════════════════

  /// Ambil daftar rekening bank gadai yang aktif (dapat difilter berdasarkan cabang)
  Future<List<RekeningGadai>> fetchRekeningGadai({String? branchId}) async {
    try {
      final data = await _client
          .from('gadai_rekening')
          .select()
          .eq('is_active', true)
          .order('created_at');

      final allActive = data.map<RekeningGadai>((row) {
        final cab = row['branch_id'] as String? ?? row['cabang_id'] as String?;
        return RekeningGadai(
          id: row['id'] as String,
          bankName: row['bank_name'] as String,
          accountNumber: row['account_number'] as String,
          accountName: row['account_name'] as String,
          isActive: row['is_active'] as bool? ?? true,
          branchId: (cab == null || cab.isEmpty || cab == 'all') ? null : cab,
          qrisImageUrl: row['qris_image_url'] as String? ?? '',
        );
      }).toList();

      if (branchId != null && branchId.isNotEmpty) {
        // Ambil rekening khusus cabang INI dan juga rekening UMUM/GLOBAL (branchId == null)
        final applicable = allActive.where((r) => r.branchId == branchId || r.branchId == null).toList();
        if (applicable.isNotEmpty) {
          return applicable;
        }
      }

      return allActive;
    } catch (e) {
      debugPrint('[RekeningGadai FETCH ERROR] $e');
      return [];
    }
  }

  /// Ambil seluruh rekening bank gadai (aktif & non-aktif) untuk Super Admin
  Future<List<RekeningGadai>> fetchAllRekeningGadaiAdmin() async {
    try {
      final data = await _client
          .from('gadai_rekening')
          .select()
          .order('created_at', ascending: false);

      return data.map<RekeningGadai>((row) {
        final cab = row['branch_id'] as String? ?? row['cabang_id'] as String?;
        return RekeningGadai(
          id: row['id'] as String,
          bankName: row['bank_name'] as String,
          accountNumber: row['account_number'] as String,
          accountName: row['account_name'] as String,
          isActive: row['is_active'] as bool? ?? true,
          branchId: (cab == null || cab.isEmpty || cab == 'all') ? null : cab,
          qrisImageUrl: row['qris_image_url'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('[RekeningGadai ADMIN FETCH ERROR] $e');
      return [];
    }
  }

  /// Simpan rekening baru per cabang (superadmin) — mengembalikan ID baru
  Future<String?> saveRekeningGadai({
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? branchId,
  }) async {
    final payload = <String, dynamic>{
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'is_active': true,
      'branch_id': (branchId == null || branchId == 'all' || branchId.isEmpty) ? null : branchId,
    };
    try {
      final res = await _client.from('gadai_rekening').insert(payload).select('id').single();
      return res['id'] as String?;
    } catch (e) {
      if (e.toString().contains('branch_id') || e.toString().contains('cabang_id') || e.toString().contains('PGRST204')) {
        payload.remove('branch_id');
        payload.remove('cabang_id');
        final res = await _client.from('gadai_rekening').insert(payload).select('id').single();
        return res['id'] as String?;
      }
      rethrow;
    }
  }

  /// Update rekening (superadmin)
  Future<void> updateRekeningGadai({
    required String id,
    required String bankName,
    required String accountNumber,
    required String accountName,
    required bool isActive,
    String? branchId,
  }) async {
    final payload = <String, dynamic>{
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'is_active': isActive,
      'branch_id': (branchId == null || branchId == 'all' || branchId.isEmpty) ? null : branchId,
    };
    try {
      await _client.from('gadai_rekening').update(payload).eq('id', id);
    } catch (e) {
      if (e.toString().contains('branch_id') || e.toString().contains('cabang_id') || e.toString().contains('PGRST204')) {
        payload.remove('branch_id');
        payload.remove('cabang_id');
        await _client.from('gadai_rekening').update(payload).eq('id', id);
        return;
      }
      rethrow;
    }
  }

  /// Hapus rekening (superadmin)
  Future<void> deleteRekeningGadai(String id) async {
    await _client.from('gadai_rekening').delete().eq('id', id);
  }

  /// Upload gambar QRIS ke storage dan simpan URL ke gadai_rekening
  /// Path: qris/{rekeningId}.jpg
  Future<String?> uploadQrisImage({
    required String rekeningId,
    required List<int> imageBytes,
  }) async {
    try {
      final path = 'qris/$rekeningId.jpg';
      await _client.storage.from('gadai-files').uploadBinary(
        path,
        Uint8List.fromList(imageBytes),
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final url = _client.storage.from('gadai-files').getPublicUrl(path);
      await _client.from('gadai_rekening').update({'qris_image_url': url}).eq('id', rekeningId);
      debugPrint('[uploadQrisImage] OK — $url');
      return url;
    } catch (e) {
      debugPrint('[uploadQrisImage ERROR] $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PEMBAYARAN MANUAL
  // ═══════════════════════════════════════════════════════════

  /// Nasabah submit bukti pembayaran — upload foto ke storage & update status
  /// [paymentType]: 'perpanjang' atau 'tebus'
  /// [periodDays]: periode tenor yang dipilih (hanya untuk perpanjang)
  Future<void> submitPaymentProof({
    required String txId,
    required List<int> proofImageBytes,
    required String paymentType,
    int? periodDays,
  }) async {
    // 1. Upload foto bukti ke storage
    final path = '$txId/payment_proof/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('gadai-files').uploadBinary(
      path,
      Uint8List.fromList(proofImageBytes),
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    final proofUrl = _client.storage.from('gadai-files').getPublicUrl(path);

    // 2. Update transaksi — status → Menunggu Verifikasi
    final updates = <String, dynamic>{
      'status': 'Menunggu Verifikasi',
      'payment_proof_url': proofUrl,
      'payment_requested_at': DateTime.now().toIso8601String(),
      'payment_type': paymentType,
      'payment_reject_reason': null,
    };
    if (periodDays != null) updates['payment_period_days'] = periodDays;
    await _client.from('gadai_transactions').update(updates).eq('id', txId);
  }

  /// Ambil semua transaksi dengan status 'Menunggu Verifikasi' beserta nama nasabah
  Future<List<PawnTransaction>> fetchPendingPayments({String? branchId}) async {
    try {
      List<Map<String, dynamic>> data;
      // Join dengan gadai_nasabah untuk mendapatkan nama nasabah
      // gadai_transactions.nasabah_id → gadai_nasabah.id
      const selectQuery = '*, gadai_nasabah!nasabah_id(name)';

      if (branchId != null && branchId.isNotEmpty) {
        data = await _client
            .from('gadai_transactions')
            .select(selectQuery)
            .eq('status', 'Menunggu Verifikasi')
            .eq('branch_id', branchId)
            .order('payment_requested_at', ascending: true);
      } else {
        data = await _client
            .from('gadai_transactions')
            .select(selectQuery)
            .eq('status', 'Menunggu Verifikasi')
            .order('payment_requested_at', ascending: true);
      }
      return data.map<PawnTransaction>((row) {
        final tx = _txFromRow(row);
        // Ambil nama nasabah dari join result
        final nasabahData = row['gadai_nasabah'];
        if (nasabahData != null && nasabahData is Map) {
          tx.nasabahName = nasabahData['name'] as String? ?? '';
        }
        return tx;
      }).toList();
    } catch (e) {
      debugPrint('[fetchPendingPayments ERROR] $e');
      return [];
    }
  }

  /// Admin verifikasi pembayaran perpanjang tenor
  /// Menggunakan RPC agar extension_history juga diisi atomic
  Future<void> verifyPerpanjangPayment({
    required String txId,
    required String adminId,
    required DateTime newDueDate,
    required int periodDays,
    required int totalFee,
    required int totalRepayment,
  }) async {
    await _client.rpc('verify_perpanjang_payment', params: {
      'p_tx_id': txId,
      'p_admin_id': adminId,
      'p_new_due_date': newDueDate.toIso8601String(),
      'p_period_days': periodDays,
      'p_total_fee': totalFee,
      'p_total_repayment': totalRepayment,
    });
  }

  /// Admin verifikasi pembayaran tebus barang
  Future<void> verifyTebusPayment({
    required String txId,
    required String adminId,
  }) async {
    await _client.rpc('verify_tebus_payment', params: {
      'p_tx_id': txId,
      'p_admin_id': adminId,
    });
  }

  /// Admin tolak pembayaran (kembalikan ke status sebelumnya)
  Future<void> rejectPayment({
    required String txId,
    required String reason,
    required String previousStatus,
  }) async {
    await _client.from('gadai_transactions').update({
      'status': previousStatus,
      'payment_proof_url': null,
      'payment_requested_at': null,
      'payment_type': null,
      'payment_period_days': null,
      'payment_reject_reason': reason,
    }).eq('id', txId);
  }

  /// Subscribe realtime ke perubahan status transaksi (untuk admin)
  RealtimeChannel subscribeToPaymentRequests({
    required String branchId,
    required void Function(PawnTransaction tx) onNewPayment,
    required void Function(PawnTransaction tx) onPaymentUpdated,
  }) {
    final channel = _client
        .channel('payment-requests-$branchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'gadai_transactions',
          filter: branchId.isNotEmpty
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'branch_id',
                  value: branchId,
                )
              : null,
          callback: (payload) {
            try {
              final row = Map<String, dynamic>.from(payload.newRecord);
              final tx = _txFromRow(row);
              if (tx.status == 'Menunggu Verifikasi') {
                onNewPayment(tx);
              } else if (tx.status == 'Aktif' ||
                  tx.status == 'Menunggu Pengambilan') {
                onPaymentUpdated(tx);
              }
            } catch (e) {
              debugPrint('[RealtimePayment] parse error: $e');
            }
          },
        )
        .subscribe();
    return channel;
  }

  /// Subscribe realtime ke transaksi nasabah tertentu (untuk nasabah lihat status update)
  RealtimeChannel subscribeToTransactionUpdates({
    required String txId,
    required void Function(PawnTransaction tx) onUpdate,
  }) {
    final channel = _client
        .channel('tx-updates-$txId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'gadai_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: txId,
          ),
          callback: (payload) {
            try {
              final row = Map<String, dynamic>.from(payload.newRecord);
              onUpdate(_txFromRow(row));
            } catch (e) {
              debugPrint('[RealtimeTx] parse error: $e');
            }
          },
        )
        .subscribe();
    return channel;
  }

  /// Log aktivitas — pembayaran disubmit nasabah
  Future<bool> logPaymentSubmitted(String nasabahId, String txId, String paymentType) =>
      logActivity(
        userId: nasabahId,
        role: 'nasabah',
        action: 'PAYMENT_SUBMITTED',
        description: 'Nasabah mengirim bukti pembayaran untuk TX-$txId (tipe: $paymentType).',
        metadata: {'tx_id': txId, 'payment_type': paymentType},
      );

  /// Log aktivitas — pembayaran diverifikasi admin
  Future<bool> logPaymentVerified(String adminId, String txId, String paymentType) =>
      logActivity(
        userId: adminId,
        role: 'admin',
        action: 'PAYMENT_VERIFIED',
        description: 'Admin memverifikasi pembayaran TX-$txId (tipe: $paymentType).',
        metadata: {'tx_id': txId, 'payment_type': paymentType},
      );

  /// Log aktivitas — pembayaran ditolak admin
  Future<bool> logPaymentRejected(String adminId, String txId, String reason) =>
      logActivity(
        userId: adminId,
        role: 'admin',
        action: 'PAYMENT_REJECTED',
        description: 'Admin menolak pembayaran TX-$txId. Alasan: $reason',
        metadata: {'tx_id': txId, 'reason': reason},
      );
}
