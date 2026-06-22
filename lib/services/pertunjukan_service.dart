import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pertunjukan.dart';
import '../models/tiket.dart'; // TAMBAHKAN IMPORT INI

class PertunjukanService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const _col = 'pertunjukan';

  // ── CREATE ────────────────────────────────────────────────────────────────
  static Future<String> create({
    required String judul,
    required String deskripsi,
    required String posterUrl,
    String? videoTeaserUrl,
    required String kategori,
    required String kota,
    GeoPoint? lokasi,
    required Timestamp tanggal,
    required List<JenisTiket> daftarTiket,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User tidak login');

    // Cari harga termurah (untuk ditampilkan di Homepage)
    double hargaTermurah = 0;
    if (daftarTiket.isNotEmpty) {
      hargaTermurah = daftarTiket.map((t) => t.harga).reduce((a, b) => a < b ? a : b);
    }

    final ref = await _db.collection(_col).add({
      'seniman_uid': uid,
      'judul': judul,
      'deskripsi': deskripsi,
      'posterUrl': posterUrl,
      'videoTeaserUrl': videoTeaserUrl,
      'kategori': kategori,
      'kota': kota,
      'lokasi': lokasi,
      'tanggal': tanggal,
      'hargaTermurah': hargaTermurah,
      'daftarTiket': daftarTiket.map((t) => {
        'id': t.id,
        'nama': t.nama,
        'harga': t.harga,
        'stok': t.stok,
        'deskripsi': t.deskripsi,
      }).toList(),
      'status': 'aktif',
      'dibuatPada': FieldValue.serverTimestamp(),
      'jumlahDipesan': 0,
      'rating': null,
    });

    await _db.collection('users').doc(uid).update({
      'jumlahPertunjukan': FieldValue.increment(1),
    });

    return ref.id;
  }

  // ── READ (single) ─────────────────────────────────────────────────────────
  static Future<Pertunjukan?> getById(String id) async {
    final doc = await _db.collection(_col).doc(id).get();
    if (!doc.exists) return null;
    return Pertunjukan.fromFirestore(doc);
  }

  // ── READ (my shows — current seniman) ─────────────────────────────────────
  static Stream<List<Pertunjukan>> myShowsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection(_col)
        .where('seniman_uid', isEqualTo: uid)
        .orderBy('dibuatPada', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Pertunjukan.fromFirestore(d)).toList());
  }

  // ── READ (browse with filter) ─────────────────────────────────────────────
  static Future<List<Pertunjukan>> browse({
    String? kategori,
    String? kota,
    String? search,
    String sortBy = 'tanggal',
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    Query q = _db
        .collection(_col)
        .where('status', isEqualTo: 'aktif')
        .where('tanggal', isGreaterThan: Timestamp.now());

    if (kategori != null && kategori != 'Semua') {
      q = q.where('kategori', isEqualTo: kategori);
    }
    if (kota != null && kota.isNotEmpty) {
      q = q.where('kota', isEqualTo: kota);
    }

    q = q.orderBy('tanggal').limit(limit);
    if (lastDoc != null) q = q.startAfterDocument(lastDoc);

    final snap = await q.get();
    var results = snap.docs.map((d) => Pertunjukan.fromFirestore(d)).toList();

    if (search != null && search.isNotEmpty) {
      final lower = search.toLowerCase();
      results = results
          .where((p) =>
              p.judul.toLowerCase().contains(lower) ||
              p.deskripsi.toLowerCase().contains(lower) ||
              p.kota.toLowerCase().contains(lower))
          .toList();
    }
    return results;
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────
  static Future<void> update(
    String id, {
    String? judul,
    String? deskripsi,
    String? posterUrl,
    String? videoTeaserUrl,
    String? kategori,
    String? kota,
    GeoPoint? lokasi,
    Timestamp? tanggal,
    List<JenisTiket>? daftarTiket,
    String? status,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User tidak login');

    final updates = <String, dynamic>{};
    if (judul != null) updates['judul'] = judul;
    if (deskripsi != null) updates['deskripsi'] = deskripsi;
    if (posterUrl != null) updates['posterUrl'] = posterUrl;
    if (videoTeaserUrl != null) updates['videoTeaserUrl'] = videoTeaserUrl;
    if (kategori != null) updates['kategori'] = kategori;
    if (kota != null) updates['kota'] = kota;
    if (lokasi != null) updates['lokasi'] = lokasi;
    if (status != null) updates['status'] = status;
    if (tanggal != null) updates['tanggal'] = tanggal;
    
    if (daftarTiket != null) {
      double hargaTermurah = 0;
      if (daftarTiket.isNotEmpty) {
        hargaTermurah = daftarTiket.map((t) => t.harga).reduce((a, b) => a < b ? a : b);
      }
      updates['hargaTermurah'] = hargaTermurah;
      updates['daftarTiket'] = daftarTiket.map((t) => {
        'id': t.id,
        'nama': t.nama,
        'harga': t.harga,
        'stok': t.stok,
        'deskripsi': t.deskripsi,
      }).toList();
    }

    await _db.collection(_col).doc(id).update(updates);
  }

  // ── CANCEL & HARD DELETE ──────────────────────────────────────────────────
  static Future<void> cancel(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User tidak login');
    await _db.collection(_col).doc(id).update({'status': 'dibatalkan'});
    await _db.collection('users').doc(uid).update({
      'jumlahPertunjukan': FieldValue.increment(-1),
    });
  }

  static Future<void> hardDelete(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User tidak login');
    await _db.collection(_col).doc(id).delete();
    await _db.collection('users').doc(uid).update({
      'jumlahPertunjukan': FieldValue.increment(-1),
    });
  }
}