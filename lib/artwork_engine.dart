import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ArtworkEngine {
  // Memoria interna para no repetir búsquedas y gastar internet
  static final Map<String, String> _cache = {};

  static Future<String?> buscarPortada(String title, String artist) async {
    // 🍂 VERSIÓN LITE: Desactivamos el "Detective" de Apple Music.
    // Ahorraremos muchísimos datos móviles al no descargar imágenes de 800x800.
    // Solo usaremos las carátulas que ya vengan incrustadas en el MP3 localmente.
    return null;
  }
}
