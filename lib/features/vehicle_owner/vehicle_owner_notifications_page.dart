import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VehicleOwnerNotificationsPage extends StatefulWidget {
  const VehicleOwnerNotificationsPage({super.key});

  @override
  State<VehicleOwnerNotificationsPage> createState() =>
      _VehicleOwnerNotificationsPageState();
}

class _VehicleOwnerNotificationsPageState
    extends State<VehicleOwnerNotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const background = Color(0xFF101214);
  static const card = Color(0xFF181B1E);
  static const yellow = Color(0xFFF6E900);
  static const white = Color(0xFFF5F7F8);
  static const grey = Color(0xFF929AA2);
  static const border = Color(0xFF30353A);

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  bool _isRead(Map<String, dynamic> data) =>
      data['read'] == true || data['isRead'] == true;

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(2000);
    return DateTime(2000);
  }

  String _dateLabel(dynamic value) {
    final date = _date(value);
    if (date.year == 2000) return 'Recently';

    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'need_information':
        return Colors.orangeAccent;
      default:
        return yellow;
    }
  }

  Future<void> _markRead(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    try {
      await document.reference.update({'read': true, 'isRead': true});
    } on FirebaseException catch (e) {
      debugPrint('Owner notification read error: ${e.code} - ${e.message}');
    }
  }

  Future<void> _delete(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    try {
      await document.reference.delete();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Unable to delete notification.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  'NOTIFICATIONS',
                  style: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: yellow),
                    );
                  }
                  if (snapshot.hasError) {
                    return _message('Unable to load notifications.');
                  }

                  final documents = [...(snapshot.data?.docs ?? [])];
                  documents.sort(
                    (a, b) =>
                        _date(b.data()['createdAt'])
                            .compareTo(_date(a.data()['createdAt'])),
                  );

                  if (documents.isEmpty) return _empty();

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      return _card(documents[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final read = _isRead(data);
    final status = (data['status'] ?? '').toString().toLowerCase();
    final color = _statusColor(status);

    return Dismissible(
      key: ValueKey(document.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _delete(document);
        return true;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: white),
      ),
      child: InkWell(
        onTap: read ? null : () => _markRead(document),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: read ? border : color.withValues(alpha: 0.65),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  status == 'approved'
                      ? Icons.check_circle_outline
                      : status == 'rejected'
                      ? Icons.cancel_outlined
                      : Icons.notifications_active_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (data['title'] ?? 'Claim Update').toString(),
                            style: TextStyle(
                              color: white,
                              fontSize: 14,
                              fontWeight: read
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (data['message'] ?? 'Your claim status was updated.')
                          .toString(),
                      style: const TextStyle(
                        color: grey,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _dateLabel(data['createdAt']),
                      style: const TextStyle(color: grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete notification',
                onPressed: () => _delete(document),
                icon: const Icon(Icons.delete_outline, color: grey, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() =>
      _message('You are all caught up. New claim updates will appear here.');

  Widget _message(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none, color: yellow, size: 52),
            const SizedBox(height: 16),
            const Text(
              'No Notifications',
              style: TextStyle(
                color: white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
