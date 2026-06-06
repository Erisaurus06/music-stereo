import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:music_stereo/services/favorites_manager.dart';
import 'package:music_stereo/widgets/design_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Importaciones de tu arquitectura limpia
import 'services/network_radar.dart';
import 'services/app_state.dart';
import 'services/player_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/auth_gate.dart';
import 'pomodoro_engine.dart';

// ✨ LLAVE MAESTRA DE NAVEGACIÓN (Para movernos desde las notificaciones)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✨ ESCUCHADOR DE NOTIFICACIONES EN SEGUNDO PLANO (APP CERRADA)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    "📩 Notificación Push recibida en background: ${message.messageId}",
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✨ Preparando la app para Android 15, 16 y 17 (Diseño Edge-to-Edge inmersivo)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor:
          Colors.transparent, // Barra de gestos inferior transparente
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase conectado con éxito");

    // ✨ INICIALIZAR NOTIFICACIONES PUSH (FCM) Y PERMISOS
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    final messaging = FirebaseMessaging.instance;

    // Pide permiso explícito al usuario (Obligatorio en Android 13+)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Imprime el token único del teléfono para que puedas enviarte pruebas
    final token = await messaging.getToken();
    debugPrint("📱 Token FCM del teléfono: $token");

    // ✨ 1. Escuchar cuando llega una notificación y LA APP ESTÁ ABIERTA
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '🔔 Notificación recibida en primer plano: ${message.notification?.title}',
      );
      // Nota: En primer plano las notificaciones push no suenan por defecto en Android.
      // Aquí puedes disparar un SnackBar personalizado o usar flutter_local_notifications si quieres que suene.
    });

    // ✨ 2. Escuchar cuando el usuario TOCA la notificación y la app estaba minimizada
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '🚀 App restaurada al tocar notificación: ${message.notification?.title}',
      );
      // ✨ Si envías datos ocultos (payload) en la notificación desde Firebase, navegamos a esa ruta
      final route = message.data['route'];
      if (route != null) {
        navigatorKey.currentState?.pushNamed(route);
      }
    });

    // ✨ 3. Escuchar cuando el usuario TOCA la notificación y la app estaba COMPLETAMENTE CERRADA
    final RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '🔥 App lanzada desde cero por una notificación: ${initialMessage.notification?.title}',
      );
      final route = initialMessage.data['route'];
      if (route != null) {
        navigatorKey.currentState?.pushNamed(route);
      }
    }
  } catch (e) {
    debugPrint("❌ Error al iniciar Firebase: $e");
    // La app seguirá aunque Firebase falle
  }

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // ✨ ESTO ES LO QUE FALTABA: Inicializar la notificación de la barra de estado
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'TecConnection Reproducción',
    androidNotificationOngoing: true,
  );

  await NetworkRadar.init();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await AppState.init();
  await FavoritesManager.init(); // ✨ AGREGA ESTA LÍNEA AQUÍ
  PlayerManager.init();
  await PlayerManager.loadFavoriteRadios(); // ✨ Cargar las radios favoritas guardadas
  await PomodoroEngine.initNotifications(); // ✨ Inicializar alertas Push del Pomodoro

  runApp(const ProviderScope(child: TecConnectionApp()));
}

class TecConnectionApp extends StatelessWidget {
  const TecConnectionApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeMode,
      builder: (context, currentMode, _) => MaterialApp(
        navigatorKey: navigatorKey, // ✨ Conectamos la llave maestra a la App
        title: 'TecConnection Hub',
        debugShowCheckedModeBanner: false,
        themeMode: currentMode,
        theme: DinobotTheme.lightTheme,
        darkTheme: DinobotTheme.darkTheme,
        home: const AuthGate(),
      ),
    );
  }
}
