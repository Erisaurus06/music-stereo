import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
  // Lista reactiva que la UI observará en tiempo real
  static final ValueNotifier<List<Map<String, dynamic>>> favoriteItems =
      ValueNotifier([]);

  // Carga los favoritos guardados al abrir la app
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favsJson = prefs.getString('tecconnection_favorites');

    if (favsJson != null) {
      List<dynamic> decoded = jsonDecode(favsJson);
      favoriteItems.value = decoded.cast<Map<String, dynamic>>();
    }
  }

  // Agrega o quita un favorito (Sirve para Radio y MP3)
  static Future<void> toggleFavorite(
    String id,
    String title,
    String artist,
    String type, {
    String? url,
    String? imageUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> currentFavs = List.from(
      favoriteItems.value,
    );

    final existingIndex = currentFavs.indexWhere((item) => item['id'] == id);

    if (existingIndex >= 0) {
      currentFavs.removeAt(existingIndex); // Ya era favorito, lo quitamos
    } else {
      currentFavs.add({
        'id': id,
        'title': title,
        'artist': artist,
        'type': type, // 'radio' o 'mp3'
        'url': url ?? '',
        'imageUrl': imageUrl ?? '',
      }); // No era favorito, lo agregamos
    }

    favoriteItems.value = currentFavs;
    await prefs.setString('tecconnection_favorites', jsonEncode(currentFavs));
  }

  // Comprueba si algo ya es favorito (Para pintar el corazón de rojo)
  static bool isFavorite(String id) {
    return favoriteItems.value.any((item) => item['id'] == id);
  }
}
