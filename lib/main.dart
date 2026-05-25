import 'package:carnitrack2/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:carnitrack2/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Asegura que Flutter esté listo antes de cualquier plugin nativo
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await NotificationService.initialize();
 await NotificationService.requestPermissions();
  // 2. Inicializa Firebase (esto debe ser await)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ColdTrackApp());
}

class ColdTrackApp extends StatelessWidget {
  const ColdTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ColdTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF941C2F), // rojo burdeos para botones
        appBarTheme: const AppBarTheme(elevation: 0),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF941C2F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
