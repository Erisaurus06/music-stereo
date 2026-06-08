import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

class LyricsEngine {
  // Función principal a la que llamará nuestra UI
  static Future<String> fetchLyrics(String title, String artist) async {
    final cleanTitle = title
        .replaceAll(RegExp(r'\(.*\)'), '')
        .replaceAll(RegExp(r'\[.*\]'), '')
        .trim();
    String cleanArtist = artist.replaceAll(RegExp(r'\(.*\)'), '').trim();

    // ✨ SOLUCIÓN 1: Evitar buscar a la banda "Desconocido"
    if (cleanArtist.toLowerCase().contains("desconocido") ||
        cleanArtist.toLowerCase().contains("unknown")) {
      cleanArtist = "";
    }

    // ✨ PLAN A: LRCLIB (El único que proporciona letras SINCRONIZADAS para animar)
    try {
      debugPrint("Buscando letra sincronizada en LRCLIB para: $cleanTitle");
      final lrclibUrl = Uri.parse(
        "https://lrclib.net/api/search?q=${Uri.encodeComponent('$cleanTitle $cleanArtist'.trim())}",
      );

      // ✨ SOLUCIÓN 2: Añadir User-Agent obligatorio para que LRCLIB no bloquee la conexión
      final response = await http
          .get(
            lrclibUrl,
            headers: {
              'User-Agent':
                  'TecConnection_MusicApp/1.0.0 (https://github.com/tuusuario)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          // Buscamos primero la versión sincronizada para tu animación
          final syncedLyrics = data[0]['syncedLyrics'];
          if (syncedLyrics != null &&
              syncedLyrics.toString().trim().isNotEmpty) {
            return syncedLyrics; // ¡Éxito! Retorna formato [00:12.33]
          }
          // Si no hay sincronizada, devolvemos texto plano de LRCLIB
          final plainLyrics = data[0]['plainLyrics'];
          if (plainLyrics != null && plainLyrics.toString().trim().isNotEmpty) {
            return plainLyrics;
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ LRCLIB falló: $e");
    }

    // ✨ PLAN B: Genius (Solo texto plano estático)
    try {
      final token = dotenv.env['GENIUS_TOKEN'];
      if (token != null && token.isNotEmpty) {
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

    // ✨ PLAN C: Si Genius falló, usamos lyrics.ovh
    debugPrint("⚠️ Genius también falló. Usando Plan C (lyrics.ovh)...");
    return await _fetchFallbackLyrics(cleanTitle, cleanArtist);
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

  // ✨ PLAN C usando la API pública gratuita de lyrics.ovh
  static Future<String> _fetchFallbackLyrics(
    String cleanTitle,
    String cleanArtist,
  ) async {
    try {
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
