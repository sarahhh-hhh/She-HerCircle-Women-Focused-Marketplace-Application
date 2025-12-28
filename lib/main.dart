import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:she_her_circle/screens/auth_landing_screen.dart';
import 'package:she_her_circle/theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SheHerCircleApp());
}

class SheHerCircleApp extends StatelessWidget {
  const SheHerCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'She&HerCircle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthLandingScreen(),
    );
  }
}
