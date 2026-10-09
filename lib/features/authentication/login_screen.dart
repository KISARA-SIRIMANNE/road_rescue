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

  static const Color backgroundColor = Color(0xFF101214);
  static const Color cardColor = Color(0xFF181B1E);
  static const Color yellowColor = Color(0xFFF6E900);
  static const Color whiteColor = Color(0xFFF5F7F8);
  static const Color greyColor = Color(0xFF929AA2);
  static const Color borderColor = Color(0xFF30353A);

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

      final String role = userData['role']?.toString() ?? '';

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
            builder: (context) => RoadsideProviderHomePage(
              userData: userData,
            ),
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

      // ----------------------------------------------------------
      // UNKNOWN ROLE
      // ----------------------------------------------------------

      _showError('Your account role is not recognized.');

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
          disabledBackgroundColor: yellowColor.withOpacity(0.5),
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

// ============================================================
// TEMPORARY ROLE HOME PLACEHOLDER
// ============================================================
//
// This is kept for the Roadside Assistance Provider and
// Insurance Provider until we create their home pages.
//
// Vehicle owners are sent directly to:
// VehicleOwnerHomePage
// ============================================================

class RoleHomePlaceholder extends StatelessWidget {
  final String role;
  final Map<String, dynamic> userData;

  const RoleHomePlaceholder({
    super.key,
    required this.role,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    String roleName;

    switch (role) {
      case 'roadside_provider':
        roleName = 'Roadside Assistance Provider';
        break;

      case 'insurance_provider':
        roleName = 'Insurance Provider';
        break;

      default:
        roleName = 'User';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101214),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6E900),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF101214),
                    size: 42,
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Login Successful',
                  style: TextStyle(
                    color: Color(0xFFF5F7F8),
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  roleName,
                  style: const TextStyle(
                    color: Color(0xFFF6E900),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Your home page will be available here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF929AA2), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
