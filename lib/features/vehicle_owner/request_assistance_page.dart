import 'package:flutter/material.dart';
import 'package:road_rescue/features/vehicle_owner/location_confirmation_page.dart';

class RequestAssistancePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const RequestAssistancePage({
    super.key,
    required this.userData,
  });

  @override
  State<RequestAssistancePage> createState() =>
      _RequestAssistancePageState();
}

class _RequestAssistancePageState extends State<RequestAssistancePage> {
  final TextEditingController _customIssueController =
      TextEditingController();

  String? _selectedIssue;

  final List<Map<String, dynamic>> _commonIssues = [
    {
      'title': 'Flat Tire',
      'subtitle': 'I have a flat or damaged tire',
      'icon': Icons.tire_repair,
    },
    {
      'title': 'Battery Issue',
      'subtitle': 'My vehicle battery is dead',
      'icon': Icons.battery_alert,
    },
    {
      'title': 'Towing',
      'subtitle': 'I need my vehicle towed',
      'icon': Icons.local_shipping,
    },
    {
      'title': 'Fuel Issue',
      'subtitle': 'I have run out of fuel',
      'icon': Icons.local_gas_station,
    },
  ];

  @override
  void dispose() {
    _customIssueController.dispose();
    super.dispose();
  }

  void _selectIssue(String issue) {
    setState(() {
      _selectedIssue = issue;

      if (issue != 'Custom Issue') {
        _customIssueController.clear();
      }
    });
  }

  void _submitRequest() {
    if (_selectedIssue == null) {
    _showMessage('Please select an issue first.');
    return;
  }

  if (_selectedIssue == 'Custom Issue' &&
      _customIssueController.text.trim().isEmpty) {
    _showMessage('Please describe your issue.');
    return;
  }

  final String issue = _selectedIssue == 'Custom Issue'
      ? _customIssueController.text.trim()
      : _selectedIssue!;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LocationConfirmationPage(
        userData: widget.userData,
        issue: issue,
      ),
    ),
  );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF24282D),
      ),
    );
  }

  void _showRequestCreatedDialog(String issue) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1D20),
          title: const Text(
            'Request Ready',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Your assistance request for "$issue" is ready to be submitted.',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFFF6E900),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userName =
        widget.userData['name']?.toString() ?? 'Driver';

    return Scaffold(
      backgroundColor: const Color(0xFF101214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101214),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Request Assistance',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF191C20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6E900),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.support_agent,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, $userName',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'What happened?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Select an issue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Choose the problem you are experiencing with your vehicle.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 18),

              // Common issue cards
              ..._commonIssues.map(
                (issue) => _buildIssueCard(
                  title: issue['title'] as String,
                  subtitle: issue['subtitle'] as String,
                  icon: issue['icon'] as IconData,
                ),
              ),

              // Custom issue
              _buildCustomIssueCard(),

              const SizedBox(height: 30),

              // Request button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF6E900),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.send_rounded,
                        size: 21,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Request Assistance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              const Center(
                child: Text(
                  'A nearby roadside assistance provider will be able to help you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIssueCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedIssue == title;

    return GestureDetector(
      onTap: () => _selectIssue(title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF6E900).withOpacity(0.10)
              : const Color(0xFF191C20),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF6E900)
                : Colors.white.withOpacity(0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF6E900)
                    : const Color(0xFF24282D),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.black : Colors.white70,
                size: 25,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFFF6E900)
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFFF6E900)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFF6E900)
                      : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 15,
                      color: Colors.black,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomIssueCard() {
    final bool isSelected = _selectedIssue == 'Custom Issue';

    return GestureDetector(
      onTap: () => _selectIssue('Custom Issue'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF6E900).withOpacity(0.10)
              : const Color(0xFF191C20),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF6E900)
                : Colors.white.withOpacity(0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF6E900)
                        : const Color(0xFF24282D),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: isSelected ? Colors.black : Colors.white70,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Issue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Describe another problem',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54,
                ),
              ],
            ),

            if (isSelected) ...[
              const SizedBox(height: 18),
              TextField(
                controller: _customIssueController,
                maxLines: 4,
                minLines: 3,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe your issue...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF101214),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(14),
                    ),
                    borderSide: BorderSide(
                      color: Color(0xFFF6E900),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}