import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tiket.dart';

/// Hasil dari proses get snap token.
class SnapTokenResult {
  final String snapToken;
  final String redirectUrl;

  const SnapTokenResult({required this.snapToken, required this.redirectUrl});
}

/// MidtransService — semua interaksi dengan Midtrans Sandbox.
///
/// ⚠️ Server Key TIDAK boleh ada di Flutter (client).
/// Semua request ke Midtrans API melewati Firebase Cloud Function [createSnapToken].
class MidtransService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
  static final _db = FirebaseFirestore.instance;

  // ── Snap Token ──────────────────────────────────────────────────────────────

  /// Memanggil Cloud Function [createSnapToken] untuk mendapatkan snap token
  /// dari Midtrans Sandbox.
  ///
  /// Cloud Function akan:
  /// 1. Menerima detail pesanan
  /// 2. Hit POST https://app.sandbox.midtrans.com/snap/v1/transactions
  /// 3. Kembalikan { snapToken, redirectUrl }
  static Future<SnapTokenResult> getSnapToken(TiketPesanan pesanan) async {
    try {
      final callable = _functions.httpsCallable('createSnapToken');

      final result = await callable.call({
        'orderId': pesanan.id,           // dipakai sebagai order_id Midtrans
        'grossAmount': pesanan.totalHarga.toInt(),
        'namaPemesan': pesanan.namaPemesan,
        'emailPemesan': pesanan.emailPemesan,
        'items': pesanan.items
            .map((item) => {
                  'id': item.jenisTiketId,
                  'price': item.hargaSatuan.toInt(),
                  'quantity': item.jumlah,
                  'name': item.namaJenisTiket,
                })
            .toList(),
      });

      final data = result.data as Map<String, dynamic>;

      // Simpan snapToken ke Firestore supaya bisa di-reuse jika user
      // kembali ke halaman pembayaran sebelum token expire (~1 jam).
      await _db.collection('pesanan').doc(pesanan.id).update({
        'snapToken': data['snapToken'],
        'midtransOrderId': pesanan.id,
      });

      return SnapTokenResult(
        snapToken: data['snapToken'] as String,
        redirectUrl: data['redirectUrl'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      throw MidtransException(
        'Gagal mendapatkan token pembayaran: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw MidtransException('Terjadi kesalahan. Silakan coba lagi.');
    }
  }

  // ── Status Update (dipanggil setelah WebView callback) ─────────────────────

  /// Dipanggil saat Midtrans Snap mengirimkan callback berhasil.
  /// Update Firestore secara optimistik — status final dikonfirmasi webhook.
  static Future<void> onPembayaranBerhasil({
    required String pesananId,
    required String paymentType,  // contoh: 'qris', 'bank_transfer', 'gopay'
    required String transactionId,
  }) async {
    await _db.collection('pesanan').doc(pesananId).update({
      'statusPembayaran': StatusPembayaran.berhasil.name,
      'statusPesanan': StatusPesanan.dikonfirmasi.name,
      'nomorPembayaran': transactionId,
      'midtransPaymentType': paymentType,
      'namaAkunPembayaran': _labelFromPaymentType(paymentType),
      'metodePembayaran': _metodePembayaranFromPaymentType(paymentType).name,
    });
  }

  /// Dipanggil saat Midtrans Snap mengirimkan callback pending (misalnya
  /// transfer bank belum dikonfirmasi). Status pesanan tetap menunggu.
  static Future<void> onPembayaranPending({
    required String pesananId,
    required String paymentType,
  }) async {
    await _db.collection('pesanan').doc(pesananId).update({
      'midtransPaymentType': paymentType,
      'namaAkunPembayaran': _labelFromPaymentType(paymentType),
      'metodePembayaran': _metodePembayaranFromPaymentType(paymentType).name,
      // statusPembayaran tetap 'menunggu' — webhook yang akan update ke berhasil
    });
  }

  /// Dipanggil saat Midtrans Snap mengirimkan callback gagal/close.
  static Future<void> onPembayaranGagal(String pesananId) async {
    await _db.collection('pesanan').doc(pesananId).update({
      'statusPembayaran': StatusPembayaran.gagal.name,
      'statusPesanan': StatusPesanan.dibatalkan.name,
    });
  }

  /// Membatalkan transaksi langsung ke sistem Midtrans
  static Future<void> cancelTransaction(String orderId) async {
    try {
      final callable = _functions.httpsCallable('cancelMidtransTransaction');
      await callable.call({'orderId': orderId});
    } on FirebaseFunctionsException catch (e) {
      // Jika error karena transaksi memang tidak ada di Midtrans (belum terbayar/terdaftar),
      // kita bisa memilih untuk mengabaikannya agar tetap bisa dibatalkan di Firestore.
      if (e.message?.contains('404') == true || e.message?.contains('doesn\'t exist') == true) {
         return; 
      }
      throw MidtransException(
        'Gagal membatalkan transaksi di Midtrans: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw MidtransException('Terjadi kesalahan saat menghubungi server Midtrans.');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _labelFromPaymentType(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'qris':
        return 'QRIS';
      case 'gopay':
        return 'GoPay';
      case 'shopeepay':
        return 'ShopeePay';
      case 'bank_transfer':
        return 'Transfer Bank';
      case 'bca_klikbca':
      case 'bca_klikpay':
        return 'BCA';
      case 'mandiri_clickpay':
      case 'echannel':
        return 'Mandiri';
      case 'credit_card':
        return 'Kartu Kredit/Debit';
      case 'cstore':
        return 'Minimarket';
      default:
        return paymentType;
    }
  }

  static MetodePembayaran _metodePembayaranFromPaymentType(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'qris':
        return MetodePembayaran.qris;
      case 'gopay':
      case 'shopeepay':
      case 'dana':
      case 'ovo':
        return MetodePembayaran.dompetDigital;
      case 'bank_transfer':
      case 'echannel':
      case 'bca_klikbca':
        return MetodePembayaran.transferBank;
      case 'credit_card':
        return MetodePembayaran.kartuKredit;
      default:
        return MetodePembayaran.qris;
    }
  }
}

class MidtransException implements Exception {
  final String message;
  final String? code;

  MidtransException(this.message, {this.code});

  @override
  String toString() => message;
}