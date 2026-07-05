import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          Text('Kalkulator Gadai Mandiri', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Hitung estimasi biaya gadai sebelum mengajukan', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),

          // Nominal Input
          Text('Nominal Pinjaman (Rp)', style: GoogleFonts.inter(color: AppColors.textInputLabel, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: TextFormField(
              controller: _nominalController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(color: AppColors.royalBlue, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: GoogleFonts.inter(color: AppColors.royalBlue, fontSize: 18, fontWeight: FontWeight.bold),
                hintText: '0',
                hintStyle: GoogleFonts.inter(color: AppColors.textInputHint, fontSize: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
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
          ),
          const SizedBox(height: 20),

          // Periode
          Text('Periode Gadai', style: GoogleFonts.inter(color: AppColors.textInputLabel, fontSize: 13, fontWeight: FontWeight.w700)),
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
                      color: isSelected ? AppColors.royalBlue : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? AppColors.royalBlue : const Color(0xFFE2E8F0)),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.royalBlue.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        p,
                        style: GoogleFonts.inter(
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 Hasil Kalkulasi', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _resultRow('Jasa Titip Harian', 'Rp ${_formatCurrency(dailyFee)} / hari', AppColors.textDark),
                const SizedBox(height: 12),
                _resultRow('Total Jasa Titip ($periodDays hari)', 'Rp ${_formatCurrency(totalFee)}', AppColors.textDark),
                const SizedBox(height: 12),
                _resultRow('Uang Diterima di Awal', 'Rp ${_formatCurrency(_pawnAmt)}', const Color(0xFF10B981)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: Color(0xFFE2E8F0)),
                ),
                _resultRow('Total Tebusan Pelunasan', 'Rp ${_formatCurrency(totalRepayment)}', AppColors.royalBlue, bold: true, large: true),
                const SizedBox(height: 12),
                _resultRow('Tanggal Jatuh Tempo', _formatDate(dueDate), const Color(0xFFEF4444)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Formula info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.royalBlue, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Formula: Jasa Harian = ⌈Nominal ÷ Rp 500.000⌉ × Rp 5.000\n'
                    'Uang diterima utuh tanpa potongan di awal.',
                    style: GoogleFonts.inter(color: const Color(0xFF1E3A8A), fontSize: 12, height: 1.5, fontWeight: FontWeight.w500),
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
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
        Text(
          value,
          style: GoogleFonts.inter(
            color: valueColor,
            fontSize: large ? 16 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
