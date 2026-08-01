import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';

// ============================================
// GADAI THERMAL PRINT SERVICE — SINGLETON
// Robust ESC/POS protocol via Bluetooth Classic.
// Full raw byte buffer compilation & chunked streaming
// Designed to work on ALL Chinese thermal printers
// (58mm & 80mm generic Bluetooth printers, GOOJPRT,
// RPP02N, PT-210, MPT-II, POS-5802, Xprinter, etc.)
// ============================================

/// Ukuran kertas thermal
enum GadaiPaperSize {
  mm58,
  mm80,
}

extension GadaiPaperSizeExt on GadaiPaperSize {
  String get label {
    switch (this) {
      case GadaiPaperSize.mm58:
        return '58mm';
      case GadaiPaperSize.mm80:
        return '80mm';
    }
  }

  /// Jumlah karakter per baris (monospace)
  int get charsPerLine {
    switch (this) {
      case GadaiPaperSize.mm58:
        return 32;
      case GadaiPaperSize.mm80:
        return 48;
    }
  }
}

/// Helper Builder untuk kompilasi perintah ESC/POS ke Uint8List murni
class EscPosBufferBuilder {
  final BytesBuilder _builder = BytesBuilder();

  /// Inisialisasi printer & reset mode karakter
  void init() {
    // ESC @: Reset printer
    _builder.add(const [0x1B, 0x40]);
    // FS .: CANCEL CHINESE MODE (Penting untuk printer Cina agar karakter Latin tidak menjadi Mandarin!)
    _builder.add(const [0x1C, 0x2E]);
    // ESC t 0: Code Page 0 (CP437 USA / Standard Europe)
    _builder.add(const [0x1B, 0x74, 0x00]);
  }

  void setAlign(int align) {
    // ESC a n (0=Left, 1=Center, 2=Right)
    _builder.add([0x1B, 0x61, align]);
  }

  void setBold(bool on) {
    // ESC E n (1=Bold, 0=Normal)
    _builder.add([0x1B, 0x45, on ? 0x01 : 0x00]);
  }

  void setDoubleSize(bool on) {
    if (on) {
      // GS ! n (Double width & height)
      _builder.add(const [0x1D, 0x21, 0x11]);
      // ESC ! n (Fallback untuk printer Cina lama)
      _builder.add(const [0x1B, 0x21, 0x30]);
    } else {
      _builder.add(const [0x1D, 0x21, 0x00]);
      _builder.add(const [0x1B, 0x21, 0x00]);
    }
  }

  void setLineSpacing(int dots) {
    // ESC 3 n
    _builder.add([0x1B, 0x33, dots]);
  }

  void resetLineSpacing() {
    // ESC 2 (Default line spacing ~ 1/6 inch)
    _builder.add(const [0x1B, 0x32]);
  }

  void addFeed(int lines) {
    // ESC d n
    _builder.add([0x1B, 0x64, lines]);
  }

  void addCut() {
    // GS V 1 (Partial Cut)
    _builder.add(const [0x1D, 0x56, 0x01]);
  }

  /// Menambahkan teks mentah dengan pengkodean ASCII / Latin1
  void addRawText(String text) {
    // Konversi string ke byte Latin1 aman
    final bytes = latin1.encode(text);
    _builder.add(bytes);
  }

  /// Menambahkan baris teks dengan opsi alignment dan gaya
  void addLine(String text, {int align = 0, bool bold = false, bool doubleSize = false}) {
    setAlign(align);
    if (bold) setBold(true);
    if (doubleSize) setDoubleSize(true);
    addRawText('$text\n');
    if (doubleSize) setDoubleSize(false);
    if (bold) setBold(false);
    if (align != 0) setAlign(0);
  }

  /// Menambahkan garis pemisah (- atau =)
  void addDivider(int maxLen, {String char = '-'}) {
    addLine(char * maxLen, align: 0);
  }

  /// Menambahkan sepasang Kunci & Nilai rata kiri-kanan
  void addKeyValue(String key, String value, int maxLen, {bool bold = false}) {
    if (bold) setBold(true);
    final spaces = maxLen - key.length - value.length;
    if (spaces > 0) {
      addRawText('$key${' ' * spaces}$value\n');
    } else {
      addRawText('$key\n');
      setAlign(2);
      addRawText('$value\n');
      setAlign(0);
    }
    if (bold) setBold(false);
  }

  /// Menambahkan label: nilai dengan penanganan teks panjang
  void addLabelValue(String label, String value, int maxLen) {
    final labelStr = '$label: ';
    final availableLen = maxLen - labelStr.length;
    if (value.length <= availableLen) {
      addRawText('$labelStr$value\n');
    } else {
      addRawText('$labelStr\n');
      addRawText('  $value\n');
    }
  }

  Uint8List toBytes() {
    return _builder.takeBytes();
  }
}

class GadaiThermalPrintService {
  GadaiThermalPrintService._() {
    loadSettings();
  }
  static final GadaiThermalPrintService instance = GadaiThermalPrintService._();

  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;

  /// Ukuran kertas aktif (default 80mm)
  GadaiPaperSize paperSize = GadaiPaperSize.mm80;

  // Customization settings
  bool showHeader = true;
  bool showNasabah = true;
  bool showTerms = true;
  bool showSignature = true;
  String customShopName = '';
  String customSubHeader = '';
  String customHeader = '';
  String customFooter = '';
  String customTermsText = '';

  // Label kustom
  String customNasabahLabel = 'Nasabah';
  String customNikLabel = 'NIK';
  String customTelpLabel = 'Telp';
  String customBarangLabel = 'Barang';
  String customMerkLabel = 'Merk';
  String customKondisiLabel = 'Kondisi';
  String customNominalLabel = 'Nominal Pinjaman';
  String customJasaLabel = 'Jasa Titip/Hari';
  String customPeriodeLabel = 'Periode';
  String customTotalJasaLabel = 'Total Jasa Titip';
  String customTotalTebusLabel = 'TOTAL TEBUSAN';
  String customJatuhTempoLabel = 'Jatuh Tempo';
  String customSignatureLeft = 'Nasabah';
  String customSignatureRight = 'Staff';

  // Formatting
  int endFeedLines = 3;
  int lineSpacing = 20;
  bool doubleSizeHeader = true;
  bool doubleSizeTitle = false;
  bool doubleSizeTotal = true;

  // Alignments (0=left, 1=center, 2=right)
  int alignHeader = 1;
  int alignSubHeader = 1;
  int alignTitle = 1;
  int alignTerms = 0;
  int alignFooter = 1;

  // Spacing
  int spacingAfterHeader = 0;
  int spacingAfterNasabah = 0;
  int spacingAfterPrices = 0;
  int spacingAfterTerms = 0;

  /// Device yang sedang terkoneksi
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // Saved printer for auto-reconnect
  String? lastConnectedAddress;
  String? lastConnectedName;

  // -----------------------------------------------
  // PRINTER LOCK FEATURE
  // -----------------------------------------------

  String? lockedDeviceAddress;
  String? lockedDeviceName;
  bool get isLocked => lockedDeviceAddress != null && lockedDeviceAddress!.isNotEmpty;

  Future<bool> lockPrinter(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gadai_printer_locked_address', device.address ?? '');
      await prefs.setString('gadai_printer_locked_name', device.name ?? 'Printer');
      lockedDeviceAddress = device.address;
      lockedDeviceName = device.name;
      debugPrint('Lock printer gadai: ${device.name}');
      return true;
    } catch (e) {
      debugPrint('Error locking printer gadai: $e');
      return false;
    }
  }

  Future<bool> unlockPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('gadai_printer_locked_address');
      await prefs.remove('gadai_printer_locked_name');
      lockedDeviceAddress = null;
      lockedDeviceName = null;
      return true;
    } catch (e) {
      debugPrint('Error unlocking printer gadai: $e');
      return false;
    }
  }

  // -----------------------------------------------
  // SETTINGS PERSISTENCE
  // -----------------------------------------------

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      paperSize = (prefs.getString('gadai_ps_paperSize') ?? 'mm80') == 'mm58'
          ? GadaiPaperSize.mm58
          : GadaiPaperSize.mm80;
      showHeader = prefs.getBool('gadai_ps_showHeader') ?? true;
      showNasabah = prefs.getBool('gadai_ps_showNasabah') ?? true;
      showTerms = prefs.getBool('gadai_ps_showTerms') ?? true;
      showSignature = prefs.getBool('gadai_ps_showSignature') ?? true;
      customShopName = prefs.getString('gadai_ps_customShopName') ?? '';
      customSubHeader = prefs.getString('gadai_ps_customSubHeader') ?? '';
      customHeader = prefs.getString('gadai_ps_customHeader') ?? '';
      customFooter = prefs.getString('gadai_ps_customFooter') ?? '';
      customTermsText = prefs.getString('gadai_ps_customTermsText') ?? '';

      customNasabahLabel = prefs.getString('gadai_ps_customNasabahLabel') ?? 'Nasabah';
      customNikLabel = prefs.getString('gadai_ps_customNikLabel') ?? 'NIK';
      customTelpLabel = prefs.getString('gadai_ps_customTelpLabel') ?? 'Telp';
      customBarangLabel = prefs.getString('gadai_ps_customBarangLabel') ?? 'Barang';
      customMerkLabel = prefs.getString('gadai_ps_customMerkLabel') ?? 'Merk';
      customKondisiLabel = prefs.getString('gadai_ps_customKondisiLabel') ?? 'Kondisi';
      customNominalLabel = prefs.getString('gadai_ps_customNominalLabel') ?? 'Nominal Pinjaman';
      customJasaLabel = prefs.getString('gadai_ps_customJasaLabel') ?? 'Jasa Titip/Hari';
      customPeriodeLabel = prefs.getString('gadai_ps_customPeriodeLabel') ?? 'Periode';
      customTotalJasaLabel = prefs.getString('gadai_ps_customTotalJasaLabel') ?? 'Total Jasa Titip';
      customTotalTebusLabel = prefs.getString('gadai_ps_customTotalTebusLabel') ?? 'TOTAL TEBUSAN';
      customJatuhTempoLabel = prefs.getString('gadai_ps_customJatuhTempoLabel') ?? 'Jatuh Tempo';
      customSignatureLeft = prefs.getString('gadai_ps_customSignatureLeft') ?? 'Nasabah';
      customSignatureRight = prefs.getString('gadai_ps_customSignatureRight') ?? 'Staff';

      endFeedLines = prefs.getInt('gadai_ps_endFeedLines') ?? 3;
      lineSpacing = prefs.getInt('gadai_ps_lineSpacing') ?? 20;
      doubleSizeHeader = prefs.getBool('gadai_ps_doubleSizeHeader') ?? true;
      doubleSizeTitle = prefs.getBool('gadai_ps_doubleSizeTitle') ?? false;
      doubleSizeTotal = prefs.getBool('gadai_ps_doubleSizeTotal') ?? true;

      alignHeader = prefs.getInt('gadai_ps_alignHeader') ?? 1;
      alignSubHeader = prefs.getInt('gadai_ps_alignSubHeader') ?? 1;
      alignTitle = prefs.getInt('gadai_ps_alignTitle') ?? 1;
      alignTerms = prefs.getInt('gadai_ps_alignTerms') ?? 0;
      alignFooter = prefs.getInt('gadai_ps_alignFooter') ?? 1;

      spacingAfterHeader = prefs.getInt('gadai_ps_spacingAfterHeader') ?? 0;
      spacingAfterNasabah = prefs.getInt('gadai_ps_spacingAfterNasabah') ?? 0;
      spacingAfterPrices = prefs.getInt('gadai_ps_spacingAfterPrices') ?? 0;
      spacingAfterTerms = prefs.getInt('gadai_ps_spacingAfterTerms') ?? 0;

      final lockedAddr = prefs.getString('gadai_printer_locked_address') ?? '';
      lockedDeviceAddress = lockedAddr.isNotEmpty ? lockedAddr : null;
      lockedDeviceName = prefs.getString('gadai_printer_locked_name');

      lastConnectedAddress = prefs.getString('gadai_printer_last_address');
      lastConnectedName = prefs.getString('gadai_printer_last_name');
    } catch (e) {
      debugPrint('Error loading gadai print settings: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gadai_ps_paperSize', paperSize == GadaiPaperSize.mm58 ? 'mm58' : 'mm80');
      await prefs.setBool('gadai_ps_showHeader', showHeader);
      await prefs.setBool('gadai_ps_showNasabah', showNasabah);
      await prefs.setBool('gadai_ps_showTerms', showTerms);
      await prefs.setBool('gadai_ps_showSignature', showSignature);
      await prefs.setString('gadai_ps_customShopName', customShopName);
      await prefs.setString('gadai_ps_customSubHeader', customSubHeader);
      await prefs.setString('gadai_ps_customHeader', customHeader);
      await prefs.setString('gadai_ps_customFooter', customFooter);
      await prefs.setString('gadai_ps_customTermsText', customTermsText);

      await prefs.setString('gadai_ps_customNasabahLabel', customNasabahLabel);
      await prefs.setString('gadai_ps_customNikLabel', customNikLabel);
      await prefs.setString('gadai_ps_customTelpLabel', customTelpLabel);
      await prefs.setString('gadai_ps_customBarangLabel', customBarangLabel);
      await prefs.setString('gadai_ps_customMerkLabel', customMerkLabel);
      await prefs.setString('gadai_ps_customKondisiLabel', customKondisiLabel);
      await prefs.setString('gadai_ps_customNominalLabel', customNominalLabel);
      await prefs.setString('gadai_ps_customJasaLabel', customJasaLabel);
      await prefs.setString('gadai_ps_customPeriodeLabel', customPeriodeLabel);
      await prefs.setString('gadai_ps_customTotalJasaLabel', customTotalJasaLabel);
      await prefs.setString('gadai_ps_customTotalTebusLabel', customTotalTebusLabel);
      await prefs.setString('gadai_ps_customJatuhTempoLabel', customJatuhTempoLabel);
      await prefs.setString('gadai_ps_customSignatureLeft', customSignatureLeft);
      await prefs.setString('gadai_ps_customSignatureRight', customSignatureRight);

      await prefs.setInt('gadai_ps_endFeedLines', endFeedLines);
      await prefs.setInt('gadai_ps_lineSpacing', lineSpacing);
      await prefs.setBool('gadai_ps_doubleSizeHeader', doubleSizeHeader);
      await prefs.setBool('gadai_ps_doubleSizeTitle', doubleSizeTitle);
      await prefs.setBool('gadai_ps_doubleSizeTotal', doubleSizeTotal);

      await prefs.setInt('gadai_ps_alignHeader', alignHeader);
      await prefs.setInt('gadai_ps_alignSubHeader', alignSubHeader);
      await prefs.setInt('gadai_ps_alignTitle', alignTitle);
      await prefs.setInt('gadai_ps_alignTerms', alignTerms);
      await prefs.setInt('gadai_ps_alignFooter', alignFooter);

      await prefs.setInt('gadai_ps_spacingAfterHeader', spacingAfterHeader);
      await prefs.setInt('gadai_ps_spacingAfterNasabah', spacingAfterNasabah);
      await prefs.setInt('gadai_ps_spacingAfterPrices', spacingAfterPrices);
      await prefs.setInt('gadai_ps_spacingAfterTerms', spacingAfterTerms);
    } catch (e) {
      debugPrint('Error saving gadai print settings: $e');
    }
  }

  // -----------------------------------------------
  // BLUETOOTH DEVICE MANAGEMENT
  // -----------------------------------------------

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _printer.getBondedDevices();
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
      return [];
    }
  }

  Future<bool> isConnected() async {
    try {
      final connected = await _printer.isConnected ?? false;
      if (!connected) _connectedDevice = null;
      return connected;
    } catch (_) {
      _connectedDevice = null;
      return false;
    }
  }

  /// Otomatis mencoba rekoneksi ke printer terakhir / yang dikunci jika koneksi terputus
  Future<bool> ensureConnected() async {
    if (await isConnected()) return true;

    final targetAddress = lockedDeviceAddress ?? lastConnectedAddress;
    if (targetAddress == null || targetAddress.isEmpty) {
      return false;
    }

    try {
      debugPrint('Auto-reconnecting to printer: $targetAddress');
      final devices = await getPairedDevices();
      final targetDevice = devices.firstWhere(
        (d) => d.address == targetAddress,
        orElse: () => BluetoothDevice(lastConnectedName ?? 'Printer', targetAddress),
      );

      return await connect(targetDevice);
    } catch (e) {
      debugPrint('Auto-reconnect printer failed: $e');
      return false;
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      if (await isConnected()) {
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 400));
      }
      await _printer.connect(device);
      // Beri waktu lebih untuk printer China yang lambat init
      await Future.delayed(const Duration(milliseconds: 1200));
      final connected = await isConnected();
      if (connected) {
        _connectedDevice = device;
        lastConnectedAddress = device.address;
        lastConnectedName = device.name;
        final prefs = await SharedPreferences.getInstance();
        if (device.address != null) {
          await prefs.setString('gadai_printer_last_address', device.address!);
        }
        if (device.name != null) {
          await prefs.setString('gadai_printer_last_name', device.name!);
        }
      } else {
        // Coba sekali lagi (printer China kadang butuh retry)
        debugPrint('First connect attempt failed, retrying...');
        await Future.delayed(const Duration(milliseconds: 800));
        await _printer.connect(device);
        await Future.delayed(const Duration(milliseconds: 1200));
        final retryConnected = await isConnected();
        if (retryConnected) {
          _connectedDevice = device;
          lastConnectedAddress = device.address;
          lastConnectedName = device.name;
          final prefs = await SharedPreferences.getInstance();
          if (device.address != null) {
            await prefs.setString('gadai_printer_last_address', device.address!);
          }
          if (device.name != null) {
            await prefs.setString('gadai_printer_last_name', device.name!);
          }
        }
        return retryConnected;
      }
      return connected;
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _printer.disconnect();
      _connectedDevice = null;
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  // -----------------------------------------------
  // CHUNKED STREAMING OVER BLUETOOTH
  // Melindungi buffer Bluetooth printer thermal Cina
  // -----------------------------------------------

  Future<bool> _sendBytesChunked(Uint8List bytes, {int chunkSize = 48, int delayMs = 40}) async {
    try {
      if (!await isConnected()) {
        final reconnected = await ensureConnected();
        if (!reconnected) return false;
      }

      final total = bytes.length;
      for (int offset = 0; offset < total; offset += chunkSize) {
        final end = (offset + chunkSize < total) ? offset + chunkSize : total;
        final chunk = bytes.sublist(offset, end);
        await _printer.writeBytes(Uint8List.fromList(chunk));
        if (delayMs > 0) {
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
      // Flush: kirim newline tambahan agar printer flush buffer internal
      await Future.delayed(const Duration(milliseconds: 80));
      return true;
    } catch (e) {
      debugPrint('Error sending raw bytes stream chunked: $e');
      return false;
    }
  }

  // -----------------------------------------------
  // FORMAT RUPIAH & TANGGAL
  // -----------------------------------------------

  String _formatRupiah(int value) {
    if (value == 0) return 'Rp 0';
    final str = value.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write('.');
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // -----------------------------------------------
  // HEADER BUILDER HELPER
  // -----------------------------------------------

  void _buildHeader(EscPosBufferBuilder builder) {
    if (!showHeader) return;
    final shopName = customShopName.isNotEmpty
        ? customShopName.toUpperCase()
        : 'GALAXI GADAI';
    final subHeader = customSubHeader.isNotEmpty
        ? customSubHeader
        : 'Gadai & Simpan Terpercaya';
    builder.addLine(shopName, align: alignHeader, bold: true, doubleSize: doubleSizeHeader);
    builder.addLine(subHeader, align: alignSubHeader);
    if (customHeader.isNotEmpty) {
      builder.addLine(customHeader, align: alignHeader);
    }
    builder.addDivider(paperSize.charsPerLine, char: '=');
    if (spacingAfterHeader > 0) {
      builder.addFeed(spacingAfterHeader);
    }
  }

  // -----------------------------------------------
  // 1. STRUK PERJANJIAN GADAI (barang masuk)
  // -----------------------------------------------

  Future<bool> printPerjanjianGadai(
    PawnTransaction tx,
    Customer customer, {
    String copyLabel = '',
  }) async {
    if (!await ensureConnected()) return false;
    try {
      final builder = EscPosBufferBuilder();
      builder.init();
      builder.setLineSpacing(lineSpacing);

      _buildHeader(builder);

      final title = copyLabel.isNotEmpty
          ? 'PERJANJIAN GADAI ($copyLabel)'
          : 'PERJANJIAN GADAI';
      builder.addLine(title, align: alignTitle, bold: true, doubleSize: doubleSizeTitle);
      builder.addDivider(paperSize.charsPerLine);

      builder.addKeyValue('No', tx.displayCode, paperSize.charsPerLine);
      builder.addKeyValue('Tgl', _formatDate(tx.dateApplied), paperSize.charsPerLine);

      if (showNasabah) {
        builder.addDivider(paperSize.charsPerLine);
        String padLabel(String label) => label.padRight(9);
        builder.addRawText('${padLabel(customNasabahLabel)}: ${customer.name}\n');
        builder.addRawText('${padLabel(customNikLabel)}: ${customer.nik}\n');
        builder.addRawText('${padLabel(customTelpLabel)}: ${customer.phone}\n');
        if (spacingAfterNasabah > 0) builder.addFeed(spacingAfterNasabah);
      }

      builder.addDivider(paperSize.charsPerLine);
      builder.addLabelValue(customBarangLabel, tx.collateralType, paperSize.charsPerLine);
      builder.addLabelValue(customMerkLabel, '${tx.brand} ${tx.model}', paperSize.charsPerLine);
      builder.addLabelValue(customKondisiLabel, tx.condition, paperSize.charsPerLine);

      builder.addDivider(paperSize.charsPerLine);
      builder.addKeyValue(customNominalLabel, _formatRupiah(tx.principal), paperSize.charsPerLine);
      builder.addKeyValue(customJasaLabel, _formatRupiah(tx.dailyFee), paperSize.charsPerLine);
      builder.addKeyValue(customPeriodeLabel, '${tx.periodDays} Hari', paperSize.charsPerLine);
      builder.addKeyValue(customTotalJasaLabel, _formatRupiah(tx.totalFee), paperSize.charsPerLine);

      builder.addDivider(paperSize.charsPerLine, char: '=');
      builder.addKeyValue(
        customTotalTebusLabel,
        _formatRupiah(tx.totalRepayment),
        paperSize.charsPerLine,
        bold: true,
      );

      builder.addDivider(paperSize.charsPerLine);
      builder.addKeyValue(
        customJatuhTempoLabel,
        _formatDate(tx.dateDue),
        paperSize.charsPerLine,
        bold: true,
      );
      builder.addDivider(paperSize.charsPerLine);
      if (spacingAfterPrices > 0) builder.addFeed(spacingAfterPrices);

      if (showTerms) {
        if (customTermsText.isNotEmpty) {
          for (final line in customTermsText.split('\n')) {
            builder.addLine(line, align: alignTerms);
          }
        } else {
          builder.addLine('- Barang tidak diambil > 30 hari', align: alignTerms);
          builder.addLine('  bukan tanggung jawab kami.', align: alignTerms);
          builder.addLine('- Biaya penitipan tetap berjalan.', align: alignTerms);
        }
        if (customFooter.isNotEmpty) {
          builder.addLine(customFooter, align: alignFooter);
        }
        builder.addDivider(paperSize.charsPerLine);
        if (spacingAfterTerms > 0) builder.addFeed(spacingAfterTerms);
      }

      if (showSignature) {
        final sigWidth = paperSize.charsPerLine ~/ 2 - 2;
        final leftSig = customSignatureLeft.padRight(sigWidth);
        final rightSig = customSignatureRight.padLeft(sigWidth);
        builder.addRawText('$leftSig  $rightSig\n\n');

        String fitName(String name, int width, {bool alignRight = false}) {
          String trimmed = name.trim();
          if (trimmed.length > width - 4) trimmed = trimmed.substring(0, width - 4);
          final formatted = '( $trimmed )';
          return alignRight ? formatted.padLeft(width) : formatted.padRight(width);
        }
        final leftName = fitName(customer.name, sigWidth);
        final rightName = fitName(customSignatureRight, sigWidth, alignRight: true);
        builder.addRawText('$leftName  $rightName\n');
      }

      builder.addFeed(endFeedLines);
      builder.resetLineSpacing();
      builder.addCut();

      return await _sendBytesChunked(builder.toBytes());
    } catch (e) {
      debugPrint('Error printing perjanjian gadai: $e');
      return false;
    }
  }

  // -----------------------------------------------
  // 2. STRUK PERPANJANGAN TENOR
  // -----------------------------------------------

  Future<bool> printPerpanjangan(
    PawnTransaction tx,
    Customer customer,
    ExtensionHistory ext,
  ) async {
    if (!await ensureConnected()) return false;
    try {
      final builder = EscPosBufferBuilder();
      builder.init();
      builder.setLineSpacing(lineSpacing);

      _buildHeader(builder);
      builder.addLine('STRUK PERPANJANGAN', align: alignTitle, bold: true, doubleSize: doubleSizeTitle);
      builder.addDivider(paperSize.charsPerLine);

      builder.addKeyValue('No', tx.displayCode, paperSize.charsPerLine);
      builder.addKeyValue('Tgl', _formatDate(ext.tglPerpanjangan), paperSize.charsPerLine);

      if (showNasabah) {
        builder.addDivider(paperSize.charsPerLine);
        String padLabel(String label) => label.padRight(9);
        builder.addRawText('${padLabel(customNasabahLabel)}: ${customer.name}\n');
        builder.addRawText('${padLabel(customTelpLabel)}: ${customer.phone}\n');
      }

      builder.addDivider(paperSize.charsPerLine);
      builder.addLabelValue(customMerkLabel, '${tx.brand} ${tx.model}', paperSize.charsPerLine);

      builder.addDivider(paperSize.charsPerLine);
      builder.addKeyValue('Jasa Dibayar', _formatRupiah(ext.jatipDibayar), paperSize.charsPerLine);
      builder.addKeyValue('Tempo Lama', _formatDateShort(ext.tglTempoLama), paperSize.charsPerLine);
      builder.addKeyValue('Tempo Baru', _formatDateShort(ext.tglTempoBaru), paperSize.charsPerLine, bold: true);

      builder.addDivider(paperSize.charsPerLine, char: '=');
      builder.addKeyValue('BAYAR', _formatRupiah(ext.jatipDibayar), paperSize.charsPerLine, bold: true);
      builder.addDivider(paperSize.charsPerLine, char: '=');

      if (showTerms) {
        if (customTermsText.isNotEmpty) {
          for (final line in customTermsText.split('\n')) {
            builder.addLine(line, align: alignTerms);
          }
        } else {
          builder.addLine('Simpan struk ini sebagai', align: alignTerms);
          builder.addLine('bukti perpanjangan gadai.', align: alignTerms);
        }
        if (customFooter.isNotEmpty) {
          builder.addLine(customFooter, align: alignFooter);
        }
      }
      builder.addLine('www.galaxigroup.id', align: 1);

      builder.addFeed(endFeedLines);
      builder.resetLineSpacing();
      builder.addCut();

      return await _sendBytesChunked(builder.toBytes());
    } catch (e) {
      debugPrint('Error printing perpanjangan: $e');
      return false;
    }
  }

  // -----------------------------------------------
  // 3. STRUK PELUNASAN / TEBUS
  // -----------------------------------------------

  Future<bool> printPelunasan(
    PawnTransaction tx,
    Customer customer,
  ) async {
    if (!await ensureConnected()) return false;
    try {
      final builder = EscPosBufferBuilder();
      builder.init();
      builder.setLineSpacing(lineSpacing);

      _buildHeader(builder);
      builder.addLine('STRUK PELUNASAN', align: alignTitle, bold: true, doubleSize: doubleSizeTitle);
      builder.addDivider(paperSize.charsPerLine);

      builder.addKeyValue('No', tx.displayCode, paperSize.charsPerLine);
      builder.addKeyValue('Tgl Lunas', _formatDate(DateTime.now()), paperSize.charsPerLine);

      if (showNasabah) {
        builder.addDivider(paperSize.charsPerLine);
        String padLabel(String label) => label.padRight(9);
        builder.addRawText('${padLabel(customNasabahLabel)}: ${customer.name}\n');
        builder.addRawText('${padLabel(customTelpLabel)}: ${customer.phone}\n');
        if (spacingAfterNasabah > 0) builder.addFeed(spacingAfterNasabah);
      }

      builder.addDivider(paperSize.charsPerLine);
      builder.addLabelValue(customBarangLabel, tx.collateralType, paperSize.charsPerLine);
      builder.addLabelValue(customMerkLabel, '${tx.brand} ${tx.model}', paperSize.charsPerLine);

      builder.addDivider(paperSize.charsPerLine);
      builder.addKeyValue(customNominalLabel, _formatRupiah(tx.principal), paperSize.charsPerLine);
      builder.addKeyValue(customTotalJasaLabel, _formatRupiah(tx.totalFee), paperSize.charsPerLine);
      builder.addDivider(paperSize.charsPerLine, char: '=');

      builder.addKeyValue('LUNAS', _formatRupiah(tx.totalRepayment), paperSize.charsPerLine, bold: true);
      builder.addDivider(paperSize.charsPerLine, char: '=');
      if (spacingAfterPrices > 0) builder.addFeed(spacingAfterPrices);

      builder.addLine('BARANG TELAH DITEBUS', align: 1, bold: true);

      if (showTerms) {
        if (customTermsText.isNotEmpty) {
          for (final line in customTermsText.split('\n')) {
            builder.addLine(line, align: alignTerms);
          }
        } else {
          builder.addLine('Simpan struk ini sebagai', align: alignTerms);
          builder.addLine('bukti pelunasan resmi.', align: alignTerms);
        }
        if (customFooter.isNotEmpty) {
          builder.addLine(customFooter, align: alignFooter);
        }
        builder.addDivider(paperSize.charsPerLine);
      }
      builder.addLine('www.galaxigroup.id', align: 1);

      builder.addFeed(endFeedLines);
      builder.resetLineSpacing();
      builder.addCut();

      return await _sendBytesChunked(builder.toBytes());
    } catch (e) {
      debugPrint('Error printing pelunasan: $e');
      return false;
    }
  }

  // -----------------------------------------------
  // 4. TEST PAGE
  // -----------------------------------------------

  Future<bool> printTestPage() async {
    if (!await ensureConnected()) return false;
    try {
      final builder = EscPosBufferBuilder();
      builder.init();
      builder.setLineSpacing(lineSpacing);

      builder.addDivider(paperSize.charsPerLine, char: '=');
      builder.addLine('GALAXI GADAI', align: 1, bold: true, doubleSize: true);
      builder.addLine('--- TEST PRINT ---', align: 1);
      builder.addDivider(paperSize.charsPerLine, char: '=');

      builder.addLine('Printer: ${_connectedDevice?.name ?? "Unknown"}', align: 0);
      builder.addLine('Kertas : ${paperSize.label}', align: 0);
      builder.addLine('Lebar  : ${paperSize.charsPerLine} karakter', align: 0);
      builder.addDivider(paperSize.charsPerLine);

      builder.addLine('NORMAL TEXT', align: 0);
      builder.addLine('BOLD TEXT', align: 0, bold: true);
      builder.addLine('DOUBLE SIZE', align: 0, doubleSize: true);
      builder.addLine('CENTER ALIGN', align: 1);
      builder.addLine('RIGHT ALIGN', align: 2);
      builder.addDivider(paperSize.charsPerLine);

      builder.addKeyValue('Nominal', 'Rp 1.000.000', paperSize.charsPerLine);
      builder.addKeyValue('Jasa Titip', 'Rp 5.000', paperSize.charsPerLine);
      builder.addDivider(paperSize.charsPerLine, char: '=');

      builder.addRawText('0123456789 ABCDEFGHIJ\n');
      builder.addRawText('KLMNOPQRSTUVWXYZ\n');
      builder.addRawText('abcdefghijklmnopqrst\n');
      builder.addDivider(paperSize.charsPerLine, char: '=');

      builder.addLine('Printer Thermal OK!', align: 1, bold: true, doubleSize: true);

      builder.addFeed(endFeedLines);
      builder.resetLineSpacing();
      builder.addCut();

      return await _sendBytesChunked(builder.toBytes());
    } catch (e) {
      debugPrint('Error printing test page: $e');
      return false;
    }
  }
}
