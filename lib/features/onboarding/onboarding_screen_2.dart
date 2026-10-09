import 'package:flutter/material.dart';

class OnboardingScreen2 extends StatelessWidget {
  const OnboardingScreen2({super.key});

  // ================================================================
  // COLORS
  // ================================================================

  static const Color backgroundColor = Color(0xFF05090B);
  static const Color whiteColor = Color(0xFFF5F7F8);
  static const Color yellowColor = Color(0xFFFFD21F);
  static const Color greyColor = Color(0xFFA5ADB3);

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
              'assets/pictures/roadrescue_onboarding_screen_2.png',
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
                    Colors.black.withOpacity(0.80),
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
                    width: screenSize.width * 0.78,
                    child: _buildMainText(),
                  ),

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
              color: Color(0xFF05090B),
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
          'Help When',
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
          'You Need It',
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
          'From flat tires to unexpected breakdowns, '
          'get the roadside assistance you need, right when you need it.',
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
        // ------------------------------------------------------------
        // SCREEN 1
        // ------------------------------------------------------------

        _buildIndicator(
          isActive: false,
        ),

        const SizedBox(width: 6),

        // ------------------------------------------------------------
        // SCREEN 2 - ACTIVE
        // ------------------------------------------------------------

        _buildIndicator(
          isActive: true,
        ),

        const SizedBox(width: 6),

        // ------------------------------------------------------------
        // SCREEN 3
        // ------------------------------------------------------------

        _buildIndicator(
          isActive: false,
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