import 'dart:async';
import 'dart:convert';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'radio_engine.dart';
import 'app_state.dart';
import '../artwork_engine.dart';
import '../api_keys.dart';

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
  static Timer?
  _recordingTimer; // ✨ NUEVO: Temporizador de seguridad para grabar

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
    const Color(0xFF2563EB), // ✨ Azul por defecto en lugar de Verde Spotify
  );

  // ✨ NUEVO: Color dinámico para íconos y textos (Blanco o Negro) garantizando lectura
  static final ValueNotifier<Color> currentForegroundColor = ValueNotifier(
    Colors.white,
  );

  // ✨ NUEVO: Función inteligente para el Camaleón en dispositivos Pro/Ultra
  static void updateThemeColor(Color newColor) {
    currentThemeColor.value = newColor;
    final bool isDark = newColor.computeLuminance() < 0.5;
    currentForegroundColor.value = isDark ? Colors.white : Colors.black;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark
            ? Brightness.dark
            : Brightness.light, // Magia en iOS
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

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
        clientId: ApiKeys.spotifyClientId,
        redirectUrl: "tecconnection://callback",
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

  static Future<void> loadFavoriteRadios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? radiosJson = prefs.getString('favorite_radios_local');

      List<RadioStation> localRadios = [];
      if (radiosJson != null) {
        final List<dynamic> decoded = jsonDecode(radiosJson);
        localRadios = decoded
            .map((item) => RadioStation.fromJson(item))
            .toList();
      }

      // ✨ NUBE: Intentar recuperar los favoritos reales desde Supabase al iniciar
      try {
        final deSupabase = Supabase.instance.client;
        final usuarioActual = deSupabase.auth.currentUser;

        if (usuarioActual != null) {
          final response = await deSupabase
              .from('profiles')
              .select('favorite_radios')
              .eq('id', usuarioActual.id)
              .maybeSingle(); // maybeSingle previene errores si el usuario aún no tiene registro

          if (response != null && response['favorite_radios'] != null) {
            final List<dynamic> nube = response['favorite_radios'];
            localRadios = nube
                .map((item) => RadioStation.fromJson(item))
                .toList();

            // Actualizar la memoria local para que coincida con la nube
            await prefs.setString(
              'favorite_radios_local',
              jsonEncode(localRadios.map((r) => r.toJson()).toList()),
            );
          }
        }
      } catch (e) {
        debugPrint(
          "⚠️ Usa favoritos locales (Error al conectar con la nube): $e",
        );
      }

      favoriteRadios.value = localRadios;
      debugPrint(
        "📻 Radios favoritas cargadas: ${favoriteRadios.value.length}",
      );
    } catch (e) {
      debugPrint("❌ Error cargando radios favoritas locales: $e");
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
    updateThemeColor(const Color(0xFF2563EB)); // ✨ Azul si no hay portada local
    try {
      Uint8List? artwork = await audioQuery.queryArtwork(
        song.id,
        ArtworkType.AUDIO,
      );
      if (artwork != null) {
        final palette = await PaletteGenerator.fromImageProvider(
          MemoryImage(artwork),
        );
        updateThemeColor(
          palette.dominantColor?.color ??
              palette.vibrantColor?.color ??
              const Color(0xFF2563EB),
        );
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
        updateThemeColor(
          palette.dominantColor?.color ??
              palette.vibrantColor?.color ??
              const Color(0xFF2563EB),
        );
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
                    updateThemeColor(
                      palette.dominantColor?.color ??
                          palette.vibrantColor?.color ??
                          const Color(0xFF2563EB),
                    ); // ✨ Azul si falla Spotify
                  } catch (e) {
                    debugPrint(
                      "⚠️ Error generando paleta desde imagen de Spotify: $e",
                    );
                  }
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
    int milliseconds = 500, // ✨ Tiempo ajustado para mayor suavidad acústica
  }) async {
    // ✨ Respetamos el ajuste: Si desactivó animaciones de alta fidelidad, hacemos corte directo.
    if (!AppState.highFidelityAnimations.value) {
      await player.setVolume(isFadingOut ? 0.0 : 1.0);
      return;
    }

    const steps =
        30; // ✨ Alta tasa de refresco (aprox 60 FPS) para que sea imperceptible
    final stepDuration = milliseconds ~/ steps;

    if (isFadingOut) {
      for (int i = steps; i >= 0; i--) {
        // ✨ Curva Premium "Equal-Power" (Coseno) - Evita la caída brusca del volumen
        double progress = i / steps;
        double volume = cos((1.0 - progress) * (pi / 2));
        try {
          await player.setVolume(volume.clamp(0.0, 1.0));
        } catch (_) {
          break; // Detener si el reproductor dejó de estar disponible
        }
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
    } else {
      for (int i = 0; i <= steps; i++) {
        // ✨ Curva Premium "Equal-Power" (Seno) - Entrada inmersiva
        double progress = i / steps;
        double volume = sin(progress * (pi / 2));
        try {
          await player.setVolume(volume.clamp(0.0, 1.0));
        } catch (_) {
          break;
        }
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
        } catch (e) {
          debugPrint(
            "⚠️ No se pudo pausar Spotify previo a reproducir local: $e",
          );
        }
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
        } catch (e) {
          debugPrint(
            "⚠️ No se pudo pausar Spotify previo a reproducir radio: $e",
          );
        }
      }

      currentTitle.value = station.name;
      currentArtist.value = "EN VIVO • ${station.country.toUpperCase()}";
      currentArtwork.value = station.favicon;

      if (station.favicon.isNotEmpty) {
        try {
          final palette = await PaletteGenerator.fromImageProvider(
            NetworkImage(station.favicon),
          );
          updateThemeColor(
            palette.dominantColor?.color ??
                palette.vibrantColor?.color ??
                const Color(0xFF2563EB),
          );
        } catch (e) {
          debugPrint("⚠️ Error generando paleta para la Radio: $e");
          updateThemeColor(const Color(0xFF2563EB));
        }
      } else {
        updateThemeColor(const Color(0xFF2563EB));
      }

      final audioSource = AudioSource.uri(
        Uri.parse(station.url),
        tag: MediaItem(
          id: station.id,
          album: "Radio Global",
          title: station.name,
          artist: "En Vivo • ${station.country}",
          artUri: station.favicon.isNotEmpty
              ? Uri.parse(station.favicon)
              : null, // ✨ Esto invoca al reproductor multimedia nativo
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

    // ✨ GUARDAMOS LOCALMENTE PRIMERO (Para que funcione sin internet / sin login)
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = jsonEncode(
        actuales.map((r) => r.toJson()).toList(),
      );
      await prefs.setString('favorite_radios_local', encodedData);
    } catch (e) {
      debugPrint("❌ Error guardando radio local: $e");
    }

    // Sube LA LISTA COMPLETA a Supabase usando el cliente oficial instanciado
    List<Object?> jsonList = actuales.map((r) => r.toJson()).toList();
    try {
      // 🧠 Usamos Supabase.instance.client que garantiza conectarse al cliente vivo de Supabase en tu Moto G41
      final deSupabase = Supabase.instance.client;
      final usuarioActual = deSupabase.auth.currentUser;

      if (usuarioActual != null) {
        await deSupabase.from('profiles').upsert(
          {'id': usuarioActual.id, 'favorite_radios': jsonList},
        ); // ✨ Upsert garantiza que se guarde forzosamente, insertando el perfil si no existía
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
      // ✨ FIX CRÍTICO: Rutas seguras para Android 11+ e iOS
      Directory? baseDir;
      if (Platform.isAndroid) {
        final dirs = await getExternalStorageDirectories(
          type: StorageDirectory.music,
        );
        baseDir = dirs?.first;
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
      if (baseDir == null) return;

      final directory = Directory('${baseDir.path}/TecConnection');
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

      // ✨ NUEVO: Límite de seguridad de 60 minutos para no llenar la memoria del teléfono.
      _recordingTimer?.cancel();
      _recordingTimer = Timer(const Duration(minutes: 60), () {
        debugPrint(
          "⏱️ Límite de seguridad de 60 minutos alcanzado. Guardando grabación.",
        );
        stopRecording(null);
      });
    } catch (e) {
      debugPrint("Error al grabar stream: $e");
    }
  }

  static Future<void> stopRecording(BuildContext? context) async {
    if (!isRecording.value) return;
    try {
      isRecording.value = false;
      HapticFeedback.heavyImpact();

      // ✨ NUEVO: Cancelamos el temporizador si el usuario detuvo la grabación manualmente
      _recordingTimer?.cancel();
      _recordingTimer = null;

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
