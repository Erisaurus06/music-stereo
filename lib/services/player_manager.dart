import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/image_uri.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'radio_engine.dart';
import 'app_state.dart';
import '../artwork_engine.dart';

// --- EL DIRECTOR DE RÍOS (ESTADO ESTRICTO) ---
enum AudioEngineType { local, spotify, radio, none }

// --- 2. MOTOR CENTRAL HÍBRIDO (RÍOS PARALELOS + CAMALEÓN VISUAL + LOSSLESS) ---
class PlayerManager {
  // EFECTOS DE GRADO DE ESTUDIO
  static final AndroidEqualizer equalizer = AndroidEqualizer();
  static final AndroidLoudnessEnhancer loudnessEnhancer =
      AndroidLoudnessEnhancer();
  // ✨ VARIABLES DE LA GRABADORA DE CASSETTE DIGITAL
  static final AudioRecorder _audioRecorder = AudioRecorder();
  static final ValueNotifier<bool> isRecording = ValueNotifier(false);
  static String? _currentRecordPath;
  // MOTOR CON PIPELINE DE HARDWARE INYECTADO
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

  // La memoria del Camaleón Visual (Azul por defecto)
  static final ValueNotifier<Color> currentThemeColor = ValueNotifier(
    DinobotTheme.primaryBlue,
  );

  static final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  static final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  static final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  static final ValueNotifier<List<SongModel>> allLocalSongs = ValueNotifier([]);

  // COLA PÚBLICA PARA ARRASTRAR Y SOLTAR
  static List<SongModel> playbackQueue = [];

  static final ValueNotifier<bool> isShuffle = ValueNotifier(false);
  static final ValueNotifier<int> repeatMode = ValueNotifier(0);

  static Timer? _spotifyTimer;

  // REORDENAR LA COLA
  static void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final SongModel song = playbackQueue.removeAt(oldIndex);
    playbackQueue.insert(newIndex, song);
    HapticFeedback.mediumImpact(); // Vibración premium al soltar
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
      if (activeEngine.value == AudioEngineType.local) {
        isPlaying.value = playing;
      }
    });
    player.positionStream.listen((p) {
      if (activeEngine.value == AudioEngineType.local) position.value = p;
    });
    player.durationStream.listen((d) {
      if (activeEngine.value == AudioEngineType.local && d != null) {
        duration.value = d;
      }
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

  // ✨ EL ESCÁNER DE METADATOS PREMIUM (Solo canciones de verdad)
  static Future<void> loadLocalMusic() async {
    bool hasPermission = await audioQuery.permissionsStatus();
    if (!hasPermission) hasPermission = await audioQuery.permissionsRequest();

    if (hasPermission) {
      List<SongModel> songs = await audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // Filtro de Calidad: Descartamos audios menores a 30 segundos (tonos, notas de voz)
      songs = songs.where((song) => (song.duration ?? 0) > 30000).toList();

      allLocalSongs.value = songs;
      _updateQueue();
      debugPrint(
        "🎵 Escáner completado: ${songs.length} canciones premium encontradas.",
      );
    }
  }

  // LA MAGIA DE EXTRACCIÓN DE COLOR DE LAS PORTADAS
  static Future<void> _updateDominantColorLocal(SongModel song) async {
    currentThemeColor.value = DinobotTheme.primaryBlue; // Reseteo
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
            DinobotTheme.primaryBlue;
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
            DinobotTheme.primaryBlue;
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
                        DinobotTheme.primaryBlue;
                  } catch (_) {}
                }
              });
            }

            currentTitle.value = state.track!.name;
            currentArtist.value =
                state.track!.artist.name ?? "Artista Desconocido";
            currentArtwork.value = state.track!.imageUri;

            isPlaying.value = !state.isPaused;
            position.value = Duration(milliseconds: state.playbackPosition);
            duration.value = Duration(milliseconds: state.track!.duration);

            _spotifyTimer?.cancel();
            if (!state.isPaused) {
              _spotifyTimer = Timer.periodic(const Duration(seconds: 1), (
                timer,
              ) {
                if (position.value.inSeconds < duration.value.inSeconds) {
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

  // ✨ EL MOTOR DE CROSSFADE (TRANSICIONES ESTILO DJ)
  static Future<void> _crossfade(
    bool isFadingOut, {
    int milliseconds = 400,
  }) async {
    const steps = 20;
    final stepDuration = milliseconds ~/ steps;

    if (isFadingOut) {
      // Fade Out (De 100% a 0%)
      for (int i = steps; i >= 0; i--) {
        await player.setVolume(i / steps);
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
    } else {
      // Fade In (De 0% a 100%)
      for (int i = 0; i <= steps; i++) {
        await player.setVolume(i / steps);
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
    }
  }

  // 1. REPRODUCCIÓN LOCAL (CON FADE IN Y FADE OUT)
  static Future<void> playSong(SongModel song) async {
    try {
      // Si ya estaba sonando algo, hacemos Fade Out antes de cambiar
      if (player.playing && activeEngine.value == AudioEngineType.local) {
        await _crossfade(true, milliseconds: 300);
      }

      activeEngine.value = AudioEngineType.local;
      isPlaying.value = false;
      await player.stop();
      await player.setVolume(1.0); // Restaurar volumen interno

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

      // Inicia en silencio y hace Fade In (Corte premium)
      await player.setVolume(0.0);
      isPlaying.value = true;
      player.play();
      _crossfade(false, milliseconds: 600); // Entrada suave Estilo DJ
    } catch (e) {
      isPlaying.value = false;
      await player.setVolume(1.0);
      debugPrint("❌ Error reproduciendo MP3: $e");
    }
  }

  // 2. PAUSA/PLAY SUAVE
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
        // 📻 LA RADIO NO LLEVA CROSSFADE (Corte directo para no dañar el streaming)
        if (player.playing) {
          isPlaying.value = false;
          await player.pause();
        } else {
          isPlaying.value = true;
          await player.setVolume(1.0);
          player.play();
        }
      } else if (activeEngine.value == AudioEngineType.local) {
        // 🎵 MP3 SÍ LLEVA CROSSFADE ESTILO DJ
        if (player.playing) {
          isPlaying.value = false;
          await _crossfade(true, milliseconds: 300); // Pausa con Fade Out
          await player.pause();
        } else {
          if (player.processingState != ProcessingState.idle) {
            isPlaying.value = true;
            await player.setVolume(0.0);
            player.play();
            await _crossfade(false, milliseconds: 400); // Play con Fade In
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Interrupción evitada: $e");
      isPlaying.value = player.playing;
      await player.setVolume(1.0);
    }
  }

  // ✨ 3. RADIO GLOBAL BLINDADA
  static Future<void> playRadio(RadioStation station) async {
    try {
      activeEngine.value = AudioEngineType.radio;
      isPlaying.value = false;
      await player.stop();
      await player.setVolume(1.0); // 🚨 RESTAURAR VOLUMEN SIEMPRE

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
              DinobotTheme.primaryBlue;
        } catch (_) {
          currentThemeColor.value = DinobotTheme.primaryBlue;
        }
      } else {
        currentThemeColor.value = DinobotTheme.primaryBlue;
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

  // 3. SIGUIENTE CANCIÓN (Automáticamente usa Crossfade gracias a playSong)
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

  // 4. CANCIÓN ANTERIOR
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

  // ✨ LA GRABADORA DE CASSETTE DIGITAL (START)
  static Future<void> startRecording() async {
    try {
      if (activeEngine.value != AudioEngineType.radio || !player.playing) {
        debugPrint("Solo puedes grabar mientras escuchas la radio.");
        return;
      }

      // Pedimos permiso de micrófono (necesario en Android para grabar audio interno/externo)
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint("Se necesita permiso de micrófono para grabar.");
        return;
      }

      // Preparamos la "Cinta" en la carpeta de documentos del celular
      final directory = await getApplicationDocumentsDirectory();
      String fileName =
          "TecConnection_REC_${DateTime.now().millisecondsSinceEpoch}.m4a";
      _currentRecordPath = '${directory.path}/$fileName';

      // ¡Botón REC presionado!
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: _currentRecordPath!,
      );

      isRecording.value = true;
      HapticFeedback.vibrate(); // Vibración larga indicando que está grabando
    } catch (e) {
      debugPrint("Error al iniciar grabación: $e");
    }
  }

  // ✨ LA GRABADORA DE CASSETTE DIGITAL (STOP Y GUARDAR)
  static Future<void> stopRecording(BuildContext context) async {
    try {
      final path = await _audioRecorder.stop();
      isRecording.value = false;
      HapticFeedback.heavyImpact(); // Vibración fuerte de cierre

      if (path != null) {
        debugPrint("Cassette guardado en: $path");

        // Le avisamos al usuario que su grabación está a salvo
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "📼 ¡Grabación guardada con éxito!\nRevisa tu Biblioteca Local.",
              ),
              backgroundColor: currentThemeColor.value,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // Forzamos un re-escaneo para que el nuevo MP3 aparezca en la lista
        await loadLocalMusic();
      }
    } catch (e) {
      debugPrint("Error al detener grabación: $e");
    }
  }
}
