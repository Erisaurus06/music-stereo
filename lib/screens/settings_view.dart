import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import '../services/player_manager.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ValueListenableBuilder<Color>(
        valueListenable: PlayerManager.currentThemeColor,
        builder: (context, themeColor, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ✨ APPBAR INMERSIVO
              SliverAppBar(
                expandedHeight: 120,
                backgroundColor: theme.scaffoldBackgroundColor,
                pinned: true,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  title: Text(
                    "Ajustes",
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              // ✨ CONTENIDO PRINCIPAL CON FLUJO EDGE-TO-EDGE
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  bottomPadding > 0 ? bottomPadding + 100 : 120,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader("Visuales", themeColor),
                    _buildColorPaletteCard(theme, themeColor),
                    const SizedBox(height: 15),
                    _buildCardGroup(theme, [
                      _buildSwitchTile(
                        title: "Animaciones de Alta Fidelidad",
                        subtitle: "Transiciones y crossfades más fluidos.",
                        icon: Icons.animation_rounded,
                        notifier: AppState.highFidelityAnimations,
                        onChanged: (v) => AppState.setAnimations(v),
                        activeColor: themeColor,
                      ),
                    ]),

                    const SizedBox(height: 30),
                    _buildSectionHeader("Audio y Experiencia", themeColor),
                    _buildCardGroup(theme, [
                      _buildSwitchTile(
                        title: "Respuesta Táctil (Haptics)",
                        subtitle: "Vibraciones inmersivas al interactuar.",
                        icon: Icons.vibration_rounded,
                        notifier: AppState.enableHaptics,
                        onChanged: (v) => AppState.setHaptics(v),
                        activeColor: themeColor,
                      ),
                    ]),

                    const SizedBox(height: 30),
                    _buildSectionHeader("Seguridad", themeColor),
                    _buildCardGroup(theme, [
                      _buildSwitchTile(
                        title: "Bloqueo Biométrico",
                        subtitle: "Protege la app con huella o rostro.",
                        icon: Icons.fingerprint_rounded,
                        notifier: AppState.biometricLockEnabled,
                        onChanged: (v) => AppState.setBiometricLock(v),
                        activeColor: themeColor,
                      ),
                    ]),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: themeColor,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCardGroup(ThemeData theme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required ValueNotifier<bool> notifier,
    required Function(bool) onChanged,
    required Color activeColor,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, value, _) {
        return SwitchListTile.adaptive(
          value: value,
          activeColor: activeColor,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          secondary: Icon(icon, color: value ? activeColor : Colors.grey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onChanged: (val) {
            HapticFeedback.lightImpact(); // ✨ Reacción táctil inmediata
            onChanged(val);
          },
        );
      },
    );
  }

  Widget _buildColorPaletteCard(ThemeData theme, Color themeColor) {
    final List<Map<String, dynamic>> colors = [
      {'name': 'Auto', 'color': null, 'icon': Icons.auto_awesome_rounded},
      {'name': 'Rojo', 'color': Colors.redAccent},
      {'name': 'Azul', 'color': Colors.blueAccent},
      {'name': 'Verde', 'color': Colors.greenAccent},
      {'name': 'Morado', 'color': Colors.deepPurpleAccent},
      {
        'name': 'OLED',
        'color': const Color(0xFF222222),
      }, // Negro brillante (Gris oscuro)
    ];

    return _buildCardGroup(theme, [
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tema de Acento",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 5),
            const Text(
              "Elige un color fijo o usa el Camaleón Inteligente.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<Color?>(
              valueListenable: PlayerManager.manualThemeColor,
              builder: (context, manualColor, _) {
                return Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: colors.map((item) {
                    final isSelected = manualColor == item['color'];
                    final isAuto = item['color'] == null;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        PlayerManager.setManualThemeColor(item['color']);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isAuto
                              ? theme.scaffoldBackgroundColor
                              : item['color'],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? themeColor
                                : (isAuto
                                      ? theme.dividerColor
                                      : Colors.transparent),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected && !isAuto
                              ? [
                                  BoxShadow(
                                    color: (item['color'] as Color).withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          isAuto
                              ? Icons.auto_awesome_rounded
                              : (isSelected ? Icons.check_rounded : null),
                          color: isAuto
                              ? theme.textTheme.bodyLarge?.color
                              : Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    ]);
  }
}
