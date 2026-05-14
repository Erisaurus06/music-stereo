import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_stereo/screens/pomodoro_view.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/player_manager.dart';
// Asegúrate de importar aquí tu YouTubeVideoModal
// import 'player_ui.dart';

class VisualVaultView extends StatefulWidget {
  const VisualVaultView({super.key});

  @override
  State<VisualVaultView> createState() => _VisualVaultViewState();
}

class _VisualVaultViewState extends State<VisualVaultView> {
  // ✨ USAMOS EL MOTOR EXPLODE (No necesita API Key)
  final YoutubeExplode _yt = YoutubeExplode();
  List<Video> _videoResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarSugerencias();
  }

  @override
  void dispose() {
    _yt.close(); // Limpiamos la memoria al salir
    super.dispose();
  }

  Future<void> _cargarSugerencias() async {
    setState(() => _isLoading = true);
    try {
      final results = await _yt.search.search(
        "Lofi hip hop radio - beats to relax/study to",
      );
      _videoResults = results.take(16).toList(); // Tomamos los primeros 16
    } catch (e) {
      debugPrint("Error cargando sugerencias: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _buscarVideos(String query) async {
    if (query.trim().isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final results = await _yt.search.search(query);
      _videoResults = results.take(16).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al buscar. Verifica tu conexión a internet."),
        ),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<Color>(
      valueListenable: PlayerManager.currentThemeColor,
      builder: (context, themeColor, _) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CABECERA Y BUSCADOR ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.video_library_rounded,
                        color: themeColor,
                        size: 32,
                      ),
                      const SizedBox(width: 15),
                      Text(
                        "Bóveda Visual",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: theme.textTheme.bodyLarge?.color,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),

                // BARRA DE BÚSQUEDA
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 10,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, color: themeColor),
                        border: InputBorder.none,
                        hintText: "Buscar documentales, lofi, tutoriales...",
                        hintStyle: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      onSubmitted: _buscarVideos,
                    ),
                  ),
                ),

                // ETIQUETAS RÁPIDAS
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _etiquetaBusqueda("Minecraft Lofi", themeColor),
                      _etiquetaBusqueda("Historia de México", themeColor),
                      _etiquetaBusqueda("Study with me", themeColor),
                      _etiquetaBusqueda("Flutter UI", themeColor),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // --- RESULTADOS (CUADRÍCULA PINTEREST STYLE) ---
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: themeColor),
                        )
                      : _videoResults.isEmpty
                      ? Center(
                          child: Text(
                            "No hay resultados",
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        )
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: _videoResults.length,
                          itemBuilder: (context, index) {
                            final video = _videoResults[index];
                            return _videoCard(video, themeColor);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- COMPONENTES VISUALES ---

  Widget _etiquetaBusqueda(String texto, Color themeColor) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _buscarVideos(texto);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeColor.withOpacity(0.3)),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _videoCard(Video video, Color themeColor) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // Abrimos el VLC Premium con el ID del video
        showDialog(
          context: context,
          builder: (_) => YouTubeVideoModal(videoId: video.id.value),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LA IMAGEN DE PORTADA
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Image.network(
                      video.thumbnails.highResUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => const Center(
                        child: Icon(Icons.error, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // TÍTULO Y CANAL
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.textTheme.bodyLarge?.color,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: themeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
