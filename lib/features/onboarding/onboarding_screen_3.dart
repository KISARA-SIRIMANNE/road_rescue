import 'package:flutter/material.dart';

import '../authentication/registration_screen.dart';

class OnboardingScreen3 extends StatelessWidget {
  const OnboardingScreen3({super.key});

  // ================================================================
  // COLORS
  // ================================================================

  static const Color backgroundColor = Color(0xFF101214);
  static const Color whiteColor = Color(0xFFF5F7F8);
  static const Color yellowColor = Color(0xFFF6E900);
  static const Color greyColor = Color(0xFF929AA2);

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
              'assets/pictures/roadrescue_onboarding_screen_3.png',
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
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.40),
                    Colors.black.withOpacity(0.82),
                  ],
                  stops: const [
                    0.0,
                    0.45,
                    1.0,
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
                  // ==================================================
                  // TOP SPACE
                  // ==================================================

                  const SizedBox(height: 20),

                  // ==================================================
                  // ROADRESCUE LOGO
                  // ==================================================

                  _buildLogo(),

                  // ==================================================
                  // FLEXIBLE SPACE
                  // ==================================================

                  const Spacer(),

                  // ==================================================
                  // MAIN TEXT
                  // ==================================================

                  SizedBox(
                    width: screenSize.width * 0.80,
                    child: _buildMainText(),
                  ),

                  // ==================================================
                  // SPACE BEFORE BUTTON
                  // ==================================================

                  const SizedBox(height: 28),

                  // ==================================================
                  // GET STARTED BUTTON
                  // ==================================================

                  _buildGetStartedButton(context),

                  // ==================================================
                  // FLEXIBLE SPACE
                  // ==================================================

                  const Spacer(),

                  // ==================================================
                  // PAGE INDICATORS
                  // ==================================================

                  Center(
                    child: _buildPageIndicators(),
                  ),

                  // ==================================================
                  // BOTTOM SPACE
                  // ==================================================

                  const SizedBox(height: 24),
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
              color: Color(0xFF101214),
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
        // ------------------------------------------------------------
        // HEADING - LINE 1
        // ------------------------------------------------------------

        const Text(
          'We\'ll Get You',
          style: TextStyle(
            color: whiteColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),

        // ------------------------------------------------------------
        // HEADING - LINE 2
        // ------------------------------------------------------------

        const Text(
          'Moving Again',
          style: TextStyle(
            color: yellowColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),

        const SizedBox(height: 16),

        // ------------------------------------------------------------
        // DESCRIPTION
        // ------------------------------------------------------------

        const Text(
          'Get reliable help from trusted roadside professionals '
          'and get back on the road with confidence.',
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
  // GET STARTED BUTTON
  // ================================================================

  Widget _buildGetStartedButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
          context,
          MaterialPageRoute(
          builder: (context) => const RegistrationScreen(),
        ),
  );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: yellowColor,
          foregroundColor: backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Get Started',
              style: TextStyle(
                color: Color(0xFF111315),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(width: 12),

            // --------------------------------------------------------
            // ARROW
            // --------------------------------------------------------

            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: yellowColor,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // PAGE INDICATORS
  // ================================================================

  Widget _buildPageIndicators() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ------------------------------------------------------------
        // SCREEN 1
        // ------------------------------------------------------------

        _buildIndicator(
          isActive: false,
        ),

        const SizedBox(width: 6),

        // ------------------------------------------------------------
        // SCREEN 2
        // ------------------------------------------------------------

        _buildIndicator(
          isActive: false,
        ),

        const SizedBox(width: 6),

        // ------------------------------------------------------------
        // SCREEN 3 - ACTIVE
        // ------------------------------------------------------------

        _buildIndicator(
          isActive: true,
        ),
      ],
    );
  }

  // ================================================================
  // INDIVIDUAL PAGE INDICATOR
  // ================================================================

  Widget _buildIndicator({
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isActive ? 24 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: isActive
            ? yellowColor
            : whiteColor.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}