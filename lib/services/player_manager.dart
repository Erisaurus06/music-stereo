import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/image_uri.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'radio_engine.dart';
import 'app_state.dart';
import '../artwork_engine.dart';

// --- EL DIRECTOR DE RÍOS (ESTADO ESTRICTO) ---
enum AudioEngineType { local, spotify, radio, none }

class PlayerManager {
  static final AndroidEqualizer equalizer = AndroidEqualizer();
  static final AndroidLoudnessEnhancer loudnessEnhancer =
      AndroidLoudnessEnhancer();

  static final ValueNotifier<bool> isRecording = ValueNotifier(false);
  static String? _currentRecordPath;
  static String? _currentRadioUrl;
  static http.Client? _radioRecordClient;
  static IOSink? _radioRecordSink;

  static final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [loudnessEnhancer, equalizer],
    ),
  );

  static final OnAudioQuery audioQuery = OnAudioQuery();

  static final ValueNotifier<AudioEngineType> activeEngine = ValueNotifier(
    AudioEngineType.none,
  );
  static final ValueNotifier<bool> isSpotifyLinked = ValueNotifier(false);
  static final ValueNotifier<SongModel?> currentSong = ValueNotifier(null);

  static final ValueNotifier<String> currentTitle = ValueNotifier(
    "TecConnection",
  );
  static final ValueNotifier<String> currentArtist = ValueNotifier(
    "Dinobot Engine",
  );
  static final ValueNotifier<dynamic> currentArtwork = ValueNotifier(null);

  static final ValueNotifier<Color> currentThemeColor = ValueNotifier(
    const Color(0xFF1DB954),
  );

  static final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  static final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  static final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  // ✨ FIX: BANDERA PARA EL SCROLL REBELDE
  static bool isUserDraggingSlider = false;

  static final ValueNotifier<List<SongModel>> allLocalSongs = ValueNotifier([]);

  // ✨ FIX: MEMORIA DE RADIOS FAVORITAS
  static final ValueNotifier<List<RadioStation>> favoriteRadios = ValueNotifier(
    [],
  );

  static List<SongModel> playbackQueue = [];

  static final ValueNotifier<bool> isShuffle = ValueNotifier(false);
  static final ValueNotifier<int> repeatMode = ValueNotifier(0);

  static Timer? _spotifyTimer;

  static Future<void> connectToSpotify() async {
    try {
      final bool result = await SpotifySdk.connectToSpotifyRemote(
        clientId: "TU_CLIENT_ID", // Reemplaza con tu Client ID
        redirectUrl: "TU_REDIRECT_URL",
      );
      isSpotifyLinked.value = result;
      if (result) startSpotifyRadar();
    } catch (e) {
      debugPrint("❌ Error al enlazar Spotify: $e");
    }
  }

  static void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final SongModel song = playbackQueue.removeAt(oldIndex);
    playbackQueue.insert(newIndex, song);
    HapticFeedback.mediumImpact();
  }

  static void _updateQueue() {
    if (isShuffle.value) {
      playbackQueue = List.from(allLocalSongs.value)..shuffle(Random());
      if (currentSong.value != null) {
        playbackQueue.removeWhere((s) => s.id == currentSong.value!.id);
        playbackQueue.insert(0, currentSong.value!);
      }
    } else {
      playbackQueue = List.from(allLocalSongs.value);
    }
  }

  static void init() {
    player.playingStream.listen((playing) {
      if (activeEngine.value == AudioEngineType.local)
        isPlaying.value = playing;
    });

    player.positionStream.listen((p) {
      // ✨ FIX: Solo actualiza la posición si el usuario NO está tocando la barra
      if (activeEngine.value == AudioEngineType.local &&
          !isUserDraggingSlider) {
        position.value = p;
      }
    });

    player.durationStream.listen((d) {
      if (activeEngine.value == AudioEngineType.local && d != null)
        duration.value = d;
    });

    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed &&
          activeEngine.value == AudioEngineType.local) {
        if (repeatMode.value == 2) {
          seek(Duration.zero);
          player.play();
        } else {
          playNext();
        }
      }
    });
  }

  static Future<void> loadLocalMusic() async {
    try {
      List<SongModel> songs = await audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      songs = songs.where((song) {
        final dataStr = song.data.toLowerCase();
        return dataStr.endsWith('.mp3') ||
            dataStr.endsWith('.m4a') ||
            dataStr.endsWith('.wav') ||
            dataStr.endsWith('.ogg');
      }).toList();

      allLocalSongs.value = songs;
      debugPrint(
        "🎵 Escáner completado: Se encontraron ${songs.length} canciones.",
      );
    } catch (e) {
      debugPrint("❌ Error cargando MP3: $e");
    }
  }

  static Future<void> _updateDominantColorLocal(SongModel song) async {
    currentThemeColor.value = const Color(0xFF2C2C2C);
    try {
      Uint8List? artwork = await audioQuery.queryArtwork(
        song.id,
        ArtworkType.AUDIO,
      );
      if (artwork != null) {
        final palette = await PaletteGenerator.fromImageProvider(
          MemoryImage(artwork),
        );
        currentThemeColor.value =
            palette.dominantColor?.color ??
            palette.vibrantColor?.color ??
            const Color(0xFF2C2C2C);
        return;
      }
      String? url = await ArtworkEngine.buscarPortada(
        song.title,
        song.artist ?? "",
      );
      if (url != null) {
        final palette = await PaletteGenerator.fromImageProvider(
          NetworkImage(url),
        );
        currentThemeColor.value =
            palette.dominantColor?.color ??
            palette.vibrantColor?.color ??
            const Color(0xFF2C2C2C);
      }
    } catch (e) {
      debugPrint("Error color: $e");
    }
  }

  static void startSpotifyRadar() {
    try {
      SpotifySdk.subscribePlayerState().listen((state) {
        if (state.track != null) {
          if (!state.isPaused &&
              activeEngine.value != AudioEngineType.spotify) {
            activeEngine.value = AudioEngineType.spotify;
            player.pause();
          }

          if (activeEngine.value == AudioEngineType.spotify) {
            if (currentTitle.value != state.track!.name) {
              SpotifySdk.getImage(
                imageUri: state.track!.imageUri,
                dimension: ImageDimension.large,
              ).then((bytes) async {
                if (bytes != null) {
                  try {
                    final palette = await PaletteGenerator.fromImageProvider(
                      MemoryImage(bytes),
                    );
                    currentThemeColor.value =
                        palette.dominantColor?.color ??
                        palette.vibrantColor?.color ??
                        const Color(0xFF1DB954);
                  } catch (_) {}
                }
              });
            }

            currentTitle.value = state.track!.name;
            currentArtist.value =
                state.track!.artist.name ?? "Artista Desconocido";
            currentArtwork.value = state.track!.imageUri;

            isPlaying.value = !state.isPaused;

            // ✨ FIX: Control manual del Slider en Spotify
            if (!isUserDraggingSlider) {
              position.value = Duration(milliseconds: state.playbackPosition);
            }
            duration.value = Duration(milliseconds: state.track!.duration);

            _spotifyTimer?.cancel();
            if (!state.isPaused) {
              _spotifyTimer = Timer.periodic(const Duration(seconds: 1), (
                timer,
              ) {
                if (position.value.inSeconds < duration.value.inSeconds &&
                    !isUserDraggingSlider) {
                  position.value = Duration(
                    seconds: position.value.inSeconds + 1,
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

  static void toggleShuffle() {
    if (activeEngine.value == AudioEngineType.spotify) {
      SpotifySdk.toggleShuffle();
    } else {
      isShuffle.value = !isShuffle.value;
      _updateQueue();
    }
  }

  static Future<void> _crossfade(
    bool isFadingOut, {
    int milliseconds = 400,
  }) async {
    const steps = 20;
    final stepDuration = milliseconds ~/ steps;

    if (isFadingOut) {
      for (int i = steps; i >= 0; i--) {
        await player.setVolume(i / steps);
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
    } else {
      for (int i = 0; i <= steps; i++) {
        await player.setVolume(i / steps);
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
    }
  }

  static Future<void> playSong(SongModel song) async {
    try {
      if (player.playing && activeEngine.value == AudioEngineType.local) {
        await _crossfade(true, milliseconds: 300);
      }

      activeEngine.value = AudioEngineType.local;
      isPlaying.value = false;
      await player.stop();
      await player.setVolume(1.0);

      _spotifyTimer?.cancel();
      if (isSpotifyLinked.value) {
        try {
          await SpotifySdk.pause();
        } catch (_) {}
      }

      currentSong.value = song;
      currentTitle.value = song.title;
      currentArtist.value = song.artist ?? "Desconocido";
      currentArtwork.value = song.id;
      _updateDominantColorLocal(song);

      final audioSource = AudioSource.uri(
        Uri.file(song.data),
        tag: MediaItem(
          id: song.id.toString(),
          album: song.album ?? "Biblioteca Local",
          title: song.title,
          artist: song.artist,
        ),
      );

      await player.setAudioSource(audioSource);
      await player.setVolume(0.0);
      isPlaying.value = true;
      player.play();
      _crossfade(false, milliseconds: 600);
    } catch (e) {
      isPlaying.value = false;
      await player.setVolume(1.0);
      debugPrint("❌ Error reproduciendo MP3: $e");
    }
  }

  static Future<void> togglePlay() async {
    HapticFeedback.lightImpact();
    try {
      if (activeEngine.value == AudioEngineType.spotify) {
        if (isPlaying.value) {
          isPlaying.value = false;
          await SpotifySdk.pause();
        } else {
          isPlaying.value = true;
          await SpotifySdk.resume();
        }
      } else if (activeEngine.value == AudioEngineType.radio) {
        if (player.playing) {
          isPlaying.value = false;
          await player.pause();
        } else {
          isPlaying.value = true;
          await player.setVolume(1.0);
          player.play();
        }
      } else if (activeEngine.value == AudioEngineType.local) {
        if (player.playing) {
          isPlaying.value = false;
          await _crossfade(true, milliseconds: 300);
          await player.pause();
        } else {
          if (player.processingState != ProcessingState.idle) {
            isPlaying.value = true;
            await player.setVolume(0.0);
            player.play();
            await _crossfade(false, milliseconds: 400);
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Interrupción evitada: $e");
      isPlaying.value = player.playing;
      await player.setVolume(1.0);
    }
  }

  static Future<void> playRadio(RadioStation station) async {
    try {
      activeEngine.value = AudioEngineType.radio;
      _currentRadioUrl = station.url;
      isPlaying.value = false;
      await player.stop();
      await player.setVolume(1.0);

      _spotifyTimer?.cancel();
      if (isSpotifyLinked.value) {
        try {
          await SpotifySdk.pause();
        } catch (_) {}
      }

      currentTitle.value = station.name;
      currentArtist.value = "EN VIVO • ${station.country.toUpperCase()}";
      currentArtwork.value = station.favicon;

      if (station.favicon.isNotEmpty) {
        try {
          final palette = await PaletteGenerator.fromImageProvider(
            NetworkImage(station.favicon),
          );
          currentThemeColor.value =
              palette.dominantColor?.color ??
              palette.vibrantColor?.color ??
              const Color(0xFF2C2C2C);
        } catch (_) {
          currentThemeColor.value = const Color(0xFF2C2C2C);
        }
      } else {
        currentThemeColor.value = const Color(0xFF2C2C2C);
      }

      final audioSource = AudioSource.uri(
        Uri.parse(station.url),
        tag: MediaItem(
          id: station.id,
          album: "Radio Global",
          title: station.name,
          artist: "En Vivo • ${station.country}",
        ),
      );

      await player.setAudioSource(audioSource);
      isPlaying.value = true;
      player.play();
    } catch (e) {
      isPlaying.value = false;
      debugPrint("❌ Error sintonizando: $e");
    }
  }

  // ✨ FIX DEFINITIVO: Eliminamos el error de puntero nulo (NoSuchMethodError)
  static Future<void> toggleRadioFavorite(RadioStation station) async {
    // Clona la lista actual
    List<RadioStation> actuales = List.from(favoriteRadios.value);

    // Verifica si ya la tienes guardada
    int index = actuales.indexWhere((r) => r.id == station.id);

    if (index >= 0) {
      actuales.removeAt(index); // La quita si ya estaba
    } else {
      actuales.add(station); // La agrega si es nueva
    }

    // Actualiza la vista al instante
    favoriteRadios.value = actuales;

    // Sube LA LISTA COMPLETA a Supabase usando el cliente oficial instanciado
    List<Object?> jsonList = actuales.map((r) => r.toJson()).toList();
    try {
      // 🧠 Usamos Supabase.instance.client que garantiza conectarse al cliente vivo de Supabase en tu Moto G41
      final deSupabase = Supabase.instance.client;
      final usuarioActual = deSupabase.auth.currentUser;

      if (usuarioActual != null) {
        await deSupabase
            .from('profiles')
            .update({'favorite_radios': jsonList})
            .eq('id', usuarioActual.id);
        debugPrint(
          "❤️ Favoritos de Radio sincronizados con Supabase: ${actuales.length}",
        );
      } else {
        debugPrint(
          "⚠️ No se guardó en la nube: No hay un usuario logueado en esta sesión.",
        );
      }
    } catch (e) {
      debugPrint("❌ Error guardando radio en Supabase: $e");
    }
  }

  static Future<void> playNext() async {
    if (AppState.mixedPlayback.value) {
      bool switchRiver = Random().nextBool();
      if (switchRiver && isSpotifyLinked.value) {
        activeEngine.value = AudioEngineType.spotify;
        SpotifySdk.skipNext();
        return;
      }
    }
    if (activeEngine.value == AudioEngineType.spotify) {
      SpotifySdk.skipNext();
    } else {
      if (currentSong.value == null || playbackQueue.isEmpty) return;

      int currentIndex = playbackQueue.indexWhere(
        (s) => s.id == currentSong.value!.id,
      );
      if (currentIndex < playbackQueue.length - 1) {
        playSong(playbackQueue[currentIndex + 1]);
      } else if (repeatMode.value == 1) {
        playSong(playbackQueue.first);
      }
    }
  }

  static Future<void> playPrevious() async {
    if (activeEngine.value == AudioEngineType.spotify) {
      SpotifySdk.skipPrevious();
    } else {
      if (currentSong.value == null || playbackQueue.isEmpty) return;
      if (position.value.inSeconds > 3) {
        seek(Duration.zero);
        return;
      }
      int currentIndex = playbackQueue.indexWhere(
        (s) => s.id == currentSong.value!.id,
      );
      if (currentIndex > 0) playSong(playbackQueue[currentIndex - 1]);
    }
  }

  static void seek(Duration d) {
    if (activeEngine.value == AudioEngineType.spotify) {
      SpotifySdk.seekTo(positionedMilliseconds: d.inMilliseconds);
      position.value = d;
    } else {
      player.seek(d);
    }
  }

  static Future<void> startRecording() async {
    if (activeEngine.value != AudioEngineType.radio || _currentRadioUrl == null)
      return;
    try {
      final directory = Directory('/storage/emulated/0/Music/TecConnection');
      if (!await directory.exists()) await directory.create(recursive: true);

      String safeName = currentTitle.value
          .replaceAll(RegExp(r'[^\w\s]+'), '')
          .replaceAll(' ', '_');
      String fileName =
          "REC_${safeName}_${DateTime.now().millisecondsSinceEpoch}.mp3";
      _currentRecordPath = '${directory.path}/$fileName';

      _radioRecordClient = http.Client();
      final request = http.Request('GET', Uri.parse(_currentRadioUrl!));
      final response = await _radioRecordClient!.send(request);

      final file = File(_currentRecordPath!);
      _radioRecordSink = file.openWrite();

      response.stream.listen(
        (chunk) {
          _radioRecordSink?.add(chunk);
        },
        onError: (e) {
          stopRecording(null);
        },
        onDone: () {
          stopRecording(null);
        },
      );

      isRecording.value = true;
      HapticFeedback.vibrate();
    } catch (e) {
      debugPrint("Error al grabar stream: $e");
    }
  }

  static Future<void> stopRecording(BuildContext? context) async {
    if (!isRecording.value) return;
    try {
      isRecording.value = false;
      HapticFeedback.heavyImpact();

      _radioRecordClient?.close();
      _radioRecordClient = null;

      await _radioRecordSink?.flush();
      await _radioRecordSink?.close();
      _radioRecordSink = null;

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("📼 ¡Grabación guardada en tu biblioteca!"),
            backgroundColor: currentThemeColor.value,
          ),
        );
      }
      await loadLocalMusic();
    } catch (e) {
      debugPrint("Error cerrando archivo: $e");
    }
  }
}
