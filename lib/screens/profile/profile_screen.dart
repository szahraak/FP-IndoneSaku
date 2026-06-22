import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../models/tiket.dart';
import '../../services/ticketing_service.dart';
import '../ticketing/tiketmu_screen.dart';
import '../my_shows_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedFilter = 'aktif';
  String _tipeAkun = 'penonton';
  String _userName = '';
  String _userEmail = '';
  String _fotoUrl = '';

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  static const _filters = [
    ('aktif', 'Aktif'),
    ('menunggu', 'Menunggu'),
    ('selesai', 'Selesai'),
    ('dibatalkan', 'Dibatalkan'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _tipeAkun = doc.data()?['tipeAkun'] ?? 'penonton';
          _userName = doc.data()?['nama'] ?? '';
          _userEmail = doc.data()?['email'] ?? user.email ?? '';
          _fotoUrl = doc.data()?['fotoUrl'] ?? ''; // Ambil fotoUrl
        });
      } else if (mounted) {
        setState(() {
          _userEmail = user.email ?? '';
        });
      }

      // Pasang Listener Real-time
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _userName = snapshot.data()?['nama'] ?? '';
            _fotoUrl = snapshot.data()?['fotoUrl'] ?? '';
          });
        }
      });
    } catch (_) {}
  }

  List<TiketPesanan> _getFiltered(List<TiketPesanan> all, String filter) {
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
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await TicketingService.batalkanPesanan(pesanan.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profil',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PengaturanScreen()),
            ).then((_) => _loadUserProfile()), // Refresh data profil setelah kembali dari pengaturan
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Pengaturan',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── User info header ─────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: _fotoUrl.isNotEmpty 
                      ? NetworkImage(_fotoUrl) 
                      : null,
                  child: _fotoUrl.isEmpty
                      ? Text(
                          _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  _userName.isNotEmpty ? _userName : 'Pengguna',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (_userEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _userEmail,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Seniman: Pertunjukan Saya button ────────────────────
          if (_tipeAkun == 'seniman')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyShowsScreen()),
                  ),
                  icon: const Icon(Icons.theater_comedy),
                  label: const Text('Pertunjukan Saya'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

          // ── Section title ───────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Tiket Saya',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),

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
                        AppColors.primary.withValues(alpha: 0.12),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.grey[700],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
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
            child: StreamBuilder<List<TiketPesanan>>(
              stream: TicketingService.getTiketSayaStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Gagal memuat tiket: ${snapshot.error}'),
                  );
                }
                final filtered = _getFiltered(
                    snapshot.data ?? [], _selectedFilter);
                return _TicketList(
                  pesananList: filtered,
                  onRefresh: () => setState(() {}),
                  onBatalkan:
                      _selectedFilter == 'menunggu' ? _batalkan : null,
                  showBatalkan: _selectedFilter == 'menunggu',
                );
              },
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: pesananList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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

  const _TicketCard({required this.pesanan, this.onBatalkan});

  Color get _statusColor {
    switch (pesanan.statusPesanan) {
      case StatusPesanan.dikonfirmasi:
        return AppColors.success;
      case StatusPesanan.menunggu:
        return AppColors.warning;
      case StatusPesanan.dibatalkan:
        return AppColors.error;
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
          color: AppColors.cardBackground,
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
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 75,
                        color: AppColors.primary.withValues(alpha: 0.15),
                        child: const Icon(Icons.image,
                            color: AppColors.primary),
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
                            color: AppColors.textPrimary,
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
                          color: AppColors.primary,
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
                            foregroundColor: AppColors.error,
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
                            backgroundColor: AppColors.primary,
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
