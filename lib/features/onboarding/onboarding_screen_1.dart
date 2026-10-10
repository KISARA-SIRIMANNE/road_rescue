import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';

import '../authentication/login_screen.dart';

class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

  // ================================================================
  // COLORS
  // ================================================================

  static const Color backgroundColor = RoadRescueColors.background;
  static const Color whiteColor = RoadRescueColors.foreground;
  static const Color yellowColor = RoadRescueColors.accent;
  static const Color greyColor = RoadRescueColors.muted;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: backgroundColor,

      body: Stack(
        children: [
          // ==========================================================
          // BACKGROUND IMAGE
          // ==========================================================

          Positioned.fill(
            child: Image.asset(
              'assets/pictures/tow_truck_3.png',
              fit: BoxFit.cover,
            ),
          ),

          // ==========================================================
          // DARK OVERLAY
          // ==========================================================
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.70),
                  ],
                ),
              ),
            ),
          ),

          // ==========================================================
          // MAIN CONTENT
          // ==========================================================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ==================================================
                  // ROADRESCUE LOGO
                  // ==================================================
                  _buildLogo(),

                  // ==================================================
                  // SPACE
                  // ==================================================
                  const Spacer(),

                  // ==================================================
                  // MAIN TEXT
                  // ==================================================
                  SizedBox(
                    width: screenSize.width * 0.72,
                    child: _buildMainText(),
                  ),

                  // ==================================================
                  // SPACE
                  // ==================================================
                  const Spacer(),

                  // ==================================================
                  // PAGE INDICATORS
                  // ==================================================
                  Center(child: _buildPageIndicators()),

                  const SizedBox(height: 12),

                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Already have an account?',
                          style: TextStyle(color: greyColor, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              color: yellowColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // ROADRESCUE LOGO
  // ================================================================

  Widget _buildLogo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ------------------------------------------------------------
        // LIGHTNING ICON
        // ------------------------------------------------------------

        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: yellowColor,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            '⚡',
            style: TextStyle(
              color: RoadRescueColors.background,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // ------------------------------------------------------------
        // BRAND NAME
        // ------------------------------------------------------------
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Road',
                    style: TextStyle(
                      color: whiteColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: 'Rescue',
                    style: TextStyle(
                      color: yellowColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'ALWAYS THERE FOR YOU',
              style: TextStyle(
                color: greyColor,
                fontSize: 7,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================================================================
  // MAIN ONBOARDING TEXT
  // ================================================================

  Widget _buildMainText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Roadside Help,',
          style: TextStyle(
            color: whiteColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),

        const Text(
          'Anytime',
          style: TextStyle(
            color: yellowColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          'Fast, reliable roadside assistance whenever '
          'your vehicle breaks down — day or night.',
          style: TextStyle(
            color: whiteColor,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // PAGE INDICATORS
  // ================================================================

  Widget _buildPageIndicators() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Screen 1 - Active
        _buildIndicator(isActive: true),

        const SizedBox(width: 6),

        // Screen 2
        _buildIndicator(isActive: false),

        const SizedBox(width: 6),

        // Screen 3
        _buildIndicator(isActive: false),
      ],
    );
  }

  // ================================================================
  // INDIVIDUAL INDICATOR
  // ================================================================

  Widget _buildIndicator({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isActive ? 24 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: isActive ? yellowColor : whiteColor.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
