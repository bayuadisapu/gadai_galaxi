import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/config/system_config.dart';

class NasabahKalkulatorTab extends StatefulWidget {
  const NasabahKalkulatorTab({super.key});

  @override
  State<NasabahKalkulatorTab> createState() => _NasabahKalkulatorTabState();
}

class _NasabahKalkulatorTabState extends State<NasabahKalkulatorTab> {
  final _nominalController = TextEditingController();
  String _selectedPeriod = '15 Hari';
  int _pawnAmt = 0;

  @override
  void dispose() {
    _nominalController.dispose();
    super.dispose();
  }

  String _formatCurrency(int val) {
    if (val <= 0) return '0';
    final s = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final periodDays = _selectedPeriod == '15 Hari' ? SystemConfig.minTenor : SystemConfig.maxTenor;
    final int dailyFee = SystemConfig.calculateDailyFee(_pawnAmt);
    final int totalFee = dailyFee * periodDays;
    final int totalRepayment = _pawnAmt + totalFee;
    final dueDate = DateTime.now().add(Duration(days: periodDays));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kalkulator Gadai Mandiri', style: TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Hitung estimasi biaya gadai sebelum mengajukan', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 24),

          // Nominal Input
          const Text('Nominal Pinjaman (Rp)', style: TextStyle(color: AppColors.textInputLabel, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nominalController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold),
              hintText: '0',
              hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 20),
              filled: true,
              fillColor: const Color(0xFFEFF6FF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            onChanged: (value) {
              final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
              final val = int.tryParse(clean) ?? 0;
              final formatted = val > 0 ? _formatCurrency(val) : '';
              _nominalController.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
              setState(() => _pawnAmt = val);
            },
          ),
          const SizedBox(height: 20),

          // Periode
          const Text('Periode Gadai', style: TextStyle(color: AppColors.textInputLabel, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: ['15 Hari', '30 Hari'].map((p) {
              final isSelected = _selectedPeriod == p;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPeriod = p),
                  child: Container(
                    margin: EdgeInsets.only(right: p == '15 Hari' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        p,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Result Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDBEAFE)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📊 Hasil Kalkulasi', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _resultRow('Jasa Titip Harian', 'Rp ${_formatCurrency(dailyFee)} / hari', AppColors.textDark),
                const SizedBox(height: 10),
                _resultRow('Total Jasa Titip ($periodDays hari)', 'Rp ${_formatCurrency(totalFee)}', AppColors.textDark),
                const SizedBox(height: 10),
                _resultRow('Uang Diterima di Awal', 'Rp ${_formatCurrency(_pawnAmt)}', const Color(0xFF10B981)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: Color(0xFFDBEAFE)),
                ),
                _resultRow('Total Tebusan Pelunasan', 'Rp ${_formatCurrency(totalRepayment)}', AppColors.primary, bold: true, large: true),
                const SizedBox(height: 14),
                _resultRow('Tanggal Jatuh Tempo', _formatDate(dueDate), const Color(0xFFEF4444)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Formula info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Formula: Jasa Harian = ⌈Nominal ÷ Rp 500.000⌉ × Rp 5.000\n'
                    'Uang diterima utuh tanpa potongan di awal.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, Color valueColor, {bool bold = false, bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: large ? 17 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
