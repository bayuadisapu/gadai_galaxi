import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';

class LaporanTabContent extends StatefulWidget {
  const LaporanTabContent({super.key});

  @override
  State<LaporanTabContent> createState() => _LaporanTabContentState();
}

class _LaporanTabContentState extends State<LaporanTabContent> {
  String _selectedRange = 'Bulanan'; // 'Harian', 'Mingguan', 'Bulanan'
  int _selectedMonthIndex = 5; // June 2026

  final List<String> _months = [
    'Januari 2026', 'Februari 2026', 'Maret 2026', 'April 2026', 'Mei 2026', 'Juni 2026',
    'Juli 2026', 'Agustus 2026', 'September 2026', 'Oktober 2026', 'November 2026', 'Desember 2026'
  ];

  void _prevMonth() {
    if (_selectedMonthIndex > 0) {
      setState(() {
        _selectedMonthIndex--;
      });
    }
  }

  void _nextMonth() {
    if (_selectedMonthIndex < _months.length - 1) {
      setState(() {
        _selectedMonthIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Date Switcher and Range Selector Banner (Dark Blue Section)
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.primary,
          ),
          padding: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
          child: Column(
            children: [
              // Date Switcher pill
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF), // slightly lighter/darker accent blue
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                      onPressed: _prevMonth,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Text(
                      _months[_selectedMonthIndex],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                      onPressed: _nextMonth,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Tabs: Harian, Mingguan, Bulanan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Harian', 'Mingguan', 'Bulanan'].map((range) {
                  final isSelected = _selectedRange == range;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRange = range;
                      });
                    },
                    child: Column(
                      children: [
                        Text(
                          range,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isSelected)
                          Container(
                            width: 56,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          )
                        else
                          const SizedBox(height: 3),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // 2. Scrollable Body Content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total Jasa Titip Summary Card (Blue Gradient)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Jasa Titip Terkumpul',
                        style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Rp 18.750.000',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      
                      // Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSummaryBadge(const Color(0xFF10B981), '47 Lunas'),
                          _buildSummaryBadge(const Color(0xFFF59E0B), '12 Perpanjangan'),
                          _buildSummaryBadge(const Color(0xFFEF4444), '2 Macet'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Chart Card: Tren Transaksi 30 Hari
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tren Transaksi 30 Hari',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.trending_up_rounded,
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.8),
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      
                      // Custom Bar Chart layout
                      _buildBarChart(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Distribution Card: Ringkasan Jenis Jaminan
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ringkasan Jenis Jaminan',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      _buildProgressRow('Handphone', 0.45, '45%', const Color(0xFF1E3A8A)),
                      const SizedBox(height: 18),
                      _buildProgressRow('Emas', 0.30, '30%', const Color(0xFF1D4ED8)),
                      const SizedBox(height: 18),
                      _buildProgressRow('Motor/Mobil', 0.15, '15%', const Color(0xFF60A5FA)),
                      const SizedBox(height: 18),
                      _buildProgressRow('Lainnya', 0.10, '10%', const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Export buttons Row
                Row(
                  children: [
                    Expanded(
                      child: _buildExportButton(
                        icon: Icons.description_outlined,
                        label: 'Ekspor PDF',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mengekspor laporan ke PDF...')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildExportButton(
                        icon: Icons.table_view_outlined,
                        label: 'Ekspor Excel',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mengekspor laporan ke Excel...')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBadge(Color dotColor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final List<Map<String, dynamic>> barData = [
      {'label': '01', 'val': 35, 'isActive': false},
      {'label': '05', 'val': 75, 'isActive': false},
      {'label': '10', 'val': 105, 'isActive': true, 'labelVal': '12'},
      {'label': '15', 'val': 70, 'isActive': false},
      {'label': '20', 'val': 88, 'isActive': false},
      {'label': '25', 'val': 120, 'isActive': true},
      {'label': '30', 'val': 45, 'isActive': false},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: barData.map((data) {
        final double height = data['val'].toDouble();
        final bool isActive = data['isActive'] as bool;
        final String? labelVal = data['labelVal'] as String?;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (labelVal != null)
              Text(
                labelVal,
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const SizedBox(height: 14),
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: height,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFF94A3B8).withValues(alpha: 0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data['label'] as String,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProgressRow(String label, double value, String percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              percentage,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: const Color(0xFFEFF6FF),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1E3A8A),
        side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
