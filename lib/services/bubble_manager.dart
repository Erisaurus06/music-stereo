import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/design_components.dart';
import '../main.dart'; // Para acceder a la llave de navegación global
import 'player_manager.dart';

/// Gestor para la burbuja flotante del reproductor.
class BubbleManager {
  static OverlayEntry? _overlayEntry;
  static bool _isVisible = false;
  static Offset _position = const Offset(20, 100); // Posición inicial

  /// Inicializa la burbuja y pide los permisos necesarios.
  static Future<void> init() async {
    // ✨ Solicitar permisos de superposición (SYSTEM_ALERT_WINDOW) para Android
    if (Platform.isAndroid) {
      final status = await Permission.systemAlertWindow.status;
      if (!status.isGranted) {
        await Permission.systemAlertWindow.request();
      }
    }
  }

  /// Muestra la burbuja en la pantalla.
  static void show() {
    if (_isVisible) return;

    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: _position.dx,
        top: _position.dy,
        child: GestureDetector(
          onPanUpdate: (details) {
            _position += details.delta;
            _overlayEntry
                ?.markNeedsBuild(); // Actualiza la posición al arrastrar
          },
          child: const BubbleWidget(),
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);
    _isVisible = true;
  }

  /// Oculta la burbuja de la pantalla.
  static void hide() {
    if (!_isVisible) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isVisible = false;
  }
}

class BubbleWidget extends StatefulWidget {
  const BubbleWidget({super.key});

  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // ✨ Detecta toques fuera del widget para cerrar el modo expandido
    return TapRegion(
      onTapOutside: (event) {
        if (_isExpanded) {
          HapticFeedback.lightImpact();
          setState(() => _isExpanded = false);
        }
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _isExpanded = !_isExpanded);
        },
        child: Material(
          color: Colors.transparent,
          elevation: 10,
          borderRadius: BorderRadius.circular(_isExpanded ? 24 : 50),
          child: _isExpanded
              ? const PlayerBubbleExpanded()
              : const PlayerBubbleIcon(),
        ),
      ),
    );
  }
}

// --- WIDGETS DE LA BURBUJA ---

/// 1. El ícono circular cuando la burbuja está contraída.
class PlayerBubbleIcon extends StatefulWidget {
  const PlayerBubbleIcon({super.key});

  @override
  State<PlayerBubbleIcon> createState() => _PlayerBubbleIconState();
}

class _PlayerBubbleIconState extends State<PlayerBubbleIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // ✨ Rotación lenta y elegante
    );
    PlayerManager.isPlaying.addListener(_checkRotation);
    _checkRotation();
  }

  void _checkRotation() {
    if (PlayerManager.isPlaying.value) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    PlayerManager.isPlaying.removeListener(_checkRotation);
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: PlayerManager.currentArtwork,
      builder: (context, art, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: PlayerManager.isPlaying,
          builder: (context, isPlaying, _) {
            return Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: PlayerManager.currentThemeColor.value.withValues(
                    alpha: 0.5,
                  ),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipOval(
                child: AnimatedScale(
                  scale: isPlaying ? 1.0 : 0.9,
                  duration: const Duration(milliseconds: 400),
                  child: RotationTransition(
                    turns: _rotationController,
                    child: HybridArtworkWidget(
                      artworkData: art,
                      title: PlayerManager.currentTitle.value,
                      artist: PlayerManager.currentArtist.value,
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

/// 2. La vista expandida con controles cuando se toca la burbuja.
class PlayerBubbleExpanded extends StatelessWidget {
  const PlayerBubbleExpanded({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Fila de Título y Artista
            Expanded(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: ValueListenableBuilder<dynamic>(
                        valueListenable: PlayerManager.currentArtwork,
                        builder: (context, art, _) => HybridArtworkWidget(
                          artworkData: art,
                          title: PlayerManager.currentTitle.value,
                          artist: PlayerManager.currentArtist.value,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: PlayerManager.currentTitle,
                          builder: (_, title, __) => Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: PlayerManager.currentArtist,
                          builder: (_, artist, __) => Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Fila de Controles
            ValueListenableBuilder<bool>(
              valueListenable: PlayerManager.isPlaying,
              builder: (context, isPlaying, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                      ),
                      onPressed: PlayerManager.playPrevious,
                    ),
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: PlayerManager.togglePlay,
                    ),
                    const IconButton(
                      icon: Icon(Icons.skip_next_rounded, color: Colors.white),
                      onPressed: PlayerManager.playNext,
                    ),
                    const IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: BubbleManager.hide,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
