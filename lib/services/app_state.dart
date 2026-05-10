import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/change_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

// Importamos los modelos que creaste en el paso anterior
import '../models/app_models.dart';

class AppState {
  static late SharedPreferences _prefs;

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.system,
  );

  static final ValueNotifier<double> fontSize = ValueNotifier(22.0);
  static final ValueNotifier<String> artworkStyle = ValueNotifier(
    "Lámpara de Lava (Apple)",
  );
  static final ValueNotifier<bool> mixedPlayback = ValueNotifier(false);

  static final ValueNotifier<AppThemeMode> appThemeMode = ValueNotifier(
    AppThemeMode.chameleon,
  );
  static final ValueNotifier<List<String>> favoriteSongs = ValueNotifier([]);
  static int rachaPomodoro = 0;
  // 🌌 MOTOR DE FONDO GLOBAL (GLASSMORPHISM)
  static final ValueNotifier<String?> backgroundImagePath =
      ValueNotifier<String?>(null);
  static final ValueNotifier<List<String>> favoriteRadios = ValueNotifier([]);

  static final ValueNotifier<List<AppCollection>> myCollections = ValueNotifier(
    [],
  );
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs.getString('themeMode') ?? 'system';
    themeMode.value = savedTheme == 'dark'
        ? ThemeMode.dark
        : (savedTheme == 'light' ? ThemeMode.light : ThemeMode.system);
    fontSize.value = _prefs.getDouble('fontSize') ?? 22.0;
    artworkStyle.value =
        _prefs.getString('artworkStyle') ?? "Lámpara de Lava (Apple)";
    mixedPlayback.value = _prefs.getBool('mixedPlayback') ?? false;
    favoriteSongs.value = _prefs.getStringList('favorites') ?? [];
    favoriteRadios.value = _prefs.getStringList('favorite_radios') ?? [];
    rachaPomodoro = _prefs.getInt('pomodoro_racha') ?? 0;

    final savedAppTheme = _prefs.getString('appThemeMode') ?? 'chameleon';
    if (savedAppTheme == 'defaultBlue')
      appThemeMode.value = AppThemeMode.defaultBlue;
    else if (savedAppTheme == 'lavaLamp')
      appThemeMode.value = AppThemeMode.lavaLamp;
    else
      appThemeMode.value = AppThemeMode.chameleon;

    final String? collectionsJson = _prefs.getString('my_collections');
    if (collectionsJson != null) {
      final List<dynamic> decoded = json.decode(collectionsJson);
      myCollections.value = decoded
          .map((e) => AppCollection.fromJson(e))
          .toList();
    }
  }

  static void setTheme(ThemeMode mode) {
    themeMode.value = mode;
    _prefs.setString('themeMode', mode.toString().split('.').last);
    sincronizarConNube();
  }

  static void setFontSize(double size) {
    fontSize.value = size;
    _prefs.setDouble('fontSize', size);
    sincronizarConNube();
  }

  static void setArtworkStyle(String style) {
    artworkStyle.value = style;
    _prefs.setString('artworkStyle', style);
    sincronizarConNube();
  }

  static void setAppThemeMode(AppThemeMode mode) {
    appThemeMode.value = mode;
    _prefs.setString('appThemeMode', mode.toString().split('.').last);
    sincronizarConNube();
  }

  static void toggleFavorite(String songId) {
    final list = List<String>.from(favoriteSongs.value);
    if (list.contains(songId))
      list.remove(songId);
    else
      list.add(songId);
    favoriteSongs.value = list;
    _prefs.setStringList('favorites', list);
    sincronizarConNube();
  }

  static void updatePomodoroRacha(int racha) {
    rachaPomodoro = racha;
    _prefs.setInt('pomodoro_racha', racha);
    sincronizarConNube();
  }

  static void addCollection(AppCollection collection) {
    final list = List<AppCollection>.from(myCollections.value)..add(collection);
    myCollections.value = list;
    _prefs.setString(
      'my_collections',
      json.encode(list.map((e) => e.toJson()).toList()),
    );
    sincronizarConNube();
  }

  // ✨ NUEVO: FUNCIÓN PARA ACTUALIZAR UNA PLAYLIST (AGREGAR/QUITAR TRACKS)
  static void updateCollection(AppCollection updatedCollection) {
    final list = List<AppCollection>.from(myCollections.value);
    final index = list.indexWhere((c) => c.id == updatedCollection.id);
    if (index != -1) {
      list[index] = updatedCollection;
      myCollections.value = list;
      _prefs.setString(
        'my_collections',
        json.encode(list.map((e) => e.toJson()).toList()),
      );
      sincronizarConNube();
    }
  }

  static Future<void> sincronizarConNube() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'font_size': fontSize.value,
        'artwork_style': artworkStyle.value,
        'theme_mode': themeMode.value.toString(),
        'favorites': favoriteSongs.value,
        'favorite_radios': favoriteRadios.value, // <- Agrega esta línea
        'pomodoro_racha': rachaPomodoro,
        'collections_json': json.encode(
          myCollections.value.map((e) => e.toJson()).toList(),
        ),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("❌ Error Sync: $e");
    }
  }

  // ✨ NUEVAS OPCIONES PRO
  static final ValueNotifier<String> playerLayout = ValueNotifier(
    "Cristal Inmersivo",
  );
  static final ValueNotifier<bool> enableHaptics = ValueNotifier(true);
  static final ValueNotifier<bool> highFidelityAnimations = ValueNotifier(true);

  // ✨ GUARDADO DE NUEVAS OPCIONES
  static void setPlayerLayout(String layout) {
    playerLayout.value = layout;
    _prefs.setString('playerLayout', layout);
    sincronizarConNube();
  }

  static void setHaptics(bool val) {
    enableHaptics.value = val;
    _prefs.setBool('enableHaptics', val);
    sincronizarConNube();
  }

  static void setAnimations(bool val) {
    highFidelityAnimations.value = val;
    _prefs.setBool('highFidelityAnimations', val);
    sincronizarConNube();
  } // ✨ LÓGICA PARA GUARDAR/QUITAR CANCIONES FAVORITAS

  static void toggleFavoriteSong(String songId) {
    final list = List<String>.from(favoriteSongs.value);
    if (list.contains(songId)) {
      list.remove(songId);
    } else {
      list.add(songId);
    }
    favoriteSongs.value = list;
    _prefs.setStringList('favorites', list);
    sincronizarConNube();
  }

  // ✨ LÓGICA PARA GUARDAR/QUITAR RADIOS FAVORITAS
  static void toggleFavoriteRadio(String radioTitle) {
    final list = List<String>.from(favoriteRadios.value);
    if (list.contains(radioTitle)) {
      list.remove(radioTitle);
    } else {
      list.add(radioTitle);
    }
    favoriteRadios.value = list;
    _prefs.setStringList('favorite_radios', list);
  }
} // <--- ¡ESTA ES LA LLAVE MÁGICA QUE FALTABA! Cierra la clase AppState.

class DinobotTheme {
  static const Color primaryBlue = Color(0xFF2979FF);

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: const Color(0xFFF5F5F7),
    cardColor: Colors.white,
    dividerColor: Colors.black12,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
      bodySmall: TextStyle(color: Colors.black38),
    ),
    fontFamily: 'Roboto',
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: const Color(0xFF09090B),
    cardColor: const Color(0xFF141416),
    dividerColor: Colors.white10,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white54),
    ),
    fontFamily: 'Roboto',
  );
}
