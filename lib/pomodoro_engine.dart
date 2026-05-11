import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para la vibración
import 'package:supabase_flutter/supabase_flutter.dart'; // Para la base de datos

enum PomodoroState { focus, shortBreak, longBreak, idle }

class PomodoroEngine {
  static final ValueNotifier<int> secondsRemaining = ValueNotifier(
    1500,
  ); // 25 min
  static final ValueNotifier<PomodoroState> currentState = ValueNotifier(
    PomodoroState.idle,
  );
  static Timer? _timer;

  static void startTimer() {
    if (currentState.value == PomodoroState.idle) {
      currentState.value = PomodoroState.focus;
      secondsRemaining.value = 1500;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining.value > 0) {
        secondsRemaining.value--;
      } else {
        _switchPhase();
      }
    });
  }

  static Future<void> _switchPhase() async {
    HapticFeedback.vibrate(); // ✨ Aviso físico de que terminó el tiempo

    if (currentState.value == PomodoroState.focus) {
      // ✨ ¡NUEVO! Guardar sesión exitosa en la nube
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          // Asume que crearás una tabla 'estudio' en tu Supabase
          await Supabase.instance.client.from('estudio').insert({
            'user_id': userId,
            'minutos': 25,
            'fecha': DateTime.now().toIso8601String(),
          });
          debugPrint("✅ Sesión de estudio guardada en la nube");
        }
      } catch (e) {
        debugPrint("❌ Error guardando estadística: $e");
      }

      currentState.value = PomodoroState.shortBreak;
      secondsRemaining.value = 300; // 5 min descanso
    } else {
      currentState.value = PomodoroState.focus;
      secondsRemaining.value = 1500; // 25 min estudio
    }
  }

  static void stopTimer() {
    _timer?.cancel();
    currentState.value = PomodoroState.idle;
    secondsRemaining.value = 1500;
  }
}
