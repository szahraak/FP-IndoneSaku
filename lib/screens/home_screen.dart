import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pertunjukan.dart';
import '../services/ticketing_service.dart';
import 'ticketing/pesan_tiket_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color _primaryColor = Color(0xFF4B88A2);

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Pertunjukan',
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Pertunjukan>>(
        stream: TicketingService.getPertunjukanStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
          }
          final shows = snapshot.data ?? [];
          if (shows.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Belum ada pertunjukan',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: shows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final show = shows[index];

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PesanTiketScreen(pertunjukan: show),
              ),
            ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Image.network(
                          show.posterUrl,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: double.infinity,
                            height: 160,
                            color: _primaryColor.withValues(alpha: 0.15),
                            child: const Icon(Icons.image,
                                color: _primaryColor, size: 50),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              show.kategori,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
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
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 13, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              dateFmt.format(show.tanggalDateTime),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              show.kota,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mulai ${show.formattedHarga}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Pesan Tiket',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
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
        },
      );
        },
      ),
    );
  }
}
