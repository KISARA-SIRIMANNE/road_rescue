import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'features/onboarding/onboarding_screen_1.dart';
import 'features/onboarding/onboarding_screen_2.dart';
import 'features/onboarding/onboarding_screen_3.dart';
import 'services/notification_service.dart';
Future<void> main() async {
  // Make sure Flutter is initialized before Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.instance.initialize();

  // Start the application.
  runApp(const RoadRescueApp());
}

// ====================================================================
// ROADRESCUE APP
// ====================================================================

class RoadRescueApp extends StatelessWidget {
  const RoadRescueApp({super.key});

  static const Color _backgroundColor = Color(0xFF05090B);
  static const Color _surfaceColor = Color(0xFF11181C);
  static const Color _elevatedSurfaceColor = Color(0xFF151D21);
  static const Color _accentColor = Color(0xFFFFD21F);
  static const Color _secondaryTextColor = Color(0xFFA5ADB3);

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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _backgroundColor,
        canvasColor: _backgroundColor,
        cardColor: _surfaceColor,
        dividerColor: Colors.white.withValues(alpha: 0.08),
        colorScheme: const ColorScheme.dark(
          primary: _accentColor,
          onPrimary: _backgroundColor,
          secondary: _accentColor,
          onSecondary: _backgroundColor,
          surface: _surfaceColor,
          onSurface: Colors.white,
          error: Color(0xFFFF5555),
          onError: Colors.white,
          outline: Color(0x1AFFFFFF),
          outlineVariant: Color(0x12FFFFFF),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: _secondaryTextColor),
          bodySmall: TextStyle(color: _secondaryTextColor),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _backgroundColor,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: _surfaceColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _elevatedSurfaceColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF6F787F),
            fontWeight: FontWeight.w400,
          ),
          labelStyle: const TextStyle(color: _secondaryTextColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _accentColor, width: 1.3),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFFF5555)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: _backgroundColor,
            disabledBackgroundColor: _accentColor.withValues(alpha: 0.35),
            disabledForegroundColor: _backgroundColor.withValues(alpha: 0.55),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _accentColor,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _accentColor,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _surfaceColor,
          surfaceTintColor: Colors.transparent,
          indicatorColor: _accentColor.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? _accentColor
                  : _secondaryTextColor,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w400,
              fontSize: 11,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _surfaceColor,
          selectedColor: _accentColor,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          labelStyle: const TextStyle(color: _secondaryTextColor),
          secondaryLabelStyle: const TextStyle(
            color: _backgroundColor,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _accentColor,
          linearTrackColor: Color(0xFF263036),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _surfaceColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: _surfaceColor,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: _surfaceColor,
          showDragHandle: true,
          dragHandleColor: Color(0xFF4D555A),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _elevatedSurfaceColor,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
      backgroundColor: const Color(0xFF05090B),

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
