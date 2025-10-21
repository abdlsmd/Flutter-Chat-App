import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'image_controller.dart';
import 'voice_message_controller.dart';

class NewMessage extends StatefulWidget {
  final String receiverId;
  final String? conversationId;

  const NewMessage({
    super.key,
    required this.receiverId,
    this.conversationId,
  });

  @override
  State<NewMessage> createState() => _NewMessageState();
}

class _NewMessageState extends State<NewMessage> {
  final _controller = TextEditingController();
  bool _isSending = false;
  Timer? _timer;
  int _seconds = 0;

  final ImageController imageController = Get.put(ImageController());
  final VoiceMessageController voiceController =
      Get.put(VoiceMessageController());

  final recorderController = RecorderController();

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _seconds = 0;
  }

  String get _formattedTime {
    final min = (_seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_seconds % 60).toString().padLeft(2, '0');
    return "$min:$sec";
  }

  Future<void> _sendMessage({String? voicePath}) async {
    final text = _controller.text.trim();
    final imageFile = imageController.selectedImage.value;

    if (text.isEmpty && imageFile == null && voicePath == null) return;

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDocSnap =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!userDocSnap.exists) throw Exception('User profile not found');

      final username = (userDocSnap.data()?['username'] ?? 'Unknown') as String;
      final userImage = (userDocSnap.data()?['image'] ?? '') as String;

      final participants = [user.uid, widget.receiverId]..sort();
      final conversationId =
          widget.conversationId ?? participants.join('_');

      await FirebaseFirestore.instance.collection('chat').add({
        'text': voicePath == null ? text : '',
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'username': username,
        'userImage': userImage,
        'receiverId': widget.receiverId,
        'participants': participants,
        'conversationId': conversationId,
        'isRead': false,
        'localImagePath': imageFile?.path,
        'voicePath': voicePath,
      });

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .set({
        'participants': participants,
        'lastMessage': text.isNotEmpty
            ? text
            : (imageFile != null
                ? '[Image]'
                : (voicePath != null ? '[Voice]' : '')),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSender': user.uid,
      }, SetOptions(merge: true));

      _controller.clear();
      imageController.clearImage();
      voiceController.voicePath.value = '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview
          Obx(() {
            final file = imageController.selectedImage.value;
            if (file == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(file.path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => imageController.clearImage(),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            );
          }),

          // Input + voice waveform container
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform + timer (shows only when recording)
                Obx(() {
                  if (!voiceController.isRecording.value) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        // Timer
                        Text(
                          _formattedTime,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 12),
                        // Waveform
                        Expanded(
                          child: AudioWaveforms(
                            enableGesture: false,
                            size: Size(screenWidth * 0.5, 40),
                            recorderController: recorderController,
                            waveStyle: const WaveStyle(
                              waveColor: Colors.green,
                              showDurationLabel: false,
                              extendWaveform: true,
                              spacing: 4,
                              showMiddleLine: false,
                              waveCap: StrokeCap.round,
                            ),
                          ),
                        ),
                        // Pause / Stop / Cancel
                        IconButton(
                          icon: Icon(
                            voiceController.isPaused.value
                                ? Icons.play_arrow
                                : Icons.pause,
                          ),
                          onPressed: () {
                            if (voiceController.isPaused.value) {
                              voiceController.resumeRecording();
                              _startTimer();
                            } else {
                              voiceController.pauseRecording();
                              _stopTimer();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop, color: Colors.red),
                          onPressed: () async {
                            final path = await voiceController.stopRecording();
                            _stopTimer();
                            recorderController.reset();
                            if (path != null) _sendMessage(voicePath: path);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.grey),
                          onPressed: () async {
                            await voiceController.cancelRecording();
                            _stopTimer();
                            recorderController.reset();
                          },
                        ),
                      ],
                    ),
                  );
                }),

                // Main input row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: 'Type a message...',
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Mic button shows only if not recording
                              Obx(() {
                                if (voiceController.isRecording.value) {
                                  return const SizedBox.shrink();
                                }
                                return IconButton(
                                  icon: const Icon(Icons.mic),
                                  onPressed: () {
                                    voiceController.startRecording();
                                    _startTimer();
                                  },
                                );
                              }),
                              // Image button
                              IconButton(
                                onPressed: () => imageController.pickImage(),
                                icon: const Icon(Icons.image),
                              ),
                            ],
                          ),
                        ),
                        maxLines: null,
                        onSubmitted: (_) {
                          if (_controller.text.trim().isNotEmpty ||
                              imageController.selectedImage.value != null) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _isSending
                            ? null
                            : () {
                                if (_controller.text.trim().isNotEmpty ||
                                    imageController.selectedImage.value != null) {
                                  _sendMessage();
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
