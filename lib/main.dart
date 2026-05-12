import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:music_stereo/widgets/design_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:on_audio_query/on_audio_query.dart'; // ✨ AGREGA ESTA LÍNEA
// Importaciones de tu arquitectura limpia
import 'widgets/player_ui.dart';
import 'package:app_settings/app_settings.dart';
import 'api_keys.dart';
import 'auth_screen.dart';
import 'models/app_models.dart';
import 'services/network_radar.dart';
import 'services/app_state.dart';
import 'services/player_manager.dart';
import 'screens/library_view.dart';
import 'screens/pomodoro_view.dart';
import 'screens/settings_view.dart';
import 'widgets/player_ui.dart';
import 'screens/radio_view.dart';
import 'dart:ui'; // CRÍTICO para el filtro de desenfoque (Blur)
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
  PlayerManager.init();

  runApp(const ProviderScope(child: TecConnectionApp()));
}

class FirebaseCrashlytics {
  static get instance => null;
}

class TecConnectionApp extends StatelessWidget {
  const TecConnectionApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeMode,
      builder: (context, currentMode, _) => MaterialApp(
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.hasData ? snapshot.data!.session : null;
        if (session != null) {
          return const MainNavigation();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // ✨ 1. LA ÚNICA Y VERDADERA LISTA MAESTRA DE PANTALLAS (Arriba, ordenada y sin nulls)
  final List<Widget> _pages = const [
    LibraryView(),
    PomodoroView(),
    RadioView(),
    SettingsProView(), // ✨ CAMBIA ESTO AQUÍ
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoConnectSpotify();
      PlayerManager.loadLocalMusic();
    });
  }

  Future<void> _autoConnectSpotify() async {
    try {
      bool result = await SpotifySdk.connectToSpotifyRemote(
        clientId: ApiKeys.spotifyClientId,
        redirectUrl: "tecconnection://callback",
      );
      if (result) {
        PlayerManager.isSpotifyLinked.value = true;
        PlayerManager.startSpotifyRadar();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<String?>(
      valueListenable: AppState.backgroundImagePath,
      builder: (context, imagePath, _) {
        return Stack(
          children: [
            // 1. CAPA BASE: LA IMAGEN ELEGIDA
            if (imagePath != null)
              Positioned.fill(
                child: Image.file(File(imagePath), fit: BoxFit.cover),
              )
            else
              Positioned.fill(
                child: Container(color: theme.scaffoldBackgroundColor),
              ),

            // 2. CAPA CRISTAL: DESENFOQUE (GLASSMORPHISM) Y OSCURECIMIENTO
            if (imagePath != null)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                  child: Container(color: Colors.black.withOpacity(0.65)),
                ),
              ),

            // 3. CAPA APP: TU INTERFAZ
            Scaffold(
              backgroundColor:
                  Colors.transparent, // ¡CRÍTICO para el Glassmorphism!
              body: Stack(
                children: [
                  _pages[_selectedIndex], // Carga la pantalla actual
                  _buildMiniPlayer(
                    theme,
                  ), // ✨ INYECTA EL MINI-REPRODUCTOR FLOTANTE
                ],
              ),
              bottomNavigationBar: _buildSolidNavBar(theme),
            ),
          ],
        );
      },
    );
  }

  // 🧭 BARRA DE NAVEGACIÓN PREMIUM Y ADAPTATIVA
  Widget _buildSolidNavBar(ThemeData theme) {
    return ValueListenableBuilder<Color>(
      valueListenable: PlayerManager.currentThemeColor,
      builder: (context, themeColor, _) {
        // ✨ ALGORITMO: Si el modo es claro y el color es muy brillante, lo oscurece para que se vea
        final bool isLightMode = theme.brightness == Brightness.light;
        final HSLColor hsl = HSLColor.fromColor(themeColor);
        final Color safeThemeColor = isLightMode && hsl.lightness > 0.6
            ? hsl.withLightness(0.4).toColor()
            : themeColor;

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppState.backgroundImagePath.value != null
                ? theme.cardColor.withOpacity(0.85)
                : theme.cardColor, // Cristal si hay fondo
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(
                0,
                Icons.my_library_music_rounded,
                'Música',
                theme,
                safeThemeColor,
              ),
              _navItem(
                1,
                Icons.timer_rounded,
                'Enfoque',
                theme,
                safeThemeColor,
              ),
              _navItem(2, Icons.radio_rounded, 'Radio', theme, safeThemeColor),
              _navItem(
                3,
                Icons.settings_rounded,
                'Ajustes',
                theme,
                safeThemeColor,
              ),
            ],
          ),
        );
      },
    );
  }

  // ✨ EL CEREBRO DE LA MICROANIMACIÓN (REBOTE Y GLOW)
  Widget _navItem(
    int index,
    IconData icon,
    String label,
    ThemeData theme,
    Color themeColor,
  ) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (AppState.enableHaptics.value) HapticFeedback.selectionClick();
        setState(() => _selectedIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: isSelected
                    ? themeColor
                    : theme.textTheme.bodySmall?.color,
                size: 26,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  label,
                  style: TextStyle(
                    color: themeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 🎵 EL MINI-REPRODUCTOR FLOTANTE BLINDADO (VERSIÓN CORREGIDA)
  Widget _buildMiniPlayer(ThemeData theme) {
    return ValueListenableBuilder<bool>(
      valueListenable: PlayerManager.isPlaying,
      builder: (context, isPlaying, _) {
        // ✨ CORRECCIÓN 1: Ahora escuchamos al "Motor Activo", no al MP3 local.
        // Esto evita que Spotify desaparezca.
        return ValueListenableBuilder<AudioEngineType>(
          valueListenable: PlayerManager.activeEngine,
          builder: (context, activeEngine, _) {
            // Ocultar SOLAMENTE si el reproductor está totalmente apagado
            if (activeEngine == AudioEngineType.none) {
              return const SizedBox.shrink();
            }

            return Positioned(
              bottom: 10,
              left: 15,
              right: 15,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  // Abre el reproductor gigante
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (c) => const FullPlayerModal(),
                  );
                },
                child: ValueListenableBuilder<Color>(
                  valueListenable: PlayerManager.currentThemeColor,
                  builder: (context, themeColor, _) {
                    // ALGORITMO DE CONTRASTE
                    final bool isLightColor =
                        themeColor.computeLuminance() > 0.5;
                    final Color contrastColor = isLightColor
                        ? Colors.black
                        : Colors.white;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutExpo,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppState.backgroundImagePath.value != null
                            ? theme.cardColor.withOpacity(0.85)
                            : themeColor.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Portada
                          AnimatedRotation(
                            turns: isPlaying ? 1 : 0,
                            duration: const Duration(seconds: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                width: 45,
                                height: 45,
                                color: Colors.black12,
                                child: ValueListenableBuilder<dynamic>(
                                  valueListenable: PlayerManager.currentArtwork,
                                  builder: (c, art, _) => HybridArtworkWidget(
                                    artworkData: art,
                                    title: PlayerManager.currentTitle.value,
                                    artist: PlayerManager.currentArtist.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),

                          // Textos Seguros
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ValueListenableBuilder<String>(
                                  valueListenable: PlayerManager.currentTitle,
                                  builder: (c, title, _) => Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color:
                                          AppState.backgroundImagePath.value !=
                                              null
                                          ? theme.textTheme.bodyLarge?.color
                                          : contrastColor,
                                    ),
                                  ),
                                ),
                                ValueListenableBuilder<String>(
                                  valueListenable: PlayerManager.currentArtist,
                                  builder: (c, artist, _) => Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          AppState.backgroundImagePath.value !=
                                              null
                                          ? theme.primaryColor
                                          : contrastColor.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ✨ CORRECCIÓN 2: BOTÓN DE BLUETOOTH (Solo 1, el correcto)
                          IconButton(
                            icon: Icon(
                              Icons.speaker_group_rounded,
                              color: AppState.backgroundImagePath.value != null
                                  ? theme.textTheme.bodyLarge?.color
                                  : contrastColor,
                              size: 24,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (c) => const AudioRouteSheet(),
                              );
                            },
                          ),

                          // ✨ CORRECCIÓN 3: BOTÓN DE PLAY/PAUSA RESTAURADO
                          IconButton(
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppState.backgroundImagePath.value != null
                                  ? theme.textTheme.bodyLarge?.color
                                  : contrastColor,
                              size: 28,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              PlayerManager.togglePlay();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ✨ PANTALLA FLOTANTE DE DISPOSITIVOS DE AUDIO (BLUETOOTH)
class AudioRouteSheet extends StatelessWidget {
  const AudioRouteSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Barrita superior (Handle)
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            "Dispositivos de Audio",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Opcion 1: Teléfono
          ListTile(
            leading: const Icon(Icons.phone_iphone_rounded, size: 30),
            title: const Text(
              "Este Teléfono",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),

          // Opcion 2: Buscar Bluetooth
          ListTile(
            leading: const Icon(
              Icons.bluetooth_audio_rounded,
              size: 30,
              color: Colors.grey,
            ),
            title: const Text(
              "Conectar a Bluetooth...",
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              // Notificación flotante
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Buscando bocinas y audífonos cercanos... 🎧',
                  ),
                  backgroundColor: PlayerManager.currentThemeColor.value,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
