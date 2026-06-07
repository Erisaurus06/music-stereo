import 'package:just_audio/just_audio.dart';

/// Gestor independiente para los efectos de audio de bajo nivel
class EqualizerManager {
  static final AndroidEqualizer equalizer = AndroidEqualizer();
  static final AndroidLoudnessEnhancer loudnessEnhancer =
      AndroidLoudnessEnhancer();
}
