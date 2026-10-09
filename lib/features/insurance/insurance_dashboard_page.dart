import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'insurance_claims_page.dart';
import 'insurance_notifications_page.dart';
import 'insurance_claim_history_page.dart';
import 'claim_details_verification_page.dart';
import 'insurance_reports_page.dart';
import 'insurance_profile_page.dart';
import '../../services/insurance_company.dart';

class InsuranceDashboardPage extends StatefulWidget {
  const InsuranceDashboardPage({super.key});

  @override
  State<InsuranceDashboardPage> createState() =>
      _InsuranceDashboardPageState();
}

class _InsuranceDashboardPageState
    extends State<InsuranceDashboardPage> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  String? _errorMessage;

  String _userName = 'Insurance Officer';
  String _companyName = 'Insurance Provider';
  String? _companyId;

  List<Map<String, dynamic>> _claims = [];

  int _selectedIndex = 0;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color backgroundColor =
      Color(0xFF0B0E10);

  static const Color cardColor =
      Color(0xFF151A1E);

  static const Color yellowColor =
      Color(0xFFF6E900);

  static const Color whiteColor =
      Color(0xFFF5F7F8);

  static const Color greyColor =
      Color(0xFF929AA2);

  static const Color mutedColor =
      Color(0xFF70777E);

  static const Color borderColor =
      Color(0xFF2A3137);

  static const Color greenColor =
      Color(0xFF20D98A);

  static const Color redColor =
      Color(0xFFFF5555);

  static const Color blueColor =
      Color(0xFF6D9DFF);

  static const Color purpleColor =
      Color(0xFFB678FF);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ============================================================
  // LOAD DASHBOARD DATA
  // ============================================================

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final User? currentUser =
          _auth.currentUser;

      if (currentUser == null) {
        throw Exception(
          'No authenticated user found.',
        );
      }

      _companyId = await loadCurrentInsuranceCompanyId();
      _companyName = insuranceCompanyById(_companyId)!.name;

      // --------------------------------------------------------
      // USER PROFILE
      // --------------------------------------------------------

      try {
        final DocumentSnapshot<
            Map<String, dynamic>> userSnapshot =
            await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .get();

        if (userSnapshot.exists) {
          final Map<String, dynamic>? userData =
              userSnapshot.data();

          if (userData != null) {
            final dynamic nameValue =
                userData['name'] ??
                    userData['displayName'] ??
                    userData['fullName'];

            final dynamic companyValue =
                userData['companyName'];

            if (nameValue != null &&
                nameValue
                    .toString()
                    .trim()
                    .isNotEmpty) {
              _userName =
                  _formatDisplayName(
                nameValue.toString(),
              );
            } else {
              _userName =
                  _formatDisplayName(
                currentUser.email
                        ?.split('@')
                        .first ??
                    'Insurance Officer',
              );
            }

            if (companyValue != null &&
                companyValue
                    .toString()
                    .trim()
                    .isNotEmpty) {
              _companyName =
                  companyValue.toString();
            }
          }
        } else {
          _userName =
              _formatDisplayName(
            currentUser.email
                    ?.split('@')
                    .first ??
                'Insurance Officer',
          );
        }
      } catch (e) {
        _userName =
            _formatDisplayName(
          currentUser.email
                  ?.split('@')
                  .first ??
              'Insurance Officer',
        );
      }

      // --------------------------------------------------------
      // CLAIMS
      // --------------------------------------------------------

      try {
        final QuerySnapshot<
            Map<String, dynamic>> claimsSnapshot =
            await _firestore
                .collection('assistance_requests')
                .where(
                  'insuranceClaim',
                  isEqualTo: true,
                )
                .where('insuranceCompanyId', isEqualTo: _companyId)
                .get();

        _claims =
            claimsSnapshot.docs.map((doc) {
          return {
            ...doc.data(),
            '_documentId': doc.id,
          };
        }).toList();
      } on FirebaseException catch (e) {
        debugPrint(
          'Claims Firebase error: '
          '${e.code} - ${e.message}',
        );

        _claims = [];
      } catch (e) {
        debugPrint(
          'Claims loading error: $e',
        );

        _claims = [];
      }

      await _syncInsuranceClaimNotifications(currentUser.uid);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.message ??
            'Unable to load dashboard.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
      });
    }
  }

  Future<void> _syncInsuranceClaimNotifications(
    String providerUserId,
  ) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('assistance_requests')
              .where('insuranceClaim', isEqualTo: true)
              .where('insuranceCompanyId', isEqualTo: _companyId)
              .get();

      for (final document in snapshot.docs) {
        final reference = _firestore.collection('notifications').doc(
          'new_claim_${document.id}_$providerUserId',
        );

        try {
          if ((await reference.get()).exists) {
            continue;
          }

          await reference.set({
            'userId': providerUserId,
            'title': 'New Insurance Claim',
            'message': 'A new insurance claim requires your review.',
            'type': 'new_claim',
            'claimId': document.id,
            'requestId': document.id,
            'read': false,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (e) {
          debugPrint(
            'Insurance notification sync error: '
            '${e.code} - ${e.message}',
          );
        }
      }
    } on FirebaseException catch (e) {
      debugPrint(
        'Insurance claim notification query error: '
        '${e.code} - ${e.message}',
      );
    } catch (e) {
      debugPrint('Unexpected insurance notification sync error: $e');
    }
  }

  // ============================================================
  // FORMAT NAME
  // ============================================================

  String _formatDisplayName(
    String value,
  ) {
    final String cleaned =
        value.trim();

    if (cleaned.isEmpty) {
      return 'Insurance Officer';
    }

    return cleaned
        .split(RegExp(r'\s+'))
        .map((String word) {
      if (word.isEmpty) return '';

      return word[0].toUpperCase() +
          word.substring(1).toLowerCase();
    }).join(' ');
  }

  // ============================================================
  // GET VALUE
  // ============================================================

  String _getValue(
    Map<String, dynamic> claim,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final dynamic value =
          claim[key];

      if (value != null &&
          value
              .toString()
              .trim()
              .isNotEmpty) {
        return value.toString();
      }
    }

    return 'Not available';
  }

  // ============================================================
  // CLAIM ID
  // ============================================================

  String _getClaimId(
    Map<String, dynamic> claim,
  ) {
    final String claimId =
        _getValue(
      claim,
      [
        'claimId',
        'claimID',
        'id',
        'referenceNumber',
        'requestId',
      ],
    );

    if (claimId !=
        'Not available') {
      return claimId;
    }

    final dynamic documentId =
        claim['_documentId'];

    if (documentId != null) {
      return documentId.toString();
    }

    return 'Unknown Claim';
  }

  // ============================================================
  // CLAIM STATUS
  // ============================================================

  String _getStatus(
    Map<String, dynamic> claim,
  ) {
    final String status =
        _getValue(
      claim,
      [
        'insuranceStatus',
        'claimStatus',
        'status',
      ],
    );

    if (status ==
        'Not available') {
      return 'Pending';
    }

    switch (
        status.toLowerCase()) {
      case 'under_review':
        return 'Under Review';

      case 'under review':
        return 'Under Review';

      case 'need_information':
        return 'Need Information';

      case 'need information':
        return 'Need Information';

      default:
        return status;
    }
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  int get _totalClaims =>
      _claims.length;

  int get _pendingClaims {
    return _claims.where(
      (claim) {
        final String status =
            _getStatus(
          claim,
        ).toLowerCase();

        return status
            .contains('pending');
      },
    ).length;
  }

  int get _underReviewClaims {
    return _claims.where(
      (claim) {
        final String status =
            _getStatus(
          claim,
        ).toLowerCase();

        return status
            .contains('review');
      },
    ).length;
  }

  int get _approvedClaims {
    return _claims.where(
      (claim) {
        final String status =
            _getStatus(
          claim,
        ).toLowerCase();

        return status
            .contains('approved');
      },
    ).length;
  }

  int get _rejectedClaims {
    return _claims.where(
      (claim) {
        final String status =
            _getStatus(
          claim,
        ).toLowerCase();

        return status
            .contains('reject');
      },
    ).length;
  }

  // ============================================================
  // RECENT CLAIMS
  // ============================================================

  List<Map<String, dynamic>>
      get _recentClaims {
    final List<Map<String, dynamic>>
        result =
        List<Map<String, dynamic>>.from(
      _claims,
    );

    result.sort(
      (a, b) {
        final DateTime dateA =
            _getClaimDate(a);

        final DateTime dateB =
            _getClaimDate(b);

        return dateB.compareTo(
          dateA,
        );
      },
    );

    return result.take(5).toList();
  }

  // ============================================================
  // ATTENTION CLAIMS
  // ============================================================

  List<Map<String, dynamic>>
      get _attentionClaims {
    return _claims
        .where(
          (claim) {
            final String status =
                _getStatus(
              claim,
            ).toLowerCase();

            return status
                    .contains(
                      'pending',
                    ) ||
                status.contains(
                  'review',
                ) ||
                status.contains(
                  'need information',
                );
          },
        )
        .take(3)
        .toList();
  }

  // ============================================================
  // CLAIM DATE
  // ============================================================

  DateTime _getClaimDate(
    Map<String, dynamic> claim,
  ) {
    final List<String> keys = [
      'createdAt',
      'updatedAt',
      'claimDate',
      'submittedAt',
      'date',
    ];

    for (final String key
        in keys) {
      final dynamic value =
          claim[key];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        final DateTime? parsed =
            DateTime.tryParse(
          value,
        );

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return DateTime
        .fromMillisecondsSinceEpoch(
      0,
    );
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatClaimDate(
    Map<String, dynamic> claim,
  ) {
    final DateTime date =
        _getClaimDate(
      claim,
    );

    if (date ==
        DateTime
            .fromMillisecondsSinceEpoch(
          0,
        )) {
      return 'Date not available';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  Future<void> _openClaimsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const InsuranceClaimsPage(),
      ),
    );

    if (!mounted) return;

    _loadDashboardData();
  }

  Future<void>
      _openClaimHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const InsuranceClaimHistoryPage(),
      ),
    );

    if (!mounted) return;

    _loadDashboardData();
  }

  Future<void> _openClaimDetails(
    String claimId,
  ) async {
    if (claimId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ClaimDetailsVerificationPage(
          claimId: claimId,
        ),
      ),
    );

    if (!mounted) return;

    _loadDashboardData();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  bool _isUnreadNotification(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return false;

    return data['read'] != true && data['isRead'] != true;
  }

  Future<void> _openNotifications() async {
    final user = _auth.currentUser;
    if (user != null) {
      unawaited(_syncInsuranceClaimNotifications(user.uid));
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InsuranceNotificationsPage(),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _onBottomNavigationTap(
    int index,
  ) {
    if (index == 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    if (index == 1) {
      _openClaimsPage();
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const InsuranceReportsPage(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const InsuranceProfilePage(),
        ),
      );
    }
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          backgroundColor,
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar:
          _buildBottomNavigation(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoading();
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    return _buildDashboard();
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Center(
      child:
          CircularProgressIndicator(
        color: yellowColor,
        strokeWidth: 2.5,
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return RefreshIndicator(
      color: yellowColor,
      backgroundColor: cardColor,
      onRefresh:
          _loadDashboardData,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          25,
        ),
        children: [
          _buildTopHeader(),

          const SizedBox(height: 25),

          _buildWelcomeHeader(),

          const SizedBox(height: 24),

          _buildStatistics(),

          const SizedBox(height: 19),

          _buildReviewBanner(),

          const SizedBox(height: 26),

          _buildClaimsAttentionSection(),

          const SizedBox(height: 27),

          _buildQuickActions(),

          const SizedBox(height: 28),

          _buildRecentHeader(),

          const SizedBox(height: 13),

          if (_recentClaims.isEmpty)
            _buildEmptyClaims()
          else
            ..._recentClaims.map(
              (claim) => Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child:
                    _buildModernClaimCard(
                  claim,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP HEADER
  // ============================================================

  Widget _buildTopHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration:
              BoxDecoration(
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF52B),
                Color(0xFFE1C900),
              ],
            ),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            boxShadow: [
              BoxShadow(
                color: yellowColor
                    .withValues(
                  alpha: 0.18,
                ),
                blurRadius: 14,
                offset:
                    const Offset(
                  0,
                  5,
                ),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.black,
            size: 27,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'ROADRESCUE',
                style:
                    GoogleFonts.poppins(
                  color: whiteColor,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 2),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF332D05,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    5,
                  ),
                  border: Border.all(
                    color:
                        const Color(
                      0xFF5C5208,
                    ),
                  ),
                ),
                child: Text(
                  'INSURANCE PORTAL',
                  style:
                      GoogleFonts.poppins(
                    color:
                        yellowColor,
                    fontSize: 7,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        0.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _notificationStream(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data?.docs
                    .where((doc) => _isUnreadNotification(doc.data()))
                    .length ??
                0;

            return _buildNotificationHeaderIcon(unreadCount);
          },
        ),

        const SizedBox(width: 8),

        _buildHeaderIcon(
          icon:
              Icons.person_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const InsuranceProfilePage(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // HEADER ICON
  // ============================================================

  Widget _buildHeaderIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        child: Container(
          width: 43,
          height: 43,
          decoration:
              BoxDecoration(
            color: cardColor,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
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
      ),
    );
  }

  Widget _buildNotificationHeaderIcon(int unreadCount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openNotifications,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: unreadCount > 0 ? redColor : whiteColor,
                size: 22,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: redColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: backgroundColor,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcomeHeader() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'GOOD EVENING',
                style:
                    GoogleFonts.poppins(
                  color: yellowColor,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                _userName,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    GoogleFonts.poppins(
                  color: whiteColor,
                  fontSize: 27,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -0.7,
                  height: 1.05,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                _companyName,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    GoogleFonts.poppins(
                  color: greyColor,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 8,
          ),
          decoration:
              BoxDecoration(
            color:
                const Color(0xFF151C22),
            borderRadius:
                BorderRadius.circular(
              28,
            ),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 39,
                height: 39,
                decoration:
                    const BoxDecoration(
                  gradient:
                      LinearGradient(
                    colors: [
                      Color(0xFF80CFFF),
                      Color(0xFF3978B8),
                    ],
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: whiteColor,
                  size: 22,
                ),
              ),

              const SizedBox(width: 7),

              Text(
                'INSURANCE',
                style:
                    GoogleFonts.poppins(
                  color: whiteColor,
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing:
                      0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child:
                  _buildModernStatCard(
                title:
                    'Total Claims',
                value:
                    _totalClaims
                        .toString(),
                icon:
                    Icons.assignment_rounded,
                accent:
                    yellowColor,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child:
                  _buildModernStatCard(
                title: 'Pending',
                value:
                    _pendingClaims
                        .toString(),
                icon:
                    Icons.pending_actions_rounded,
                accent:
                    const Color(
                  0xFFFFB52E,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child:
                  _buildModernStatCard(
                title: 'Approved',
                value:
                    _approvedClaims
                        .toString(),
                icon:
                    Icons.verified_rounded,
                accent:
                    greenColor,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child:
                  _buildModernStatCard(
                title: 'Rejected',
                value:
                    _rejectedClaims
                        .toString(),
                icon:
                    Icons.gpp_bad_rounded,
                accent:
                    redColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      height: 112,
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.16,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color:
                      accent.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 23,
                ),
              ),

              const Spacer(),

              Text(
                value,
                style:
                    GoogleFonts.poppins(
                  color:
                      accent ==
                              yellowColor
                          ? whiteColor
                          : accent,
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const Spacer(),

          Text(
            title,
            style:
                GoogleFonts.poppins(
              color: greyColor,
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REVIEW BANNER
  // ============================================================

  Widget _buildReviewBanner() {
    final int count =
        _pendingClaims +
            _underReviewClaims;

    if (count == 0) {
      return Container(
        padding:
            const EdgeInsets.all(16),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFF10251C),
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          border: Border.all(
            color:
                const Color(0xFF1D5D43),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF183D2C,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .verified_rounded,
                color:
                    greenColor,
                size: 26,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    'All caught up!',
                    style:
                        GoogleFonts.poppins(
                      color:
                          whiteColor,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    'No claims require immediate attention.',
                    style:
                        GoogleFonts.poppins(
                      color:
                          greyColor,
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openClaimsPage,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(16),
          decoration:
              BoxDecoration(
            color:
                const Color(0xFF242008),
            borderRadius:
                BorderRadius.circular(
              17,
            ),
            border: Border.all(
              color:
                  const Color(0xFF5C510B),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF3A3309,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .priority_high_rounded,
                  color:
                      yellowColor,
                  size: 26,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Claims need your attention',
                      style:
                          GoogleFonts.poppins(
                        color:
                            whiteColor,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      '$count claim${count == 1 ? '' : 's'} currently need attention.',
                      style:
                          GoogleFonts.poppins(
                        color:
                            greyColor,
                        fontSize: 9.5,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                color:
                    yellowColor,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CLAIMS ATTENTION
  // ============================================================

  Widget _buildClaimsAttentionSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Claims Requiring Attention',
                style:
                    GoogleFonts.poppins(
                  color:
                      whiteColor,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w700,
                  letterSpacing:
                      -0.2,
                ),
              ),
            ),

            if (_attentionClaims
                .isNotEmpty)
              GestureDetector(
                onTap:
                    _openClaimsPage,
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style:
                          GoogleFonts.poppins(
                        color:
                            yellowColor,
                        fontSize: 10.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    const Icon(
                      Icons
                          .arrow_forward_ios_rounded,
                      color:
                          yellowColor,
                      size: 10,
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 13),

        if (_attentionClaims
            .isEmpty)
          _buildNoAttentionCard()
        else
          ..._attentionClaims.map(
            (claim) => Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              child:
                  _buildAttentionClaimCard(
                claim,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // ATTENTION CLAIM CARD
  // ============================================================

  Widget _buildAttentionClaimCard(
    Map<String, dynamic> claim,
  ) {
    final String claimId =
        _getClaimId(
      claim,
    );

    final String customer =
        _getValue(
      claim,
      [
        'customerName',
        'userName',
        'driverName',
        'name',
      ],
    );

    final String vehicle =
        _getValue(
      claim,
      [
        'vehicle',
        'vehicleName',
        'vehicleModel',
        'vehicleType',
      ],
    );

    final String status =
        _getStatus(
      claim,
    );

    final String lowerStatus =
        status.toLowerCase();

    Color accent;
    Color iconBackground;
    IconData icon;

    if (lowerStatus.contains(
      'need information',
    )) {
      accent = blueColor;
      iconBackground =
          const Color(0xFF172A47);
      icon =
          Icons.info_rounded;
    } else if (lowerStatus.contains(
      'review',
    )) {
      accent = purpleColor;
      iconBackground =
          const Color(0xFF2A1B3D);
      icon =
          Icons.fact_check_rounded;
    } else {
      accent = yellowColor;
      iconBackground =
          const Color(0xFF302B08);
      icon =
          Icons.pending_actions_rounded;
    }

    final String documentId =
        claim['_documentId']
                ?.toString() ??
            '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (documentId.isNotEmpty) {
            _openClaimDetails(
              documentId,
            );
          }
        },
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(13),
          decoration:
              BoxDecoration(
            color: cardColor,
            borderRadius:
                BorderRadius.circular(
              17,
            ),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.12,
                ),
                blurRadius: 10,
                offset:
                    const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 51,
                height: 51,
                decoration:
                    BoxDecoration(
                  color:
                      iconBackground,
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 25,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            claimId,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                GoogleFonts.poppins(
                              color:
                                  whiteColor,
                              fontSize:
                                  12.5,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 6,
                        ),

                        _buildModernStatusBadge(
                          status,
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      customer,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          GoogleFonts.poppins(
                        color:
                            whiteColor,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      vehicle,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          GoogleFonts.poppins(
                        color:
                            greyColor,
                        fontSize: 9.5,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 9),

              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(
                  color:
                      accent.withValues(
                    alpha: 0.10,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  color: accent,
                  size: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NO ATTENTION
  // ============================================================

  Widget _buildNoAttentionCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 19,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF10251C),
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color:
              const Color(0xFF1D5D43),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF183D2C,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: const Icon(
              Icons
                  .verified_rounded,
              color: greenColor,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'All caught up!',
                  style:
                      GoogleFonts.poppins(
                    color:
                        whiteColor,
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  'No claims currently require your attention.',
                  style:
                      GoogleFonts.poppins(
                    color:
                        greyColor,
                    fontSize: 9.5,
                    fontWeight:
                        FontWeight.w500,
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
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Quick Actions',
                style:
                    GoogleFonts.poppins(
                  color:
                      whiteColor,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),

            GestureDetector(
              onTap:
                  _openClaimsPage,
              child: Text(
                'View All',
                style:
                    GoogleFonts.poppins(
                  color:
                      yellowColor,
                  fontSize: 10.5,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 13),

        Row(
          children: [
            Expanded(
              child:
                  _buildQuickAction(
                icon:
                    Icons.assignment_rounded,
                title: 'Claims',
                accent:
                    yellowColor,
                onTap:
                    _openClaimsPage,
              ),
            ),

            const SizedBox(width: 9),

            Expanded(
              child:
                  _buildQuickAction(
                icon:
                    Icons.pending_actions_rounded,
                title: 'Pending',
                accent:
                    const Color(
                  0xFFFFB52E,
                ),
                onTap:
                    _openClaimsPage,
              ),
            ),

            const SizedBox(width: 9),

            Expanded(
              child:
                  _buildQuickAction(
                icon:
                    Icons.analytics_rounded,
                title: 'Reports',
                accent:
                    blueColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              const InsuranceReportsPage(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 9),

            Expanded(
              child:
                  _buildQuickAction(
                icon:
                    Icons.history_rounded,
                title: 'History',
                accent:
                    purpleColor,
                onTap:
                    _openClaimHistory,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACTION ITEM
  // ============================================================

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: Container(
          height: 91,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 11,
          ),
          decoration:
              BoxDecoration(
            color: cardColor,
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.12,
                ),
                blurRadius: 9,
                offset:
                    const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration:
                    BoxDecoration(
                  color:
                      accent.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 24,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    GoogleFonts.poppins(
                  color:
                      whiteColor,
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RECENT HEADER
  // ============================================================

  Widget _buildRecentHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Recent Claims',
            style:
                GoogleFonts.poppins(
              color: whiteColor,
              fontSize: 18,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),

        GestureDetector(
          onTap:
              _openClaimsPage,
          child: Row(
            children: [
              Text(
                'See All',
                style:
                    GoogleFonts.poppins(
                  color:
                      yellowColor,
                  fontSize: 10.5,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(
                width: 4,
              ),
              const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                color:
                    yellowColor,
                size: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RECENT CLAIM CARD
  // ============================================================

  Widget _buildModernClaimCard(
    Map<String, dynamic> claim,
  ) {
    final String claimId =
        _getClaimId(
      claim,
    );

    final String customer =
        _getValue(
      claim,
      [
        'customerName',
        'userName',
        'driverName',
        'name',
      ],
    );

    final String vehicle =
        _getValue(
      claim,
      [
        'vehicle',
        'vehicleName',
        'vehicleModel',
        'vehicleType',
      ],
    );

    final String service =
        _getValue(
      claim,
      [
        'service',
        'serviceType',
        'assistanceType',
        'issueType',
      ],
    );

    final String status =
        _getStatus(
      claim,
    );

    final String date =
        _formatClaimDate(
      claim,
    );

    final String documentId =
        claim['_documentId']
                ?.toString() ??
            '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (documentId
              .isNotEmpty) {
            _openClaimDetails(
              documentId,
            );
          }
        },
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(
            14,
          ),
          decoration:
              BoxDecoration(
            color: cardColor,
            borderRadius:
                BorderRadius.circular(
              17,
            ),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Container(
                width: 49,
                height: 49,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF20272D,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  _getClaimIcon(
                    service,
                    vehicle,
                  ),
                  color:
                      const Color(
                    0xFFD4DADE,
                  ),
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child: Text(
                            claimId,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                GoogleFonts.poppins(
                              color:
                                  yellowColor,
                              fontSize:
                                  12,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        _buildModernStatusBadge(
                          status,
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      customer,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          GoogleFonts.poppins(
                        color:
                            whiteColor,
                        fontSize:
                            12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      '$vehicle • $service',
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          GoogleFonts.poppins(
                        color:
                            greyColor,
                        fontSize:
                            9.5,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .calendar_month_rounded,
                          color:
                              mutedColor,
                          size: 12,
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        Expanded(
                          child: Text(
                            date,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                GoogleFonts.poppins(
                              color:
                                  greyColor,
                              fontSize:
                                  9,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ),

                        Text(
                          'VERIFY',
                          style:
                              GoogleFonts.poppins(
                            color:
                                yellowColor,
                            fontSize:
                                8.5,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing:
                                0.3,
                          ),
                        ),

                        const SizedBox(
                          width: 3,
                        ),

                        const Icon(
                          Icons
                              .arrow_forward_ios_rounded,
                          color:
                              yellowColor,
                          size: 8,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CLAIM ICON
  // ============================================================

  IconData _getClaimIcon(
    String service,
    String vehicle,
  ) {
    final String value =
        '$service $vehicle'
            .toLowerCase();

    if (value.contains(
      'health',
    )) {
      return Icons
          .favorite_rounded;
    }

    if (value.contains(
          'property',
        ) ||
        value.contains(
          'fire',
        ) ||
        value.contains(
          'home',
        )) {
      return Icons
          .home_work_rounded;
    }

    if (value.contains(
          'bike',
        ) ||
        value.contains(
          'motorcycle',
        )) {
      return Icons
          .two_wheeler_rounded;
    }

    if (value.contains(
          'accident',
        ) ||
        value.contains(
          'crash',
        )) {
      return Icons
          .car_crash_rounded;
    }

    if (value.contains(
      'repair',
    )) {
      return Icons
          .car_repair_rounded;
    }

    return Icons
        .directions_car_filled_rounded;
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _buildModernStatusBadge(
    String status,
  ) {
    final String lower =
        status.toLowerCase();

    Color textColor;
    Color background;
    IconData icon;

    if (lower.contains(
      'approved',
    )) {
      textColor =
          greenColor;
      background =
          const Color(0xFF123A2A);
      icon =
          Icons.verified_rounded;
    } else if (lower.contains(
      'reject',
    )) {
      textColor =
          redColor;
      background =
          const Color(0xFF3A171A);
      icon =
          Icons.gpp_bad_rounded;
    } else if (lower.contains(
      'need information',
    )) {
      textColor =
          blueColor;
      background =
          const Color(0xFF172A47);
      icon =
          Icons.info_rounded;
    } else if (lower.contains(
      'review',
    )) {
      textColor =
          yellowColor;
      background =
          const Color(0xFF393000);
      icon =
          Icons.fact_check_rounded;
    } else {
      textColor =
          const Color(0xFFFFC107);
      background =
          const Color(0xFF3A3205);
      icon =
          Icons.pending_actions_rounded;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration:
          BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: textColor,
            size: 10,
          ),

          const SizedBox(
            width: 4,
          ),

          Text(
            status.toUpperCase(),
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.poppins(
              color: textColor,
              fontSize: 7,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY CLAIMS
  // ============================================================

  Widget _buildEmptyClaims() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 40,
        horizontal: 20,
      ),
      decoration:
          BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF20272D,
              ),
              shape:
                  BoxShape.circle,
            ),
            child:
                const Icon(
              Icons
                  .folder_open_rounded,
              color:
                  mutedColor,
              size: 30,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          Text(
            'No claims available',
            style:
                GoogleFonts.poppins(
              color:
                  whiteColor,
              fontSize: 14,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'Claims from Firestore will appear here.',
            textAlign:
                TextAlign.center,
            style:
                GoogleFonts.poppins(
              color:
                  greyColor,
              fontSize: 10,
              fontWeight:
                  FontWeight.w500,
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
        padding:
            const EdgeInsets.all(
          25,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(
            23,
          ),
          decoration:
              BoxDecoration(
            color: cardColor,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration:
                    BoxDecoration(
                  color:
                      redColor.withValues(
                    alpha: 0.10,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons
                      .error_outline_rounded,
                  color:
                      redColor,
                  size: 32,
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              Text(
                'Unable to load dashboard',
                textAlign:
                    TextAlign.center,
                style:
                    GoogleFonts.poppins(
                  color:
                      whiteColor,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              Text(
                _errorMessage ??
                    'Something went wrong.',
                textAlign:
                    TextAlign.center,
                style:
                    GoogleFonts.poppins(
                  color:
                      greyColor,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),

              const SizedBox(
                height: 19,
              ),

              SizedBox(
                height: 46,
                width:
                    double.infinity,
                child:
                    ElevatedButton(
                  onPressed:
                      _loadDashboardData,
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        yellowColor,
                    foregroundColor:
                        Colors.black,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style:
                        GoogleFonts.poppins(
                      fontWeight:
                          FontWeight.w700,
                    ),
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
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return Container(
      decoration:
          const BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child:
            BottomNavigationBar(
          currentIndex:
              _selectedIndex,
          onTap:
              _onBottomNavigationTap,
          type:
              BottomNavigationBarType
                  .fixed,
          backgroundColor:
              cardColor,
          selectedItemColor:
              yellowColor,
          unselectedItemColor:
              Color(0xFF70777E),
          selectedFontSize: 9,
          unselectedFontSize: 9,
          elevation: 0,
          iconSize: 24,
          selectedLabelStyle:
              GoogleFonts.poppins(
            fontWeight:
                FontWeight.w700,
          ),
          unselectedLabelStyle:
              GoogleFonts.poppins(
            fontWeight:
                FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(
                Icons
                    .dashboard_outlined,
              ),
              activeIcon: Icon(
                Icons
                    .dashboard_rounded,
              ),
              label: 'Dashboard',
            ),

            BottomNavigationBarItem(
              icon: Icon(
                Icons
                    .assignment_outlined,
              ),
              activeIcon: Icon(
                Icons
                    .assignment_rounded,
              ),
              label: 'Claims',
            ),

            BottomNavigationBarItem(
              icon: Icon(
                Icons
                    .analytics_outlined,
              ),
              activeIcon: Icon(
                Icons
                    .analytics_rounded,
              ),
              label: 'Reports',
            ),

            BottomNavigationBarItem(
              icon: Icon(
                Icons
                    .person_outline_rounded,
              ),
              activeIcon: Icon(
                Icons.person_rounded,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
