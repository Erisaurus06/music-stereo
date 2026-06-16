import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import '../services/player_manager.dart';
import '../lyrics_engine.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({super.key});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  String? _lyricsText;
  bool _isLoading = true;
  LyricsReaderModel? _lyricModel;
  bool _isSynced = false; // Define si usamos el modo Karaoke o el modo estático

  @override
  void initState() {
    super.initState();
    _loadLyrics();
    // ✨ Escuchamos el cambio de título (funciona para Local y Spotify)
    PlayerManager.currentTitle.addListener(_onSongChanged);
  }

  @override
  void dispose() {
    PlayerManager.currentTitle.removeListener(_onSongChanged);
    super.dispose();
  }

  void _onSongChanged() {
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lyricsText = null;
      _lyricModel = null;
      _isSynced = false;
    });

    final title = PlayerManager.currentTitle.value;
    final artist = PlayerManager.currentArtist.value;

    final fetchedLyrics = await LyricsEngine.fetchLyrics(title, artist);

    // Expresión regular para detectar si el texto trae tiempos LRC [00:12.33]
    _isSynced = fetchedLyrics.contains(
      RegExp(r'\[\d{2}:\d{2}\.\d{1,3}\]'),
    ); // ✨ Soporta cualquier formato de fracción LRC

    if (_isSynced) {
      // Cargamos el motor de karaoke de flutter_lyric
      try {
        _lyricModel = LyricsModelBuilder.create()
            .bindLyricToMain(fetchedLyrics)
            .getModel();
      } catch (e) {
        debugPrint("Error construyendo LRC: $e");
        _isSynced = false; // Cae al modo estático si falla
      }
    }

    if (mounted) {
      setState(() {
        _lyricsText = fetchedLyrics;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Ideal para usar sobre el reproductor
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: PlayerManager.currentThemeColor.value,
                ),
              )
            : _isSynced && _lyricModel != null
            ? _buildSyncedLyrics()
            : _buildPlainLyrics(theme),
      ),
    );
  }

  // ✨ MODO KARAOKE DINÁMICO
  Widget _buildSyncedLyrics() {
    return ValueListenableBuilder<Duration>(
      valueListenable: PlayerManager.position,
      builder: (context, position, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: PlayerManager.isPlaying,
          builder: (context, isPlaying, _) {
            return LyricsReader(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 40.0,
              ),
              model: _lyricModel,
              position: position.inMilliseconds,
              lyricUi: _AppLyricUI(
                // Usamos el Camaleón Visual para resaltar la letra actual
                activeColor: PlayerManager.currentThemeColor.value,
                inactiveColor: Colors.grey.withOpacity(0.4),
              ),
              playing: isPlaying,
              emptyBuilder: () => const Center(child: Text("Letra vacía")),
              // Permite adelantar la canción si el usuario toca la letra
              selectLineBuilder: (progress, confirm) {
                return Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        PlayerManager.seek(Duration(milliseconds: progress));
                        confirm.call(); // Cierra el menú de selección
                      },
                      icon: Icon(
                        Icons.play_circle_fill,
                        color: PlayerManager.currentThemeColor.value,
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: PlayerManager.currentThemeColor.value,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ✨ MODO ESTÁTICO (Para cuando LRCLIB falla y usamos Genius/ovh)
  Widget _buildPlainLyrics(ThemeData theme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(30.0),
      child: Center(
        child: Text(
          _lyricsText ?? "No se encontraron letras.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            height: 1.8,
            fontWeight: FontWeight.w800,
            color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ✨ CONFIGURACIÓN VISUAL DEL PAQUETE FLUTTER_LYRIC
class _AppLyricUI extends UINetease {
  final Color activeColor;
  final Color inactiveColor;

  _AppLyricUI({required this.activeColor, required this.inactiveColor});

  @override
  TextStyle getPlayingExtTextStyle() => TextStyle(
    color: activeColor,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );

  @override
  TextStyle getOtherExtTextStyle() => TextStyle(
    color: inactiveColor,
    fontSize: 20,
    fontWeight: FontWeight.w500,
  );

  @override
  TextStyle getPlayingMainTextStyle() => TextStyle(
    color: activeColor,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0, // ✨ Estilo Apple Music (letras más juntas)
  );

  @override
  TextStyle getOtherMainTextStyle() => TextStyle(
    color: inactiveColor.withOpacity(
      0.6,
    ), // Más suave para que resalte la actual
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );

  @override
  double getInlineSpace() => 24.0;

  @override
  double getLineSpace() => 35.0; // Espaciado cómodo entre líneas
}
