import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pertunjukan.dart';
import '../../models/tiket.dart';
import '../../services/pertunjukan_service.dart';
import '../../services/cloudinary_service.dart';
import 'location_picker_screen.dart';
import '../../theme/app_colors.dart';

class CreateEditShowScreen extends StatefulWidget {
  final Pertunjukan? existing;
  const CreateEditShowScreen({super.key, this.existing});

  @override
  State<CreateEditShowScreen> createState() => _CreateEditShowScreenState();
}

class _CreateEditShowScreenState extends State<CreateEditShowScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _judulCtrl;
  late final TextEditingController _deskripsiCtrl;
  late final TextEditingController _kotaCtrl;

  String _selectedKategori = 'Tari';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LocationResult? _selectedLocation;
  File? _posterFile;
  File? _videoFile;
  String? _existingPosterUrl;
  String? _existingVideoUrl;

  List<JenisTiket> _daftarTiket = []; // STATE UNTUK MULTI-TIKET

  bool _isLoading = false;
  String? _uploadStatus;
  bool get _isEditing => widget.existing != null;

  final List<String> _categories = [
    'Tari', 'Gamelan', 'Wayang', 'Musik', 'Ludruk', 'Ketoprak',
    'Reog', 'Lenong', 'Kecak', 'Angklung', 'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _judulCtrl = TextEditingController(text: e?.judul ?? '');
    _deskripsiCtrl = TextEditingController(text: e?.deskripsi ?? '');
    _kotaCtrl = TextEditingController(text: e?.kota ?? '');

    if (e != null) {
      _selectedKategori = e.kategori;
      _selectedDate = e.tanggalDateTime;
      _selectedTime = TimeOfDay.fromDateTime(e.tanggalDateTime);
      _existingPosterUrl = e.posterUrl;
      _existingVideoUrl = e.videoTeaserUrl;
      _daftarTiket = List.from(e.daftarTiket); // Salin tiket yang sudah ada
    }
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _deskripsiCtrl.dispose();
    _kotaCtrl.dispose();
    super.dispose();
  }

  // ── DIALOG TAMBAH/EDIT TIKET ────────────────────────────────────────────────
  Future<void> _tambahAtauEditJenisTiket({int? editIndex}) async {
    final namaCtrl = TextEditingController();
    final hargaCtrl = TextEditingController();
    final stokCtrl = TextEditingController();
    final deskripsiCtrl = TextEditingController();

    if (editIndex != null) {
      final tiket = _daftarTiket[editIndex];
      namaCtrl.text = tiket.nama;
      
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
      hargaCtrl.text = formatter.format(tiket.harga).trim();
      
      stokCtrl.text = formatter.format(tiket.stok).trim();
      
      deskripsiCtrl.text = tiket.deskripsi ?? '';
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(editIndex == null ? 'Tambah Jenis Tiket' : 'Edit Jenis Tiket', 
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(controller: namaCtrl, label: 'Nama (cth: VIP, Reguler)'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: hargaCtrl, 
                  label: 'Harga (Rp)', 
                  hint: '0 untuk gratis',
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumberInputFormatter()], 
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: stokCtrl, 
                  label: 'Kuota/Stok Tiket',
                  keyboardType: TextInputType.number,
                  inputFormatters: [NumberInputFormatter()], 
                ),
                const SizedBox(height: 10),
                _buildTextField(controller: deskripsiCtrl, label: 'Deskripsi singkat (Opsional)', maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              if (namaCtrl.text.isNotEmpty && hargaCtrl.text.isNotEmpty && stokCtrl.text.isNotEmpty) {
                final hargaBersih = hargaCtrl.text.replaceAll('.', '');
                final stokBersih = stokCtrl.text.replaceAll('.', '');

                setState(() {
                  final tiketBaru = JenisTiket(
                    id: editIndex == null 
                        ? DateTime.now().millisecondsSinceEpoch.toString() 
                        : _daftarTiket[editIndex].id, 
                    nama: namaCtrl.text.trim(),
                    harga: double.tryParse(hargaBersih) ?? 0, 
                    stok: int.tryParse(stokBersih) ?? 0,
                    deskripsi: deskripsiCtrl.text.isEmpty ? null : deskripsiCtrl.text.trim(),
                  );

                  if (editIndex == null) {
                    _daftarTiket.add(tiketBaru); 
                  } else {
                    _daftarTiket[editIndex] = tiketBaru; 
                  }
                });
                Navigator.pop(context);
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lengkapi nama, harga, dan stok')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── Media & Location pickers ───────────────────────────────────────────────
  Future<void> _pickPoster() async {
    final xFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xFile != null) setState(() => _posterFile = File(xFile.path));
  }

  Future<void> _pickVideo() async {
    final xFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (xFile != null) setState(() => _videoFile = File(xFile.path));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context, initialTime: _selectedTime ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationResult>(
      context, MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedLocation = result;

        if (result.cityName.isNotEmpty) {
          _kotaCtrl.text = result.cityName;
        } else {
          final parts = result.description.split(', ');
          if (parts.length >= 3) {
            _kotaCtrl.text = parts[parts.length - 3].replaceFirst('Kota ', '');
          } else if (parts.length >= 2) {
            _kotaCtrl.text = parts[parts.length - 2].replaceFirst('Kota ', '');
          }
        }
      });
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      _showSnack('Pilih tanggal dan waktu pertunjukan', error: true);
      return;
    }
    if (_posterFile == null && _existingPosterUrl == null) {
      _showSnack('Upload poster pertunjukan terlebih dahulu', error: true);
      return;
    }
    // VALIDASI TIKET
    if (_daftarTiket.isEmpty) {
      _showSnack('Minimal tambahkan 1 jenis tiket (misal: Reguler)', error: true);
      return;
    }

    setState(() { _isLoading = true; _uploadStatus = 'Menyiapkan...'; });

    try {
      final dt = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      final tanggal = Timestamp.fromDate(dt);

      String posterUrl = _existingPosterUrl ?? '';
      if (_posterFile != null) {
        setState(() => _uploadStatus = 'Mengunggah poster...');
        posterUrl = await CloudinaryService.uploadPoster(_posterFile!);
      }

      String? videoUrl = _existingVideoUrl;
      if (_videoFile != null) {
        setState(() => _uploadStatus = 'Mengunggah video...');
        videoUrl = await CloudinaryService.uploadVideoTeaser(_videoFile!);
      }

      final GeoPoint? lokasi = _selectedLocation?.toGeoPoint() ?? widget.existing?.lokasi;
      setState(() => _uploadStatus = 'Menyimpan data...');

      if (_isEditing) {
        await PertunjukanService.update(
          widget.existing!.id,
          judul: _judulCtrl.text.trim(), deskripsi: _deskripsiCtrl.text.trim(),
          posterUrl: posterUrl, videoTeaserUrl: videoUrl,
          kategori: _selectedKategori, kota: _kotaCtrl.text.trim(),
          lokasi: lokasi, tanggal: tanggal,
          daftarTiket: _daftarTiket, // Kirim list tiket
        );
        if (mounted) { _showSnack('Pertunjukan diperbarui!'); Navigator.pop(context, true); }
      } else {
        await PertunjukanService.create(
          judul: _judulCtrl.text.trim(), deskripsi: _deskripsiCtrl.text.trim(),
          posterUrl: posterUrl, videoTeaserUrl: videoUrl,
          kategori: _selectedKategori, kota: _kotaCtrl.text.trim(),
          lokasi: lokasi, tanggal: tanggal,
          daftarTiket: _daftarTiket, // Kirim list tiket
        );
        if (mounted) { _showSnack('Pertunjukan diterbitkan!'); Navigator.pop(context, true); }
      }
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : AppColors.primary));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary, foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit Pertunjukan' : 'Buat Pertunjukan', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: _isLoading ? _buildLoadingOverlay() : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Poster Pertunjukan *'), const SizedBox(height: 10), _buildPosterPicker(), const SizedBox(height: 24),
              
              _sectionTitle('Informasi Dasar'), const SizedBox(height: 12),
              _buildTextField(controller: _judulCtrl, label: 'Judul Pertunjukan', validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null), const SizedBox(height: 14),
              _buildDropdown(), const SizedBox(height: 14),
              _buildTextField(controller: _deskripsiCtrl, label: 'Deskripsi', maxLines: 4, validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null), const SizedBox(height: 24),
              
              _sectionTitle('Jadwal Pertunjukan *'), const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildPickerButton(icon: Icons.calendar_today, label: _selectedDate == null ? 'Pilih Tanggal' : _formatDate(_selectedDate!), onTap: _pickDate, hasValue: _selectedDate != null)), const SizedBox(width: 12),
                Expanded(child: _buildPickerButton(icon: Icons.access_time, label: _selectedTime == null ? 'Pilih Jam' : _selectedTime!.format(context), onTap: _pickTime, hasValue: _selectedTime != null)),
              ]), const SizedBox(height: 24),

              _sectionTitle('Lokasi Pertunjukan'), const SizedBox(height: 12),
              _buildPickerButton(icon: Icons.location_on_outlined, label: _selectedLocation?.description ?? (widget.existing?.kota.isNotEmpty == true ? widget.existing!.kota : 'Pilih Lokasi via Maps'), onTap: _openLocationPicker, hasValue: _selectedLocation != null || widget.existing?.lokasi != null), const SizedBox(height: 14),
              _buildTextField(controller: _kotaCtrl, label: 'Kota (cth: Surabaya)', validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null), const SizedBox(height: 24),

              // ── BAGIAN TIKET (DIPERBARUI) ──
              _sectionTitle('Jenis Tiket *'), const SizedBox(height: 12),
              if (_daftarTiket.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Belum ada tiket. Pembeli tidak akan bisa memesan!', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ..._daftarTiket.asMap().entries.map((entry) {
                final index = entry.key;
                final tiket = entry.value;
                
                final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
                
                return Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.divider)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(tiket.nama, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    subtitle: Text('${formatter.format(tiket.harga)} • Kuota: ${tiket.stok}', style: const TextStyle(color: AppColors.textSecondary)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                          onPressed: () => _tambahAtauEditJenisTiket(editIndex: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => setState(() => _daftarTiket.removeAt(index)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () => _tambahAtauEditJenisTiket(), 
                icon: const Icon(Icons.add), label: const Text('Tambah Kelas Tiket'),
              ),
              const SizedBox(height: 24),

              _sectionTitle('Video Teaser (Opsional)'), const SizedBox(height: 10), _buildVideoPicker(), const SizedBox(height: 36),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _submit, child: Text(_isEditing ? 'Simpan Perubahan' : 'Publikasikan Pertunjukan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ), const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widgets (tetap sama)
  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700));
  Widget _buildTextField({required TextEditingController controller, required String label, String? hint, int maxLines = 1, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator}) {
    return TextFormField(controller: controller, maxLines: maxLines, keyboardType: keyboardType, inputFormatters: inputFormatters, validator: validator, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14), decoration: InputDecoration(labelText: label, hintText: hint, labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)));
  }
  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedKategori, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(labelText: 'Kategori', filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) { if (v != null) setState(() => _selectedKategori = v); },
    );
  }
  Widget _buildPickerButton({required IconData icon, required String label, required VoidCallback onTap, bool hasValue = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: hasValue ? AppColors.primary.withAlpha((0.05 * 255).round()) : AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: hasValue ? AppColors.primary : AppColors.divider)),
        child: Row(children: [Icon(icon, color: hasValue ? AppColors.primary : AppColors.textSecondary, size: 18), const SizedBox(width: 8), Expanded(child: Text(label, style: TextStyle(color: hasValue ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 13, fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal), overflow: TextOverflow.ellipsis))]),
      ),
    );
  }
  Widget _buildPosterPicker() { /* Logic yang sama persis seperti file asli kamu (hanya memendekkan di preview ini) */ return GestureDetector(onTap: _pickPoster, child: Container(height: 180, width: double.infinity, decoration: BoxDecoration(color: _posterFile != null || _existingPosterUrl != null ? Colors.transparent : AppColors.secondary.withAlpha(12), borderRadius: BorderRadius.circular(14), border: Border.all(color: _posterFile != null || _existingPosterUrl != null ? AppColors.primary : AppColors.divider)), child: _posterFile != null ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(_posterFile!, fit: BoxFit.cover)) : _existingPosterUrl != null ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.network(_existingPosterUrl!, fit: BoxFit.cover)) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28), SizedBox(height: 10), Text('Tambahkan Poster', style: TextStyle(fontWeight: FontWeight.w600))]))); }
  Widget _buildVideoPicker() { /* Logic yang sama persis seperti file asli */ return GestureDetector(onTap: _pickVideo, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)), child: Row(children: [const Icon(Icons.video_camera_back_outlined), const SizedBox(width: 12), const Expanded(child: Text('Tambahkan Video Teaser'))]))); }
  Widget _buildLoadingOverlay() { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(color: AppColors.primary), const SizedBox(height: 20), Text(_uploadStatus ?? 'Memproses...')])); }
  String _formatDate(DateTime d) { const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des']; return '${d.day} ${months[d.month]} ${d.year}'; }
}

// ── FORMATTER UANG ──────────────────────────────────────────
class NumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hanya ambil karakter angka
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final int value = int.parse(digitsOnly);

    // Format dengan pemisah ribuan titik bergaya Indonesia
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    String newText = formatter.format(value).trim();

    return newValue.copyWith(
      text: newText,
      // Letakkan kursor di akhir teks yang baru
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}