import 'dart:async';
import 'package:flutter/material.dart';

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

  static void _switchPhase() {
    if (currentState.value == PomodoroState.focus) {
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
