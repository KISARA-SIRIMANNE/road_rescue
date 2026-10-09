import 'package:flutter/material.dart';
import 'request_assistance_page.dart';
import 'vehicle_owner_notifications_page.dart';

class VehicleOwnerHomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const VehicleOwnerHomePage({
    super.key,
    required this.userData,
  });

  @override
  State<VehicleOwnerHomePage> createState() =>
      _VehicleOwnerHomePageState();
}

class _VehicleOwnerHomePageState
    extends State<VehicleOwnerHomePage> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color backgroundColor = Color(0xFF05090B);
  static const Color cardColor = Color(0xFF11181C);
  static const Color yellowColor = Color(0xFFFFD21F);
  static const Color whiteColor = Color(0xFFF5F7F8);
  static const Color greyColor = Color(0xFFA5ADB3);
  static const Color borderColor = Color(0xFF263036);

  // ============================================================
  // STATE
  // ============================================================

  int _selectedIndex = 0;

  // ============================================================
  // USER DATA
  // ============================================================

  String get userName {
    final name = widget.userData['name'];

    if (name == null || name.toString().trim().isEmpty) {
      return 'there';
    }

    return name.toString().trim();
  }

  String get vehicleType {
    final vehicle = widget.userData['vehicleType'];

    if (vehicle == null || vehicle.toString().trim().isEmpty) {
      return 'Vehicle';
    }

    return vehicle.toString().trim();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomePage(),
            _buildRequestsPage(),
            _buildProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // HOME PAGE
  // ============================================================

  Widget _buildHomePage() {
    return RefreshIndicator(
      color: yellowColor,
      backgroundColor: cardColor,
      onRefresh: () async {
        await Future.delayed(
          const Duration(milliseconds: 600),
        );
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          22,
          20,
          22,
          30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),

            const SizedBox(height: 28),

            _buildGreeting(),

            const SizedBox(height: 25),

            _buildEmergencyCard(),

            const SizedBox(height: 26),

            _buildSectionTitle(
              title: 'Quick Services',
              actionText: 'View All',
              onActionPressed: () {},
            ),

            const SizedBox(height: 14),

            _buildQuickServices(),

            const SizedBox(height: 28),

            _buildSectionTitle(
              title: 'My Vehicle',
              actionText: 'Edit',
              onActionPressed: () {
                _showComingSoon(
                  'Vehicle editing will be available soon.',
                );
              },
            ),

            const SizedBox(height: 14),

            _buildVehicleCard(),

            const SizedBox(height: 28),

            _buildSectionTitle(
              title: 'Recent Requests',
              actionText: 'View All',
              onActionPressed: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
            ),

            const SizedBox(height: 14),

            _buildRecentRequests(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Row(
      children: [
        // Logo
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: yellowColor,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            '⚡',
            style: TextStyle(
              color: backgroundColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 11),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'RoadRescue',
              style: TextStyle(
                color: whiteColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'ALWAYS THERE FOR YOU',
              style: TextStyle(
                color: greyColor,
                fontSize: 6.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Notification
        _buildIconButton(
          icon: Icons.notifications_none_rounded,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const VehicleOwnerNotificationsPage(),
              ),
            );
          },
        ),

        const SizedBox(width: 9),

        // Profile
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
          child: Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: whiteColor,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GREETING
  // ============================================================

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $userName 👋',
          style: const TextStyle(
            color: whiteColor,
            fontSize: 27,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'How can we help you today?',
          style: TextStyle(
            color: greyColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMERGENCY CARD
  // ============================================================

  Widget _buildEmergencyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: yellowColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: yellowColor.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: backgroundColor,
                  size: 25,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      color: Color(0xFF1B5E20),
                      size: 8,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Available 24/7',
                      style: TextStyle(
                        color: backgroundColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'Need roadside help?',
            style: TextStyle(
              color: backgroundColor,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Request assistance and get help from a nearby provider.',
            style: TextStyle(
              color: backgroundColor.withOpacity(0.65),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                context,
                MaterialPageRoute(
                builder: (context) => RequestAssistancePage(
                  userData: widget.userData,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: yellowColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.car_repair_rounded,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Request Assistance',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle({
    required String title,
    required String actionText,
    required VoidCallback onActionPressed,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: whiteColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),

        const Spacer(),

        GestureDetector(
          onTap: onActionPressed,
          child: Text(
            actionText,
            style: const TextStyle(
              color: yellowColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK SERVICES
  // ============================================================

  Widget _buildQuickServices() {
    return Row(
      children: [
        Expanded(
          child: _buildServiceCard(
            icon: Icons.local_shipping_outlined,
            title: 'Towing',
            subtitle: 'Vehicle towing',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildServiceCard(
            icon: Icons.tire_repair_outlined,
            title: 'Flat Tire',
            subtitle: 'Tire assistance',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildServiceCard(
            icon: Icons.battery_alert_outlined,
            title: 'Battery',
            subtitle: 'Jump start',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildServiceCard(
            icon: Icons.local_gas_station_outlined,
            title: 'Fuel',
            subtitle: 'Fuel delivery',
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () {
        _showComingSoon(
          '$title assistance will be available soon.',
        );
      },
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 112,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: yellowColor.withOpacity(0.09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: yellowColor,
                size: 21,
              ),
            ),

            const SizedBox(height: 9),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: whiteColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: greyColor,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VEHICLE CARD
  // ============================================================

  Widget _buildVehicleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: yellowColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: yellowColor,
              size: 29,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Vehicle',
                  style: TextStyle(
                    color: greyColor,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  vehicleType,
                  style: const TextStyle(
                    color: whiteColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Vehicle information',
                  style: TextStyle(
                    color: greyColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: greyColor,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECENT REQUESTS
  // ============================================================

  Widget _buildRecentRequests() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: greyColor,
              size: 27,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'No recent requests',
            style: TextStyle(
              color: whiteColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Your roadside assistance requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: greyColor,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUESTS PAGE
  // ============================================================

  Widget _buildRequestsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        22,
        25,
        22,
        30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            title: 'My Requests',
            subtitle: 'Track your roadside assistance requests.',
          ),

          const SizedBox(height: 28),

          _buildRecentRequests(),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE PAGE
  // ============================================================

  Widget _buildProfilePage() {
    final email =
        widget.userData['email']?.toString() ?? '';

    final contactNumber =
        widget.userData['contactNumber']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        22,
        25,
        22,
        30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader(
            title: 'My Profile',
            subtitle: 'Manage your RoadRescue account.',
          ),

          const SizedBox(height: 28),

          // Profile header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: yellowColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: backgroundColor,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  userName,
                  style: const TextStyle(
                    color: whiteColor,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  email,
                  style: const TextStyle(
                    color: greyColor,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: yellowColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Vehicle Owner',
                    style: TextStyle(
                      color: yellowColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildProfileInfoTile(
            icon: Icons.directions_car_outlined,
            title: 'Vehicle Type',
            value: vehicleType,
          ),

          if (contactNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildProfileInfoTile(
              icon: Icons.phone_outlined,
              title: 'Contact Number',
              value: contactNumber,
            ),
          ],

          const SizedBox(height: 20),

          _buildProfileAction(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            onTap: () {
              _showComingSoon(
                'Profile editing will be available soon.',
              );
            },
          ),

          const SizedBox(height: 10),

          _buildProfileAction(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            isDestructive: true,
            onTap: () {
              _showLogoutDialog();
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAGE HEADER
  // ============================================================

  Widget _buildPageHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: whiteColor,
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          subtitle,
          style: const TextStyle(
            color: greyColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE INFO TILE
  // ============================================================

  Widget _buildProfileInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: yellowColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: yellowColor,
              size: 21,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: greyColor,
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    color: whiteColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE ACTION
  // ============================================================

  Widget _buildProfileAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFF4A2727)
                : borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? const Color(0xFFFF5252)
                  : greyColor,
              size: 21,
            ),

            const SizedBox(width: 13),

            Text(
              title,
              style: TextStyle(
                color: isDestructive
                    ? const Color(0xFFFF5252)
                    : whiteColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),

            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive
                  ? const Color(0xFFFF5252)
                  : greyColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 0.6,
          ),
        ),
      ),
      child: NavigationBar(
        height: 68,
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: yellowColor.withOpacity(0.12),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
              color: greyColor,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: yellowColor,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.assignment_outlined,
              color: greyColor,
            ),
            selectedIcon: Icon(
              Icons.assignment_rounded,
              color: yellowColor,
            ),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
              color: greyColor,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: yellowColor,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ICON BUTTON
  // ============================================================

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Icon(
          icon,
          color: whiteColor,
          size: 22,
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT DIALOG
  // ============================================================

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(
              color: whiteColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out of RoadRescue?',
            style: TextStyle(
              color: greyColor,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: greyColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                _showComingSoon(
                  'Logout functionality will be connected next.',
                );
              },
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: Color(0xFFFF5252),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  void _showComingSoon(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: cardColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}