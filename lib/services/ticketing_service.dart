import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pertunjukan.dart';
import '../models/tiket.dart';

class TicketingService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser?.uid ?? '';

  // ── Pertunjukan ─────────────────────────────────────────────────────

  static Stream<List<Pertunjukan>> getPertunjukanStream() {
    return _db
        .collection('pertunjukan')
        .where('status', isEqualTo: 'aktif')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Pertunjukan.fromFirestore).toList();
      list.sort((a, b) => a.tanggal.compareTo(b.tanggal));
      return list;
    });
  }

  // ── Jenis Tiket ─────────────────────────────────────────────────────

  static Future<List<JenisTiket>> getJenisTiket(String pertunjukanId) {
    return _db
        .collection('pertunjukan')
        .doc(pertunjukanId)
        .collection('jenisTiket')
        .get()
        .then((snap) => snap.docs.map(JenisTiket.fromFirestore).toList());
  }

  // ── User info ────────────────────────────────────────────────────────

  static Future<Map<String, String>> getCurrentUserInfo() async {
    if (_uid.isEmpty) return {'nama': 'Pengguna', 'email': ''};
    final doc = await _db.collection('seniman').doc(_uid).get();
    if (!doc.exists) {
      final user = _auth.currentUser;
      return {
        'nama': user?.displayName ?? 'Pengguna',
        'email': user?.email ?? '',
      };
    }
    final data = doc.data()!;
    return {
      'nama': (data['nama'] as String?) ?? 'Pengguna',
      'email': (data['email'] as String?) ?? '',
    };
  }

  // ── Pesanan ──────────────────────────────────────────────────────────

  static Stream<List<TiketPesanan>> getTiketSayaStream() {
    if (_uid.isEmpty) return Stream.value([]);
    return _db
        .collection('pesanan')
        .where('penggunaUid', isEqualTo: _uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(TiketPesanan.fromFirestore).toList();
      list.sort((a, b) => b.dibuatPada.compareTo(a.dibuatPada));
      return list;
    });
  }

  static Future<TiketPesanan> buatPesanan({
    required String pertunjukanId,
    required String judulPertunjukan,
    required String posterUrl,
    required DateTime tanggalPertunjukan,
    required String lokasi,
    required String namaPemesan,
    required String emailPemesan,
    required List<ItemPesanan> items,
    required double totalHarga,
  }) async {
    final ref = _db.collection('pesanan').doc();
    final pesanan = TiketPesanan(
      id: ref.id,
      penggunaUid: _uid,
      pertunjukanId: pertunjukanId,
      judulPertunjukan: judulPertunjukan,
      posterUrl: posterUrl,
      tanggalPertunjukan: tanggalPertunjukan,
      lokasi: lokasi,
      namaPemesan: namaPemesan,
      emailPemesan: emailPemesan,
      items: items,
      totalHarga: totalHarga,
      qrCodeData: 'INDONESAKU-${ref.id}-$_uid',
    );
    await ref.set(pesanan.toMap());
    return pesanan;
  }

  static Future<TiketPesanan> konfirmasiPembayaran({
    required TiketPesanan pesanan,
    required MetodePembayaran metode,
    String? namaAkun,
  }) async {
    final namaAkunFinal = namaAkun ?? metode.label;
    final nomorPembayaran =
        '11988${DateTime.now().millisecondsSinceEpoch % 10000000000}';
    await _db.collection('pesanan').doc(pesanan.id).update({
      'statusPembayaran': StatusPembayaran.berhasil.name,
      'statusPesanan': StatusPesanan.dikonfirmasi.name,
      'metodePembayaran': metode.name,
      'namaAkunPembayaran': namaAkunFinal,
      'nomorPembayaran': nomorPembayaran,
    });
    pesanan.statusPembayaran = StatusPembayaran.berhasil;
    pesanan.statusPesanan = StatusPesanan.dikonfirmasi;
    pesanan.metodePembayaran = metode;
    pesanan.namaAkunPembayaran = namaAkunFinal;
    return pesanan;
  }

  static Future<void> batalkanPesanan(String pesananId) {
    return _db.collection('pesanan').doc(pesananId).update({
      'statusPesanan': StatusPesanan.dibatalkan.name,
      'statusPembayaran': StatusPembayaran.gagal.name,
    });
  }
}
