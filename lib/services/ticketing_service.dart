import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pertunjukan.dart';
import '../models/tiket.dart';

class TicketingService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser?.uid ?? '';

  // ── Pertunjukan ──────────────────────────────────────────────────────────────

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

  // ── Jenis Tiket ──────────────────────────────────────────────────────────────

  static Future<List<JenisTiket>> getJenisTiket(String pertunjukanId) {
    return _db
        .collection('pertunjukan')
        .doc(pertunjukanId)
        .collection('jenisTiket')
        .get()
        .then((snap) => snap.docs.map(JenisTiket.fromFirestore).toList());
  }

  // ── User Info ────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> getCurrentUserInfo() async {
    if (_uid.isEmpty) return {'nama': 'Pengguna', 'email': ''};
    // Cek koleksi 'users' dulu (penonton & seniman ada di sini)
    final doc = await _db.collection('users').doc(_uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      return {
        'nama': (data['nama'] as String?) ?? 'Pengguna',
        'email': (data['email'] as String?) ?? '',
      };
    }
    // Fallback ke Firebase Auth display name
    final user = _auth.currentUser;
    return {
      'nama': user?.displayName ?? 'Pengguna',
      'email': user?.email ?? '',
    };
  }

  // ── Pesanan ──────────────────────────────────────────────────────────────────

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

  /// Membuat pesanan baru di Firestore dengan status 'menunggu'.
  ///
  /// Pesanan dibuat lebih dulu, lalu [MidtransService.getSnapToken] dipanggil
  /// dari [PembayaranScreen] untuk mendapatkan Snap token. Ini memastikan
  /// order ID di Midtrans selalu sinkron dengan ID dokumen Firestore.
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
    final now = DateTime.now();
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
      batasWaktuPembayaran: now.add(const Duration(hours: 24)),
      qrCodeData: 'INDONESAKU-${ref.id}-$_uid',
      // midtransOrderId diisi setelah snap token berhasil didapat
      midtransOrderId: ref.id,
    );
    await ref.set(pesanan.toMap());
    return pesanan;
  }

  /// Batalkan pesanan — update status di Firestore.
  /// Jika sudah dibayar via Midtrans, refund harus dilakukan manual
  /// dari dashboard Midtrans Sandbox.
  static Future<void> batalkanPesanan(String pesananId) {
    return _db.collection('pesanan').doc(pesananId).update({
      'statusPesanan': StatusPesanan.dibatalkan.name,
      'statusPembayaran': StatusPembayaran.gagal.name,
    });
  }
}