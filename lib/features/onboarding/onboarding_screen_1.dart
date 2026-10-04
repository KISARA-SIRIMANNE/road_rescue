import 'package:flutter/material.dart';

class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

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
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.70),
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

                  Center(
                    child: _buildPageIndicators(),
                  ),

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
        _buildIndicator(
          isActive: true,
        ),

        const SizedBox(width: 6),

        // Screen 2
        _buildIndicator(
          isActive: false,
        ),

        const SizedBox(width: 6),

        // Screen 3
        _buildIndicator(
          isActive: false,
        ),
      ],
    );
  }

  // ================================================================
  // INDIVIDUAL INDICATOR
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