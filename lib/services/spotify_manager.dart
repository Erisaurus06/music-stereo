import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:palette_generator/palette_generator.dart';

import '../api_keys.dart';
import 'player_manager.dart';

/// Gestor independiente para la integración y radar de Spotify SDK
class SpotifyManager {
  static final ValueNotifier<bool> isSpotifyLinked = ValueNotifier(false);
  static Timer? spotifyTimer;

  static Future<void> connectToSpotify() async {
    try {
      final bool result = await SpotifySdk.connectToSpotifyRemote(
        clientId: ApiKeys.spotifyClientId,
        redirectUrl: "tecconnection://callback",
      );
      isSpotifyLinked.value = result;
      if (result) startSpotifyRadar();
    } catch (e) {
      debugPrint("❌ Error al enlazar Spotify: $e");
    }
  }

  static void startSpotifyRadar() {
    try {
      SpotifySdk.subscribePlayerState().listen((state) {
        if (state.track != null) {
          if (!state.isPaused &&
              PlayerManager.activeEngine.value != AudioEngineType.spotify) {
            PlayerManager.activeEngine.value = AudioEngineType.spotify;
            PlayerManager.player.pause();
          }

          if (PlayerManager.activeEngine.value == AudioEngineType.spotify) {
            if (PlayerManager.currentTitle.value != state.track!.name) {
              SpotifySdk.getImage(
                imageUri: state.track!.imageUri,
                dimension: ImageDimension.large,
              ).then((bytes) async {
                if (bytes != null) {
                  try {
                    final palette = await PaletteGenerator.fromImageProvider(
                      MemoryImage(bytes),
                    );
                    PlayerManager.updateThemeColor(
                      palette.dominantColor?.color ??
                          palette.vibrantColor?.color ??
                          const Color(0xFF2563EB),
                    );
                  } catch (e) {
                    debugPrint("⚠️ Error generando paleta de Spotify: $e");
                  }
                }
              });
            }

            PlayerManager.currentTitle.value = state.track!.name;
            PlayerManager.currentArtist.value =
                state.track!.artist.name ?? "Artista Desconocido";
            PlayerManager.currentArtwork.value = state.track!.imageUri;
            PlayerManager.isPlaying.value = !state.isPaused;

            if (!PlayerManager.isUserDraggingSlider) {
              PlayerManager.position.value = Duration(
                milliseconds: state.playbackPosition,
              );
            }
            PlayerManager.duration.value = Duration(
              milliseconds: state.track!.duration,
            );

            spotifyTimer?.cancel();
            if (!state.isPaused) {
              spotifyTimer = Timer.periodic(const Duration(seconds: 1), (
                timer,
              ) {
                if (PlayerManager.position.value.inSeconds <
                        PlayerManager.duration.value.inSeconds &&
                    !PlayerManager.isUserDraggingSlider) {
                  PlayerManager.position.value = Duration(
                    seconds: PlayerManager.position.value.inSeconds + 1,
                  );
                }
              });
            }
          }
        }
      });
    } catch (e) {
      debugPrint("Error en Río Spotify: $e");
    }
  }
}
