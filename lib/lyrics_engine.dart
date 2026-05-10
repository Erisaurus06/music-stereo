import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LyricsEngine {
  static get query => null;

  // Ahora pedimos Título y Artista para que la búsqueda sea exacta (como un francotirador)
  static Future<String> buscarCancion(String title, String artist) async {
    try {
      // 1. ELIMINAMOS LA BASURA DE LAS DESCARGAS (Filtro Industrial)
      String cleanTitle = title
          .replaceAll(
            RegExp(
              r'(?i)(y2mate|com|oficial|official|video|audio|lyric|lyrics|128kbps|320kbps|\.mp3|\.flac|\.wav)',
            ),
            '',
          )
          .replaceAll(
            RegExp(r'\[.*?\]|\(.*?\)', dotAll: true),
            '',
          ) // Borra lo que esté entre paréntesis o corchetes (Live Version)
          .trim();

      String cleanArtist = artist.replaceAll(RegExp(r'\(.*\)'), '').trim();
      if (cleanArtist.toLowerCase().contains("desconocido")) cleanArtist = "";

      // 2. Construimos la petición a la red neuronal de Lrclib con los datos limpios
      final response = await http.get(
        Uri.parse('https://api.genius.com/search?q=$query'),
        headers: {
          'Authorization':
              'Bearer ${dotenv.env['GENIUS_TOKEN']!}', // Reemplaza ApiKeys.geniusToken
        },
      );

      // 3. Hacemos la llamada (con un límite de 10 segundos para no trabar la app)
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        if (data.isNotEmpty) {
          // Tomamos el resultado más exacto (el primero de la lista)
          final bestMatch = data[0];

          // PRIORIDAD 1: Letras Sincronizadas (Modo Karaoke Tier 1)
          if (bestMatch['syncedLyrics'] != null &&
              bestMatch['syncedLyrics'].toString().trim().isNotEmpty) {
            return bestMatch['syncedLyrics'];
          }
          // PRIORIDAD 2: Letras de texto plano (Modo Scroll Manual)
          else if (bestMatch['plainLyrics'] != null &&
              bestMatch['plainLyrics'].toString().trim().isNotEmpty) {
            return bestMatch['plainLyrics'];
          }
        }
      }
      return "No se encontraron letras para esta pista.\nIntenta con otra canción.";
    } catch (e) {
      debugPrint("Error buscando letras en la red: $e");
      return "Error de conexión.\nRevisa tu internet e inténtalo de nuevo.";
    }
  }
}
