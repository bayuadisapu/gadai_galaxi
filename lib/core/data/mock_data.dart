class Customer {
  final String id;
  final String name;
  final String nik;
  final String birthPlace;
  final String birthDate;
  final String gender;
  final String phone;
  final String address;

  Customer({
    required this.id,
    required this.name,
    required this.nik,
    required this.birthPlace,
    required this.birthDate,
    required this.gender,
    required this.phone,
    required this.address,
  });
}

class PawnTransaction {
  final String id;
  final String customerId;
  final String collateralType;
  final String brand;
  final String model;
  final String condition;
  final int principal;
  final int periodDays;
  final int dailyFee;
  int totalFee;
  int totalRepayment;
  DateTime dateApplied;
  DateTime dateDue;
  String status; // 'Pending', 'Aktif', 'Perlu_Bayar_Jatip', 'Lunas', 'Macet'

  PawnTransaction({
    required this.id,
    required this.customerId,
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
  });

  void extendTenor(int additionalDays) {
    // Under rollover logic:
    // 1. Due date shifts by additionalDays
    dateDue = dateDue.add(Duration(days: additionalDays));
    // 2. Accumulation of current fee resets or calculates new one. We can keep it active with new due date.
    // 3. Status remains 'Aktif'
    status = 'Aktif';
  }

  void redeem() {
    status = 'Lunas';
  }
}

// Global shared mock data lists
final List<Customer> mockCustomers = [
  Customer(
    id: 'C001',
    name: 'Ahmad Fauzi',
    nik: '3578011204950001',
    birthPlace: 'Surabaya',
    birthDate: '12 Apr 1995',
    gender: 'Laki-laki',
    phone: '081234567890',
    address: 'Jl. Dharmahusada Indah No. 12, Surabaya',
  ),
  Customer(
    id: 'C002',
    name: 'Siti Aminah',
    nik: '3578022308970003',
    birthPlace: 'Sidoarjo',
    birthDate: '23 Agt 1997',
    gender: 'Perempuan',
    phone: '082345678901',
    address: 'Perumahan Gading Fajar Blok B2/15, Sidoarjo',
  ),
  Customer(
    id: 'C003',
    name: 'Budi Santoso',
    nik: '3578031510900002',
    birthPlace: 'Gresik',
    birthDate: '15 Okt 1990',
    gender: 'Laki-laki',
    phone: '085678901234',
    address: 'Jl. Dr. Sutomo No. 45, Gresik',
  ),
];

final List<PawnTransaction> mockTransactions = [
  PawnTransaction(
    id: 'TX-2026-0001',
    customerId: 'C001',
    collateralType: 'Handphone',
    brand: 'Apple',
    model: 'iPhone 13 Pro Max',
    condition: 'Mulus (95%+)',
    principal: 5000000,
    periodDays: 15,
    dailyFee: 50000, // 5.000.000 / 500.000 = 10 * 5.000 = 50.000
    totalFee: 750000,
    totalRepayment: 5750000,
    dateApplied: DateTime.now().subtract(const Duration(days: 10)),
    dateDue: DateTime.now().add(const Duration(days: 5)),
    status: 'Aktif',
  ),
  PawnTransaction(
    id: 'TX-2026-0002',
    customerId: 'C002',
    collateralType: 'Emas',
    brand: 'Antam',
    model: 'Emas Batangan 10 gram',
    condition: 'Sertifikat Lengkap',
    principal: 8000000,
    periodDays: 30,
    dailyFee: 80000, // 8.000.000 / 500.000 = 16 * 5.000 = 80.000
    totalFee: 2400000,
    totalRepayment: 10400000,
    dateApplied: DateTime.now().subtract(const Duration(days: 15)),
    dateDue: DateTime.now().add(const Duration(days: 15)),
    status: 'Aktif',
  ),
  PawnTransaction(
    id: 'TX-2026-0003',
    customerId: 'C003',
    collateralType: 'Motor / Mobil',
    brand: 'Honda',
    model: 'Vario 150 CBS',
    condition: 'Lecet Pemakaian',
    principal: 12000000,
    periodDays: 15,
    dailyFee: 120000, // 12.000.000 / 500.000 = 24 * 5.000 = 120.000
    totalFee: 1800000,
    totalRepayment: 13800000,
    dateApplied: DateTime.now().subtract(const Duration(days: 20)),
    dateDue: DateTime.now().subtract(const Duration(days: 5)), // past due
    status: 'Macet',
  ),
];
