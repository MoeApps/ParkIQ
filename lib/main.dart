// lib/main.dart
//
// App entry point. Keep this file as small as possible —
// it just wires together the theme and the first screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait mode (makes sense for a parking app on phone)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Dark status bar icons on the dark background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:      Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ParkIQApp());
}

class ParkIQApp extends StatelessWidget {
  const ParkIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:        'ParkIQ',
      debugShowCheckedModeBanner: false, // hides the "debug" banner
      theme:        buildAppTheme(),
      home:         const LoginScreen(),
    );
  }
}
