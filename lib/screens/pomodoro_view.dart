import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import '../services/radio_engine.dart';
// Importaciones de tu proyecto
import '../services/player_manager.dart';
import '../services/app_state.dart';
import '../api_keys.dart';

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
    final controller = ref.read(pomodoroControllerProvider);

    final bool isRunning = state != PomodoroState.idle;
    int min = sec ~/ 60;
    int s = sec % 60;

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
                  vertical: 20,
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

              // CONTENIDO SCROLLABLE
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // INPUT MISIÓN
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 5,
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
                                fontSize: 18,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),

                        // CÍRCULO DEL RELOJ
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(35),
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
                                width: 240,
                                height: 240,
                                child: CircularProgressIndicator(
                                  value: sec / controller.tiempoTotalFase,
                                  strokeWidth: 14,
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
                                      fontSize: 65,
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
                        const SizedBox(height: 50),

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
                          const SizedBox(height: 30),
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
                              vertical: 18,
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
                        const SizedBox(height: 40),

                        // ==========================================
                        // --- PANEL DE ECOSISTEMA MUSICAL LOFI ---
                        // ==========================================
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 25),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.grey.shade200,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(40),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // FILA 1: RADIOS EN VIVO (24/7)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 30,
                                  right: 15,
                                  bottom: 15,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
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

                              const SizedBox(height: 35),

                              // FILA 2: PISTAS FIJAS DE SUPABASE
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 30,
                                  right: 15,
                                  bottom: 15,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "PISTAS FIJAS (TU NUBE SUPABASE)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: theme.textTheme.bodySmall?.color,
                                        fontSize: 11,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.info_outline_rounded,
                                        color: Colors.grey,
                                        size: 22,
                                      ),
                                      onPressed: () => _showCreditsDialog(
                                        context,
                                        theme,
                                        themeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    _localMusicCard(
                                      context,
                                      theme,
                                      "Awakening Forest",
                                      "Chase9602",
                                      "chase9602-the-wind-awakening-memories-of-the-forest-468155.mp3",
                                      Icons.park_rounded,
                                      themeColor,
                                    ),
                                    _localMusicCard(
                                      context,
                                      theme,
                                      "Study Calm",
                                      "Fassounds",
                                      "fassounds-lofi-study-calm-peaceful-chill-hop-112191.mp3",
                                      Icons.menu_book_rounded,
                                      themeColor,
                                    ),
                                    _localMusicCard(
                                      context,
                                      theme,
                                      "Lofi Girl Chill",
                                      "Mondamusic",
                                      "mondamusic-lofi-lofi-girl-lofi-chill-512853.mp3",
                                      Icons.coffee_rounded,
                                      themeColor,
                                    ),
                                    _localMusicCard(
                                      context,
                                      theme,
                                      "Long Day",
                                      "Purrplecat",
                                      "purrplecat-long-day-518602.mp3",
                                      Icons.nightlight_round,
                                      themeColor,
                                    ),
                                    _localMusicCard(
                                      context,
                                      theme,
                                      "Hip Hop Vibes",
                                      "Leberch",
                                      "leberch-lofi-hip-hop-519408.mp3",
                                      Icons.headphones_rounded,
                                      themeColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  // --- MÉTODOS DE CONSTRUCCIÓN INTERNOS ---
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
                height: 300,
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
                child: Column(
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
                    const Spacer(),
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

  // ✨ TARJETA PARA RADIOS EN VIVO (24/7)
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
              content: Text("📡 Sintonizando radio en vivo: $title..."),
              duration: const Duration(seconds: 1),
            ),
          );

        final station = RadioStation(
          id: title.replaceAll(" ", "_").toLowerCase(),
          name: title,
          url: url,
          favicon: imgUrl,
          tags: "lofi, focus, 24/7",
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

  // TARJETA PARA PISTAS FIJAS DE SUPABASE
  Widget _localMusicCard(
    BuildContext context,
    ThemeData theme,
    String title,
    String artist,
    String filename,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🎵 Conectando a Supabase: $title..."),
              duration: const Duration(seconds: 1),
            ),
          );
        try {
          if (PlayerManager.isSpotifyLinked.value) {
            try {
              await SpotifySdk.pause();
            } catch (_) {}
          }

          PlayerManager.activeEngine.value = AudioEngineType.local;
          PlayerManager.currentTitle.value = title;
          PlayerManager.currentArtist.value = artist;
          PlayerManager.currentArtwork.value = null;
          PlayerManager.isPlaying.value = true;

          final String fileUrl =
              "${ApiKeys.supabaseUrl}/storage/v1/object/public/lofi_sounds/$filename";
          final audioSource = AudioSource.uri(
            Uri.parse(fileUrl),
            tag: MediaItem(id: filename, title: title, artist: artist),
          );

          await PlayerManager.player.setAudioSource(audioSource);
          await PlayerManager.player.setLoopMode(LoopMode.one);
          PlayerManager.player.play();
        } catch (e) {
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "❌ Error Lofi: Asegúrate de tener tu Bucket creado.",
                ),
                backgroundColor: Colors.red,
              ),
            );
        }
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

  void _showCreditsDialog(
    BuildContext context,
    ThemeData theme,
    Color themeColor,
  ) {
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
              Icon(Icons.volunteer_activism_rounded, color: themeColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Supabase Audio",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sube estos archivos a tu Bucket 'lofi_sounds' en Supabase para que los botones inferiores funcionen:",
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 15),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "• chase9602-the-wind...\n• fassounds-lofi-study...\n• mondamusic-lofi-girl...\n• purrplecat-long-day...\n• leberch-lofi-hip-hop...",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "CERRAR",
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
