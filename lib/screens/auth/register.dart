import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:indonesaku/services/auth_service.dart';
import '../../theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();

  // Step tracking
  int _currentStep = 1; // 1, 2, 3

  // Step 1 — tipe akun
  String _selectedTipeAkun = 'penonton';

  // Step 2 — form data diri
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _tanggalLahirController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  // Step 3 — preferensi seni
  final List<String> _allSeniOptions = [
    'Seni Teater',
    'Seni Perwayangan',
    'Seni Tari',
    'Seni Musik',
    'Seni Sastra',
    'Seni Rupa',
  ];
  final Set<String> _selectedPreferensi = {};

  bool _isLoading = false;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const Color _primaryColor = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _namaController.dispose();
    _tanggalLahirController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    _animController.reset();
    setState(() => _currentStep = step);
    _animController.forward();
  }

  void _handleStep1Next() {
    _goToStep(2);
  }

  void _handleStep2Next() {
    if (_formKey.currentState!.validate()) {
      // Seniman tidak perlu pilih preferensi — langsung daftar
      if (_selectedTipeAkun == 'seniman') {
        _handleRegister();
      } else {
        _goToStep(3);
      }
    }
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);

    try {
      await _authService.registerWithEmailAndPassword(
        nama: _namaController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        tipeAkun: _selectedTipeAkun,
        preferensiSeni: _selectedPreferensi.toList(),
        tanggalLahir: _tanggalLahirController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_authService.getErrorMessage(e.code));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickTanggalLahir() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 5),
      locale: const Locale('id', 'ID'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _tanggalLahirController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _buildCurrentStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  // ─────────────────────────────────────────────
  // STEP 1 — Pilih tipe akun
  // ─────────────────────────────────────────────
  Widget _buildStep1() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          children: [
            const SizedBox(height: 64),

            // Logo
            Center(
              child: Image.asset(
                'assets/images/IndoneSaku.png',
                height: 120,
                errorBuilder: (_, _, _) => _PlaceholderLogo(),
              ),
            ),

            const SizedBox(height: 44),

            // Pertanyaan
            const Text(
              'Kamu ingin mendaftar sebagai?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 20),

            // Toggle Penonton / Seniman
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TipeAkunChip(
                  label: 'Penonton',
                  isSelected: _selectedTipeAkun == 'penonton',
                  onTap: () => setState(() => _selectedTipeAkun = 'penonton'),
                ),
                const SizedBox(width: 16),
                _TipeAkunChip(
                  label: 'Seniman',
                  isSelected: _selectedTipeAkun == 'seniman',
                  onTap: () => setState(() => _selectedTipeAkun = 'seniman'),
                ),
              ],
            ),

            const SizedBox(height: 64),

            // Lanjutkan button
            _PrimaryButton(
              label: 'Lanjutkan',
              onPressed: _handleStep1Next,
            ),

            const SizedBox(height: 192),

            // Sudah punya akun
            _LoginLink(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STEP 2 — Form data diri
  // ─────────────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              // Tombol Back
              GestureDetector(
                onTap: () => _goToStep(1), // Kembali ke Step 1
                child: const SizedBox(
                  width: 24, // Lebar tetap
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: _primaryColor,
                  ),
                ),
              ),
              
              // Tulisan Daftar (di tengah)
              const Expanded(
                child: Text(
                  'Daftar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _primaryColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              
              // Kotak kosong penyeimbang agar judul presisi di tengah
              const SizedBox(width: 24),
            ],
          ),

          const SizedBox(height: 64),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama Lengkap
                _FieldLabel('Nama Lengkap'),
                const SizedBox(height: 8),
                _StyledTextField(
                  controller: _namaController,
                  hintText: 'Masukkan nama lengkap',
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    if (v.trim().length < 3) return 'Nama minimal 3 karakter';
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Tanggal Lahir
                _FieldLabel('Tanggal Lahir'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tanggalLahirController,
                  readOnly: true,
                  onTap: _pickTanggalLahir,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary),
                  decoration: _inputDecoration('DD/MM/YYYY').copyWith(
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF9E9E9E),
                      size: 18,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Tanggal lahir tidak boleh kosong';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Email
                _FieldLabel('Email'),
                const SizedBox(height: 8),
                _StyledTextField(
                  controller: _emailController,
                  hintText: 'Masukkan email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(v.trim())) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Kata Sandi
                _FieldLabel('Kata Sandi'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary),
                  decoration: _inputDecoration('••••••••').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Kata sandi tidak boleh kosong';
                    }
                    if (v.length < 8) {
                      return 'Kata sandi minimal 8 karakter';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          _PrimaryButton(
            label: 'Lanjutkan',
            onPressed: _isLoading ? null : _handleStep2Next,
            isLoading: _isLoading,
          ),

          const SizedBox(height: 28),
          _LoginLink(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STEP 3 — Pilih preferensi seni (Penonton only)
  // ─────────────────────────────────────────────
  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // App bar row
          Row(
            children: [
              // Tombol Back
              GestureDetector(
                onTap: () => _goToStep(2), // Kembali ke Step 2
                child: const SizedBox(
                  width: 24, // Lebar tetap
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: _primaryColor,
                  ),
                ),
              ),
              
              // Tulisan Daftar (di tengah)
              const Expanded(
                child: Text(
                  'Pilih Pertunjukan yang Kamu Sukai',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _primaryColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              
              // Kotak kosong penyeimbang agar judul presisi di tengah
              const SizedBox(width: 24),
            ],
          ),

          const SizedBox(height: 56),

          // Seni chips — bisa multi-select
          Expanded(
            child: ListView.separated(
              itemCount: _allSeniOptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final seni = _allSeniOptions[index];
                final isSelected = _selectedPreferensi.contains(seni);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedPreferensi.remove(seni);
                      } else {
                        _selectedPreferensi.add(seni);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _primaryColor.withValues(alpha:0.12)
                          : AppColors.inputFill,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected
                            ? _primaryColor
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      seni,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? _primaryColor
                            : const Color(0xFF555555),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          _PrimaryButton(
            label: 'Lanjutkan',
            onPressed: _isLoading ? null : _handleRegister,
            isLoading: _isLoading,
          ),

          const SizedBox(height: 56),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
    filled: true,
    fillColor: AppColors.inputFill,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  const _StyledTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: _inputDecoration(hintText),
      validator: validator,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF444444),
      ),
    );
  }
}

class _TipeAkunChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TipeAkunChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  static const Color _primaryColor = AppColors.primary;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primaryColor.withValues(alpha:0.6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _LoginLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Sudah punya akun?  ',
          style: TextStyle(color: Color(0xFF888888), fontSize: 14),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
          child: const Text(
            'Masuk',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'Indone',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary),
          ),
          TextSpan(
            text: 'Saku',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}