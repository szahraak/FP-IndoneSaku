import 'package:cloud_firestore/cloud_firestore.dart';

class Seniman {
  final String uid;
  final String nama;
  final String email;
  final String fotoUrl;
  final String tipeAkun;
  final List<String> preferensiSeni;
  final Timestamp dibuatPada;
  final String? cvPortofolioUrl;

  // Extra fields for UI display
  final int? jumlahPertunjukan;
  final double? rating;

  Seniman({
    required this.uid,
    required this.nama,
    required this.email,
    required this.fotoUrl,
    required this.tipeAkun,
    required this.preferensiSeni,
    required this.dibuatPada,
    this.cvPortofolioUrl,
    this.jumlahPertunjukan,
    this.rating,
  });

  factory Seniman.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Seniman(
      uid: doc.id,
      nama: data['nama'] ?? '',
      email: data['email'] ?? '',
      fotoUrl: data['fotoUrl'] ?? '',
      tipeAkun: data['tipeAkun'] ?? 'seniman',
      preferensiSeni: List<String>.from(data['preferensiSeni'] ?? []),
      dibuatPada: data['dibuatPada'] ?? Timestamp.now(),
      cvPortofolioUrl: data['cvPortofolioUrl'],
      jumlahPertunjukan: data['jumlahPertunjukan'],
      rating: (data['rating'] as num?)?.toDouble(),
    );
  }
}
