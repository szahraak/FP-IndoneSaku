import '../models/pertunjukan_model.dart';
import '../models/tiket_pesanan_model.dart';

// ── Mock current user ────────────────────────────────────────────────
class MockUser {
  static const String uid = 'user_001';
  static const String nama = 'Fauzan Willis';
  static const String email = 'fauzan@example.com';
}

// ── Mock pertunjukan data ────────────────────────────────────────────
final List<PertunjukanModel> mockPertunjukan = [
  PertunjukanModel(
    id: 'show_001',
    seniman: 'ATLAS',
    judul: 'ATLAS: THE RISE OF ALAS',
    deskripsi:
        'Sebuah pertunjukan musik spektakuler yang memadukan elemen budaya Nusantara dengan musik modern. '
        'Dipersembahkan oleh seniman muda berbakat dari seluruh Indonesia.',
    posterUrl:
        'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400',
    kategori: 'Musik',
    kota: 'Jakarta',
    tanggal: DateTime(2022, 10, 29, 15, 0),
    lokasi: 'SMAN CMBBS',
    jenisTiket: [
      JenisTiket(
        id: 'tiket_001',
        nama: 'Jenis Tiket 1',
        harga: 35000,
        stok: 0,
        deskripsi: 'Tiket reguler',
      ),
      JenisTiket(
        id: 'tiket_002',
        nama: 'Jenis Tiket 2',
        harga: 85000,
        stok: 50,
        deskripsi: 'Tiket VIP dengan akses eksklusif',
      ),
    ],
    status: 'aktif',
  ),
  PertunjukanModel(
    id: 'show_002',
    seniman: 'Sanggar Nusantara',
    judul: 'Tari Nusantara: Dari Sabang Sampai Merauke',
    deskripsi:
        'Pertunjukan tari tradisional yang memperlihatkan kekayaan budaya Indonesia dari Sabang hingga Merauke.',
    posterUrl:
        'https://images.unsplash.com/photo-1518834107812-67b0b7c58434?w=400',
    kategori: 'Tari',
    kota: 'Bandung',
    tanggal: DateTime(2022, 11, 5, 19, 0),
    lokasi: 'Gedung Kesenian Bandung',
    jenisTiket: [
      JenisTiket(
        id: 'tiket_003',
        nama: 'Reguler',
        harga: 50000,
        stok: 100,
      ),
      JenisTiket(
        id: 'tiket_004',
        nama: 'VIP',
        harga: 150000,
        stok: 20,
      ),
    ],
    status: 'aktif',
  ),
];

// ── In-memory pesanan store ──────────────────────────────────────────
final List<TiketPesanan> _pesananStore = [
  TiketPesanan(
    id: 'pesanan_001',
    penggunaUid: MockUser.uid,
    pertunjukanId: 'show_002',
    judulPertunjukan: 'Tari Nusantara',
    posterUrl:
        'https://images.unsplash.com/photo-1518834107812-67b0b7c58434?w=400',
    tanggalPertunjukan: DateTime(2022, 11, 5, 19, 0),
    lokasi: 'Gedung Kesenian Bandung',
    namaPemesan: MockUser.nama,
    emailPemesan: MockUser.email,
    items: [
      ItemPesanan(
        jenisTiketId: 'tiket_003',
        namaJenisTiket: 'Reguler',
        hargaSatuan: 50000,
        jumlah: 2,
      ),
    ],
    totalHarga: 100000,
    statusPembayaran: StatusPembayaran.berhasil,
    statusPesanan: StatusPesanan.dikonfirmasi,
    qrCodeData: 'INDONESAKU-pesanan_001-user_001',
    nomorPembayaran: '119880479400162508',
    metodePembayaran: MetodePembayaran.dompetDigital,
    namaAkunPembayaran: 'Dana',
    dibuatPada: DateTime(2022, 11, 1, 10, 0),
  ),
];

class MockTicketingService {
  // Get all pertunjukan
  static List<PertunjukanModel> getAllPertunjukan() => mockPertunjukan;

  // Get pertunjukan by id
  static PertunjukanModel? getPertunjukanById(String id) {
    try {
      return mockPertunjukan.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // Get my tickets for current user
  static List<TiketPesanan> getTiketSaya() {
    return _pesananStore
        .where((p) => p.penggunaUid == MockUser.uid)
        .toList()
      ..sort((a, b) => b.dibuatPada.compareTo(a.dibuatPada));
  }

  // Create new pesanan
  static TiketPesanan buatPesanan({
    required String pertunjukanId,
    required String judulPertunjukan,
    required String posterUrl,
    required DateTime tanggalPertunjukan,
    required String lokasi,
    required String namaPemesan,
    required String emailPemesan,
    required List<ItemPesanan> items,
    required double totalHarga,
  }) {
    final pesanan = TiketPesanan(
      penggunaUid: MockUser.uid,
      pertunjukanId: pertunjukanId,
      judulPertunjukan: judulPertunjukan,
      posterUrl: posterUrl,
      tanggalPertunjukan: tanggalPertunjukan,
      lokasi: lokasi,
      namaPemesan: namaPemesan,
      emailPemesan: emailPemesan,
      items: items,
      totalHarga: totalHarga,
    );
    _pesananStore.add(pesanan);
    return pesanan;
  }

  // Confirm payment
  static TiketPesanan konfirmasiPembayaran({
    required TiketPesanan pesanan,
    required MetodePembayaran metode,
    String? namaAkun,
  }) {
    pesanan.statusPembayaran = StatusPembayaran.berhasil;
    pesanan.statusPesanan = StatusPesanan.dikonfirmasi;
    pesanan.metodePembayaran = metode;
    pesanan.namaAkunPembayaran = namaAkun ?? metode.label;
    return pesanan;
  }

  // Cancel pesanan (soft-delete)
  static void batalkanPesanan(String pesananId) {
    final idx = _pesananStore.indexWhere((p) => p.id == pesananId);
    if (idx != -1) {
      _pesananStore[idx].statusPesanan = StatusPesanan.dibatalkan;
      _pesananStore[idx].statusPembayaran = StatusPembayaran.gagal;
    }
  }
}
