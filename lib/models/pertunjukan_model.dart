class JenisTiket {
  final String id;
  final String nama;
  final double harga;
  int stok;
  final String? deskripsi;

  JenisTiket({
    required this.id,
    required this.nama,
    required this.harga,
    required this.stok,
    this.deskripsi,
  });
}

class PertunjukanModel {
  final String id;
  final String seniman;
  final String judul;
  final String deskripsi;
  final String posterUrl;
  final String? videoTeaserUrl;
  final String kategori;
  final String kota;
  final DateTime tanggal;
  final String lokasi;
  final List<JenisTiket> jenisTiket;
  final String status;

  PertunjukanModel({
    required this.id,
    required this.seniman,
    required this.judul,
    required this.deskripsi,
    required this.posterUrl,
    this.videoTeaserUrl,
    required this.kategori,
    required this.kota,
    required this.tanggal,
    required this.lokasi,
    required this.jenisTiket,
    required this.status,
  });
}
