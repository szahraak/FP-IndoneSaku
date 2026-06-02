import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tiket_pesanan_model.dart';
import '../../services/mock_ticketing_service.dart';
import '../ticketing/tiketmu_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _primaryColor = Color(0xFF4B88A2);
  String _selectedFilter = 'aktif';

  static const _filters = [
    ('aktif', 'Aktif'),
    ('menunggu', 'Menunggu'),
    ('selesai', 'Selesai'),
    ('dibatalkan', 'Dibatalkan'),
  ];

  List<TiketPesanan> _getFiltered(String filter) {
    final all = MockTicketingService.getTiketSaya();
    final now = DateTime.now();
    switch (filter) {
      case 'aktif':
        return all
            .where((p) =>
                p.statusPesanan == StatusPesanan.dikonfirmasi &&
                p.statusPembayaran == StatusPembayaran.berhasil &&
                p.tanggalPertunjukan.isAfter(now))
            .toList();
      case 'menunggu':
        return all
            .where((p) => p.statusPesanan == StatusPesanan.menunggu)
            .toList();
      case 'selesai':
        return all
            .where((p) =>
                p.statusPesanan == StatusPesanan.dikonfirmasi &&
                p.statusPembayaran == StatusPembayaran.berhasil &&
                p.tanggalPertunjukan.isBefore(now))
            .toList();
      case 'dibatalkan':
        return all
            .where((p) => p.statusPesanan == StatusPesanan.dibatalkan)
            .toList();
      default:
        return all;
    }
  }

  void _batalkan(TiketPesanan pesanan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: const Text(
            'Apakah kamu yakin ingin membatalkan pesanan ini? Tindakan ini tidak dapat dibatalkan.'),
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
    if (confirm == true) {
      MockTicketingService.batalkanPesanan(pesanan.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter chips ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _selectedFilter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.$2),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedFilter = f.$1),
                    selectedColor:
                        _primaryColor.withValues(alpha: 0.12),
                    checkmarkColor: _primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? _primaryColor : Colors.grey[700],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? _primaryColor
                          : Colors.grey[300]!,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 0),
                  ),
                );
              }).toList(),
            ),
          ),
          // ── Ticket list ──────────────────────────────────────────
          Expanded(
            child: _TicketList(
              pesananList: _getFiltered(_selectedFilter),
              onRefresh: () => setState(() {}),
              onBatalkan: _selectedFilter == 'menunggu' ? _batalkan : null,
              showBatalkan: _selectedFilter == 'menunggu',
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  final List<TiketPesanan> pesananList;
  final VoidCallback onRefresh;
  final void Function(TiketPesanan)? onBatalkan;
  final bool showBatalkan;

  const _TicketList({
    required this.pesananList,
    required this.onRefresh,
    required this.onBatalkan,
    required this.showBatalkan,
  });

  @override
  Widget build(BuildContext context) {
    if (pesananList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Belum ada tiket di sini',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pesananList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pesanan = pesananList[index];
        return _TicketCard(
          pesanan: pesanan,
          onBatalkan:
              showBatalkan && onBatalkan != null ? onBatalkan : null,
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TiketPesanan pesanan;
  final void Function(TiketPesanan)? onBatalkan;

  static const Color _primaryColor = Color(0xFF1A1A6E);

  const _TicketCard({required this.pesanan, this.onBatalkan});

  Color get _statusColor {
    switch (pesanan.statusPesanan) {
      case StatusPesanan.dikonfirmasi:
        return const Color(0xFF38A169);
      case StatusPesanan.menunggu:
        return const Color(0xFFD69E2E);
      case StatusPesanan.dibatalkan:
        return const Color(0xFFE53E3E);
    }
  }

  String get _statusLabel {
    switch (pesanan.statusPesanan) {
      case StatusPesanan.dikonfirmasi:
        return 'Dikonfirmasi';
      case StatusPesanan.menunggu:
        return 'Menunggu Pembayaran';
      case StatusPesanan.dibatalkan:
        return 'Dibatalkan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
    final currencyFmt =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TiketmuScreen(pesanan: pesanan),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top section ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      pesanan.posterUrl,
                      width: 60,
                      height: 75,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 60,
                        height: 75,
                        color: _primaryColor.withValues(alpha: 0.15),
                        child: const Icon(Icons.image, color: _primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pesanan.judulPertunjukan,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFmt.format(pesanan.tanggalPertunjukan),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 13, color: Colors.grey[600]),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                pesanan.lokasi,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Dashed divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: List.generate(
                  40,
                  (i) => Expanded(
                    child: Container(
                      height: 1,
                      color: i.isEven ? Colors.grey[300] : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom section ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pesanan.totalJumlah} tiket',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        currencyFmt.format(pesanan.totalHarga),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (onBatalkan != null)
                        TextButton(
                          onPressed: () => onBatalkan!(pesanan),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red[600],
                          ),
                          child: const Text('Batalkan'),
                        ),
                      if (pesanan.statusPesanan ==
                          StatusPesanan.dikonfirmasi)
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TiketmuScreen(pesanan: pesanan),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.qr_code,
                              color: Colors.white, size: 16),
                          label: const Text(
                            'E-Ticket',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
