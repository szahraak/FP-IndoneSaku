import 'package:uuid/uuid.dart';

enum StatusPembayaran { menunggu, berhasil, gagal, kedaluwarsa }

enum StatusPesanan { menunggu, dikonfirmasi, dibatalkan }

enum MetodePembayaran { qris, dompetDigital, transferBank, kartuKredit }

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
  })  : id = id ?? const Uuid().v4(),
        dibuatPada = dibuatPada ?? DateTime.now();

  int get totalJumlah =>
      items.fold(0, (sum, item) => sum + item.jumlah);
}
