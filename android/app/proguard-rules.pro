# Proteger las clases del SDK de Spotify
-keep class com.spotify.** { *; }
-dontwarn com.spotify.**

# Proteger Jackson (La librería que usa Spotify para leer datos)
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**