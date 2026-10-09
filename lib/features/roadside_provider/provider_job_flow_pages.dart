import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const Color _pageCard = RoadRescueColors.surface;
const Color _pageBorder = Color(0xFF394149);
const Color _pageYellow = RoadRescueColors.accent;
const Color _pageMuted = RoadRescueColors.muted;

double? providerJobFee(Map<String, dynamic> data) {
  final Object? fee =
      data['earningsAmount'] ?? data['estimatedFee'] ?? data['estimatedCost'];
  return fee is num ? fee.toDouble() : null;
}

String providerJobFeeLabel(Map<String, dynamic> data) {
  final double? fee = providerJobFee(data);
  return fee == null ? 'Fee not set' : _formatRupees(fee);
}

String providerJobCustomer(Map<String, dynamic> data) =>
    data['userName']?.toString().trim().isNotEmpty == true
    ? data['userName'].toString().trim()
    : 'Customer';

String providerJobService(Map<String, dynamic> data) =>
    data['issueType']?.toString().trim().isNotEmpty == true
    ? data['issueType'].toString().trim()
    : 'Roadside assistance';

String providerJobVehicle(Map<String, dynamic> data) =>
    data['vehicleType']?.toString().trim().isNotEmpty == true
    ? data['vehicleType'].toString().trim()
    : 'Vehicle details unavailable';

LatLng? providerJobLocation(Map<String, dynamic> data) {
  final Object? latitude = data['latitude'];
  final Object? longitude = data['longitude'];
  if (latitude is! num || longitude is! num) return null;
  return LatLng(latitude.toDouble(), longitude.toDouble());
}

class ProviderRequestDetailsView extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> requestData;
  final VoidCallback onBack;
  final VoidCallback onNavigate;

  const ProviderRequestDetailsView({
    super.key,
    required this.requestId,
    required this.requestData,
    required this.onBack,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final String customer = providerJobCustomer(requestData);
    final String vehicle = providerJobVehicle(requestData);
    final String registration =
        requestData['registrationNumber']?.toString() ??
        requestData['plateNumber']?.toString() ??
        'Not provided';
    final LatLng? location = providerJobLocation(requestData);

    return _FlowPage(
      title: 'Request details',
      subtitle: 'Review the job before starting navigation',
      onBack: onBack,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _InfoCard(
            children: [
              _InfoLine(label: 'Customer', value: customer),
              _InfoLine(
                label: 'Service',
                value: providerJobService(requestData),
                accent: true,
              ),
              _InfoLine(label: 'Vehicle', value: vehicle),
              _InfoLine(label: 'Registration', value: registration),
              _InfoLine(
                label: 'Estimated fee',
                value: providerJobFeeLabel(requestData),
                accent: true,
              ),
              _InfoLine(label: 'Request ID', value: requestId, compact: true),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Customer note',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _InfoCard(
            children: [
              Text(
                requestData['customerNote']?.toString() ??
                    requestData['note']?.toString() ??
                    'No note added by the customer.',
                style: const TextStyle(color: _pageMuted, height: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: _pageYellow),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      location == null
                          ? 'Customer location is unavailable'
                          : '${location.latitude.toStringAsFixed(5)}, '
                                '${location.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          _PrimaryButton(
            label: 'Accept & Navigate',
            icon: Icons.navigation_rounded,
            onPressed: onNavigate,
          ),
        ],
      ),
    );
  }
}

class ProviderNavigationView extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback onBack;
  final VoidCallback onChat;
  final VoidCallback onStartService;

  const ProviderNavigationView({
    super.key,
    required this.requestData,
    required this.onBack,
    required this.onChat,
    required this.onStartService,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng? destination = providerJobLocation(requestData);
    final LatLng mapCenter = destination ?? const LatLng(6.9271, 79.8612);

    return _FlowPage(
      title: 'Navigate to customer',
      subtitle: destination == null
          ? 'Customer location is unavailable'
          : 'Customer location is marked on the map',
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: mapCenter,
                  zoom: 14,
                ),
                markers: destination == null
                    ? const <Marker>{}
                    : {
                        Marker(
                          markerId: const MarkerId('customer'),
                          position: destination,
                          infoWindow: InfoWindow(
                            title: providerJobCustomer(requestData),
                            snippet: 'Customer location',
                          ),
                        ),
                      },
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerJobCustomer(requestData),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${providerJobVehicle(requestData)} • '
                          '${providerJobService(requestData)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _pageMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    providerJobFeeLabel(requestData),
                    style: const TextStyle(
                      color: _pageYellow,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: 'Open Chat',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: onChat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PrimaryButton(
                  label: 'Arrived',
                  icon: Icons.check_rounded,
                  onPressed: onStartService,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProviderChatView extends StatefulWidget {
  final String requestId;
  final String providerName;
  final Map<String, dynamic> requestData;
  final VoidCallback onBack;
  final ValueChanged<String> onError;
  final String chatTitle;

  const ProviderChatView({
    super.key,
    required this.requestId,
    required this.providerName,
    required this.requestData,
    required this.onBack,
    required this.onError,
    this.chatTitle = 'Chat with customer',
  });

  @override
  State<ProviderChatView> createState() => _ProviderChatViewState();
}

class _ProviderChatViewState extends State<ProviderChatView> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final String message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      widget.onError('Please sign in again to send messages.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance
          .collection('assistance_requests')
          .doc(widget.requestId)
          .collection('messages')
          .add({
            'text': message,
            'senderId': currentUserId,
            'senderName': widget.providerName,
            'createdAt': FieldValue.serverTimestamp(),
          });
      _messageController.clear();
    } on FirebaseException catch (error) {
      widget.onError(
        error.code == 'permission-denied'
            ? 'Chat access was denied. Deploy the Firestore chat rules and try again.'
            : error.message ?? 'Could not send your message.',
      );
    } catch (error) {
      widget.onError('Could not send your message: $error');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = FirebaseFirestore.instance
        .collection('assistance_requests')
        .doc(widget.requestId)
        .collection('messages')
        .orderBy('createdAt', descending: true);

    return _FlowPage(
      title: widget.chatTitle,
      subtitle: providerJobCustomer(widget.requestData),
      onBack: widget.onBack,
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final Object? error = snapshot.error;
                  final bool permissionDenied =
                      error is FirebaseException &&
                      error.code == 'permission-denied';
                  return _EmptyState(
                    icon: Icons.cloud_off_outlined,
                    message: permissionDenied
                        ? 'Chat access was denied. Deploy the Firestore chat rules to read this conversation.'
                        : 'Could not load this conversation.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _pageYellow),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    message: 'Send a message to contact the customer.',
                  );
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final bool isMine =
                        data['senderId'] ==
                        FirebaseAuth.instance.currentUser?.uid;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: isMine ? _pageYellow : _pageCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          data['text']?.toString() ?? '',
                          style: TextStyle(
                            color: isMine ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLength: 2000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: _pageMuted),
                    filled: true,
                    fillColor: _pageCard,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSending ? null : _sendMessage,
                style: IconButton.styleFrom(
                  backgroundColor: _pageYellow,
                  foregroundColor: Colors.black,
                ),
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProviderServiceProgressView extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final bool isCompleting;
  final ValueChanged<String> onComplete;

  const ProviderServiceProgressView({
    super.key,
    required this.requestData,
    required this.isCompleting,
    required this.onComplete,
  });

  @override
  State<ProviderServiceProgressView> createState() =>
      _ProviderServiceProgressViewState();
}

class _ProviderServiceProgressViewState
    extends State<ProviderServiceProgressView> {
  final TextEditingController _notesController = TextEditingController();
  final List<String> _checklist = [
    'Inspect the vehicle issue',
    'Complete the requested service',
    'Confirm the vehicle is safe',
  ];
  final Set<int> _checked = <int>{};

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      title: 'Service in progress',
      subtitle: providerJobService(widget.requestData),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _InfoCard(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Service fee',
                      style: TextStyle(color: _pageMuted),
                    ),
                  ),
                  Text(
                    providerJobFeeLabel(widget.requestData),
                    style: const TextStyle(
                      color: _pageYellow,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                '${providerJobCustomer(widget.requestData)} • '
                '${providerJobVehicle(widget.requestData)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Service checklist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...List<Widget>.generate(_checklist.length, (index) {
            final bool checked = _checked.contains(index);
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: _pageCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: checked ? _pageYellow : _pageBorder),
              ),
              child: CheckboxListTile(
                value: checked,
                activeColor: _pageYellow,
                checkColor: Colors.black,
                title: Text(
                  _checklist[index],
                  style: const TextStyle(color: Colors.white),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _checked.add(index);
                    } else {
                      _checked.remove(index);
                    }
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text(
            'Service notes',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a note about the completed work...',
              hintStyle: const TextStyle(color: _pageMuted),
              filled: true,
              fillColor: _pageCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _pageBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _pageBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _pageYellow),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _PrimaryButton(
            label: widget.isCompleting ? 'Saving...' : 'Complete Service',
            icon: Icons.check_circle_outline_rounded,
            onPressed:
                _checked.length == _checklist.length && !widget.isCompleting
                ? () => widget.onComplete(_notesController.text.trim())
                : null,
          ),
        ],
      ),
    );
  }
}

class ProviderMapView extends StatelessWidget {
  final Map<String, dynamic>? requestData;
  final VoidCallback? onOpenJob;

  const ProviderMapView({
    super.key,
    required this.requestData,
    required this.onOpenJob,
  });

  @override
  Widget build(BuildContext context) {
    final data = requestData;
    if (data == null) {
      return const _FlowPage(
        title: 'Map',
        subtitle: 'Your customer route will appear here',
        child: _EmptyState(
          icon: Icons.map_outlined,
          message: 'Accept a service request to see its location on the map.',
        ),
      );
    }

    final LatLng? location = providerJobLocation(data);
    final LatLng center = location ?? const LatLng(6.9271, 79.8612);
    return _FlowPage(
      title: 'Customer map',
      subtitle: providerJobCustomer(data),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: center, zoom: 14),
                markers: location == null
                    ? const <Marker>{}
                    : {
                        Marker(
                          markerId: const MarkerId('active_customer'),
                          position: location,
                          infoWindow: InfoWindow(
                            title: providerJobCustomer(data),
                          ),
                        ),
                      },
                myLocationButtonEnabled: true,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PrimaryButton(
            label: 'Open active job',
            icon: Icons.navigation_rounded,
            onPressed: onOpenJob,
          ),
        ],
      ),
    );
  }
}

class ProviderEarningsView extends StatelessWidget {
  final String providerId;

  const ProviderEarningsView({super.key, required this.providerId});

  @override
  Widget build(BuildContext context) {
    if (providerId.isEmpty) {
      return const _FlowPage(
        title: 'Earnings',
        subtitle: 'Your provider earnings',
        child: _EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          message: 'Sign in to view earnings.',
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('assistance_requests')
        .where('providerId', isEqualTo: providerId)
        .snapshots();

    return _FlowPage(
      title: 'Earnings',
      subtitle: 'Your provider earnings',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _EmptyState(
              icon: Icons.cloud_off_outlined,
              message: 'Could not load earnings right now.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _pageYellow),
            );
          }

          final completed =
              snapshot.data!.docs
                  .where((doc) => doc.data()['status'] == 'completed')
                  .toList()
                ..sort(
                  (a, b) =>
                      _completedDate(b.data())
                          .compareTo(_completedDate(a.data())),
                );
          final DateTime weekStart = DateTime.now().subtract(
            const Duration(days: 7),
          );
          final double weekTotal = completed
              .where((doc) => _completedDate(doc.data()).isAfter(weekStart))
              .fold<double>(
                0,
                (total, doc) => total + (providerJobFee(doc.data()) ?? 0),
              );
          final double allTotal = completed.fold<double>(
            0,
            (total, doc) => total + (providerJobFee(doc.data()) ?? 0),
          );

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _InfoCard(
                children: [
                  const Text('This week', style: TextStyle(color: _pageMuted)),
                  const SizedBox(height: 7),
                  Text(
                    _formatRupees(weekTotal),
                    style: const TextStyle(
                      color: _pageYellow,
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${completed.length} completed jobs  •  '
                    'All-time ${_formatRupees(allTotal)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 23),
              const Text(
                'Recent payments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (completed.isEmpty)
                const _EmptyState(
                  icon: Icons.payments_outlined,
                  message: 'Completed service payments will appear here.',
                )
              else
                ...completed.take(20).map((doc) {
                  final data = doc.data();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _pageCard,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _pageBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: _pageYellow,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                providerJobService(data),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                providerJobCustomer(data),
                                style: const TextStyle(
                                  color: _pageMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          providerJobFeeLabel(data),
                          style: const TextStyle(
                            color: _pageYellow,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _FlowPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  const _FlowPage({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _pageMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pageCard,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _pageBorder.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  final bool compact;

  const _InfoLine({
    required this.label,
    required this.value,
    this.accent = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 102,
            child: Text(
              label,
              style: const TextStyle(color: _pageMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: accent ? _pageYellow : Colors.white,
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _pageYellow,
          foregroundColor: Colors.black,
          disabledBackgroundColor: _pageYellow.withValues(alpha: 0.35),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: _pageBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _pageYellow, size: 38),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _pageMuted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _completedDate(Map<String, dynamic> data) {
  final Object? value = data['completedAt'] ?? data['updatedAt'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatRupees(double amount) {
  final String value = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return 'Rs.$value';
}
