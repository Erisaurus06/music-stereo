import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:app_settings/app_settings.dart';

import '../api_keys.dart';
import '../services/player_manager.dart';
import '../services/app_state.dart';
import '../widgets/player_ui.dart';
import '../widgets/design_components.dart';
import 'library_view.dart';
import 'pomodoro_view.dart';
import 'radio_view.dart';
import 'settings_view.dart';
import '../widgets/bluetooth_panel.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    LibraryView(),
    PomodoroView(),
    RadioView(),
    SettingsProView(),
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
    } catch (e) {
      debugPrint(
        "Info: No se pudo auto-conectar a Spotify silenciosamente. $e",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<String?>(
      valueListenable: AppState.backgroundImagePath,
      builder: (context, imagePath, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: PlayerManager.currentThemeColor,
          builder: (context, themeColor, _) {
            return Stack(
              children: [
                if (imagePath != null)
                  Positioned.fill(
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: theme.scaffoldBackgroundColor),
                    ),
                  )
                else
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.scaffoldBackgroundColor,
                            Color.alphaBlend(
                              themeColor.withOpacity(0.15),
                              theme.scaffoldBackgroundColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (imagePath != null)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        color: Color.alphaBlend(
                          themeColor.withOpacity(0.3),
                          Colors.black.withOpacity(
                            0.75,
                          ), // ✨ Aumentamos contraste para mejor legibilidad
                        ),
                      ),
                    ),
                  ),

                Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Stack(
                    children: [_pages[_selectedIndex], _buildMiniPlayer(theme)],
                  ),
                  bottomNavigationBar: _buildSolidNavBar(theme),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSolidNavBar(ThemeData theme) {
    return ValueListenableBuilder<Color>(
      valueListenable: PlayerManager.currentThemeColor,
      builder: (context, themeColor, _) {
        final bool isLightMode = theme.brightness == Brightness.light;
        final HSLColor hsl = HSLColor.fromColor(themeColor);

        Color safeThemeColor = themeColor;
        if (isLightMode && hsl.lightness > 0.6) {
          safeThemeColor = hsl
              .withLightness(0.4)
              .toColor(); // Oscurece si es muy claro en modo claro
        } else if (!isLightMode && hsl.lightness < 0.4) {
          safeThemeColor = hsl
              .withLightness(0.65)
              .toColor(); // ✨ Aclara si es muy oscuro en modo oscuro
        }

        return SafeArea(
          top: false,
          bottom:
              true, // ✨ ¡LA MAGIA! Esto detecta los 3 botones y empuja el menú hacia arriba dinámicamente
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: AppState.backgroundImagePath.value != null
                    ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppState.backgroundImagePath.value != null
                        ? (isLightMode
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.3))
                        : theme.cardColor,
                    border: Border.all(
                      color: AppState.backgroundImagePath.value != null
                          ? Colors.white.withOpacity(
                              0.25,
                            ) // ✨ Efecto de vidrio (Glassmorphism)
                          : Colors.white.withOpacity(0.05),
                    ),
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
                      _navItem(
                        2,
                        Icons.radio_rounded,
                        'Radio',
                        theme,
                        safeThemeColor,
                      ),
                      _navItem(
                        3,
                        Icons.settings_rounded,
                        'Ajustes',
                        theme,
                        safeThemeColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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

  Widget _buildMiniPlayer(ThemeData theme) {
    return ValueListenableBuilder<bool>(
      valueListenable: PlayerManager.isPlaying,
      builder: (context, isPlaying, _) {
        return ValueListenableBuilder<AudioEngineType>(
          valueListenable: PlayerManager.activeEngine,
          builder: (context, activeEngine, _) {
            if (activeEngine == AudioEngineType.none)
              return const SizedBox.shrink();

            return Positioned(
              bottom: 10,
              left: 15,
              right: 15,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
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
                    final bool isLightColor =
                        themeColor.computeLuminance() > 0.5;
                    final Color contrastColor = isLightColor
                        ? Colors.black
                        : Colors.white;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: AppState.backgroundImagePath.value != null
                              ? ImageFilter.blur(sigmaX: 15, sigmaY: 15)
                              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutExpo,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppState.backgroundImagePath.value != null
                                  ? (theme.brightness == Brightness.light
                                        ? Colors.white.withOpacity(0.15)
                                        : Colors.black.withOpacity(0.3))
                                  : themeColor.withOpacity(0.95),
                              border: Border.all(
                                color:
                                    AppState.backgroundImagePath.value != null
                                    ? Colors.white.withOpacity(0.25)
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              children: [
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
                                        valueListenable:
                                            PlayerManager.currentArtwork,
                                        builder: (c, art, _) =>
                                            HybridArtworkWidget(
                                              artworkData: art,
                                              title: PlayerManager
                                                  .currentTitle
                                                  .value,
                                              artist: PlayerManager
                                                  .currentArtist
                                                  .value,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ValueListenableBuilder<String>(
                                        valueListenable:
                                            PlayerManager.currentTitle,
                                        builder: (c, title, _) => Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color:
                                                AppState
                                                        .backgroundImagePath
                                                        .value !=
                                                    null
                                                ? Colors
                                                      .white // ✨ Siempre blanco para contraste óptimo sobre fondos
                                                : contrastColor,
                                          ),
                                        ),
                                      ),
                                      ValueListenableBuilder<String>(
                                        valueListenable:
                                            PlayerManager.currentArtist,
                                        builder: (c, artist, _) => Text(
                                          artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppState
                                                        .backgroundImagePath
                                                        .value !=
                                                    null
                                                ? Colors.white70
                                                : contrastColor.withOpacity(
                                                    0.7,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.bluetooth_audio_rounded,
                                    color:
                                        AppState.backgroundImagePath.value !=
                                            null
                                        ? Colors.white
                                        : contrastColor,
                                    size: 26,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.heavyImpact();
                                    BluetoothPanel.show(context);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color:
                                        AppState.backgroundImagePath.value !=
                                            null
                                        ? Colors.white
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
                          ),
                        ),
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
