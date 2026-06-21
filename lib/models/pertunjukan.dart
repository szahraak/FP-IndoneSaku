import 'package:cloud_firestore/cloud_firestore.dart';

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
  final num harga;
  final num stokTiket;
  final String status;
  final Timestamp dibuatPada;

  // Extra fields for homepage features (not in class diagram but needed for UI)
  final int? jumlahDipesan; // for trending
  final double? rating;

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
    required this.harga,
    required this.stokTiket,
    required this.status,
    required this.dibuatPada,
    this.jumlahDipesan,
    this.rating,
  });

  factory Pertunjukan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      harga: data['harga'] ?? 0,
      stokTiket: data['stokTiket'] ?? 0,
      status: data['status'] ?? 'aktif',
      dibuatPada: data['dibuatPada'] ?? Timestamp.now(),
      jumlahDipesan: data['jumlahDipesan'],
      rating: (data['rating'] as num?)?.toDouble(),
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
      'harga': harga,
      'stokTiket': stokTiket,
      'status': status,
      'dibuatPada': dibuatPada,
      'jumlahDipesan': jumlahDipesan,
      'rating': rating,
    };
  }

  String get formattedHarga {
    if (harga == 0) return 'Gratis';
    final h = harga.toInt();
    final str = h.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  DateTime get tanggalDateTime => tanggal.toDate();

  bool get isUpcoming => tanggalDateTime.isAfter(DateTime.now());
}
