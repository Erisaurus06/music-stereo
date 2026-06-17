import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_stereo/widgets/design_components.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui';
import 'collection_view.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import '../services/player_manager.dart';
import '../services/app_state.dart';
import '../models/app_models.dart';

// --- 4. BIBLIOTECA CON BUSCADOR Y SUPER FAVORITOS EN COLECCIONES ---
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});
  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> searchQuery = ValueNotifier("");

  // ✨ CONTROLES EXCLUSIVOS PARA TRACKS MP3
  bool _isMp3GridView = false;
  bool _mp3SortAscending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    searchQuery.dispose();
    super.dispose();
  }

  Future<void> _showCreatePlaylistDialog(
    ThemeData theme,
    CollectionType type,
  ) async {
    String playlistName = "";
    String? imagePath;
    final picker = ImagePicker();

    String typeTitle = type == CollectionType.playlist
        ? "Nueva Playlist"
        : (type == CollectionType.folder
              ? "Nueva Carpeta"
              : "Nuevo Mix Híbrido");

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(40),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withValues(alpha: 0.85),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        typeTitle,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 25),
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null) {
                            final directory =
                                await getApplicationDocumentsDirectory();
                            final String newPath =
                                '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                            final File newImage = await File(
                              image.path,
                            ).copy(newPath);
                            setModalState(() => imagePath = newImage.path);
                          }
                        },
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            image: imagePath != null
                                ? DecorationImage(
                                    image: FileImage(File(imagePath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: Border.all(
                              color: theme.primaryColor.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            boxShadow: imagePath != null
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 10),
                                    ),
                                  ]
                                : [],
                          ),
                          child: imagePath == null
                              ? Icon(
                                  Icons.add_a_photo_rounded,
                                  size: 40,
                                  color: theme.primaryColor,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        imagePath == null
                            ? "Toca para añadir portada"
                            : "Portada lista",
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        onChanged: (v) => playlistName = v,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: "¿Cómo se llamará esta joya?",
                          hintStyle: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontWeight: FontWeight.normal,
                          ),
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor.withValues(
                            alpha: 0.5,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            if (playlistName.trim().isEmpty) return;
                            HapticFeedback.heavyImpact();
                            final newCollection = AppCollection(
                              id: DateTime.now().millisecondsSinceEpoch
                                  .toString(),
                              name: playlistName.trim(),
                              imagePath: imagePath,
                              type: type,
                            );
                            AppState.addCollection(newCollection);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "✅ '$playlistName' guardada en colecciones.",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: const Text(
                            "CREAR",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSpotifyLinkDialog(ThemeData theme) async {
    String playlistName = "";
    String spotifyUrl = "";

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        color: Color(0xFF1DB954),
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Enlace Externo",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    onChanged: (v) => playlistName = v,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: "Ej. This is Billie Eilish",
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor.withValues(
                        alpha: 0.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (v) => spotifyUrl = v,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: "Pega el link de Spotify aquí...",
                      prefixIcon: const Icon(
                        Icons.share_rounded,
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor.withValues(
                        alpha: 0.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        if (playlistName.trim().isEmpty ||
                            spotifyUrl.trim().isEmpty) {
                          return;
                        }
                        HapticFeedback.heavyImpact();
                        String finalUri = spotifyUrl;
                        if (spotifyUrl.contains("open.spotify.com")) {
                          final parts = spotifyUrl.split("/");
                          final idPart = parts.last.split("?").first;
                          if (spotifyUrl.contains("playlist")) {
                            finalUri = "spotify:playlist:$idPart";
                          }
                          if (spotifyUrl.contains("album")) {
                            finalUri = "spotify:album:$idPart";
                          }
                          if (spotifyUrl.contains("artist")) {
                            finalUri = "spotify:artist:$idPart";
                          }
                        }
                        final newCollection = AppCollection(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: playlistName.trim(),
                          type: CollectionType.mix,
                          songIds: [finalUri],
                        );
                        AppState.addCollection(newCollection);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "VINCULAR SPOTIFY",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              "Mi Música",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 34,
                color: theme.textTheme.bodyLarge?.color,
                letterSpacing: -1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => searchQuery.value = val,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  hintText: "Buscar tracks o colecciones...",
                  hintStyle: TextStyle(
                    color: theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.primaryColor,
                  ),
                  suffixIcon: ValueListenableBuilder<String>(
                    valueListenable: searchQuery,
                    builder: (context, query, _) {
                      return query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                searchQuery.value = "";
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            tabs: const [
              Tab(text: "TRACKS MP3"),
              Tab(text: "COLECCIONES"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [_buildMp3List(theme), _buildCollectionsTab(theme)],
            ),
          ),
        ],
      ),
    );
  }

  // 🎵 SECCIÓN MP3 (AHORA CON CONTROLES A-Z Y VISTA GRID)
  Widget _buildMp3List(ThemeData theme) {
    return ValueListenableBuilder<String>(
      valueListenable: searchQuery,
      builder: (context, query, _) {
        return ValueListenableBuilder<List<SongModel>>(
          valueListenable: PlayerManager.allLocalSongs,
          builder: (context, allSongs, _) {
            final songs = allSongs
                .where(
                  (s) =>
                      s.title.toLowerCase().contains(query.toLowerCase()) ||
                      (s.artist ?? "").toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();

            // ✨ ORDENAR LA LISTA (A-Z o Z-A)
            songs.sort((a, b) {
              int cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
              return _mp3SortAscending ? cmp : -cmp;
            });

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // CONTROLES DE LA CARPETA
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.cardColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _mp3SortAscending = !_mp3SortAscending;
                            });
                            HapticFeedback.lightImpact();
                          },
                          icon: Icon(
                            _mp3SortAscending
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          label: Text(
                            _mp3SortAscending ? "De A a Z" : "De Z a A",
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isMp3GridView
                                ? Icons.view_list_rounded
                                : Icons.grid_view_rounded,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMp3GridView = !_isMp3GridView;
                            });
                            HapticFeedback.selectionClick();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                if (songs.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        query.isEmpty
                            ? "Cargando ADN Musical..."
                            : "No se encontró '$query'",
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else if (_isMp3GridView)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            childAspectRatio: 0.8,
                          ),
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final song = songs[i];
                        return GestureDetector(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            PlayerManager.playSong(song);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: HybridArtworkWidget(
                                        artworkData: song.id,
                                        title: song.title,
                                        artist: song.artist ?? "",
                                        isFullSize: true,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color:
                                              theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              song.artist ?? "Desconocido",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          ValueListenableBuilder<List<String>>(
                                            valueListenable:
                                                AppState.favoriteSongs,
                                            builder: (context, favorites, _) {
                                              final isFav = favorites.contains(
                                                song.id.toString(),
                                              );
                                              return GestureDetector(
                                                onTap: () {
                                                  HapticFeedback.selectionClick();
                                                  AppState.toggleFavoriteSong(
                                                    song.id.toString(),
                                                  );
                                                },
                                                child: Icon(
                                                  isFav
                                                      ? Icons.favorite_rounded
                                                      : Icons
                                                            .favorite_border_rounded,
                                                  color: isFav
                                                      ? Colors.redAccent
                                                      : Colors.grey.withValues(
                                                          alpha: 0.5,
                                                        ),
                                                  size: 16,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: songs.length),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final song = songs[i];
                      return ValueListenableBuilder<SongModel?>(
                        valueListenable: PlayerManager.currentSong,
                        builder: (context, currentSong, _) {
                          final isPlayingThis =
                              currentSong?.id == song.id &&
                              PlayerManager.activeEngine.value !=
                                  AudioEngineType.spotify;
                          return InkWell(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              PlayerManager.playSong(song);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isPlayingThis
                                    ? theme.primaryColor.withValues(alpha: 0.1)
                                    : theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: HybridArtworkWidget(
                                      artworkData: song.id,
                                      title: song.title,
                                      artist: song.artist ?? "Desconocido",
                                    ),
                                  ),
                                ),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isPlayingThis
                                        ? theme.primaryColor
                                        : theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                subtitle: Text(
                                  song.artist ?? "Artista Desconocido",
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPlayingThis)
                                      Icon(
                                        Icons.bar_chart_rounded,
                                        color: theme.primaryColor,
                                      ),
                                    ValueListenableBuilder<List<String>>(
                                      valueListenable: AppState.favoriteSongs,
                                      builder: (context, favorites, _) {
                                        final isFav = favorites.contains(
                                          song.id.toString(),
                                        );
                                        return IconButton(
                                          icon: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            transitionBuilder:
                                                (child, animation) =>
                                                    ScaleTransition(
                                                      scale: animation,
                                                      child: child,
                                                    ),
                                            child: Icon(
                                              isFav
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                        .favorite_border_rounded,
                                              key: ValueKey<bool>(isFav),
                                              color: isFav
                                                  ? Colors.redAccent
                                                  : Colors.grey.withValues(
                                                      alpha: 0.5,
                                                    ),
                                              size: 24,
                                            ),
                                          ),
                                          onPressed: () {
                                            HapticFeedback.selectionClick();
                                            AppState.toggleFavoriteSong(
                                              song.id.toString(),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }, childCount: songs.length),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 180)),
              ],
            );
          },
        );
      },
    );
  }

  // 📂 COLECCIONES (AHORA CON "MIS IMPRESCINDIBLES" AQUÍ)
  Widget _buildCollectionsTab(ThemeData theme) {
    return ValueListenableBuilder<String>(
      valueListenable: searchQuery,
      builder: (context, query, _) {
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            if (query.isEmpty) ...[
              // ✨ EL BOTÓN DE FAVORITOS AHORA VIVE EN COLECCIONES
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SuperFavoritesFolderView(),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurpleAccent, Colors.redAccent],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    title: const Text(
                      "Mis Imprescindibles",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: ValueListenableBuilder<List<String>>(
                      valueListenable: AppState.favoriteSongs,
                      builder: (context, favs, _) => Text(
                        "${favs.length} tracks locales",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              _buildCreationButton(
                theme: theme,
                title: "Crear Playlist",
                subtitle: "Orden personalizado y portada propia.",
                icon: Icons.add_photo_alternate_rounded,
                color: Colors.purpleAccent,
                onTap: () =>
                    _showCreatePlaylistDialog(theme, CollectionType.playlist),
              ),
              const SizedBox(height: 15),
              _buildCreationButton(
                theme: theme,
                title: "Crear Carpeta",
                subtitle: "Agrupa por artista, álbum o letra.",
                icon: Icons.create_new_folder_rounded,
                color: Colors.orangeAccent,
                onTap: () =>
                    _showCreatePlaylistDialog(theme, CollectionType.folder),
              ),
              const SizedBox(height: 15),
              _buildCreationButton(
                theme: theme,
                title: "Crear Mix Híbrido",
                subtitle: "Combina Spotify Premium con tus MP3.",
                icon: Icons.all_inclusive_rounded,
                color: Colors.greenAccent,
                onTap: () =>
                    _showCreatePlaylistDialog(theme, CollectionType.mix),
              ),
              const SizedBox(height: 15),
              _buildCreationButton(
                theme: theme,
                title: "Vincular Enlace Externo",
                subtitle: "Accesos directos (This is The Weeknd, etc.)",
                icon: Icons.link_rounded,
                color: const Color(0xFF1DB954),
                onTap: () => _showSpotifyLinkDialog(theme),
              ),
              const SizedBox(height: 40),
              Text(
                "Mis Colecciones",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 20),
            ],

            ValueListenableBuilder<List<AppCollection>>(
              valueListenable: AppState.myCollections,
              builder: (context, allCollections, _) {
                final collections = allCollections
                    .where(
                      (c) => c.name.toLowerCase().contains(query.toLowerCase()),
                    )
                    .toList();

                if (collections.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Text(
                        query.isEmpty
                            ? "Aún no tienes colecciones creadas.\n¡Toca un botón arriba para empezar!"
                            : "No se encontró '$query'",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    Color badgeColor =
                        collection.type == CollectionType.playlist
                        ? Colors.purpleAccent
                        : (collection.type == CollectionType.folder
                              ? Colors.orangeAccent
                              : Colors.greenAccent);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        FocusScope.of(context).unfocus();
                        if (collection.songIds.isNotEmpty &&
                            collection.songIds.first.startsWith("spotify:")) {
                          PlayerManager.activeEngine.value =
                              AudioEngineType.spotify;
                          PlayerManager.isPlaying.value = true;
                          SpotifySdk.play(spotifyUri: collection.songIds.first);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "🎵 Sintonizando: ${collection.name}",
                              ),
                              backgroundColor: const Color(0xFF1DB954),
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CollectionView(collection: collection),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  image: collection.imagePath != null
                                      ? DecorationImage(
                                          image: FileImage(
                                            File(collection.imagePath!),
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: badgeColor.withValues(alpha: 0.1),
                                ),
                                child: collection.imagePath == null
                                    ? Icon(
                                        Icons.music_note_rounded,
                                        size: 40,
                                        color: badgeColor,
                                      )
                                    : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    collection.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    collection.type.name.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      color: badgeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 150),
          ],
        );
      },
    );
  }

  Widget _buildCreationButton({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.dividerColor),
          ],
        ),
      ),
    );
  }
}

// ✨ LA SÚPER CARPETA DE MP3 FAVORITOS (VISTA SIMPLE SIN CONTROLES)
class SuperFavoritesFolderView extends StatelessWidget {
  const SuperFavoritesFolderView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ValueListenableBuilder<List<String>>(
        valueListenable: AppState.favoriteSongs,
        builder: (context, favIds, _) {
          List<SongModel> favSongs = PlayerManager.allLocalSongs.value
              .where((song) => favIds.contains(song.id.toString()))
              .toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                stretch: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [Colors.deepPurpleAccent, Colors.redAccent],
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 70,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Imprescindibles",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              "${favSongs.length} Pistas Locales",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (favSongs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      "Aún no tienes favoritos locales.",
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final song = favSongs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
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
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        song.artist ?? "Desconocido",
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          AppState.toggleFavoriteSong(song.id.toString());
                          HapticFeedback.lightImpact();
                        },
                      ),
                      onTap: () => PlayerManager.playSong(song),
                    );
                  }, childCount: favSongs.length),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}
