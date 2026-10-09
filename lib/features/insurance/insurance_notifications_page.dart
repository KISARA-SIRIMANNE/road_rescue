import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'claim_details_verification_page.dart';
import '../../services/insurance_company.dart';

class InsuranceNotificationsPage extends StatefulWidget {
  const InsuranceNotificationsPage({super.key});

  @override
  State<InsuranceNotificationsPage> createState() =>
      _InsuranceNotificationsPageState();
}

class _InsuranceNotificationsPageState
    extends State<InsuranceNotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const Color backgroundColor = Color(0xFF101214);
  static const Color cardColor = Color(0xFF181B1E);
  static const Color yellowColor = Color(0xFFF6E900);
  static const Color whiteColor = Color(0xFFF5F7F8);
  static const Color greyColor = Color(0xFF929AA2);
  static const Color borderColor = Color(0xFF30353A);

  String? _syncError;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_syncProviderNotifications());
  }

  Future<void> _syncProviderNotifications() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() {
        _isSyncing = true;
        _syncError = null;
      });
    }

    try {
      final claims = await _firestore
          .collection('assistance_requests')
          .where('insuranceClaim', isEqualTo: true)
          .where(
            'insuranceCompanyId',
            isEqualTo: await loadCurrentInsuranceCompanyId(),
          )
          .get();

      for (final claim in claims.docs) {
        final notification = _firestore
            .collection('notifications')
            .doc('new_claim_${claim.id}_${user.uid}');

        try {
          if ((await notification.get()).exists) {
            continue;
          }

          await notification.set({
            'userId': user.uid,
            'title': 'New Insurance Claim',
            'message': 'A new insurance claim requires your review.',
            'type': 'new_claim',
            'claimId': claim.id,
            'requestId': claim.id,
            'read': false,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (e) {
          debugPrint(
            'Insurance notification create error: '
            '${e.code} - ${e.message}',
          );
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _syncError =
              '${e.code}: ${e.message ?? 'Firebase request failed.'}';
        });
      }
      debugPrint(
        'Insurance notification page sync error: '
        '${e.code} - ${e.message}',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _syncError = e.toString();
        });
      }
      debugPrint('Unexpected insurance notification page sync error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _notificationStream() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  String _getTitle(
    Map<String, dynamic> data,
  ) {
    return (data['title'] ??
            data['notificationTitle'] ??
            'Insurance Notification')
        .toString();
  }

  String _getMessage(
    Map<String, dynamic> data,
  ) {
    return (data['message'] ??
            data['body'] ??
            'You have a new notification.')
        .toString();
  }

  bool _isRead(
    Map<String, dynamic> data,
  ) {
    return data['read'] == true ||
        data['isRead'] == true;
  }

  bool _isDeleted(
    Map<String, dynamic> data,
  ) {
    return data['isDeleted'] == true;
  }

  DateTime _getDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime(2000);
    }

    return DateTime(2000);
  }

  String _formatDate(
    dynamic value,
  ) {
    final DateTime date = _getDate(value);

    if (date.year == 2000) {
      return 'Recently';
    }

    final String day =
        date.day.toString().padLeft(2, '0');

    final String month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  IconData _getNotificationIcon(
    Map<String, dynamic> data,
  ) {
    final String type =
        (data['type'] ?? '').toString().toLowerCase();

    if (type.contains('approved')) {
      return Icons.check_circle_outline;
    }

    if (type.contains('rejected')) {
      return Icons.cancel_outlined;
    }

    if (type.contains('claim')) {
      return Icons.description_outlined;
    }

    if (type.contains('payment')) {
      return Icons.payment_outlined;
    }

    return Icons.notifications_none;
  }

  Color _getNotificationColor(
    Map<String, dynamic> data,
  ) {
    final String type =
        (data['type'] ?? '').toString().toLowerCase();

    if (type.contains('approved')) {
      return Colors.green;
    }

    if (type.contains('rejected')) {
      return Colors.redAccent;
    }

    if (type.contains('claim')) {
      return yellowColor;
    }

    return Colors.blueAccent;
  }

  String _getTypeLabel(Map<String, dynamic> data) {
    final String type = (data['type'] ?? '').toString().toLowerCase();

    if (type.contains('approved')) return 'CLAIM APPROVED';
    if (type.contains('rejected')) return 'CLAIM REJECTED';
    if (type.contains('information')) return 'ACTION REQUIRED';
    if (type.contains('review')) return 'UNDER REVIEW';
    if (type.contains('claim')) return 'NEW CLAIM';
    if (type.contains('payment')) return 'PAYMENT';

    return 'NOTIFICATION';
  }

  List<Widget> _buildClaimReference(Map<String, dynamic> data) {
    final claimId = data['claimId'] ?? data['requestId'];
    if (claimId == null) return const [];

    return [
      const SizedBox(height: 6),
      Text(
        'Claim: $claimId',
        style: const TextStyle(
          color: greyColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
  }

  Future<void> _markAsRead(
    String documentId,
  ) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(documentId)
          .update({
        'read': true,
        'isRead': true,
      });
    } catch (e) {
      debugPrint(
        'Notification read update error: $e',
      );
    }
  }

  Future<void> _openNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    if (!_isRead(data)) {
      await _markAsRead(document.id);
    }

    final claimId = (data['claimId'] ?? data['requestId'] ?? '').toString();
    if (!mounted || claimId.trim().isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClaimDetailsVerificationPage(
          claimId: claimId,
        ),
      ),
    );
  }

  Future<void> _markAllAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>
        documents,
  ) async {
    try {
      final WriteBatch batch =
          _firestore.batch();

      bool hasUnread = false;

      for (final doc in documents) {
        final data = doc.data();

        if (!_isRead(data)) {
          hasUnread = true;

          batch.update(
            doc.reference,
            {
              'read': true,
              'isRead': true,
            },
          );
        }

      }

      if (hasUnread) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint(
        'Mark all notifications error: $e',
      );
    }
  }

  Future<void> _deleteNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Delete notification?',
          style: TextStyle(color: whiteColor),
        ),
        content: const Text(
          'This notification will be removed from your notifications.',
          style: TextStyle(color: greyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: greyColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await document.reference.delete();
    } on FirebaseException catch (e) {
      if (!mounted) return;

      final message = e.code == 'permission-denied'
          ? 'Delete permission denied. Deploy the latest Firestore rules and try again.'
          : e.message ?? 'Unable to delete the notification.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete the notification.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      debugPrint('Unexpected notification delete error: $e');
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            color: whiteColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh notifications',
            onPressed: _isSyncing
                ? null
                : () {
                    unawaited(_syncProviderNotifications());
                  },
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: yellowColor,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: whiteColor,
                  ),
          ),
          StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: _notificationStream(),
            builder: (
              context,
              snapshot,
            ) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final docs = snapshot.data!.docs
                  .where((doc) => !_isDeleted(doc.data()))
                  .toList();

              final hasUnread = docs.any(
                (doc) => !_isRead(doc.data()),
              );

              if (!hasUnread) {
                return const SizedBox.shrink();
              }

              return TextButton(
                onPressed: () {
                  _markAllAsRead(docs);
                },
                child: const Text(
                  'Read All',
                  style: TextStyle(
                    color: yellowColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationStream(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: yellowColor,
              ),
            );
          }

          if (snapshot.hasError) {
            debugPrint(
              'Insurance notifications stream error: ${snapshot.error}',
            );
            return _buildErrorState(
              message:
                  'Unable to load notifications. Check your account access and try again.',
            );
          }

          if (_auth.currentUser == null) {
            return _buildErrorState(
              message: 'Your session has expired. Please sign in again.',
            );
          }

          final documents = (snapshot.data?.docs ?? [])
              .where((doc) => !_isDeleted(doc.data()))
              .toList();

          if (documents.isEmpty) {
            if (_syncError != null) {
              return _buildErrorState(
                message: _syncError!,
              );
            }
            return _buildEmptyState();
          }

          final sortedDocuments =
              List<QueryDocumentSnapshot<
                  Map<String, dynamic>>>.from(
            documents,
          );

          sortedDocuments.sort(
            (a, b) {
              final DateTime dateA =
                  _getDate(
                a.data()['createdAt'],
              );

              final DateTime dateB =
                  _getDate(
                b.data()['createdAt'],
              );

              return dateB.compareTo(dateA);
            },
          );

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              30,
            ),
            itemCount: sortedDocuments.length + 1,
            itemBuilder: (
              context,
              index,
            ) {
              if (index == 0) {
                final unreadCount = sortedDocuments
                    .where((doc) => !_isRead(doc.data()))
                    .length;

                return _buildSummaryHeader(
                  totalCount: sortedDocuments.length,
                  unreadCount: unreadCount,
                );
              }

              final doc =
                  sortedDocuments[index - 1];

              return _buildNotificationCard(
                doc,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader({
    required int totalCount,
    required int unreadCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: yellowColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: yellowColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unreadCount == 0
                      ? 'You are all caught up'
                      : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: whiteColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalCount notification${totalCount == 1 ? '' : 's'} in your inbox',
                  style: const TextStyle(
                    color: greyColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            const Icon(
              Icons.mark_email_unread_outlined,
              color: yellowColor,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        document,
  ) {
    final Map<String, dynamic> data =
        document.data();

    final bool isRead = _isRead(data);

    final Color iconColor =
        _getNotificationColor(data);

    return Semantics(
      button: true,
      label: '${_getTitle(data)} notification',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _openNotification(document);
        },
        child: Container(
        margin: const EdgeInsets.only(
          bottom: 12,
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isRead ? borderColor : yellowColor.withOpacity(0.5)),
          boxShadow: isRead
              ? null
              : [
                  BoxShadow(
                    color: yellowColor.withOpacity(0.08),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius:
                    BorderRadius.circular(13),
              ),
              child: Icon(
                _getNotificationIcon(data),
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                _getTitle(data),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: whiteColor,
                                  fontSize: 14,
                                  fontWeight: isRead
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                ),
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(width: 7),
                              Container(
                                height: 7,
                                width: 7,
                                decoration: const BoxDecoration(
                                  color: yellowColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete notification',
                        onPressed: () {
                          _deleteNotification(document);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: greyColor,
                          size: 21,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _getTypeLabel(data),
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _getMessage(data),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: greyColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  ..._buildClaimReference(data),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: greyColor.withOpacity(0.75),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(data['createdAt']),
                        style: const TextStyle(
                          color: greyColor,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: greyColor,
                        size: 12,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              height: 85,
              width: 85,
              decoration: BoxDecoration(
                color: yellowColor
                    .withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none,
                color: yellowColor,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Notifications',
              style: TextStyle(
                color: whiteColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are all caught up. New claim '
              'notifications will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: greyColor,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState({
    String message =
        'Please check your connection and try again.',
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 55,
            ),
            SizedBox(height: 15),
            Text(
              'Unable to Load Notifications',
              style: TextStyle(
                color: whiteColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: greyColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}