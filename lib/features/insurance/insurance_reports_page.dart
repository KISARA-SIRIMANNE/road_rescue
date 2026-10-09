import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InsuranceReportsPage extends StatefulWidget {
  const InsuranceReportsPage({super.key});

  @override
  State<InsuranceReportsPage> createState() => _InsuranceReportsPageState();
}

class _InsuranceReportsPageState extends State<InsuranceReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _errorMessage;

  int _totalClaims = 0;
  int _pendingClaims = 0;
  int _underReviewClaims = 0;
  int _approvedClaims = 0;
  int _rejectedClaims = 0;
  int _needInformationClaims = 0;

  List<Map<String, dynamic>> _recentClaims = [];

  // ============================================================
  // PREMIUM ROADRESCUE DESIGN SYSTEM
  // ============================================================

  static const Color _background = Color(0xFF070B0D);
  static const Color _surface = Color(0xFF11181D);
  static const Color _surfaceLight = Color(0xFF172127);
  static const Color _surfaceSecondary = Color(0xFF1B252C);
  static const Color _field = Color(0xFF0D1317);

  static const Color _yellow = Color(0xFFFFD21C);
  static const Color _white = Color(0xFFF5F7F8);
  static const Color _muted = Color(0xFF9BA6AF);
  static const Color _mutedDark = Color(0xFF68747D);
  static const Color _border = Color(0xFF29353D);

  static const Color _green = Color(0xFF19D98B);
  static const Color _red = Color(0xFFFF5055);
  static const Color _blue = Color(0xFF2697FF);
  static const Color _orange = Color(0xFFFFA726);
  static const Color _purple = Color(0xFFB36BFF);

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  // ============================================================
  // FIREBASE
  // ============================================================

  Future<void> _loadReportData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('assistance_requests')
          .where('insuranceClaim', isEqualTo: true)
          .get();

      int pending = 0;
      int underReview = 0;
      int approved = 0;
      int rejected = 0;
      int needInformation = 0;

      final List<Map<String, dynamic>> claims = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final String status = _getStatus(data);

        switch (status) {
          case 'pending':
            pending++;
            break;

          case 'under_review':
            underReview++;
            break;

          case 'approved':
            approved++;
            break;

          case 'rejected':
            rejected++;
            break;

          case 'need_information':
            needInformation++;
            break;
        }

        claims.add({...data, '_documentId': doc.id});
      }

      claims.sort((a, b) {
        final DateTime dateA = _getDate(a['createdAt']);
        final DateTime dateB = _getDate(b['createdAt']);

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _totalClaims = claims.length;
        _pendingClaims = pending;
        _underReviewClaims = underReview;
        _approvedClaims = approved;
        _rejectedClaims = rejected;
        _needInformationClaims = needInformation;
        _recentClaims = claims.take(5).toList();
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _errorMessage = e.code == 'permission-denied'
            ? 'You do not have permission to view insurance reports.'
            : 'Unable to load reports. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong while loading reports.';
      });
    }
  }

  String _getStatus(Map<String, dynamic> data) {
    final dynamic insuranceStatus = data['insuranceStatus'];
    final dynamic status = data['status'];

    final String value = (insuranceStatus ?? status ?? 'pending')
        .toString()
        .toLowerCase();

    switch (value) {
      case 'approved':
        return 'approved';

      case 'rejected':
        return 'rejected';

      case 'under_review':
      case 'under review':
      case 'review':
        return 'under_review';

      case 'need_information':
      case 'need information':
      case 'information_required':
        return 'need_information';

      case 'pending':
      default:
        return 'pending';
    }
  }

  DateTime _getDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime(2000);
    }

    return DateTime(2000);
  }

  String _formatDate(dynamic value) {
    final DateTime date = _getDate(value);

    if (date.year == 2000) {
      return 'Date unavailable';
    }

    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = date.year.toString();

    return '$day/$month/$year';
  }

  double get _approvalRate {
    if (_totalClaims == 0) return 0;

    return (_approvedClaims / _totalClaims) * 100;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INSURANCE PORTAL',
                  style: GoogleFonts.poppins(
                    color: _yellow,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reports & Analytics',
                  style: GoogleFonts.poppins(
                    color: _white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          _buildIconButton(
            icon: Icons.refresh_rounded,
            iconColor: _yellow,
            onTap: _loadReportData,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = _white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      color: _yellow,
      backgroundColor: _surface,
      onRefresh: _loadReportData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 35),
        children: [
          _buildHeroCard(),

          const SizedBox(height: 18),

          _buildSectionTitle(
            'CLAIMS OVERVIEW',
            'Current insurance portfolio performance',
          ),

          const SizedBox(height: 10),

          _buildOverviewCard(),

          const SizedBox(height: 20),

          _buildSectionTitle('CLAIM STATISTICS', 'Breakdown by current status'),

          const SizedBox(height: 10),

          _buildStatisticsGrid(),

          const SizedBox(height: 20),

          _buildStatusDistribution(),

          const SizedBox(height: 20),

          _buildApprovalRateCard(),

          const SizedBox(height: 20),

          _buildRecentActivity(),
        ],
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surfaceLight, _surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _yellow.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _yellow.withValues(alpha: 0.22),
                  _yellow.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _yellow.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: _yellow,
              size: 29,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claims Analytics',
                  style: GoogleFonts.poppins(
                    color: _white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Monitor claim performance, decisions and overall approval activity.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
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
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: _white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: _mutedDark,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OVERVIEW
  // ============================================================

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD21C), Color(0xFFFFC107)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _yellow.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_rounded,
              color: Colors.black,
              size: 29,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL CLAIMS',
                  style: GoogleFonts.poppins(
                    color: Colors.black.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '$_totalClaims',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Insurance claims received',
                  style: GoogleFonts.poppins(
                    color: Colors.black.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.black,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 11,
      mainAxisSpacing: 11,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          title: 'Pending',
          value: _pendingClaims,
          icon: Icons.pending_actions_rounded,
          color: _orange,
        ),

        _buildStatCard(
          title: 'Under Review',
          value: _underReviewClaims,
          icon: Icons.manage_search_rounded,
          color: _blue,
        ),

        _buildStatCard(
          title: 'Approved',
          value: _approvedClaims,
          icon: Icons.verified_rounded,
          color: _green,
        ),

        _buildStatCard(
          title: 'Rejected',
          value: _rejectedClaims,
          icon: Icons.cancel_rounded,
          color: _red,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 39,
                width: 39,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),

              const Spacer(),

              Text(
                '$value',
                style: GoogleFonts.poppins(
                  color: _white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const Spacer(),

          Text(
            title,
            style: GoogleFonts.poppins(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS DISTRIBUTION
  // ============================================================

  Widget _buildStatusDistribution() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSmallIcon(Icons.pie_chart_rounded, _yellow),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claim Status',
                      style: GoogleFonts.poppins(
                        color: _white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    Text(
                      'Distribution across all claims',
                      style: GoogleFonts.poppins(
                        color: _mutedDark,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          _buildProgressRow(
            label: 'Approved',
            value: _approvedClaims,
            total: _totalClaims,
            color: _green,
            icon: Icons.verified_rounded,
          ),

          const SizedBox(height: 16),

          _buildProgressRow(
            label: 'Pending',
            value: _pendingClaims,
            total: _totalClaims,
            color: _orange,
            icon: Icons.pending_actions_rounded,
          ),

          const SizedBox(height: 16),

          _buildProgressRow(
            label: 'Under Review',
            value: _underReviewClaims,
            total: _totalClaims,
            color: _blue,
            icon: Icons.manage_search_rounded,
          ),

          const SizedBox(height: 16),

          _buildProgressRow(
            label: 'Rejected',
            value: _rejectedClaims,
            total: _totalClaims,
            color: _red,
            icon: Icons.cancel_rounded,
          ),

          const SizedBox(height: 16),

          _buildProgressRow(
            label: 'Need Information',
            value: _needInformationClaims,
            total: _totalClaims,
            color: _purple,
            icon: Icons.info_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required int value,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final double percentage = total == 0 ? 0 : (value / total).clamp(0.0, 1.0);

    final int percentageValue = total == 0
        ? 0
        : ((value / total) * 100).round();

    return Column(
      children: [
        Row(
          children: [
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            Text(
              '$value',
              style: GoogleFonts.poppins(
                color: _white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(width: 7),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$percentageValue%',
                style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.055),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // APPROVAL RATE
  // ============================================================

  Widget _buildApprovalRateCard() {
    return _buildCard(
      borderColor: _green.withValues(alpha: 0.16),
      child: Row(
        children: [
          SizedBox(
            height: 86,
            width: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 86,
                  width: 86,
                  child: CircularProgressIndicator(
                    value: _approvalRate / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    valueColor: const AlwaysStoppedAnimation<Color>(_green),
                  ),
                ),

                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_approvalRate.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        color: _white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    Text(
                      'RATE',
                      style: GoogleFonts.poppins(
                        color: _mutedDark,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: _green,
                        size: 17,
                      ),
                    ),

                    const SizedBox(width: 9),

                    Text(
                      'Approval Rate',
                      style: GoogleFonts.poppins(
                        color: _white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                Text(
                  'Percentage of claims approved by the insurance officer.',
                  style: GoogleFonts.poppins(
                    color: _muted,
                    fontSize: 10.5,
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
  // RECENT ACTIVITY
  // ============================================================

  Widget _buildRecentActivity() {
    return _buildCard(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSmallIcon(Icons.history_rounded, _yellow),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Claim Activity',
                      style: GoogleFonts.poppins(
                        color: _white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    Text(
                      'Latest insurance submissions',
                      style: GoogleFonts.poppins(
                        color: _mutedDark,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _yellow.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_recentClaims.length} recent',
                  style: GoogleFonts.poppins(
                    color: _yellow,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (_recentClaims.isEmpty)
            _buildEmptyActivity()
          else
            ..._recentClaims.map(_buildRecentClaimItem),
        ],
      ),
    );
  }

  Widget _buildRecentClaimItem(Map<String, dynamic> claim) {
    final String status = _getStatus(claim);

    final String claimId =
        (claim['claimId'] ?? claim['requestId'] ?? claim['_documentId'])
            .toString();

    final String driverName =
        (claim['userName'] ?? claim['driverName'] ?? 'Unknown Driver')
            .toString();

    final String issue =
        (claim['issueType'] ?? claim['issue'] ?? 'Roadside Assistance')
            .toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final String documentId = claim['_documentId'].toString();

          debugPrint('Selected claim: $documentId');

          // Claim details navigation can be connected here.
        },
        borderRadius: BorderRadius.circular(13),
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _statusColor(status).withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  _statusIcon(status),
                  color: _statusColor(status),
                  size: 21,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortenId(claimId),
                      style: GoogleFonts.poppins(
                        color: _white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '$driverName • $issue',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 7),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusBadge(status),

                  const SizedBox(height: 5),

                  Text(
                    _formatDate(claim['createdAt']),
                    style: GoogleFonts.poppins(
                      color: _mutedDark,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 3),

              const Icon(
                Icons.chevron_right_rounded,
                color: _mutedDark,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: _surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_rounded,
                color: _mutedDark,
                size: 25,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'No insurance claims available',
              style: GoogleFonts.poppins(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMMON CARD
  // ============================================================

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    Color? borderColor,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSmallIcon(IconData icon, Color color) {
    return Container(
      height: 37,
      width: 37,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatusBadge(String status) {
    final Color color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Text(
        _displayStatus(status),
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.25,
        ),
      ),
    );
  }

  String _shortenId(String id) {
    if (id.length <= 14) return id;

    return '${id.substring(0, 10)}...';
  }

  String _displayStatus(String status) {
    switch (status) {
      case 'under_review':
        return 'UNDER REVIEW';

      case 'need_information':
        return 'NEED INFO';

      case 'approved':
        return 'APPROVED';

      case 'rejected':
        return 'REJECTED';

      default:
        return 'PENDING';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return _green;

      case 'rejected':
        return _red;

      case 'under_review':
        return _blue;

      case 'need_information':
        return _purple;

      default:
        return _orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.verified_rounded;

      case 'rejected':
        return Icons.cancel_rounded;

      case 'under_review':
        return Icons.manage_search_rounded;

      case 'need_information':
        return Icons.info_rounded;

      default:
        return Icons.pending_actions_rounded;
    }
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: _border),
            ),
            child: const Center(
              child: SizedBox(
                height: 25,
                width: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _yellow,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Loading reports...',
            style: GoogleFonts.poppins(
              color: _white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Preparing insurance analytics',
            style: GoogleFonts.poppins(color: _mutedDark, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.09),
                shape: BoxShape.circle,
                border: Border.all(color: _red.withValues(alpha: 0.15)),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _red,
                size: 34,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Unable to Load Reports',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              _errorMessage ?? 'Something went wrong while loading reports.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _loadReportData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _yellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: Text(
                  'Try Again',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
