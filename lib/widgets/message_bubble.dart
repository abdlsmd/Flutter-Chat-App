import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class MessageBubble extends StatelessWidget {
  final String message; // text OR file path (image/audio)
  final bool isMe;
  final String time;
  final String? username;
  final String? userImage;
  final bool isFirstInSequence;
  final bool isImage;
  final bool isVoice;

  const MessageBubble.first({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    required this.username,
    required this.userImage,
    required this.isImage,
    required this.isVoice,
  }) : isFirstInSequence = true;

  const MessageBubble.next({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    required this.isImage,
    required this.isVoice,
  })  : isFirstInSequence = false,
        username = null,
        userImage = null;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? Colors.blue[300]! : Colors.grey[300]!;
    final textColor = isMe ? Colors.white : Colors.black87;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe && isFirstInSequence)
          CircleAvatar(
            backgroundImage: userImage != null && userImage!.isNotEmpty
                ? NetworkImage(userImage!)
                : null,
            child: userImage == null || userImage!.isEmpty
                ? const Icon(Icons.person)
                : null,
          )
        else
          const SizedBox(width: 40),

        const SizedBox(width: 8),

        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.all((isImage || isVoice) ? 6 : 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 12),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isFirstInSequence && username != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      username!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),

                // ✅ Show Image
                if (isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(message),
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          "⚠️ Image not found",
                          style: TextStyle(color: Colors.red),
                        );
                      },
                    ),
                  )

                // ✅ Show Voice Message Player
                else if (isVoice)
                  _VoiceMessagePlayer(filePath: message, isMe: isMe)

                // ✅ Show Text
                else
                  Text(
                    message,
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),

                const SizedBox(height: 4),

                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceMessagePlayer extends StatefulWidget {
  final String filePath;
  final bool isMe;

  const _VoiceMessagePlayer({
    Key? key,
    required this.filePath,
    required this.isMe,
  }) : super(key: key);

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;

  void _togglePlay() async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.filePath));
    }
    setState(() => isPlaying = !isPlaying);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe ? Colors.white : Colors.black),
          onPressed: _togglePlay,
        ),
        const Text("Voice Message"),
      ],
    );
  }
}
