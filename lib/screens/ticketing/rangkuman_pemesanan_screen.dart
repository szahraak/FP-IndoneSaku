import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tiket_pesanan_model.dart';
import '../profile/profile_screen.dart';

class RangkumanPemesananScreen extends StatelessWidget {
  final TiketPesanan pesanan;

  const RangkumanPemesananScreen({super.key, required this.pesanan});

  static const Color _primaryColor = Color(0xFF4B88A2);

  @override
  Widget build(BuildContext context) {
    final currencyFmt =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

    // Generate a fake payment number if not set
    final nomorPembayaran =
        pesanan.nomorPembayaran ?? '11988047940016${pesanan.id.hashCode.abs() % 10000}';

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
          'Rangkuman Pemesanan',
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
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ── Show card ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              pesanan.posterUrl,
                              width: 72,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 72,
                                height: 90,
                                color: _primaryColor.withValues(alpha: 0.15),
                                child: const Icon(Icons.image,
                                    color: _primaryColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pesanan.judulPertunjukan}\n${pesanan.lokasi}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  dateFmt.format(pesanan.tanggalPertunjukan),
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, thickness: 1),

                    // ── Detail rows ───────────────────────────────
                    _DetailSection(
                      children: [
                        _DetailRow(
                          label: 'Nomor Pembayaran',
                          value: nomorPembayaran,
                          valueBold: true,
                        ),
                        _DetailRow(
                          label: 'Nama',
                          value: pesanan.namaPemesan,
                          valueBold: true,
                        ),
                        _DetailRow(
                          label: 'Metode Pembayaran',
                          value: pesanan.namaAkunPembayaran ??
                              (pesanan.metodePembayaran?.label ?? '-'),
                          valueBold: true,
                        ),
                        // Per-item breakdown
                        ...pesanan.items.map((item) => _DetailRow(
                              label: 'Kuantitas',
                              value:
                                  '${currencyFmt.format(item.hargaSatuan)} x ${item.jumlah}',
                              valueBold: true,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom button ────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to ProfileScreen, clearing back stack to it
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()),
                      (route) => route.isFirst,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Konfirmasi Pembayaran',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
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

class _DetailSection extends StatelessWidget {
  final List<Widget> children;
  const _DetailSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool valueBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    valueBold ? FontWeight.bold : FontWeight.normal,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
