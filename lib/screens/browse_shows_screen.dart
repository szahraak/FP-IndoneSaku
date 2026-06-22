import 'package:flutter/material.dart';
import '../models/pertunjukan.dart';
import '../services/pertunjukan_service.dart';
import 'show_detail_screen.dart';
import '../theme/app_colors.dart';

class BrowseShowsScreen extends StatefulWidget {
  /// Optional: pre-select a category
  final String? initialCategory;

  const BrowseShowsScreen({super.key, this.initialCategory});

  @override
  State<BrowseShowsScreen> createState() => _BrowseShowsScreenState();
}

class _BrowseShowsScreenState extends State<BrowseShowsScreen> {
  final _searchCtrl = TextEditingController();

  List<Pertunjukan> _shows = [];
  bool _loading = true;

  String _selectedCategory = 'Semua';
  String _selectedKota = '';
  String _searchQuery = '';

  final List<String> _categories = [
    'Semua', 'Tari', 'Gamelan', 'Wayang', 'Musik',
    'Ludruk', 'Ketoprak', 'Reog', 'Lenong', 'Kecak', 'Angklung', 'Lainnya',
  ];

  final List<String> _kotaList = [
    'Semua Kota', 'Jakarta', 'Surabaya', 'Yogyakarta', 'Bali',
    'Bandung', 'Semarang', 'Malang', 'Solo', 'Medan',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadShows();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadShows({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _shows = [];
      });
    }

    try {
      final results = await PertunjukanService.browse(
        kategori: _selectedCategory == 'Semua' ? null : _selectedCategory,
        kota: _selectedKota.isEmpty || _selectedKota == 'Semua Kota'
            ? null
            : _selectedKota,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _shows = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query);
    // Debounce a bit
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_searchQuery == query) _loadShows();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        title: const Text('Jelajahi Pertunjukan',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari pertunjukan, kota...',
                hintStyle: TextStyle(
                    color: Colors.white.withAlpha((0.5 * 255).round())),
                filled: true,
                fillColor:
                    Colors.white.withAlpha((0.1 * 255).round()),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.white70),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onChanged: _onSearch,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Category chips ───────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _loadShows();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── City filter + result count ───────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // City filter
                GestureDetector(
                  onTap: _showCityFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _selectedKota.isNotEmpty &&
                              _selectedKota != 'Semua Kota'
                          ? AppColors.primary.withAlpha((0.1 * 255).round())
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedKota.isNotEmpty &&
                                _selectedKota != 'Semua Kota'
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14,
                            color: _selectedKota.isNotEmpty &&
                                    _selectedKota != 'Semua Kota'
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _selectedKota.isEmpty ||
                                  _selectedKota == 'Semua Kota'
                              ? 'Semua Kota'
                              : _selectedKota,
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedKota.isNotEmpty &&
                                    _selectedKota != 'Semua Kota'
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down,
                            size: 14,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (!_loading)
                  Text(
                    '${_shows.length} pertunjukan',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),

          // ── Results ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _shows.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadShows,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _shows.length,
                          itemBuilder: (context, i) =>
                              _BrowseShowCard(show: _shows[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showCityFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Pilih Kota',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ..._kotaList.map((kota) => ListTile(
                  title: Text(kota),
                  trailing: kota == (_selectedKota.isEmpty
                          ? 'Semua Kota'
                          : _selectedKota)
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedKota =
                        kota == 'Semua Kota' ? '' : kota);
                    Navigator.pop(context);
                    _loadShows();
                  },
                )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.theater_comedy_outlined,
              color: AppColors.textSecondary.withAlpha((0.4 * 255).round()),
              size: 64),
          const SizedBox(height: 12),
          const Text(
            'Tidak ada pertunjukan',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coba ubah filter atau kata pencarian',
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = 'Semua';
                _selectedKota = '';
                _searchCtrl.clear();
                _searchQuery = '';
              });
              _loadShows();
            },
            child: const Text('Reset Filter',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _BrowseShowCard extends StatelessWidget {
  final Pertunjukan show;
  const _BrowseShowCard({required this.show});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ShowDetailScreen(showId: show.id, show: show),
        ),
      ),
      child: Container(
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
            // Poster
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: show.posterUrl.isNotEmpty
                        ? Image.network(
                            show.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        show.kategori,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.judul,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: AppColors.textSecondary, size: 11),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            show.kota,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: AppColors.textSecondary, size: 11),
                        const SizedBox(width: 3),
                        Text(
                          _shortDate(show.tanggalDateTime),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      show.formattedHarga,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
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

  String _shortDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}
