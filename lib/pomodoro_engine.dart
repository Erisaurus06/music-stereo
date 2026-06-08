import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para la vibración
import 'package:supabase_flutter/supabase_flutter.dart'; // Para la base de datos
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
  static Timer? _timer;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

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
        }
      } catch (e) {
        debugPrint("❌ Error guardando estadística: $e");
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
      'pomodoro_channel_v3', // ✨ Se actualiza el ID para forzar el reinicio de los permisos
      'Alertas de Sesión',
      channelDescription:
          'Notificaciones cuando inicia o termina el estudio/descanso',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      fullScreenIntent:
          true, // ✨ Fuerza a que aparezca por encima de otras apps (Heads-up)
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('tono_pomodoro'),
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: 'tono_pomodoro.mp3',
    ); // ✨ En iOS SÍ lleva la extensión
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _notificationsPlugin.show(0, title, body, platformDetails);
  }

  static void stopTimer() {
    _timer?.cancel();
    currentState.value = PomodoroState.idle;
    secondsRemaining.value = focusDurationInSeconds;
  }
}
