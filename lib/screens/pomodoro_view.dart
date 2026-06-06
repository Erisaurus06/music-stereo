import 'dart:async';
import 'dart:convert'; // ✨ Para guardar links como JSON
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:music_stereo/services/radio_engine.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✨ El disco duro

import '../services/player_manager.dart';
import '../services/app_state.dart';
import '../models/app_models.dart';

// ==========================================
// --- EL CEREBRO DEL POMODORO INMORTAL ---
// ==========================================
enum PomodoroState { focus, shortBreak, longBreak, idle }

final pomodoroPhaseProvider = StateProvider<PomodoroState>(
  (ref) => PomodoroState.idle,
);
final pomodoroSecondsProvider = StateProvider<int>((ref) => 1500);
final pomodoroSessionsProvider = StateProvider<int>((ref) => 0);

// ✨ MEMORIA DE PLAYLISTS Y VIDEOS
final customLinksProvider = StateProvider<List<Map<String, String>>>(
  (ref) => [],
);

final pomodoroTaskProvider = StateProvider<String>((ref) => "");
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

  // ✨ NUEVO: Variables para almacenar los tiempos personalizados
  int focusTimeInSeconds = 1500;
  int shortBreakTimeInSeconds = 300;
  int longBreakTimeInSeconds = 900;

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
      final isZen = ref.read(zenModeProvider);
      final isFocus = ref.read(pomodoroPhaseProvider) == PomodoroState.focus;

      if (isZen && isFocus) {
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

  void setModo(int minutos, {int breakMinutos = 5}) {
    focusTimeInSeconds = minutos * 60;
    shortBreakTimeInSeconds = breakMinutos * 60;
    longBreakTimeInSeconds =
        (breakMinutos * 3) * 60; // El descanso largo es 3 veces el corto

    if (ref.read(pomodoroPhaseProvider) == PomodoroState.idle) {
      ref.read(pomodoroSecondsProvider.notifier).state = focusTimeInSeconds;
      tiempoTotalFase = focusTimeInSeconds;
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
        ref.read(pomodoroSecondsProvider.notifier).state =
            longBreakTimeInSeconds;
        tiempoTotalFase = longBreakTimeInSeconds;
      } else {
        ref.read(pomodoroPhaseProvider.notifier).state =
            PomodoroState.shortBreak;
        ref.read(pomodoroSecondsProvider.notifier).state =
            shortBreakTimeInSeconds;
        tiempoTotalFase = shortBreakTimeInSeconds;
      }
    } else {
      ref.read(pomodoroPhaseProvider.notifier).state = PomodoroState.focus;
      ref.read(pomodoroSecondsProvider.notifier).state = focusTimeInSeconds;
      tiempoTotalFase = focusTimeInSeconds;
    }
  }

  void stopTimer() {
    _timer?.cancel();
    ref.read(pomodoroPhaseProvider.notifier).state = PomodoroState.idle;
    ref.read(pomodoroSecondsProvider.notifier).state = focusTimeInSeconds;
    tiempoTotalFase = focusTimeInSeconds;
  }
}

// ==========================================
// --- VISTA DE PRODUCTIVIDAD (UI/UX PREMIUM) ---
// ==========================================
class PomodoroView extends ConsumerStatefulWidget {
  const PomodoroView({super.key});

  @override
  ConsumerState<PomodoroView> createState() => _PomodoroViewState();
}

class _PomodoroViewState extends ConsumerState<PomodoroView> {
  @override
  void initState() {
    super.initState();
    _cargarLinksGuardados(); // ✨ Leer memoria al iniciar
  }

  // ✨ FUNCIÓN PARA LEER DEL DISCO DURO
  Future<void> _cargarLinksGuardados() async {
    final prefs = await SharedPreferences.getInstance();
    final String? linksJson = prefs.getString('mis_frecuencias_pomodoro');
    if (linksJson != null) {
      final List<dynamic> decodificado = jsonDecode(linksJson);
      final List<Map<String, String>> recuperados = decodificado
          .map((e) => Map<String, String>.from(e))
          .toList();
      ref.read(customLinksProvider.notifier).state = recuperados;
    }
  }

  // ✨ FUNCIÓN PARA GUARDAR EN EL DISCO DURO
  Future<void> _guardarLinksPermanentes(List<Map<String, String>> links) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mis_frecuencias_pomodoro', jsonEncode(links));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(pomodoroPhaseProvider);
    final sec = ref.watch(pomodoroSecondsProvider);
    final sesiones = ref.watch(pomodoroSessionsProvider);
    final isZenMode = ref.watch(zenModeProvider);
    final controller = ref.read(pomodoroControllerProvider);

    final bool isRunning = state != PomodoroState.idle;
    int min = sec ~/ 60;
    int s = sec % 60;

    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double circleSize = screenWidth * 0.55;
    final double spacing = screenHeight * 0.03;

    return ValueListenableBuilder<Color>(
      valueListenable: PlayerManager.currentThemeColor,
      builder: (context, themeColor, _) {
        // ✨ CEREBRO DE LUMINOSIDAD: Aclara el color si es muy oscuro en modo oscuro
        final bool isLightMode = theme.brightness == Brightness.light;
        final HSLColor hsl = HSLColor.fromColor(themeColor);

        Color safeThemeColor = themeColor;
        if (isLightMode && hsl.lightness > 0.6) {
          safeThemeColor = hsl
              .withLightness(0.4)
              .toColor(); // Oscurece si es muy claro en modo claro
        } else if (!isLightMode && hsl.lightness < 0.4) {
          safeThemeColor = hsl
              .withLightness(0.65)
              .toColor(); // Aclara si es muy oscuro en modo oscuro
        }

        final bool isLightColor = safeThemeColor.computeLuminance() > 0.5;
        final Color dynamicTextColor = isLightColor
            ? Colors.black
            : Colors.white;
        final Color glowColor = isLightColor
            ? safeThemeColor.withOpacity(0.7)
            : safeThemeColor.withOpacity(0.9);

        return SafeArea(
          child: Column(
            children: [
              // 1. CABECERA
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
                        color: safeThemeColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.psychology_rounded,
                        color: safeThemeColor,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. CONTENIDO CENTRAL SCROLLABLE
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
                                    isRunning
                                        ? safeThemeColor
                                        : theme.dividerColor,
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
                                          ? safeThemeColor.withOpacity(0.2)
                                          : (state == PomodoroState.idle
                                                ? Colors.white10
                                                : Colors.green.withOpacity(
                                                    0.2,
                                                  )),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: state == PomodoroState.focus
                                            ? safeThemeColor
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
                                            ? safeThemeColor
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
                                  5,
                                  safeThemeColor,
                                  controller,
                                ),
                                const SizedBox(width: 10),
                                _timeOption(
                                  context,
                                  theme,
                                  "50m",
                                  50,
                                  10,
                                  safeThemeColor,
                                  controller,
                                ),
                                const SizedBox(width: 10),
                                _timeOption(
                                  context,
                                  theme,
                                  "90m",
                                  90,
                                  15,
                                  safeThemeColor,
                                  controller,
                                ),
                                const SizedBox(width: 10),
                                _customTimeButton(
                                  context,
                                  theme,
                                  safeThemeColor,
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
                                        safeThemeColor,
                                        safeThemeColor.withOpacity(0.8),
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [Colors.redAccent, Colors.red],
                                    ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: state == PomodoroState.idle
                                      ? safeThemeColor.withOpacity(0.4)
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

                        // PANEL DE GAMIFICACIÓN Y MODO ZEN
                        _buildGamificationPanel(
                          theme,
                          safeThemeColor,
                          ref,
                          sesiones,
                          isZenMode,
                        ),
                        const SizedBox(height: 30),

                        // ECOSISTEMA MULTIMEDIA
                        _buildMediaEcosystemPanel(
                          theme,
                          safeThemeColor,
                          context,
                          ref,
                        ),
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

  // ==========================================
  // --- SUB-WIDGETS INTERNOS ---
  // ==========================================

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
                // ✨ CIRUGÍA: EXPANDED PARA EVITAR OVERFLOW DE 34 PIXELES
                Expanded(
                  child: Column(
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

  // PANEL MULTIMEDIA DIVIDIDO
  Widget _buildMediaEcosystemPanel(
    ThemeData theme,
    Color themeColor,
    BuildContext context,
    WidgetRef ref,
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
          // 📻 SECCIÓN 1: RADIOS GLOBALES
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 15, bottom: 15),
            child: Text(
              "FRECUENCIAS GLOBALES (24/7)",
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
                _focusMediaCard(
                  context,
                  theme,
                  "Lofi Girl",
                  "Chillhop & Focus",
                  "https://stream.zeno.fm/f3wvbbqmdg8uv",
                  Icons.radio_rounded,
                  Colors.purpleAccent,
                  "radio",
                ),
                _focusMediaCard(
                  context,
                  theme,
                  "Synthwave FM",
                  "Retrowave Vibes",
                  "https://stream.nightride.fm/nightride.m4a",
                  Icons.electric_bolt_rounded,
                  Colors.pinkAccent,
                  "radio",
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 🟢 SECCIÓN 2: SPOTIFY
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 15, bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ✨ CIRUGÍA: EXPANDED PARA EVITAR OVERFLOW
                Expanded(
                  child: Text(
                    "TUS FRECUENCIAS (SPOTIFY)",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () =>
                      _mostrarDialogoNuevoLink(context, ref, themeColor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "+ AÑADIR",
                      style: TextStyle(
                        color: Color(0xFF1DB954),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Consumer(
              builder: (context, ref, child) {
                final misLinks = ref.watch(customLinksProvider);
                final spotifyLinks = misLinks
                    .where((l) => l['tipo'] == 'spotify')
                    .toList();

                return Row(
                  children: [
                    _focusMediaCard(
                      context,
                      theme,
                      "Deep Focus",
                      "Spotify Default",
                      "spotify:playlist:37i9dQZF1DWZeKCadgRdKQ",
                      Icons.headset_rounded,
                      const Color(0xFF1DB954),
                      "spotify",
                    ),
                    ...spotifyLinks.map(
                      (data) => _focusMediaCard(
                        context,
                        theme,
                        data['titulo']!,
                        "Mi Playlist",
                        data['uri']!,
                        Icons.library_music_rounded,
                        const Color(0xFF1DB954),
                        "spotify",
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 30),

          // 🔴 SECCIÓN 3: VIDEOS YOUTUBE
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 15, bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ✨ CIRUGÍA: EXPANDED PARA EVITAR OVERFLOW
                Expanded(
                  child: Text(
                    "ESTUDIA CONMIGO (VISUAL)",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () =>
                      _mostrarDialogoNuevoLink(context, ref, themeColor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "+ AÑADIR",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Consumer(
              builder: (context, ref, child) {
                final misLinks = ref.watch(customLinksProvider);
                final youtubeLinks = misLinks
                    .where((l) => l['tipo'] == 'youtube_video')
                    .toList();

                return Row(
                  children: [
                    _focusMediaCard(
                      context,
                      theme,
                      "Minecraft Rain",
                      "Video Default",
                      "Fj-E_w2a64A",
                      Icons.smart_display_rounded,
                      Colors.redAccent,
                      "youtube_video",
                    ),
                    ...youtubeLinks.map(
                      (data) => _focusMediaCard(
                        context,
                        theme,
                        data['titulo']!,
                        "Mi Video",
                        data['uri']!,
                        Icons.smart_display_rounded,
                        Colors.redAccent,
                        "youtube_video",
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _focusMediaCard(
    BuildContext context,
    ThemeData theme,
    String title,
    String subtitle,
    String uri,
    IconData icon,
    Color color,
    String tipo,
  ) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();

        if (tipo == 'radio') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("📡 Sintonizando: $title..."),
              duration: const Duration(seconds: 1),
            ),
          );
          final station = RadioStation(
            id: title.replaceAll(" ", "_").toLowerCase(),
            name: title,
            url: uri,
            favicon: "",
            tags: "lofi",
            country: "Global",
          );
          PlayerManager.playRadio(station);
        } else if (tipo == 'spotify') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("🟢 Abriendo Spotify...")),
          );
          final Uri url = Uri.parse(uri);
          if (await canLaunchUrl(url))
            await launchUrl(url, mode: LaunchMode.externalApplication);
        } else if (tipo == 'youtube_video') {
          showDialog(
            context: context,
            builder: (_) => YouTubeVideoModal(videoId: uri),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 15),
        width: 150,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodySmall?.color,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeOption(
    BuildContext context,
    ThemeData theme,
    String label,
    int minFocus,
    int minBreak,
    Color color,
    PomodoroController controller,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        controller.setModo(minFocus, breakMinutos: minBreak);
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
        int focusElegido = controller.focusTimeInSeconds ~/ 60;
        int breakElegido = controller.shortBreakTimeInSeconds ~/ 60;

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
                  child: SingleChildScrollView(
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
                        const SizedBox(height: 20),
                        Text(
                          "Tiempos a Medida",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ✨ SECCIÓN ENFOQUE
                        Text(
                          "Estudio: $focusElegido min",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Slider(
                          value: focusElegido.toDouble(),
                          min: 1,
                          max: 120,
                          divisions: 119,
                          activeColor: color,
                          inactiveColor: Colors.white10,
                          onChanged: (v) {
                            setState(() => focusElegido = v.toInt());
                            HapticFeedback.lightImpact();
                          },
                        ),
                        const SizedBox(height: 20),

                        // ✨ SECCIÓN DESCANSO
                        Text(
                          "Descanso: $breakElegido min",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors
                                .greenAccent, // Distintivo verde para el descanso
                            fontFamily: 'monospace',
                          ),
                        ),
                        Slider(
                          value: breakElegido.toDouble(),
                          min: 1,
                          max: 60,
                          divisions: 59,
                          activeColor: Colors.greenAccent,
                          inactiveColor: Colors.white10,
                          onChanged: (v) {
                            setState(() => breakElegido = v.toInt());
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
                              controller.setModo(
                                focusElegido,
                                breakMinutos: breakElegido,
                              );
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "ESTABLECER TIEMPOS",
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

  // ✨ DIÁLOGO INTELIGENTE Y PERMANENTE
  void _mostrarDialogoNuevoLink(
    BuildContext context,
    WidgetRef ref,
    Color themeColor,
  ) {
    final theme = Theme.of(context);
    String nuevoTitulo = "";
    String nuevoLink = "";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: Row(
            children: [
              Icon(Icons.add_link_rounded, color: themeColor),
              const SizedBox(width: 10),
              Text(
                "Vincular Frecuencia",
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: "Nombre (ej. Rap para programar)",
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => nuevoTitulo = val,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: "Pega enlace de Spotify o YouTube...",
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => nuevoLink = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (nuevoTitulo.isNotEmpty && nuevoLink.isNotEmpty) {
                  String tipoDetectado = 'spotify';
                  String uriFinal = nuevoLink;

                  if (nuevoLink.contains("youtube.com") ||
                      nuevoLink.contains("youtu.be")) {
                    tipoDetectado = 'youtube_video';
                  } else if (nuevoLink.contains("spotify.com")) {
                    try {
                      final partes = nuevoLink
                          .split("spotify.com/")[1]
                          .split("?")[0]
                          .split("/");
                      uriFinal = "spotify:${partes[0]}:${partes[1]}";
                    } catch (e) {
                      uriFinal = nuevoLink;
                    }
                  }

                  // 🧠 CEREBRO: Actualiza y Guarda en Disco Duro
                  ref.read(customLinksProvider.notifier).update((state) {
                    final newState = [
                      ...state,
                      {
                        'titulo': nuevoTitulo,
                        'uri': uriFinal,
                        'tipo': tipoDetectado,
                      },
                    ];
                    _guardarLinksPermanentes(
                      newState,
                    ); // 💾 Se sella en la memoria
                    return newState;
                  });

                  HapticFeedback.heavyImpact();
                  Navigator.pop(context);
                }
              },
              child: const Text(
                "Fijar",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// --- REPRODUCTOR VISUAL (MINI VLC YOUTUBE) ---
// ==========================================
class YouTubeVideoModal extends StatefulWidget {
  final String videoId;
  const YouTubeVideoModal({super.key, required this.videoId});
  @override
  State<YouTubeVideoModal> createState() => _YouTubeVideoModalState();
}

class _YouTubeVideoModalState extends State<YouTubeVideoModal> {
  late YoutubePlayerController _controller;
  @override
  void initState() {
    super.initState();
    final vId = YoutubePlayer.convertUrlToId(widget.videoId) ?? widget.videoId;
    _controller = YoutubePlayerController(
      initialVideoId: vId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: true,
        hideControls: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                color: Colors.black87,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Estudia Conmigo",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.redAccent,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.redAccent,
                  handleColor: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
