# Music Stereo

¡Bienvenido a **Music Stereo**! Una aplicación musical hiper-personalizable de vanguardia construida con Flutter. 

A diferencia de los reproductores convencionales, esta app unifica tus **archivos MP3 locales**, **emisoras de radio globales** y tu cuenta de **Spotify Premium** bajo una sola interfaz inmersiva. Además, trasciende el entretenimiento integrando un **Motor Pomodoro** para la productividad y un ecosistema de **Letras Dinámicas** (Karaoke sincronizado).

## 🌟 ¿De qué trata la App?
Music Stereo está diseñada como una estación de concentración y entretenimiento absoluto. Su enfoque principal es brindar una **Experiencia de Usuario (UX) Premium** mediante un diseño *Edge-to-Edge* (sin bordes) que fluye por toda la pantalla de tu dispositivo. 

Puedes estudiar escuchando radios Lo-Fi guardando tu progreso en la nube (Supabase), o cambiar a modo fiesta escuchando tus MP3 locales con las letras sincronizadas línea por línea al puro estilo de Apple Music.

## ✨ Funcionalidades Únicas y UX Inmersivo
El proyecto fue diseñado prestando atención maniática a la interacción humana:

* 🎛️ **Crossfade de Alta Fidelidad (Curvas Equal-Power):** Al cambiar de una canción a otra, el motor usa cálculos trigonométricos (`Math.sin` y `Math.cos`) para hacer una transición donde el volumen cruza de manera impecable, simulando una mesa de mezclas profesional.
* 🦎 **El Camaleón Visual:** Gracias a `palette_generator`, la interfaz entera (fondos, botones y barra de notificaciones) extrae los colores dominantes de la carátula actual y muta. Además, incluye un *Override* manual para que el usuario fuerce temas estáticos (Rojo, Morado, Verde, etc.).
* 📱 **Notificaciones Nativas Enriquecidas:** El reproductor se ancla a la barra de estado de Android 13+ (`just_audio_background`) extrayendo la portada, cambiando el fondo dinámicamente y usando **Iconos Vectoriales (.xml)** diseñados a medida.
* 🍅 **Pomodoro Cloud-Synced:** Un temporizador de productividad que interrumpe gentilmente con notificaciones push (alta prioridad) y guarda tus estadísticas de estudio en tiempo real en una base de datos de **Supabase**.
* 📳 **Haptics Táctiles Premium:** Uso intensivo de `HapticFeedback` para simular la resistencia mecánica de botones reales al tocar controles o reordenar listas.

## ⚙️ ¿Cómo funciona?
El núcleo de la aplicación recae sobre un gestor central de arquitectura limpia (`PlayerManager`) que permite intercalar de forma totalmente transparente entre diferentes "Motores" (Engines) de audio:
* 💾 **Motor Local (`AudioEngineType.local`):** Escanea automáticamente el almacenamiento buscando `.mp3`, leyendo etiquetas ID3 (`on_audio_query` / `audiotagger`).
* 📻 **Motor de Radio (`AudioEngineType.radio`):** Consume APIs globales para miles de emisoras en directo. (¡Las favoritas se sincronizan en la nube!).
* 🟢 **Motor Spotify (`AudioEngineType.spotify`):** Controla de forma nativa la app de Spotify por medio de Broadcast Intents.
* 🎤 **Letras Dinámicas (`LyricsEngine`):** Intercepta la metadata actual y extrae fracciones de tiempo LRC (`[00:15.22]`) dibujando las letras sobre un lienzo de `flutter_lyric`.

## 🛠️ Herramientas y Tecnologías Utilizadas

### Framework y Lenguaje
* **Flutter SDK:** `^3.11.4` (Diseño Edge-to-Edge Android 15 ready).
* **Dart:** `3.x`

### Backend & Cloud Services
* **Supabase (`supabase_flutter`):** Base de datos PostgreSQL en tiempo real para respaldar perfiles, emisoras favoritas y telemetría del Pomodoro.
* **Firebase (`firebase_core`, `crashlytics`, `messaging`):** Captura de errores fatales remotos y recepción de alertas Push.

### Motores de Audio y Archivos
* `just_audio` + `just_audio_background`: Manejo de búfer de audio, ecualización y servicio en segundo plano (Wake Locks).
* `spotify_sdk`: Wrapper nativo para autenticación e inyección remota.
* `on_audio_query` & `audiotagger`: Lectura y escritura de metadatos locales (Portadas, Títulos, Álbumes).
* `path_provider` & `record`: Para funciones de grabación en caché.

### UI, Gráficos y Sistema
* `palette_generator`: Procesamiento de imágenes para extracción de colores dominantes.
* `flutter_lyric`: Lienzo interactivo de letras Netease.
* `interactive_slider` & `perfect_volume_control`: Manipulación directa de los canales de hardware del teléfono.
* `flutter_local_notifications`: Disparador de alarmas locales con vibración háptica al finalizar un Pomodoro.
* `permission_handler`: Puente nativo para requerir permisos granulares en Android 13+ (Almacenamiento y Notificaciones).

---

## 🚀 Guía de Instalación y Despliegue
Sigue estos pasos rigurosos para levantar el proyecto localmente sin errores:

### 1. Clonar el repositorio y dependencias
```bash
git clone https://github.com/tu_usuario/music_stereo.git
cd music_stereo
flutter pub get
```

### 2. Configurar Variables de Entorno (Obligatorio)
Crea un archivo llamado `.env` en la raíz del proyecto (junto a `pubspec.yaml`) e inyecta tus llaves maestras:
```env
SUPABASE_URL=tu_url_del_proyecto_supabase
SUPABASE_ANON_KEY=tu_anon_key_de_supabase
SPOTIFY_CLIENT_ID=tu_cliente_id_de_spotify_developer
GENIUS_TOKEN=tu_token_de_la_api_de_genius
```

### 3. Configurar Firebase (Google Services)
Para que el motor de notificaciones Push (FCM) y Crashlytics compilen, debes:
1. Ir a la Consola de Firebase y registrar un proyecto Android con tu nombre de paquete.
2. Descargar el archivo `google-services.json`.
3. Pegarlo en la ruta exacta: `android/app/google-services.json`.

### 4. Compilación en Entorno de Desarrollo (Debug)
Conecta tu teléfono físico (Recomendado para probar audios y haptics) o un emulador:
```bash
flutter run
```

### 5. ⚠️ Compilación para Producción (Release APK)
Si vas a construir el instalador final, Android activará el modo R8/ProGuard que ofusca el código. Para evitar que el reproductor en segundo plano se rompa, asegúrate de que el archivo `android/app/proguard-rules.pro` contenga las reglas estipuladas para `just_audio` y `spotify_sdk`.

Para generar el APK:
```bash
flutter build apk --release
```
El archivo resultante estará en: `build/app/outputs/flutter-apk/app-release.apk`