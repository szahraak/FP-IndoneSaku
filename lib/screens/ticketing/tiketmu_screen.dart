import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/tiket.dart';
import '../../services/ticketing_service.dart';

class TiketmuScreen extends StatefulWidget {
  final TiketPesanan pesanan;

  const TiketmuScreen({super.key, required this.pesanan});

  @override
  State<TiketmuScreen> createState() => _TiketmuScreenState();
}

class _TiketmuScreenState extends State<TiketmuScreen> {
  static const Color _primaryColor = Color(0xFF4B88A2);

  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.pesanan.statusPembayaran == StatusPembayaran.menunggu) {
      _updateRemaining();
      _timer = Timer.periodic(
          const Duration(seconds: 1), (_) => _updateRemaining());
    }
  }

  void _updateRemaining() {
    final deadline =
        widget.pesanan.dibuatPada.add(const Duration(hours: 24));
    final diff = deadline.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    if (diff.isNegative) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pesanan = widget.pesanan;
    final dateFmt = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
    final timeFmt = DateFormat('HH:mm', 'id_ID');
    final currencyFmt =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final qrData =
        'INDONESAKU-${pesanan.id}-${pesanan.penggunaUid}';

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tiketmu',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Poster ───────────────────────────────────────
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    pesanan.posterUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: double.infinity,
                      height: 200,
                      color: _primaryColor.withValues(alpha: 0.15),
                      child: const Icon(Icons.image,
                          color: _primaryColor, size: 60),
                    ),
                  ),
                ),

                // ── Title & venue ─────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pesanan.judulPertunjukan,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pesanan.lokasi,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Date / Time row ───────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        // Tanggal
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateFmt.format(
                                    pesanan.tanggalPertunjukan),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Divider
                        Container(
                          width: 1,
                          color: Colors.grey[300],
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16),
                        ),
                        // Jam
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jam',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeFmt.format(
                                      pesanan.tanggalPertunjukan),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Tear-line ─────────────────────────────────────
                _TearLine(),

                // ── Nomor Pembayaran & Nama ───────────────────────
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nomor Pembayaran',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pesanan.nomorPembayaran ?? '-',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Nama',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pesanan.namaPemesan,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildPaymentBody(context, pesanan, qrData, currencyFmt),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Conditional payment body ──────────────────────────────────────────────

  Widget _buildPaymentBody(
    BuildContext context,
    TiketPesanan pesanan,
    String qrData,
    NumberFormat currencyFmt,
  ) {
    final isPending =
        pesanan.statusPembayaran == StatusPembayaran.menunggu;
    final isPaid =
        pesanan.statusPembayaran == StatusPembayaran.berhasil;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (pesanan.statusPembayaran) {
      case StatusPembayaran.berhasil:
        statusColor = const Color(0xFF38A169);
        statusLabel = 'Pembayaran Berhasil';
        statusIcon = Icons.check_circle_outline;
      case StatusPembayaran.menunggu:
        statusColor = const Color(0xFFD69E2E);
        statusLabel = 'Menunggu Pembayaran';
        statusIcon = Icons.access_time_outlined;
      case StatusPembayaran.gagal:
        statusColor = const Color(0xFFE53E3E);
        statusLabel = 'Pembayaran Gagal';
        statusIcon = Icons.cancel_outlined;
      case StatusPembayaran.kedaluwarsa:
        statusColor = Colors.grey;
        statusLabel = 'Kedaluwarsa';
        statusIcon = Icons.timer_off_outlined;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Status badge ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (isPending) ...[
          // ── Countdown timer ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              children: [
                Text(
                  'Selesaikan pembayaran dalam',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD69E2E),
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pesanan dibatalkan otomatis jika melewati batas waktu',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // ── Cancel button ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: OutlinedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Batalkan Pesanan?'),
                    content: const Text(
                        'Pesanan akan dibatalkan dan tidak dapat dikembalikan.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Tidak'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600]),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Ya, Batalkan',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await TicketingService.batalkanPesanan(pesanan.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[600],
                side: BorderSide(color: Colors.red[300]!),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Batalkan Pesanan'),
            ),
          ),
        ] else if (isPaid) ...[
          // ── QR Code ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  pesanan.nomorPembayaran ??
                      'INDONESAKU-${pesanan.id.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tunjukkan QR ini kepada petugas',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // ── Ticket items ──────────────────────────────────────
          const Divider(color: Color(0xFFEEEEEE), height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              children: [
                ...pesanan.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.namaJenisTiket} x${item.jumlah}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            currencyFmt.format(item.subtotal),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
                if (pesanan.metodePembayaran != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        pesanan.metodePembayaran!.label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
                const Divider(color: Color(0xFFEEEEEE)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currencyFmt.format(pesanan.totalHarga),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          // ── Gagal / Kedaluwarsa ───────────────────────────────
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(statusIcon, size: 56, color: statusColor),
                const SizedBox(height: 12),
                Text(
                  statusLabel,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pesanan ini sudah tidak dapat diproses.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── Tear-line widget ──────────────────────────────────────────────────────────

class _TearLine extends StatelessWidget {
  const _TearLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left notch (cuts into the card from left edge)
        Container(
          width: 18,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
        ),
        // Dashed line
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dashWidth = 6.0;
              final dashSpace = 4.0;
              final count =
                  (constraints.maxWidth / (dashWidth + dashSpace))
                      .floor();
              return Row(
                children: List.generate(
                  count,
                  (i) => Container(
                    width: dashWidth,
                    height: 1.5,
                    margin:
                        EdgeInsets.only(right: i < count - 1 ? dashSpace : 0),
                    color: Colors.grey[300],
                  ),
                ),
              );
            },
          ),
        ),
        // Right notch
        Container(
          width: 18,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
          ),
        ),
      ],
    );
  }
}