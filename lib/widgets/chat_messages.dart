import 'package:chat_app/widgets/message_bubble.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatMessages extends StatelessWidget {
  final String conversationId;
  const ChatMessages({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context) {
    final authenticatedUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat')
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('ChatMessages error: ${snapshot.error}');
          return const Center(child: Text('Something went wrong.'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No messages yet. Say hi!'));
        }

        final messages = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (ctx, index) {
            final doc = messages[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};

            final String? userId = data['userId'] as String?;
            final String username = (data['username'] ?? 'Unknown') as String;
            final String messageText = (data['text'] ?? '') as String;
            final String userImage = (data['userImage'] ??
                'https://via.placeholder.com/150/cccccc/000000?text=User') as String;

            final String? imagePath = data['localImagePath'] as String?;
            final String? voicePath = data['voicePath'] as String?;

            final bool isImage = imagePath != null && imagePath.isNotEmpty;
            final bool isVoice = voicePath != null && voicePath.isNotEmpty;

            String messageContent = messageText;
            if (isImage) {
              messageContent = imagePath;
            } else if (isVoice) {
              messageContent = voicePath;
            }

            DateTime createdAt;
            final createdAtRaw = data['createdAt'];
            if (createdAtRaw is Timestamp) {
              createdAt = createdAtRaw.toDate();
            } else {
              createdAt = DateTime.now();
            }

            final bool isMe = userId != null &&
                authenticatedUser != null &&
                userId == authenticatedUser.uid;

            final String timeString = DateFormat.jm().format(createdAt);

            bool showDateLabel = false;
            if (index == messages.length - 1) {
              showDateLabel = true;
            } else {
              final nextDoc = messages[index + 1];
              final nextData = nextDoc.data() as Map<String, dynamic>? ?? {};
              DateTime nextCreatedAt;
              final nextCreatedAtRaw = nextData['createdAt'];
              if (nextCreatedAtRaw is Timestamp) {
                nextCreatedAt = nextCreatedAtRaw.toDate();
              } else {
                nextCreatedAt = DateTime.now();
              }

              final currentDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
              final nextDate = DateTime(nextCreatedAt.year, nextCreatedAt.month, nextCreatedAt.day);
              showDateLabel = currentDate != nextDate;
            }

            final nextSameUser = index + 1 < messages.length &&
                (messages[index + 1].data() as Map<String, dynamic>? ?? {})['userId'] == userId;

            final messageBubble = nextSameUser
                ? MessageBubble.next(
                    message: messageContent,
                    isMe: isMe,
                    time: timeString,
                    isImage: isImage,
                    isVoice: isVoice,
                  )
                : MessageBubble.first(
                    userImage: userImage,
                    username: username,
                    message: messageContent,
                    isMe: isMe,
                    time: timeString,
                    isImage: isImage,
                    isVoice: isVoice,
                  );

            if (showDateLabel) {
              String label;
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final yesterday = today.subtract(const Duration(days: 1));
              final currentDate =
                  DateTime(createdAt.year, createdAt.month, createdAt.day);

              if (currentDate == today) {
                label = "Today";
              } else if (currentDate == yesterday) {
                label = "Yesterday";
              } else {
                label = DateFormat.yMMMMd().format(currentDate);
              }

              return Column(
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  messageBubble,
                ],
              );
            }

            return messageBubble;
          },
        );
      },
    );
  }
}
