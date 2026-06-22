import 'package:cloud_firestore/cloud_firestore.dart';
import 'tiket.dart';

class Pertunjukan {
  final String id;
  final String senimanUid;
  final String judul;
  final String deskripsi;
  final String posterUrl;
  final String? videoTeaserUrl;
  final String kategori;
  final String kota;
  final GeoPoint? lokasi;
  final Timestamp tanggal;
  final String status;
  final Timestamp dibuatPada;
  final int? jumlahDipesan;
  final double? rating;
  final num hargaTermurah;
  final List<JenisTiket> daftarTiket;

  Pertunjukan({
    required this.id,
    required this.senimanUid,
    required this.judul,
    required this.deskripsi,
    required this.posterUrl,
    this.videoTeaserUrl,
    required this.kategori,
    required this.kota,
    this.lokasi,
    required this.tanggal,
    required this.status,
    required this.dibuatPada,
    this.jumlahDipesan,
    this.rating,
    required this.hargaTermurah,
    required this.daftarTiket,
  });

  factory Pertunjukan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final List<dynamic> tiketRaw = data['daftarTiket'] ?? [];
    final List<JenisTiket> tiketList = tiketRaw.map((t) => JenisTiket(
      id: t['id'] ?? '',
      nama: t['nama'] ?? '',
      harga: (t['harga'] as num?)?.toDouble() ?? 0,
      stok: (t['stok'] as num?)?.toInt() ?? 0,
      deskripsi: t['deskripsi'],
    )).toList();

    return Pertunjukan(
      id: doc.id,
      senimanUid: data['seniman_uid'] ?? '',
      judul: data['judul'] ?? '',
      deskripsi: data['deskripsi'] ?? '',
      posterUrl: data['posterUrl'] ?? '',
      videoTeaserUrl: data['videoTeaserUrl'],
      kategori: data['kategori'] ?? '',
      kota: data['kota'] ?? '',
      lokasi: data['lokasi'],
      tanggal: data['tanggal'] ?? Timestamp.now(),
      status: data['status'] ?? 'aktif',
      dibuatPada: data['dibuatPada'] ?? Timestamp.now(),
      jumlahDipesan: data['jumlahDipesan'],
      rating: (data['rating'] as num?)?.toDouble(),
      hargaTermurah: data['hargaTermurah'] ?? 0,
      daftarTiket: tiketList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seniman_uid': senimanUid,
      'judul': judul,
      'deskripsi': deskripsi,
      'posterUrl': posterUrl,
      'videoTeaserUrl': videoTeaserUrl,
      'kategori': kategori,
      'kota': kota,
      'lokasi': lokasi,
      'tanggal': tanggal,
      'status': status,
      'dibuatPada': dibuatPada,
      'jumlahDipesan': jumlahDipesan,
      'rating': rating,
      'hargaTermurah': hargaTermurah,
      'daftarTiket': daftarTiket.map((t) => {
        'id': t.id,
        'nama': t.nama,
        'harga': t.harga,
        'stok': t.stok,
        'deskripsi': t.deskripsi,
      }).toList(),
    };
  }

  // Helper getters
  String get formattedHarga {
    if (hargaTermurah == 0) return 'Mulai dari Gratis';
    final h = hargaTermurah.toInt();
    final str = h.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Mulai Rp ${buffer.toString()}';
  }

  DateTime get tanggalDateTime => tanggal.toDate();
  bool get isUpcoming => tanggalDateTime.isAfter(DateTime.now());
  
  int get totalStok => daftarTiket.fold(0, (total, tiket) => total + tiket.stok);
}