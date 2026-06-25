import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';

class Step2FinanceView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController pawnAmountController;
  final String selectedPeriod;
  final ValueChanged<String?> onPeriodChanged;
  final VoidCallback onAmountChanged;
  final int maxTaksiran;

  const Step2FinanceView({
    super.key,
    required this.formKey,
    required this.pawnAmountController,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onAmountChanged,
    required this.maxTaksiran,
  });

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

  int get _pawnAmountValue {
    final cleanString = pawnAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleanString) ?? 0;
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
    final pawnAmt = _pawnAmountValue;
    final periodDays = selectedPeriod == '15 Hari' ? 15 : 30;

    // Formula SRS: Rhari = ⌈N / 500.000⌉ × 5.000
    final int ceilTiers = pawnAmt > 0 ? ((pawnAmt / 500000).ceil()) : 0;
    final int dailyFee = ceilTiers * 5000;
    final int totalFee = dailyFee * periodDays;
    final int totalRepayment = pawnAmt + totalFee;

    // Dates
    final today = DateTime.now();
    final dueDate = today.add(Duration(days: periodDays));
    final String dateStart = _formatIndonesianDate(today);
    final String dateEnd = _formatIndonesianDate(dueDate);

    final List<String> periods = ['15 Hari', '30 Hari'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Subtitle
            const Text(
              'Keuangan & Tenor',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Atur nilai pinjaman dan jangka waktu gadai Anda',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),

            // Nominal Gadai Input
            const Text(
              'Nominal Gadai (Rp)',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: pawnAmountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                filled: true,
                fillColor: const Color(0xFFEFF6FF), // soft blue tint
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onChanged: (value) {
                if (value.isEmpty) return;
                final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                final val = int.tryParse(clean) ?? 0;
                final formatted = _formatCurrency(val);
                pawnAmountController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                onAmountChanged();
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nominal gadai tidak boleh kosong';
                }
                final amt = _pawnAmountValue;
                if (amt <= 0) {
                  return 'Nominal gadai harus lebih dari 0';
                }
                if (amt > maxTaksiran) {
                  return 'Maksimal Rp ${_formatCurrency(maxTaksiran)} sesuai taksiran jaminan';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            // Limit text
            Text(
              'Maks. Rp ${_formatCurrency(maxTaksiran)} (Sesuai taksiran jaminan)',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Pilih Periode Gadai
            const Text(
              'Pilih Periode Gadai',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedPeriod,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFEFF6FF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: periods.map((period) {
                return DropdownMenuItem(
                  value: period,
                  child: Text(period, style: const TextStyle(fontSize: 15)),
                );
              }).toList(),
              onChanged: onPeriodChanged,
            ),
            const SizedBox(height: 24),

            // Summary Box (Blue container)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jasa Titip Harian',
                        style: TextStyle(color: AppColors.textDark, fontSize: 14),
                      ),
                      Text(
                        'Rp ${_formatCurrency(dailyFee)} / hari',
                        style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Jasa Titip ($periodDays hari)',
                        style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                      ),
                      Text(
                        'Rp ${_formatCurrency(totalFee)}',
                        style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Color(0xFFDBEAFE), height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pelunasan',
                        style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Rp ${_formatCurrency(totalRepayment)}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Green alert banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💵 Uang Diterima di Awal',
                          style: TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${_formatCurrency(pawnAmt)}',
                          style: const TextStyle(
                            color: Color(0xFF047857),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Diterima penuh tanpa potongan',
                          style: TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dates Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tanggal Pengajuan',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              dateStart,
                              style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tanggal Jatuh Tempo',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              dateEnd,
                              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
