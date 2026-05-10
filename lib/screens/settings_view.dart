import 'package:flutter/material.dart';
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
import 'dart:io';
import '../services/app_state.dart';

// --- 6. AJUSTES (Settings Pro con Nuevas Opciones y Memoria) ---
class SettingsProView extends StatefulWidget {
  const SettingsProView({super.key});
  @override
  State<SettingsProView> createState() => _SettingsProViewState();
}

class _SettingsProViewState extends State<SettingsProView> {
  bool _isLoadingSpotify = false;

  Future<void> _connectToSpotify() async {
    setState(() => _isLoadingSpotify = true);
    try {
      String token = await SpotifySdk.getAccessToken(
        clientId: ApiKeys.spotifyClientId,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "✅ Vinculado a Spotify Premium",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
            "Configuración",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: theme.textTheme.bodyLarge?.color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 25),
          // --- BLOQUE 1.5: TEMA GENERAL DE LA APLICACIÓN ---
          _buildConfigCard(
            context,
            title: "Apariencia del Sistema",
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppState.themeMode,
                  builder: (context, mode, _) =>
                      DropdownButtonFormField<ThemeMode>(
                        value: mode,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: "Modo de Color",
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
                            value: ThemeMode.system,
                            child: Text("Automático (Teléfono)"),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text("Modo Oscuro"),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text("Modo Claro"),
                          ),
                        ],
                        onChanged: (v) {
                          AppState.setTheme(v!);
                          if (AppState.enableHaptics.value)
                            HapticFeedback.selectionClick();
                        },
                      ),
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
                          if (AppState.enableHaptics.value)
                            HapticFeedback.selectionClick();
                        },
                      ),
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              ValueListenableBuilder<bool>(
                valueListenable: AppState.enableHaptics,
                builder: (context, haptics, _) => SwitchListTile(
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
                  activeColor: theme.primaryColor,
                  value: haptics,
                  onChanged: (v) {
                    AppState.setHaptics(v);
                    if (v) HapticFeedback.heavyImpact();
                  },
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              ValueListenableBuilder<bool>(
                valueListenable: AppState.highFidelityAnimations,
                builder: (context, anims, _) => SwitchListTile(
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
                  activeColor: theme.primaryColor,
                  value: anims,
                  onChanged: (v) {
                    AppState.setAnimations(v);
                    if (AppState.enableHaptics.value)
                      HapticFeedback.lightImpact();
                  },
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

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("🌌 Fondo espacial activado"),
                    backgroundColor: theme.primaryColor,
                  ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "🚀 $name estará disponible en la versión 2.0",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: DinobotTheme.primaryBlue,
            ),
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
          padding: const EdgeInsets.only(left: 15, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
