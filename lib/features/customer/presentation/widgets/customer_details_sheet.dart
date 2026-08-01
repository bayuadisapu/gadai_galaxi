import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/data_models.dart';
import 'package:galaxi_gadai/core/services/supabase_gadai_service.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/extension_page.dart';
import 'package:galaxi_gadai/features/pawn/presentation/pages/redemption_page.dart';

class CustomerDetailsSheet extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsSheet({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailsSheet> createState() => _CustomerDetailsSheetState();
}

class _CustomerDetailsSheetState extends State<CustomerDetailsSheet> {
  List<PawnTransaction> _customerTxs = [];
  bool _isLoading = true;
  bool _isUploadingKtp = false;
  late Customer _customer;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadTxs();
  }

  Future<void> _loadTxs() async {
    try {
      final txs = await SupabaseGadaiService.instance
          .fetchTransactions(nasabahId: _customer.id);
      if (!mounted) return;
      setState(() {
        _customerTxs = txs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ── Upload KTP ──
  Future<void> _pickAndUploadKtp(ImageSource source) async {
    Navigator.pop(context); // tutup bottom sheet source picker
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked == null) return;
      setState(() => _isUploadingKtp = true);

      final bytes = await picked.readAsBytes();
      final url = await SupabaseGadaiService.instance.uploadNasabahKtp(
        nasabahId: _customer.id,
        imageBytes: bytes,
      );

      if (!mounted) return;
      setState(() {
        _isUploadingKtp = false;
        if (url != null) {
          _customer = Customer(
            id: _customer.id,
            name: _customer.name,
            nik: _customer.nik,
            birthPlace: _customer.birthPlace,
            birthDate: _customer.birthDate,
            gender: _customer.gender,
            phone: _customer.phone,
            address: _customer.address,
            cabangId: _customer.cabangId,
            ktpPhotoUrl: url,
          );
        }
      });

      _showSnack(url != null ? '✅ Foto KTP berhasil diupload!' : '❌ Gagal upload foto KTP', isError: url == null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingKtp = false);
      _showSnack('Gagal: $e', isError: true);
    }
  }

  void _showKtpSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Upload Foto KTP', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _sourceBtn(Icons.camera_alt_rounded, 'Kamera', const Color(0xFF2563EB), () => _pickAndUploadKtp(ImageSource.camera))),
              const SizedBox(width: 12),
              Expanded(child: _sourceBtn(Icons.photo_library_rounded, 'Galeri', const Color(0xFF7C3AED), () => _pickAndUploadKtp(ImageSource.gallery))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sourceBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );
  }

  void _viewKtpFullscreen() {
    if (_customer.ktpPhotoUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _KtpFullscreenPage(
          imageUrl: _customer.ktpPhotoUrl,
          nasabahName: _customer.name,
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _formatCurrency(int val) {
    final s = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  String _formatIndonesianDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // ── Drag Handle ──
          Center(
            child: Container(
              width: 48, height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // ── Header ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _customer.name.isNotEmpty ? _customer.name[0].toUpperCase() : 'N',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_customer.name, style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('NIK: ${_customer.nik.isNotEmpty ? _customer.nik : '-'}',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_customer.gender,
                      style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Scrollable Body ──
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── FOTO KTP CARD ──
                  _buildKtpCard(),
                  const SizedBox(height: 16),

                  // ── Informasi Personal ──
                  _buildSectionCard(
                    title: 'Informasi Personal',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _buildDetailRow(Icons.cake_outlined, 'Tempat, Tgl Lahir',
                          '${_customer.birthPlace.isNotEmpty ? _customer.birthPlace : '-'}, ${_customer.birthDate.isNotEmpty ? _customer.birthDate : '-'}'),
                      _buildDetailRow(Icons.phone_outlined, 'Nomor Telepon', _customer.phone.isNotEmpty ? _customer.phone : '-'),
                      _buildDetailRow(Icons.home_outlined, 'Alamat Lengkap', _customer.address.isNotEmpty ? _customer.address : '-'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Transaksi ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transaksi Gadai', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                        child: Text('${_customerTxs.length} item',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_customerTxs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Icon(Icons.assignment_late_outlined, size: 40, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          Text('Nasabah belum memiliki riwayat gadai.',
                              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _customerTxs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, idx) => _buildTransactionCard(_customerTxs[idx]),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Foto KTP Card ──
  Widget _buildKtpCard() {
    final hasPhoto = _customer.ktpPhotoUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPhoto ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: hasPhoto ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.badge_rounded,
                      size: 18,
                      color: hasPhoto ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Foto KTP', style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(
                      hasPhoto ? 'Foto tersedia' : 'Belum ada foto KTP',
                      style: GoogleFonts.inter(
                        color: hasPhoto ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ]),
                ]),
                // Upload / Ganti button
                GestureDetector(
                  onTap: _isUploadingKtp ? null : _showKtpSourceSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _isUploadingKtp
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              hasPhoto ? Icons.edit_rounded : Icons.upload_rounded,
                              color: Colors.white, size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              hasPhoto ? 'Ganti' : 'Upload',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ]),
                  ),
                ),
              ],
            ),
          ),

          // Photo Area
          if (hasPhoto) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            GestureDetector(
              onTap: _viewKtpFullscreen,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    child: Image.network(
                      // Cache buster agar update KTP langsung kelihatan
                      '${_customer.ktpPhotoUrl}?t=${DateTime.now().millisecondsSinceEpoch ~/ 10000}',
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              height: 180,
                              color: const Color(0xFFF1F5F9),
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: const Color(0xFFF1F5F9),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.broken_image_rounded, color: Color(0xFFCBD5E1), size: 40),
                          const SizedBox(height: 6),
                          Text('Gagal memuat gambar', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                        ]),
                      ),
                    ),
                  ),
                  // Tap to view hint
                  Positioned(
                    bottom: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text('Lihat penuh', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // No photo state
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            GestureDetector(
              onTap: _isUploadingKtp ? null : _showKtpSourceSheet,
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFCBD5E1), size: 36),
                  const SizedBox(height: 6),
                  Text('Tap untuk upload foto KTP', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF64748B), size: 17),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTransactionCard(PawnTransaction tx) {
    Color statusColor = AppColors.primary;
    Color statusBg = const Color(0xFFEFF6FF);
    if (tx.status == 'Macet') { statusColor = const Color(0xFFEF4444); statusBg = const Color(0xFFFEF2F2); }
    else if (tx.status == 'Lunas') { statusColor = const Color(0xFF10B981); statusBg = const Color(0xFFECFDF5); }
    else if (tx.status == 'Lelang' || tx.status == 'Terjual') { statusColor = const Color(0xFF8B5CF6); statusBg = const Color(0xFFF5F3FF); }
    else if (tx.status == 'Menunggu Verifikasi') { statusColor = const Color(0xFFF59E0B); statusBg = const Color(0xFFFFFBEB); }

    final daysRemaining = tx.dateDue.difference(DateTime.now()).inDays;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(
                tx.collateralType == 'Emas'
                    ? Icons.workspace_premium_outlined
                    : tx.collateralType == 'Motor / Mobil'
                        ? Icons.two_wheeler_rounded
                        : Icons.phone_android_rounded, // default 'Barang' → ikon HP/elektronik
                color: AppColors.primary, size: 20,
              ),
              const SizedBox(width: 8),
              Text('${tx.brand} ${tx.model}',
                  style: GoogleFonts.inter(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
              child: Text(tx.status, style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _buildTxRow('No. Kontrak', tx.displayCode),
            _buildTxRow('Nominal Pinjaman', 'Rp ${_formatCurrency(tx.principal)}'),
            _buildTxRow('Jasa Titip Harian', 'Rp ${_formatCurrency(tx.dailyFee)} / hari'),
            _buildTxRow(
              'Jatuh Tempo',
              '${_formatIndonesianDate(tx.dateDue)}${tx.status == 'Aktif' ? ' ($daysRemaining hari lagi)' : ''}',
              valueColor: tx.status == 'Macet' ? const Color(0xFFEF4444) : AppColors.textDark,
            ),
          ]),
        ),
        if (tx.status != 'Lunas' && tx.status != 'Terjual') ...[
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExtensionPage(prefilledTxId: tx.id))).then((_) => setState(() {})),
                  icon: const Icon(Icons.autorenew_rounded, size: 16),
                  label: const Text('Perpanjang', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RedemptionPage(prefilledTxId: tx.id))).then((_) => setState(() {})),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                  label: const Text('Lunasi / Tebus', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildTxRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: GoogleFonts.inter(color: valueColor ?? AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Halaman fullscreen lihat KTP ──
class _KtpFullscreenPage extends StatelessWidget {
  final String imageUrl;
  final String nasabahName;

  const _KtpFullscreenPage({required this.imageUrl, required this.nasabahName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'KTP — $nasabahName',
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, __, ___) => Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 60),
              SizedBox(height: 12),
              Text('Gagal memuat gambar', style: TextStyle(color: Colors.white54)),
            ]),
          ),
        ),
      ),
    );
  }
}
