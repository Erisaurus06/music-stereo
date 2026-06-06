import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ArtworkEngine {
  // Memoria interna para no repetir búsquedas y gastar internet
  static final Map<String, String> _cache = {};

  static Future<String?> buscarPortada(String title, String artist) async {
    // Si la canción no tiene artista o se llama "Desconocido", ignoramos
    if (artist.toLowerCase().contains("desconocido") || artist.isEmpty) {
      return null;
    }

    final query = "$title $artist".toLowerCase().trim();

    // Si ya la buscamos antes en esta sesión, regresamos la guardada
    if (_cache.containsKey(query)) return _cache[query];

    try {
      // Limpiamos la basura del título para que Apple Music lo encuentre fácil
      final cleanTitle = title
          .replaceAll(RegExp(r'\(.*\)'), '')
          .replaceAll(RegExp(r'\[.*\]'), '')
          .trim();
      final cleanArtist = artist.replaceAll(RegExp(r'\(.*\)'), '').trim();

      final url = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent("$cleanTitle $cleanArtist")}&entity=song&limit=1',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['resultCount'] != null &&
            data['resultCount'] > 0 &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          // El hack de Apple Music: Cambiamos 100x100 por 800x800 para calidad 4K
          String? imgUrl = data['results'][0]['artworkUrl100'];
          if (imgUrl != null) {
            imgUrl = imgUrl.replaceAll('100x100bb', '800x800bb');

            _cache[query] = imgUrl; // Guardamos en memoria
            return imgUrl;
          }
        }
      }
    } catch (e) {
      debugPrint("El Detective falló buscando la portada: $e");
    }
    return null;
  }
}
