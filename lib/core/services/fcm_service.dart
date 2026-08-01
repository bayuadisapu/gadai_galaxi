import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum NotifPermissionStatus { granted, denied, permanentlyDenied }

/// Handler untuk background messages (harus top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] ${message.notification?.title}: ${message.notification?.body}');
}

/// Service untuk Firebase Cloud Messaging (Push Notification)
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'galaxi_gadai_payments';
  static const _channelName = 'Pembayaran Gadai';
  static const _channelDesc = 'Notifikasi verifikasi pembayaran nasabah';

  bool _initialized = false;

  /// Inisialisasi FCM & local notifications. Aman dipanggil berkali-kali.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Setup Android notification channel
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // 2. Init flutter_local_notifications
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _localNotif.initialize(initSettings);

      // 3. Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Foreground FCM → tampilkan sebagai local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notif = message.notification;
        if (notif != null) {
          _showLocalNotification(
            title: notif.title ?? 'Galaxi Gadai',
            body: notif.body ?? '',
          );
        }
      });

      _initialized = true;
      debugPrint('[FCM] Service initialized');
    } catch (e) {
      debugPrint('[FCM] initialize error: $e');
      // Jangan set _initialized = true jika gagal agar bisa diulang
    }
  }

  /// Minta izin notifikasi dari user — munculkan dialog sistem.
  /// Return status: granted / denied / permanentlyDenied.
  Future<NotifPermissionStatus> requestPermission() async {
    if (!_initialized) await initialize();

    try {
      // Android 13+: request via flutter_local_notifications
      final bool? androidGranted = await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // iOS: request via firebase_messaging
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final iosStatus = settings.authorizationStatus;

      // Jika Android API < 33, androidGranted == null → anggap granted
      final isAndroidGranted = androidGranted ?? true;
      final isIosGranted = iosStatus == AuthorizationStatus.authorized ||
          iosStatus == AuthorizationStatus.provisional;
      final isIosDenied = iosStatus == AuthorizationStatus.denied;

      NotifPermissionStatus status;
      if (isAndroidGranted || isIosGranted) {
        status = NotifPermissionStatus.granted;
      } else if (isIosDenied) {
        // iOS tidak bisa beda antara denied vs permanentlyDenied
        status = NotifPermissionStatus.permanentlyDenied;
      } else {
        // Android: androidGranted == false → bisa denied atau permanentlyDenied
        // Cara bedain: coba request lagi — jika sistem langsung tolak tanpa popup
        // maka permanently denied. Kita anggap denied saja agar tidak overcomplicate.
        status = NotifPermissionStatus.denied;
      }

      debugPrint('[FCM] Permission: $status (android=$androidGranted, ios=$iosStatus)');
      return status;
    } catch (e) {
      debugPrint('[FCM] requestPermission error: $e');
      return NotifPermissionStatus.denied;
    }
  }

  /// Ambil FCM token device
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('[FCM] Token: $token');
      return token;
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  /// Simpan FCM token ke tabel profiles (staff admin/superadmin)
  Future<void> saveStaffFcmToken(String userId) async {
    try {
      final token = await getToken();
      if (token == null) return;
      await Supabase.instance.client.from('profiles').update({
        'fcm_token': token,
        'fcm_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('[FCM] Token saved for staff $userId');
    } catch (e) {
      debugPrint('[FCM] saveStaffFcmToken error: $e');
    }
  }

  /// Simpan FCM token ke tabel gadai_nasabah_accounts (nasabah)
  Future<void> saveNasabahFcmToken(String phone) async {
    try {
      final token = await getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('gadai_nasabah_accounts')
          .update({
            'fcm_token': token,
            'fcm_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('phone', phone);
      debugPrint('[FCM] Token saved for nasabah $phone');
    } catch (e) {
      debugPrint('[FCM] saveNasabahFcmToken error: $e');
    }
  }

  /// Tampilkan local notification internal
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      debugPrint('[FCM] Tidak bisa tampilkan notifikasi — belum di-initialize');
      return;
    }
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: Color(0xFFD4A017),
        playSound: true,
        enableVibration: true,
        fullScreenIntent: false,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _localNotif.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
        title,
        body,
        details,
        payload: payload,
      );
      debugPrint('[FCM] Notifikasi ditampilkan: $title');
    } catch (e) {
      debugPrint('[FCM] _showLocalNotification error: $e');
    }
  }

  /// Notifikasi ke ADMIN: ada permintaan pembayaran baru dari nasabah
  Future<void> showPaymentRequestNotification({
    required String nasabahName,
    required String txCode,
    required String paymentType,
  }) async {
    if (!_initialized) await initialize();
    final typeLabel = paymentType == 'tebus' ? 'Tebus Barang' : 'Perpanjang Tenor';
    await _showLocalNotification(
      title: '💰 Permintaan Pembayaran Baru',
      body: '$nasabahName — $typeLabel ($txCode). Ketuk untuk verifikasi.',
      payload: 'payment_request:$txCode',
    );
  }

  /// Notifikasi ke NASABAH: pembayaran dikonfirmasi admin
  Future<void> showPaymentVerifiedNotification({
    required String txCode,
    required String paymentType,
  }) async {
    if (!_initialized) await initialize();
    final msg = paymentType == 'tebus'
        ? 'Pelunasan dikonfirmasi! Silakan ambil barang di toko.'
        : 'Perpanjangan tenor dikonfirmasi! Jatuh tempo sudah diperbarui.';
    await _showLocalNotification(
      title: '✅ Pembayaran Dikonfirmasi — $txCode',
      body: msg,
      payload: 'payment_verified:$txCode',
    );
  }

  /// Notifikasi ke NASABAH: pembayaran ditolak admin
  Future<void> showPaymentRejectedNotification({
    required String txCode,
    String? reason,
  }) async {
    if (!_initialized) await initialize();
    await _showLocalNotification(
      title: '❌ Pembayaran Ditolak — $txCode',
      body: reason ?? 'Silakan hubungi admin untuk informasi lebih lanjut.',
      payload: 'payment_rejected:$txCode',
    );
  }

  /// Reset state (untuk testing)
  void reset() {
    _initialized = false;
  }
}
