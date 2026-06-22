import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.showFCMNotification(message);
}

class NotificationService {
  static final AwesomeNotifications _awesome = AwesomeNotifications();
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    await _awesome.initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'transaction_channel',
          channelName: 'Transaksi Tiket',
          channelDescription: 'Notifikasi konfirmasi pembayaran',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
        NotificationChannel(
          channelKey: 'reminder_channel',
          channelName: 'Pengingat Pertunjukan',
          channelDescription: 'Notifikasi H-1 dan Hari-H sebelum acara dimulai',
          defaultColor: const Color(0xFF00C853),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
        NotificationChannel(
          channelKey: 'payment_reminder_channel',
          channelName: 'Pengingat Pembayaran',
          channelDescription: 'Notifikasi pembayaran tertunda atau hampir hangus',
          defaultColor: const Color(0xFFFF9800),
          importance: NotificationImportance.High,
        )
      ],
    );

    await _fcm.requestPermission();
    await _awesome.isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        _awesome.requestPermissionToSendNotifications();
      }
    });

    FirebaseMessaging.onMessage.listen(showFCMNotification);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _saveFCMToken();
  }

  static Future<void> _saveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    }
  }

  // ── FCM NOTIFICATION ─────────────────────────────────────────────────────
  static Future<void> showFCMNotification(RemoteMessage message) async {
    if (message.data.isNotEmpty) {
      final action = message.data['action'];
      final pesananId = message.data['pesananId'];

      // Jika webhook midtrans mengirimkan info sukses pembayaran
      if (action == 'payment_success' && pesananId != null) {
        await cancelPaymentReminders(pesananId);
        if (message.data['tanggalPertunjukan'] != null) {
          final tanggal = DateTime.parse(message.data['tanggalPertunjukan']);
          await schedulePertunjukanReminders(
            pesananId: pesananId,
            judul: message.data['judulPertunjukan'] ?? 'Pertunjukan',
            tanggalPertunjukan: tanggal,
          );
        }
      }

      await _awesome.createNotification(
        content: NotificationContent(
          id: pesananId != null ? pesananId.hashCode : message.hashCode,
          channelKey: 'transaction_channel',
          title: message.data['title'] ?? 'Info IndoneSaku',
          body: message.data['body'] ?? 'Cek detail tiket Anda.',
          notificationLayout: NotificationLayout.Default,
        ),
      );
    }
  }

  // ── NOTIFICATION PAYMENT SUCCESS (LOCAL) ────────────────────────────────────────────────
  static Future<void> showPaymentSuccessNotification(String pesananId, String judul) async {
    await _awesome.createNotification(
      content: NotificationContent(
        id: pesananId.hashCode,
        channelKey: 'transaction_channel', // Gunakan channel transaksi berwarna ungu
        title: 'Pembayaran Berhasil! 🎉',
        body: 'Hore! Tiket "$judul" sudah lunas dan aman di menu Tiketmu.',
      ),
    );
  }

  // ── NOTIFICATION H-1 DAN HARI-H ────────────────────────────────────────────────
  static Future<void> schedulePertunjukanReminders({
    required String pesananId,
    required String judul,
    required DateTime tanggalPertunjukan,
  }) async {
    final now = DateTime.now();

    // 1. Jadwal H-1 (24 jam sebelum acara)
    final hMinus1Time = tanggalPertunjukan.subtract(const Duration(days: 1));
    if (hMinus1Time.isAfter(now)) {
      await _awesome.createNotification(
        content: NotificationContent(
          id: (pesananId + "_h1").hashCode,
          channelKey: 'reminder_channel',
          title: 'Pengingat Pertunjukan Besok! 🎭',
          body: 'Jangan lupa, pertunjukan "$judul" akan dimulai besok.',
        ),
        schedule: NotificationCalendar.fromDate(date: hMinus1Time),
      );
    }

    // 2. Jadwal Hari-H (3 jam sebelum acara dimulai)
    final hariHTime = tanggalPertunjukan.subtract(const Duration(hours: 3));
    if (hariHTime.isAfter(now)) {
      await _awesome.createNotification(
        content: NotificationContent(
          id: (pesananId + "_h0").hashCode,
          channelKey: 'reminder_channel',
          title: 'Hari Ini Pertunjukan Dimulai! 🚀',
          body: 'Siapkan tiket Anda, "$judul" akan dimulai dalam 3 jam.',
        ),
        schedule: NotificationCalendar.fromDate(date: hariHTime),
      );
    }
  }

  // ── TRANSAKSI TERTUNDA & KEDALUWARSA ───────────────────────────────────────
  
  static Future<void> showPendingPaymentNotification(String judul) async {
    await _awesome.createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecond,
        channelKey: 'payment_reminder_channel',
        title: 'Pembayaran Belum Selesai ⚠️',
        body: 'Tiket "$judul" Anda menunggu pembayaran. Selesaikan segera agar tidak hangus.',
      ),
    );
  }

  static Future<void> schedulePaymentExpiryReminder({
    required String pesananId,
    required String judul,
    required DateTime batasWaktu,
  }) async {
    final now = DateTime.now();

    // 1. Pengingat 2 Jam Sebelum Batas Waktu 
    // (Cocok untuk Transfer Bank / VA yang expired-nya 24 jam)
    final reminder2Hours = batasWaktu.subtract(const Duration(hours: 2));
    if (reminder2Hours.isAfter(now)) {
      await _awesome.createNotification(
        content: NotificationContent(
          id: (pesananId + "_expiry").hashCode,
          channelKey: 'payment_reminder_channel',
          title: 'Batas Pembayaran Hampir Habis! ⏰',
          body: 'Waktu pembayaran tiket "$judul" sisa 2 jam. Segera selesaikan sebelum hangus.',
        ),
        schedule: NotificationCalendar.fromDate(date: reminder2Hours),
      );
    }

    // 2. Pengingat 10 Menit Sebelum Batas Waktu
    // (Sangat penting untuk E-Wallet/QRIS yang expired-nya singkat, misal 15 menit)
    final reminder10Minutes = batasWaktu.subtract(const Duration(minutes: 10));
    if (reminder10Minutes.isAfter(now)) {
      await _awesome.createNotification(
        content: NotificationContent(
          id: (pesananId + "_expiry_10m").hashCode, // ID unik berbeda
          channelKey: 'payment_reminder_channel',
          title: 'Waktu Pembayaran Sisa 10 Menit! ⏳',
          body: 'Tiket "$judul" kamu akan otomatis dibatalkan dalam 10 menit. Yuk bayar sekarang!',
        ),
        schedule: NotificationCalendar.fromDate(date: reminder10Minutes),
      );
    }
  }

  // Bersihkan SEMUA reminder pembayaran jika user akhirnya melunasi tiket
  static Future<void> cancelPaymentReminders(String pesananId) async {
    await _awesome.cancel((pesananId + "_expiry").hashCode);      // Batal pengingat 2 jam
    await _awesome.cancel((pesananId + "_expiry_10m").hashCode);  // Batal pengingat 10 menit
  }
}