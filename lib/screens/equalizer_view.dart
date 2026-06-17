import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interactive_slider/interactive_slider.dart';
import 'package:just_audio/just_audio.dart';
import '../services/player_manager.dart';
import '../services/equalizer_manager.dart';

class EqualizerView extends StatefulWidget {
  const EqualizerView({super.key});

  @override
  State<EqualizerView> createState() => _EqualizerViewState();
}

class _EqualizerViewState extends State<EqualizerView> {
  bool _eqEnabled = false;
  AndroidEqualizerParameters? _params;
  List<double> _targetGains = [];
  Duration _animationDuration = Duration.zero;
  String _activePreset = 'Custom';

  final Map<String, List<double>> _presets = {
    'Custom': [],
    'Pop': [1.5, 0.5, 0.0, -1.0, 2.0],
    'Rock': [2.0, 1.0, -0.5, 0.5, 2.5],
    'Bass': [3.0, 2.0, 0.0, 1.0, 1.5],
    'Acoustic': [1.0, 0.5, 1.5, 0.5, 1.0],
    'Vocal': [-1.0, -0.5, 2.0, 1.5, -0.5],
  };

  @override
  void initState() {
    super.initState();
    _checkEqStatus();
  }

  Future<void> _checkEqStatus() async {
    if (!Platform.isAndroid) return;
    try {
      final enabled = PlayerManager.equalizer.enabled;
      _params = await PlayerManager.equalizer.parameters;

      if (_params != null) {
        _targetGains = List.filled(_params!.bands.length, 0.0);
        for (int i = 0; i < _params!.bands.length; i++) {
          _targetGains[i] = await _params!.bands[i].gainStream.first;
        }
      }

      if (mounted) setState(() => _eqEnabled = enabled);
    } catch (e) {
      debugPrint("Hardware de ecualización no soportado.");
    }
  }

  // ✨ DISPARADOR MOTORIZADO: Aplica el preset usando TweenAnimationBuilder
  void _applyPreset(String presetName) {
    HapticFeedback.mediumImpact();
    setState(() {
      _activePreset = presetName;
      _animationDuration = const Duration(
        milliseconds: 600,
      ); // Animación suave al auto-ajustarse
      final presetGains = _presets[presetName] ?? [];
      for (int i = 0; i < _targetGains.length; i++) {
        // Protege contra hardwares con más de 5 bandas rellenando con 0
        _targetGains[i] = i < presetGains.length ? presetGains[i] : 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = PlayerManager.currentThemeColor.value;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Negro técnico puro (OLED)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          "Calibración Hi-Fi",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        centerTitle: true,
        actions: [
          Switch.adaptive(
            value: _eqEnabled,
            activeColor: themeColor,
            onChanged: (v) async {
              HapticFeedback.lightImpact();
              await PlayerManager.equalizer.setEnabled(v);
              setState(() => _eqEnabled = v);
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        bottom: false, // Edge-to-Edge activado
        child: _params == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const SizedBox(height: 10),
                  // 🎛️ SELECTOR DE PRESETS HORIZONTAL
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: _presets.keys.map((preset) {
                        final isActive = _activePreset == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ChoiceChip(
                            label: Text(preset),
                            selected: isActive,
                            selectedColor: themeColor.withValues(alpha: 0.2),
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: isActive ? themeColor : Colors.white70,
                              fontWeight: isActive
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.05,
                            ),
                            side: BorderSide(
                              color: isActive ? themeColor : Colors.transparent,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (_) => _applyPreset(preset),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 🎚️ LOS FADERS MOTORIZADOS
                  Expanded(
                    child: Opacity(
                      opacity: _eqEnabled ? 1.0 : 0.3,
                      child: IgnorePointer(
                        ignoring: !_eqEnabled,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(_params!.bands.length, (
                            index,
                          ) {
                            final band = _params!.bands[index];
                            return _AnimatedEqSlider(
                              band: band,
                              minDb: _params!.minDecibels,
                              maxDb: _params!.maxDecibels,
                              themeColor: themeColor,
                              targetGain: _targetGains[index],
                              animationDuration: _animationDuration,
                              onManualDrag: (v) {
                                setState(() {
                                  _activePreset = 'Custom';
                                  _animationDuration = Duration
                                      .zero; // Sin animación para reaccionar inmediato al dedo
                                  _targetGains[index] = v;
                                });
                              },
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: bottomPadding > 0 ? bottomPadding + 20 : 40),
                ],
              ),
      ),
    );
  }
}

// ✨ WIDGET INTERNO: El Fader Motorizado Individual
class _AnimatedEqSlider extends StatefulWidget {
  final AndroidEqualizerBand band;
  final double minDb;
  final double maxDb;
  final Color themeColor;
  final double targetGain;
  final Duration animationDuration;
  final ValueChanged<double> onManualDrag;

  const _AnimatedEqSlider({
    required this.band,
    required this.minDb,
    required this.maxDb,
    required this.themeColor,
    required this.targetGain,
    required this.animationDuration,
    required this.onManualDrag,
  });

  @override
  State<_AnimatedEqSlider> createState() => _AnimatedEqSliderState();
}

class _AnimatedEqSliderState extends State<_AnimatedEqSlider> {
  double _previousGain = 0.0;

  @override
  Widget build(BuildContext context) {
    // ✨ MAGIA MOTORIZADA: El Tween reacciona a los cambios en targetGain
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.targetGain),
      duration: widget.animationDuration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        // ✨ Sincronizar el hardware con la animación (silenciosamente)
        if (widget.animationDuration.inMilliseconds > 0) {
          widget.band.setGain(animatedValue);
        }

        return Column(
          children: [
            Text(
              "${(widget.band.centerFrequency / 1000).toStringAsFixed(0)}k",
              style: TextStyle(
                color: widget.targetGain == animatedValue
                    ? widget.themeColor
                    : Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 24,
                    ),
                  ),
                  child: Slider(
                    min: widget.minDb,
                    max: widget.maxDb,
                    value: animatedValue.clamp(widget.minDb, widget.maxDb),
                    activeColor: widget.themeColor,
                    inactiveColor: Colors.white.withValues(alpha: 0.05),
                    onChanged: (v) {
                      bool wasNegative = _previousGain < 0;
                      bool wasPositive = _previousGain > 0;
                      bool isNegative = v < 0;
                      bool isPositive = v > 0;
                      if ((wasNegative && !isNegative) ||
                          (wasPositive && !isPositive)) {
                        HapticFeedback.selectionClick();
                      }
                      _previousGain = v;
                      widget.band.setGain(v);
                      widget.onManualDrag(v);
                    },
                    onChangeStart: (_) => HapticFeedback.lightImpact(),
                    onChangeEnd: (_) => HapticFeedback.mediumImpact(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 20,
              child: Text(
                "${animatedValue > 0 ? '+' : ''}${animatedValue.toStringAsFixed(1)} dB",
                style: TextStyle(
                  color: animatedValue.abs() < 0.1
                      ? Colors.white24
                      : widget.themeColor.withValues(alpha: 0.8),
                  fontSize: 12,
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
