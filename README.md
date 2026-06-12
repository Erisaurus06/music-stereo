# TecConnection Hub (Music Stereo) 🎵

¡Bienvenido a **TecConnection Hub**! Una aplicación musical de vanguardia construida con Flutter que unifica tus archivos MP3 locales, emisoras de radio globales y tu cuenta de Spotify Premium en un solo ecosistema. Además, integra herramientas de productividad como un temporizador Pomodoro y visualización dinámica de letras de canciones (Karaoke sincronizado).

## 🌟 ¿De qué trata la App?
TecConnection Hub no es solo un reproductor multimedia; funciona también como una estación de concentración para estudio/trabajo gracias a su **Pomodoro Engine**, y como centro de entretenimiento gracias a su motor de **Letras Dinámicas** obtenidas en tiempo real desde plataformas como LRCLIB y Genius. Su enfoque principal es brindar una experiencia de usuario (UX) inmersiva, elegante y altamente personalizable.

## ⚙️ ¿Cómo funciona?
El núcleo de la aplicación recae sobre un gestor central de arquitectura limpia (`PlayerManager`) que permite intercalar de forma totalmente transparente entre diferentes "Motores" (Engines) de audio:
1. **Motor Local (`AudioEngineType.local`):** Escanea automáticamente el almacenamiento de tu dispositivo buscando archivos `.mp3` y los reproduce en alta calidad.
2. **Motor de Radio (`AudioEngineType.radio`):** Se conecta a APIs web y extrae miles de emisoras de radio alrededor del mundo, reproduciéndolas en directo.
3. **Motor Spotify (`AudioEngineType.spotify`):** Vincula y controla de forma nativa la aplicación de Spotify instalada en tu teléfono.
4. **Letras Sincronizadas (`LyricsEngine`):** Intercepta la canción actual y extrae el texto puro o las métricas de tiempo (`[00:12.33]`) para animar un Karaoke usando el widget de `flutter_lyric`.

## 🛠️ Lenguaje y Tecnologías Principales
* **Lenguaje Principal:** Dart
* **Framework:** Flutter (Diseñado con UI Edge-to-Edge inmersiva para Android 15+)
* **Backend & Nube:** 
  * **Supabase:** Base de datos en la nube (guarda estadísticas del Pomodoro, sesiones de usuario y antenas de radio favoritas).
  * **Firebase:** Servicios de Crashlytics para telemetría, Analytics y Mensajería Push (FCM).

## 📦 Librerías e Importaciones Clave
La aplicación aprovecha las herramientas más profesionales del ecosistema de pub.dev:

* **Audio y Media:**
  * `just_audio` & `just_audio_background`: Reproducción sólida con notificaciones persistentes en la barra de estado y controles Bluetooth.
  * `spotify_sdk`: Interfaz de comunicación con Spotify.
  * `on_audio_query`: Motor profundo para explorar metadatos, álbumes y canciones del disco duro.
* **Estado y Base de Datos:**
  * `flutter_riverpod`: Manejo de estado reactivo (State Management).
  * `supabase_flutter`: Cliente oficial de Supabase.
  * `shared_preferences`: Memoria persistente para funcionamiento en modo avión (Offline).
* **UI e Interfaz:**
  * `flutter_lyric`: Motor gráfico que dibuja las letras en formato Netease.
  * `palette_generator`: Algoritmo que lee los píxeles de una carátula y extrae sus colores predominantes.
  * `blurrycontainer`: Efectos de cristal esmerilado (Glassmorphism).
  * `interactive_slider` & `perfect_volume_control`: Manipulación customizada del reproductor y el sonido maestro del celular.
* **Utilidades del Sistema:**
  * `permission_handler`: Motor dinámico para solicitar permisos en Android 13+.
  * `flutter_local_notifications` & `firebase_messaging`: Alertas enriquecidas con sonidos y prioridades "Max".
  * `flutter_dotenv`: Ocultación y protección de API Keys (`.env`).

## ✨ Herramientas de Animación y UX Inmersivo
El proyecto fue diseñado prestando atención maníaca a la interacción humana:
* **Crossfade (Curvas Equal-Power):** Al cambiar de una canción local a otra, no hay cortes de sonido crudos. Se usa un sistema matemático (`Math.sin` y `Math.cos`) para subir una pista y bajar la otra imperceptiblemente creando transiciones dignas de estudio de grabación.
* **Camaleón Visual:** A través de un `ValueListenableBuilder` global y la librería `palette_generator`, los colores de toda la interfaz, botones y los íconos de la barra de estado (blanco/negro) mutan dependiendo de la portada de la canción o de la emisora actual.
* **Haptics Táctiles Premium:** Integración de la clase `HapticFeedback` nativa de Flutter, programada para detonar en cada interacción (heavy impact para Play/Pausa, light impact en botones), simulando la botonera de un estéreo real.
* **Animaciones Explícitas a 60FPS:** Usa escuchadores (`ValueNotifier`) para evitar re-dibujados en todo el árbol de Widgets. Solo se mueven las piezas y barras necesarias con un coste de CPU extremadamente bajo.

## 🚀 Instalación y Despliegue
Sigue estos pasos para compilar la aplicación de forma local:

1. **Clona el repositorio** en tu máquina local.
2. **Verifica tu entorno:** Asegúrate de tener el SDK de Flutter (`^3.11.4` o superior) instalado y corriendo en `flutter doctor`.
3. **Instala las dependencias:** Ubícate en la raíz del proyecto y ejecuta:
   ```bash
   flutter pub get
   ```
4. **Configura tus variables de entorno (`.env`):**
   Crea un archivo llamado `.env` en la raíz del proyecto (al lado de `pubspec.yaml`) y llénalo con tus credenciales:
   ```env
   SUPABASE_URL=tu_url_del_proyecto_supabase
   SUPABASE_ANON_KEY=tu_anon_key_de_supabase
   SPOTIFY_CLIENT_ID=tu_cliente_id_de_spotify_developer
   GENIUS_TOKEN=tu_token_de_la_api_de_genius
   ```
5. **Vincula Firebase (Crashlytics / Push):**
   Para que FCM compile correctamente, recuerda haber generado y añadido el archivo `google-services.json` para Android dentro de `android/app/`.
6. **Compila en el dispositivo:**
   Conecta tu teléfono (recomendado) o enciende un emulador y ejecuta:
   ```bash
   flutter run
   ```
   *(Opcional) Si quieres compilar el APK de producción:*
   ```bash
   flutter build apk --release
   ```