import 'package:flutter/material.dart';
import 'package:galaxi_gadai/core/constants/app_colors.dart';
import 'package:galaxi_gadai/core/data/mock_data.dart';

/// Notifikasi model sederhana
class _Notif {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final DateTime time;
  final bool isRead;

  const _Notif({required this.title, required this.body, required this.icon, required this.color, required this.time, this.isRead = false});
}

/// Generate notifikasi dari data yang diberikan
List<_Notif> _generateNotifications(List<PawnTransaction> transactions, List<Customer> customers) {
  final List<_Notif> notifs = [];
  final now = DateTime.now();

  for (final tx in transactions) {
    final customer = customers.firstWhere(
      (c) => c.id == tx.customerId,
      orElse: () => Customer(id: '', name: 'Unknown', nik: '', birthPlace: '', birthDate: '', gender: '', phone: '', address: ''),
    );
    final daysLeft = tx.dateDue.difference(now).inDays;

    if (tx.status == 'Macet') {
      notifs.add(_Notif(
        title: '🔴 Transaksi Macet',
        body: '${customer.name} — ${tx.brand} ${tx.model} telah melewati jatuh tempo.',
        icon: Icons.warning_rounded,
        color: const Color(0xFFEF4444),
        time: tx.dateDue.add(const Duration(days: 1)),
      ));
    } else if (tx.status == 'Aktif' && daysLeft <= 3 && daysLeft >= 0) {
      notifs.add(_Notif(
        title: '⚠️ Jatuh Tempo Segera',
        body: '${customer.name} — ${tx.brand} ${tx.model} jatuh tempo dalam $daysLeft hari.',
        icon: Icons.timer_outlined,
        color: const Color(0xFFF59E0B),
        time: now.subtract(Duration(hours: 3 - daysLeft)),
        isRead: daysLeft == 3,
      ));
    } else if (tx.status == 'Aktif' && daysLeft <= 7 && daysLeft > 3) {
      notifs.add(_Notif(
        title: '🔔 Pengingat Jatuh Tempo',
        body: '${customer.name} — ${tx.brand} ${tx.model} jatuh tempo $daysLeft hari lagi.',
        icon: Icons.notifications_outlined,
        color: AppColors.primary,
        time: now.subtract(const Duration(hours: 6)),
        isRead: true,
      ));
    }
  }

  notifs.sort((a, b) {
    if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
    return b.time.compareTo(a.time);
  });

  return notifs;
}

class NotificationPanel extends StatefulWidget {
  final List<PawnTransaction> transactions;
  final List<Customer> customers;
  const NotificationPanel({super.key, required this.transactions, required this.customers});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  late List<_Notif> _notifs;

  @override
  void initState() {
    super.initState();
    _notifs = _generateNotifications(widget.transactions, widget.customers);
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  void _markAllRead() {
    setState(() {
      _notifs = _notifs.map((n) => _Notif(title: n.title, body: n.body, icon: n.icon, color: n.color, time: n.time, isRead: true)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifs.where((n) => !n.isRead).length;
    return DraggableScrollableSheet(
      initialChildSize: 0.65, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
          child: Column(children: [
            Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Notifikasi', style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (unreadCount > 0) Text('$unreadCount belum dibaca', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ]),
                if (unreadCount > 0) TextButton(onPressed: _markAllRead, child: const Text('Tandai semua dibaca', style: TextStyle(color: AppColors.primary, fontSize: 12))),
              ]),
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Expanded(
              child: _notifs.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('Tidak ada notifikasi', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                    ]))
                  : ListView.separated(
                      controller: scrollController, padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _notifs.length, separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                      itemBuilder: (context, i) {
                        final n = _notifs[i];
                        return GestureDetector(
                          onTap: () => setState(() => _notifs[i] = _Notif(title: n.title, body: n.body, icon: n.icon, color: n.color, time: n.time, isRead: true)),
                          child: Container(
                            color: n.isRead ? Colors.transparent : n.color.withValues(alpha: 0.04),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(width: 42, height: 42, decoration: BoxDecoration(color: n.color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(n.icon, color: n.color, size: 20)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(n.title, style: TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold))),
                                  if (!n.isRead) Container(width: 8, height: 8, decoration: BoxDecoration(color: n.color, shape: BoxShape.circle)),
                                ]),
                                const SizedBox(height: 4),
                                Text(n.body, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
                                const SizedBox(height: 4),
                                Text(_timeAgo(n.time), style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 11)),
                              ])),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }
}

/// Utility to show notification panel as bottom sheet
void showNotificationPanel(BuildContext context, {List<PawnTransaction>? transactions, List<Customer>? customers}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NotificationPanel(transactions: transactions ?? [], customers: customers ?? []),
  );
}
