import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

class LyricsEngine {
  // Función principal a la que llamará nuestra UI
  static Future<String> fetchLyrics(String title, String artist) async {
    try {
      final token = dotenv.env['GENIUS_TOKEN'];
      if (token != null && token.isNotEmpty) {
        // 1. Buscar la canción en la API de Genius
        final query = Uri.encodeComponent('$title $artist');
        final searchUrl = Uri.parse("https://api.genius.com/search?q=$query");

        final response = await http.get(
          searchUrl,
          headers: {"Authorization": "Bearer $token"},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final hits = data['response']?['hits'] as List?;

          if (hits != null && hits.isNotEmpty) {
            // Tomamos el enlace de la primera coincidencia
            final songUrl = hits[0]['result']?['url'];
            if (songUrl != null) {
              // 2. Extraemos la letra real de la página
              final lyrics = await _scrapeLyrics(songUrl);
              if (lyrics != null && lyrics.isNotEmpty) {
                return lyrics;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error buscando letra en Genius: $e");
    }

    // ✨ PLAN B: Si Genius falló, no tiene token o la estructura web cambió
    debugPrint(
      "⚠️ Genius falló o no encontró la letra. Usando Plan B (lyrics.ovh)...",
    );
    return await _fetchFallbackLyrics(title, artist);
  }

  // Scraper interno porque la API de Genius no devuelve la letra directamente
  static Future<String?> _scrapeLyrics(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        // Genius guarda las letras en estos contenedores especiales
        final lyricsContainers = document.querySelectorAll(
          '[data-lyrics-container="true"]',
        );

        if (lyricsContainers.isNotEmpty) {
          String lyrics = "";
          for (var container in lyricsContainers) {
            // Convertimos los <br> de HTML en saltos de línea reales de Dart
            container.innerHtml = container.innerHtml.replaceAll('<br>', '\n');
            lyrics += "${container.text}\n\n";
          }
          return lyrics.trim();
        }
      }
    } catch (e) {
      debugPrint("Error extrayendo letra de Genius: $e");
    }
    return null; // Retorna null para que el Plan B entre en acción
  }

  // ✨ NUEVO: Plan B usando la API pública gratuita de lyrics.ovh
  static Future<String> _fetchFallbackLyrics(
    String title,
    String artist,
  ) async {
    try {
      // Limpiamos el título y artista de textos extraños como "(feat. X)" o "[Remix]"
      final cleanTitle = title
          .replaceAll(RegExp(r'\(.*\)'), '')
          .replaceAll(RegExp(r'\[.*\]'), '')
          .trim();
      final cleanArtist = artist.replaceAll(RegExp(r'\(.*\)'), '').trim();

      final url = Uri.parse(
        "https://api.lyrics.ovh/v1/$cleanArtist/$cleanTitle",
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lyrics = data['lyrics'];
        if (lyrics != null && lyrics.toString().trim().isNotEmpty) {
          return lyrics.toString().trim();
        }
      }
      return "No se encontraron letras para esta canción. 🎵";
    } catch (e) {
      debugPrint("Error en Plan B (lyrics.ovh): $e");
      return "Error de conexión al buscar la letra. Revisa tu internet.";
    }
  }
}
