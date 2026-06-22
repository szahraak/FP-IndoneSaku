import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/tiket.dart';
import '../../services/midtrans_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../main_scaffold.dart';
import 'tiketmu_screen.dart';
import 'rangkuman_pemesanan_screen.dart';

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
  bool _isHandled = false;

  static const String _callbackBase = 'https://fp-indonesaku.web.app/payment';

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
      case 'qris':
        return MetodePembayaran.qris;
      case 'cstore':
      case 'akulaku':
      default:
        return MetodePembayaran.online; 
    }
  }

  void _handleCallbackUrl(String url) {
    if (_isHandled) return;
    _isHandled = true;

    final uri = Uri.parse(url);
    final path = uri.path;
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
      _onTertunda();
    } else if (path.contains('error')) {
      _onGagal();
    }
  }

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
            realPaymentType = webhookPaymentType;
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

      // --- LOGIKA NOTIFIKASI SUKSES ---
      await NotificationService.cancelPaymentReminders(widget.pesanan.id);
      await NotificationService.showPaymentSuccessNotification(
         widget.pesanan.id, 
         widget.pesanan.judulPertunjukan
      );
      await NotificationService.schedulePertunjukanReminders(
        pesananId: widget.pesanan.id,
        judul: widget.pesanan.judulPertunjukan,
        tanggalPertunjukan: widget.pesanan.tanggalPertunjukan,
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

      // --- LOGIKA NOTIFIKASI PENDING ---
      await NotificationService.showPendingPaymentNotification(widget.pesanan.judulPertunjukan);
      await NotificationService.schedulePaymentExpiryReminder(
        pesananId: widget.pesanan.id,
        judul: widget.pesanan.judulPertunjukan,
        batasWaktu: widget.pesanan.batasWaktuPembayaran,
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
            MaterialPageRoute(
                builder: (_) => const MainScaffold(initialIndex: 2)),
            (route) => false, 
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
        Navigator.pop(context);
      },
    );
  }

  Future<void> _onTertunda() async {
    // --- LOGIKA NOTIFIKASI PENDING ---
    await NotificationService.showPendingPaymentNotification(widget.pesanan.judulPertunjukan);
    await NotificationService.schedulePaymentExpiryReminder(
      pesananId: widget.pesanan.id,
      judul: widget.pesanan.judulPertunjukan,
      batasWaktu: widget.pesanan.batasWaktuPembayaran,
    );

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
        MaterialPageRoute(
            builder: (_) => const MainScaffold(initialIndex: 2)),
        (route) => false, 
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TiketmuScreen(pesanan: widget.pesanan)),
      );
    }
  }

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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
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
                onOkAction();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Tutup Halaman?'),
                content: const Text('Anda belum menyelesaikan pembayaran. Anda masih dapat melanjutkannya nanti di halaman Tiketmu sebelum waktu habis.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Ya, Tutup', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            
            if (confirm == true && mounted) {
              if (!_isHandled) {
                _isHandled = true;
                
                // --- LOGIKA NOTIFIKASI PENDING SAAT TUTUP SNAP ---
                await NotificationService.showPendingPaymentNotification(widget.pesanan.judulPertunjukan);
                await NotificationService.schedulePaymentExpiryReminder(
                  pesananId: widget.pesanan.id,
                  judul: widget.pesanan.judulPertunjukan,
                  batasWaktu: widget.pesanan.batasWaktuPembayaran,
                );
              }
              if (!context.mounted) return;
              
              if (widget.fromTiketmu) {
                Navigator.pop(context);
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MainScaffold(initialIndex: 2)),
                  (route) => false, 
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TiketmuScreen(pesanan: widget.pesanan)),
                );
              }
            }
          },
        ),
        title: const Text('Pembayaran Midtrans', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.redirectUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
              useOnDownloadStart: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
            ),
            onWebViewCreated: (controller) => webViewController = controller,
            onLoadStart: (controller, url) { if (mounted) setState(() => _isLoading = true); },
            onLoadStop: (controller, url) { if (mounted) setState(() => _isLoading = false); },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url.toString();
              if (url.startsWith(_callbackBase)) {
                _handleCallbackUrl(url);
                return NavigationActionPolicy.CANCEL;
              }
              if (!url.startsWith('http') && !url.startsWith('https')) {
                return NavigationActionPolicy.CANCEL; 
              }
              return NavigationActionPolicy.ALLOW;
            },
            onDownloadStartRequest: (controller, downloadRequest) async {
              final url = downloadRequest.url.toString();
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
          if (_isLoading) const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      ),
    );
  }
}