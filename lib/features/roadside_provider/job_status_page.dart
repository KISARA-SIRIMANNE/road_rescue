import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';
import 'roadside_provider_home_page.dart';

class JobStatusPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> userData;

  const JobStatusPage({
    super.key,
    required this.requestId,
    required this.userData,
  });

  @override
  State<JobStatusPage> createState() => _JobStatusPageState();
}

class _JobStatusPageState extends State<JobStatusPage> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _jobSubscription;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _amountController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  String _status = 'accepted';

  String _driverName = 'Vehicle Owner';

  String _vehicleType = 'Vehicle';

  String _issueType = 'Assistance';

  String _paymentStatus = 'not_applicable';

  double? _jobAmount;

  bool _isUpdating = false;

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
  // LISTEN TO JOB
  // ============================================================

  void _listenToJob() {
    _jobSubscription = _firestore
        .collection('assistance_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen(
      (DocumentSnapshot snapshot) {
        if (!mounted) {
          return;
        }

        if (!snapshot.exists) {
          return;
        }

        final Map<String, dynamic> data =
            snapshot.data() as Map<String, dynamic>;

        final dynamic amount = data['jobAmount'];

        if (amount is num) {
          _jobAmount = amount.toDouble();

          if (_amountController.text.isEmpty) {
            _amountController.text = _jobAmount!.toStringAsFixed(2);
          }
        }

        setState(() {
          _status = data['status']?.toString() ?? 'accepted';

          _driverName = data['userName']?.toString() ?? 'Vehicle Owner';

          _vehicleType = data['vehicleType']?.toString() ?? 'Vehicle';

          _issueType = data['issueType']?.toString() ?? 'Assistance';

          _paymentStatus =
              data['paymentStatus']?.toString() ?? 'not_applicable';

          _isLoading = false;
        });
      },
      onError: (error) {
        debugPrint('Job listener error: $error');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  // ============================================================
  // UPDATE JOB STATUS
  // ============================================================

  Future<void> _updateJobStatus(String newStatus) async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'on_the_way') {
        updateData['onTheWayAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == 'arrived') {
        updateData['arrivedAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == 'in_progress') {
        updateData['serviceStartedAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();

        // Payment becomes available after the service is completed.
        updateData['paymentStatus'] = 'pending';

        updateData['paymentUpdatedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('assistance_requests')
          .doc(widget.requestId)
          .update(updateData);

      if (!mounted) {
        return;
      }

      _showMessage(_statusMessage(newStatus));
    } catch (e) {
      debugPrint('Error updating job status: $e');

      if (mounted) {
        _showMessage('Unable to update job status.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE JOB AMOUNT
  // ============================================================

  Future<void> _saveJobAmount() async {
    final String amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      _showMessage('Please enter the job amount.');
      return;
    }

    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showMessage('Please enter a valid amount.');
      return;
    }

    try {
      await _firestore
          .collection('assistance_requests')
          .doc(widget.requestId)
          .update({
        'jobAmount': amount,
        'paymentStatus': _paymentStatus == 'paid' ? 'paid' : 'pending',
        'paymentUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _jobAmount = amount;
      });

      _showMessage('Job amount saved.');
    } catch (e) {
      debugPrint('Error saving job amount: $e');

      if (mounted) {
        _showMessage('Unable to save job amount.');
      }
    }
  }

  // ============================================================
  // MARK PAYMENT RECEIVED
  // ============================================================

  Future<void> _markPaymentReceived() async {
    if (_status != 'completed') {
      _showMessage('Complete the job before recording payment.');
      return;
    }

    if (_jobAmount == null || _jobAmount! <= 0) {
      _showMessage('Please enter and save the job amount first.');
      return;
    }

    if (_paymentStatus == 'paid') {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: RoadRescueColors.surface,
          title: const Text(
            'Confirm Payment',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Have you actually received the payment of ${_formatAmount(_jobAmount!)} from the customer?',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'Not Yet',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: RoadRescueColors.accent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Yes, Received'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _firestore
          .collection('assistance_requests')
          .doc(widget.requestId)
          .update({
        'paymentStatus': 'paid',
        'paymentReceivedAt': FieldValue.serverTimestamp(),
        'paymentUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentStatus = 'paid';
      });

      _showMessage('Payment marked as received.');
    } catch (e) {
      debugPrint('Error updating payment: $e');

      if (mounted) {
        _showMessage('Unable to update payment status.');
      }
    }
  }

  // ============================================================
  // GO TO PROVIDER DASHBOARD
  // ============================================================

  Future<void> _goToProviderDashboard() async {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => RoadsideProviderHomePage(
          userData: widget.userData,
        ),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // STATUS MESSAGE
  // ============================================================

  String _statusMessage(String status) {
    switch (status) {
      case 'on_the_way':
        return 'Status updated: On the way';

      case 'arrived':
        return 'Status updated: Arrived';

      case 'in_progress':
        return 'Status updated: Job in progress';

      case 'completed':
        return 'Job completed. Payment is now pending.';

      default:
        return 'Job status updated.';
    }
  }

  // ============================================================
  // STATUS TITLE
  // ============================================================

  String _statusTitle() {
    switch (_status) {
      case 'accepted':
        return 'Request Accepted';

      case 'on_the_way':
        return 'On the Way';

      case 'arrived':
        return 'Arrived';

      case 'in_progress':
        return 'Job in Progress';

      case 'completed':
        return 'Job Completed';

      default:
        return 'Job Status';
    }
  }

  // ============================================================
  // STATUS DESCRIPTION
  // ============================================================

  String _statusDescription() {
    switch (_status) {
      case 'accepted':
        return 'You have accepted this assistance request.';

      case 'on_the_way':
        return 'You are currently travelling to the vehicle owner.';

      case 'arrived':
        return 'You have arrived at the vehicle owner location.';

      case 'in_progress':
        return 'The roadside assistance service is currently in progress.';

      case 'completed':
        return 'The roadside assistance service has been completed.';

      default:
        return 'Manage the current roadside assistance job.';
    }
  }

  // ============================================================
  // CURRENT STATUS INDEX
  // ============================================================

  int _currentStatusIndex() {
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
  // NEXT STATUS
  // ============================================================

  String? _nextStatus() {
    switch (_status) {
      case 'accepted':
        return 'on_the_way';

      case 'on_the_way':
        return 'arrived';

      case 'arrived':
        return 'in_progress';

      case 'in_progress':
        return 'completed';

      default:
        return null;
    }
  }

  // ============================================================
  // NEXT BUTTON TEXT
  // ============================================================

  String _nextButtonText() {
    switch (_status) {
      case 'accepted':
        return 'Start Journey';

      case 'on_the_way':
        return 'Mark as Arrived';

      case 'arrived':
        return 'Start Job';

      case 'in_progress':
        return 'Complete Job';

      default:
        return 'Job Completed';
    }
  }

  // ============================================================
  // FORMAT AMOUNT
  // ============================================================

  String _formatAmount(double amount) {
    return 'LKR ${amount.toStringAsFixed(2)}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoadRescueColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: RoadRescueColors.accent,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
                      child: Column(
                        children: [
                          _buildCustomerCard(),
                          const SizedBox(height: 18),
                          _buildStatusCard(),
                          const SizedBox(height: 18),
                          _buildProgress(),
                          const SizedBox(height: 20),
                          _buildActionButton(),
                          const SizedBox(height: 20),
                          _buildPaymentCard(),
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
                  'Manage your current assistance job',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
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
  // CUSTOMER CARD
  // ============================================================

  Widget _buildCustomerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RoadRescueColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: RoadRescueColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: RoadRescueColors.accent,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driverName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_vehicleType • $_issueType',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
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
  // STATUS CARD
  // ============================================================

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RoadRescueColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: RoadRescueColors.accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statusIcon(),
              color: RoadRescueColors.accent,
              size: 31,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            _statusTitle(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
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
        return Icons.work_outline;
    }
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

    final int currentIndex = _currentStatusIndex();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RoadRescueColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(
          labels.length,
          (index) {
            final bool completed = index <= currentIndex;

            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: completed
                          ? RoadRescueColors.accent
                          : Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      completed ? Icons.check : Icons.circle,
                      color: completed ? Colors.black : Colors.white24,
                      size: 15,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: completed ? Colors.white : Colors.white30,
                      fontSize: 8,
                      fontWeight:
                          completed ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _buildActionButton() {
    final String? next = _nextStatus();

    if (next == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isUpdating
            ? null
            : () {
                if (next == 'completed') {
                  _showCompleteConfirmation();
                } else {
                  _updateJobStatus(next);
                }
              },
        icon: _isUpdating
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Icon(
                next == 'completed'
                    ? Icons.check_circle_outline
                    : Icons.arrow_forward_rounded,
              ),
        label: Text(
          _isUpdating ? 'Updating...' : _nextButtonText(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: RoadRescueColors.accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white10,
          disabledForegroundColor: Colors.white30,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // COMPLETE CONFIRMATION
  // ============================================================

  Future<void> _showCompleteConfirmation() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: RoadRescueColors.surface,
          title: const Text(
            'Complete Job?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure the roadside assistance service has been completed?',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
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
                backgroundColor: RoadRescueColors.accent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateJobStatus('completed');
    }
  }

  // ============================================================
  // PAYMENT CARD
  // ============================================================

  Widget _buildPaymentCard() {
    final bool completed = _status == 'completed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RoadRescueColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: completed
              ? RoadRescueColors.accent.withOpacity(0.18)
              : Colors.white.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: RoadRescueColors.accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: RoadRescueColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Service payment',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              _buildPaymentStatusBadge(),
            ],
          ),

          const SizedBox(height: 18),

          if (!completed)
            const Text(
              'Payment details become available after the job is completed.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.5,
              ),
            )
          else ...[
            const Text(
              'Job Amount',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixText: 'LKR ',
                prefixStyle: const TextStyle(color: Colors.white54),
                hintText: 'Enter service amount',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: RoadRescueColors.elevatedSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _saveJobAmount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save Amount'),
              ),
            ),

            const SizedBox(height: 12),

            if (_paymentStatus == 'pending')
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _markPaymentReceived,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Confirm Payment Received'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),

            if (_paymentStatus == 'paid') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.greenAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _jobAmount != null
                            ? 'Payment received: ${_formatAmount(_jobAmount!)}'
                            : 'Payment received',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _goToProviderDashboard,
                  icon: const Icon(
                    Icons.dashboard_rounded,
                    size: 20,
                  ),
                  label: const Text(
                    'Back to Provider Dashboard',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RoadRescueColors.accent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT STATUS BADGE
  // ============================================================

  Widget _buildPaymentStatusBadge() {
    Color textColor;
    String text;

    switch (_paymentStatus) {
      case 'pending':
        textColor = Colors.orangeAccent;
        text = 'PENDING';
        break;

      case 'paid':
        textColor = Colors.greenAccent;
        text = 'PAID';
        break;

      default:
        textColor = Colors.white38;
        text = 'WAITING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
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
        backgroundColor: RoadRescueColors.surface,
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _amountController.dispose();

    super.dispose();
  }
}