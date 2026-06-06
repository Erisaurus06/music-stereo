import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  // Llaves de Spotify (Dinobot Company)
  static String get spotifyClientId =>
      dotenv.env['SPOTIFY_CLIENT_ID'] ?? "538237e9cc984eed9704d0eab041a56d";
  static String get spotifyClientSecret =>
      dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? "46b4e4a0d8014227990a0f1bad6559f9";

  // Llaves de Genius (Cerebro de Letras)
  static String get geniusClientId =>
      dotenv.env['GENIUS_CLIENT_ID'] ??
      "qJ3tM8d9WSLt0j9Xl4tiwiVwbhKKh-YCNvVkgBFDkrO7-I60BOwbhUN0LANmfXG0";
  static String get geniusClientSecret =>
      dotenv.env['GENIUS_CLIENT_SECRET'] ??
      "j1822A1aRLs3zoY7fkFzgtN1Itt2V7qnTpKvN7gLcgPD4g-6eu8hRRadUMtnreiuEkkK5zJlXbaHK69GgwvGAw";
  static String get geniusToken =>
      dotenv.env['GENIUS_TOKEN'] ??
      "uJSvnurYq2ASqZxVyn1_mzYJ3rLk6-mW3eXmFu0Nxa8jKjLpUPGmEDRUJxlhxDN1";

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? "https://ublqvfmlqppvcpgqyuqh.supabase.co";
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVibHF2Zm1scXBwdmNwZ3F5dXFoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwMjg0MTUsImV4cCI6MjA5MjYwNDQxNX0.sFyhv_T8LAaXwdMd8_RWPIT_cEzKDzz_9MMKB2I7EEI";
}
