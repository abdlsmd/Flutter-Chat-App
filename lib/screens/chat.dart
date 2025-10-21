import 'package:chat_app/widgets/chat_messages.dart';
import 'package:chat_app/widgets/new_message.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:chat_app/screens/user_info.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverUsername;
  final String receiverImage;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverUsername,
    required this.receiverImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  late final String _conversationId;
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    _currentUserId = user.uid;
    final participants = [_currentUserId, widget.receiverId]..sort();
    _conversationId = participants.join('_');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            backgroundImage: NetworkImage(widget.receiverImage.isNotEmpty
                ? widget.receiverImage
                : 'https://via.placeholder.com/150/cccccc/000000?text=User'),
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.receiverUsername)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              // Show the other user's info page (modified to accept userId)
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserInfoScreen(userId: widget.receiverId),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: ChatMessages(conversationId: _conversationId)),
          NewMessage(
            receiverId: widget.receiverId,
            conversationId: _conversationId,
          ),
        ],
      ),
    );
  }
}
