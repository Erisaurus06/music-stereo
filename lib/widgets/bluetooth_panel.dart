import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:app_settings/app_settings.dart';
import '../services/player_manager.dart';
import '../services/app_state.dart';
import 'player_ui.dart';

class BluetoothPanel extends StatefulWidget {
  const BluetoothPanel({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BluetoothPanel(),
    );
  }

  @override
  State<BluetoothPanel> createState() => _BluetoothPanelState();
}

class _BluetoothPanelState extends State<BluetoothPanel> {
  List<AudioDevice> _dispositivos = [];
  bool _buscando = true;

  @override
  void initState() {
    super.initState();
    _escanearDispositivosReales();
  }

  Future<void> _escanearDispositivosReales() async {
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices();
      if (mounted) {
        setState(() {
          _dispositivos = devices.where((d) {
            if (!d.isOutput) return false;
            return d.type == AudioDeviceType.builtInSpeaker ||
                d.type == AudioDeviceType.bluetoothA2dp ||
                d.type == AudioDeviceType.wiredHeadphones ||
                d.type == AudioDeviceType.wiredHeadset;
          }).toList();
          final seen = <String>{};
          _dispositivos.retainWhere((d) => seen.add(d.name));
          _buscando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Evita que el teclado o el borde inferior corten el panel
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 40,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BARRA DE ARRASTRE SUPERIOR
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // CABECERA BLUETOOTH
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bluetooth_connected_rounded,
                    color: Colors.blueAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  "Dispositivos",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.textTheme.bodyLarge?.color,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // SCRULL (SLIDER) DE VOLUMEN SINCRONIZADO AL SISTEMA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: SystemVolumeSlider(
                activeColor: Colors.blueAccent,
                textColor: theme.textTheme.bodyLarge?.color ?? Colors.white,
              ),
            ),
            const SizedBox(height: 30),

            // HISTORIAL DE DISPOSITIVOS MAS USADOS / REALES
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "CONEXIONES DE AUDIO",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
            const SizedBox(height: 10),

            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height *
                    0.40, // ✨ Ligeramente más amplio para evitar desbordes
              ),
              child: _buscando
                  ? const Padding(
                      padding: EdgeInsets.all(30.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : ListView(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      children: _dispositivos.isEmpty
                          ? [
                              _buildDeviceTile(
                                name: "Altavoz Interno",
                                subtitle: "Dispositivo predeterminado",
                                icon: Icons.smartphone_rounded,
                                isConnected: true,
                                theme: theme,
                              ),
                            ]
                          : _dispositivos.map((d) {
                              bool isBluetooth =
                                  d.type == AudioDeviceType.bluetoothA2dp;
                              bool isWired =
                                  d.type == AudioDeviceType.wiredHeadphones ||
                                  d.type == AudioDeviceType.wiredHeadset;
                              bool isSpeaker =
                                  d.type == AudioDeviceType.builtInSpeaker;

                              IconData icon = Icons.speaker_rounded;
                              if (isBluetooth)
                                icon = Icons.bluetooth_audio_rounded;
                              if (isWired) icon = Icons.headphones_rounded;
                              if (isSpeaker) icon = Icons.smartphone_rounded;

                              String nombre = d.name;
                              if (isSpeaker &&
                                  (nombre.isEmpty ||
                                      nombre.toLowerCase().contains(
                                        "speaker",
                                      ))) {
                                nombre = "Altavoz Interno";
                              } else if (nombre.isEmpty) {
                                nombre = "Dispositivo de Audio";
                              }

                              String subtitulo = "Conexión interna";
                              if (isBluetooth)
                                subtitulo = "Conectado vía Bluetooth";
                              if (isWired) subtitulo = "Conectado por cable";

                              return _buildDeviceTile(
                                name: nombre,
                                subtitle: subtitulo,
                                icon: icon,
                                isConnected: true,
                                theme: theme,
                              );
                            }).toList(),
                    ),
            ),

            const SizedBox(height: 25),

            // BOTÓN DE BÚSQUEDA / REDIRECCIÓN
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.15),
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (AppState.enableHaptics.value)
                    HapticFeedback.selectionClick();

                  AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                  Navigator.pop(context); // Cierra el panel
                },
                icon: const Icon(Icons.bluetooth_searching_rounded),
                label: const Text(
                  "BUSCAR DISPOSITIVOS",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile({
    required String name,
    required String subtitle,
    required IconData icon,
    required bool isConnected,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 2,
          ),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected
                  ? Colors.blueAccent.withOpacity(0.2)
                  : theme.cardColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isConnected
                    ? Colors.blueAccent.withOpacity(0.5)
                    : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Icon(
              icon,
              color: isConnected ? Colors.blueAccent : Colors.grey,
            ),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: isConnected ? FontWeight.w800 : FontWeight.w600,
              color: isConnected
                  ? Colors.blueAccent
                  : theme.textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: isConnected
                  ? Colors.blueAccent.withOpacity(0.8)
                  : Colors.grey,
              fontSize: 12,
            ),
          ),
          trailing: isConnected
              ? const Icon(Icons.waves_rounded, color: Colors.blueAccent)
              : const Icon(Icons.more_vert_rounded, color: Colors.grey),
        ),
      ),
    );
  }
}
