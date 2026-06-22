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

  static Future<List<JenisTiket>> getJenisTiket(String pertunjukanId) async {
    final doc = await _db.collection('pertunjukan').doc(pertunjukanId).get();
    if (doc.exists && doc.data()!['daftarTiket'] != null) {
      final tiketList = List<Map<String, dynamic>>.from(doc.data()!['daftarTiket']);
      return tiketList.map((t) => JenisTiket(
        id: t['id'],
        nama: t['nama'],
        harga: (t['harga'] as num).toDouble(),
        stok: t['stok'] as int,
        deskripsi: t['deskripsi'],
      )).toList();
    }
    return [];
  }

  // ── User Info ────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> getCurrentUserInfo() async {
    if (_uid.isEmpty) return {'nama': 'Pengguna', 'email': ''};
    
    final doc = await _db.collection('users').doc(_uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      return {
        'nama': (data['nama'] as String?) ?? 'Pengguna',
        'email': (data['email'] as String?) ?? '',
      };
    }
    
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

  /// Membuat pesanan baru menggunakan Transaction agar stok akurat & mencegah overselling.
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
    final pertunjukanRef = _db.collection('pertunjukan').doc(pertunjukanId);
    final now = DateTime.now();

    return await _db.runTransaction((transaction) async {
      // 1. Ambil data pertunjukan terbaru
      final snapshot = await transaction.get(pertunjukanRef);
      if (!snapshot.exists) throw Exception("Pertunjukan tidak ditemukan");

      final data = snapshot.data()!;
      List<dynamic> daftarTiket = List.from(data['daftarTiket'] ?? []);
      int totalDipesan = data['jumlahDipesan'] ?? 0;
      int totalItemBaru = 0;

      for (var item in items) {
        totalItemBaru += item.jumlah;
        
        final ticketIndex = daftarTiket.indexWhere((t) => t['id'] == item.jenisTiketId);
        if (ticketIndex == -1) throw Exception("Jenis tiket tidak valid");

        int currentStok = daftarTiket[ticketIndex]['stok'];
        if (currentStok < item.jumlah) {
          throw Exception("Stok tiket ${item.namaJenisTiket} habis atau tidak mencukupi");
        }
        
        daftarTiket[ticketIndex]['stok'] = currentStok - item.jumlah;
      }

      transaction.update(pertunjukanRef, {
        'daftarTiket': daftarTiket,
        'jumlahDipesan': totalDipesan + totalItemBaru,
      });

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
        midtransOrderId: ref.id,
      );

      transaction.set(ref, pesanan.toMap());
      
      return pesanan;
    });
  }

  /// Membatalkan pesanan menggunakan Transaction untuk mengembalikan stok tiket yang hangus
  static Future<void> batalkanPesanan(String pesananId) async {
    final pesananRef = _db.collection('pesanan').doc(pesananId);

    await _db.runTransaction((transaction) async {
      final pesananSnap = await transaction.get(pesananRef);
      if (!pesananSnap.exists) throw Exception("Pesanan tidak ditemukan");

      final pesananData = pesananSnap.data()!;
      
      if (pesananData['statusPesanan'] == StatusPesanan.dibatalkan.name) {
        return; 
      }

      final pertunjukanId = pesananData['pertunjukanId'];
      final pertunjukanRef = _db.collection('pertunjukan').doc(pertunjukanId);

      final pertunjukanSnap = await transaction.get(pertunjukanRef);
      
      if (pertunjukanSnap.exists) {
        final pertunjukanData = pertunjukanSnap.data()!;
        List<dynamic> daftarTiket = List.from(pertunjukanData['daftarTiket'] ?? []);
        int totalDipesan = pertunjukanData['jumlahDipesan'] ?? 0;
        int totalItemDikembalikan = 0;

        List<dynamic> items = pesananData['items'] ?? [];

        for (var item in items) {
          int jumlah = item['jumlah'] ?? 0;
          totalItemDikembalikan += jumlah;
          String jenisTiketId = item['jenisTiketId'];

          final ticketIndex = daftarTiket.indexWhere((t) => t['id'] == jenisTiketId);
          if (ticketIndex != -1) {
            daftarTiket[ticketIndex]['stok'] = (daftarTiket[ticketIndex]['stok'] as int) + jumlah;
          }
        }

        transaction.update(pertunjukanRef, {
          'daftarTiket': daftarTiket,
          'jumlahDipesan': (totalDipesan - totalItemDikembalikan).clamp(0, 999999),
        });
      }

      transaction.update(pesananRef, {
        'statusPesanan': StatusPesanan.dibatalkan.name,
        'statusPembayaran': StatusPembayaran.gagal.name,
      });
    });
  }
}