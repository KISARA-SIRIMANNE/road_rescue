import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../vehicle_owner/vehicle_owner_home_page.dart';
import '../insurance/insurance_dashboard_page.dart';
import '../roadside_provider/roadside_provider_home_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;
  bool _obscurePassword = true;

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
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOGIN USER
  // ============================================================

  Future<void> _loginUser() async {
    FocusScope.of(context).unfocus();

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    // ------------------------------------------------------------
    // VALIDATION
    // ------------------------------------------------------------

    if (email.isEmpty) {
      _showError('Please enter your email address.');
      return;
    }

    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    if (password.isEmpty) {
      _showError('Please enter your password.');
      return;
    }

    // ------------------------------------------------------------
    // START LOADING
    // ------------------------------------------------------------

    setState(() {
      _isLoading = true;
    });

    try {
      // ----------------------------------------------------------
      // FIREBASE AUTHENTICATION
      // ----------------------------------------------------------

      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user == null) {
        _showError('Unable to retrieve your account information.');
        return;
      }

      // ----------------------------------------------------------
      // GET USER DATA FROM FIRESTORE
      // ----------------------------------------------------------

      final DocumentSnapshot userDocument = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDocument.exists) {
        _showError('Your account information could not be found.');

        await _auth.signOut();
        return;
      }

      final Map<String, dynamic> userData = {
        ...(userDocument.data() as Map<String, dynamic>),
        'uid': user.uid,
        'email': user.email,
      };

      final Object? storedRole =
          userData['role'] ??
          userData['userRole'] ??
          userData['accountType'] ??
          userData['userType'];
      final String role = _resolveRole(userData);

      // ----------------------------------------------------------
      // CHECK ROLE
      // ----------------------------------------------------------

      if (!mounted) return;

      // ----------------------------------------------------------
      // VEHICLE OWNER
      // ----------------------------------------------------------

      if (role == 'vehicle_owner') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VehicleOwnerHomePage(userData: userData),
          ),
        );

        return;
      }

      // ----------------------------------------------------------
      // ROADSIDE PROVIDER
      // ----------------------------------------------------------

      if (role == 'roadside_provider') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RoadsideProviderHomePage(userData: userData),
          ),
        );

        return;
      }

      // ----------------------------------------------------------
      // INSURANCE PROVIDER
      // ----------------------------------------------------------

      if (role == 'insurance_provider') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const InsuranceDashboardPage(),
          ),
        );

        return;
      }

      // A few accounts were created in Firebase Auth without a matching role
      // in their Firestore profile. Let the signed-in user complete that
      // missing profile field instead of immediately signing them out.
      if (role.isEmpty) {
        final selectedRole = await _chooseMissingAccountRole();
        if (selectedRole == null || !mounted) return;

        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'role': selectedRole,
        }, SetOptions(merge: true));

        if (!mounted) return;
        userData['role'] = selectedRole;
        _navigateToRole(selectedRole, userData);
        return;
      }

      // ----------------------------------------------------------
      // UNKNOWN ROLE
      // ----------------------------------------------------------

      final String roleLabel = storedRole?.toString().trim().isNotEmpty == true
          ? storedRole.toString().trim()
          : 'missing';
      debugPrint(
        'Login role not recognized: "$roleLabel"; '
        'profile fields: ${userData.keys.join(', ')}',
      );
      _showError('Account role "$roleLabel" is not recognized.');

      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;

        case 'invalid-email':
          message = 'The email address is not valid.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'user-not-found':
          message = 'No account was found with this email.';
          break;

        case 'wrong-password':
          message = 'Incorrect password.';
          break;

        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Unable to log in. Please try again.';
      }

      _showError(message);
    } on FirebaseException catch (e) {
      _showError(e.message ?? 'A Firebase error occurred. Please try again.');
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _resolveRole(Map<String, dynamic> userData) {
    final explicitRole = _normalizeRole(
      userData['role'] ??
          userData['userRole'] ??
          userData['accountType'] ??
          userData['userType'],
    );

    if (const {
      'vehicle_owner',
      'roadside_provider',
      'insurance_provider',
    }.contains(explicitRole)) {
      return explicitRole;
    }

    // Older user documents may not have a role field. Use the profile fields
    // written by registration to recover the corresponding app role.
    if (_hasAnyField(userData, const {
      'insuranceCompanyId',
      'companyId',
      'companyName',
    })) {
      return 'insurance_provider';
    }
    if (_hasAnyField(userData, const {
      'workshopLocation',
      'serviceArea',
      'providerType',
    })) {
      return 'roadside_provider';
    }
    if (_hasAnyField(userData, const {
      'vehicleType',
      'vehicleNumber',
      'vehiclePlate',
      'contactNumber',
    })) {
      return 'vehicle_owner';
    }

    return explicitRole;
  }

  bool _hasAnyField(Map<String, dynamic> data, Set<String> fields) =>
      fields.any(
        (field) =>
            data[field] != null && data[field].toString().trim().isNotEmpty,
      );

  Future<String?> _chooseMissingAccountRole() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Complete your account',
          style: TextStyle(color: whiteColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose the account type you selected when you registered.',
              style: TextStyle(color: greyColor),
            ),
            const SizedBox(height: 12),
            _roleChoice(dialogContext, 'Vehicle owner', 'vehicle_owner'),
            _roleChoice(
              dialogContext,
              'Roadside assistance provider',
              'roadside_provider',
            ),
            _roleChoice(
              dialogContext,
              'Insurance provider',
              'insurance_provider',
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChoice(BuildContext context, String title, String role) {
    return TextButton(
      onPressed: () => Navigator.pop(context, role),
      child: Text(title, style: const TextStyle(color: yellowColor)),
    );
  }

  void _navigateToRole(String role, Map<String, dynamic> userData) {
    final Widget page;
    switch (role) {
      case 'vehicle_owner':
        page = VehicleOwnerHomePage(userData: userData);
      case 'roadside_provider':
        page = RoadsideProviderHomePage(userData: userData);
      case 'insurance_provider':
        page = const InsuranceDashboardPage();
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  String _normalizeRole(Object? rawRole) {
    final role = rawRole?.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );

    switch (role) {
      case 'vehicle_owner':
      case 'vehicleowner':
      case 'owner':
      case 'customer':
      case 'motorist':
        return 'vehicle_owner';
      case 'roadside_provider':
      case 'roadside_assistance_provider':
      case 'roadside_assistance':
      case 'roadsideprovider':
      case 'serviceprovider':
      case 'service_provider':
      case 'provider':
      case 'mechanic':
      case 'workshop':
      case 'garage':
      case 'towing_provider':
        return 'roadside_provider';
      case 'insurance_provider':
      case 'insurancecompany':
      case 'insurance_company':
      case 'insurer':
      case 'insurance_agent':
      case 'insurance':
        return 'insurance_provider';
      default:
        return role ?? '';
    }
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(),

                const SizedBox(height: 36),

                _buildLogo(),

                const SizedBox(height: 42),

                _buildHeader(),

                const SizedBox(height: 34),

                _buildEmailField(),

                const SizedBox(height: 18),

                _buildPasswordField(),

                const SizedBox(height: 12),

                _buildForgotPassword(),

                const SizedBox(height: 30),

                _buildLoginButton(),

                const SizedBox(height: 28),

                _buildRegisterText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BACK BUTTON
  // ============================================================

  Widget _buildBackButton() {
    return IconButton(
      onPressed: () {
        Navigator.pop(context);
      },
      icon: const Icon(Icons.arrow_back_ios_new, color: whiteColor, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _buildLogo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: yellowColor,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            '⚡',
            style: TextStyle(
              color: backgroundColor,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 13),

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
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'Rescue',
                    style: TextStyle(
                      color: yellowColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'ALWAYS THERE FOR YOU',
              style: TextStyle(
                color: greyColor,
                fontSize: 7,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back',
          style: TextStyle(
            color: whiteColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),

        SizedBox(height: 8),

        Text(
          'Log in to continue using RoadRescue.',
          style: TextStyle(color: greyColor, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  // ============================================================
  // EMAIL FIELD
  // ============================================================

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            color: whiteColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 9),

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: whiteColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: const TextStyle(color: greyColor, fontSize: 14),
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: greyColor,
              size: 21,
            ),
            filled: true,
            fillColor: cardColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: yellowColor, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PASSWORD FIELD
  // ============================================================

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            color: whiteColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 9),

        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loginUser(),
          style: const TextStyle(color: whiteColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: const TextStyle(color: greyColor, fontSize: 14),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: greyColor,
              size: 21,
            ),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: greyColor,
                size: 21,
              ),
            ),
            filled: true,
            fillColor: cardColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: yellowColor, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          _showError('Password reset will be added soon.');
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Forgot Password?',
          style: TextStyle(
            color: yellowColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGIN BUTTON
  // ============================================================

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _loginUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: yellowColor,
          foregroundColor: backgroundColor,
          disabledBackgroundColor: yellowColor.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: backgroundColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Log In',
                    style: TextStyle(
                      color: backgroundColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(width: 12),

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

  // ============================================================
  // REGISTER TEXT
  // ============================================================

  Widget _buildRegisterText() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          const Text(
            "Don't have an account? ",
            style: TextStyle(color: greyColor, fontSize: 13),
          ),

          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Create Account',
              style: TextStyle(
                color: yellowColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
