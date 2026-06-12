import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:music_stereo/widgets/design_components.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

// Importaciones de tu proyecto
import '../api_keys.dart';
import '../services/player_manager.dart';
import '../services/app_state.dart';
import '../models/app_models.dart';
import '../main.dart'; // Temporal: para leer herramientas que siguen en main.dart
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../widgets/bluetooth_panel.dart';

// --- 6. AJUSTES (Settings Pro con Nuevas Opciones y Memoria) ---
class SettingsProView extends StatefulWidget {
  const SettingsProView({super.key});
  @override
  State<SettingsProView> createState() => _SettingsProViewState();
}

class _SettingsProViewState extends State<SettingsProView> {
  bool _isLoadingSpotify = false;

  // ✨ ALERTA NATIVA DE iOS (Reemplaza los Snackbars de Android)
  void _showIOSAlert(String title, String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("OK"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // ✨ SELECTOR NATIVO DE iOS (Reemplaza los Dropdowns de Android)
  void _showPicker({
    required List<String> items,
    required int initialIndex,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    final theme = Theme.of(context);
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Container(
              color: theme.cardColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    child: const Text(
                      'Listo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32.0,
                scrollController: FixedExtentScrollController(
                  initialItem: initialIndex,
                ),
                onSelectedItemChanged: onSelectedItemChanged,
                children: items
                    .map(
                      (e) => Center(
                        child: Text(
                          e,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToSpotify() async {
    setState(() => _isLoadingSpotify = true);
    try {
      String token = await SpotifySdk.getAccessToken(
        clientId: dotenv.env['SPOTIFY_CLIENT_ID']!,
        redirectUrl: "tecconnection://callback",
        scope:
            "app-remote-control, user-modify-playback-state, playlist-read-private",
      );
      bool result = await SpotifySdk.connectToSpotifyRemote(
        clientId: ApiKeys.spotifyClientId,
        redirectUrl: "tecconnection://callback",
        accessToken: token,
      );
      if (result) {
        PlayerManager.isSpotifyLinked.value = true;
        PlayerManager.startSpotifyRadar();
        _showIOSAlert("Vinculado", "✅ Conectado a Spotify Premium con éxito.");
      }
    } catch (e) {
      _showIOSAlert("Error de Vinculación", "❌ Ocurrió un error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingSpotify = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            "Ajustes",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700, // ✨ Tipografía SF Pro original
              color: theme.textTheme.bodyLarge?.color,
              letterSpacing: 0.41,
            ),
          ),
          const SizedBox(height: 25),
          // --- BLOQUE 1.5: TEMA GENERAL DE LA APLICACIÓN ---
          _buildConfigCard(
            context,
            title: "Apariencia del Sistema",
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppState.themeMode,
                builder: (context, mode, _) => ListTile(
                  title: Text(
                    "Modo de Color",
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mode == ThemeMode.system
                            ? "Automático"
                            : (mode == ThemeMode.dark ? "Oscuro" : "Claro"),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        CupertinoIcons.chevron_forward,
                        color: Colors.grey,
                        size: 18,
                      ),
                    ],
                  ),
                  onTap: () {
                    final items = ["Automático", "Modo Oscuro", "Modo Claro"];
                    final values = [
                      ThemeMode.system,
                      ThemeMode.dark,
                      ThemeMode.light,
                    ];
                    int initialIndex = values.indexOf(mode);
                    _showPicker(
                      items: items,
                      initialIndex: initialIndex,
                      onSelectedItemChanged: (idx) {
                        AppState.setTheme(values[idx]);
                        if (AppState.enableHaptics.value)
                          HapticFeedback.selectionClick();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // --- BLOQUE 1: PERSONALIZACIÓN DEL REPRODUCTOR (UI/UX) ---
          _buildConfigCard(
            context,
            title: "Diseño y Experiencia",
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: AppState.playerLayout,
                  builder: (context, layout, _) =>
                      DropdownButtonFormField<String>(
                        value: layout,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: "Estructura Visual",
                          labelStyle: TextStyle(color: Colors.grey),
                        ),
                        dropdownColor: theme.cardColor,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: "Cristal Inmersivo",
                            child: Text("Cristal Inmersivo (Apple)"),
                          ),
                          DropdownMenuItem(
                            value: "Consola Oscura",
                            child: Text("Consola Oscura (Spotify)"),
                          ),
                          DropdownMenuItem(
                            value: "Neo-Retro",
                            child: Text("Neo-Retro (Vinilo)"),
                          ),
                          // ✨ LAS DOS NUEVAS INTERFACES
                          DropdownMenuItem(
                            value: "Minimalista Zen",
                            child: Text("Minimalista Zen (Claro)"),
                          ),
                          DropdownMenuItem(
                            value: "Cyberpunk Neón",
                            child: Text("Cyberpunk Neón (Gamer)"),
                          ),
                        ],
                        onChanged: (v) {
                          AppState.setPlayerLayout(v!);
                          if (AppState.enableHaptics.value) {
                            HapticFeedback.selectionClick();
                          }
                        },
                      ),
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              ValueListenableBuilder<bool>(
                valueListenable: AppState.enableHaptics,
                builder: (context, haptics, _) => ListTile(
                  title: Text(
                    "Vibración Háptica",
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    "Respuestas táctiles al tocar botones",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: CupertinoSwitch(
                    activeColor: theme.primaryColor,
                    value: haptics,
                    onChanged: (v) {
                      AppState.setHaptics(v);
                      if (v) HapticFeedback.heavyImpact();
                    },
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              ValueListenableBuilder<bool>(
                valueListenable: AppState.highFidelityAnimations,
                builder: (context, anims, _) => ListTile(
                  title: Text(
                    "Animaciones de Alta Fidelidad",
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    "Apágalo para ahorrar batería",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: CupertinoSwitch(
                    activeColor: theme.primaryColor,
                    value: anims,
                    onChanged: (v) {
                      AppState.setAnimations(v);
                      if (AppState.enableHaptics.value) {
                        HapticFeedback.lightImpact();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 25),
          Text(
            "Personalización",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 15),

          // 🖼️ BOTÓN PARA CAMBIAR EL FONDO GLOBAL
          GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              final picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.gallery,
              );

              if (image != null) {
                final directory = await getApplicationDocumentsDirectory();
                final String newPath =
                    '${directory.path}/custom_bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final File newImage = await File(image.path).copy(newPath);

                // Guardamos la imagen en el cerebro de la app
                AppState.backgroundImagePath.value = newImage.path;

                _showIOSAlert(
                  "Fondo Actualizado",
                  "🌌 Fondo espacial activado correctamente.",
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wallpaper_rounded,
                      color: Colors.blueAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Fondo de Pantalla",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Elige una imagen de tu galería",
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: AppState.backgroundImagePath,
                    builder: (context, path, _) {
                      if (path != null) {
                        return IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            AppState.backgroundImagePath.value =
                                null; // Borrar fondo
                          },
                        );
                      }
                      return Icon(
                        Icons.chevron_right_rounded,
                        color: theme.dividerColor,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          // ☁️ BOTÓN PARA OBTENER FONDO DE API
          GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              try {
                // Genera un fondo aleatorio con desenfoque elegante de Picsum
                final url = Uri.parse("https://picsum.photos/800/1200/?blur=2");
                final response = await http
                    .get(url)
                    .timeout(const Duration(seconds: 10));

                if (response.statusCode == 200) {
                  final directory = await getApplicationDocumentsDirectory();
                  final String newPath =
                      '${directory.path}/api_bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  final File newImage = await File(
                    newPath,
                  ).writeAsBytes(response.bodyBytes);

                  AppState.backgroundImagePath.value = newImage.path;

                  _showIOSAlert(
                    "Fondo Actualizado",
                    "🌌 Fondo estético descargado y activado.",
                  );
                }
              } catch (e) {
                _showIOSAlert(
                  "Error de Conexión",
                  "❌ No se pudo descargar el fondo desde la nube.",
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_download_rounded,
                      color: Colors.purpleAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Fondo Aleatorio (Nube)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Descarga un fondo estético por API",
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- BLOQUE 2: MOTOR DE REPRODUCCIÓN ---
          _buildConfigCard(
            context,
            title: "Motor de Audio",
            children: [
              ValueListenableBuilder<Color>(
                valueListenable: PlayerManager.currentThemeColor,
                builder: (context, themeColor, _) {
                  final bool isLightColor = themeColor.computeLuminance() > 0.5;
                  final Color dynamicTextColor = isLightColor
                      ? Colors.black
                      : Colors.white;

                  return ValueListenableBuilder<bool>(
                    valueListenable: PlayerManager.isPlaying,
                    builder: (context, playing, _) => AnimatedPress(
                      onTap: PlayerManager.togglePlay,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: themeColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: dynamicTextColor,
                          size: 40,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- BLOQUE 3: SISTEMA Y CONEXIONES ---
          _buildConfigCard(
            context,
            title: "Servicios de Streaming",
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: PlayerManager.isSpotifyLinked,
                builder: (context, isLinked, _) => ListTile(
                  leading: const Icon(
                    Icons.settings_input_antenna_rounded,
                    color: Colors.green,
                    size: 28,
                  ),
                  title: const Text(
                    "Spotify Premium",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLinked
                          ? Colors.transparent
                          : Colors.green.withOpacity(0.15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: isLinked ? null : _connectToSpotify,
                    child: Text(
                      isLinked ? "CONECTADO" : "VINCULAR",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildUpcomingService(
                context,
                "Apple Music",
                Colors.pinkAccent,
                Icons.apple,
              ),
              _buildUpcomingService(
                context,
                "Amazon Music",
                Colors.orange,
                Icons.library_music_rounded,
              ),
              _buildUpcomingService(
                context,
                "YouTube Music",
                Colors.red,
                Icons.play_circle_fill_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- BLOQUE 3.5: BLUETOOTH Y DISPOSITIVOS ---
          _buildConfigCard(
            context,
            title: "Dispositivos y Sonido",
            children: [
              ListTile(
                onTap: () {
                  HapticFeedback.selectionClick();
                  BluetoothPanel.show(context);
                },
                leading: const Icon(
                  Icons.bluetooth_audio_rounded,
                  color: Colors.blueAccent,
                  size: 28,
                ),
                title: const Text(
                  "Bluetooth y Sonido",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  "Gestiona conexiones y volumen",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- BLOQUE 4: MI CUENTA ---
          _buildConfigCard(
            context,
            title: "Mi Cuenta",
            children: [
              ListTile(
                leading: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.grey,
                ),
                title: Text(
                  Supabase.instance.client.auth.currentUser?.email ?? "Usuario",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  "Sesión activa en la nube",
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              ListTile(
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  HapticFeedback.heavyImpact();
                },
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "CERRAR SESIÓN",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 150),
        ],
      ),
    );
  }

  Widget _buildUpcomingService(
    BuildContext context,
    String name,
    Color color,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: color.withOpacity(0.5), size: 28),
      title: Text(
        name,
        style: const TextStyle(
          color: Colors.white38,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: TextButton(
        onPressed: () {
          _showIOSAlert(
            "Próximamente",
            "🚀 $name estará disponible en la próxima actualización (v2.0).",
          );
        },
        child: const Text(
          "PRÓXIMAMENTE",
          style: TextStyle(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildConfigCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15, bottom: 6, top: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: CupertinoColors.systemGrey, // ✨ Título gris nativo
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(
              10,
            ), // ✨ Curvatura oficial de celdas en iOS
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
