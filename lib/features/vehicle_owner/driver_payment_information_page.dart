import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';

class DriverPaymentInformationPage extends StatefulWidget {
  final String userId;
  final String paymentPreference;
  final String billingName;
  final String billingAddress;

  const DriverPaymentInformationPage({
    super.key,
    required this.userId,
    required this.paymentPreference,
    required this.billingName,
    required this.billingAddress,
  });

  @override
  State<DriverPaymentInformationPage> createState() =>
      _DriverPaymentInformationPageState();
}

class _DriverPaymentInformationPageState
    extends State<DriverPaymentInformationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _billingNameController = TextEditingController();
  final TextEditingController _billingAddressController =
      TextEditingController();

  late String _paymentPreference;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _paymentPreference = widget.paymentPreference == 'cash' ? 'cash' : 'card';
    _billingNameController.text = widget.billingName;
    _billingAddressController.text = widget.billingAddress;
  }

  @override
  void dispose() {
    _billingNameController.dispose();
    _billingAddressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.userId.isEmpty) {
      _showError('Unable to identify your account.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    final String billingName = _billingNameController.text.trim();
    final String billingAddress = _billingAddressController.text.trim();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'paymentPreference': _paymentPreference,
            'billingName': billingName,
            'billingAddress': billingAddress,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      Navigator.of(context).pop(<String, String>{
        'paymentPreference': _paymentPreference,
        'billingName': billingName,
        'billingAddress': billingAddress,
      });
    } on FirebaseException catch (error) {
      debugPrint('Saving driver payment information failed: ${error.code}');
      _showError(
        error.code == 'permission-denied'
            ? 'You do not have permission to update payment information.'
            : 'Could not save payment information. Please try again.',
      );
    } catch (error) {
      debugPrint('Saving driver payment information failed: $error');
      _showError('Could not save payment information. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: RoadRescueColors.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoadRescueColors.background,
      appBar: AppBar(title: const Text('Payment Information')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const Text(
                'Payment preference',
                style: TextStyle(
                  color: RoadRescueColors.foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'card',
                    label: Text('Card'),
                    icon: Icon(Icons.credit_card_rounded),
                  ),
                  ButtonSegment<String>(
                    value: 'cash',
                    label: Text('Cash'),
                    icon: Icon(Icons.payments_outlined),
                  ),
                ],
                selected: {_paymentPreference},
                onSelectionChanged: _isSaving
                    ? null
                    : (selection) => setState(() {
                        _paymentPreference = selection.first;
                      }),
              ),
              const SizedBox(height: 24),
              const Text(
                'Billing information',
                style: TextStyle(
                  color: RoadRescueColors.foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _billingNameController,
                textCapitalization: TextCapitalization.words,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Billing name',
                  hintText: 'Name for the receipt',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _billingAddressController,
                textCapitalization: TextCapitalization.words,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Billing address',
                  hintText: 'Address for billing records (optional)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Card details',
                style: TextStyle(
                  color: RoadRescueColors.foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: RoadRescueColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: RoadRescueColors.border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.credit_card_rounded,
                      color: RoadRescueColors.accent,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'When you choose card at checkout, enter the cardholder '
                        'name, card number, expiry date, and CVV in the payment '
                        'form. These details are used only for that checkout and '
                        'are never saved to your profile.',
                        style: TextStyle(
                          color: RoadRescueColors.muted,
                          height: 1.45,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: RoadRescueColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: RoadRescueColors.border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: RoadRescueColors.accent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only your payment preference and billing details are saved. '
                        'Do not enter card numbers or CVV on this page. Card checkout '
                        'is currently a demo and is not connected to a payment gateway.',
                        style: TextStyle(
                          color: RoadRescueColors.muted,
                          height: 1.45,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RoadRescueColors.background,
                          ),
                        )
                      : const Text('Save payment information'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
