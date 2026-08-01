// ═══════════════════════════════════════════════════
//  DATA MODELS — used by Supabase service & UI
// ═══════════════════════════════════════════════════

// ── Model: Cabang ──
class Cabang {
  final String id;
  final String nama;
  final String kode;
  String admin;
  String status; // 'Aktif', 'Tidak Aktif'

  Cabang({
    required this.id,
    required this.nama,
    required this.kode,
    required this.admin,
    this.status = 'Aktif',
  });
}

// ── Model: Customer (Nasabah Gadai) ──
class Customer {
  final String id;
  final String name;
  final String nik;
  final String birthPlace;
  final String birthDate;
  final String gender;
  final String phone;
  final String address;
  final String cabangId;
  final String ktpPhotoUrl;  // URL foto KTP nasabah

  Customer({
    required this.id,
    required this.name,
    required this.nik,
    required this.birthPlace,
    required this.birthDate,
    required this.gender,
    required this.phone,
    required this.address,
    this.cabangId = '',
    this.ktpPhotoUrl = '',
  });
}

// ── Model: PawnTransaction ──
class PawnTransaction {
  final String id;
  final String transactionCode; // Format: GDI-2026-0001
  final String customerId;
  final String cabangId;
  final String collateralType;
  final String brand;
  final String model;
  final String condition;
  final int principal;
  int periodDays;
  final int dailyFee;
  int totalFee;
  int totalRepayment;
  DateTime dateApplied;
  DateTime dateDue;
  String status; // 'Aktif', 'Lunas', 'Macet', 'Menunggu Verifikasi', 'Menunggu Pengambilan'

  // ── Pembayaran Manual ──
  String? paymentProofUrl;        // URL foto bukti transfer
  DateTime? paymentRequestedAt;   // Waktu nasabah submit bukti
  DateTime? paymentVerifiedAt;    // Waktu admin verifikasi
  String? paymentVerifiedBy;      // Admin ID yang memverifikasi
  String? paymentType;            // 'perpanjang' | 'tebus'
  int? paymentPeriodDays;         // Periode yang dipilih (untuk perpanjang)
  String? paymentRejectReason;    // Alasan ditolak (jika ada)

  // ── Denormalized (diisi saat join/lookup) ──
  String nasabahName;             // Nama nasabah (dari tabel gadai_nasabah_accounts)

  PawnTransaction({
    required this.id,
    this.transactionCode = '',
    required this.customerId,
    this.cabangId = '',
    required this.collateralType,
    required this.brand,
    required this.model,
    required this.condition,
    required this.principal,
    required this.periodDays,
    required this.dailyFee,
    required this.totalFee,
    required this.totalRepayment,
    required this.dateApplied,
    required this.dateDue,
    required this.status,
    this.paymentProofUrl,
    this.paymentRequestedAt,
    this.paymentVerifiedAt,
    this.paymentVerifiedBy,
    this.paymentType,
    this.paymentPeriodDays,
    this.paymentRejectReason,
    this.nasabahName = '',
  });

  /// Nomor transaksi yang ditampilkan ke user.
  /// Gunakan transactionCode jika ada, fallback ke 8 karakter pertama UUID.
  String get displayCode =>
      transactionCode.isNotEmpty ? transactionCode : 'GDI-${id.substring(0, 8).toUpperCase()}';

  /// Apakah transaksi sedang menunggu verifikasi pembayaran
  bool get isAwaitingVerification => status == 'Menunggu Verifikasi';

  void extendTenor(int additionalDays) {
    dateDue = dateDue.add(Duration(days: additionalDays));
    status = 'Aktif';
  }

  void redeem() {
    status = 'Lunas';
  }
}

// ── Model: ExtensionHistory ──
class ExtensionHistory {
  final String id;
  final String transactionId;
  final int jatipDibayar;
  final DateTime tglPerpanjangan;
  final DateTime tglTempoLama;
  final DateTime tglTempoBaru;

  ExtensionHistory({
    required this.id,
    required this.transactionId,
    required this.jatipDibayar,
    required this.tglPerpanjangan,
    required this.tglTempoLama,
    required this.tglTempoBaru,
  });
}

// ── Model: LelangHistory ──
class LelangHistory {
  final String id;
  final String transactionId;
  final int hargaLelang;
  final DateTime tglLelang;

  LelangHistory({
    required this.id,
    required this.transactionId,
    required this.hargaLelang,
    required this.tglLelang,
  });
}

// ── Model: RekeningGadai ──
class RekeningGadai {
  final String id;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final bool isActive;
  final String? branchId;
  final String qrisImageUrl; // URL gambar QRIS (kosong jika belum ada)

  RekeningGadai({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.isActive = true,
    this.branchId,
    this.qrisImageUrl = '',
  });
}
