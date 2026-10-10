import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/insurance_company.dart';

class ClaimDetailsVerificationPage extends StatefulWidget {
  final String claimId;

  const ClaimDetailsVerificationPage({super.key, required this.claimId});

  @override
  State<ClaimDetailsVerificationPage> createState() =>
      _ClaimDetailsVerificationPageState();
}

class _ClaimDetailsVerificationPageState
    extends State<ClaimDetailsVerificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _claim;

  bool _isLoading = true;
  bool _isUpdating = false;

  String? _errorMessage;

  // ============================================================
  // PREMIUM DESIGN SYSTEM
  // ============================================================

  static const Color bg = Color(0xFF070B0D);
  static const Color card = Color(0xFF11181D);
  static const Color cardSecondary = Color(0xFF1B252C);
  static const Color field = Color(0xFF0D1317);

  static const Color yellow = Color(0xFFFFD21C);

  static const Color white = Color(0xFFF5F7F8);
  static const Color muted = Color(0xFF9BA6AF);
  static const Color mutedDark = Color(0xFF68747D);
  static const Color border = Color(0xFF29353D);

  static const Color green = Color(0xFF19D98B);
  static const Color red = Color(0xFFFF5055);
  static const Color blue = Color(0xFF2697FF);
  static const Color orange = Color(0xFFFFA726);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadClaim();
  }

  // ============================================================
  // LOAD CLAIM
  // ============================================================

  Future<void> _loadClaim() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final document = await _firestore
          .collection('assistance_requests')
          .doc(widget.claimId)
          .get();

      if (!document.exists) {
        throw Exception('The roadside assistance request could not be found.');
      }

      final data = document.data();

      if (data == null || data['insuranceClaim'] != true) {
        throw Exception(
          'This roadside assistance request is not marked as an insurance claim.',
        );
      }

      final providerCompanyId = await loadCurrentInsuranceCompanyId();
      if (data['insuranceCompanyId'] != providerCompanyId) {
        throw Exception('You do not have access to this insurance claim.');
      }

      if (!mounted) return;

      setState(() {
        _claim = {...data, '_documentId': document.id};

        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _errorMessage = e.code == 'permission-denied'
            ? 'You do not have permission to view this claim.'
            : (e.message ?? 'Unable to load claim details.');
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // STATUS
  // ============================================================

  String get _status {
    final value = (_claim?['insuranceStatus'] ?? 'pending')
        .toString()
        .toLowerCase();

    switch (value) {
      case 'under_review':
      case 'under review':
        return 'Under Review';

      case 'approved':
        return 'Approved';

      case 'rejected':
        return 'Rejected';

      case 'need_information':
      case 'needs_information':
      case 'request_information':
        return 'Need Information';

      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return green;

      case 'Rejected':
        return red;

      case 'Under Review':
        return blue;

      case 'Need Information':
        return orange;

      default:
        return yellow;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle_rounded;

      case 'Rejected':
        return Icons.cancel_rounded;

      case 'Under Review':
        return Icons.manage_search_rounded;

      case 'Need Information':
        return Icons.info_rounded;

      default:
        return Icons.schedule_rounded;
    }
  }

  // ============================================================
  // UPDATE CLAIM STATUS
  // ============================================================

  Future<void> _updateClaimStatus(String newStatus, {String? note}) async {
    if (_isUpdating || _claim == null) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('Your insurance session has expired.');
      }

      final Map<String, dynamic> updateData = {
        'insuranceStatus': newStatus,
        'insuranceReviewedBy': user.uid,
        'insuranceReviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (note != null && note.trim().isNotEmpty) {
        updateData['insuranceReviewNote'] = note.trim();
      }

      await _firestore
          .collection('assistance_requests')
          .doc(widget.claimId)
          .update(updateData);

      await _createStatusNotification(newStatus);
      await _loadClaim();

      if (!mounted) return;

      String message;

      switch (newStatus) {
        case 'approved':
          message = 'Claim approved successfully.';
          break;

        case 'rejected':
          message = 'Claim rejected successfully.';
          break;

        default:
          message = 'Additional information requested.';
      }

      _showMessage(message);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.code == 'permission-denied'
            ? 'You can view this claim, but your account cannot update it yet.'
            : (e.message ?? 'Unable to update the claim.'),
        error: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _createStatusNotification(String newStatus) async {
    final claim = _claim;
    final userId = claim?['userId']?.toString();
    if (userId == null || userId.trim().isEmpty) return;

    final String title;
    final String message;

    switch (newStatus) {
      case 'approved':
        title = 'Claim Approved';
        message = 'Your insurance claim has been approved.';
        break;
      case 'rejected':
        title = 'Claim Rejected';
        message = 'Your insurance claim has been rejected.';
        break;
      default:
        title = 'More Information Required';
        message =
            'Additional information is required for your insurance claim.';
    }

    try {
      final notificationId = 'claim_status_${widget.claimId}_$newStatus';
      await _firestore.collection('notifications').doc(notificationId).set({
        'userId': userId,
        'title': title,
        'message': message,
        'type': 'claim_status_update',
        'status': newStatus,
        'claimId': widget.claimId,
        'requestId': widget.claimId,
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('Claim status notification error: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('Unexpected claim status notification error: $e');
    }
  }

  // ============================================================
  // CONFIRM DECISION
  // ============================================================

  Future<void> _confirmDecision(String action) async {
    String title;
    String message;
    String status;

    switch (action) {
      case 'approved':
        title = 'Approve Claim';
        message = 'Are you sure you want to approve this insurance claim?';
        status = 'approved';
        break;

      case 'rejected':
        title = 'Reject Claim';
        message = 'Are you sure you want to reject this insurance claim?';
        status = 'rejected';
        break;

      default:
        title = 'Request Information';
        message = 'Ask the driver for additional information before processing this claim.';
        status = 'need_information';
    }

    final TextEditingController noteController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final Color actionColor = action == 'rejected' ? red : yellow;

        return Dialog(
          backgroundColor: card,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        action == 'approved'
                            ? Icons.check_circle_rounded
                            : action == 'rejected'
                            ? Icons.cancel_rounded
                            : Icons.info_rounded,
                        color: actionColor,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 17),

                Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),

                if (action == 'request_information') ...[
                  const SizedBox(height: 17),

                  Text(
                    'Information Required',
                    style: GoogleFonts.poppins(
                      color: white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 7),

                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    cursorColor: yellow,
                    style: GoogleFonts.poppins(color: white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText:
                          'Describe what additional information is required...',
                      hintStyle: GoogleFonts.poppins(
                        color: mutedDark,
                        fontSize: 10,
                      ),
                      filled: true,
                      fillColor: field,
                      contentPadding: const EdgeInsets.all(13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: yellow),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          side: const BorderSide(color: border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            color: muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: action == 'rejected'
                              ? Colors.white
                              : Colors.black,
                          minimumSize: const Size(0, 44),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: Text(
                          action == 'approved'
                              ? 'Approve'
                              : action == 'rejected'
                              ? 'Reject'
                              : 'Request',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _updateClaimStatus(status, note: noteController.text);
    }

    noteController.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : _errorMessage != null
            ? _buildError()
            : Column(
                children: [
                  _buildTopBar(),

                  Expanded(
                    child: RefreshIndicator(
                      color: yellow,
                      backgroundColor: card,
                      onRefresh: _loadClaim,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 35),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: yellow, strokeWidth: 2.5),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claim Verification',
                  style: GoogleFonts.poppins(
                    color: white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Review claim information',
                  style: GoogleFonts.poppins(
                    color: muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          _topButton(
            icon: Icons.refresh_rounded,
            iconColor: yellow,
            onTap: _loadClaim,
          ),
        ],
      ),
    );
  }

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 47,
          height: 47,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    final claim = _claim!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClaimHero(claim),

        const SizedBox(height: 14),

        _buildVerificationProgress(),

        const SizedBox(height: 22),

        _buildSection(
          title: 'Driver Information',
          subtitle: 'Policy holder and driver details',
          icon: Icons.person_rounded,
          children: [
            _buildDetailRow(
              'Driver Name',
              _value(claim['userName'], 'Not available'),
              Icons.person_rounded,
            ),
            _buildDetailRow(
              'Driver ID',
              _value(claim['userId'], 'Not available'),
              Icons.fingerprint_rounded,
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildSection(
          title: 'Vehicle & Breakdown',
          subtitle: 'Vehicle and assistance request',
          icon: Icons.directions_car_rounded,
          children: [
            _buildDetailRow(
              'Vehicle',
              _value(claim['vehicleType'], 'Not available'),
              Icons.directions_car_rounded,
            ),
            _buildDetailRow(
              'Issue',
              _value(claim['issueType'], 'Not available'),
              Icons.build_rounded,
            ),
            _buildDetailRow(
              'Request Status',
              _value(claim['status'], 'Not available'),
              Icons.sync_rounded,
            ),
            _buildDetailRow(
              'Request Date',
              _formatDate(claim['createdAt']),
              Icons.calendar_month_rounded,
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildSection(
          title: 'Policy Verification',
          subtitle: 'Insurance and policy information',
          icon: Icons.shield_rounded,
          children: [
            _buildDetailRow(
              'Insurance Company',
              _value(claim['insuranceCompany'], 'Not provided'),
              Icons.business_rounded,
            ),
            _buildDetailRow(
              'Policy Number',
              _value(claim['policyNumber'], 'Not provided'),
              Icons.badge_rounded,
            ),
            _buildDescriptionRow(
              'Claim Description',
              _value(claim['insuranceDescription'], 'No description provided'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildSection(
          title: 'Roadside Assistance',
          subtitle: 'Request verification details',
          icon: Icons.car_repair_rounded,
          children: [
            _buildDetailRow(
              'Assistance Status',
              _value(claim['status'], 'Not available'),
              Icons.support_agent_rounded,
            ),
            _buildDetailRow(
              'Latitude',
              _value(claim['latitude'], 'Not available'),
              Icons.location_on_rounded,
            ),
            _buildDetailRow(
              'Longitude',
              _value(claim['longitude'], 'Not available'),
              Icons.location_on_rounded,
            ),
          ],
        ),

        if ((claim['insuranceReviewNote'] ?? '')
            .toString()
            .trim()
            .isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildReviewNote(),
        ],

        const SizedBox(height: 23),

        _buildDecisionSection(),
      ],
    );
  }

  // ============================================================
  // CLAIM HERO
  // ============================================================

  Widget _buildClaimHero(Map<String, dynamic> claim) {
    final requestId = (claim['requestId'] ?? widget.claimId).toString();

    final shortId = requestId.length > 6
        ? requestId.substring(requestId.length - 6).toUpperCase()
        : requestId.toUpperCase();

    final statusColor = _statusColor(_status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [statusColor.withValues(alpha: 0.13), card, card],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: yellow.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: yellow.withValues(alpha: 0.22)),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: yellow,
                  size: 29,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSURANCE CLAIM',
                      style: GoogleFonts.poppins(
                        color: yellow,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'CLM-$shortId',
                      style: GoogleFonts.poppins(
                        color: white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          _statusIcon(_status),
                          color: statusColor,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _status,
                          style: GoogleFonts.poppins(
                            color: statusColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _statusBadge(_status),
            ],
          ),

          const SizedBox(height: 17),

          Container(height: 1, color: border),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: _heroInfo(
                  Icons.person_rounded,
                  _value(claim['userName'], 'Unknown Driver'),
                ),
              ),
              Expanded(
                child: _heroInfo(
                  Icons.directions_car_rounded,
                  _value(claim['vehicleType'], 'Vehicle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroInfo(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: mutedDark, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VERIFICATION PROGRESS
  // ============================================================

  Widget _buildVerificationProgress() {
    final status = _status;

    int activeStep;

    switch (status) {
      case 'Approved':
      case 'Rejected':
        activeStep = 3;
        break;

      case 'Need Information':
        activeStep = 2;
        break;

      case 'Under Review':
        activeStep = 1;
        break;

      default:
        activeStep = 0;
    }

    final steps = ['Submitted', 'Review', 'Decision'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VERIFICATION PROGRESS',
            style: GoogleFonts.poppins(
              color: muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 13),

          Row(
            children: List.generate(steps.length, (index) {
              final bool active = index <= activeStep;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: active ? yellow : cardSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        index == 0
                            ? Icons.description_rounded
                            : index == 1
                            ? Icons.manage_search_rounded
                            : Icons.check_rounded,
                        color: active ? Colors.black : mutedDark,
                        size: 13,
                      ),
                    ),

                    const SizedBox(width: 6),

                    Flexible(
                      child: Text(
                        steps[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: active ? white : mutedDark,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          height: 2,
                          color: index < activeStep ? yellow : border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: yellow.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: yellow, size: 20),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: muted,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(height: 1, color: border),

          const SizedBox(height: 13),

          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: cardSecondary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: muted, size: 15),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 105,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(width: 5),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  color: white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================

  Widget _buildDescriptionRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: field,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_rounded, color: muted, size: 15),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Text(
            value,
            style: GoogleFonts.poppins(
              color: white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REVIEW NOTE
  // ============================================================

  Widget _buildReviewNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.comment_rounded, color: orange, size: 19),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REVIEW NOTE',
                  style: GoogleFonts.poppins(
                    color: orange,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _claim!['insuranceReviewNote'],
                  style: GoogleFonts.poppins(
                    color: white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
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
  // DECISION SECTION
  // ============================================================

  Widget _buildDecisionSection() {
    final bool alreadyFinal = _status == 'Approved' || _status == 'Rejected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: yellow.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                color: yellow,
                size: 20,
              ),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claim Decision',
                  style: GoogleFonts.poppins(
                    color: white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Choose the appropriate action',
                  style: GoogleFonts.poppins(color: muted, fontSize: 9),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (alreadyFinal)
          _buildFinalDecision()
        else ...[
          _decisionButton(
            label: 'Approve Claim',
            icon: Icons.check_circle_rounded,
            background: yellow,
            foreground: Colors.black,
            onPressed: _isUpdating ? null : () => _confirmDecision('approved'),
          ),

          const SizedBox(height: 9),

          _decisionButton(
            label: 'Request Information',
            icon: Icons.info_rounded,
            background: card,
            foreground: yellow,
            outlined: true,
            onPressed: _isUpdating
                ? null
                : () => _confirmDecision('request_information'),
          ),

          const SizedBox(height: 9),

          _decisionButton(
            label: 'Reject Claim',
            icon: Icons.cancel_rounded,
            background: card,
            foreground: red,
            outlined: true,
            onPressed: _isUpdating ? null : () => _confirmDecision('rejected'),
          ),
        ],

        if (_isUpdating) ...[
          const SizedBox(height: 18),
          const Center(
            child: CircularProgressIndicator(color: yellow, strokeWidth: 2.5),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // FINAL DECISION
  // ============================================================

  Widget _buildFinalDecision() {
    final color = _statusColor(_status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(_status), color: color, size: 23),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLAIM DECISION',
                  style: GoogleFonts.poppins(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'This claim has been marked as $_status.',
                  style: GoogleFonts.poppins(
                    color: white,
                    fontSize: 10.5,
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
  // DECISION BUTTON
  // ============================================================

  Widget _decisionButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback? onPressed,
    bool outlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: foreground,
                side: BorderSide(color: foreground.withValues(alpha: 0.42)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                disabledBackgroundColor: yellow.withValues(alpha: 0.30),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 6.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: red,
                  size: 34,
                ),
              ),

              const SizedBox(height: 17),

              Text(
                'Unable to Load Claim',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: muted,
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _loadClaim,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: yellow,
                  size: 17,
                ),
                label: Text(
                  'Try Again',
                  style: GoogleFonts.poppins(
                    color: yellow,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: yellow),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _value(dynamic value, String fallback) {
    if (value == null) {
      return fallback;
    }

    final String text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return 'Date unavailable';
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error
            ? const Color(0xFF6E2424)
            : const Color(0xFF242B30),
      ),
    );
  }
}
