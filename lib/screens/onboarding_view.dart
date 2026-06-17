import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';
import 'auth_gate.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  PermissionStatus _storageStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final storage =
        Platform.isAndroid && (await _getAndroidVersion() ?? 0) >= 13
        ? await Permission.audio.status
        : await Permission.storage.status;
    final notifications = await Permission.notification.status;

    if (mounted) {
      setState(() {
        _storageStatus = storage;
        _notificationStatus = notifications;
      });
    }
  }

  Future<int?> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      // Esta es una forma de obtener la versión del SDK. No es un método oficial de Flutter.
      // Se basa en que `Platform.version` contiene "SDK X".
      final version = Platform.version;
      final sdkInt = int.tryParse(version.split(" ")[1].split(".")[0]);
      return sdkInt;
    }
    return null;
  }

  Future<void> _requestStorage() async {
    HapticFeedback.heavyImpact();
    final permission =
        Platform.isAndroid && (await _getAndroidVersion() ?? 0) >= 13
        ? Permission.audio
        : Permission.storage;

    await permission.request();
    _checkPermissions();
  }

  Future<void> _requestNotifications() async {
    HapticFeedback.heavyImpact();
    await Permission.notification.request();
    _checkPermissions();
  }

  Future<void> _finishOnboarding() async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allGranted =
        _storageStatus.isGranted && _notificationStatus.isGranted;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Un último paso",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Para ofrecerte una experiencia completa, Music Stereo necesita los siguientes permisos:",
                style: TextStyle(
                  fontSize: 16,
                  color: theme.textTheme.bodyMedium?.color,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              _PermissionCard(
                title: "Música y Audio",
                subtitle:
                    "Para encontrar y reproducir tus archivos MP3 locales.",
                icon: Icons.folder_music_rounded,
                status: _storageStatus,
                onRequest: _requestStorage,
              ),
              const SizedBox(height: 20),
              _PermissionCard(
                title: "Notificaciones",
                subtitle:
                    "Para los controles en la barra de estado y las alertas del temporizador Pomodoro.",
                icon: Icons.notifications_active_rounded,
                status: _notificationStatus,
                onRequest: _requestNotifications,
              ),
              const Spacer(),
              if (allGranted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _finishOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "FINALIZAR CONFIGURACIÓN",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final PermissionStatus status;
  final VoidCallback onRequest;

  const _PermissionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isGranted = status.isGranted;
    final bool isPermanentlyDenied = status.isPermanentlyDenied;

    Color cardColor = isGranted
        ? theme.primaryColor.withValues(alpha: 0.1)
        : theme.cardColor;
    Color borderColor = isGranted ? theme.primaryColor : theme.dividerColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isGranted
                    ? theme.primaryColor
                    : theme.textTheme.bodyMedium?.color,
                size: 28,
              ),
              const SizedBox(width: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isGranted
                  ? null
                  : (isPermanentlyDenied
                        ? AppSettings.openAppSettings
                        : onRequest),
              style: ElevatedButton.styleFrom(
                backgroundColor: isGranted
                    ? Colors.green
                    : (isPermanentlyDenied
                          ? Colors.amber.shade800
                          : theme.primaryColor),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.green.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                isGranted
                    ? "PERMISO CONCEDIDO"
                    : (isPermanentlyDenied
                          ? "ABRIR AJUSTES"
                          : "CONCEDER PERMISO"),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
