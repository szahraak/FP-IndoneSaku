import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pertunjukan.dart';
import '../services/pertunjukan_service.dart';
import '../services/cloudinary_service.dart';
import 'location_picker_screen.dart';
import '../theme/app_colors.dart';

class CreateEditShowScreen extends StatefulWidget {
  /// Pass an existing [Pertunjukan] to edit it; null = create new.
  final Pertunjukan? existing;

  const CreateEditShowScreen({super.key, this.existing});

  @override
  State<CreateEditShowScreen> createState() => _CreateEditShowScreenState();
}

class _CreateEditShowScreenState extends State<CreateEditShowScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _judulCtrl;
  late final TextEditingController _deskripsiCtrl;
  late final TextEditingController _kotaCtrl;
  late final TextEditingController _hargaCtrl;
  late final TextEditingController _stokCtrl;

  // State
  String _selectedKategori = 'Tari';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LocationResult? _selectedLocation;
  File? _posterFile;
  File? _videoFile;
  String? _existingPosterUrl;
  String? _existingVideoUrl;

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
    _hargaCtrl = TextEditingController(text: e?.harga.toString() ?? '');
    _stokCtrl = TextEditingController(text: e?.stokTiket.toString() ?? '');

    if (e != null) {
      _selectedKategori = e.kategori;
      _selectedDate = e.tanggalDateTime;
      _selectedTime = TimeOfDay.fromDateTime(e.tanggalDateTime);
      _existingPosterUrl = e.posterUrl;
      _existingVideoUrl = e.videoTeaserUrl;
    }
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _deskripsiCtrl.dispose();
    _kotaCtrl.dispose();
    _hargaCtrl.dispose();
    _stokCtrl.dispose();
    super.dispose();
  }

  // ── Media pickers ──────────────────────────────────────────────────────────
  Future<void> _pickPoster() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (xFile != null) {
      setState(() => _posterFile = File(xFile.path));
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final xFile = await picker.pickVideo(source: ImageSource.gallery);
    if (xFile != null) {
      setState(() => _videoFile = File(xFile.path));
    }
  }

  // ── Date/time pickers ─────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 19, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Location picker ────────────────────────────────────────────────────────
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedLocation = result;
        // Auto-fill kota from the last part of the description
        final parts = result.description.split(', ');
        if (parts.length >= 2) {
          _kotaCtrl.text = parts[parts.length - 2]; // city before country
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

    setState(() {
      _isLoading = true;
      _uploadStatus = 'Menyiapkan...';
    });

    try {
      // Build Timestamp from picked date + time
      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      final tanggal = Timestamp.fromDate(dt);

      // Upload poster if new file selected
      String posterUrl = _existingPosterUrl ?? '';
      if (_posterFile != null) {
        setState(() => _uploadStatus = 'Mengunggah poster...');
        posterUrl = await CloudinaryService.uploadPoster(_posterFile!);
      }

      // Upload video teaser if provided
      String? videoUrl = _existingVideoUrl;
      if (_videoFile != null) {
        setState(() => _uploadStatus = 'Mengunggah video teaser...');
        videoUrl = await CloudinaryService.uploadVideoTeaser(_videoFile!);
      }

      // Build GeoPoint if location was selected
      final GeoPoint? lokasi = _selectedLocation?.toGeoPoint() ??
          (widget.existing?.lokasi);

      setState(() => _uploadStatus = 'Menyimpan data...');

      if (_isEditing) {
        await PertunjukanService.update(
          widget.existing!.id,
          judul: _judulCtrl.text.trim(),
          deskripsi: _deskripsiCtrl.text.trim(),
          posterUrl: posterUrl,
          videoTeaserUrl: videoUrl,
          kategori: _selectedKategori,
          kota: _kotaCtrl.text.trim(),
          lokasi: lokasi,
          tanggal: tanggal,
          harga: num.tryParse(_hargaCtrl.text) ?? 0,
          stokTiket: num.tryParse(_stokCtrl.text) ?? 0,
        );
        if (mounted) {
          _showSnack('Pertunjukan berhasil diperbarui!');
          Navigator.pop(context, true);
        }
      } else {
        await PertunjukanService.create(
          judul: _judulCtrl.text.trim(),
          deskripsi: _deskripsiCtrl.text.trim(),
          posterUrl: posterUrl,
          videoTeaserUrl: videoUrl,
          kategori: _selectedKategori,
          kota: _kotaCtrl.text.trim(),
          lokasi: lokasi,
          tanggal: tanggal,
          harga: num.tryParse(_hargaCtrl.text) ?? 0,
          stokTiket: num.tryParse(_stokCtrl.text) ?? 0,
        );
        if (mounted) {
          _showSnack('Pertunjukan berhasil dibuat!');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AppColors.primary,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Edit Pertunjukan' : 'Buat Pertunjukan',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingOverlay()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Poster upload ──────────────────────────────────────
                    _sectionTitle('Poster Pertunjukan *'),
                    const SizedBox(height: 10),
                    _buildPosterPicker(),
                    const SizedBox(height: 24),

                    // ── Basic info ─────────────────────────────────────────
                    _sectionTitle('Informasi Dasar'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _judulCtrl,
                      label: 'Judul Pertunjukan',
                      hint: 'Contoh: Pentas Tari Remo Surabaya',
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Judul wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _deskripsiCtrl,
                      label: 'Deskripsi',
                      hint: 'Ceritakan tentang pertunjukan ini...',
                      maxLines: 4,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Deskripsi wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // ── Date & time ────────────────────────────────────────
                    _sectionTitle('Jadwal Pertunjukan *'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPickerButton(
                            icon: Icons.calendar_today_outlined,
                            label: _selectedDate == null
                                ? 'Pilih Tanggal'
                                : _formatDate(_selectedDate!),
                            onTap: _pickDate,
                            hasValue: _selectedDate != null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPickerButton(
                            icon: Icons.access_time_outlined,
                            label: _selectedTime == null
                                ? 'Pilih Jam'
                                : _selectedTime!.format(context),
                            onTap: _pickTime,
                            hasValue: _selectedTime != null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Location ───────────────────────────────────────────
                    _sectionTitle('Lokasi Pertunjukan'),
                    const SizedBox(height: 12),
                    _buildPickerButton(
                      icon: Icons.location_on_outlined,
                      label: _selectedLocation?.description ??
                          (widget.existing?.kota.isNotEmpty == true
                              ? widget.existing!.kota
                              : 'Pilih Lokasi via Google Maps'),
                      onTap: _openLocationPicker,
                      hasValue: _selectedLocation != null ||
                          widget.existing?.lokasi != null,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _kotaCtrl,
                      label: 'Kota',
                      hint: 'Contoh: Surabaya',
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Kota wajib diisi' : null,
                    ),
                    const SizedBox(height: 24),

                    // ── Ticket ─────────────────────────────────────────────
                    _sectionTitle('Tiket'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _hargaCtrl,
                            label: 'Harga (Rp)',
                            hint: '0 = Gratis',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _stokCtrl,
                            label: 'Stok Tiket',
                            hint: '100',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Stok wajib diisi'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Video teaser (optional) ────────────────────────────
                    _sectionTitle('Video Teaser (Opsional)'),
                    const SizedBox(height: 10),
                    _buildVideoPicker(),
                    const SizedBox(height: 36),

                    // ── Submit button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _submit,
                        child: Text(
                          _isEditing
                              ? 'Simpan Perubahan'
                              : 'Publikasikan Pertunjukan',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle:
            TextStyle(color: AppColors.textSecondary.withAlpha((0.6 * 255).round())),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedKategori,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Kategori',
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: _categories
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedKategori = v);
      },
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool hasValue = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: hasValue
              ? AppColors.primary.withAlpha((0.05 * 255).round())
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: hasValue ? AppColors.primary : AppColors.textSecondary,
                size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasValue
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight:
                      hasValue ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPicker() {
    final hasPoster = _posterFile != null || _existingPosterUrl != null;

    return GestureDetector(
      onTap: _pickPoster,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasPoster
              ? Colors.transparent
              : AppColors.secondary.withAlpha((0.05 * 255).round()),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasPoster ? AppColors.primary : AppColors.divider,
            width: hasPoster ? 2 : 1,
            style:
                hasPoster ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: _posterFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_posterFile!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _pickPoster,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _existingPosterUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(_existingPosterUrl!, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _pickPoster,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary.withAlpha((0.1 * 255).round()),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tambahkan Poster Pertunjukan',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ketuk untuk memilih gambar dari galeri',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildVideoPicker() {
    final hasVideo = _videoFile != null || _existingVideoUrl != null;

    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: hasVideo
              ? AppColors.primary.withAlpha((0.05 * 255).round())
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasVideo ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasVideo
                    ? Icons.videocam
                    : Icons.video_camera_back_outlined,
                color: hasVideo
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasVideo
                        ? (_videoFile != null
                            ? 'Video dipilih: ${_videoFile!.path.split('/').last}'
                            : 'Video teaser sudah ada')
                        : 'Tambahkan Video Teaser',
                    style: TextStyle(
                      color: hasVideo
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!hasVideo)
                    const Text(
                      'Format MP4, maks. 50MB',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (hasVideo)
              TextButton(
                onPressed: _pickVideo,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary),
                child: const Text('Ganti'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            _uploadStatus ?? 'Memproses...',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}
