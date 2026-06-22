import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class JenisTiket {
  final String id;
  final String nama;
  final double harga;
  final int stok;
  final String? deskripsi;

  JenisTiket({
    required this.id,
    required this.nama,
    required this.harga,
    required this.stok,
    this.deskripsi,
  });

  factory JenisTiket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JenisTiket(
      id: doc.id,
      nama: data['nama'] ?? '',
      harga: (data['harga'] as num?)?.toDouble() ?? 0,
      stok: (data['stok'] as num?)?.toInt() ?? 0,
      deskripsi: data['deskripsi'],
    );
  }
}

enum StatusPembayaran { menunggu, berhasil, gagal, kedaluwarsa }

enum StatusPesanan { menunggu, dikonfirmasi, dibatalkan }

// MetodePembayaran dipertahankan untuk label UI — nilai sebenarnya
// datang dari Midtrans (payment_type di webhook).
enum MetodePembayaran { qris, dompetDigital, transferBank, kartuKredit, online }

extension MetodePembayaranExt on MetodePembayaran {
  String get label {
    switch (this) {
      case MetodePembayaran.qris:
        return 'QRIS';
      case MetodePembayaran.dompetDigital:
        return 'Dompet Digital';
      case MetodePembayaran.transferBank:
        return 'Transfer Bank';
      case MetodePembayaran.kartuKredit:
        return 'Kartu Kredit/Debit';
      case MetodePembayaran.online:
        return 'Pembayaran Online';
    }
  }

  String get subLabel {
    switch (this) {
      case MetodePembayaran.qris:
        return 'Bayar dengan QRIS';
      case MetodePembayaran.dompetDigital:
        return 'GoPay, OVO, Dana, dll';
      case MetodePembayaran.transferBank:
        return 'BCA, Mandiri, BNI, dll';
      case MetodePembayaran.kartuKredit:
        return 'Visa, Mastercard, dll';
      case MetodePembayaran.online:
        return 'Pembayaran Online';
    }
  }
}

class ItemPesanan {
  final String jenisTiketId;
  final String namaJenisTiket;
  final double hargaSatuan;
  int jumlah;

  ItemPesanan({
    required this.jenisTiketId,
    required this.namaJenisTiket,
    required this.hargaSatuan,
    required this.jumlah,
  });

  double get subtotal => hargaSatuan * jumlah;
}

class TiketPesanan {
  final String id;
  final String penggunaUid;
  final String pertunjukanId;
  final String judulPertunjukan;
  final String posterUrl;
  final DateTime tanggalPertunjukan;
  final String lokasi;
  final String namaPemesan;
  final String emailPemesan;
  final List<ItemPesanan> items;
  final double totalHarga;
  StatusPembayaran statusPembayaran;
  StatusPesanan statusPesanan;
  final String? qrCodeData;
  final DateTime dibuatPada;
  final String? nomorPembayaran;
  MetodePembayaran? metodePembayaran;
  String? namaAkunPembayaran;
  final DateTime batasWaktuPembayaran;

  // ── Midtrans fields ──────────────────────────────────────────────────
  /// Snap token yang didapat dari Cloud Function — dipakai untuk buka
  /// halaman pembayaran Midtrans Snap. Nilainya sementara (expire ~1 jam).
  String? snapToken;

  /// Order ID yang dikirim ke Midtrans — sama dengan [id] pesanan,
  /// dipakai untuk mencocokkan webhook callback dari Midtrans.
  final String? midtransOrderId;

  /// Payment type mentah dari Midtrans (contoh: 'qris', 'bank_transfer',
  /// 'gopay'). Disimpan untuk keperluan audit/display.
  String? midtransPaymentType;
  // ────────────────────────────────────────────────────────────────────

  TiketPesanan({
    String? id,
    required this.penggunaUid,
    required this.pertunjukanId,
    required this.judulPertunjukan,
    required this.posterUrl,
    required this.tanggalPertunjukan,
    required this.lokasi,
    required this.namaPemesan,
    required this.emailPemesan,
    required this.items,
    required this.totalHarga,
    this.statusPembayaran = StatusPembayaran.menunggu,
    this.statusPesanan = StatusPesanan.menunggu,
    this.qrCodeData,
    DateTime? dibuatPada,
    this.nomorPembayaran,
    this.metodePembayaran,
    this.namaAkunPembayaran,
    required this.batasWaktuPembayaran,
    this.snapToken,
    this.midtransOrderId,
    this.midtransPaymentType,
  })  : id = id ?? const Uuid().v4(),
        dibuatPada = dibuatPada ?? DateTime.now();

  factory TiketPesanan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsData = (data['items'] as List<dynamic>?) ?? [];
    return TiketPesanan(
      id: doc.id,
      penggunaUid: data['penggunaUid'] ?? '',
      pertunjukanId: data['pertunjukanId'] ?? '',
      judulPertunjukan: data['judulPertunjukan'] ?? '',
      posterUrl: data['posterUrl'] ?? '',
      tanggalPertunjukan:
          (data['tanggalPertunjukan'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lokasi: data['lokasi'] ?? '',
      namaPemesan: data['namaPemesan'] ?? '',
      emailPemesan: data['emailPemesan'] ?? '',
      items: itemsData
          .map((e) => ItemPesanan(
                jenisTiketId: e['jenisTiketId'] ?? '',
                namaJenisTiket: e['namaJenisTiket'] ?? '',
                hargaSatuan: (e['hargaSatuan'] as num?)?.toDouble() ?? 0,
                jumlah: (e['jumlah'] as num?)?.toInt() ?? 0,
              ))
          .toList(),
      totalHarga: (data['totalHarga'] as num?)?.toDouble() ?? 0,
      statusPembayaran: _statusPembayaranFromString(data['statusPembayaran']),
      statusPesanan: _statusPesananFromString(data['statusPesanan']),
      qrCodeData: data['qrCodeData'],
      dibuatPada: (data['dibuatPada'] as Timestamp?)?.toDate(),
      nomorPembayaran: data['nomorPembayaran'],
      metodePembayaran: data['metodePembayaran'] != null
          ? _metodePembayaranFromString(data['metodePembayaran'])
          : null,
      namaAkunPembayaran: data['namaAkunPembayaran'],
      batasWaktuPembayaran: (data['batasWaktuPembayaran'] as Timestamp?)?.toDate() 
          ?? ((data['dibuatPada'] as Timestamp?)?.toDate() ?? DateTime.now()).add(const Duration(hours: 24)),
      snapToken: data['snapToken'],
      midtransOrderId: data['midtransOrderId'],
      midtransPaymentType: data['midtransPaymentType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'penggunaUid': penggunaUid,
      'pertunjukanId': pertunjukanId,
      'judulPertunjukan': judulPertunjukan,
      'posterUrl': posterUrl,
      'tanggalPertunjukan': Timestamp.fromDate(tanggalPertunjukan),
      'lokasi': lokasi,
      'namaPemesan': namaPemesan,
      'emailPemesan': emailPemesan,
      'items': items
          .map((e) => {
                'jenisTiketId': e.jenisTiketId,
                'namaJenisTiket': e.namaJenisTiket,
                'hargaSatuan': e.hargaSatuan,
                'jumlah': e.jumlah,
              })
          .toList(),
      'totalHarga': totalHarga,
      'statusPembayaran': statusPembayaran.name,
      'statusPesanan': statusPesanan.name,
      'qrCodeData': qrCodeData,
      'dibuatPada': Timestamp.fromDate(dibuatPada),
      'nomorPembayaran': nomorPembayaran,
      'metodePembayaran': metodePembayaran?.name,
      'namaAkunPembayaran': namaAkunPembayaran,
      'batasWaktuPembayaran': Timestamp.fromDate(batasWaktuPembayaran),
      'snapToken': snapToken,
      'midtransOrderId': midtransOrderId,
      'midtransPaymentType': midtransPaymentType,
    };
  }

  static StatusPembayaran _statusPembayaranFromString(String? s) {
    if (s == null) return StatusPembayaran.menunggu;
    try {
      return StatusPembayaran.values.byName(s);
    } catch (_) {
      return StatusPembayaran.menunggu;
    }
  }

  static StatusPesanan _statusPesananFromString(String? s) {
    if (s == null) return StatusPesanan.menunggu;
    try {
      return StatusPesanan.values.byName(s);
    } catch (_) {
      return StatusPesanan.menunggu;
    }
  }

  static MetodePembayaran _metodePembayaranFromString(String? s) {
    if (s == null) return MetodePembayaran.qris;
    try {
      return MetodePembayaran.values.byName(s);
    } catch (_) {
      return MetodePembayaran.qris;
    }
  }

  int get totalJumlah =>
      items.fold(0, (total, item) => total + item.jumlah);

  // ── GETTER LABEL PEMBAYARAN SPESIFIK ──────────────────────────────────────────────
  String get labelPembayaranSpesifik {
    if (midtransPaymentType == null || midtransPaymentType == 'unknown') {
      return metodePembayaran?.label ?? 'Pembayaran Online';
    }

    final type = midtransPaymentType!.toLowerCase();

    if (type.contains('bca')) return 'Transfer Bank - BCA';
    if (type.contains('bni')) return 'Transfer Bank - BNI';
    if (type.contains('bri')) return 'Transfer Bank - BRI';
    if (type.contains('mandiri') || type == 'echannel') return 'Transfer Bank - Mandiri';
    if (type.contains('permata')) return 'Transfer Bank - Permata';
    if (type.contains('cimb')) return 'Transfer Bank - CIMB Niaga';
    if (type == 'bank_transfer') return 'Transfer Bank';

    if (type.contains('indomaret')) return 'Indomaret';
    if (type.contains('alfamart')) return 'Alfamart';
    if (type == 'cstore') return 'Minimarket';

    switch (type) {
      case 'gopay': return 'GoPay';
      case 'shopeepay': return 'ShopeePay';
      case 'ovo': return 'OVO';
      case 'dana': return 'DANA';
      case 'qris': return 'QRIS';
      case 'credit_card': return 'Kartu Kredit';
      case 'akulaku': return 'Akulaku Paylater';
      default:
        return metodePembayaran?.label ?? 'Pembayaran Online';
    }
  }
}