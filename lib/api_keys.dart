import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  // Llaves de Spotify (Dinobot Company)
  static String get spotifyClientId => dotenv.env['SPOTIFY_CLIENT_ID'] ?? "";
  static String get spotifyClientSecret =>
      dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? "";

  // Llaves de Genius (Cerebro de Letras)
  static String get geniusClientId => dotenv.env['GENIUS_CLIENT_ID'] ?? "";
  static String get geniusClientSecret =>
      dotenv.env['GENIUS_CLIENT_SECRET'] ?? "";
  static String get geniusToken => dotenv.env['GENIUS_TOKEN'] ?? "";

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? "";
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? "";
}
