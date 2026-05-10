import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../services/player_manager.dart';
import '../widgets/design_components.dart';

class CollectionView extends StatefulWidget {
  final AppCollection collection;
  const CollectionView({super.key, required this.collection});

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  // 🔍 Filtra solo las canciones que pertenecen a esta colección
  List<SongModel> get _collectionSongs {
    return PlayerManager.allLocalSongs.value
        .where((song) => widget.collection.songIds.contains(song.id.toString()))
        .toList();
  }

  // ✨ EL BUSCADOR E INYECTOR DE TRACKS
  void _showAddSongsModal(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allSongs = PlayerManager.allLocalSongs.value;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      "Añadir ADN Musical",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: allSongs.length,
                      itemBuilder: (context, index) {
                        final song = allSongs[index];
                        final isAdded = widget.collection.songIds.contains(
                          song.id.toString(),
                        );

                        return ListTile(
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
                          trailing: AnimatedPress(
                            onTap: () {
                              setModalState(() {
                                setState(() {
                                  if (isAdded) {
                                    widget.collection.songIds.remove(
                                      song.id.toString(),
                                    );
                                  } else {
                                    widget.collection.songIds.add(
                                      song.id.toString(),
                                    );
                                  }
                                  // ¡Se guarda en el cerebro automáticamente!
                                  AppState.updateCollection(widget.collection);
                                });
                              });
                            },
                            child: Icon(
                              isAdded
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: isAdded ? theme.primaryColor : Colors.grey,
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songs = _collectionSongs;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSongsModal(theme),
        backgroundColor: theme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          "Añadir",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 🖼️ CABECERA INMERSIVA TIPO SPOTIFY
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
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
                  if (widget.collection.imagePath != null)
                    Image.file(
                      File(widget.collection.imagePath!),
                      fit: BoxFit.cover,
                    ),
                  if (widget.collection.imagePath != null)
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(color: Colors.black.withOpacity(0.4)),
                    ),
                  Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      margin: const EdgeInsets.only(top: 40),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: widget.collection.imagePath != null
                            ? DecorationImage(
                                image: FileImage(
                                  File(widget.collection.imagePath!),
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: theme.primaryColor.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: widget.collection.imagePath == null
                          ? Icon(
                              Icons.music_note_rounded,
                              size: 60,
                              color: theme.primaryColor,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.collection.name,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: theme.textTheme.bodyLarge?.color,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${widget.collection.type.name.toUpperCase()} • ${songs.length} pistas",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 🎶 LISTA DE CANCIONES GUARDADAS
          if (songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.library_music_rounded,
                      size: 60,
                      color: theme.dividerColor,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Esta colección está vacía.",
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final song = songs[index];
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
                      Icons.remove_circle_outline_rounded,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        widget.collection.songIds.remove(song.id.toString());
                        AppState.updateCollection(widget.collection);
                      });
                    },
                  ),
                  onTap: () {
                    PlayerManager.playSong(song);
                  },
                );
              }, childCount: songs.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ❤️ MEMORIA DE FAVORITOS
  static final ValueNotifier<List<String>> favoriteSongs =
      ValueNotifier<List<String>>([]);
  static final ValueNotifier<List<String>> favoriteRadios =
      ValueNotifier<List<String>>([]);

  static void toggleFavoriteSong(String songId) {
    final current = List<String>.from(favoriteSongs.value);
    if (current.contains(songId)) {
      current.remove(songId);
    } else {
      current.add(songId);
    }
    favoriteSongs.value = current;
  }

  static void toggleFavoriteRadio(String radioName) {
    final current = List<String>.from(favoriteRadios.value);
    if (current.contains(radioName)) {
      current.remove(radioName);
    } else {
      current.add(radioName);
    }
    favoriteRadios.value = current;
  }
}
