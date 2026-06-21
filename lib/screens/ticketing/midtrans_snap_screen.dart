import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/tiket.dart';
import '../../services/midtrans_service.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';
import 'tiketmu_screen.dart';
import 'rangkuman_pemesanan_screen.dart';

/// Layar InAppWebView untuk menampilkan halaman pembayaran Midtrans Snap.
///
/// Alur:
/// 1. Snap redirectUrl dimuat di WebView.
/// 2. Saat Midtrans selesai, WebView diarahkan ke salah satu callback URL
///    yang berformat: https://fp-indonesaku.web.app/payment/{finish|pending|error|unfinish}
/// 3. WebView mengintersep URL tersebut, mencegah navigasi nyata, lalu
///    memproses hasil pembayaran.
class MidtransSnapScreen extends StatefulWidget {
  final TiketPesanan pesanan;
  final String redirectUrl;
  final bool fromTiketmu;

  const MidtransSnapScreen({
    super.key,
    required this.pesanan,
    required this.redirectUrl,
    this.fromTiketmu = false,
  });

  @override
  State<MidtransSnapScreen> createState() => _MidtransSnapScreenState();
}

class _MidtransSnapScreenState extends State<MidtransSnapScreen> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  bool _isHandled = false; // mencegah double-handle callback

  // Base URL yang dipakai sebagai callback — WebView akan mengintersep path ini.
  static const String _callbackBase = 'https://fp-indonesaku.web.app/payment';

  // ── Helper Get Metode Pembayaran ────────────────────────────────────────────────────────
  
  MetodePembayaran _mapMidtransPaymentToEnum(String paymentType) {
    switch (paymentType) {
      case 'credit_card':
        return MetodePembayaran.kartuKredit;
      case 'bank_transfer':
      case 'echannel':
      case 'bca_va':
      case 'bni_va':
      case 'bri_va':
      case 'permata_va':
      case 'mandiri_va':
      case 'bsi_va':
      case 'cimb_va':
      case 'danamon_va':
      case 'seabank_va':
      case 'saqu_va':
        return MetodePembayaran.transferBank;
      case 'gopay':
      case 'shopeepay':
      case 'qris': // E-wallet dan QRIS sering dianggap serupa di sini
        return MetodePembayaran.qris; // Atau MetodePembayaran.dompetDigital tergantung preferensimu
      case 'cstore':
      case 'akulaku':
      default:
        // Gunakan nilai default jika tidak dikenali (bisa disesuaikan)
        return MetodePembayaran.online; 
    }
  }

  // ── Callback Handler ────────────────────────────────────────────────────────

  void _handleCallbackUrl(String url) {
    if (_isHandled) return;
    _isHandled = true;

    final uri = Uri.parse(url);
    final path = uri.path; // e.g. /payment/finish
    final params = uri.queryParameters;

    final transactionStatus = params['transaction_status'] ?? '';
    final transactionId = params['transaction_id'] ?? '';
    final paymentType = params['payment_type'] ?? '';

    if (path.contains('finish')) {
      if (transactionStatus == 'capture' || transactionStatus == 'settlement') {
        _onBerhasil(paymentType: paymentType, transactionId: transactionId);
      } else if (transactionStatus == 'pending') {
        _onPending(paymentType: paymentType);
      } else {
        _onBerhasil(paymentType: paymentType, transactionId: transactionId);
      }
    } else if (path.contains('pending')) {
      _onPending(paymentType: paymentType);
    } else if (path.contains('cancel') || path.contains('unfinish')) {
      // Jika user menekan tombol batal/kembali dari UI Midtrans
      _onTertunda();
    } else if (path.contains('error')) {
      _onGagal();
    }
  }

  // ── Outcome Handlers ────────────────────────────────────────────────────────

  Future<void> _onBerhasil({
    required String paymentType,
    required String transactionId,
  }) async {
    String realPaymentType = paymentType;

    if (realPaymentType.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('pesanan')
            .doc(widget.pesanan.id)
            .get();

        if (doc.exists && doc.data()!.containsKey('midtransPaymentType')) {
          final webhookPaymentType = doc.data()!['midtransPaymentType'] as String?;
          if (webhookPaymentType != null && webhookPaymentType != 'unknown') {
            realPaymentType = webhookPaymentType; // Dapatkan tipe asli (misal: 'credit_card')
          }
        }
      } catch (_) {}
    }

    try {
      await MidtransService.onPembayaranBerhasil(
        pesananId: widget.pesanan.id,
        paymentType: realPaymentType.isEmpty ? 'unknown' : realPaymentType,
        transactionId: transactionId.isEmpty ? widget.pesanan.id : transactionId,
      );
    } catch (_) {}

    if (!mounted) return;

    widget.pesanan
      ..statusPembayaran = StatusPembayaran.berhasil
      ..statusPesanan = StatusPesanan.dikonfirmasi
      ..metodePembayaran = _mapMidtransPaymentToEnum(realPaymentType)
      ..midtransPaymentType = realPaymentType;

    if (widget.fromTiketmu) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RangkumanPemesananScreen(pesanan: widget.pesanan),
        ),
      );
    }
  }

  Future<void> _onPending({required String paymentType}) async {
    try {
      await MidtransService.onPembayaranPending(
        pesananId: widget.pesanan.id,
        paymentType: paymentType.isEmpty ? 'unknown' : paymentType,
      );
    } catch (_) {}

    if (!mounted) return;

    widget.pesanan.metodePembayaran = _mapMidtransPaymentToEnum(paymentType);
    widget.pesanan.midtransPaymentType = paymentType;
    
    _showStatusDialog(
      icon: Icons.hourglass_top_rounded,
      iconColor: AppColors.warning,
      title: 'Pembayaran Belum Diterima',
      message: 'Pesanan kamu tersimpan! Kamu bisa melanjutkan pembayaran ini nanti di halaman Tiketmu sebelum batas waktu habis.',
      onOkAction: () {
        if (widget.fromTiketmu) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
            (route) => route.isFirst,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TiketmuScreen(pesanan: widget.pesanan)),
          );
        }
      },
    );
  }

  Future<void> _onGagal() async {
    try {
      await MidtransService.onPembayaranGagal(widget.pesanan.id);
    } catch (_) {}

    if (!mounted) return;
    
    _showStatusDialog(
      icon: Icons.cancel_outlined,
      iconColor: AppColors.error,
      title: 'Pembayaran Gagal',
      message: 'Pembayaran dibatalkan atau gagal diproses. Silakan kembali ke halaman Pesan Tiket untuk mengulang.',
      onOkAction: () {
        Navigator.pop(context); // Kembali ke halaman Pesan Tiket
      },
    );
  }

  void _onTertunda() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pembayaran tertunda. Anda dapat melanjutkannya di halaman Tiketmu.'),
        duration: Duration(seconds: 4),
        backgroundColor: AppColors.primary,
      ),
    );

    if (widget.fromTiketmu) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
        (route) => route.isFirst,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TiketmuScreen(pesanan: widget.pesanan)),
      );
    }
  }

  // ── Dialog ──────────────────────────────────────────────────────────────────

  void _showStatusDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required VoidCallback onOkAction,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // 1. Tutup popup dialognya
                onOkAction();       // 2. Jalankan perintah navigasi
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          tooltip: 'Tutup',
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Tutup Halaman?'),
                content: const Text(
                    'Anda belum menyelesaikan pembayaran. Anda masih dapat melanjutkannya nanti di halaman Tiketmu sebelum waktu habis.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Ya, Tutup',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            
            if (confirm == true && mounted) {
              if (!_isHandled) {
                _isHandled = true;
                // Kita tidak lagi memanggil API Gagal, agar status tetap "menunggu"
              }
              if (!context.mounted) return;
              
              if (widget.fromTiketmu) {
                Navigator.pop(context);
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  (route) => route.isFirst,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TiketmuScreen(pesanan: widget.pesanan)),
                );
              }
            }
          },
        ),
        title: const Text(
          'Pembayaran Midtrans',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.redirectUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true, // Wajib diaktifkan untuk intercept
              useOnDownloadStart: true,          // Deteksi tombol download
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStart: (controller, url) {
              if (mounted) setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) {
              if (mounted) setState(() => _isLoading = false);
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url.toString();

              // 1. Intersep Callback Midtrans kita
              if (url.startsWith(_callbackBase)) {
                _handleCallbackUrl(url);
                return NavigationActionPolicy.CANCEL;
              }

              // 2. Izinkan Deep Link (Membuka aplikasi e-wallet luar seperti Gojek/Shopee)
              if (!url.startsWith('http') && !url.startsWith('https')) {
                // Di masa depan bisa tambahkan package url_launcher di sini 
                // if (await canLaunchUrl(Uri.parse(url))) await launchUrl(...);
                return NavigationActionPolicy.CANCEL; 
              }

              return NavigationActionPolicy.ALLOW;
            },
            onDownloadStartRequest: (controller, downloadRequest) async {
              final url = downloadRequest.url.toString();
              // Jika user menekan tombol Download QRIS
              if (url.startsWith('blob:') || url.startsWith('data:')) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pengunduhan tidak didukung. Silakan lakukan Screenshot layar ini untuk menyimpan QR Code.'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}