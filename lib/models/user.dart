import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String nama;
  final String email;
  final String fotoUrl;
  final String tipeAkun; // 'penonton' | 'seniman' | 'admin'
  final List<String> preferensiSeni;
  final String tanggalLahir; // format DD/MM/YYYY
  final Timestamp createdAt;
  final String? cvUrl;        // khusus seniman
  final String? portofolioUrl; // khusus seniman

  const UserModel({
    required this.uid,
    required this.nama,
    required this.email,
    required this.fotoUrl,
    required this.tipeAkun,
    required this.preferensiSeni,
    required this.tanggalLahir,
    required this.createdAt,
    this.cvUrl,
    this.portofolioUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      nama: map['nama'] ?? '',
      email: map['email'] ?? '',
      fotoUrl: map['fotoUrl'] ?? '',
      tipeAkun: map['tipeAkun'] ?? 'penonton',
      preferensiSeni: List<String>.from(map['preferensiSeni'] ?? []),
      tanggalLahir: map['tanggalLahir'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      cvUrl: map['cvUrl'] as String?,
      portofolioUrl: map['portofolioUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nama': nama,
      'email': email,
      'fotoUrl': fotoUrl,
      'tipeAkun': tipeAkun,
      'preferensiSeni': preferensiSeni,
      'tanggalLahir': tanggalLahir,
      'createdAt': createdAt,
      if (cvUrl != null) 'cvUrl': cvUrl,
      if (portofolioUrl != null) 'portofolioUrl': portofolioUrl,
    };
  }

  UserModel copyWith({
    String? uid,
    String? nama,
    String? email,
    String? fotoUrl,
    String? tipeAkun,
    List<String>? preferensiSeni,
    String? tanggalLahir,
    Timestamp? createdAt,
    String? cvUrl,
    String? portofolioUrl,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      tipeAkun: tipeAkun ?? this.tipeAkun,
      preferensiSeni: preferensiSeni ?? this.preferensiSeni,
      tanggalLahir: tanggalLahir ?? this.tanggalLahir,
      createdAt: createdAt ?? this.createdAt,
      cvUrl: cvUrl ?? this.cvUrl,
      portofolioUrl: portofolioUrl ?? this.portofolioUrl,
    );
  }
}