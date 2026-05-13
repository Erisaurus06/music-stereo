import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
  // Notificador reactivo para que el corazón cambie de color al instante
  static final ValueNotifier<List<Map<String, dynamic>>> favoriteItems =
      ValueNotifier([]);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favsJson = prefs.getString('favorites_data');
    if (favsJson != null) {
      favoriteItems.value = List<Map<String, dynamic>>.from(
        json.decode(favsJson),
      );
    }
  }

  static bool isFavorite(String id) {
    return favoriteItems.value.any((item) => item['id'] == id);
  }

  static Future<void> toggleFavorite(
    String id,
    String title,
    String artist,
    String engineType,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final currentList = List<Map<String, dynamic>>.from(favoriteItems.value);

    if (isFavorite(id)) {
      currentList.removeWhere((item) => item['id'] == id);
    } else {
      currentList.add({
        'id': id,
        'title': title,
        'artist': artist,
        'engine': engineType, // Sabe si es de Spotify, Local o Radio
      });
    }

    favoriteItems.value = currentList; // Actualiza la UI
    await prefs.setString(
      'favorites_data',
      json.encode(currentList),
    ); // Guarda en el celular
  }
}
