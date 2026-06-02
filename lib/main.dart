import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Try to sign in anonymously, but don't crash if it fails
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('⚠️ Anonymous auth failed (non-fatal): $e');
      // Continue anyway - app can work with anonymous/no auth
    }
  }
  
  await initializeDateFormatting('id_ID', null);
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
  runApp(const IndoneSakuApp());
}

class IndoneSakuApp extends StatefulWidget {
  const IndoneSakuApp({super.key});

  @override
  State<IndoneSakuApp> createState() => _IndoneSakuAppState();
}

class _IndoneSakuAppState extends State<IndoneSakuApp> {
  Timer? _rehideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
      if (systemOverlaysAreVisible) {
        _rehideTimer?.cancel();
        _rehideTimer = Timer(const Duration(seconds: 3), () {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: [SystemUiOverlay.top],
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _rehideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IndoneSaku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB5451B),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        brightness: Brightness.light,
      ),
      home: const MainScaffold(),
    );
  }
}
