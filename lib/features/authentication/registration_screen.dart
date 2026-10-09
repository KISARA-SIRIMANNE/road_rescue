import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';

import 'login_screen.dart';
import '../../services/insurance_company.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _vehicleTypeController = TextEditingController();

  final TextEditingController _contactNumberController =
      TextEditingController();

  final TextEditingController _workshopLocationController =
      TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  String _selectedRole = 'vehicle_owner';
  String? _selectedInsuranceCompanyId;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color backgroundColor = RoadRescueColors.background;
  static const Color cardColor = RoadRescueColors.surface;
  static const Color yellowColor = RoadRescueColors.accent;
  static const Color whiteColor = RoadRescueColors.foreground;
  static const Color greyColor = RoadRescueColors.muted;
  static const Color borderColor = RoadRescueColors.border;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _vehicleTypeController.dispose();
    _contactNumberController.dispose();
    _workshopLocationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // REGISTRATION
  // ============================================================

  Future<void> _registerUser() async {
    FocusScope.of(context).unfocus();

    // ------------------------------------------------------------
    // BASIC VALIDATION
    // ------------------------------------------------------------

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (_selectedRole == 'vehicle_owner') {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your name.');
        return;
      }

      if (_vehicleTypeController.text.trim().isEmpty) {
        _showError('Please enter your vehicle type.');
        return;
      }

      if (_contactNumberController.text.trim().isEmpty) {
        _showError('Please enter your contact number.');
        return;
      }
    }

    if (_selectedRole == 'roadside_provider') {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your name.');
        return;
      }

      if (_workshopLocationController.text.trim().isEmpty) {
        _showError('Please enter your workshop location.');
        return;
      }
    }

    if (_selectedRole == 'insurance_provider') {
      if (insuranceCompanyById(_selectedInsuranceCompanyId) == null) {
        _showError('Please select your insurance company.');
        return;
      }
    }

    if (email.isEmpty) {
      _showError('Please enter your email address.');
      return;
    }

    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    if (password.isEmpty) {
      _showError('Please enter a password.');
      return;
    }

    if (password.length < 6) {
      _showError('Password must contain at least 6 characters.');
      return;
    }

    if (confirmPassword.isEmpty) {
      _showError('Please confirm your password.');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match.');
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
      // CREATE FIREBASE AUTH ACCOUNT
      // ----------------------------------------------------------

      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Unable to create the user account.');
      }

      // ----------------------------------------------------------
      // CREATE FIRESTORE USER DATA
      // ----------------------------------------------------------

      final Map<String, dynamic> userData = {
        'uid': user.uid,
        'email': email,
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // ----------------------------------------------------------
      // VEHICLE OWNER DATA
      // ----------------------------------------------------------

      if (_selectedRole == 'vehicle_owner') {
        userData['name'] = _nameController.text.trim();

        userData['vehicleType'] = _vehicleTypeController.text.trim();

        userData['contactNumber'] = _contactNumberController.text.trim();
      }

      // ----------------------------------------------------------
      // ROADSIDE ASSISTANCE PROVIDER DATA
      // ----------------------------------------------------------

      if (_selectedRole == 'roadside_provider') {
        userData['name'] = _nameController.text.trim();

        userData['workshopLocation'] = _workshopLocationController.text.trim();
      }

      // ----------------------------------------------------------
      // INSURANCE PROVIDER DATA
      // ----------------------------------------------------------

      if (_selectedRole == 'insurance_provider') {
        final company = insuranceCompanyById(_selectedInsuranceCompanyId);
        userData['insuranceCompanyId'] = company!.id;
        userData['companyName'] = company.name;
      }

      // ----------------------------------------------------------
      // SAVE USER DATA TO FIRESTORE
      // ----------------------------------------------------------

      await _firestore.collection('users').doc(user.uid).set(userData);

      // ----------------------------------------------------------
      // REGISTRATION SUCCESS
      // ----------------------------------------------------------

      if (!mounted) return;

      await _showRegistrationSuccessDialog();

      if (!mounted) return;

      // ----------------------------------------------------------
      // NAVIGATE TO LOGIN PAGE
      // ----------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email address.';
          break;

        case 'invalid-email':
          message = 'The email address is not valid.';
          break;

        case 'weak-password':
          message = 'The password is too weak. Please use a stronger password.';
          break;

        case 'operation-not-allowed':
          message =
              'Email and password registration is not enabled in Firebase.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;

        default:
          message =
              e.message ?? 'Unable to create your account. Please try again.';
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
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _showRegistrationSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Registration Successful',
            style: TextStyle(color: whiteColor, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Your RoadRescue account has been created successfully. '
            'Please log in to continue.',
            style: TextStyle(color: greyColor, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: yellowColor,
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
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(),

                const SizedBox(height: 28),

                _buildLogo(),

                const SizedBox(height: 36),

                _buildHeader(),

                const SizedBox(height: 28),

                _buildRoleSelector(),

                const SizedBox(height: 28),

                _buildRoleFields(),

                const SizedBox(height: 18),

                _buildEmailField(),

                const SizedBox(height: 18),

                _buildPasswordField(),

                const SizedBox(height: 18),

                _buildConfirmPasswordField(),

                const SizedBox(height: 30),

                _buildRegisterButton(),

                const SizedBox(height: 24),

                _buildLoginText(),
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
          'Create Account',
          style: TextStyle(
            color: whiteColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),

        SizedBox(height: 8),

        Text(
          'Create your RoadRescue account to get started.',
          style: TextStyle(color: greyColor, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  // ============================================================
  // ROLE SELECTOR
  // ============================================================

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Type',
          style: TextStyle(
            color: whiteColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 12),

        _buildRoleCard(
          role: 'vehicle_owner',
          icon: Icons.directions_car_outlined,
          title: 'Vehicle Owner',
          description: 'Get roadside assistance',
        ),

        const SizedBox(height: 10),

        _buildRoleCard(
          role: 'roadside_provider',
          icon: Icons.car_repair_outlined,
          title: 'Roadside Assistance Provider',
          description: 'Provide roadside services',
        ),

        const SizedBox(height: 10),

        _buildRoleCard(
          role: 'insurance_provider',
          icon: Icons.shield_outlined,
          title: 'Insurance Provider',
          description: 'Manage insurance services',
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final bool isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? yellowColor.withValues(alpha: 0.08) : cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? yellowColor : borderColor,
            width: isSelected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected ? yellowColor : backgroundColor,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: isSelected ? backgroundColor : greyColor,
                size: 22,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? yellowColor : whiteColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    description,
                    style: const TextStyle(color: greyColor, fontSize: 11),
                  ),
                ],
              ),
            ),

            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? yellowColor : greyColor,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ROLE-SPECIFIC FIELDS
  // ============================================================

  Widget _buildRoleFields() {
    if (_selectedRole == 'vehicle_owner') {
      return Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_outline,
            textInputType: TextInputType.name,
          ),

          const SizedBox(height: 18),

          _buildTextField(
            controller: _vehicleTypeController,
            label: 'Vehicle Type',
            hint: 'e.g. Car, Van, Motorcycle',
            icon: Icons.directions_car_outlined,
            textInputType: TextInputType.text,
          ),

          const SizedBox(height: 18),

          _buildTextField(
            controller: _contactNumberController,
            label: 'Contact Number',
            hint: 'Enter your contact number',
            icon: Icons.phone_outlined,
            textInputType: TextInputType.phone,
          ),
        ],
      );
    }

    if (_selectedRole == 'roadside_provider') {
      return Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Provider Name',
            hint: 'Enter your name',
            icon: Icons.person_outline,
            textInputType: TextInputType.name,
          ),

          const SizedBox(height: 18),

          _buildTextField(
            controller: _workshopLocationController,
            label: 'Workshop Location',
            hint: 'Enter your workshop location',
            icon: Icons.location_on_outlined,
            textInputType: TextInputType.streetAddress,
          ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedInsuranceCompanyId,
      isExpanded: true,
      dropdownColor: cardColor,
      style: const TextStyle(color: whiteColor),
      decoration: const InputDecoration(
        labelText: 'Insurance Company',
        prefixIcon: Icon(Icons.business_outlined, color: greyColor),
      ),
      hint: const Text('Select insurance company'),
      items: insuranceCompanies
          .map(
            (company) =>
                DropdownMenuItem(value: company.id, child: Text(company.name)),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedInsuranceCompanyId = value;
        });
      },
    );
  }

  // ============================================================
  // EMAIL FIELD
  // ============================================================

  Widget _buildEmailField() {
    return _buildTextField(
      controller: _emailController,
      label: 'Email Address',
      hint: 'Enter your email',
      icon: Icons.email_outlined,
      textInputType: TextInputType.emailAddress,
    );
  }

  // ============================================================
  // PASSWORD FIELD
  // ============================================================

  Widget _buildPasswordField() {
    return _buildTextField(
      controller: _passwordController,
      label: 'Password',
      hint: 'Create a password',
      icon: Icons.lock_outline,
      obscureText: _obscurePassword,
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
    );
  }

  // ============================================================
  // CONFIRM PASSWORD FIELD
  // ============================================================

  Widget _buildConfirmPasswordField() {
    return _buildTextField(
      controller: _confirmPasswordController,
      label: 'Confirm Password',
      hint: 'Re-enter your password',
      icon: Icons.lock_outline,
      obscureText: _obscureConfirmPassword,
      suffixIcon: IconButton(
        onPressed: () {
          setState(() {
            _obscureConfirmPassword = !_obscureConfirmPassword;
          });
        },
        icon: Icon(
          _obscureConfirmPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: greyColor,
          size: 21,
        ),
      ),
    );
  }

  // ============================================================
  // GENERIC TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType textInputType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: whiteColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 9),

        TextField(
          controller: controller,
          keyboardType: textInputType,
          obscureText: obscureText,
          style: const TextStyle(color: whiteColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: greyColor, fontSize: 14),
            prefixIcon: Icon(icon, color: greyColor, size: 21),
            suffixIcon: suffixIcon,
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
  // REGISTER BUTTON
  // ============================================================

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerUser,
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
                    'Create Account',
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
  // LOGIN TEXT
  // ============================================================

  Widget _buildLoginText() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          const Text(
            'Already have an account? ',
            style: TextStyle(color: greyColor, fontSize: 13),
          ),

          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text(
              'Log In',
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
