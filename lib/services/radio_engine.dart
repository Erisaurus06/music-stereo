import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 📻 EL MOLDE DE UNA ESTACIÓN DE RADIO
class RadioStation {
  final String id;
  final String name;
  final String url;
  final String favicon;
  final String tags;
  final String country;

  RadioStation({
    required this.id,
    required this.name,
    required this.url,
    required this.favicon,
    required this.tags,
    required this.country,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['stationuuid'] ?? '',
      name: json['name'] ?? 'Radio Desconocida',
      url: json['url_resolved'] ?? json['url'] ?? '',
      favicon: json['favicon'] ?? '',
      tags: json['tags'] ?? '',
      country: json['country'] ?? '',
    );
  }

  Object? toJson() {}
}

// 📡 LA ANTENA RECEPTORA (SE CONECTA A INTERNET)
class RadioEngine {
  // Usamos el servidor principal de la API pública
  static const String _baseUrl =
      "https://de1.api.radio-browser.info/json/stations/search";

  // Busca las estaciones más populares (Puedes pedirle "phonk", "jazz", "anime", etc.)
  static Future<List<RadioStation>> getTopStations({
    int limit = 20,
    String tag = "",
    String country = "",
  }) async {
    try {
      String url =
          "$_baseUrl?limit=$limit&hidebroken=true&order=clickcount&reverse=true";
      if (tag.isNotEmpty) url += "&tag=${Uri.encodeComponent(tag)}";
      if (country.isNotEmpty) url += "&country=${Uri.encodeComponent(country)}";

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => RadioStation.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("📡 Error sintonizando la radio: $e");
    }
    return [];
  }

  // Busca estaciones por nombre (ej. "Los 40", "Alfa", "Radio Sakura")
  static Future<List<RadioStation>> searchStations(String query) async {
    try {
      final url =
          "$_baseUrl?name=${Uri.encodeComponent(query)}&limit=20&hidebroken=true&order=clickcount&reverse=true";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => RadioStation.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("📡 Error buscando estaciones: $e");
    }
    return [];
  }
}
