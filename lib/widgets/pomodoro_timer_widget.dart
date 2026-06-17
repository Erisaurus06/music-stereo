import 'dart:math';
import 'package:flutter/material.dart';
import '../pomodoro_engine.dart';
import '../services/player_manager.dart';

class PomodoroTimerWidget extends StatefulWidget {
  const PomodoroTimerWidget({super.key});

  @override
  State<PomodoroTimerWidget> createState() => _PomodoroTimerWidgetState();
}

class _PomodoroTimerWidgetState extends State<PomodoroTimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    // ✨ Controlador para el efecto de respiración (Breathing effect)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 2,
      ), // Ciclo completo de 4s (2 ida, 2 vuelta)
    );

    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine, // Curva orgánica y natural
      ),
    );

    PomodoroEngine.currentState.addListener(_onStateChanged);
    _onStateChanged();
  }

  void _onStateChanged() {
    // El temporizador "respira" solo cuando está corriendo
    if (PomodoroEngine.currentState.value != PomodoroState.idle) {
      _breathingController.repeat(reverse: true);
    } else {
      _breathingController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    PomodoroEngine.currentState.removeListener(_onStateChanged);
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PomodoroState>(
      valueListenable: PomodoroEngine.currentState,
      builder: (context, state, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: PlayerManager.currentThemeColor,
          builder: (context, themeColor, _) {
            // ✨ Lógica de Color Dinámico: Usa el Camaleón en enfoque, o un verde relajante en descanso
            final targetColor =
                (state == PomodoroState.focus || state == PomodoroState.idle)
                ? themeColor
                : const Color(0xFF4ADE80); // Verde Zen (Tailwind)

            return ValueListenableBuilder<int>(
              valueListenable: PomodoroEngine.secondsRemaining,
              builder: (context, seconds, _) {
                final int totalSeconds =
                    (state == PomodoroState.focus ||
                        state == PomodoroState.idle)
                    ? PomodoroEngine.focusDurationInSeconds
                    : PomodoroEngine.breakDurationInSeconds;

                final double progress = totalSeconds > 0
                    ? seconds / totalSeconds
                    : 0.0;

                // ✨ Animación suave del cambio de color entre fases
                return TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: targetColor),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  builder: (context, color, child) {
                    return AnimatedBuilder(
                      animation: _breathingAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _breathingAnimation.value,
                          child: SizedBox(
                            width: 280, // Tamaño grande e inmersivo
                            height: 280,
                            child: CustomPaint(
                              painter: _TimerPainter(
                                progress: progress,
                                color: color ?? themeColor,
                                backgroundColor: (color ?? themeColor)
                                    .withValues(alpha: 0.12),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}",
                                      style: TextStyle(
                                        fontSize: 56,
                                        fontWeight: FontWeight.w900,
                                        color: color,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      state == PomodoroState.focus
                                          ? "CONCENTRACIÓN"
                                          : (state == PomodoroState.idle
                                                ? "LISTO PARA INICIAR"
                                                : "DESCANSO"),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: (color ?? themeColor).withValues(
                                          alpha: 0.7,
                                        ),
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ✨ RENDERIZADO PERSONALIZADO DE ALTO RENDIMIENTO
class _TimerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _TimerPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 18.0;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    // Pinta el anillo de fondo sutil
    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    // Pinta el arco de progreso con bordes redondeados
    final Paint fgPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap
          .round // ✨ Bordes premium
      ..style = PaintingStyle.stroke;

    final double sweepAngle = 2 * pi * progress;

    // Comienza en la posición de las 12 en punto (-pi/2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
