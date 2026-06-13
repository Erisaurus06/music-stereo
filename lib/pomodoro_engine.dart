import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para la vibración
import 'package:supabase_flutter/supabase_flutter.dart'; // Para la base de datos
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum PomodoroState { focus, shortBreak, longBreak, idle }

class PomodoroEngine {
  // ✨ NUEVO: Variables configurables (por defecto 25 min estudio / 5 min descanso)
  static int focusDurationInSeconds = 1500;
  static int breakDurationInSeconds = 300;

  static final ValueNotifier<int> secondsRemaining = ValueNotifier(
    focusDurationInSeconds,
  );
  static final ValueNotifier<PomodoroState> currentState = ValueNotifier(
    PomodoroState.idle,
  );
  // ✨ NUEVO: Contador reactivo para los Pomodoros completados hoy
  static final ValueNotifier<int> todaysPomodoros = ValueNotifier(0);
  // ✨ NUEVO: Arreglo de 7 posiciones (Lunes a Domingo) para la semana actual
  static final ValueNotifier<List<int>> weeklyPomodoros = ValueNotifier(
    List.filled(7, 0),
  );

  static Timer? _timer;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static DateTime? _targetTime; // ✨ Memoria del reloj absoluto

  static Future<void> initNotifications() async {
    // Configuramos el icono de la notificación (usa el por defecto de Android)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await _notificationsPlugin.initialize(initializationSettings);

    // ✨ SOLUCIÓN 1: Pedir permisos explícitos en Android 13+ para notificaciones locales
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    // ✨ NUEVO: Cargar conteo del día al arrancar
    await fetchTodaysPomodoros();
    await fetchWeeklyPomodoros(); // ✨ Cargar también los de la semana
  }

  // ✨ NUEVO: Método que consulta a Supabase los registros de hoy
  static Future<void> fetchTodaysPomodoros() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();

      final response = await Supabase.instance.client
          .from('estudio')
          .select('id') // Pedimos solo la columna ID para que sea rapidísimo
          .eq('user_id', userId)
          .gte('fecha', startOfDay);

      todaysPomodoros.value = List.from(response).length;
    } catch (e) {
      debugPrint("❌ Error obteniendo Pomodoros de hoy: $e");
    }
  }

  // ✨ NUEVO: Consultar registros desde el Lunes de la semana actual
  static Future<void> fetchWeeklyPomodoros() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now();
      // Calcular el día Lunes de esta semana
      final currentDay = now.weekday; // 1 = Lunes, 7 = Domingo
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: currentDay - 1));

      final response = await Supabase.instance.client
          .from('estudio')
          .select('fecha')
          .eq('user_id', userId)
          .gte('fecha', startOfWeek.toIso8601String());

      List<int> weekCounts = List.filled(7, 0); // L, M, M, J, V, S, D
      for (var record in response) {
        final date = DateTime.parse(record['fecha']).toLocal();
        weekCounts[date.weekday - 1]++; // weekday es 1-7, el array es 0-6
      }

      weeklyPomodoros.value = weekCounts;
    } catch (e) {
      debugPrint("❌ Error obteniendo Pomodoros semanales: $e");
    }
  }

  // ✨ NUEVO: Método para que puedas cambiar los tiempos desde tu pantalla de Configuración
  static void setDurations(int focusMinutes, int breakMinutes) {
    focusDurationInSeconds = focusMinutes * 60;
    breakDurationInSeconds = breakMinutes * 60;
    if (currentState.value == PomodoroState.idle) {
      secondsRemaining.value = focusDurationInSeconds;
    }
  }

  static void startTimer() {
    if (currentState.value == PomodoroState.idle) {
      currentState.value = PomodoroState.focus;
      secondsRemaining.value = focusDurationInSeconds;
    }

    // ✨ Calculamos la HORA EXACTA en la que debe terminar
    _targetTime = DateTime.now().add(Duration(seconds: secondsRemaining.value));

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_targetTime != null) {
        final now = DateTime.now();
        final diff = _targetTime!.difference(now).inSeconds;

        if (diff > 0) {
          secondsRemaining.value = diff;
        } else {
          _timer?.cancel();
          _switchPhase(); // El tiempo se acabó, disparamos notificación
        }
      }
    });
  }

  static Future<void> _switchPhase() async {
    // ✨ Haptics modernos: Un golpe seco y premium típico de dispositivos Ultra/Pro
    HapticFeedback.heavyImpact();

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
          todaysPomodoros.value += 1; // ✨ Actualiza la vista inmediatamente

          // ✨ Actualiza el gráfico semanal inmediatamente
          final updatedWeek = List<int>.from(weeklyPomodoros.value);
          updatedWeek[DateTime.now().weekday - 1] += 1;
          weeklyPomodoros.value = updatedWeek;
        }
      } catch (e, stackTrace) {
        debugPrint("❌ Error guardando estadística: $e");
        // ✨ Monitoreo remoto: Registramos si la base de datos falla al guardar el Pomodoro
        FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'Fallo al guardar sesión Pomodoro en Supabase',
        );
      }

      currentState.value = PomodoroState.shortBreak;
      secondsRemaining.value = breakDurationInSeconds;

      // ✨ Lanzar Notificación Push Local
      await _showPushNotification(
        "¡Tiempo de Descanso! ☕",
        "Tu sesión de 25 minutos ha terminado. ¡Tómate un respiro!",
      );
    } else {
      currentState.value = PomodoroState.focus;
      secondsRemaining.value = focusDurationInSeconds;

      // ✨ Lanzar Notificación Push Local
      await _showPushNotification(
        "¡Hora de Concentrarse! 🎯",
        "El descanso terminó. ¡Vamos a darle con todo!",
      );
    }
  }

  static Future<void> _showPushNotification(String title, String body) async {
    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'pomodoro_channel_v5', // ✨ Forzamos un canal nuevo y limpio
      'Alertas de Sesión',
      channelDescription:
          'Notificaciones cuando inicia o termina el estudio/descanso',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      visibility: NotificationVisibility.public,
      playSound: true,
      // ✨ SOLUCIÓN 2 y 3: Quitamos el sonido personalizado y fullScreenIntent que bloqueaban la notificación si fallaban
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // ✨ SOLUCIÓN 4: Generamos un ID único para que la notificación SIEMPRE salte arriba y no se agrupe en silencio
    final int uniqueId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );
    await _notificationsPlugin.show(uniqueId, title, body, platformDetails);
  }

  static void stopTimer() {
    _timer?.cancel();
    _targetTime = null; // Limpiamos la memoria
    currentState.value = PomodoroState.idle;
    secondsRemaining.value = focusDurationInSeconds;
  }
}
