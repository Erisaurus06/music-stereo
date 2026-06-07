import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/player_manager.dart';
import '../services/app_state.dart';

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
  bool _isBluetoothOn = true;
  double _volume = 1.0;

  // Simulación de historial de dispositivos con iconos variados
  final List<Map<String, dynamic>> _devices = [
    {
      "name": "AirPods Pro Ultra",
      "type": Icons.headphones_rounded,
      "connected": true,
    },
    {
      "name": "Sony SRS-XB43",
      "type": Icons.speaker_rounded,
      "connected": false,
    },
    {
      "name": "MacBook Pro",
      "type": Icons.laptop_mac_rounded,
      "connected": false,
    },
    {
      "name": "Estéreo del Coche",
      "type": Icons.directions_car_rounded,
      "connected": false,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Leemos el volumen actual directamente desde tu PlayerManager
    _volume = PlayerManager.player.volume;
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                      "Bluetooth",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.textTheme.bodyLarge?.color,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isBluetoothOn,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) {
                    if (AppState.enableHaptics.value)
                      HapticFeedback.heavyImpact();
                    setState(() => _isBluetoothOn = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 25),

            // SCRULL (SLIDER) DE VOLUMEN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Icon(
                    _volume == 0
                        ? Icons.volume_mute_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blueAccent,
                        inactiveTrackColor: Colors.grey.withOpacity(0.2),
                        thumbColor: Colors.blueAccent,
                        trackHeight: 6,
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 15,
                        ),
                      ),
                      child: Slider(
                        value: _volume,
                        onChanged: (val) {
                          setState(() => _volume = val);
                          PlayerManager.player.setVolume(
                            val,
                          ); // Aplica volumen a tu música
                        },
                      ),
                    ),
                  ),
                  Text(
                    "${(_volume * 100).toInt()}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // HISTORIAL DE DISPOSITIVOS MAS USADOS
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "DISPOSITIVOS RECIENTES",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
            const SizedBox(height: 10),

            if (!_isBluetoothOn)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled_rounded,
                      size: 50,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Activa el Bluetooth para ver dispositivos",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ..._devices.map((device) => _buildDeviceTile(device, theme)),

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

                  // 💡 SUGERENCIA: Para abrir los ajustes reales, añade el paquete 'app_settings'
                  // en tu pubspec.yaml y llama a: AppSettings.openAppSettings(type: AppSettingsType.bluetooth);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        "🔍 Abriendo configuraciones de Bluetooth...",
                      ),
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
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

  Widget _buildDeviceTile(Map<String, dynamic> device, ThemeData theme) {
    bool isConnected = device['connected'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            if (AppState.enableHaptics.value) HapticFeedback.lightImpact();
            // Simular que conecta a este dispositivo
            setState(() {
              for (var d in _devices) {
                d['connected'] = false; // Desconecta todos
              }
              device['connected'] = true; // Conecta el seleccionado
            });
          },
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
                device['type'],
                color: isConnected ? Colors.blueAccent : Colors.grey,
              ),
            ),
            title: Text(
              device['name'],
              style: TextStyle(
                fontWeight: isConnected ? FontWeight.w800 : FontWeight.w600,
                color: isConnected
                    ? Colors.blueAccent
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
            subtitle: Text(
              isConnected ? "Conectado ahora" : "Guardado",
              style: TextStyle(
                color: isConnected
                    ? Colors.blueAccent.withOpacity(0.8)
                    : Colors.grey,
                fontSize: 12,
              ),
            ),
            trailing: isConnected
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.blueAccent,
                  )
                : const Icon(Icons.more_vert_rounded, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
