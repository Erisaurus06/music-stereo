import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import '../services/player_manager.dart';

// ✨ PANTALLA FLOTANTE DE DISPOSITIVOS DE AUDIO (BLUETOOTH)
class AudioRouteSheet extends StatelessWidget {
  const AudioRouteSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Barrita superior (Handle)
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            "Dispositivos de Audio",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Opcion 1: Teléfono
          ListTile(
            leading: const Icon(Icons.phone_iphone_rounded, size: 30),
            title: const Text(
              "Este Teléfono",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(
              Icons.check_circle_rounded,
              color: Color.fromARGB(255, 53, 105, 250),
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),

          // Opcion 2: Buscar Bluetooth
          ListTile(
            leading: const Icon(
              Icons.bluetooth_audio_rounded,
              size: 30,
              color: Colors.grey,
            ),
            title: const Text(
              "Conectar a Bluetooth...",
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
            },
          ),
        ],
      ),
    );
  }
}
