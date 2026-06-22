import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pertunjukan.dart';
import '../../models/tiket.dart';
import '../../services/ticketing_service.dart';
import '../../services/midtrans_service.dart';
import 'midtrans_snap_screen.dart';
import 'tiketmu_screen.dart';
import '../../theme/app_colors.dart';

class PesanTiketScreen extends StatefulWidget {
  final Pertunjukan pertunjukan;

  const PesanTiketScreen({super.key, required this.pertunjukan});

  @override
  State<PesanTiketScreen> createState() => _PesanTiketScreenState();
}

class _PesanTiketScreenState extends State<PesanTiketScreen> {
  // Map jenisTiketId -> jumlah yang dipilih
  final Map<String, int> _selectedQty = {};
  List<JenisTiket> _jenisTiket = [];
  String _namaPemesan = 'Pengguna';
  String _emailPemesan = '';
  bool _loadingJenisTiket = true;
  bool _submitting = false;

  static const Color _primaryColor = AppColors.primary;

  final _currencyFmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();

    _jenisTiket = widget.pertunjukan.daftarTiket;
    _loadingJenisTiket = false;

    TicketingService.getCurrentUserInfo().then((info) {
      if (mounted) {
        setState(() {
          _namaPemesan = info['nama'] ?? 'Pengguna';
          _emailPemesan = info['email'] ?? '';
        });
      }
    });
  }

  double get _totalHarga {
    double total = 0;
    for (final tiket in _jenisTiket) {
      total += tiket.harga * (_selectedQty[tiket.id] ?? 0);
    }
    return total;
  }

  int get _totalItems {
    return _selectedQty.values.fold(0, (a, b) => a + b);
  }

  void _increment(JenisTiket tiket) {
    if (tiket.stok == 0) return;
    setState(() {
      final current = _selectedQty[tiket.id] ?? 0;
      if (current < tiket.stok) {
        _selectedQty[tiket.id] = current + 1;
      }
    });
  }

  void _decrement(JenisTiket tiket) {
    setState(() {
      final current = _selectedQty[tiket.id] ?? 0;
      if (current > 0) {
        _selectedQty[tiket.id] = current - 1;
      }
    });
  }

  Future<bool> _showSandboxWarning() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Mode Sandbox', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              const Text('Anda sedang berada di lingkungan pengujian (Sandbox).'),
              const SizedBox(height: 12),
              const Text(
                '⚠️ JANGAN gunakan uang atau rekening asli Anda untuk melakukan pembayaran pada halaman selanjutnya.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text('Gunakan simulator resmi Midtrans untuk menyimulasikan pembayaran:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              SelectableText(
                'https://simulator.sandbox.midtrans.com/',
                style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 12),
              const Text('Dokumentasi testing:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              SelectableText(
                'https://docs.midtrans.com/docs/testing-payment-on-sandbox',
                style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('Mengerti', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _onTambahkan() async {
    if (_totalItems == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 tiket terlebih dahulu.')),
      );
      return;
    }

    final bool confirm = await _showSandboxWarning();
    if (!confirm) return;

    setState(() => _submitting = true);
    TiketPesanan? pesanan; // Deklarasi di luar try untuk handle error fallback

    try {
      final items = <ItemPesanan>[];
      for (final tiket in _jenisTiket) {
        final qty = _selectedQty[tiket.id] ?? 0;
        if (qty > 0) {
          items.add(ItemPesanan(
            jenisTiketId: tiket.id,
            namaJenisTiket: tiket.nama,
            hargaSatuan: tiket.harga,
            jumlah: qty,
          ));
        }
      }

      // 1. Buat pesanan di Firestore
      pesanan = await TicketingService.buatPesanan(
        pertunjukanId: widget.pertunjukan.id,
        judulPertunjukan: widget.pertunjukan.judul,
        posterUrl: widget.pertunjukan.posterUrl,
        tanggalPertunjukan: widget.pertunjukan.tanggalDateTime,
        lokasi: widget.pertunjukan.kota,
        namaPemesan: _namaPemesan,
        emailPemesan: _emailPemesan,
        items: items,
        totalHarga: _totalHarga,
      );

      // 2. Langsung dapatkan Snap Token dari Midtrans
      final snapResult = await MidtransService.getSnapToken(pesanan);

      await FirebaseFirestore.instance.collection('pesanan').doc(pesanan.id).update({
        'snapToken': snapResult.snapToken,
      });
      pesanan.snapToken = snapResult.snapToken;

      if (!mounted) return;
      
      // 3. Arahkan ke Midtrans Snap Screen (Gunakan pushReplacement agar tidak bisa di-back)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MidtransSnapScreen(
            pesanan: pesanan!,
            redirectUrl: snapResult.redirectUrl,
            fromTiketmu: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
      // Jika pesanan terlanjur terbuat tapi Snap gagal dimuat (misal koneksi putus),
      // lemparkan ke TiketmuScreen agar bisa dilanjutkan nanti.
      if (pesanan != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TiketmuScreen(pesanan: pesanan!)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.pertunjukan;
    final dateFmt = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pesan Tiket',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Show card ──────────────────────────────────────
                  Container(
                    alignment: Alignment.topLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            show.posterUrl,
                            width: 96,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 96,
                              height: 120,
                              color: _primaryColor.withValues(alpha: 0.15),
                              child: const Icon(Icons.image,
                                  color: _primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                show.judul,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateFmt.format(show.tanggalDateTime),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                'Pukul ${timeFmt.format(show.tanggalDateTime)} WIB',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 13,
                                      color: Colors.grey[600]),
                                  const SizedBox(width: 2),
                                  Text(
                                    show.kota,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Ticket type list ───────────────────────────────
                  if (_loadingJenisTiket)
                    const Center(child: CircularProgressIndicator())
                  else
                  ..._jenisTiket.map((tiket) {
                    final isHabis = tiket.stok == 0;
                    final qty = _selectedQty[tiket.id] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badge HABIS / TERSEDIA
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isHabis
                                        ? AppColors.error
                                        : AppColors.success,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isHabis ? 'HABIS' : 'TERSEDIA',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tiket.nama,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _currencyFmt.format(tiket.harga),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Qty controls
                          Row(
                            children: [
                              _QtyButton(
                                icon: Icons.remove,
                                onTap: isHabis
                                    ? null
                                    : () => _decrement(tiket),
                              ),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '$qty',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _QtyButton(
                                icon: Icons.add,
                                onTap: isHabis
                                    ? null
                                    : () => _increment(tiket),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── Bottom bar ────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_totalItems > 0 && !_submitting) ? _onTambahkan : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_totalItems Item(s)',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _currencyFmt.format(_totalHarga),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(
              color: onTap == null ? Colors.grey[300]! : Colors.grey[400]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
    );
  }
}
