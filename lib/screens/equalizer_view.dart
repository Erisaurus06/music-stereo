import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../services/player_manager.dart';

class EqualizerView extends StatefulWidget {
  const EqualizerView({super.key});

  @override
  State<EqualizerView> createState() => _EqualizerViewState();
}

class _EqualizerViewState extends State<EqualizerView> {
  bool _isEnabled = false;
  AndroidEqualizerParameters? _parameters;
  double _loudness = 0.0;

  @override
  void initState() {
    super.initState();
    _initEqualizer();
  }

  Future<void> _initEqualizer() async {
    try {
      final eq = PlayerManager.equalizer;
      _isEnabled = eq.enabled;
      _parameters = await eq.parameters;
      // El potenciador de graves por defecto inicia en 0
    } catch (e) {
      debugPrint("⚠️ No se pudo cargar el ecualizador: $e");
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = PlayerManager.currentThemeColor.value;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Ecualizador",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Switch.adaptive(
            value: _isEnabled,
            activeColor: themeColor,
            onChanged: (val) async {
              HapticFeedback.heavyImpact();
              await PlayerManager.equalizer.setEnabled(val);
              setState(() => _isEnabled = val);
            },
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: _parameters == null
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // 🎛️ PANEL: Amplificador de Graves
                _buildLoudnessControl(themeColor),
                const SizedBox(height: 30),

                // 🎚️ PANEL: Bandas del Ecualizador
                SizedBox(
                  height:
                      380, // ✨ Altura fija y segura para evitar overflow en pantallas pequeñas
                  child: _buildBands(themeColor),
                ),
              ],
            ),
    );
  }

  Widget _buildLoudnessControl(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Amplificador de Graves (Loudness)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Icon(Icons.speaker_group_rounded, color: themeColor),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: themeColor,
              inactiveTrackColor: themeColor.withOpacity(0.2),
              thumbColor: Colors.white,
              trackHeight: 12, // ✨ Track ancho tipo barra de sonido
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: _loudness,
              min: 0.0,
              max: 2.0, // Rango seguro para targetGain
              onChanged: (val) {
                setState(() => _loudness = val);
                PlayerManager.loudnessEnhancer.setTargetGain(val);
              },
              onChangeEnd: (_) => HapticFeedback.lightImpact(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBands(Color themeColor) {
    final minDb = _parameters!.minDecibels;
    final maxDb = _parameters!.maxDecibels;
    final bands = _parameters!.bands;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Bandas de Frecuencia",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Icon(Icons.tune_rounded, color: themeColor),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: bands.map((band) {
                  return SizedBox(
                    width: 70, // ✨ Fija un ancho exacto para evitar Overflows
                    child: _buildBandSlider(band, minDb, maxDb, themeColor),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandSlider(
    AndroidEqualizerBand band,
    double minDb,
    double maxDb,
    Color themeColor,
  ) {
    return StreamBuilder<double>(
      stream: band.gainStream,
      builder: (context, snapshot) {
        final currentGain = snapshot.data ?? band.gain;
        return Column(
          children: [
            Text(
              "${currentGain > 0 ? '+' : ''}${currentGain.toStringAsFixed(1)}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RotatedBox(
                quarterTurns:
                    3, // ✨ Gira el slider nativo para que sea vertical
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: themeColor,
                    inactiveTrackColor: themeColor.withOpacity(0.15),
                    thumbColor: Colors.white,
                    trackHeight: 24, // ✨ Grosor premium inmersivo
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 14,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 28,
                    ),
                  ),
                  child: Slider(
                    value: currentGain.clamp(minDb, maxDb),
                    min: minDb,
                    max: maxDb,
                    onChanged: _isEnabled
                        ? (val) {
                            band.setGain(val);
                          }
                        : null,
                    onChangeEnd: (_) => HapticFeedback.selectionClick(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // ✨ Añadimos FittedBox por si la fuente del teléfono es muy grande
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatFrequency(band.centerFrequency),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatFrequency(double freq) {
    if (freq >= 1000) {
      return "${(freq / 1000).toStringAsFixed(1)}k";
    }
    return "${freq.toInt()}Hz";
  }
}
