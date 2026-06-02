import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pertunjukan_model.dart';
import '../../models/tiket_pesanan_model.dart';
import '../../services/mock_ticketing_service.dart';
import 'pembayaran_screen.dart';

class PesanTiketScreen extends StatefulWidget {
  final PertunjukanModel pertunjukan;

  const PesanTiketScreen({super.key, required this.pertunjukan});

  @override
  State<PesanTiketScreen> createState() => _PesanTiketScreenState();
}

class _PesanTiketScreenState extends State<PesanTiketScreen> {
  // Map jenisTiketId -> jumlah yang dipilih
  final Map<String, int> _selectedQty = {};

  static const Color _primaryColor = Color(0xFF4B88A2);

  final _currencyFmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  double get _totalHarga {
    double total = 0;
    for (final tiket in widget.pertunjukan.jenisTiket) {
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

  void _onTambahkan() {
    if (_totalItems == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 tiket terlebih dahulu.'),
        ),
      );
      return;
    }

    final items = <ItemPesanan>[];
    for (final tiket in widget.pertunjukan.jenisTiket) {
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

    final pesanan = MockTicketingService.buatPesanan(
      pertunjukanId: widget.pertunjukan.id,
      judulPertunjukan: widget.pertunjukan.judul,
      posterUrl: widget.pertunjukan.posterUrl,
      tanggalPertunjukan: widget.pertunjukan.tanggal,
      lokasi: widget.pertunjukan.lokasi,
      namaPemesan: MockUser.nama,
      emailPemesan: MockUser.email,
      items: items,
      totalHarga: _totalHarga,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PembayaranScreen(pesanan: pesanan),
      ),
    );
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
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateFmt.format(show.tanggal),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                'Pukul ${timeFmt.format(show.tanggal)} WIB',
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
                                    show.lokasi,
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
                  ...show.jenisTiket.map((tiket) {
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
                                        ? const Color(0xFFE53E3E)
                                        : const Color(0xFF38A169),
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
                  onPressed: _totalItems > 0 ? _onTambahkan : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Row(
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
