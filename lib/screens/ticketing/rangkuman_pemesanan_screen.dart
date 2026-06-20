import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/tiket.dart';
import '../main_scaffold.dart';

class RangkumanPemesananScreen extends StatelessWidget {
  final TiketPesanan pesanan;

  const RangkumanPemesananScreen({super.key, required this.pesanan});

  static const Color _primaryColor = Color(0xFF4B88A2);

  @override
  Widget build(BuildContext context) {
    final currencyFmt =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pesanan')
            .doc(pesanan.id)
            .snapshots(),
        builder: (context, snapshot) {
          // Jadikan data lokal sebagai fallback jika Firestore belum merespons
          TiketPesanan displayPesanan = pesanan;

          if (snapshot.hasData && snapshot.data!.exists) {
            try {
              displayPesanan = TiketPesanan.fromFirestore(snapshot.data!);
            } catch (_) {}
          }

          final nomorPembayaran = displayPesanan.nomorPembayaran ??
              'ORD-${displayPesanan.id.toUpperCase()}';

          return Column(
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
                                  displayPesanan.posterUrl,
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
                                      '${displayPesanan.judulPertunjukan}\n${displayPesanan.lokasi}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      dateFmt.format(displayPesanan.tanggalPertunjukan),
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
                              value: displayPesanan.namaPemesan,
                              valueBold: true,
                            ),
                            _DetailRow(
                              label: 'Metode Pembayaran',
                              value: displayPesanan.labelPembayaranSpesifik,
                              valueBold: true,
                            ),
                            const Divider(
                                height: 24, thickness: 1, color: Color(0xFFEEEEEE)),

                            // Per-item breakdown
                            ...displayPesanan.items.map((item) => _DetailRow(
                                  label: '${item.namaJenisTiket}',
                                  value:
                                      '${currencyFmt.format(item.hargaSatuan)} x ${item.jumlah}',
                                  valueBold: true, 
                                )),

                            const Divider(
                                height: 24, thickness: 1, color: Color(0xFFEEEEEE)),
                            _DetailRow(
                              label: 'Total Pembayaran',
                              value: currencyFmt.format(displayPesanan.totalHarga),
                              valueBold: true,
                            ),
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
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MainScaffold(initialIndex: 2)),
                        (route) => false, 
                      );
                    },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Lihat Tiket Saya',
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
          );
        },
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
                fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}