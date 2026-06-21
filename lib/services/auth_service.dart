import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:indonesaku/models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Register new user with email and password
  /// Stores user data to Firestore based on UserModel (class diagram)
  Future<UserCredential> registerWithEmailAndPassword({
    required String nama,
    required String email,
    required String password,
    required String tipeAkun, // 'penonton' | 'seniman'
    required List<String> preferensiSeni,
    required String tanggalLahir, // format DD/MM/YYYY
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update display name
    await credential.user?.updateDisplayName(nama);

    // Save to Firestore - matches UserModel class diagram
    final userModel = UserModel(
      uid: credential.user!.uid,
      nama: nama,
      email: email,
      fotoUrl: '',
      tipeAkun: tipeAkun,
      preferensiSeni: preferensiSeni,
      tanggalLahir: tanggalLahir,
      createdAt: Timestamp.now(),
    );

    await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .set(userModel.toMap());

    return credential;
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Centralized Firebase Auth error messages (Bahasa Indonesia)
  String getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Akun tidak ditemukan. Periksa email kamu.';
      case 'wrong-password':
        return 'Password salah. Silakan coba lagi.';
      case 'invalid-credential':
        return 'Email atau password tidak valid.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan masuk atau gunakan email lain.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 8 karakter.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun kamu telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba beberapa saat lagi.';
      case 'network-request-failed':
        return 'Gagal terhubung ke jaringan. Periksa koneksi internet kamu.';
      default:
        return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }

  /// Get current user data from Firestore
  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}