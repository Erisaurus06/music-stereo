import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:music_stereo/services/favorites_manager.dart';
import 'package:music_stereo/widgets/design_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Importaciones de tu arquitectura limpia
import 'services/network_radar.dart';
import 'services/app_state.dart';
import 'services/player_manager.dart';
import 'services/bubble_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/auth_gate.dart';
import 'pomodoro_engine.dart';
import 'package:local_auth/local_auth.dart';

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
    androidNotificationChannelName: 'Music Stereo Reproducción',
    androidNotificationOngoing: true,
    // Ícono principal de la barra superior (el logotípo pequeñito)
    androidNotificationIcon: 'mipmap/ic_launcher',
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

  await BubbleManager.init(); // ✨ Inicializar la burbuja flotante

  runApp(const ProviderScope(child: MusicStereoApp()));
}

class MusicStereoApp extends StatefulWidget {
  const MusicStereoApp({super.key});

  @override
  State<MusicStereoApp> createState() => _MusicStereoAppState();
}

class _MusicStereoAppState extends State<MusicStereoApp>
    with WidgetsBindingObserver {
  final LocalAuthentication auth = LocalAuthentication();
  // ✨ La app inicia bloqueada SOLO SI el usuario lo tiene activado
  bool _isLocked = AppState.biometricLockEnabled.value;
  bool _isAuthenticating =
      false; // ✨ Evita que el usuario toque el botón múltiples veces

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ✨ Solo pedimos biometría al abrir si la opción está activa
    if (AppState.biometricLockEnabled.value) {
      _authenticate();
    } else {
      setState(() => _isLocked = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si el usuario desactivó la función, no hacemos nada.
    if (!AppState.biometricLockEnabled.value) return;

    // ✨ EVITAR BUCLE: Si el diálogo de huella está abierto, ignoramos el ciclo de vida por completo
    if (_isAuthenticating) return;

    if (state == AppLifecycleState.paused) {
      setState(() => _isLocked = true); // Se minimizó, bloquear inmediato
      PomodoroEngine.showCustomNotification(
        "Sesión en pausa",
        "Aplicación bloqueada por inactividad.",
      );
    } else if (state == AppLifecycleState.resumed) {
      // ✨ FIX: Sincronizar Pomodoro tras salir de la suspensión del SO
      PomodoroEngine.checkBackgroundState();

      // ✨ SOLO pedir biometría si la app está realmente bloqueada
      if (_isLocked) {
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    // Si ya hay un proceso o la app ya está desbloqueada, no hacemos nada.
    if (_isAuthenticating || !_isLocked) return;

    // Doble chequeo de seguridad por si el usuario lo desactiva mientras la app está en segundo plano
    if (!AppState.biometricLockEnabled.value) {
      if (mounted) setState(() => _isLocked = false);
      return;
    }

    try {
      // Mostramos al usuario que algo está pasando (ej. un spinner en el botón)
      if (mounted) setState(() => _isAuthenticating = true);

      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final bool isSupported = await auth.isDeviceSupported();

      // Si el dispositivo no tiene huella/cara, dejamos pasar directo
      if (!canCheckBiometrics || !isSupported) {
        if (mounted) setState(() => _isLocked = false);
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Usa tu biometría para desbloquear Music Stereo',
        options: const AuthenticationOptions(
          stickyAuth:
              true, // Mantiene el diálogo aunque la app vaya a segundo plano
          biometricOnly: false, // Permite usar PIN/Patrón si la huella falla
        ),
      );

      if (didAuthenticate) {
        if (mounted) setState(() => _isLocked = false);
        PomodoroEngine.showCustomNotification(
          "Datos Biométricos",
          "Verificación exitosa, sesión iniciada.",
        );
      }
    } catch (e) {
      debugPrint("❌ Error biométrico: $e");
      // Aquí podrías mostrar un SnackBar si quieres notificar al usuario del error
    } finally {
      // Pase lo que pase (éxito, fallo o cancelación), reactivamos el botón
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeMode,
      builder: (context, currentMode, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Music Stereo',
        debugShowCheckedModeBanner: false,
        themeMode: currentMode,
        theme: DinobotTheme.lightTheme,
        darkTheme: DinobotTheme.darkTheme,
        // ✨ APLICAMOS EL CROSSFADE GLOBAL DEL TEMA
        themeAnimationDuration: const Duration(milliseconds: 800),
        themeAnimationCurve: Curves.easeInOutCubic,
        home: ValueListenableBuilder<Color>(
          valueListenable: PlayerManager.currentThemeColor,
          builder: (context, themeColor, _) {
            return AnimatedTheme(
              data: Theme.of(context).copyWith(
                primaryColor: themeColor,
                colorScheme: Theme.of(
                  context,
                ).colorScheme.copyWith(primary: themeColor),
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOutCubic,
              child: Builder(
                builder: (innerContext) {
                  return Stack(
                    children: [
                      // ✨ LA APP SIEMPRE ESTÁ DEBAJO PARA EL EFECTO BLUR
                      const AuthGate(),

                      // ✨ PANTALLA DE BLOQUEO CON GLASSMORPHISM
                      if (_isLocked)
                        Positioned.fill(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            builder: (context, value, child) => BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 25 * value,
                                sigmaY: 25 * value,
                              ),
                              child: Container(
                                color: Colors.black.withValues(
                                  alpha: 0.5 * value,
                                ),
                                child: child,
                              ),
                            ),
                            child: Scaffold(
                              backgroundColor: Colors.transparent,
                              body: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      "Aplicación Bloqueada",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    AnimatedScale(
                                      scale: _isAuthenticating ? 0.95 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: themeColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 30,
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          elevation: 8,
                                          shadowColor: themeColor.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        onPressed: _isAuthenticating
                                            ? null
                                            : () {
                                                HapticFeedback.mediumImpact();
                                                _authenticate();
                                              },
                                        icon: _isAuthenticating
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 3,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.fingerprint_rounded,
                                              ),
                                        label: Text(
                                          _isAuthenticating
                                              ? "Verificando..."
                                              : "Desbloquear",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ✨ BANNER GLOBAL ANIMADO PARA PÉRDIDA DE RED
                      ValueListenableBuilder<bool>(
                        valueListenable: NetworkRadar.isOnline,
                        builder: (context, isOnline, _) {
                          final double topPadding = MediaQuery.of(
                            innerContext,
                          ).padding.top;
                          return AnimatedPositioned(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            top: isOnline ? -150 : topPadding + 10,
                            left: 20,
                            right: 20,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 15,
                                  sigmaY: 15,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.85,
                                    ),
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 15,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.wifi_off_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "Sin conexión a Internet",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              "Solo música local disponible",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
