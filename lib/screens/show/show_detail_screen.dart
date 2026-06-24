import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/pertunjukan.dart';
import '../../services/pertunjukan_service.dart';
import '../../theme/app_colors.dart';
import '../ticketing/pesan_tiket_screen.dart';

class ShowDetailScreen extends StatefulWidget {
  final String showId;
  // Optional: pass the object directly to avoid an extra fetch if we already have it
  final Pertunjukan? show;

  const ShowDetailScreen({super.key, required this.showId, this.show});

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
  Pertunjukan? _show;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.show != null) {
      _show = widget.show;
      _loading = false;
    } else {
      _fetchShow();
    }
  }

  Future<void> _fetchShow() async {
    try {
      final show = await PertunjukanService.getById(widget.showId);
      setState(() {
        _show = show;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_error != null || _show == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Pertunjukan tidak ditemukan')),
      );
    }

    return _ShowDetailBody(show: _show!);
  }
}

class _ShowDetailBody extends StatelessWidget {
  final Pertunjukan show;
  const _ShowDetailBody({required this.show});

  String _formatDate(DateTime d) {
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final date = show.tanggalDateTime;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero poster app bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.secondary,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.white),
                    onPressed: () {
                      // Share functionality
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  show.posterUrl.isNotEmpty
                      ? Image.network(
                          show.posterUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _posterPlaceholder(),
                        )
                      : _posterPlaceholder(),
                  // Gradient bottom
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha((0.6 * 255).round()),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Category & status badges
                  Positioned(
                    top: 100,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _badge(show.kategori, AppColors.primary),
                        const SizedBox(height: 6),
                        if (!show.isUpcoming)
                          _badge('Selesai', Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    show.judul,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info chips row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(Icons.calendar_today_outlined,
                          _formatDate(date), AppColors.secondary),
                      _infoChip(Icons.access_time, _timeStr(date),
                          AppColors.secondary),
                      _infoChip(Icons.location_city_outlined, show.kota,
                          AppColors.secondary),
                      _infoChip(Icons.confirmation_number_outlined,
                          '${show.totalStok} tiket tersisa', Colors.green),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha((0.08 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.primary.withAlpha((0.2 * 255).round())),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_activity,
                            color: AppColors.primary),
                        const SizedBox(width: 10),
                        const Text(
                          'Harga Tiket',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          show.formattedHarga,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Tentang Pertunjukan',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    show.deskripsi,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Location map (Google Static Maps or deep-link button)
                  if (show.lokasi != null) ...[
                    const Text(
                      'Lokasi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _LocationCard(
                      lokasi: show.lokasi!,
                      kota: show.kota,
                      judul: show.judul,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Video teaser
                  if (show.videoTeaserUrl != null &&
                      show.videoTeaserUrl!.isNotEmpty) ...[
                    const Text(
                      'Video Teaser',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _VideoTeaserCard(url: show.videoTeaserUrl!),
                    const SizedBox(height: 24),
                  ],

                  // Rating (if available)
                  if (show.rating != null) ...[
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.accent, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          show.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '/ 5.0',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Buy ticket / book button ─────────────────────────────────────────
      bottomNavigationBar: show.isUpcoming && show.totalStok > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PesanTiketScreen(pertunjukan: show),
                      ),
                    );
                  },
                  child: Text(
                    show.hargaTermurah == 0
                        ? 'Daftar Sekarang (Gratis)'
                        : 'Pesan Tiket — ${show.formattedHarga}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  String _timeStr(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m WIB';
  }

  Widget _posterPlaceholder() {
    return Container(
      color: AppColors.secondary,
      child: const Center(
        child: Icon(Icons.theater_comedy, color: AppColors.primary, size: 64),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: color.withAlpha((0.15 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Location card with Google Static Maps ──────────────────────────────────────
class _LocationCard extends StatelessWidget {
  final GeoPoint lokasi;
  final String kota;
  final String judul;

  const _LocationCard({
    required this.lokasi,
    required this.kota,
    required this.judul,
  });

  @override
  Widget build(BuildContext context) {
    // Google Static Maps API — replace YOUR_GOOGLE_MAPS_API_KEY with real key
    // For a free fallback, we show a tappable card that opens Google Maps
    final lat = lokasi.latitude;
    final lng = lokasi.longitude;
    const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final staticMapUrl =
        'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=15'
        '&size=600x200'
        '&maptype=roadmap'
        '&markers=color:red%7C$lat,$lng'
        '&key=$apiKey';

    return GestureDetector(
      onTap: () async {
        final url =
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Static map image
            Image.network(
              staticMapUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 160,
                color: AppColors.secondary.withAlpha((0.1 * 255).round()),
                child: const Center(
                  child: Icon(Icons.map_outlined,
                      color: AppColors.textSecondary, size: 40),
                ),
              ),
            ),
            // Overlay with location info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: Colors.black.withAlpha((0.6 * 255).round()),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        kota,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.open_in_new,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      'Buka Maps',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Video teaser card ──────────────────────────────────────────────────────────
class _VideoTeaserCard extends StatelessWidget {
  final String url;
  const _VideoTeaserCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [AppColors.secondary, Color(0xFF2D2D4E)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative dots
            Positioned(
              right: 20,
              top: 10,
              child: Icon(Icons.movie_creation_outlined,
                  color: Colors.white.withAlpha((0.1 * 255).round()), size: 80),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tonton Video Teaser',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ketuk untuk membuka',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.6 * 255).round()),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
