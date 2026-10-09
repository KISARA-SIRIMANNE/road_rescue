import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'claim_details_verification_page.dart';
import 'insurance_claim_history_page.dart';
import '../../services/insurance_company.dart';

class InsuranceClaimsPage extends StatefulWidget {
  const InsuranceClaimsPage({super.key});

  @override
  State<InsuranceClaimsPage> createState() => _InsuranceClaimsPageState();
}

class _InsuranceClaimsPageState extends State<InsuranceClaimsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _claims = [];

  bool _loading = true;
  String? _error;

  String _search = '';
  String _filter = 'All';

  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color bg = Color(0xFF070B0D);
  static const Color card = Color(0xFF11181D);
  static const Color cardSecondary = Color(0xFF1B252C);

  static const Color yellow = Color(0xFFFFD21C);

  static const Color white = Color(0xFFF5F7F8);
  static const Color muted = Color(0xFF9BA6AF);
  static const Color mutedDark = Color(0xFF68747D);
  static const Color border = Color(0xFF29353D);

  static const Color pending = Color(0xFFFFB020);
  static const Color underReview = Color(0xFF2697FF);
  static const Color approved = Color(0xFF19D98B);
  static const Color rejected = Color(0xFFFF5055);
  static const Color information = Color(0xFF2DA8FF);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  // ============================================================
  // LOAD CLAIMS
  // ============================================================

  Future<void> _loadClaims() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _firestore
          .collection('assistance_requests')
          .where('insuranceClaim', isEqualTo: true)
          .where(
            'insuranceCompanyId',
            isEqualTo: await loadCurrentInsuranceCompanyId(),
          )
          .get();

      final data = snap.docs.map((d) {
        return {...d.data(), '_documentId': d.id};
      }).toList();

      // Newest first
      data.sort((a, b) {
        final aTime = a['createdAt'] is Timestamp
            ? a['createdAt'] as Timestamp
            : null;

        final bTime = b['createdAt'] is Timestamp
            ? b['createdAt'] as Timestamp
            : null;

        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      if (!mounted) return;

      setState(() {
        _claims = data;
        _loading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _claims = [];

        _error = e.code == 'permission-denied'
            ? 'Your insurance account does not have permission to view claims.'
            : (e.message ?? 'Unable to load claims.');
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _claims = [];
        _error = 'Unable to load insurance claims.';
      });
    }
  }

  // ============================================================
  // CLAIM ID
  // ============================================================

  String _claimId(Map<String, dynamic> c) {
    final existing = '${c['claimId'] ?? ''}'.trim();

    if (existing.isNotEmpty) {
      return existing;
    }

    final id = '${c['requestId'] ?? c['_documentId'] ?? ''}';

    if (id.isEmpty) {
      return 'INSURANCE CLAIM';
    }

    final short = id.length > 6
        ? id.substring(id.length - 6).toUpperCase()
        : id.toUpperCase();

    return 'CLM-$short';
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _status(Map<String, dynamic> c) {
    switch ('${c['insuranceStatus'] ?? 'pending'}'.toLowerCase()) {
      case 'under_review':
      case 'under review':
        return 'Under Review';

      case 'approved':
        return 'Approved';

      case 'rejected':
        return 'Rejected';

      case 'need_information':
      case 'needs_information':
      case 'need information':
        return 'Need Information';

      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return approved;

      case 'Rejected':
        return rejected;

      case 'Under Review':
        return underReview;

      case 'Need Information':
        return information;

      default:
        return pending;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle_rounded;

      case 'Rejected':
        return Icons.cancel_rounded;

      case 'Under Review':
        return Icons.description_rounded;

      case 'Need Information':
        return Icons.info_rounded;

      default:
        return Icons.schedule_rounded;
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _date(Map<String, dynamic> c) {
    final t = c['createdAt'];

    if (t is Timestamp) {
      final d = t.toDate();

      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    }

    return 'Date unavailable';
  }

  // ============================================================
  // FILTERED CLAIMS
  // ============================================================

  List<Map<String, dynamic>> get _visible {
    final q = _search.trim().toLowerCase();

    return _claims.where((c) {
      final s = _status(c);

      if (_filter != 'All' && s != _filter) {
        return false;
      }

      if (q.isEmpty) {
        return true;
      }

      return [
        _claimId(c),
        c['userName'],
        c['vehicleType'],
        c['issueType'],
        c['insuranceCompany'],
        c['policyNumber'],
      ].map((v) => '$v'.toLowerCase()).any((v) => v.contains(q));
    }).toList();
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int _count(String status) {
    return _claims.where((claim) => _status(claim) == status).length;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: yellow,
                backgroundColor: card,
                onRefresh: _loadClaims,
                child: _loading
                    ? _buildLoading()
                    : _error != null
                    ? _errorView()
                    : _buildContent(),
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
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 22),

          _buildSearch(),

          const SizedBox(height: 14),

          _buildFilters(),

          const SizedBox(height: 20),

          _buildStats(),

          const SizedBox(height: 25),

          _buildResultsHeader(),

          const SizedBox(height: 13),

          if (_visible.isEmpty)
            _emptyView()
          else
            ..._visible.map(
              (claim) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _buildClaimCard(claim),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Claims Management',
                style: GoogleFonts.poppins(
                  color: white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                'Review and manage insurance claims',
                style: GoogleFonts.poppins(
                  color: muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        _buildIconButton(
          icon: Icons.history_rounded,
          iconColor: yellow,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InsuranceClaimHistoryPage(),
              ),
            );

            _loadClaims();
          },
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: iconColor, size: 23),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return Container(
      height: 57,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _search = value;
          });
        },
        style: GoogleFonts.poppins(
          color: white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: yellow,
        decoration: InputDecoration(
          hintText: 'Search claims, customer, vehicle...',
          hintStyle: GoogleFonts.poppins(
            color: const Color(0xFF7F8B94),
            fontSize: 11.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9BA6AF),
            size: 26,
          ),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      _search = '';
                    });
                  },
                  icon: const Icon(Icons.close_rounded, color: muted, size: 18),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    const filters = ['All', 'Pending', 'Under Review', 'Approved', 'Rejected'];

    return SizedBox(
      height: 47,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = filters[index];

          final selected = _filter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _filter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? yellow : card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: selected ? yellow : border),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: yellow.withValues(alpha: 0.20),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filter != 'All') ...[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.black.withValues(alpha: 0.10)
                            : _statusColor(filter).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _statusIcon(filter),
                        color: selected ? Colors.black : _statusColor(filter),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    filter,
                    style: GoogleFonts.poppins(
                      color: selected ? Colors.black : white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStats() {
    return SizedBox(
      height: 135,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatCard(
            title: 'Total Claims',
            value: '${_claims.length}',
            icon: Icons.description_rounded,
            color: yellow,
          ),
          const SizedBox(width: 11),
          _buildStatCard(
            title: 'Pending',
            value: '${_count('Pending')}',
            icon: Icons.schedule_rounded,
            color: pending,
          ),
          const SizedBox(width: 11),
          _buildStatCard(
            title: 'Under Review',
            value: '${_count('Under Review')}',
            icon: Icons.manage_search_rounded,
            color: underReview,
          ),
          const SizedBox(width: 11),
          _buildStatCard(
            title: 'Approved',
            value: '${_count('Approved')}',
            icon: Icons.check_circle_rounded,
            color: approved,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.12), card],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
          ),

          const Spacer(),

          Text(
            value,
            style: GoogleFonts.poppins(
              color: white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULTS HEADER
  // ============================================================

  Widget _buildResultsHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Insurance Claims',
                style: GoogleFonts.poppins(
                  color: white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Review and process submitted claims',
                style: GoogleFonts.poppins(
                  color: muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cardSecondary,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: border),
          ),
          child: Text(
            '${_visible.length} results',
            style: GoogleFonts.poppins(
              color: muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CLAIM CARD
  // ============================================================

  Widget _buildClaimCard(Map<String, dynamic> c) {
    final status = _status(c);

    final company = '${c['insuranceCompany'] ?? ''}';

    final policy = '${c['policyNumber'] ?? ''}';

    final customer = '${c['userName'] ?? 'Unknown Driver'}';

    final vehicle = '${c['vehicleType'] ?? 'Vehicle unavailable'}';

    final issue = '${c['issueType'] ?? 'Roadside Assistance'}';

    final documentId = '${c['_documentId'] ?? ''}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (documentId.isEmpty) {
            _message('Request ID is unavailable.');
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClaimDetailsVerificationPage(claimId: documentId),
            ),
          ).then((_) {
            _loadClaims();
          });
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClaimIcon(issue),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${_claimId(c)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                            const SizedBox(width: 7),

                            _statusBadge(status),
                          ],
                        ),

                        const SizedBox(height: 5),

                        Text(
                          customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          '$vehicle  •  $issue',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFFB3BDC4),
                    size: 14,
                  ),
                ],
              ),

              const SizedBox(height: 13),

              Container(height: 1, color: border),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _miniInfo(Icons.calendar_today_rounded, _date(c)),
                  ),
                  if (company.isNotEmpty)
                    Expanded(child: _miniInfo(Icons.business_rounded, company)),
                ],
              ),

              if (policy.isNotEmpty) ...[
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: _miniInfo(Icons.badge_rounded, 'Policy: $policy'),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              Container(
                height: 37,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2126),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View Claim Details',
                      style: GoogleFonts.poppins(
                        color: yellow,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: yellow,
                      size: 9,
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

  Widget _buildClaimIcon(String issue) {
    final value = issue.toLowerCase();

    IconData icon = Icons.directions_car_rounded;

    if (value.contains('fire') ||
        value.contains('home') ||
        value.contains('property')) {
      icon = Icons.home_rounded;
    } else if (value.contains('health')) {
      icon = Icons.favorite_rounded;
    } else if (value.contains('bike') || value.contains('motorcycle')) {
      icon = Icons.two_wheeler_rounded;
    } else if (value.contains('battery')) {
      icon = Icons.battery_charging_full_rounded;
    } else if (value.contains('towing') || value.contains('tow')) {
      icon = Icons.local_shipping_rounded;
    } else if (value.contains('repair')) {
      icon = Icons.build_rounded;
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: cardSecondary,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: const Color(0xFFB8C1C8), size: 29),
    );
  }

  // ============================================================
  // MINI INFO
  // ============================================================

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: mutedDark, size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: muted,
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _emptyView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 22),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: cardSecondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: mutedDark,
              size: 34,
            ),
          ),

          const SizedBox(height: 17),

          Text(
            'No Claims Found',
            style: GoogleFonts.poppins(
              color: white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            _search.isNotEmpty || _filter != 'All'
                ? 'Try changing your search or filter.'
                : 'Insurance claims will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: muted,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),

          if (_search.isNotEmpty || _filter != 'All') ...[
            const SizedBox(height: 18),

            OutlinedButton(
              onPressed: () {
                setState(() {
                  _search = '';
                  _filter = 'All';
                });
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: yellow),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                'Clear Filters',
                style: GoogleFonts.poppins(
                  color: yellow,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorView() {
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
                  color: rejected.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: rejected,
                  size: 34,
                ),
              ),

              const SizedBox(height: 17),

              Text(
                'Claims Access Unavailable',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: muted,
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _loadClaims,
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
  // MESSAGE
  // ============================================================

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.poppins(fontSize: 11)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF242B30),
      ),
    );
  }
}
