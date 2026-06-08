import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pertunjukan.dart';

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
    required num harga,
    required num stokTiket,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User tidak login');

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
      'harga': harga,
      'stokTiket': stokTiket,
      'status': 'aktif',
      'dibuatPada': FieldValue.serverTimestamp(),
      'jumlahDipesan': 0,
      'rating': null,
    });

    // Increment artist's show count
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
    String sortBy = 'tanggal', // 'tanggal' | 'harga' | 'jumlahDipesan'
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

    if (lastDoc != null) {
      q = q.startAfterDocument(lastDoc);
    }

    final snap = await q.get();
    var results = snap.docs.map((d) => Pertunjukan.fromFirestore(d)).toList();

    // Client-side search filter (Firestore doesn't support full-text search)
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
    num? harga,
    num? stokTiket,
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
    if (tanggal != null) updates['tanggal'] = tanggal;
    if (harga != null) updates['harga'] = harga;
    if (stokTiket != null) updates['stokTiket'] = stokTiket;
    if (status != null) updates['status'] = status;

    await _db.collection(_col).doc(id).update(updates);
  }

  // ── DELETE (soft — set status to 'dibatalkan') ────────────────────────────
  static Future<void> cancel(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User tidak login');

    await _db.collection(_col).doc(id).update({'status': 'dibatalkan'});

    await _db.collection('users').doc(uid).update({
      'jumlahPertunjukan': FieldValue.increment(-1),
    });
  }

  // ── HARD DELETE ───────────────────────────────────────────────────────────
  static Future<void> hardDelete(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User tidak login');

    await _db.collection(_col).doc(id).delete();

    await _db.collection('users').doc(uid).update({
      'jumlahPertunjukan': FieldValue.increment(-1),
    });
  }
}
