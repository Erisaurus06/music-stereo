import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'player_manager.dart';

/// Gestor independiente para la grabación de emisoras de radio en vivo
class RecordingManager {
  static final ValueNotifier<bool> isRecording = ValueNotifier(false);
  static String? currentRecordPath;
  static String? currentRadioUrl;
  static http.Client? _radioRecordClient;
  static IOSink? _radioRecordSink;
  static Timer? _recordingTimer;

  static Future<void> startRecording() async {
    if (PlayerManager.activeEngine.value != AudioEngineType.radio ||
        currentRadioUrl == null) {
      return;
    }
    try {
      Directory? baseDir;
      if (Platform.isAndroid) {
        final dirs = await getExternalStorageDirectories(
          type: StorageDirectory.music,
        );
        baseDir = dirs?.first;
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
      if (baseDir == null) return;

      final directory = Directory('${baseDir.path}/TecConnection');
      if (!await directory.exists()) await directory.create(recursive: true);

      String safeName = PlayerManager.currentTitle.value
          .replaceAll(RegExp(r'[^\w\s]+'), '')
          .replaceAll(' ', '_');
      String fileName =
          "REC_${safeName}_${DateTime.now().millisecondsSinceEpoch}.mp3";
      currentRecordPath = '${directory.path}/$fileName';

      _radioRecordClient = http.Client();
      final request = http.Request('GET', Uri.parse(currentRadioUrl!));
      final response = await _radioRecordClient!.send(request);

      final file = File(currentRecordPath!);
      _radioRecordSink = file.openWrite();

      response.stream.listen(
        (chunk) => _radioRecordSink?.add(chunk),
        onError: (e) => stopRecording(null),
        onDone: () => stopRecording(null),
      );

      isRecording.value = true;
      HapticFeedback.vibrate();

      _recordingTimer?.cancel();
      _recordingTimer = Timer(const Duration(minutes: 60), () {
        debugPrint("⏱️ Límite de seguridad alcanzado. Guardando grabación.");
        stopRecording(null);
      });
    } catch (e) {
      debugPrint("Error al grabar stream: $e");
    }
  }

  static Future<void> stopRecording(BuildContext? context) async {
    if (!isRecording.value) return;
    try {
      isRecording.value = false;
      HapticFeedback.heavyImpact();

      _recordingTimer?.cancel();
      _recordingTimer = null;

      _radioRecordClient?.close();
      _radioRecordClient = null;

      await _radioRecordSink?.flush();
      await _radioRecordSink?.close();
      _radioRecordSink = null;

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("📼 ¡Grabación guardada en tu biblioteca!"),
            backgroundColor: PlayerManager.currentThemeColor.value,
          ),
        );
      }
      await PlayerManager.loadLocalMusic();
    } catch (e) {
      debugPrint("Error cerrando archivo: $e");
    }
  }
}
