import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/image_uri.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/network_radar.dart';
import '../services/app_state.dart';
import '../artwork_engine.dart';

// --- WIDGET UTILITARIO: MICROANIMACIÓN ---
class AnimatedPress extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const AnimatedPress({required this.child, required this.onTap, super.key});

  @override
  State<AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<AnimatedPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
    HapticFeedback.selectionClick();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: 1 - _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// --- WIDGET UTILITARIO: PORTADA HÍBRIDA CUADRADA INTELIGENTE ---
class HybridArtworkWidget extends StatelessWidget {
  final dynamic artworkData;
  final String title;
  final String artist;
  final bool isFullSize;

  const HybridArtworkWidget({
    required this.artworkData,
    required this.title,
    required this.artist,
    this.isFullSize = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: _buildImageContext(),
      ),
    );
  }

  Widget _buildImageContext() {
    // 1. Si es MP3 Local (ID numérico)
    if (artworkData is int) {
      return QueryArtworkWidget(
        id: artworkData,
        type: ArtworkType.AUDIO,
        artworkWidth: 800,
        artworkHeight: 800,
        artworkFit: BoxFit.cover,
        nullArtworkWidget: FutureBuilder<String?>(
          future: NetworkRadar.isOnline.value
              ? ArtworkEngine.buscarPortada(title, artist)
              : Future.value(null),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.blueGrey.shade900,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: DinobotTheme.primaryBlue,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              return AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: CachedNetworkImage(
                  imageUrl: snapshot.data!,
                  fit: BoxFit.cover,
                  memCacheWidth: isFullSize ? 800 : 150, // ✨ Control de RAM
                  memCacheHeight: isFullSize ? 800 : 150,
                  placeholder: (c, u) => const ShimmerPlaceholder(),
                  errorWidget: (c, u, e) => Container(
                    color: const Color(
                      0xFF141416,
                    ), // ✨ Fondo oscuro minimalista
                    child: Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        color: Colors.grey.withValues(alpha: 0.5),
                        size: isFullSize ? 80.0 : 24.0,
                      ),
                    ),
                  ),
                ),
              );
            }
            return Container(
              color: Colors.blueGrey.shade900,
              child: Icon(
                Icons.music_note,
                color: Colors.white24,
                size: isFullSize ? 100.0 : 30.0,
              ),
            );
          },
        ),
      );
    }
    // 2. Si es Spotify (ImageUri)
    else if (artworkData is ImageUri) {
      return FutureBuilder<Uint8List?>(
        future: SpotifySdk.getImage(
          imageUri: artworkData,
          dimension: ImageDimension.large,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Image.memory(snapshot.data!, fit: BoxFit.cover),
            );
          }
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: DinobotTheme.primaryBlue),
            ),
          );
        },
      );
    }
    // 3. ✨ NUEVO: Si es Radio FM (URL de texto)
    else if (artworkData is String && artworkData.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: artworkData,
        fit: BoxFit.cover,
        memCacheWidth: isFullSize ? 800 : 150, // ✨ Control de RAM
        memCacheHeight: isFullSize ? 800 : 150,
        placeholder: (context, url) => const ShimmerPlaceholder(),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xFF141416),
          child: Center(
            child: Icon(
              Icons.music_note_rounded,
              color: Colors.grey.withValues(alpha: 0.5),
              size: isFullSize ? 80.0 : 24.0,
            ),
          ),
        ),
      );
    }
    // 4. Fallback (Si no hay nada)
    return Container(
      color: Colors.blueGrey.shade900,
      child: Icon(
        Icons.album,
        color: Colors.white24,
        size: isFullSize ? 100.0 : 30.0,
      ),
    );
  }
}

// ✨ WIDGET UTILITARIO: SHIMMER PLACEHOLDER PARA IMÁGENES
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({super.key});

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white24 : Colors.black12;
    final highlightColor = isDark ? Colors.white70 : Colors.black26;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + (_controller.value * 3), -0.3),
              end: Alignment(-0.5 + (_controller.value * 3), 0.3),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Container(
        color: Colors.white,
      ), // El lienzo base sobre el que pinta el Shader
    );
  }
}

// --- MOTOR DE VINILO INFINITO ---
class VinylSpinner extends StatefulWidget {
  final Widget child;
  final bool isPlaying;
  const VinylSpinner({super.key, required this.child, required this.isPlaying});

  @override
  State<VinylSpinner> createState() => _VinylSpinnerState();
}

class _VinylSpinnerState extends State<VinylSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(VinylSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}

// ✨ MOTOR DE LÁMPARA DE LAVA REAL (ANIMACIÓN PROCEDURAL) ✨
class LavaLampBackground extends StatefulWidget {
  const LavaLampBackground({super.key});
  @override
  State<LavaLampBackground> createState() => _LavaLampBackgroundState();
}

class _LavaLampBackgroundState extends State<LavaLampBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFF0F0C29),
                  const Color(0xFF302B63),
                  _ctrl.value,
                )!,
                Color.lerp(
                  const Color(0xFF302B63),
                  const Color(0xFF24243E),
                  _ctrl.value,
                )!,
                Color.lerp(
                  const Color(0xFF24243E),
                  const Color(0xFF0F0C29),
                  _ctrl.value,
                )!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ✨ WIDGET UTILITARIO: SKELETON LOADER CON SHIMMER EFFECT ✨
class ShimmerSkeletonItem extends StatefulWidget {
  const ShimmerSkeletonItem({super.key});

  @override
  State<ShimmerSkeletonItem> createState() => _ShimmerSkeletonItemState();
}

class _ShimmerSkeletonItemState extends State<ShimmerSkeletonItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white24 : Colors.black12;
    final highlightColor = isDark ? Colors.white70 : Colors.black26;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // ✨ El gradiente barre de izquierda a derecha dinámicamente
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + (_controller.value * 3), -0.3),
              end: Alignment(-0.5 + (_controller.value * 3), 0.3),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: Row(
          children: [
            // Cuadrado de la Portada
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            const SizedBox(width: 15),
            // Líneas de Texto (Título y Artista)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Container(width: 120, height: 10, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Ícono lateral
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
