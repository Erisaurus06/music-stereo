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
      if (token == null || token.isEmpty)
        return "⚠️ Error: Token de Genius no configurado en .env";

      // 1. Buscar la canción en la API de Genius
      final query = Uri.encodeComponent('$title $artist');
      final searchUrl = Uri.parse("https://api.genius.com/search?q=$query");

      final response = await http.get(
        searchUrl,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hits = data['response']['hits'] as List;

        if (hits.isNotEmpty) {
          // Tomamos el enlace de la primera coincidencia
          final songUrl = hits[0]['result']['url'];
          // 2. Extraemos la letra real de la página
          return await _scrapeLyrics(songUrl);
        }
      }
      return "No se encontraron letras para esta canción. 🎵";
    } catch (e) {
      debugPrint("Error buscando letra: $e");
      return "Error de conexión al buscar la letra. Revisa tu internet.";
    }
  }

  // Scraper interno porque la API de Genius no devuelve la letra directamente
  static Future<String> _scrapeLyrics(String url) async {
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
      return "No se pudo leer la letra de la página.";
    } catch (e) {
      return "Error extrayendo la letra.";
    }
  }
}
