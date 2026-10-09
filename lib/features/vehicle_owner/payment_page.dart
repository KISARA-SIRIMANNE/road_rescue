import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';

import 'review_rating_page.dart';

class PaymentPage extends StatefulWidget {
  final String requestId;
  final double amount;

  const PaymentPage({super.key, required this.requestId, required this.amount});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _cardHolderController = TextEditingController();

  final TextEditingController _cardNumberController = TextEditingController();

  final TextEditingController _expiryController = TextEditingController();

  final TextEditingController _cvvController = TextEditingController();

  bool _isProcessing = false;
  bool _showCvv = false;
  bool _paymentSuccessful = false;

  @override
  void dispose() {
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();

    super.dispose();
  }

  String _formatCardNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }

      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  String _maskCardNumber() {
    final digits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length < 4) {
      return '**** **** **** ****';
    }

    return '**** **** **** ${digits.substring(digits.length - 4)}';
  }

  bool _isValidExpiry(String value) {
    final cleaned = value.replaceAll('/', '');

    if (cleaned.length != 4) {
      return false;
    }

    final month = int.tryParse(cleaned.substring(0, 2));
    final year = int.tryParse(cleaned.substring(2, 4));

    if (month == null || year == null) {
      return false;
    }

    if (month < 1 || month > 12) {
      return false;
    }

    final now = DateTime.now();

    final currentYear = now.year % 100;
    final currentMonth = now.month;

    if (year < currentYear) {
      return false;
    }

    if (year == currentYear && month < currentMonth) {
      return false;
    }

    return true;
  }

  String _generatePaymentReference() {
    final random = Random();

    final randomNumber = List.generate(8, (_) => random.nextInt(10)).join();

    return 'RR-$randomNumber';
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
    });

    try {
      /*
       * This is a DEMO payment.
       *
       * No real payment gateway is connected.
       * Card number and CVV are NOT stored in Firestore.
       */

      await Future.delayed(const Duration(seconds: 2));

      final String paymentReference = _generatePaymentReference();

      await _firestore
          .collection('assistance_requests')
          .doc(widget.requestId)
          .update({
            'paymentStatus': 'paid',
            'paymentMethod': 'card',
            'paidAmount': widget.amount,
            'paidAt': FieldValue.serverTimestamp(),
            'paymentReference': paymentReference,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _paymentSuccessful = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed. Please try again.\n$e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentSuccessful) {
      return _buildPaymentSuccessPage();
    }

    return Scaffold(
      backgroundColor: RoadRescueColors.background,
      appBar: AppBar(
        backgroundColor: RoadRescueColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: _isProcessing
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAmountCard(),

                const SizedBox(height: 24),

                const Text(
                  'Card Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Enter your card details to complete the payment.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),

                const SizedBox(height: 22),

                _buildTextField(
                  controller: _cardHolderController,
                  label: 'Cardholder Name',
                  hint: 'John Doe',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the cardholder name';
                    }

                    if (value.trim().length < 3) {
                      return 'Enter a valid name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                _buildTextField(
                  controller: _cardNumberController,
                  label: 'Card Number',
                  hint: '1234 5678 9012 3456',
                  icon: Icons.credit_card,
                  keyboardType: TextInputType.number,
                  maxLength: 19,
                  onChanged: (value) {
                    final formatted = _formatCardNumber(value);

                    if (formatted != value) {
                      _cardNumberController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }

                    setState(() {});
                  },
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');

                    if (digits.isEmpty) {
                      return 'Please enter your card number';
                    }

                    if (digits.length != 16) {
                      return 'Card number must contain 16 digits';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _expiryController,
                        label: 'Expiry Date',
                        hint: 'MM/YY',
                        icon: Icons.calendar_month_outlined,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        onChanged: (value) {
                          String digits = value.replaceAll(RegExp(r'\D'), '');

                          if (digits.length > 4) {
                            digits = digits.substring(0, 4);
                          }

                          String formatted = digits;

                          if (digits.length >= 3) {
                            formatted =
                                '${digits.substring(0, 2)}/${digits.substring(2)}';
                          }

                          if (formatted != value) {
                            _expiryController.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }

                          if (!_isValidExpiry(value)) {
                            return 'Invalid date';
                          }

                          return null;
                        },
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: _buildTextField(
                        controller: _cvvController,
                        label: 'CVV',
                        hint: '123',
                        icon: Icons.lock_outline,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: !_showCvv,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showCvv ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey.shade500,
                          ),
                          onPressed: () {
                            setState(() {
                              _showCvv = !_showCvv;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }

                          if (value.length < 3 || value.length > 4) {
                            return 'Invalid CVV';
                          }

                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                _buildSecurityNotice(),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RoadRescueColors.accent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey.shade800,
                      disabledForegroundColor: Colors.grey.shade500,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Pay Rs. ${widget.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                Center(
                  child: Text(
                    'Demo payment • No real money will be charged',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: RoadRescueColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RoadRescueColors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: RoadRescueColors.accent,
            size: 34,
          ),

          const SizedBox(height: 12),

          Text(
            'Amount to Pay',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),

          const SizedBox(height: 5),

          Text(
            'Rs. ${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'RoadRescue Assistance',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    bool obscureText = false,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscureText,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: RoadRescueColors.accent,
      validator: validator,
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade500),
        hintStyle: TextStyle(color: Colors.grey.shade700),
        prefixIcon: Icon(icon, color: RoadRescueColors.accent),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: RoadRescueColors.elevatedSurface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: RoadRescueColors.accent,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: RoadRescueColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: RoadRescueColors.accent,
            size: 22,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your payment information is protected',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'RoadRescue does not store your full card number or CVV.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSuccessPage() {
    return Scaffold(
      backgroundColor: RoadRescueColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.greenAccent,
                    size: 58,
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Payment Successful',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Your RoadRescue service payment has been recorded successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: RoadRescueColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _successRow(
                        'Amount',
                        'Rs. ${widget.amount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 14),
                      _successRow('Payment Method', 'Card'),
                      const SizedBox(height: 14),
                      _successRow('Card', _maskCardNumber()),
                      const SizedBox(height: 14),
                      _successRow(
                        'Status',
                        'PAID',
                        valueColor: Colors.greenAccent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ReviewRatingPage(
                            requestId: widget.requestId,
                            providerName: 'Roadside Assistance Provider',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RoadRescueColors.accent,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_rounded, size: 21),
                        SizedBox(width: 8),
                        Text(
                          'Rate Your Provider',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _successRow(String title, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}