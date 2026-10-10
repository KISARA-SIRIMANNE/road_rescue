import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'payment_page.dart';

class DriverJobStatusPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> userData;
  final String issue;

  const DriverJobStatusPage({
    super.key,
    required this.requestId,
    required this.userData,
    required this.issue,
  });

  @override
  State<DriverJobStatusPage> createState() => _DriverJobStatusPageState();
}

class _DriverJobStatusPageState extends State<DriverJobStatusPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _status = 'accepted';

  String _providerName = 'Roadside Provider';

  double? _jobAmount;

  String _paymentStatus = 'not_applicable';

  bool _isPaying = false;

  bool _isLoading = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _listenToJob();
  }

  // ============================================================
  // LISTEN TO JOB IN REAL TIME
  // ============================================================

  void _listenToJob() {
    _firestore
        .collection('assistance_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) {
            if (!snapshot.exists) {
              return;
            }

            final Map<String, dynamic> data =
                snapshot.data() as Map<String, dynamic>;

            final dynamic amount = data['jobAmount'];

            if (!mounted) {
              return;
            }

            setState(() {
              _status = data['status']?.toString() ?? 'accepted';

              _providerName =
                  data['providerName']?.toString() ?? 'Roadside Provider';

              _paymentStatus =
                  data['paymentStatus']?.toString() ?? 'not_applicable';

              if (amount is num) {
                _jobAmount = amount.toDouble();
              } else {
                _jobAmount = null;
              }

              _isLoading = false;
            });
          },
          onError: (error) {
            debugPrint('Driver job status listener error: $error');

            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
  }

  // ============================================================
  // PAY NOW
  // ============================================================

  Future<void> _payNow() async {
    if (_jobAmount == null || _jobAmount! <= 0) {
      _showMessage('Payment amount is not available.');

      return;
    }

    if (_paymentStatus == 'paid') {
      return;
    }

    if (_isPaying) {
      return;
    }

    // ----------------------------------------------------------
    // CONFIRM PAYMENT
    // ----------------------------------------------------------

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF11181C),
          title: const Text(
            'Confirm Payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Confirm payment of ${_formatAmount(_jobAmount!)} for the roadside assistance service?',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF6E900),
                foregroundColor: Colors.black,
              ),
              child: const Text('Pay Now'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PaymentPage(requestId: widget.requestId, amount: _jobAmount!),
        ),
      );
    }

    if (confirmed != true) {
      return;
    }

    // ----------------------------------------------------------
    // UPDATE FIRESTORE
    // ----------------------------------------------------------

    setState(() {
      _isPaying = true;
    });

    try {
      await _firestore
          .collection('assistance_requests')
          .doc(widget.requestId)
          .update({
            'paymentStatus': 'paid',
            'paymentPaidBy': widget.userData['uid'],
            'paymentPaidAt': FieldValue.serverTimestamp(),
            'paymentUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      _showMessage('Payment completed successfully.');
    } catch (e) {
      debugPrint('Payment error: $e');

      if (mounted) {
        _showMessage('Unable to complete payment.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  // ============================================================
  // FORMAT AMOUNT
  // ============================================================

  String _formatAmount(double amount) {
    return 'LKR ${amount.toStringAsFixed(2)}';
  }

  // ============================================================
  // STATUS TITLE
  // ============================================================

  String _statusTitle() {
    switch (_status) {
      case 'accepted':
        return 'Provider Accepted';

      case 'on_the_way':
        return 'Provider Is On The Way';

      case 'arrived':
        return 'Provider Has Arrived';

      case 'in_progress':
        return 'Job In Progress';

      case 'completed':
        return 'Job Completed';

      default:
        return 'Assistance Status';
    }
  }

  // ============================================================
  // STATUS DESCRIPTION
  // ============================================================

  String _statusDescription() {
    switch (_status) {
      case 'accepted':
        return 'Your roadside assistance provider has accepted your request.';

      case 'on_the_way':
        return '$_providerName is travelling to your location.'.replaceFirst(
          '\$ ',
          '',
        );

      case 'arrived':
        return 'The roadside assistance provider has arrived at your location.';

      case 'in_progress':
        return 'The roadside assistance service is currently in progress.';

      case 'completed':
        return 'The roadside assistance service has been completed.';

      default:
        return 'Your assistance request is being processed.';
    }
  }

  // ============================================================
  // STATUS INDEX
  // ============================================================

  int _statusIndex() {
    switch (_status) {
      case 'accepted':
        return 0;

      case 'on_the_way':
        return 1;

      case 'arrived':
        return 2;

      case 'in_progress':
        return 3;

      case 'completed':
        return 4;

      default:
        return 0;
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _statusIcon() {
    switch (_status) {
      case 'accepted':
        return Icons.check_circle_outline;

      case 'on_the_way':
        return Icons.directions_car_rounded;

      case 'arrived':
        return Icons.location_on_rounded;

      case 'in_progress':
        return Icons.build_rounded;

      case 'completed':
        return Icons.task_alt_rounded;

      default:
        return Icons.support_agent;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05090B),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF6E900),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      child: Column(
                        children: [
                          _buildProviderCard(),

                          const SizedBox(height: 18),

                          _buildStatusCard(),

                          const SizedBox(height: 18),

                          _buildProgress(),

                          const SizedBox(height: 20),

                          if (_status == 'completed' && _jobAmount != null)
                            _buildPaymentCard(),

                          if (_status == 'completed' && _jobAmount != null)
                            const SizedBox(height: 20),

                          _buildBackButton(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 15),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 5),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track your roadside assistance',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROVIDER CARD
  // ============================================================

  Widget _buildProviderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF11181C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF6E900).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFFF6E900),
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Roadside Provider',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  _providerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.issue,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF11181C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: const Color(0xFFF6E900).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statusIcon(),
              color: const Color(0xFFF6E900),
              size: 32,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _statusTitle(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusDescription(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _buildProgress() {
    const List<String> labels = [
      'Accepted',
      'On Way',
      'Arrived',
      'Working',
      'Completed',
    ];

    final int current = _statusIndex();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11181C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final bool active = index <= current;

          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFF6E900) : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    active ? Icons.check : Icons.circle,
                    color: active ? Colors.black : Colors.white24,
                    size: 15,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white30,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // PAYMENT CARD
  // ============================================================

  Widget _buildPaymentCard() {
    final bool paid = _paymentStatus == 'paid';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF11181C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF6E900).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E900).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFFF6E900),
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Required',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Roadside assistance service',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF05090B),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Amount to Pay',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatAmount(_jobAmount!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          if (!paid)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isPaying ? null : _payNow,
                icon: _isPaying
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.payments_rounded),
                label: Text(
                  _isPaying ? 'Processing...' : 'Pay Now',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF6E900),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 21,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Payment completed successfully.',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
  // BACK BUTTON
  // ============================================================

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          Navigator.pop(context);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Back',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF151D21),
      ),
    );
  }
}
