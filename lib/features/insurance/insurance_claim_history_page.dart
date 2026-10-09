import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import 'claim_details_verification_page.dart';
import '../../services/insurance_company.dart';

class InsuranceClaimHistoryPage extends StatefulWidget {
  const InsuranceClaimHistoryPage({super.key});

  @override
  State<InsuranceClaimHistoryPage> createState() =>
      _InsuranceClaimHistoryPageState();
}

class _InsuranceClaimHistoryPageState extends State<InsuranceClaimHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _claims = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedFilter = 'All';
  String _sortOption = 'Newest first';

  final List<String> _filters = [
    'All',
    'Pending',
    'Under Review',
    'Approved',
    'Rejected',
    'Need Information',
  ];

  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color bg = RoadRescueColors.background;
  static const Color card = RoadRescueColors.surface;
  static const Color cardSecondary = RoadRescueColors.surface;

  static const Color yellow = RoadRescueColors.accent;
  static const Color white = RoadRescueColors.foreground;
  static const Color muted = RoadRescueColors.muted;
  static const Color mutedDark = RoadRescueColors.mutedDark;
  static const Color border = RoadRescueColors.border;

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

    _loadClaimHistory();

    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CLAIMS
  // ============================================================

  Future<void> _loadClaimHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('assistance_requests')
          .where('insuranceClaim', isEqualTo: true)
          .where(
            'insuranceCompanyId',
            isEqualTo: await loadCurrentInsuranceCompanyId(),
          )
          .get();

      final List<Map<String, dynamic>> loadedClaims = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        loadedClaims.add({...data, '_documentId': doc.id});
      }

      loadedClaims.sort((a, b) {
        final Timestamp? dateA = a['updatedAt'] is Timestamp
            ? a['updatedAt'] as Timestamp
            : a['createdAt'] is Timestamp
            ? a['createdAt'] as Timestamp
            : null;

        final Timestamp? dateB = b['updatedAt'] is Timestamp
            ? b['updatedAt'] as Timestamp
            : b['createdAt'] is Timestamp
            ? b['createdAt'] as Timestamp
            : null;

        if (dateA == null && dateB == null) {
          return 0;
        }

        if (dateA == null) {
          return 1;
        }

        if (dateB == null) {
          return -1;
        }

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _claims = loadedClaims;
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        if (e.code == 'permission-denied') {
          _errorMessage =
              'You do not have permission to access insurance claims.';
        } else {
          _errorMessage = 'Unable to load claim history. Please try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong while loading claim history.';
      });
    }
  }

  Future<void> _deleteClaim(Map<String, dynamic> claim) async {
    final documentId = claim['_documentId']?.toString();
    if (documentId == null || documentId.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: rejected.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: rejected,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete claim?',
              style: GoogleFonts.poppins(
                color: white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'This claim will be permanently removed from claim history.',
          style: GoogleFonts.poppins(color: muted, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: rejected,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestore
          .collection('assistance_requests')
          .doc(documentId)
          .delete();

      if (!mounted) return;

      setState(() {
        _claims.removeWhere(
          (item) => item['_documentId']?.toString() == documentId,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Claim deleted successfully.'),
          backgroundColor: cardSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      final message = e.code == 'permission-denied'
          ? 'Delete permission denied. Publish the latest Firestore rules and try again.'
          : e.message ?? 'Unable to delete claim.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: rejected,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Claim history delete error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete claim. Please try again.'),
          backgroundColor: rejected,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>> get _filteredClaims {
    final search = _searchController.text.trim().toLowerCase();

    final List<Map<String, dynamic>> filtered = _claims.where((claim) {
      final rawStatus =
          (claim['insuranceStatus'] ?? claim['status'] ?? 'pending')
              .toString()
              .toLowerCase();

      final normalizedStatus = _normalizeStatus(rawStatus);

      final matchesFilter =
          _selectedFilter == 'All' || normalizedStatus == _selectedFilter;

      if (!matchesFilter) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final claimId = (claim['requestId'] ?? claim['_documentId'] ?? '')
          .toString()
          .toLowerCase();

      final driverName = (claim['userName'] ?? '').toString().toLowerCase();

      final vehicle = (claim['vehicleType'] ?? '').toString().toLowerCase();

      final issue = (claim['issueType'] ?? '').toString().toLowerCase();

      return claimId.contains(search) ||
          driverName.contains(search) ||
          vehicle.contains(search) ||
          issue.contains(search);
    }).toList();

    filtered.sort((a, b) {
      if (_sortOption == 'Oldest first') {
        return _claimDate(a).compareTo(_claimDate(b));
      }

      if (_sortOption == 'Status') {
        final statusA = _normalizeStatus(
          (a['insuranceStatus'] ?? a['status'] ?? 'pending')
              .toString()
              .toLowerCase(),
        );
        final statusB = _normalizeStatus(
          (b['insuranceStatus'] ?? b['status'] ?? 'pending')
              .toString()
              .toLowerCase(),
        );
        return statusA.compareTo(statusB);
      }

      return _claimDate(b).compareTo(_claimDate(a));
    });

    return filtered;
  }

  DateTime _claimDate(Map<String, dynamic> claim) {
    final value = claim['updatedAt'] ?? claim['createdAt'];
    return value is Timestamp ? value.toDate() : DateTime(2000);
  }

  Future<void> _showSortMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Sort claims',
                style: GoogleFonts.poppins(
                  color: white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final option in ['Newest first', 'Oldest first', 'Status'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    option == 'Status'
                        ? Icons.sort_by_alpha_rounded
                        : Icons.schedule_rounded,
                    color: _sortOption == option ? yellow : muted,
                  ),
                  title: Text(
                    option,
                    style: GoogleFonts.poppins(
                      color: _sortOption == option ? yellow : white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: _sortOption == option
                      ? const Icon(Icons.check_rounded, color: yellow)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _sortOption = selected);
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _normalizeStatus(String status) {
    switch (status) {
      case 'under_review':
      case 'under review':
        return 'Under Review';

      case 'need_information':
      case 'need information':
        return 'Need Information';

      case 'approved':
        return 'Approved';

      case 'rejected':
        return 'Rejected';

      case 'pending':
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

      case 'Pending':
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

      case 'Pending':
      default:
        return Icons.schedule_rounded;
    }
  }

  IconData _claimIcon(String issue) {
    final value = issue.toLowerCase();

    if (value.contains('battery')) {
      return Icons.battery_charging_full_rounded;
    }

    if (value.contains('towing') || value.contains('tow')) {
      return Icons.local_shipping_rounded;
    }

    if (value.contains('repair')) {
      return Icons.build_rounded;
    }

    if (value.contains('bike') || value.contains('motorcycle')) {
      return Icons.two_wheeler_rounded;
    }

    if (value.contains('truck')) {
      return Icons.local_shipping_rounded;
    }

    return Icons.directions_car_rounded;
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      return '$day/$month/$year';
    }

    return 'Not available';
  }

  // ============================================================
  // STAT COUNTS
  // ============================================================

  int _countStatus(String status) {
    return _claims.where((claim) {
      final raw = (claim['insuranceStatus'] ?? claim['status'] ?? 'pending')
          .toString()
          .toLowerCase();

      return _normalizeStatus(raw) == status;
    }).length;
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
        child: _isLoading
            ? _buildLoading()
            : _errorMessage != null
            ? _buildErrorState()
            : Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      color: yellow,
                      backgroundColor: card,
                      onRefresh: _loadClaimHistory,
                      child: _buildContent(),
                    ),
                  ),
                  _buildBottomNavigation(),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: yellow, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading claims...',
            style: GoogleFonts.poppins(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildContent() {
    final filteredClaims = _filteredClaims;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 20),

          _buildSearch(),

          const SizedBox(height: 14),

          _buildFilterBar(),

          const SizedBox(height: 18),

          _buildSummaryCards(),

          const SizedBox(height: 25),

          _buildHistoryHeader(filteredClaims.length),

          const SizedBox(height: 13),

          if (filteredClaims.isEmpty)
            _buildEmptyState()
          else
            ...filteredClaims.map((claim) => _buildClaimCard(claim)),
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
                'Claims',
                style: GoogleFonts.poppins(
                  color: white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'All insurance claims and their status',
                style: GoogleFonts.poppins(
                  color: muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        _buildHeaderButton(
          icon: Icons.filter_alt_rounded,
          iconColor: yellow,
          onTap: _showFilterSheet,
        ),
      ],
    );
  }

  Widget _buildHeaderButton({
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
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        cursorColor: yellow,
        style: GoogleFonts.poppins(
          color: white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9AA6B0),
            size: 29,
          ),
          hintText: 'Search by claim ID, name, vehicle...',
          hintStyle: GoogleFonts.poppins(
            color: const Color(0xFF8A969F),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.close_rounded, color: muted, size: 19),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _buildFilterBar() {
    return SizedBox(
      height: 47,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
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
                          color: yellow.withValues(alpha: 0.22),
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
                            : _statusColor(filter).withValues(alpha: 0.15),
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
                      fontSize: 10.5,
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
  // SUMMARY CARDS
  // ============================================================

  Widget _buildSummaryCards() {
    return SizedBox(
      height: 138,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildSummaryCard(
            title: 'Total Claims',
            value: _claims.length.toString(),
            icon: Icons.description_rounded,
            color: yellow,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            title: 'Pending',
            value: _countStatus('Pending').toString(),
            icon: Icons.schedule_rounded,
            color: pending,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            title: 'Under Review',
            value: _countStatus('Under Review').toString(),
            icon: Icons.description_rounded,
            color: underReview,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            title: 'Approved',
            value: _countStatus('Approved').toString(),
            icon: Icons.check_circle_rounded,
            color: approved,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.13), card.withValues(alpha: 0.92)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
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
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY HEADER
  // ============================================================

  Widget _buildHistoryHeader(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Claim list',
                style: GoogleFonts.poppins(
                  color: white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'Sort',
              style: GoogleFonts.poppins(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showSortMenu,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Text(
                      _sortOption,
                      style: GoogleFonts.poppins(
                        color: white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: muted,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '$count ${count == 1 ? 'claim' : 'claims'} available',
          style: GoogleFonts.poppins(
            color: muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CLAIM CARD
  // ============================================================

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final documentId = claim['_documentId'].toString();

    final claimId = (claim['requestId'] ?? documentId).toString();

    final driverName = (claim['userName'] ?? 'Unknown Driver').toString();

    final vehicle = (claim['vehicleType'] ?? 'Vehicle not available')
        .toString();

    final issue = (claim['issueType'] ?? 'Accident Assistance').toString();

    final status = _normalizeStatus(
      (claim['insuranceStatus'] ?? claim['status'] ?? 'pending')
          .toString()
          .toLowerCase(),
    );

    final date = _formatDate(claim['updatedAt'] ?? claim['createdAt']);

    final statusColor = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ClaimDetailsVerificationPage(claimId: documentId),
              ),
            ).then((_) {
              _loadClaimHistory();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // VEHICLE ICON
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: cardSecondary,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: border),
                  ),
                  child: Icon(
                    _claimIcon(issue),
                    color: const Color(0xFFB9C2C9),
                    size: 30,
                  ),
                ),

                const SizedBox(width: 13),

                // DETAILS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$claimId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: white,
                          fontSize: 11.5,
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

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: mutedDark,
                            size: 12,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            date,
                            style: GoogleFonts.poppins(
                              color: muted,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // STATUS + ARROW
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatusBadge(status, statusColor),

                    const SizedBox(height: 7),

                    IconButton(
                      tooltip: 'Delete claim',
                      onPressed: () => _deleteClaim(claim),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: muted,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;

    final hasFilter = _selectedFilter != 'All';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 24),
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
            hasSearch || hasFilter
                ? 'Try changing your search or filter.'
                : 'Insurance claim history will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: muted,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),

          if (hasSearch || hasFilter) ...[
            const SizedBox(height: 17),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedFilter = 'All';
                  _searchController.clear();
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

  Widget _buildErrorState() {
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
                'Unable to Load History',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _errorMessage ?? 'Please try again later.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: muted,
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _loadClaimHistory,
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
  // FILTER BOTTOM SHEET
  // ============================================================

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          decoration: const BoxDecoration(
            color: card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: mutedDark,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(Icons.filter_alt_rounded, color: yellow, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Filter Claims',
                    style: GoogleFonts.poppins(
                      color: white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              ..._filters.map((filter) {
                final selected = _selectedFilter == filter;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? yellow.withValues(alpha: 0.12)
                              : cardSecondary,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: selected ? yellow : border),
                        ),
                        child: Row(
                          children: [
                            if (filter == 'All')
                              const Icon(
                                Icons.apps_rounded,
                                color: yellow,
                                size: 20,
                              )
                            else
                              Icon(
                                _statusIcon(filter),
                                color: _statusColor(filter),
                                size: 20,
                              ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                filter,
                                style: GoogleFonts.poppins(
                                  color: white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            if (selected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: yellow,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1216),
        border: Border(top: BorderSide(color: border.withValues(alpha: 0.8))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -7),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildNavItem(
            icon: Icons.home_rounded,
            label: 'Dashboard',
            selected: false,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          _buildNavItem(
            icon: Icons.description_rounded,
            label: 'Claims',
            selected: true,
            onTap: () {},
          ),
          _buildNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            selected: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reports section'),
                  backgroundColor: cardSecondary,
                ),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            selected: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile section'),
                  backgroundColor: cardSecondary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? yellow : const Color(0xFFB1BBC3),
              size: 25,
            ),

            const SizedBox(height: 5),

            Text(
              label,
              style: GoogleFonts.poppins(
                color: selected ? yellow : const Color(0xFFB1BBC3),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),

            const SizedBox(height: 4),

            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 35 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
