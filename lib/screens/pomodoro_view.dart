import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// Importaciones de tu proyecto
import '../services/player_manager.dart';
import '../services/app_state.dart';

// ✨ AGREGA ESTAS DOS LÍNEAS AQUÍ:
import '../services/radio_engine.dart';
import '../models/app_models.dart';

// ==========================================
// --- EL CEREBRO DEL POMODORO INMORTAL ---
// ==========================================
enum PomodoroState { focus, shortBreak, longBreak, idle }

final pomodoroPhaseProvider = StateProvider<PomodoroState>(
  (ref) => PomodoroState.idle,
);
final pomodoroSecondsProvider = StateProvider<int>((ref) => 1500); // 25 min
final pomodoroSessionsProvider = StateProvider<int>((ref) => 0);
final pomodoroTaskProvider = StateProvider<String>((ref) => "");

// ✨ NUEVO: El estado del Modo Zen
final zenModeProvider = StateProvider<bool>((ref) => false);

final pomodoroControllerProvider = Provider<PomodoroController>((ref) {
  final controller = PomodoroController(ref);
  ref.onDispose(() => controller.dispose());
  return controller;
});

class PomodoroController with WidgetsBindingObserver {
  final Ref ref;
  Timer? _timer;
  int tiempoTotalFase = 1500;
  DateTime? _tiempoFondo;

  PomodoroController(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ref.read(pomodoroPhaseProvider) == PomodoroState.idle) return;

    if (state == AppLifecycleState.paused) {
      // ✨ MODO ZEN ESTRÍCTO: Si salen de la app en pleno enfoque...
      final isZen = ref.read(zenModeProvider);
      final isFocus = ref.read(pomodoroPhaseProvider) == PomodoroState.focus;

      if (isZen && isFocus) {
        // ¡Castigo por distraerse! Pierden la racha y se aborta la sesión.
        stopTimer();
        ref.read(pomodoroSessionsProvider.notifier).state = 0;
        AppState.updatePomodoroRacha(0);
        return;
      }

      _tiempoFondo = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _tiempoFondo != null) {
      final diferenciaSegundos = DateTime.now()
          .difference(_tiempoFondo!)
          .inSeconds;
      _tiempoFondo = null;
      int currentSec = ref.read(pomodoroSecondsProvider);
      currentSec -= diferenciaSegundos;
      if (currentSec <= 0) {
        _switchPhase();
      } else {
        ref.read(pomodoroSecondsProvider.notifier).state = currentSec;
      }
    }
  }

  void setModo(int minutos) {
    if (ref.read(pomodoroPhaseProvider) == PomodoroState.idle) {
      ref.read(pomodoroSecondsProvider.notifier).state = minutos * 60;
      tiempoTotalFase = minutos * 60;
    }
  }

  void startTimer() {
    if (ref.read(pomodoroPhaseProvider) == PomodoroState.idle) {
      ref.read(pomodoroPhaseProvider.notifier).state = PomodoroState.focus;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentSec = ref.read(pomodoroSecondsProvider);
      if (currentSec > 0) {
        ref.read(pomodoroSecondsProvider.notifier).state = currentSec - 1;
      } else {
        _switchPhase();
      }
    });
  }

  void _switchPhase() {
    HapticFeedback.heavyImpact();
    final currentState = ref.read(pomodoroPhaseProvider);
    final sesiones = ref.read(pomodoroSessionsProvider);

    if (currentState == PomodoroState.focus) {
      ref.read(pomodoroSessionsProvider.notifier).state = sesiones + 1;
      AppState.updatePomodoroRacha(sesiones + 1);

      if ((sesiones + 1) % 4 == 0) {
        ref.read(pomodoroPhaseProvider.notifier).state =
            PomodoroState.longBreak;
        ref.read(pomodoroSecondsProvider.notifier).state = 900;
        tiempoTotalFase = 900;
      } else {
        ref.read(pomodoroPhaseProvider.notifier).state =
            PomodoroState.shortBreak;
        ref.read(pomodoroSecondsProvider.notifier).state = 300;
        tiempoTotalFase = 300;
      }
    } else {
      ref.read(pomodoroPhaseProvider.notifier).state = PomodoroState.focus;
      ref.read(pomodoroSecondsProvider.notifier).state = 1500;
      tiempoTotalFase = 1500;
    }
  }

  void stopTimer() {
    _timer?.cancel();
    ref.read(pomodoroPhaseProvider.notifier).state = PomodoroState.idle;
    ref.read(pomodoroSecondsProvider.notifier).state = tiempoTotalFase;
  }
}

// ==========================================
// --- VISTA DE PRODUCTIVIDAD ---
// ==========================================
class PomodoroView extends ConsumerWidget {
  const PomodoroView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(pomodoroPhaseProvider);
    final sec = ref.watch(pomodoroSecondsProvider);
    final sesiones = ref.watch(pomodoroSessionsProvider);
    final isZenMode = ref.watch(zenModeProvider);
    final controller = ref.read(pomodoroControllerProvider);

    final bool isRunning = state != PomodoroState.idle;
    int min = sec ~/ 60;
    int s = sec % 60;

    // MAGIA RESPONSIVA
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double circleSize = screenWidth * 0.55;
    final double spacing = screenHeight * 0.03;

    return ValueListenableBuilder<Color>(
      valueListenable: PlayerManager.currentThemeColor,
      builder: (context, themeColor, _) {
        final bool isLightColor = themeColor.computeLuminance() > 0.5;
        final Color dynamicTextColor = isLightColor
            ? Colors.black
            : Colors.white;
        final Color glowColor = isLightColor
            ? themeColor.withOpacity(0.7)
            : themeColor.withOpacity(0.9);

        return SafeArea(
          child: Column(
            children: [
              // CABECERA
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Zona de Enfoque",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: theme.textTheme.bodyLarge?.color,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: sesiones > 0
                                    ? Colors.orange
                                    : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  sesiones == 0
                                      ? "Aún no hay sesiones hoy"
                                      : "Racha: $sesiones sesiones completadas",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.psychology_rounded,
                        color: themeColor,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // CONTENIDO SCROLLABLE (Elástico)
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(height: spacing),

                        // INPUT MISIÓN
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.cardColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: TextField(
                              onChanged: (v) =>
                                  ref
                                          .read(pomodoroTaskProvider.notifier)
                                          .state =
                                      v,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "¿Cuál es tu misión principal?",
                                hintStyle: TextStyle(
                                  color: theme.textTheme.bodySmall?.color,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: spacing),

                        // CÍRCULO DEL RELOJ ELÁSTICO
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.all(screenWidth * 0.08),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.cardColor,
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withOpacity(0.3),
                                blurRadius: 60,
                                spreadRadius: 15,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: circleSize,
                                height: circleSize,
                                child: CircularProgressIndicator(
                                  value: sec / controller.tiempoTotalFase,
                                  strokeWidth: 12,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor:
                                      theme.scaffoldBackgroundColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isRunning ? themeColor : theme.dividerColor,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${min.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.15,
                                      fontWeight: FontWeight.w900,
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontFamily: 'monospace',
                                      letterSpacing: -2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: state == PomodoroState.focus
                                          ? themeColor.withOpacity(0.2)
                                          : (state == PomodoroState.idle
                                                ? Colors.white10
                                                : Colors.green.withOpacity(
                                                    0.2,
                                                  )),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: state == PomodoroState.focus
                                            ? themeColor
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Text(
                                      state == PomodoroState.focus
                                          ? "EN MODO BESTIA"
                                          : (state == PomodoroState.idle
                                                ? "LISTO PARA EMPEZAR"
                                                : "TIEMPO DE RESPIRAR"),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: state == PomodoroState.focus
                                            ? themeColor
                                            : (state == PomodoroState.idle
                                                  ? Colors.grey
                                                  : Colors.green),
                                        letterSpacing: 1,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: spacing),

                        // CONTROLES DE TIEMPO
                        if (state == PomodoroState.idle) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _timeOption(
                                  context,
                                  theme,
                                  "25m",
                                  25,
                                  themeColor,
                                  controller,
                                ),
                                const SizedBox(width: 10),
                                _timeOption(
                                  context,
                                  theme,
                                  "50m",
                                  50,
                                  themeColor,
                                  controller,
                                ),
                                const SizedBox(width: 10),
                                _timeOption(
                                  context,
                                  theme,
                                  "90m",
                                  90,
                                  themeColor,
                                  controller,
                                ),
                                const SizedBox(width: 10),
                                _customTimeButton(
                                  context,
                                  theme,
                                  themeColor,
                                  controller,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: spacing),
                        ],

                        // BOTÓN DE ACCIÓN START/STOP
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            state == PomodoroState.idle
                                ? controller.startTimer()
                                : controller.stopTimer();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              gradient: state == PomodoroState.idle
                                  ? LinearGradient(
                                      colors: [
                                        themeColor,
                                        themeColor.withOpacity(0.8),
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [Colors.redAccent, Colors.red],
                                    ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: state == PomodoroState.idle
                                      ? themeColor.withOpacity(0.4)
                                      : Colors.red.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  state == PomodoroState.idle
                                      ? Icons.rocket_launch_rounded
                                      : Icons.stop_rounded,
                                  color: state == PomodoroState.idle
                                      ? dynamicTextColor
                                      : Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  state == PomodoroState.idle
                                      ? "INICIAR MISIÓN"
                                      : "ABORTAR SESIÓN",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: state == PomodoroState.idle
                                        ? dynamicTextColor
                                        : Colors.white,
                                    fontSize: 16,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ✨ NUEVO: PANEL DE GAMIFICACIÓN Y MODO ZEN
                        _buildGamificationPanel(
                          theme,
                          themeColor,
                          ref,
                          sesiones,
                          isZenMode,
                        ),
                        const SizedBox(height: 30),

                        // PANEL DE ECOSISTEMA MUSICAL LOFI
                        _buildLofiPanel(theme, themeColor, context),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MÉTODOS DE CONSTRUCCIÓN INTERNOS ---

  // ✨ EL PANEL DE ESTADÍSTICAS Y MODO ZEN
  Widget _buildGamificationPanel(
    ThemeData theme,
    Color themeColor,
    WidgetRef ref,
    int sesiones,
    bool isZenMode,
  ) {
    String rango = sesiones < 4
        ? "Estudiante"
        : (sesiones < 10 ? "Erudito" : "Maestro Zen");
    IconData rangoIcon = sesiones < 4
        ? Icons.menu_book_rounded
        : (sesiones < 10
              ? Icons.school_rounded
              : Icons.self_improvement_rounded);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isZenMode
                ? themeColor.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
            width: isZenMode ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(rangoIcon, color: themeColor),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Rango Actual",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          rango,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Racha",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      "$sesiones 🔥",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 30, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Modo Zen Estricto",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const Text(
                      "Si sales de la app, pierdes tu racha.",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Switch(
                  value: isZenMode,
                  activeColor: themeColor,
                  onChanged: (val) {
                    ref.read(zenModeProvider.notifier).state = val;
                    HapticFeedback.lightImpact();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLofiPanel(
    ThemeData theme,
    Color themeColor,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.black.withOpacity(0.3)
            : Colors.grey.shade200,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 15, bottom: 15),
            child: Text(
              "RADIOS GLOBALES (EN VIVO 24/7)",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: theme.textTheme.bodySmall?.color,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _liveRadioCard(
                  context,
                  theme,
                  "Lofi Girl",
                  "Chillhop & Focus",
                  "https://stream.zeno.fm/f3wvbbqmdg8uv",
                  "https://i.imgur.com/xO4zT4M.jpeg",
                  Icons.radio_rounded,
                  Colors.purpleAccent,
                ),
                _liveRadioCard(
                  context,
                  theme,
                  "Synthwave FM",
                  "Retrowave / Cyberpunk",
                  "https://stream.nightride.fm/nightride.m4a",
                  "https://i.imgur.com/Qh15x1F.jpeg",
                  Icons.electric_bolt_rounded,
                  Colors.pinkAccent,
                ),
                _liveRadioCard(
                  context,
                  theme,
                  "Chill Lounge",
                  "Jazz & Ambient",
                  "https://streams.ilovemusic.de/iloveradio17.mp3",
                  "https://i.imgur.com/bK1E1pT.jpeg",
                  Icons.nightlife_rounded,
                  Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeOption(
    BuildContext context,
    ThemeData theme,
    String label,
    int min,
    Color color,
    PomodoroController controller,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        controller.setModo(min);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _customTimeButton(
    BuildContext context,
    ThemeData theme,
    Color color,
    PomodoroController controller,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        int minutosElegidos = 15;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              return Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 40,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Tiempo a Medida",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "$minutosElegidos minutos",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Slider(
                        value: minutosElegidos.toDouble(),
                        min: 1,
                        max: 120,
                        divisions: 119,
                        activeColor: color,
                        inactiveColor: Colors.white10,
                        onChanged: (v) {
                          setState(() => minutosElegidos = v.toInt());
                          HapticFeedback.lightImpact();
                        },
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            controller.setModo(minutosElegidos);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "ESTABLECER",
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
              );
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Icon(Icons.tune_rounded, color: color, size: 20),
      ),
    );
  }

  Widget _liveRadioCard(
    BuildContext context,
    ThemeData theme,
    String title,
    String artist,
    String url,
    String imgUrl,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("📡 Sintonizando: $title..."),
              duration: const Duration(seconds: 1),
            ),
          );
        final station = RadioStation(
          id: title.replaceAll(" ", "_").toLowerCase(),
          name: title,
          url: url,
          favicon: imgUrl,
          tags: "lofi, focus",
          country: "Global",
        );
        PlayerManager.playRadio(station);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 140,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              artist,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodySmall?.color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
