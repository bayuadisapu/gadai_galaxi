import 'dart:io';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/services/gadai_thermal_print_service.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================
// HALAMAN PENGATURAN PRINTER THERMAL — GADAI GALAXI
// Tab 1: Koneksi Bluetooth
// Tab 2: Konfigurasi Struk
// ============================================================

class GadaiPrintSettingsPage extends StatefulWidget {
  const GadaiPrintSettingsPage({super.key});

  @override
  State<GadaiPrintSettingsPage> createState() => _GadaiPrintSettingsPageState();
}

class _GadaiPrintSettingsPageState extends State<GadaiPrintSettingsPage>
    with SingleTickerProviderStateMixin {
  final _svc = GadaiThermalPrintService.instance;
  late TabController _tabController;

  List<BluetoothDevice> _pairedDevices = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isTesting = false;
  bool _isLoadingDevices = false;

  // Text controllers for struk settings
  late TextEditingController _shopNameCtrl;
  late TextEditingController _subHeaderCtrl;
  late TextEditingController _customHeaderCtrl;
  late TextEditingController _customFooterCtrl;
  late TextEditingController _termsCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initControllers();
    _refresh();
  }

  void _initControllers() {
    _shopNameCtrl = TextEditingController(text: _svc.customShopName);
    _subHeaderCtrl = TextEditingController(text: _svc.customSubHeader);
    _customHeaderCtrl = TextEditingController(text: _svc.customHeader);
    _customFooterCtrl = TextEditingController(text: _svc.customFooter);
    _termsCtrl = TextEditingController(text: _svc.customTermsText);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shopNameCtrl.dispose();
    _subHeaderCtrl.dispose();
    _customHeaderCtrl.dispose();
    _customFooterCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // Android 12+: minta izin Bluetooth sebelum scan perangkat
    if (Platform.isAndroid) {
      final btConnect = await Permission.bluetoothConnect.request();
      final btScan = await Permission.bluetoothScan.request();
      if (!btConnect.isGranted || !btScan.isGranted) {
        if (mounted) {
          _showSnack(
            '⚠️ Izin Bluetooth ditolak. Buka Pengaturan > Izin Aplikasi untuk mengaktifkan.',
            const Color(0xFFEF4444),
          );
        }
        setState(() => _isLoadingDevices = false);
        return;
      }
    }
    setState(() => _isLoadingDevices = true);
    final devices = await _svc.getPairedDevices();
    final connected = await _svc.isConnected();
    if (!mounted) return;
    setState(() {
      _pairedDevices = devices;
      _isConnected = connected;
      _isLoadingDevices = false;
    });
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    setState(() => _isConnecting = true);
    final ok = await _svc.connect(device);
    final connected = await _svc.isConnected();
    if (!mounted) return;
    setState(() {
      _isConnected = connected;
      _isConnecting = false;
    });
    _showSnack(
      ok ? '✅ Terhubung ke ${device.name}' : '❌ Gagal terhubung ke ${device.name}',
      ok ? AppColors.primary : const Color(0xFFEF4444),
    );
  }

  Future<void> _disconnect() async {
    await _svc.disconnect();
    final connected = await _svc.isConnected();
    if (!mounted) return;
    setState(() => _isConnected = connected);
    _showSnack('Printer terputus', const Color(0xFF94A3B8));
  }

  Future<void> _testPrint() async {
    setState(() => _isTesting = true);
    final ok = await _svc.printTestPage();
    if (!mounted) return;
    setState(() => _isTesting = false);
    _showSnack(
      ok ? '🖨️ Test print berhasil!' : '❌ Gagal cetak. Cek koneksi printer.',
      ok ? AppColors.primary : const Color(0xFFEF4444),
    );
  }

  Future<void> _toggleLock(BluetoothDevice device) async {
    if (_svc.isLocked && _svc.lockedDeviceAddress == device.address) {
      await _svc.unlockPrinter();
    } else {
      await _svc.lockPrinter(device);
    }
    if (!mounted) return;
    setState(() {});
    _showSnack(
      _svc.isLocked
          ? '🔒 Printer dikunci: ${_svc.lockedDeviceName}'
          : '🔓 Printer lock dibuka',
      AppColors.primary,
    );
  }

  void _saveStrukSettings() {
    _svc.customShopName = _shopNameCtrl.text.trim();
    _svc.customSubHeader = _subHeaderCtrl.text.trim();
    _svc.customHeader = _customHeaderCtrl.text.trim();
    _svc.customFooter = _customFooterCtrl.text.trim();
    _svc.customTermsText = _termsCtrl.text.trim();
    _svc.saveSettings();
    setState(() {});
    _showSnack('✅ Pengaturan struk disimpan', AppColors.primary);
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengaturan Printer',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_isConnected)
            IconButton(
              icon: _isTesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_rounded, color: AppColors.primary),
              tooltip: 'Test Print',
              onPressed: _isTesting ? null : _testPrint,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.bluetooth_rounded), text: 'Printer'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Struk'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrinterTab(),
          _buildStrukTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // TAB 1: BLUETOOTH / PRINTER
  // ─────────────────────────────────────────

  Widget _buildPrinterTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isConnected
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [const Color(0xFF64748B), const Color(0xFF94A3B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_isConnected ? const Color(0xFF10B981) : const Color(0xFF64748B))
                      .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isConnected ? Icons.print_rounded : Icons.print_disabled_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isConnected ? 'Printer Terhubung' : 'Tidak Ada Printer',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isConnected
                            ? (_svc.connectedDevice?.name ?? 'Unknown')
                            : 'Pilih printer di bawah',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_isConnected)
                  TextButton(
                    onPressed: _disconnect,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Putus', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),

          // Printer lock info
          if (_svc.isLocked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Printer terkunci: ${_svc.lockedDeviceName ?? "-"}',
                      style: const TextStyle(
                          color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _svc.unlockPrinter();
                      setState(() {});
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 28),
                    ),
                    child: const Text('Buka', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Perangkat Bluetooth (Paired)',
                style: TextStyle(
                    color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isLoadingDevices ? null : _refresh,
                icon: _isLoadingDevices
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_pairedDevices.isEmpty && !_isLoadingDevices)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.bluetooth_disabled_rounded,
                      size: 48, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 10),
                  Text('Tidak ada perangkat Bluetooth yang di-pair.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  SizedBox(height: 6),
                  Text('Pair printer di Settings HP Anda terlebih dahulu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            )
          else
            ..._pairedDevices.map((device) {
              final isThisConnected = _isConnected &&
                  _svc.connectedDevice?.address == device.address;
              final isLocked =
                  _svc.isLocked && _svc.lockedDeviceAddress == device.address;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isThisConnected
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : const Color(0xFFE2E8F0),
                    width: isThisConnected ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isThisConnected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      color: isThisConnected ? AppColors.primary : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    device.name ?? 'Unknown',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight: isThisConnected ? FontWeight.bold : FontWeight.w500),
                  ),
                  subtitle: Row(
                    children: [
                      Text(device.address ?? '',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      if (isThisConnected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Terhubung',
                              style: TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (isLocked) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.lock_rounded, size: 12, color: Color(0xFFF59E0B)),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Lock/unlock button
                      if (isThisConnected)
                        IconButton(
                          icon: Icon(
                            isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                            size: 18,
                            color: isLocked
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF94A3B8),
                          ),
                          tooltip: isLocked ? 'Buka Kunci' : 'Kunci Printer',
                          onPressed: () => _toggleLock(device),
                        ),
                      // Connect/disconnect button
                      _isConnecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: () => isThisConnected
                                  ? _disconnect()
                                  : _connectTo(device),
                              style: TextButton.styleFrom(
                                foregroundColor: isThisConnected
                                    ? const Color(0xFFEF4444)
                                    : AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: Text(
                                isThisConnected ? 'Putus' : 'Hubungkan',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 20),
          // Ukuran kertas
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ukuran Kertas',
                  style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: GadaiPaperSize.values.map((size) {
                    final selected = _svc.paperSize == size;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _svc.paperSize = size;
                          _svc.saveSettings();
                          setState(() {});
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFFE2E8F0),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  color: selected
                                      ? AppColors.primary
                                      : const Color(0xFF94A3B8),
                                  size: 20),
                              const SizedBox(height: 4),
                              Text(
                                size.label,
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${size.charsPerLine} char/baris',
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // Test print button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isConnected && !_isTesting) ? _testPrint : null,
              icon: _isTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print_rounded, color: Colors.white, size: 18),
              label: Text(
                _isTesting ? 'Mencetak...' : 'Cetak Halaman Test',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isConnected ? AppColors.primary : const Color(0xFF94A3B8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // TAB 2: KONFIGURASI STRUK
  // ─────────────────────────────────────────

  Widget _buildStrukTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Tampilan Struk'),

        // Toggle switches
        _toggleCard(
          'Tampilkan Header',
          'Nama toko dan sub-header di atas struk',
          _svc.showHeader,
          (v) {
            _svc.showHeader = v;
            _svc.saveSettings();
            setState(() {});
          },
          icon: Icons.store_rounded,
        ),
        _toggleCard(
          'Tampilkan Data Nasabah',
          'NIK, nama, dan nomor telepon',
          _svc.showNasabah,
          (v) {
            _svc.showNasabah = v;
            _svc.saveSettings();
            setState(() {});
          },
          icon: Icons.person_rounded,
        ),
        _toggleCard(
          'Tampilkan Syarat & Ketentuan',
          'Teks S&K di bawah rincian',
          _svc.showTerms,
          (v) {
            _svc.showTerms = v;
            _svc.saveSettings();
            setState(() {});
          },
          icon: Icons.rule_rounded,
        ),
        _toggleCard(
          'Tampilkan Kolom Tanda Tangan',
          'Kolom TTD nasabah dan staff',
          _svc.showSignature,
          (v) {
            _svc.showSignature = v;
            _svc.saveSettings();
            setState(() {});
          },
          icon: Icons.draw_rounded,
        ),

        const SizedBox(height: 8),
        _sectionHeader('Format & Ukuran Teks'),

        _switchRow('Header Teks Besar', _svc.doubleSizeHeader, (v) {
          _svc.doubleSizeHeader = v;
          _svc.saveSettings();
          setState(() {});
        }),
        _switchRow('Judul Teks Besar', _svc.doubleSizeTitle, (v) {
          _svc.doubleSizeTitle = v;
          _svc.saveSettings();
          setState(() {});
        }),
        _switchRow('Total Teks Besar', _svc.doubleSizeTotal, (v) {
          _svc.doubleSizeTotal = v;
          _svc.saveSettings();
          setState(() {});
        }),

        const SizedBox(height: 8),
        _sectionHeader('Teks Kustom'),
        const SizedBox(height: 8),

        _buildTextField(_shopNameCtrl, 'Nama Toko', 'Contoh: GALAXI GADAI CABANG UTARA'),
        const SizedBox(height: 10),
        _buildTextField(_subHeaderCtrl, 'Sub-Header', 'Contoh: Gadai & Simpan Terpercaya'),
        const SizedBox(height: 10),
        _buildTextField(_customHeaderCtrl, 'Baris Tambahan Header', 'Contoh: Jl. Merdeka No. 10 - 081234567'),
        const SizedBox(height: 10),
        _buildTextField(_customFooterCtrl, 'Footer', 'Contoh: Terima kasih telah mempercayai kami'),
        const SizedBox(height: 10),
        _buildTextField(
          _termsCtrl,
          'Syarat & Ketentuan',
          'Kosongkan untuk menggunakan teks default',
          maxLines: 4,
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveStrukSettings,
            icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
            label: const Text('Simpan Pengaturan Struk',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleCard(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData icon = Icons.settings_rounded,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: value
                ? AppColors.primary.withValues(alpha: 0.1)
                : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: value ? AppColors.primary : const Color(0xFF94A3B8)),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        title: Text(label,
            style: const TextStyle(
                color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w500)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        dense: true,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textInputHint, fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
