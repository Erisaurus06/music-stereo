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

import '../models/app_models.dart';
import '../services/player_manager.dart';
import '../services/bubble_manager.dart';
import '../services/app_state.dart';
import '../services/network_radar.dart';
import 'design_components.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'bluetooth_panel.dart';
import '../screens/equalizer_view.dart'; // ✨ IMPORTAMOS LA NUEVA PANTALLA
import '../screens/lyrics_view.dart'; // ✨ IMPORTAMOS LA PANTALLA DE LETRAS

// --- 7. REPRODUCTOR GIGANTE (UX MEJORADO: CRISTAL Y CONTRASTE DINÁMICO) ---
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: PlayerManager.currentThemeColor,
      builder: (context, themeColor, _) {
        final double statusBarHeight = MediaQuery.of(context).padding.top;

        // 🧠 CEREBRO DE LUMINOSIDAD: Si el color de la portada es demasiado oscuro,
        // lo aclaramos artificialmente (subimos el lightness) para que nunca se pierda en negro.
        final HSLColor hslColor = HSLColor.fromColor(themeColor);
        final Color safeThemeColor = hslColor.lightness < 0.35
            ? hslColor.withLightness(0.45).toColor()
            : themeColor;

        // 🌗 CONTRASTE INTELIGENTE: Detectamos si el color final es claro u oscuro
        // para decidir si pintamos los textos/iconos principales de Blanco o Negro.
        final bool isLightColor = safeThemeColor.computeLuminance() > 0.45;
        final Color contrastIconColor = isLightColor
            ? Colors.black
            : Colors.white;

        return Padding(
          padding: EdgeInsets.only(top: statusBarHeight + 15),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            child: ValueListenableBuilder<String>(
              valueListenable: AppState.playerLayout,
              builder: (context, layoutMode, _) {
                final bool isLightMode =
                    Theme.of(context).brightness == Brightness.light;

                Color bgColor = isLightMode ? Colors.white : Colors.black;
                Color textColor = isLightMode ? Colors.black87 : Colors.white;
                Color dynSecondaryText = isLightMode
                    ? Colors.black54
                    : Colors.white70;

                // ✨ CRISTAL ADAPTATIVO: Si el fondo de la portada es claro, los botones de fondo
                // se vuelven negro transparente. Si es oscuro, blanco transparente. ¡Impecable legibilidad!
                Color glassBtnColor = isLightColor
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.15);

                if (layoutMode == "Neo-Retro") {
                  bgColor = isLightMode
                      ? const Color(0xFFF5F4F0)
                      : const Color(0xFF1A1A1D);
                } else if (layoutMode == "Consola Oscura") {
                  bgColor = const Color(0xFF121212);
                  textColor = Colors.white;
                  dynSecondaryText = Colors.white70;
                  glassBtnColor = Colors.white.withValues(alpha: 0.12);
                } else if (layoutMode == "Cyberpunk Neón") {
                  bgColor = const Color(0xFF09090B);
                  textColor = Colors.white;
                  dynSecondaryText = Colors.white54;
                  glassBtnColor = safeThemeColor.withValues(alpha: 0.15);
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
                              // 🌌 FONDO DINÁMICO MEJORADO (MENOS BORROSO)
                              if (layoutMode == "Cristal Inmersivo" ||
                                  backgroundStyle == "Lámpara de Lava (Apple)")
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: ValueListenableBuilder<dynamic>(
                                      // --- SECCIÓN: FONDO DINÁMICO ---
                                      valueListenable:
                                          PlayerManager.currentArtwork,
                                      builder: (context, art, _) => Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Transform.scale(
                                              scale: 1.2,
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
                                                sigmaX: 35,
                                                sigmaY: 35,
                                              ),
                                              child: Container(
                                                color: Colors.transparent,
                                              ),
                                            ),
                                          ),
                                          Positioned.fill(
                                            child: Container(
                                              color: isLightColor
                                                  ? Colors.white.withValues(
                                                      alpha: 0.4,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.5,
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
                                                    isLightColor
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.9,
                                                              )
                                                        : Colors.black
                                                              .withValues(
                                                                alpha: 0.9,
                                                              ),
                                                  ],
                                                  stops: const [0.4, 1.0],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

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

                              SafeArea(
                                bottom: false,
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
                                        // --- SECCIÓN: CABECERA ---
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color:
                                                  isLightColor &&
                                                      layoutMode ==
                                                          "Cristal Inmersivo"
                                                  ? Colors.black
                                                  : textColor,
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
                                                        .withValues(alpha: 0.2),
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
                                                  color:
                                                      isLightColor &&
                                                          layoutMode ==
                                                              "Cristal Inmersivo"
                                                      ? Colors.black54
                                                      : dynSecondaryText,
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
                                              color:
                                                  isLightColor &&
                                                      layoutMode ==
                                                          "Cristal Inmersivo"
                                                  ? Colors.black
                                                  : textColor,
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

                                    // --- SECCIÓN: PORTADA ---
                                    Expanded(
                                      child: Center(
                                        child: GestureDetector(
                                          onHorizontalDragEnd: (details) {
                                            if (PlayerManager
                                                    .activeEngine
                                                    .value !=
                                                AudioEngineType.radio) {
                                              if ((details.primaryVelocity ??
                                                      0) <
                                                  0) {
                                                PlayerManager.playNext();
                                              } else if ((details
                                                          .primaryVelocity ??
                                                      0) >
                                                  0) {
                                                PlayerManager.playPrevious();
                                              }
                                            }
                                          },
                                          child: ValueListenableBuilder<bool>(
                                            valueListenable:
                                                PlayerManager.isPlaying,
                                            builder: (context, playing, _) {
                                              Widget
                                              artwork = ValueListenableBuilder<dynamic>(
                                                valueListenable: PlayerManager
                                                    .currentArtwork,
                                                builder: (c, art, _) =>
                                                    AnimatedSwitcher(
                                                      duration: const Duration(
                                                        milliseconds: 600,
                                                      ),
                                                      transitionBuilder:
                                                          (
                                                            Widget child,
                                                            Animation<double>
                                                            animation,
                                                          ) {
                                                            return FadeTransition(
                                                              opacity:
                                                                  animation,
                                                              child: child,
                                                            );
                                                          },
                                                      child: HybridArtworkWidget(
                                                        key: ValueKey(
                                                          art?.toString() ??
                                                              'empty',
                                                        ),
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
                                              );

                                              if (layoutMode == "Neo-Retro") {
                                                artwork = VinylSpinner(
                                                  isPlaying: playing,
                                                  child: ClipOval(
                                                    child: artwork,
                                                  ),
                                                );
                                              } else if (layoutMode ==
                                                  "Minimalista Zen") {
                                                artwork = AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 400,
                                                  ),
                                                  curve: Curves.easeOut,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          40,
                                                        ),
                                                    boxShadow: playing
                                                        ? [
                                                            BoxShadow(
                                                              color: themeColor
                                                                  .withValues(
                                                                    alpha: 0.4,
                                                                  ),
                                                              blurRadius: 25,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    15,
                                                                  ),
                                                            ),
                                                          ]
                                                        : [],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          40,
                                                        ),
                                                    child: artwork,
                                                  ),
                                                );
                                              } else {
                                                artwork = AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 400,
                                                  ),
                                                  curve: Curves.easeOut,
                                                  decoration: BoxDecoration(
                                                    boxShadow: playing
                                                        ? [
                                                            BoxShadow(
                                                              color: themeColor
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                              blurRadius: 35,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    15,
                                                                  ),
                                                            ),
                                                          ]
                                                        : [],
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

                                              return AnimatedScale(
                                                scale: playing ? 1.0 : 0.85,
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                curve: Curves.easeOut,
                                                child: Hero(
                                                  tag: 'cover_active',
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 35,
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

                                    // --- SECCIÓN: CONTROLES ---
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        30,
                                        0,
                                        30,
                                        MediaQuery.of(context).padding.bottom >
                                                0
                                            ? MediaQuery.of(
                                                    context,
                                                  ).padding.bottom +
                                                  20
                                            : 40,
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

                                              // Colores finales respetando el contraste dinámico de la portada
                                              final Color activeTextColor =
                                                  layoutMode ==
                                                      "Cristal Inmersivo"
                                                  ? contrastIconColor
                                                  : textColor;
                                              final Color activeSubtitleColor =
                                                  layoutMode ==
                                                      "Cristal Inmersivo"
                                                  ? (isLightColor
                                                        ? Colors.black54
                                                        : Colors.white70)
                                                  : dynSecondaryText;

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
                                                                      activeTextColor,
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
                                                                    activeSubtitleColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 15),

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
                                                                        : activeTextColor,
                                                                    size: 32,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(width: 10),

                                                      // ✨ BOTÓN PARA LANZAR LA BURBUJA
                                                      AnimatedPress(
                                                        onTap: () {
                                                          if (AppState
                                                              .enableHaptics
                                                              .value) {
                                                            HapticFeedback.lightImpact();
                                                          }
                                                          BubbleManager.show();
                                                          // Opcional: cerrar el reproductor grande al activar la burbuja
                                                          // Navigator.pop(context);
                                                        },
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration:
                                                              BoxDecoration(
                                                                color:
                                                                    glassBtnColor,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          child: Icon(
                                                            Icons
                                                                .picture_in_picture_alt_rounded,
                                                            color:
                                                                activeTextColor,
                                                            size: 24,
                                                          ),
                                                        ),
                                                      ),

                                                      if (!isRadio && !isLofi)
                                                        AnimatedPress(
                                                          onTap: () async {
                                                            if (AppState
                                                                .enableHaptics
                                                                .value) {
                                                              HapticFeedback.lightImpact();
                                                            }
                                                            // ✨ LANZAMOS LA PANTALLA DE LETRAS REAL (CON LA API)
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder:
                                                                    (context) =>
                                                                        const LyricsView(),
                                                              ),
                                                            );
                                                          },
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  12,
                                                                ),
                                                            decoration:
                                                                BoxDecoration(
                                                                  color:
                                                                      glassBtnColor,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                            child: Icon(
                                                              Icons
                                                                  .lyrics_rounded,
                                                              color:
                                                                  activeTextColor,
                                                              size: 24,
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
                                                              .value) {
                                                            HapticFeedback.lightImpact();
                                                          }
                                                          // ✨ AHORA NAVEGA A LA PANTALLA COMPLETA
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  const EqualizerView(),
                                                            ),
                                                          );
                                                        },
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration:
                                                              BoxDecoration(
                                                                color:
                                                                    glassBtnColor,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          child: Icon(
                                                            Icons.tune_rounded,
                                                            color:
                                                                activeTextColor,
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
                                                        return Column(
                                                          children: [
                                                            SliderTheme(
                                                              data: SliderTheme.of(context).copyWith(
                                                                trackHeight: 4,
                                                                thumbShape:
                                                                    const RoundSliderThumbShape(
                                                                      enabledThumbRadius:
                                                                          6,
                                                                    ),
                                                                overlayShape:
                                                                    SliderComponentShape
                                                                        .noOverlay,
                                                                activeTrackColor:
                                                                    layoutMode ==
                                                                        "Cristal Inmersivo"
                                                                    ? safeThemeColor
                                                                    : (layoutMode ==
                                                                              "Minimalista Zen"
                                                                          ? textColor
                                                                          : safeThemeColor),
                                                                inactiveTrackColor:
                                                                    activeTextColor
                                                                        .withValues(
                                                                          alpha:
                                                                              0.15,
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
                                                                onChangeStart: (_) =>
                                                                    PlayerManager
                                                                            .isUserDraggingSlider =
                                                                        true,
                                                                onChanged: (v) =>
                                                                    PlayerManager
                                                                        .position
                                                                        .value = Duration(
                                                                      seconds: v
                                                                          .toInt(),
                                                                    ),
                                                                onChangeEnd: (v) {
                                                                  PlayerManager.seek(
                                                                    Duration(
                                                                      seconds: v
                                                                          .toInt(),
                                                                    ),
                                                                  );
                                                                  Future.delayed(
                                                                    const Duration(
                                                                      milliseconds:
                                                                          200,
                                                                    ),
                                                                    () => PlayerManager.isUserDraggingSlider =
                                                                        false,
                                                                  );
                                                                },
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
                                                                        activeSubtitleColor,
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
                                                                        activeSubtitleColor,
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
                                                                  .value) {
                                                                HapticFeedback.lightImpact();
                                                              }
                                                            },
                                                            child: Icon(
                                                              Icons
                                                                  .shuffle_rounded,
                                                              color: shuffle
                                                                  ? safeThemeColor
                                                                  : activeSubtitleColor,
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
                                                                .value) {
                                                              HapticFeedback.lightImpact();
                                                            }
                                                          },
                                                          child: Icon(
                                                            Icons
                                                                .skip_previous_rounded,
                                                            color:
                                                                activeTextColor,
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
                                                                .value) {
                                                              HapticFeedback.heavyImpact();
                                                            }
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
                                                                  layoutMode ==
                                                                      "Minimalista Zen"
                                                                  ? textColor
                                                                  : safeThemeColor,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    isRadio
                                                                        ? 35
                                                                        : 28,
                                                                  ),
                                                              boxShadow: playing
                                                                  ? [
                                                                      BoxShadow(
                                                                        color:
                                                                            (layoutMode ==
                                                                                        "Minimalista Zen"
                                                                                    ? textColor
                                                                                    : safeThemeColor)
                                                                                .withValues(
                                                                                  alpha: 0.4,
                                                                                ),
                                                                        blurRadius:
                                                                            25,
                                                                        spreadRadius:
                                                                            4,
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
                                                                .value) {
                                                              HapticFeedback.lightImpact();
                                                            }
                                                          },
                                                          child: Icon(
                                                            Icons
                                                                .skip_next_rounded,
                                                            color:
                                                                activeTextColor,
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
                                                                  .value) {
                                                                HapticFeedback.lightImpact();
                                                              }
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
                                                                  : activeSubtitleColor,
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

                                                  const SizedBox(height: 25),
                                                  SystemVolumeSlider(
                                                    activeColor:
                                                        layoutMode ==
                                                            "Minimalista Zen"
                                                        ? textColor
                                                        : safeThemeColor
                                                              .withValues(
                                                                alpha: 0.8,
                                                              ),
                                                    textColor: activeTextColor,
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
}

// 🖌️ HERRAMIENTA EXTRA PARA EL MODO CYBERPUNK
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
class FloatingMiniPlayer extends StatefulWidget {
  const FloatingMiniPlayer({super.key});

  @override
  State<FloatingMiniPlayer> createState() => _FloatingMiniPlayerState();
}

class _FloatingMiniPlayerState extends State<FloatingMiniPlayer> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<String>(
      valueListenable: PlayerManager.currentTitle,
      builder: (context, title, _) {
        if (title == "TecConnection") return const SizedBox.shrink();

        return ValueListenableBuilder<Color>(
          valueListenable: PlayerManager.currentThemeColor,
          builder: (context, themeColor, _) {
            final isLightMode =
                Theme.of(context).brightness == Brightness.light;
            final glassColor = isLightMode
                ? Colors.white
                : const Color(0xFF141416);

            return GestureDetector(
              onTapDown: (_) {
                HapticFeedback.lightImpact();
                setState(() => _isPressed = true);
              },
              onTapUp: (_) {
                setState(() => _isPressed = false);
                HapticFeedback.mediumImpact();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (c) => const FullPlayerModal(),
                );
              },
              onTapCancel: () => setState(() => _isPressed = false),
              onHorizontalDragEnd: (details) {
                if (PlayerManager.activeEngine.value != AudioEngineType.radio) {
                  if ((details.primaryVelocity ?? 0) < 0) {
                    PlayerManager.playNext();
                  } else if ((details.primaryVelocity ?? 0) > 0) {
                    PlayerManager.playPrevious();
                  }
                }
              },
              child: AnimatedScale(
                scale: _isPressed ? 0.96 : 1.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.fromLTRB(
                    15,
                    0,
                    15,
                    bottomPadding > 0 ? bottomPadding + 10 : 20,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: -2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              glassColor.withValues(
                                alpha: isLightMode ? 0.75 : 0.45,
                              ),
                              glassColor.withValues(
                                alpha: isLightMode ? 0.5 : 0.2,
                              ),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: isLightMode ? 0.3 : 0.08,
                            ),
                            width: 1.2,
                          ),
                        ),
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
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            child: HybridArtworkWidget(
                                              key: ValueKey(
                                                art?.toString() ?? 'empty',
                                              ),
                                              artworkData: art,
                                              title: title,
                                              artist: PlayerManager
                                                  .currentArtist
                                                  .value,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                            color: theme
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
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
                                      HapticFeedback.selectionClick();
                                      BluetoothPanel.show(context);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Icon(
                                        Icons.speaker_group_rounded,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: PlayerManager.isPlaying,
                                    builder: (c, playing, _) => AnimatedPress(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        PlayerManager.togglePlay();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: themeColor.withValues(
                                            alpha: 0.15,
                                          ),
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
                                    color: themeColor.withValues(alpha: 0.1),
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor:
                                        PlayerManager.activeEngine.value ==
                                            AudioEngineType.radio
                                        ? 1.0
                                        : progress,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.linearToEaseOut,
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
                                                            AudioEngineType
                                                                .radio
                                                        ? Colors.red
                                                        : themeColor)
                                                    .withValues(alpha: 0.6),
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
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        25,
        15,
        25,
        bottomPadding > 0 ? bottomPadding + 20 : 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
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
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _buscando
                  ? const Padding(
                      padding: EdgeInsets.all(30.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : ListView(
                      // ✨ FIX OVERFLOW: De Column a ListView deslizable
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      children: _dispositivos.isEmpty
                          ? [
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.smartphone_rounded,
                                    color: themeColor,
                                  ),
                                ),
                                title: Text(
                                  "Moto G41 (Altavoz Interno)",
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
                              if (isBluetooth) {
                                icon = Icons.bluetooth_audio_rounded;
                              }
                              if (isWired) icon = Icons.headphones_rounded;
                              if (isSpeaker) icon = Icons.smartphone_rounded;

                              String nombre = d.name;
                              if (isSpeaker &&
                                  (nombre.isEmpty ||
                                      nombre.toLowerCase().contains(
                                        "speaker",
                                      ))) {
                                nombre = "Moto G41 (Altavoz Interno)";
                              } else if (nombre.isEmpty) {
                                nombre = "Dispositivo de Audio";
                              }

                              String subtitulo = "Conexión interna";
                              if (isBluetooth) {
                                subtitulo = "Conectado vía Bluetooth";
                              }
                              if (isWired) subtitulo = "Conectado por cable";

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.1),
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
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor.withValues(alpha: 0.1),
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
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.40,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(
                  alpha: 0.55,
                ), // ✨ Efecto Glassmorphism transparente
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
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
                  Expanded(
                    child: ValueListenableBuilder<AudioEngineType>(
                      valueListenable: PlayerManager.activeEngine,
                      builder: (context, engine, _) {
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
                        if (PlayerManager.playbackQueue.isEmpty) {
                          return const Center(
                            child: Text(
                              "La cola está vacía",
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        return ReorderableListView.builder(
                          scrollController: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: 100 + bottomPadding),
                          itemCount: PlayerManager.playbackQueue.length,
                          onReorder: (oldIndex, newIndex) {
                            HapticFeedback.lightImpact();
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
            ),
          ),
        );
      },
    );
  }
}

// --- 13. CONSOLA DE ECUALIZACIÓN PRO ---
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
      final enabled = PlayerManager.equalizer.enabled;
      if (mounted) setState(() => _eqEnabled = enabled);
    } catch (e) {
      debugPrint("Hardware no soportado.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = PlayerManager.currentThemeColor.value;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        25,
        15,
        25,
        bottomPadding > 0 ? bottomPadding + 10 : 20,
      ),
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
                activeThumbColor: themeColor,
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
                child: _PremiumHorizontalFader(
                  value: _loudness,
                  themeColor: themeColor,
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
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
                }
                final params = snapshot.data!;
                return Opacity(
                  opacity: _eqEnabled ? 1.0 : 0.3,
                  child: IgnorePointer(
                    ignoring: !_eqEnabled,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: params.bands
                            .map(
                              (band) => SizedBox(
                                width:
                                    70, // ✨ Ancho fijo para proteger contra Overflow
                                child: _VerticalEqFader(
                                  band: band,
                                  params: params,
                                  themeColor: themeColor,
                                ),
                              ),
                            )
                            .toList(),
                      ),
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
}

// ✨ NUEVO: COMPONENTE DE FADER VERTICAL REACTIVO E INMERSIVO
class _VerticalEqFader extends StatefulWidget {
  final AndroidEqualizerBand band;
  final AndroidEqualizerParameters params;
  final Color themeColor;

  const _VerticalEqFader({
    required this.band,
    required this.params,
    required this.themeColor,
  });

  @override
  State<_VerticalEqFader> createState() => _VerticalEqFaderState();
}

class _VerticalEqFaderState extends State<_VerticalEqFader> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: _isDragging ? widget.themeColor : Colors.grey,
            fontSize: _isDragging ? 14 : 12,
            fontWeight: FontWeight.bold,
          ),
          child: Text(
            "${(widget.band.centerFrequency / 1000).toStringAsFixed(0)}k",
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: StreamBuilder<double>(
              stream: widget.band.gainStream,
              builder: (context, snapshot) {
                final currentGain = snapshot.data ?? 0.0;
                return AnimatedScale(
                  scale: _isDragging ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: _isDragging ? 8 : 4,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: _isDragging ? 14 : 10,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 24,
                      ),
                    ),
                    child: Slider(
                      value: currentGain,
                      min: widget.params.minDecibels,
                      max: widget.params.maxDecibels,
                      activeColor: widget.themeColor,
                      inactiveColor: Colors.white10,
                      onChangeStart: (_) {
                        HapticFeedback.lightImpact();
                        setState(() => _isDragging = true);
                      },
                      onChanged: (v) {
                        widget.band.setGain(v);
                      },
                      onChangeEnd: (_) {
                        HapticFeedback.mediumImpact();
                        setState(() => _isDragging = false);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: _isDragging
                ? widget.themeColor.withValues(alpha: 0.5)
                : Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          child: const Text("Hz"),
        ),
      ],
    );
  }
}

// ✨ NUEVO: COMPONENTE HORIZONTAL PREMIUM PARA LOUDNESS
class _PremiumHorizontalFader extends StatefulWidget {
  final double value;
  final Color themeColor;
  final ValueChanged<double> onChanged;

  const _PremiumHorizontalFader({
    required this.value,
    required this.themeColor,
    required this.onChanged,
  });

  @override
  State<_PremiumHorizontalFader> createState() =>
      _PremiumHorizontalFaderState();
}

class _PremiumHorizontalFaderState extends State<_PremiumHorizontalFader> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isDragging ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: _isDragging ? 8 : 4,
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: _isDragging ? 14 : 10,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        ),
        child: Slider(
          value: widget.value,
          min: 0,
          max: 2000,
          activeColor: widget.themeColor,
          inactiveColor: Colors.white10,
          onChangeStart: (_) {
            HapticFeedback.lightImpact();
            setState(() => _isDragging = true);
          },
          onChanged: widget.onChanged,
          onChangeEnd: (_) {
            HapticFeedback.mediumImpact();
            setState(() => _isDragging = false);
          },
        ),
      ),
    );
  }
}

// --- 14. LA BÓVEDA DE LETRAS OFFLINE (.lrc) ---
class LyricsVault {
  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  static Future<File> _getFileRef(String title, String artist) async {
    final directory = await getApplicationDocumentsDirectory();
    return File(
      '${directory.path}/${_sanitizeFilename(title)}_${_sanitizeFilename(artist)}.lrc',
    );
  }

  static Future<String?> readLyrics(String title, String artist) async {
    try {
      final file = await _getFileRef(title, artist);
      if (await file.exists()) return await file.readAsString();
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
          lyricsData.contains("Buscando...")) {
        return;
      }
      final file = await _getFileRef(title, artist);
      await file.writeAsString(lyricsData);
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
    if (!NetworkRadar.isOnline.value) {
      return "[00:00.00] 🚫 Modo Sin Conexión\n[00:05.00] No se encontró en la bóveda local.";
    }

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

// ✨ COMPONENTE DE VOLUMEN SINCRONIZADO BLINDADO
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
  bool _isDragging = false;
  @override
  void initState() {
    super.initState();
    FlutterVolumeController.getVolume().then(
      (v) => setState(() => _currentVolume = v ?? 0.5),
    );
    FlutterVolumeController.addListener((v) {
      if (mounted && !_isDragging) setState(() => _currentVolume = v);
    });
  }

  @override
  void dispose() {
    FlutterVolumeController.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.volume_mute_rounded,
          color: widget.textColor.withValues(alpha: 0.5),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: widget.activeColor,
              inactiveTrackColor: widget.textColor.withValues(alpha: 0.15),
              thumbColor: widget.activeColor,
            ),
            child: Slider(
              value: _currentVolume.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              onChangeStart: (_) => _isDragging = true,
              onChanged: (v) {
                setState(() => _currentVolume = v);
                FlutterVolumeController.setVolume(v);
              },
              onChangeEnd: (_) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) setState(() => _isDragging = false);
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          Icons.volume_up_rounded,
          color: widget.textColor.withValues(alpha: 0.5),
          size: 20,
        ),
      ],
    );
  }
}
