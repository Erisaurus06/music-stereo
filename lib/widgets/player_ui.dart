import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:music_stereo/services/favorites_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:audio_session/audio_session.dart';
import 'package:app_settings/app_settings.dart';
import 'package:just_audio/just_audio.dart';
import 'package:interactive_slider/interactive_slider.dart';
// Importaciones de tus otras carpetas
import '../models/app_models.dart';
import '../services/player_manager.dart';
import '../services/app_state.dart';
import '../services/network_radar.dart';
import 'design_components.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// --- 7. REPRODUCTOR GIGANTE (UX MEJORADO: CONTRASTE Y MODO CLARO) ---
class FullPlayerModal extends StatelessWidget {
  const FullPlayerModal({super.key});

  static const List<String> _lofiArtists = [
    "Chase9602",
    "Fassounds",
    "Mondamusic",
    "Purrplecat",
    "Leberch",
    "Lemonmusiclab",
    "Watermello",
    "The Mountain",
  ];

  get PerfectVolumeControl => null;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: PlayerManager.currentThemeColor,
      builder: (context, themeColor, _) {
        final double statusBarHeight = MediaQuery.of(context).padding.top;

        // 🧠 CEREBRO DE LUMINANCIA: Para el Modo Camaleón
        final HSLColor hslColor = HSLColor.fromColor(themeColor);
        final Color safeThemeColor = hslColor.lightness < 0.3
            ? hslColor.withLightness(0.4).toColor()
            : themeColor;

        final bool isLightColor = safeThemeColor.computeLuminance() > 0.5;
        final Color contrastIconColor = isLightColor
            ? Colors.black
            : Colors.white;

        final double luminance = themeColor.computeLuminance();
        final Color contrastColor = luminance < 0.5
            ? Colors.white
            : Colors.black;
        final Color secondaryContrast = luminance < 0.5
            ? Colors.white70
            : Colors.black54;

        return Padding(
          padding: EdgeInsets.only(top: statusBarHeight + 15),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            child: ValueListenableBuilder<String>(
              valueListenable: AppState.playerLayout,
              builder: (context, layoutMode, _) {
                // ☀️ DETECCIÓN DE MODO CLARO/OSCURO
                final bool isLightMode =
                    Theme.of(context).brightness == Brightness.light;

                // 🎨 LÓGICA DE COLORES BASE ADAPTATIVOS
                Color bgColor = isLightMode ? Colors.white : Colors.black;
                Color textColor = isLightMode ? Colors.black87 : Colors.white;
                Color secondaryTextColor = isLightMode
                    ? Colors.black54
                    : Colors.white54;

                if (layoutMode == "Neo-Retro") {
                  bgColor = isLightMode
                      ? const Color(0xFFF5F4F0)
                      : const Color(0xFF1A1A1D);
                } else if (layoutMode == "Consola Oscura") {
                  bgColor = const Color(0xFF121212);
                  textColor = Colors.white;
                  secondaryTextColor = Colors.white70;
                } else if (layoutMode == "Cyberpunk Neón") {
                  bgColor = const Color(0xFF09090B);
                  textColor = Colors.white;
                  secondaryTextColor = Colors.white54;
                } else if (layoutMode == "Minimalista Zen") {
                  bgColor = isLightMode
                      ? const Color(0xFFF0F0F3)
                      : const Color(0xFF1E1E1E);
                }

                return Scaffold(
                  backgroundColor: bgColor,
                  body: ValueListenableBuilder<bool>(
                    valueListenable: AppState.highFidelityAnimations,
                    builder: (context, highFidelity, _) {
                      return ValueListenableBuilder<String>(
                        valueListenable: AppState.artworkStyle,
                        builder: (context, backgroundStyle, _) {
                          return Stack(
                            children: [
                              // --- CAPA 1: FONDOS AUTÉNTICOS ---
                              if (layoutMode != "Minimalista Zen" &&
                                  layoutMode != "Cyberpunk Neón") ...[
                                if (layoutMode == "Consola Oscura")
                                  Positioned.fill(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            safeThemeColor.withOpacity(0.8),
                                            bgColor,
                                          ],
                                          stops: const [0.0, 0.7],
                                        ),
                                      ),
                                    ),
                                  ),

                                if (layoutMode == "Cristal Inmersivo" ||
                                    backgroundStyle ==
                                        "Lámpara de Lava (Apple)")
                                  Positioned.fill(
                                    child: RepaintBoundary(
                                      child: ValueListenableBuilder<dynamic>(
                                        valueListenable:
                                            PlayerManager.currentArtwork,
                                        builder: (context, art, _) => Stack(
                                          children: [
                                            Positioned.fill(
                                              child: Transform.scale(
                                                scale: 1.5,
                                                child: HybridArtworkWidget(
                                                  artworkData: art,
                                                  title: PlayerManager
                                                      .currentTitle
                                                      .value,
                                                  artist: PlayerManager
                                                      .currentArtist
                                                      .value,
                                                  isFullSize: true,
                                                ),
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                  sigmaX: 90,
                                                  sigmaY: 90,
                                                ),
                                                child: Container(
                                                  color: Colors.transparent,
                                                ),
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: Container(
                                                color: isLightMode
                                                    ? Colors.white.withOpacity(
                                                        0.4,
                                                      )
                                                    : Colors.black.withOpacity(
                                                        0.5,
                                                      ),
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      isLightMode
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.8,
                                                                )
                                                          : Colors.black
                                                                .withOpacity(
                                                                  0.8,
                                                                ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],

                              if (layoutMode == "Cyberpunk Neón")
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.05,
                                    child: CustomPaint(
                                      painter: GridPainter(
                                        color: safeThemeColor,
                                      ),
                                    ),
                                  ),
                                ),

                              // --- CAPA 2: INTERFAZ PRINCIPAL ---
                              SafeArea(
                                top: false,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        15,
                                        10,
                                        10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: textColor,
                                              size: 38,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                          ValueListenableBuilder<
                                            AudioEngineType
                                          >(
                                            valueListenable:
                                                PlayerManager.activeEngine,
                                            builder: (c, engine, _) {
                                              if (engine ==
                                                  AudioEngineType.radio) {
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.circle,
                                                        color: Colors.red,
                                                        size: 10,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        "RADIO EN VIVO",
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                              return Text(
                                                layoutMode.toUpperCase(),
                                                style: TextStyle(
                                                  color: secondaryTextColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 2,
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.queue_music_rounded,
                                              color: textColor,
                                              size: 28,
                                            ),
                                            onPressed: () {
                                              showModalBottomSheet(
                                                context: context,
                                                backgroundColor:
                                                    Colors.transparent,
                                                isScrollControlled: true,
                                                builder: (context) =>
                                                    const InteractiveQueueView(),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 🖼️ PORTADA GIGANTE
                                    Expanded(
                                      child: Center(
                                        child: GestureDetector(
                                          onHorizontalDragEnd: (details) {
                                            if (PlayerManager
                                                    .activeEngine
                                                    .value !=
                                                AudioEngineType.radio) {
                                              if (details.primaryVelocity! < 0)
                                                PlayerManager.playNext();
                                              else if (details
                                                      .primaryVelocity! >
                                                  0)
                                                PlayerManager.playPrevious();
                                            }
                                          },
                                          child: ValueListenableBuilder<bool>(
                                            valueListenable:
                                                PlayerManager.isPlaying,
                                            builder: (context, playing, _) {
                                              Widget artwork =
                                                  ValueListenableBuilder<
                                                    dynamic
                                                  >(
                                                    valueListenable:
                                                        PlayerManager
                                                            .currentArtwork,
                                                    builder: (c, art, _) =>
                                                        HybridArtworkWidget(
                                                          artworkData: art,
                                                          title: PlayerManager
                                                              .currentTitle
                                                              .value,
                                                          artist: PlayerManager
                                                              .currentArtist
                                                              .value,
                                                          isFullSize: true,
                                                        ),
                                                  );

                                              if (layoutMode == "Neo-Retro") {
                                                artwork = VinylSpinner(
                                                  isPlaying: playing,
                                                  child: ClipOval(
                                                    child: artwork,
                                                  ),
                                                );
                                              } else if (layoutMode ==
                                                  "Consola Oscura") {
                                                artwork = Container(
                                                  decoration: BoxDecoration(
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.5),
                                                        blurRadius: 40,
                                                        offset: const Offset(
                                                          0,
                                                          20,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: artwork,
                                                  ),
                                                );
                                              } else if (layoutMode ==
                                                  "Minimalista Zen") {
                                                artwork = Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          40,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: isLightMode
                                                            ? Colors.black12
                                                            : Colors.black54,
                                                        blurRadius: 25,
                                                        offset: const Offset(
                                                          0,
                                                          15,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          40,
                                                        ),
                                                    child: artwork,
                                                  ),
                                                );
                                              } else if (layoutMode ==
                                                  "Cyberpunk Neón") {
                                                artwork = Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: safeThemeColor,
                                                      width: 3,
                                                    ),
                                                    boxShadow: playing
                                                        ? [
                                                            BoxShadow(
                                                              color: safeThemeColor
                                                                  .withOpacity(
                                                                    0.6,
                                                                  ),
                                                              blurRadius: 30,
                                                              spreadRadius: 5,
                                                            ),
                                                          ]
                                                        : [],
                                                  ),
                                                  child: artwork,
                                                );
                                              } else {
                                                artwork = Container(
                                                  decoration: BoxDecoration(
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        blurRadius: 30,
                                                        offset: const Offset(
                                                          0,
                                                          15,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    child: artwork,
                                                  ),
                                                );
                                              }

                                              double paddingArt =
                                                  (layoutMode ==
                                                          "Consola Oscura" ||
                                                      layoutMode ==
                                                          "Cyberpunk Neón")
                                                  ? 45
                                                  : 35;
                                              return AnimatedScale(
                                                scale: playing ? 1.0 : 0.90,
                                                duration: const Duration(
                                                  milliseconds: 500,
                                                ),
                                                curve: Curves.easeOutCubic,
                                                child: Hero(
                                                  tag: 'cover_active',
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal:
                                                              paddingArt,
                                                        ),
                                                    child: artwork,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 🎛️ CONTROLES BOTTOM
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        30,
                                        0,
                                        30,
                                        40,
                                      ),
                                      child: ValueListenableBuilder<AudioEngineType>(
                                        valueListenable:
                                            PlayerManager.activeEngine,
                                        builder: (context, engine, _) {
                                          return ValueListenableBuilder<String>(
                                            valueListenable:
                                                PlayerManager.currentArtist,
                                            builder: (context, artist, _) {
                                              bool isRadio =
                                                  engine ==
                                                  AudioEngineType.radio;
                                              bool isLofi = _lofiArtists
                                                  .contains(artist);

                                              return Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            ValueListenableBuilder<
                                                              String
                                                            >(
                                                              valueListenable:
                                                                  PlayerManager
                                                                      .currentTitle,
                                                              builder: (c, title, _) => Text(
                                                                title,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 26,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color:
                                                                      textColor,
                                                                  letterSpacing:
                                                                      -0.5,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              artist,
                                                              maxLines: 1,
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                color:
                                                                    secondaryTextColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 15),

                                                      // ✨ BOTÓN DE FAVORITOS (CORAZÓN)
                                                      ValueListenableBuilder<
                                                        String
                                                      >(
                                                        valueListenable:
                                                            PlayerManager
                                                                .currentTitle,
                                                        builder: (context, title, _) {
                                                          return ValueListenableBuilder<
                                                            List<
                                                              Map<
                                                                String,
                                                                dynamic
                                                              >
                                                            >
                                                          >(
                                                            valueListenable:
                                                                FavoritesManager
                                                                    .favoriteItems,
                                                            builder: (context, favs, _) {
                                                              final isFav =
                                                                  FavoritesManager.isFavorite(
                                                                    title,
                                                                  );
                                                              return AnimatedPress(
                                                                onTap: () {
                                                                  HapticFeedback.lightImpact();
                                                                  FavoritesManager.toggleFavorite(
                                                                    title,
                                                                    title,
                                                                    PlayerManager
                                                                        .currentArtist
                                                                        .value,
                                                                    PlayerManager
                                                                        .activeEngine
                                                                        .value
                                                                        .name,
                                                                  );
                                                                },
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        right:
                                                                            8.0,
                                                                      ),
                                                                  child: Icon(
                                                                    isFav
                                                                        ? Icons
                                                                              .favorite_rounded
                                                                        : Icons
                                                                              .favorite_border_rounded,
                                                                    color: isFav
                                                                        ? Colors
                                                                              .redAccent
                                                                        : textColor,
                                                                    size: 32,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                      ),

                                                      if (!isRadio && !isLofi)
                                                        AnimatedPress(
                                                          onTap: () async {
                                                            if (AppState
                                                                .enableHaptics
                                                                .value)
                                                              HapticFeedback.lightImpact();
                                                            // Aquí va la lógica de letras si la tienes
                                                          },
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  12,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: textColor
                                                                  .withOpacity(
                                                                    0.08,
                                                                  ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .lyrics_rounded,
                                                              color: textColor,
                                                              size: 24,
                                                            ),
                                                          ),
                                                        ),
                                                      // ✨ BOTÓN DE CASSETTE (SOLO APARECE EN LA RADIO)
                                                      if (isRadio)
                                                        ValueListenableBuilder<
                                                          bool
                                                        >(
                                                          valueListenable:
                                                              PlayerManager
                                                                  .isRecording,
                                                          builder: (context, recording, _) => AnimatedPress(
                                                            onTap: () {
                                                              if (recording) {
                                                                PlayerManager.stopRecording(
                                                                  context,
                                                                );
                                                              } else {
                                                                PlayerManager.startRecording();
                                                              }
                                                            },
                                                            child: AnimatedContainer(
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        300,
                                                                  ),
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    12,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                // Si está grabando, parpadea en rojo oscuro. Si no, gris discreto.
                                                                color: recording
                                                                    ? Colors.red
                                                                          .withOpacity(
                                                                            0.3,
                                                                          )
                                                                    : textColor
                                                                          .withOpacity(
                                                                            0.08,
                                                                          ),
                                                                shape: BoxShape
                                                                    .circle,
                                                                border:
                                                                    recording
                                                                    ? Border.all(
                                                                        color: Colors
                                                                            .redAccent,
                                                                        width:
                                                                            2,
                                                                      )
                                                                    : null,
                                                              ),
                                                              child: Icon(
                                                                recording
                                                                    ? Icons
                                                                          .stop_circle_rounded
                                                                    : Icons
                                                                          .fiber_manual_record_rounded,
                                                                color: recording
                                                                    ? Colors
                                                                          .redAccent
                                                                    : textColor,
                                                                size: 24,
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                      if (!isRadio && isLofi)
                                                        const Icon(
                                                          Icons
                                                              .local_fire_department_rounded,
                                                          color: Colors.orange,
                                                          size: 28,
                                                        ),
                                                      const SizedBox(width: 10),
                                                      AnimatedPress(
                                                        onTap: () {
                                                          if (AppState
                                                              .enableHaptics
                                                              .value)
                                                            HapticFeedback.lightImpact();
                                                          showModalBottomSheet(
                                                            context: context,
                                                            isScrollControlled:
                                                                true,
                                                            backgroundColor:
                                                                Colors
                                                                    .transparent,
                                                            builder: (context) =>
                                                                const EqualizerProView(),
                                                          );
                                                        },
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration:
                                                              BoxDecoration(
                                                                color: textColor
                                                                    .withOpacity(
                                                                      0.08,
                                                                    ),
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          child: Icon(
                                                            Icons.tune_rounded,
                                                            color: textColor,
                                                            size: 24,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 30),

                                                  if (!isRadio)
                                                    ValueListenableBuilder<
                                                      Duration
                                                    >(
                                                      valueListenable:
                                                          PlayerManager
                                                              .position,
                                                      builder: (context, pos, _) {
                                                        final dur =
                                                            PlayerManager
                                                                .duration
                                                                .value;
                                                        final progress =
                                                            dur.inMilliseconds >
                                                                0
                                                            ? (pos.inMilliseconds /
                                                                      dur.inMilliseconds)
                                                                  .clamp(
                                                                    0.0,
                                                                    1.0,
                                                                  )
                                                            : 0.0;
                                                        return Column(
                                                          children: [
                                                            SliderTheme(
                                                              data: SliderTheme.of(context).copyWith(
                                                                trackHeight:
                                                                    (layoutMode ==
                                                                            "Neo-Retro" ||
                                                                        layoutMode ==
                                                                            "Cyberpunk Neón")
                                                                    ? 6
                                                                    : 4,
                                                                thumbShape:
                                                                    layoutMode ==
                                                                        "Cyberpunk Neón"
                                                                    ? const RoundSliderThumbShape(
                                                                        enabledThumbRadius:
                                                                            0,
                                                                      )
                                                                    : const RoundSliderThumbShape(
                                                                        enabledThumbRadius:
                                                                            6,
                                                                      ),
                                                                overlayShape:
                                                                    SliderComponentShape
                                                                        .noOverlay,
                                                                activeTrackColor:
                                                                    (layoutMode ==
                                                                            "Consola Oscura" ||
                                                                        layoutMode ==
                                                                            "Cyberpunk Neón")
                                                                    ? safeThemeColor
                                                                    : textColor,
                                                                inactiveTrackColor:
                                                                    textColor
                                                                        .withOpacity(
                                                                          0.2,
                                                                        ),
                                                              ),
                                                              child: Slider(
                                                                value: pos
                                                                    .inSeconds
                                                                    .toDouble()
                                                                    .clamp(
                                                                      0,
                                                                      dur.inSeconds
                                                                          .toDouble(),
                                                                    ),
                                                                max:
                                                                    dur.inSeconds
                                                                            .toDouble() >
                                                                        0
                                                                    ? dur.inSeconds
                                                                          .toDouble()
                                                                    : 1,
                                                                onChanged: (v) =>
                                                                    PlayerManager.seek(
                                                                      Duration(
                                                                        seconds:
                                                                            v.toInt(),
                                                                      ),
                                                                    ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 8,
                                                            ),
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Text(
                                                                  "${pos.inMinutes}:${(pos.inSeconds % 60).toString().padLeft(2, '0')}",
                                                                  style: TextStyle(
                                                                    color:
                                                                        secondaryTextColor,
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}",
                                                                  style: TextStyle(
                                                                    color:
                                                                        secondaryTextColor,
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  if (isRadio)
                                                    const SizedBox(height: 40),

                                                  const SizedBox(height: 20),

                                                  Row(
                                                    mainAxisAlignment: isRadio
                                                        ? MainAxisAlignment
                                                              .center
                                                        : MainAxisAlignment
                                                              .spaceBetween,
                                                    children: [
                                                      if (!isRadio && !isLofi)
                                                        ValueListenableBuilder<
                                                          bool
                                                        >(
                                                          valueListenable:
                                                              PlayerManager
                                                                  .isShuffle,
                                                          builder: (c, shuffle, _) => AnimatedPress(
                                                            onTap: () {
                                                              PlayerManager.toggleShuffle();
                                                              if (AppState
                                                                  .enableHaptics
                                                                  .value)
                                                                HapticFeedback.lightImpact();
                                                            },
                                                            child: Icon(
                                                              Icons
                                                                  .shuffle_rounded,
                                                              color: shuffle
                                                                  ? safeThemeColor
                                                                  : secondaryTextColor,
                                                              size: 28,
                                                            ),
                                                          ),
                                                        ),
                                                      if (isLofi)
                                                        const SizedBox(
                                                          width: 28,
                                                        ),

                                                      if (!isRadio)
                                                        AnimatedPress(
                                                          onTap: () {
                                                            PlayerManager.playPrevious();
                                                            if (AppState
                                                                .enableHaptics
                                                                .value)
                                                              HapticFeedback.lightImpact();
                                                          },
                                                          child: Icon(
                                                            Icons
                                                                .skip_previous_rounded,
                                                            color: textColor,
                                                            size: 50,
                                                          ),
                                                        ),

                                                      ValueListenableBuilder<
                                                        bool
                                                      >(
                                                        valueListenable:
                                                            PlayerManager
                                                                .isPlaying,
                                                        builder: (c, playing, _) => AnimatedPress(
                                                          onTap: () {
                                                            if (AppState
                                                                .enableHaptics
                                                                .value)
                                                              HapticFeedback.heavyImpact();
                                                            PlayerManager.togglePlay();
                                                          },
                                                          child: AnimatedContainer(
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      600,
                                                                ),
                                                            width: isRadio
                                                                ? 100
                                                                : 80,
                                                            height: isRadio
                                                                ? 100
                                                                : 80,
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  (layoutMode ==
                                                                      "Minimalista Zen")
                                                                  ? textColor
                                                                  : safeThemeColor,
                                                              borderRadius: BorderRadius.circular(
                                                                layoutMode ==
                                                                        "Cyberpunk Neón"
                                                                    ? 10
                                                                    : (isRadio
                                                                          ? 35
                                                                          : (layoutMode ==
                                                                                    "Neo-Retro"
                                                                                ? 20
                                                                                : 28)),
                                                              ),
                                                              boxShadow:
                                                                  isRadio &&
                                                                      playing
                                                                  ? [
                                                                      BoxShadow(
                                                                        color: safeThemeColor
                                                                            .withOpacity(
                                                                              0.5,
                                                                            ),
                                                                        blurRadius:
                                                                            30,
                                                                        spreadRadius:
                                                                            10,
                                                                      ),
                                                                    ]
                                                                  : [],
                                                            ),
                                                            child: Icon(
                                                              playing
                                                                  ? (PlayerManager.activeEngine.value ==
                                                                            AudioEngineType.radio
                                                                        ? Icons
                                                                              .stop_rounded
                                                                        : Icons
                                                                              .pause_rounded)
                                                                  : Icons
                                                                        .play_arrow_rounded,
                                                              color:
                                                                  layoutMode ==
                                                                      "Minimalista Zen"
                                                                  ? bgColor
                                                                  : contrastIconColor,
                                                              size: isRadio
                                                                  ? 55
                                                                  : 45,
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      if (!isRadio)
                                                        AnimatedPress(
                                                          onTap: () {
                                                            PlayerManager.playNext();
                                                            if (AppState
                                                                .enableHaptics
                                                                .value)
                                                              HapticFeedback.lightImpact();
                                                          },
                                                          child: Icon(
                                                            Icons
                                                                .skip_next_rounded,
                                                            color: textColor,
                                                            size: 50,
                                                          ),
                                                        ),

                                                      if (!isRadio && !isLofi)
                                                        ValueListenableBuilder<
                                                          int
                                                        >(
                                                          valueListenable:
                                                              PlayerManager
                                                                  .repeatMode,
                                                          builder: (c, repeat, _) => AnimatedPress(
                                                            onTap: () {
                                                              PlayerManager
                                                                      .repeatMode
                                                                      .value =
                                                                  (repeat + 1) %
                                                                  3;
                                                              if (AppState
                                                                  .enableHaptics
                                                                  .value)
                                                                HapticFeedback.lightImpact();
                                                            },
                                                            child: Icon(
                                                              repeat == 0
                                                                  ? Icons
                                                                        .repeat_rounded
                                                                  : (repeat == 1
                                                                        ? Icons
                                                                              .repeat_on_rounded
                                                                        : Icons
                                                                              .repeat_one_on_rounded),
                                                              color: repeat > 0
                                                                  ? safeThemeColor
                                                                  : secondaryTextColor,
                                                              size: 28,
                                                            ),
                                                          ),
                                                        ),
                                                      if (isLofi)
                                                        const SizedBox(
                                                          width: 28,
                                                        ),
                                                    ],
                                                  ),

                                                  const SizedBox(
                                                    height: 25,
                                                  ), // Espaciador antes del volumen
                                                  // ✨ LLAMADA AL COMPONENTE DE VOLUMEN SINCRONIZADO
                                                  SystemVolumeSlider(
                                                    activeColor: safeThemeColor
                                                        .withOpacity(0.8),
                                                    textColor: textColor,
                                                  ),
                                                ], // Cierre de la Column de controles
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ], // Cierre de los children de la Column principal
                                ),
                              ),
                            ], // Cierre del Stack principal
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
} // <--- ESTA ES LA LLAVE FINAL DE LA CLASE FullPlayerModal

// 🖌️ HERRAMIENTA EXTRA PARA EL MODO CYBERPUNK (Pegar hasta el final del archivo)
class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 8. MINI REPRODUCTOR FLOTANTE (VERSIÓN PREMIUM GLASSMORPHISM) ---
class FloatingMiniPlayer extends StatelessWidget {
  const FloatingMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: PlayerManager.currentTitle,
      builder: (context, title, _) {
        if (title == "TecConnection") return const SizedBox.shrink();

        return ValueListenableBuilder<Color>(
          valueListenable: PlayerManager.currentThemeColor,
          builder: (context, themeColor, _) {
            // Adaptación de cristal según el tema claro u oscuro
            final isLightMode =
                Theme.of(context).brightness == Brightness.light;
            final glassColor = isLightMode
                ? Colors.white.withOpacity(0.85)
                : const Color(0xFF141416).withOpacity(0.85);

            return GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (c) => const FullPlayerModal(),
              ),
              // ✨ LA MAGIA DE LOS SWIPES: Cambiar canción deslizando
              onHorizontalDragEnd: (details) {
                if (PlayerManager.activeEngine.value != AudioEngineType.radio) {
                  if (details.primaryVelocity! < 0) {
                    PlayerManager.playNext();
                  } else if (details.primaryVelocity! > 0) {
                    PlayerManager.playPrevious();
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(15, 0, 15, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    // Sombra base suave
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                    // Sombra dinámica con el color de la portada
                    BoxShadow(
                      color: themeColor.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 15,
                      sigmaY: 15,
                    ), // Efecto Cristal Esmerilado
                    child: Container(
                      color: glassColor,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                // Portada más cuadrada y moderna
                                Hero(
                                  tag: 'cover_active',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ValueListenableBuilder<dynamic>(
                                      valueListenable:
                                          PlayerManager.currentArtwork,
                                      builder: (c, art, _) => SizedBox(
                                        width: 46,
                                        height: 46,
                                        child: HybridArtworkWidget(
                                          artworkData: art,
                                          title: title,
                                          artist:
                                              PlayerManager.currentArtist.value,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color:
                                              theme.textTheme.bodyLarge?.color,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      ValueListenableBuilder<String>(
                                        valueListenable:
                                            PlayerManager.currentArtist,
                                        builder: (c, artist, _) => Text(
                                          artist,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .textTheme
                                                .bodyMedium
                                                ?.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedPress(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) =>
                                          const AudioRouteSheet(),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Icon(
                                      Icons.speaker_group_rounded,
                                      color: theme.textTheme.bodyMedium?.color,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                ValueListenableBuilder<bool>(
                                  valueListenable: PlayerManager.isPlaying,
                                  builder: (c, playing, _) => AnimatedPress(
                                    onTap: PlayerManager.togglePlay,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: themeColor.withOpacity(
                                          0.15,
                                        ), // Círculo de color dinámico
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        playing
                                            ? (PlayerManager
                                                          .activeEngine
                                                          .value ==
                                                      AudioEngineType.radio
                                                  ? Icons.stop_rounded
                                                  : Icons.pause_rounded)
                                            : Icons.play_arrow_rounded,
                                        color: themeColor,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                            ),
                          ),
                          // Barra de progreso con Glow
                          ValueListenableBuilder<Duration>(
                            valueListenable: PlayerManager.position,
                            builder: (c, pos, _) {
                              final dur = PlayerManager.duration.value;
                              final progress = dur.inMilliseconds > 0
                                  ? (pos.inMilliseconds / dur.inMilliseconds)
                                        .clamp(0.0, 1.0)
                                  : 0.0;
                              return Container(
                                height: 3,
                                width: double.infinity,
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.1),
                                ),
                                child: FractionallySizedBox(
                                  widthFactor:
                                      PlayerManager.activeEngine.value ==
                                          AudioEngineType.radio
                                      ? 1.0
                                      : progress,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color:
                                          PlayerManager.activeEngine.value ==
                                              AudioEngineType.radio
                                          ? Colors.red
                                          : themeColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (PlayerManager
                                                              .activeEngine
                                                              .value ==
                                                          AudioEngineType.radio
                                                      ? Colors.red
                                                      : themeColor)
                                                  .withOpacity(0.6),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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
      },
    );
  }
}

// --- 9. VISTA DE LETRAS INMERSIVAS (MODO KARAOKE FLUIDO) ---
class LyricsProView extends StatefulWidget {
  final String lyrics;
  final String songName;
  const LyricsProView({
    required this.lyrics,
    required this.songName,
    super.key,
  });
  @override
  State<LyricsProView> createState() => _LyricsProViewState();
}

class _LyricsProViewState extends State<LyricsProView> {
  final ScrollController _scrollController = ScrollController();
  List<LrcLine> _lineasSincronizadas = [];
  bool _esSincronizada = false;
  int _indiceActual = -1;
  bool _usuarioInteractuando = false;
  Timer? _reintentoTimer;

  @override
  void initState() {
    super.initState();
    _procesarLetras(widget.lyrics);
    PlayerManager.position.addListener(_sincronizarLetra);
  }

  void _procesarLetras(String rawLyrics) {
    if (rawLyrics.trim().isEmpty) {
      _lineasSincronizadas = [
        LrcLine(
          time: Duration.zero,
          text: "No se encontraron letras para esta pista.",
        ),
      ];
      return;
    }
    final lrcRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    final lineas = rawLyrics.split('\n');
    for (var linea in lineas) {
      final match = lrcRegex.firstMatch(linea);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final ms = int.parse(match.group(3)!.padRight(3, '0'));
        final texto = match.group(4)!.trim();
        if (texto.isNotEmpty) {
          _lineasSincronizadas.add(
            LrcLine(
              time: Duration(minutes: min, seconds: sec, milliseconds: ms),
              text: texto,
            ),
          );
        }
      }
    }
    if (_lineasSincronizadas.isNotEmpty) {
      _esSincronizada = true;
    } else {
      _esSincronizada = false;
      _lineasSincronizadas = lineas
          .map((l) => LrcLine(time: Duration.zero, text: l))
          .toList();
    }
  }

  void _sincronizarLetra() {
    if (!_esSincronizada || _lineasSincronizadas.isEmpty) return;
    final posMs = PlayerManager.position.value.inMilliseconds;
    int nuevoIndice = _lineasSincronizadas.lastIndexWhere(
      (linea) => linea.time.inMilliseconds <= posMs,
    );
    if (nuevoIndice != _indiceActual && nuevoIndice != -1) {
      setState(() => _indiceActual = nuevoIndice);
      if (!_usuarioInteractuando && _scrollController.hasClients) {
        final double alturaEstimadaLinea = AppState.fontSize.value * 2.8;
        final targetScroll =
            (_indiceActual * alturaEstimadaLinea) -
            (MediaQuery.of(context).size.height * 0.25);
        _scrollController.animateTo(
          targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    PlayerManager.position.removeListener(_sincronizarLetra);
    _scrollController.dispose();
    _reintentoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: Container(
        color: const Color(0xFF141416),
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(25, 15, 25, 15),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.songName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (notification is UserScrollNotification) {
                    setState(() => _usuarioInteractuando = true);
                    _reintentoTimer?.cancel();
                    _reintentoTimer = Timer(const Duration(seconds: 3), () {
                      if (mounted) {
                        setState(() => _usuarioInteractuando = false);
                        _sincronizarLetra();
                      }
                    });
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: MediaQuery.of(context).size.height * 0.3,
                  ),
                  itemCount: _lineasSincronizadas.length,
                  itemBuilder: (context, index) {
                    final isActiva = index == _indiceActual;
                    return ValueListenableBuilder<double>(
                      valueListenable: AppState.fontSize,
                      builder: (context, size, _) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontSize: isActiva ? size + 4 : size,
                              fontWeight: isActiva
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: _esSincronizada
                                  ? (isActiva ? Colors.white : Colors.white24)
                                  : Colors.white70,
                              height: 1.5,
                            ),
                            child: Text(
                              _lineasSincronizadas[index].text,
                              textAlign: TextAlign.left,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 10. TECCONNECTION DEVICE HUB (GESTOR BLUETOOTH PREMIUM) ---
class AudioRouteSheet extends StatefulWidget {
  const AudioRouteSheet({super.key});
  @override
  State<AudioRouteSheet> createState() => _AudioRouteSheetState();
}

class _AudioRouteSheetState extends State<AudioRouteSheet> {
  List<AudioDevice> _dispositivos = [];
  bool _buscando = true;
  @override
  void initState() {
    super.initState();
    _escanearDispositivosReales();
  }

  Future<void> _escanearDispositivosReales() async {
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices();
      if (mounted) {
        setState(() {
          _dispositivos = devices.where((d) {
            if (!d.isOutput) return false;
            return d.type == AudioDeviceType.builtInSpeaker ||
                d.type == AudioDeviceType.bluetoothA2dp ||
                d.type == AudioDeviceType.wiredHeadphones ||
                d.type == AudioDeviceType.wiredHeadset;
          }).toList();
          final seen = <String>{};
          _dispositivos.retainWhere((d) => seen.add(d.name));
          _buscando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = PlayerManager.currentThemeColor.value;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(25, 15, 25, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Icon(Icons.speaker_group_rounded, color: themeColor, size: 28),
              const SizedBox(width: 12),
              Text(
                "Dispositivos",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.textTheme.bodyLarge?.color,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(30.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: _dispositivos.isEmpty
                        ? [
                            ListTile(
                              leading: Icon(
                                Icons.smartphone_rounded,
                                color: themeColor,
                              ),
                              title: Text(
                                "Altavoz del Teléfono",
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Icon(
                                Icons.check_circle_rounded,
                                color: themeColor,
                              ),
                            ),
                          ]
                        : _dispositivos.map((d) {
                            bool isBluetooth =
                                d.type == AudioDeviceType.bluetoothA2dp;
                            bool isWired =
                                d.type == AudioDeviceType.wiredHeadphones ||
                                d.type == AudioDeviceType.wiredHeadset;
                            bool isSpeaker =
                                d.type == AudioDeviceType.builtInSpeaker;
                            IconData icon = Icons.speaker_rounded;
                            if (isBluetooth)
                              icon = Icons.bluetooth_audio_rounded;
                            if (isWired) icon = Icons.headphones_rounded;
                            if (isSpeaker) icon = Icons.smartphone_rounded;
                            String nombre = d.name;
                            if (isSpeaker &&
                                (nombre.isEmpty ||
                                    nombre.toLowerCase().contains("speaker")))
                              nombre = "Altavoz del Teléfono";
                            else if (nombre.isEmpty)
                              nombre = "Dispositivo de Audio";
                            String subtitulo = "Conexión interna";
                            if (isBluetooth)
                              subtitulo = "Conectado vía Bluetooth";
                            if (isWired) subtitulo = "Conectado por cable";
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: themeColor),
                              ),
                              title: Text(
                                nombre,
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                subtitulo,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.waves_rounded,
                                color: Colors.grey,
                              ),
                            );
                          }).toList(),
                  ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor.withOpacity(0.1),
                foregroundColor: themeColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
              },
              icon: const Icon(Icons.bluetooth_searching_rounded),
              label: const Text(
                "EMPAREJAR NUEVO DISPOSITIVO",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 11. VISTA DE COLA INTERACTIVA INTELIGENTE (UP NEXT) ---
class InteractiveQueueView extends StatefulWidget {
  const InteractiveQueueView({super.key});
  @override
  State<InteractiveQueueView> createState() => _InteractiveQueueViewState();
}

class _InteractiveQueueViewState extends State<InteractiveQueueView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = PlayerManager.currentThemeColor.value;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 15),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: Row(
              children: [
                Text(
                  "A continuación",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const Spacer(),
                // ✨ Solo mostramos el número de pistas si estamos en modo Local
                ValueListenableBuilder<AudioEngineType>(
                  valueListenable: PlayerManager.activeEngine,
                  builder: (context, engine, _) {
                    if (engine == AudioEngineType.local) {
                      return Text(
                        "${PlayerManager.playbackQueue.length} pistas",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),

          // ✨ EL CEREBRO DE LA COLA (EL IF QUE PEDISTE)
          Expanded(
            child: ValueListenableBuilder<AudioEngineType>(
              valueListenable: PlayerManager.activeEngine,
              builder: (context, engine, _) {
                // 🟢 1. SI ESTÁ SONANDO SPOTIFY
                if (engine == AudioEngineType.spotify) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.speaker_group_rounded,
                          color: Color(0xFF1DB954),
                          size: 70,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Conectado a Spotify",
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "La cola de reproducción está siendo\ngestionada por la app de Spotify.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // 🔴 2. SI ESTÁ SONANDO LA RADIO
                if (engine == AudioEngineType.radio) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.radio_rounded,
                          color: Colors.redAccent,
                          size: 70,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Transmisión en Vivo",
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Las estaciones globales no\ntienen cola de reproducción.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // 🎵 3. SI ESTÁ SONANDO EL MP3 LOCAL (Tu código original)
                if (PlayerManager.playbackQueue.isEmpty) {
                  return const Center(
                    child: Text(
                      "La cola está vacía",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ReorderableListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: PlayerManager.playbackQueue.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      PlayerManager.reorderQueue(oldIndex, newIndex);
                    });
                  },
                  itemBuilder: (context, index) {
                    final song = PlayerManager.playbackQueue[index];
                    final bool isCurrent =
                        PlayerManager.currentSong.value?.id == song.id;
                    return ListTile(
                      key: ValueKey(song.id),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 45,
                          height: 45,
                          child: HybridArtworkWidget(
                            artworkData: song.id,
                            title: song.title,
                            artist: song.artist ?? "",
                          ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.w900
                              : FontWeight.bold,
                          color: isCurrent
                              ? themeColor
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        song.artist ?? "Desconocido",
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.drag_handle_rounded,
                        color: Colors.white24,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- 13. CONSOLA DE ECUALIZACIÓN PRO (Verdugo de VLC) ---
class EqualizerProView extends StatefulWidget {
  const EqualizerProView({super.key});
  @override
  State<EqualizerProView> createState() => _EqualizerProViewState();
}

class _EqualizerProViewState extends State<EqualizerProView> {
  bool _eqEnabled = false;
  double _loudness = 0.0;
  @override
  void initState() {
    super.initState();
    _checkEqStatus();
  }

  Future<void> _checkEqStatus() async {
    if (!Platform.isAndroid) return;
    try {
      final enabled = await PlayerManager.equalizer.enabled;
      if (mounted) {
        setState(() {
          _eqEnabled = enabled;
        });
      }
    } catch (e) {
      debugPrint("Hardware no soportado.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = PlayerManager.currentThemeColor.value;
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(25, 15, 25, 20),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: themeColor, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Estudio de Audio",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.textTheme.bodyLarge?.color,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _eqEnabled,
                activeColor: themeColor,
                onChanged: (v) async {
                  try {
                    await PlayerManager.equalizer.setEnabled(v);
                    HapticFeedback.lightImpact();
                    setState(() => _eqEnabled = v);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Función bloqueada por tu dispositivo."),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const Divider(height: 30, color: Colors.white10),
          Row(
            children: [
              const Icon(Icons.speaker_rounded, color: Colors.grey, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Potencia Pura (Pre-Amp)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  value: _loudness,
                  min: 0,
                  max: 2000,
                  activeColor: themeColor,
                  inactiveColor: Colors.white10,
                  onChanged: (v) {
                    setState(() => _loudness = v);
                    try {
                      PlayerManager.loudnessEnhancer.setTargetGain(v / 1000);
                      PlayerManager.loudnessEnhancer.setEnabled(v > 0);
                    } catch (e) {}
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<AndroidEqualizerParameters>(
              future: PlayerManager.equalizer.parameters,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError || !snapshot.hasData)
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block_rounded,
                          color: theme.dividerColor,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Hardware de audio no compatible.",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                final params = snapshot.data!;
                return Opacity(
                  opacity: _eqEnabled ? 1.0 : 0.3,
                  child: IgnorePointer(
                    ignoring: !_eqEnabled,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: params.bands.map((band) {
                        return _buildVerticalFader(
                          band,
                          params,
                          themeColor,
                          theme,
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalFader(
    AndroidEqualizerBand band,
    AndroidEqualizerParameters params,
    Color themeColor,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Text(
          "${(band.centerFrequency / 1000).toStringAsFixed(0)}k",
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: StreamBuilder<double>(
              stream: band.gainStream,
              builder: (context, snapshot) {
                final currentGain = snapshot.data ?? 0.0;
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: currentGain,
                    min: params.minDecibels,
                    max: params.maxDecibels,
                    activeColor: themeColor,
                    inactiveColor: Colors.white10,
                    onChanged: (v) {
                      band.setGain(v);
                      HapticFeedback.selectionClick();
                    },
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text("Hz", style: TextStyle(color: Colors.white24, fontSize: 10)),
      ],
    );
  }
}

// ==========================================
// --- 14. LA BÓVEDA DE LETRAS OFFLINE (.lrc) ---
class LyricsVault {
  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  static Future<File> _getFileRef(String title, String artist) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeTitle = _sanitizeFilename(title);
    final safeArtist = _sanitizeFilename(artist);
    return File('${directory.path}/${safeTitle}_$safeArtist.lrc');
  }

  static Future<String?> readLyrics(String title, String artist) async {
    try {
      final file = await _getFileRef(title, artist);
      if (await file.exists()) {
        debugPrint("🗄️ BÓVEDA: Letra cargada.");
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint("ERROR BÓVEDA.");
    }
    return null;
  }

  static Future<void> saveLyrics(
    String title,
    String artist,
    String lyricsData,
  ) async {
    try {
      if (lyricsData.contains("No se encontró") ||
          lyricsData.contains("Buscando..."))
        return;
      final file = await _getFileRef(title, artist);
      await file.writeAsString(lyricsData);
      debugPrint("🗄️ BÓVEDA: Letra guardada.");
    } catch (e) {
      debugPrint("ERROR BÓVEDA.");
    }
  }
}

// --- 15. EL BUSCADOR DE LETRAS ---
class LyricsEngine {
  static Future<String> buscarCancion(String title, String artist) async {
    final localLyrics = await LyricsVault.readLyrics(title, artist);
    if (localLyrics != null) return localLyrics;
    if (!NetworkRadar.isOnline.value)
      return "[00:00.00] 🚫 Modo Sin Conexión\n[00:05.00] No se encontró en la bóveda local.";

    final cleanTitle = _cleanTitle(title);
    final encodedTitle = Uri.encodeComponent(cleanTitle);
    final encodedArtist = Uri.encodeComponent(artist);
    final url = Uri.parse(
      "https://lrclib.net/api/get?track_name=$encodedTitle&artist_name=$encodedArtist",
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['syncedLyrics'] != null) {
          final fetchedLyrics = data['syncedLyrics'];
          await LyricsVault.saveLyrics(title, artist, fetchedLyrics);
          return fetchedLyrics;
        } else if (data['plainLyrics'] != null) {
          return "[00:00.00] 📝 Letra sin sincronizar\n${data['plainLyrics']}";
        }
      }
      return "[00:00.00] 🔍 No se encontró la letra exacta.";
    } catch (e) {
      return "[00:00.00] ⚠️ Error de conexión.";
    }
  }

  static String _cleanTitle(String title) {
    String clean = title.replaceAll(RegExp(r'\(.*?\)'), '');
    clean = clean.replaceAll(RegExp(r'\[.*?\]'), '');
    clean = clean.replaceAll(
      RegExp(
        r'official video|audio|lyric|lyrics|remastered|remaster',
        caseSensitive: false,
      ),
      '',
    );
    return clean.trim();
  }
}

// ✨ COMPONENTE DE VOLUMEN SINCRONIZADO (Fábrica independiente)
class SystemVolumeSlider extends StatefulWidget {
  final Color activeColor;
  final Color textColor;
  const SystemVolumeSlider({
    super.key,
    required this.activeColor,
    required this.textColor,
  });

  @override
  State<SystemVolumeSlider> createState() => _SystemVolumeSliderState();
}

class _SystemVolumeSliderState extends State<SystemVolumeSlider> {
  double _currentVolume = 0.5;

  @override
  void initState() {
    super.initState();
    // 1. Leer volumen inicial
    FlutterVolumeController.getVolume().then(
      (v) => setState(() => _currentVolume = v ?? 0.5),
    );
    // 2. Escuchar cambios de los botones físicos
    FlutterVolumeController.addListener((v) {
      if (mounted) setState(() => _currentVolume = v);
    });
  }

  @override
  void dispose() {
    FlutterVolumeController.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveSlider(
      min: 0.0,
      max: 1.0,
      initialProgress: _currentVolume,
      startIcon: Icon(
        Icons.volume_mute_rounded,
        color: widget.textColor.withOpacity(0.5),
        size: 20,
      ),
      endIcon: Icon(
        Icons.volume_up_rounded,
        color: widget.textColor.withOpacity(0.5),
        size: 20,
      ),
      foregroundColor: widget.activeColor,
      onChanged: (v) {
        FlutterVolumeController.setVolume(v); // Cambia el volumen del sistema
      },
    );
  }
}
// ✨ EL REPRODUCTOR DE VIDEO VISUAL (VLC STYLE)
class YouTubeVideoModal extends StatefulWidget {
  final String videoId;
  const YouTubeVideoModal({super.key, required this.videoId});

  @override
  State<YouTubeVideoModal> createState() => _YouTubeVideoModalState();
}

class _YouTubeVideoModalState extends State<YouTubeVideoModal> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Extraemos el ID del video si pusiste el link completo, o usamos el ID directo
    final vId = YoutubePlayer.convertUrlToId(widget.videoId) ?? widget.videoId;
    
    _controller = YoutubePlayerController(
      initialVideoId: vId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: true, // Ideal para videos de Lofi o Study with me
        hideControls: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior para cerrar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                color: Colors.black87,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Estudia Conmigo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // El Reproductor de Video
              YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.redAccent,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.redAccent,
                  handleColor: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}