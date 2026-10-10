import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';

import 'vehicle_owner_home_page.dart';
import 'request_assistance_page.dart';

class InsuranceClaimResultPage extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final Map<String, dynamic> userData;
  final String issue;

  const InsuranceClaimResultPage({
    super.key,
    required this.requestData,
    required this.userData,
    required this.issue,
  });

  bool get _isApproved =>
      requestData['insuranceStatus']?.toString().toLowerCase() == 'approved';

  @override
  Widget build(BuildContext context) {
    final bool approved = _isApproved;
    final String company =
        requestData['insuranceCompany']?.toString().trim() ?? '';
    final String reviewNote =
        requestData['insuranceReviewNote']?.toString().trim() ?? '';
    final String requestId =
        requestData['requestId']?.toString() ??
        requestData['id']?.toString() ??
        '';

    return Scaffold(
      backgroundColor: RoadRescueColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: approved
                          ? const Color(0xFF183C2A)
                          : const Color(0xFF402326),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      approved
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: approved
                          ? const Color(0xFF7DE0A3)
                          : RoadRescueColors.error,
                      size: 54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    approved ? 'Claim Approved' : 'Claim Rejected',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: RoadRescueColors.foreground,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    approved
                        ? 'Your insurance provider approved your claim.'
                        : 'Your insurance provider did not approve this claim.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: RoadRescueColors.muted,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: RoadRescueColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: RoadRescueColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow('Service', issue),
                        if (company.isNotEmpty)
                          _detailRow('Insurance provider', company),
                        if (requestId.isNotEmpty)
                          _detailRow(
                            'Claim reference',
                            requestId.length > 10
                                ? requestId.substring(0, 10)
                                : requestId,
                          ),
                        if (reviewNote.isNotEmpty) ...[
                          const Divider(height: 24),
                          const Text(
                            'Provider note',
                            style: TextStyle(
                              color: RoadRescueColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reviewNote,
                            style: const TextStyle(
                              color: RoadRescueColors.foreground,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: approved
                          ? () => _goToHome(context)
                          : () => _requestAgain(context),
                      child: Text(
                        approved ? 'Back to RoadRescue' : 'Request again',
                      ),
                    ),
                  ),
                  if (!approved) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _goToHome(context),
                      child: const Text('Back to RoadRescue'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: const TextStyle(
                color: RoadRescueColors.muted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: RoadRescueColors.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (context) => VehicleOwnerHomePage(userData: userData),
      ),
      (route) => false,
    );
  }

  void _requestAgain(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => RequestAssistancePage(
          userData: userData,
          initialIssue: null,
          initialCustomIssue: '',
          initialInsuranceCompanyId: requestData['insuranceCompanyId']
              ?.toString(),
          initialPolicyNumber: requestData['policyNumber']?.toString() ?? '',
          initialInsuranceDescription:
              requestData['insuranceDescription']?.toString() ?? '',
          startInsuranceClaim: true,
        ),
      ),
    );
  }
}
