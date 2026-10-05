import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'features/onboarding/onboarding_screen_1.dart';
import 'features/onboarding/onboarding_screen_2.dart';
import 'features/onboarding/onboarding_screen_3.dart';




Future<void> main() async {
  // Make sure Flutter is initialized before Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Start the application.
  runApp(const RoadRescueApp());
}

// ====================================================================
// ROADRESCUE APP
// ====================================================================

class RoadRescueApp extends StatelessWidget {
  const RoadRescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'RoadRescue',

      // ============================================================== 
      // THEME
      // ==============================================================

      theme: ThemeData(
        useMaterial3: true,

        scaffoldBackgroundColor: const Color(0xFF101214),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF6E900),
          brightness: Brightness.dark,
        ),
      ),

      // ============================================================== 
      // TEMPORARY GOOGLE MAP TEST
      // ==============================================================

      home: const OnboardingPage(),
    );
  }
}

// ====================================================================
// ONBOARDING PAGE
// ====================================================================

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  // ================================================================
  // PAGE CONTROLLER
  // ================================================================

  final PageController _pageController = PageController();

  // ================================================================
  // DISPOSE
  // ================================================================

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101214),

      body: PageView(
        controller: _pageController,

        children: const [
          OnboardingScreen1(),
          OnboardingScreen2(),
          OnboardingScreen3(),
        ],
      ),
    );
  }
}