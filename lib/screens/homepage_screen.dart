import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pertunjukan.dart';
import '../models/seniman.dart';
import 'show_detail_screen.dart';
import 'browse_shows_screen.dart';
import 'my_shows_screen.dart';

// ─── App Colors ───────────────────────────────────────────────────────────────
class AppColors {
  static const Color primary = Color(0xFFB5451B);       // deep batik terracotta
  static const Color primaryLight = Color(0xFFE8603A);
  static const Color secondary = Color(0xFF1A1A2E);     // deep navy
  static const Color accent = Color(0xFFF5C842);        // gold accent
  static const Color background = Color(0xFFF7F3EE);    // warm cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B7B);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8E0D8);
}

// ─── Homepage Screen ──────────────────────────────────────────────────────────
class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Pertunjukan> _upcomingShows = [];
  List<Pertunjukan> _recommendedShows = [];
  List<Pertunjukan> _trendingShows = [];
  List<Seniman> _recommendedArtists = [];

  bool _isLoading = true;
  String _userName = '';
  List<String> _userPreferensi = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUserData(),
      _loadUpcomingShows(),
      _loadTrendingShows(),
      _loadRecommendedArtists(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _userName = data['nama'] ?? '';
        _userPreferensi = List<String>.from(data['preferensiSeni'] ?? []);
      }
      await _loadRecommendedShows();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadUpcomingShows() async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('pertunjukan')
          .where('status', isEqualTo: 'aktif')
          .where('tanggal', isGreaterThan: now)
          .orderBy('tanggal')
          .limit(10)
          .get();

      _upcomingShows =
          snapshot.docs.map((doc) => Pertunjukan.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error loading upcoming shows: $e');
    }
  }

  Future<void> _loadRecommendedShows() async {
    try {
      final now = Timestamp.now();
      Query query = _firestore
          .collection('pertunjukan')
          .where('status', isEqualTo: 'aktif')
          .where('tanggal', isGreaterThan: now);

      // Filter by user preferences if available
      if (_userPreferensi.isNotEmpty) {
        query = query.where('kategori', whereIn: _userPreferensi.take(10).toList());
      }

      final snapshot = await query.limit(8).get();
      _recommendedShows =
          snapshot.docs.map((doc) => Pertunjukan.fromFirestore(doc)).toList();

      // Fallback: if no preference-based results, show recent shows
      if (_recommendedShows.isEmpty) {
        final fallback = await _firestore
            .collection('pertunjukan')
            .where('status', isEqualTo: 'aktif')
            .where('tanggal', isGreaterThan: now)
            .limit(8)
            .get();
        _recommendedShows =
            fallback.docs.map((doc) => Pertunjukan.fromFirestore(doc)).toList();
      }
    } catch (e) {
      debugPrint('Error loading recommended shows: $e');
    }
  }

  Future<void> _loadTrendingShows() async {
    try {
      final snapshot = await _firestore
          .collection('pertunjukan')
          .where('status', isEqualTo: 'aktif')
          .orderBy('jumlahDipesan', descending: true)
          .limit(8)
          .get();

      _trendingShows =
          snapshot.docs.map((doc) => Pertunjukan.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error loading trending shows: $e');
    }
  }

  Future<void> _loadRecommendedArtists() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('tipeAkun', isEqualTo: 'seniman')
          .orderBy('jumlahPertunjukan', descending: true)
          .limit(10)
          .get();

      _recommendedArtists =
          snapshot.docs.map((doc) => Seniman.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error loading recommended artists: $e');
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isLoading = true);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const _LoadingShimmer()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(),
                        _buildCategoryChips(),
                        const SizedBox(height: 8),
                        _buildUpcomingSection(),
                        _buildRecommendedSection(),
                        _buildTrendingSection(),
                        _buildArtistSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    final user = _auth.currentUser;

    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: false,
      snap: true,
      backgroundColor: AppColors.secondary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.secondary, Color(0xFF2D2D4E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Logo & greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.theater_comedy,
                                  color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'IndoneSaku',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userName.isNotEmpty
                              ? 'Halo, $_userName! 👋'
                              : 'Temukan pertunjukan seni terbaik',
                          style: const TextStyle(
                            color: Color(0xFFB0B0C8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification & profile
                  IconButton(
                    onPressed: () {
                      // Navigate to notifications
                    },
                    icon: Stack(
                      children: [
                        const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 26),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      // Navigate to profile
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Search Bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BrowseShowsScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.06 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Cari pertunjukan, seniman...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Filter',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Category Chips ────────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    final categories = [
      ('🎭', 'Semua'),
      ('🥁', 'Gamelan'),
      ('💃', 'Tari'),
      ('🎪', 'Wayang'),
      ('🎵', 'Musik'),
      ('🎨', 'Ludruk'),
      ('🎬', 'Ketoprak'),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isFirst = index == 0;
          return GestureDetector(
            onTap: () {
                final cat = categories[index].$2;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BrowseShowsScreen(
                      initialCategory: cat == 'Semua' ? null : cat,
                    ),
                  ),
                );
              },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isFirst ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isFirst ? AppColors.primary : AppColors.divider,
                ),
                boxShadow: isFirst
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withAlpha((0.3 * 255).round()),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(categories[index].$1, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    categories[index].$2,
                    style: TextStyle(
                      color: isFirst
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Section Header Helper ─────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, String subtitle,
      {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'Lihat Semua →',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Section 1: Upcoming Shows (large horizontal card) ───────────────────
  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Pertunjukan Mendatang',
          'Jangan sampai ketinggalan!',
          onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseShowsScreen())),
            ? _buildEmptyState('Belum ada pertunjukan mendatang')
            : SizedBox(
                height: 220,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.88),
                  itemCount: _upcomingShows.length,
                  itemBuilder: (context, index) {
                    return _UpcomingShowCard(
                        show: _upcomingShows[index]);
                  },
                ),
              ),
      ],
    );
  }

  // ─── Section 2: Recommended Shows ─────────────────────────────────────────
  Widget _buildRecommendedSection() {
    final title = _userPreferensi.isNotEmpty
        ? 'Sesuai Seleramu'
        : 'Rekomendasi Untukmu';
    final subtitle = _userPreferensi.isNotEmpty
        ? 'Berdasarkan preferensi seni kamu'
        : 'Pertunjukan yang mungkin kamu suka';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title,
          subtitle,
          onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseShowsScreen())),
        ),
        _recommendedShows.isEmpty
            ? _buildEmptyState('Belum ada rekomendasi')
            : SizedBox(
                height: 200,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommendedShows.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _ShowCard(show: _recommendedShows[index]);
                  },
                ),
              ),
      ],
    );
  }

  // ─── Section 3: Trending / Most Booked ────────────────────────────────────
  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          '🔥 Lagi Trending',
          'Paling banyak dipesan minggu ini',
          onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseShowsScreen())),
        ),
        _trendingShows.isEmpty
            ? _buildEmptyState('Belum ada data trending')
            : SizedBox(
                height: 200,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _trendingShows.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _TrendingShowCard(
                      show: _trendingShows[index],
                      rank: index + 1,
                    );
                  },
                ),
              ),
      ],
    );
  }

  // ─── Section 4: Recommended Artists ───────────────────────────────────────
  Widget _buildArtistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Seniman Pilihan',
          'Temukan seniman berbakat Indonesia',
          onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseShowsScreen())),
        ),
        _recommendedArtists.isEmpty
            ? _buildEmptyState('Belum ada data seniman')
            : SizedBox(
                height: 130,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommendedArtists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    return _ArtistCard(artist: _recommendedArtists[index]);
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: Text(message,
            style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

// ─── Upcoming Show Card (Large Banner) ────────────────────────────────────────
class _UpcomingShowCard extends StatelessWidget {
  final Pertunjukan show;
  const _UpcomingShowCard({required this.show});

  @override
  Widget build(BuildContext context) {
    final date = show.tanggalDateTime;
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShowDetailScreen(showId: show.id, show: show),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.15 * 255).round()),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              show.posterUrl.isNotEmpty
                  ? Image.network(
                      show.posterUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _buildPosterPlaceholder(),
                    )
                  : _buildPosterPlaceholder(),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha((0.75 * 255).round()),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),

              // Date badge (top-left)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        date.day.toString(),
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1,
                        ),
                      ),
                      Text(
                        months[date.month],
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category badge (top-right)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    show.kategori,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Bottom info
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      show.judul,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFFB0B0C8), size: 12),
                        const SizedBox(width: 3),
                        Text(
                          show.kota,
                          style: const TextStyle(
                            color: Color(0xFFB0B0C8),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            show.formattedHarga,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
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
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      color: AppColors.secondary,
      child: const Center(
        child: Icon(Icons.theater_comedy,
            color: AppColors.primary, size: 48),
      ),
    );
  }
}

// ─── Standard Show Card ───────────────────────────────────────────────────────
class _ShowCard extends StatelessWidget {
  final Pertunjukan show;
  const _ShowCard({required this.show});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShowDetailScreen(showId: show.id, show: show),
          ),
        );
      },
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.07 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: show.posterUrl.isNotEmpty
                    ? Image.network(show.posterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder())
                    : _placeholder(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.judul,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      show.formattedHarga,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: AppColors.textSecondary, size: 10),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            show.kota,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _placeholder() => Container(
        color: AppColors.secondary.withAlpha((0.1 * 255).round()),
        child: const Center(
            child: Icon(Icons.image, color: AppColors.textSecondary)),
      );
}

// ─── Trending Show Card (with rank badge) ─────────────────────────────────────
class _TrendingShowCard extends StatelessWidget {
  final Pertunjukan show;
  final int rank;
  const _TrendingShowCard({required this.show, required this.rank});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShowDetailScreen(showId: show.id, show: show),
        ),
      ),
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.07 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: show.posterUrl.isNotEmpty
                        ? Image.network(show.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder())
                        : _placeholder(),
                  ),
                  // Rank badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? AppColors.accent
                            : AppColors.secondary.withAlpha((0.8 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            color: rank <= 3
                                ? AppColors.secondary
                                : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.judul,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.confirmation_number,
                            color: AppColors.primary, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          show.jumlahDipesan != null
                              ? '${show.jumlahDipesan} tiket'
                              : show.formattedHarga,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _placeholder() => Container(
        color: AppColors.secondary.withAlpha((0.1 * 255).round()),
        child: const Center(
            child: Icon(Icons.image, color: AppColors.textSecondary)),
      );
}

// ─── Artist Card ──────────────────────────────────────────────────────────────
class _ArtistCard extends StatelessWidget {
  final Seniman artist;
  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {/* Artist profile screen — to be built by other dev */},
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha((0.2 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: artist.fotoUrl.isNotEmpty
                    ? Image.network(
                        artist.fotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _avatarPlaceholder(),
                      )
                    : _avatarPlaceholder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.nama,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (artist.preferensiSeni.isNotEmpty)
              Text(
                artist.preferensiSeni.first,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    final initial = artist.nama.isNotEmpty ? artist.nama[0].toUpperCase() : '?';
    return Container(
      color: AppColors.primary.withAlpha((0.15 * 255).round()),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}

// ─── Loading Shimmer ───────────────────────────────────────────────────────────
class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              _shimmerBox(double.infinity, 180),
              const SizedBox(height: 16),
              _shimmerBox(double.infinity, 50, padding: 20),
              const SizedBox(height: 16),
              _shimmerBox(double.infinity, 50, padding: 20),
              const SizedBox(height: 24),
              _shimmerRow(height: 220),
              const SizedBox(height: 24),
              _shimmerRow(height: 200),
              const SizedBox(height: 24),
              _shimmerRow(height: 200),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double width, double height, {double padding = 0}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Opacity(
        opacity: _animation.value,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(padding > 0 ? 12 : 0),
          ),
        ),
      ),
    );
  }

  Widget _shimmerRow({required double height}) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => Opacity(
          opacity: _animation.value,
          child: Container(
            width: 148,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
