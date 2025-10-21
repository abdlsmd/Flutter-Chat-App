import 'package:get/get.dart';
import 'package:record/record.dart';
import 'dart:io';

class VoiceMessageController extends GetxController {
  final record = AudioRecorder();
  var isRecording = false.obs;
  var isPaused = false.obs;
  var voicePath = ''.obs;

  Future<void> startRecording() async {
    if (await record.hasPermission()) {
      voicePath.value =
          '/storage/emulated/0/Download/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await record.start(const RecordConfig(), path: voicePath.value);

      isRecording.value = true;
      isPaused.value = false;
    }
  }

  Future<void> pauseRecording() async {
    if (await record.isRecording()) {
      await record.pause();
      isPaused.value = true;
    }
  }

  Future<void> resumeRecording() async {
    if (await record.isPaused()) {
      await record.resume();
      isPaused.value = false;
    }
  }

  Future<String?> stopRecording() async {
    if (await record.isRecording() || await record.isPaused()) {
      final path = await record.stop();
      isRecording.value = false;
      isPaused.value = false;
      return path;
    }
    return null;
  }

  Future<void> cancelRecording() async {
    if (await record.isRecording() || await record.isPaused()) {
      await record.stop();
      final file = File(voicePath.value);
      if (await file.exists()) {
        await file.delete();
      }
      voicePath.value = '';
      isRecording.value = false;
      isPaused.value = false;
    }
  }
}
