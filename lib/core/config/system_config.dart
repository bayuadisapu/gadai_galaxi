class SystemConfig {
  static int tariffPerUnit = 5000;
  static int unitAmount = 500000;
  static int minTenor = 15;
  static int maxTenor = 30;
  static int alertDays = 3;

  /// Calculates daily fee based on principal amount.
  /// Standard calculation: (principal / unitAmount).ceil() * tariffPerUnit
  static int calculateDailyFee(int principal) {
    if (principal <= 0) return 0;
    return (principal / unitAmount).ceil() * tariffPerUnit;
  }
}

class TenantWallet {
  static int balance = 7000;
  static List<Map<String, dynamic>> mutations = [
    {
      'date': DateTime(2026, 6, 25, 10, 30),
      'type': 'Kredit',
      'amount': 10000,
      'desc': 'Top Up Awal',
    },
    {
      'date': DateTime(2026, 6, 25, 14, 20),
      'type': 'Debet',
      'amount': 3000,
      'desc': 'Bayar Administrasi Gadai',
    },
  ];

  static void topUp(int amount, String description) {
    balance += amount;
    mutations.insert(0, {
      'date': DateTime.now(),
      'type': 'Kredit',
      'amount': amount,
      'desc': description,
    });
  }

  static void pay(int amount, String description) {
    balance -= amount;
    mutations.insert(0, {
      'date': DateTime.now(),
      'type': 'Debet',
      'amount': amount,
      'desc': description,
    });
  }
}
