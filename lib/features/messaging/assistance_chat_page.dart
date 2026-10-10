import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';

class AssistanceChatPage extends StatefulWidget {
  final String requestId;
  final String currentUserName;
  final String otherPartyName;
  final String title;

  const AssistanceChatPage({
    super.key,
    required this.requestId,
    required this.currentUserName,
    required this.otherPartyName,
    required this.title,
  });

  @override
  State<AssistanceChatPage> createState() => _AssistanceChatPageState();
}

class _AssistanceChatPageState extends State<AssistanceChatPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  CollectionReference<Map<String, dynamic>> get _messages =>
      FirebaseFirestore.instance
          .collection('assistance_requests')
          .doc(widget.requestId)
          .collection('messages');

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final String? senderId = FirebaseAuth.instance.currentUser?.uid;
    if (senderId == null) {
      _showMessage('Please sign in again to send messages.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await _messages.add({
        'text': text,
        'senderId': senderId,
        'senderName': widget.currentUserName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
    } on FirebaseException catch (error) {
      _showMessage(
        error.code == 'permission-denied'
            ? 'You do not have access to this conversation.'
            : error.message ?? 'Could not send your message.',
      );
    } catch (error) {
      debugPrint('Failed to send assistance chat message: $error');
      _showMessage('Could not send your message. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final Stream<QuerySnapshot<Map<String, dynamic>>> messages = _messages
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: RoadRescueColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              widget.otherPartyName,
              style: const TextStyle(
                color: RoadRescueColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final Object? error = snapshot.error;
                    final bool permissionDenied =
                        error is FirebaseException &&
                        error.code == 'permission-denied';
                    return _ChatState(
                      icon: Icons.cloud_off_outlined,
                      message: permissionDenied
                          ? 'You do not have access to this conversation.'
                          : 'Could not load this conversation.',
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: RoadRescueColors.accent,
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const _ChatState(
                      icon: Icons.chat_bubble_outline_rounded,
                      message: 'Send a message to start the conversation.',
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final Map<String, dynamic> data = docs[index].data();
                      final bool isMine = data['senderId'] == currentUserId;
                      final String senderName =
                          data['senderName']?.toString() ??
                          widget.otherPartyName;

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
                            color: isMine
                                ? RoadRescueColors.accent
                                : RoadRescueColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: isMine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isMine) ...[
                                Text(
                                  senderName,
                                  style: const TextStyle(
                                    color: RoadRescueColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                              ],
                              Text(
                                data['text']?.toString() ?? '',
                                style: TextStyle(
                                  color: isMine ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLength: 2000,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(color: RoadRescueColors.foreground),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        counterText: '',
                        filled: true,
                        fillColor: RoadRescueColors.surface,
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
                    tooltip: 'Send message',
                    onPressed: _isSending ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: RoadRescueColors.accent,
                      foregroundColor: RoadRescueColors.background,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: RoadRescueColors.background,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ChatState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: RoadRescueColors.muted, size: 38),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: RoadRescueColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
