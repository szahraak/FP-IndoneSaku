import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/tiket.dart';
import '../../services/midtrans_service.dart';
import 'rangkuman_pemesanan_screen.dart';

/// Layar WebView untuk menampilkan halaman pembayaran Midtrans Snap.
///
/// Alur:
/// 1. Snap redirectUrl dimuat di WebView.
/// 2. Saat Midtrans selesai, WebView diarahkan ke salah satu callback URL
///    yang berformat: https://fp-indonesaku.web.app/payment/{finish|pending|error}
/// 3. WebView mengintersep URL tersebut, mencegah navigasi nyata, lalu
///    memproses hasil pembayaran.
class MidtransSnapScreen extends StatefulWidget {
  final TiketPesanan pesanan;
  final String redirectUrl;

  const MidtransSnapScreen({
    super.key,
    required this.pesanan,
    required this.redirectUrl,
  });

  @override
  State<MidtransSnapScreen> createState() => _MidtransSnapScreenState();
}

class _MidtransSnapScreenState extends State<MidtransSnapScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isHandled = false; // mencegah double-handle callback

  // Base URL yang dipakai sebagai callback — WebView akan mengintersep path ini.
  static const String _callbackBase = 'https://fp-indonesaku.web.app/payment';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith(_callbackBase)) {
              // Cegah WebView menavigasi ke URL callback (URL tidak nyata).
              _handleCallbackUrl(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // Abaikan error dari URL callback yang dicegah.
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));
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
      // Midtrans mengarahkan ke /finish untuk status: capture, settlement, pending
      if (transactionStatus == 'capture' || transactionStatus == 'settlement') {
        _onBerhasil(paymentType: paymentType, transactionId: transactionId);
      } else if (transactionStatus == 'pending') {
        _onPending(paymentType: paymentType);
      } else {
        // Tidak ada status yang dikenal — anggap sebagai pembayaran berhasil
        // (user sudah menyelesaikan flow di Snap).
        _onBerhasil(paymentType: paymentType, transactionId: transactionId);
      }
    } else if (path.contains('pending')) {
      _onPending(paymentType: paymentType);
    } else if (path.contains('error') || path.contains('cancel')) {
      _onGagal();
    }
  }

  // ── Outcome Handlers ────────────────────────────────────────────────────────

  Future<void> _onBerhasil({
    required String paymentType,
    required String transactionId,
  }) async {
    try {
      await MidtransService.onPembayaranBerhasil(
        pesananId: widget.pesanan.id,
        paymentType: paymentType.isEmpty ? 'unknown' : paymentType,
        transactionId: transactionId.isEmpty ? widget.pesanan.id : transactionId,
      );
    } catch (_) {
      // Update Firestore gagal — tetap lanjut ke rangkuman (webhook akan fix).
    }

    if (!mounted) return;

    widget.pesanan
      ..statusPembayaran = StatusPembayaran.berhasil
      ..statusPesanan = StatusPesanan.dikonfirmasi;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RangkumanPemesananScreen(pesanan: widget.pesanan),
      ),
    );
  }

  Future<void> _onPending({required String paymentType}) async {
    try {
      await MidtransService.onPembayaranPending(
        pesananId: widget.pesanan.id,
        paymentType: paymentType.isEmpty ? 'unknown' : paymentType,
      );
    } catch (_) {}

    if (!mounted) return;
    _showStatusDialog(
      icon: Icons.hourglass_top_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Menunggu Pembayaran',
      message:
          'Pesanan kamu sedang menunggu konfirmasi pembayaran. Selesaikan pembayaran sesuai instruksi yang diterima.',
      isPending: true,
    );
  }

  Future<void> _onGagal() async {
    try {
      await MidtransService.onPembayaranGagal(widget.pesanan.id);
    } catch (_) {}

    if (!mounted) return;
    _showStatusDialog(
      icon: Icons.cancel_outlined,
      iconColor: const Color(0xFFE53935),
      title: 'Pembayaran Gagal',
      message:
          'Pembayaran dibatalkan atau gagal diproses. Silakan lakukan pemesanan ulang.',
      isPending: false,
    );
  }

  // ── Dialog ──────────────────────────────────────────────────────────────────

  void _showStatusDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required bool isPending,
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
                Navigator.pop(ctx);
                // Kembali ke PembayaranScreen (dan biarkan stack atas ber-pop)
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B88A2),
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
                title: const Text('Batalkan Pembayaran?'),
                content: const Text(
                    'Apakah kamu yakin ingin menutup halaman pembayaran?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Tidak'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B88A2),
                    ),
                    child: const Text('Ya, Batalkan',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            if (confirm == true && mounted) {
              if (!_isHandled) {
                _isHandled = true;
                await MidtransService.onPembayaranGagal(widget.pesanan.id)
                    .catchError((_) {});
              }
              if (mounted) Navigator.pop(context);
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
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4B88A2),
              ),
            ),
        ],
      ),
    );
  }
}
