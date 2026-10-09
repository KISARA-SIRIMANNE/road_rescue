import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'features/onboarding/onboarding_screen_1.dart';
import 'features/onboarding/onboarding_screen_2.dart';
import 'features/onboarding/onboarding_screen_3.dart';
import 'services/notification_service.dart';
import 'theme/road_rescue_theme.dart';

Future<void> main() async {
  // Make sure Flutter is initialized before Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.instance.initialize();

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

      theme: RoadRescueTheme.dark,

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
      backgroundColor: RoadRescueColors.background,

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