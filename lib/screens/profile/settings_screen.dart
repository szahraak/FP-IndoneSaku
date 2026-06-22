import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  final _namaController = TextEditingController();
  final _asalController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Pisahkan controller untuk password lama dan baru
  final _oldPasswordController = TextEditingController(); 
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingPic = false;
  String _fotoUrl = '';
  String _tipeAkun = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _asalController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _namaController.text = data['nama'] ?? '';
          _asalController.text = data['asal'] ?? ''; 
          _emailController.text = user.email ?? data['email'] ?? '';
          _fotoUrl = data['fotoUrl'] ?? '';
          _tipeAkun = data['tipeAkun'] ?? 'penonton';
        });
      }
    } catch (e) {
      debugPrint("Gagal memuat data: $e");
    }
  }

  // ── FUNGSI GANTI FOTO PROFIL ──────────────────────────────────────────
  Future<void> _gantiFotoProfil() async {
    final picker = ImagePicker();
    
    // 1. Pilih gambar dari galeri
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return; // Batal memilih gambar

    // 2. Tampilkan UI Cropper (Pemotong Gambar)
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Kunci rasio 1:1 untuk CircleAvatar
      maxWidth: 800, // Kompres ukuran setelah di-crop
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Sesuaikan Foto',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Sesuaikan Foto',
          aspectRatioLockEnabled: true, // Kunci rasio di iOS
          resetButtonHidden: true,
        ),
      ],
    );

    if (croppedFile == null) return; // Pengguna membatalkan proses crop

    // Mulai animasi loading di avatar
    setState(() => _isUploadingPic = true);

    try {
      // Gunakan file hasil crop untuk diupload
      final File imageFile = File(croppedFile.path);
      
      // Simpan URL foto lama untuk dihapus nanti
      final oldFotoUrl = _fotoUrl;

      // Upload gambar baru ke Cloudinary
      final newFotoUrl = await CloudinaryService.uploadProfilePicture(imageFile);

      // Update Firestore dan Auth PhotoURL
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fotoUrl': newFotoUrl,
        });
        if (_tipeAkun == 'seniman') {
          await FirebaseFirestore.instance.collection('seniman').doc(user.uid).update({
            'fotoUrl': newFotoUrl,
          });
        }
        await user.updatePhotoURL(newFotoUrl);
      }

      // Update UI
      setState(() {
        _fotoUrl = newFotoUrl;
      });

      // Hapus foto lama di Cloudinary secara asinkronus (di background)
      if (oldFotoUrl.isNotEmpty && oldFotoUrl.contains('cloudinary.com')) {
        FirebaseFunctions.instanceFor(region: 'asia-southeast2')
            .httpsCallable('deleteMediaCloudinary')
            .call({'url': oldFotoUrl, 'resourceType': 'image'})
            .then((_) => debugPrint('Foto lama berhasil dihapus dari Cloudinary'))
            .catchError((e) => debugPrint('Gagal menghapus foto lama: $e'));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Gagal mengganti foto: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPic = false);
    }
  }

  // ── Fungsi Simpan Perubahan ──────────────────────────────────────────
  Future<void> _simpanPerubahan() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Update ke Firestore (Nama dan Asal)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'nama': _namaController.text.trim(),
        'asal': _asalController.text.trim(),
      });

      if (_tipeAkun == 'seniman') {
        await FirebaseFirestore.instance.collection('seniman').doc(user.uid).update({
          'nama': _namaController.text.trim(),
        });
      }

      // 2. Update Display Name di Auth
      await user.updateDisplayName(_namaController.text.trim());

      // 3. Update Email (Jika berubah)
      if (_emailController.text.trim().isNotEmpty && _emailController.text.trim() != user.email) {
        await user.verifyBeforeUpdateEmail(_emailController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link verifikasi email telah dikirim ke email baru Anda.')),
          );
        }
      }

      // 4. Update Password (Menggunakan otentikasi ulang)
      final oldPass = _oldPasswordController.text;
      final newPass = _newPasswordController.text;

      if (oldPass.isNotEmpty || newPass.isNotEmpty) {
        // Validasi pengisian form
        if (oldPass.isEmpty) {
          throw Exception("Password lama harus diisi untuk mengubah password.");
        }
        if (newPass.isEmpty) {
          throw Exception("Password baru harus diisi.");
        }
        if (newPass.length < 8) {
          throw Exception("Password baru harus minimal 8 karakter.");
        }

        try {
          // Lakukan re-autentikasi agar Firebase yakin ini benar-benar pemilik akun
          final credential = EmailAuthProvider.credential(
            email: user.email!, 
            password: oldPass,
          );
          await user.reauthenticateWithCredential(credential);

          // Jika berhasil re-auth, update password ke yang baru
          await user.updatePassword(newPass);
          
          // Kosongkan kolom password setelah berhasil
          _oldPasswordController.clear();
          _newPasswordController.clear();

        } on FirebaseAuthException catch (e) {
          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
            throw Exception("Password lama yang Anda masukkan salah.");
          } else {
            rethrow; // Lemparkan error lain ke blok catch utama
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context); // Kembali ke halaman sebelumnya

    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showErrorSnackBar('Sesi Anda sudah terlalu lama. Silakan logout dan login kembali untuk mengubah kredensial penting (Email).');
      } else {
        _showErrorSnackBar('Gagal memperbarui profil: ${e.message}');
      }
    } catch (e) {
      // Menangkap Exception buatan sendiri (validasi form)
      _showErrorSnackBar(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Fungsi Logout ────────────────────────────────────────────────────
  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Akun?'),
        content: const Text('Apakah kamu yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AuthService().signOut();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Gagal keluar: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengaturan',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _simpanPerubahan,
              child: const Text('Simpan', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Foto Profil
            Center(
              child: GestureDetector(
                onTap: _isUploadingPic ? null : _gantiFotoProfil,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _fotoUrl.isNotEmpty ? NetworkImage(_fotoUrl) : null,
                      child: _isUploadingPic
                          ? const CircularProgressIndicator(color: AppColors.primary)
                          : (_fotoUrl.isEmpty
                              ? const Icon(Icons.person, size: 50, color: Colors.grey)
                              : null),
                    ),
                    if (!_isUploadingPic)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2), // Tambah border putih agar icon menonjol
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Form Inputs 
            _buildInputField('Name', _namaController),
            _buildInputField('Asal', _asalController),
            _buildInputField('Email', _emailController, keyboardType: TextInputType.emailAddress),
            
            // Perubahan: Menambahkan dua form input password
            _buildInputField('Pass Lama', _oldPasswordController, isPassword: true, hint: 'Kosongkan jika tak diubah'),
            _buildInputField('Pass Baru', _newPasswordController, isPassword: true, hint: 'Minimal 8 karakter'),

            const SizedBox(height: 48),

            // Tombol Keluar Merah
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC01126), 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Keluar',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Helper Widget
  Widget _buildInputField(String label, TextEditingController controller, {bool isPassword = false, String? hint, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100, 
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword,
              keyboardType: keyboardType,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}