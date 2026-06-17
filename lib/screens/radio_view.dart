import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_stereo/services/radio_engine.dart';
import '../services/app_state.dart';
import '../services/player_manager.dart';
import '../models/app_models.dart';
import '../widgets/design_components.dart';
import '../services/network_radar.dart';

// --- 📻 VISTA DE RADIO GLOBAL (CON FAVORITOS PERMANENTES) ---
class RadioView extends StatefulWidget {
  const RadioView({super.key});

  @override
  State<RadioView> createState() => _RadioViewState();
}

class _RadioViewState extends State<RadioView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> searchQuery = ValueNotifier("");

  // Búsquedas temporales de la API
  List<RadioStation> _apiStations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // ✨ 3 Pestañas
    _cargarRadios(); // Carga las top al iniciar
  }

  Future<void> _cargarRadios([String query = ""]) async {
    setState(() => _isLoading = true);
    try {
      if (query.isEmpty) {
        _apiStations = await RadioEngine.getTopStations();
      } else {
        _apiStations = await RadioEngine.searchStations(query);
      }
    } catch (e) {
      debugPrint("Error al buscar emisoras de radio: $e");
      _apiStations = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // ✨ Lógica de espaciado dinámica e infalible (Estilo iOS)
    // Deja espacio para el minireproductor, margen del sistema y el teclado virtual.
    final double listBottomSpace =
        120.0 + (bottomPadding > 0 ? bottomPadding : 20.0) + keyboardHeight;

    return SafeArea(
      bottom:
          false, // ✨ Permitimos que la lista llegue hasta abajo (Edge-to-Edge)
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 840,
          ), // ✨ Diseño adaptable para Mac/PC/Web
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  "Radio Global",
                  style: TextStyle(
                    fontWeight: FontWeight.w800, // ✨ Tipografía más elegante
                    fontSize: 38,
                    color: theme.textTheme.bodyLarge?.color,
                    letterSpacing: -1.2,
                  ),
                ),
              ),

              // 🔎 BARRA DE BÚSQUEDA CONECTADA A LA API
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 5,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(
                      12,
                    ), // ✨ iOS: Bordes más sutiles para barras de búsqueda
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (val) {
                      searchQuery.value = val;
                      _cargarRadios(val); // ✨ Busca en internet al darle Enter
                    },
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      hintText: "Buscar emisora y presiona Enter...",
                      hintStyle: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: Icon(
                        Icons.satellite_alt_rounded,
                        color: theme.primaryColor,
                      ),
                      suffixIcon: ValueListenableBuilder<String>(
                        valueListenable: searchQuery,
                        builder: (context, query, _) {
                          return query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    searchQuery.value = "";
                                    FocusScope.of(context).unfocus();
                                    _cargarRadios(); // Recarga las top
                                  },
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              TabBar(
                controller: _tabController,
                indicatorColor: theme.primaryColor,
                labelColor: theme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                splashFactory: InkSparkle
                    .splashFactory, // ✨ Android 13+: Animación de agua (Ripple moderno)
                indicatorSize: TabBarIndicatorSize
                    .label, // ✨ iOS: Indicador corto y elegante
                tabs: const [
                  Tab(text: "EXPLORAR"),
                  Tab(text: "FAVORITAS"),
                  Tab(text: "GRABACIONES"), // ✨ NUEVA PESTAÑA
                ],
              ),

              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: NetworkRadar.isOnline,
                  builder: (context, isOnline, _) {
                    // ✨ EMPTY STATE PREMIUM CUANDO SE CORTA EL INTERNET
                    if (!isOnline) return _buildOfflineEmptyState(theme);

                    return TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildRadioList(
                          theme,
                          isFavoritesTab: false,
                          bottomSpace: listBottomSpace,
                        ),
                        _buildRadioList(
                          theme,
                          isFavoritesTab: true,
                          bottomSpace: listBottomSpace,
                        ),
                        _buildRecordingsTab(
                          theme,
                          bottomSpace: listBottomSpace,
                        ), // ✨ CONTENIDO GRABACIONES
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✨ NUEVO: Empty State animado y elegante para cuando no hay red
  Widget _buildOfflineEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Sombra difuminada (Glow) detrás del ícono
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.25),
                        blurRadius: 50,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              "Sin Señal",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: theme.textTheme.bodyLarge?.color,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "La radio global requiere conexión a internet. Disfruta de tu música guardada mientras regresa la señal.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                // Regresa al usuario a la primera pestaña de la App (Local) si implementas un PageController global
              },
              icon: const Icon(Icons.library_music_rounded),
              label: const Text(
                "Ir a Biblioteca Local",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✨ NUEVO: Pestaña dedicada a las Grabaciones de Radio
  Widget _buildRecordingsTab(ThemeData theme, {required double bottomSpace}) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomSpace,
        left: 20,
        right: 20,
        top: 40,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_external_on_rounded,
              size: 80,
              color: theme.primaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              "Tus Casetes",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Toca el botón rojo (⏺) en cualquier emisora para comenzar a grabar en vivo. Tus grabaciones MP3 aparecerán aquí.",
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.explore_rounded),
              label: const Text("Ir a Explorar"),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioList(
    ThemeData theme, {
    required bool isFavoritesTab,
    required double bottomSpace,
  }) {
    if (_isLoading && !isFavoritesTab) {
      // ✨ SKELETON LOADER EN ACCIÓN
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: 10,
          left: 20,
          right: 20,
          bottom: bottomSpace,
        ),
        itemCount: 8, // Mostramos 8 esqueletos falsos para llenar la pantalla
        itemBuilder: (context, index) {
          return const ShimmerSkeletonItem();
        },
      );
    }

    // ✨ MAGIA: Ahora escuchamos la memoria real de PlayerManager, no un filtro temporal
    return ValueListenableBuilder<List<RadioStation>>(
      valueListenable: PlayerManager.favoriteRadios,
      builder: (context, favoritesList, _) {
        // 🧠 CEREBRO: Si es favoritos, muestra la memoria permanente. Si es explorar, muestra la API temporal.
        List<RadioStation> radiosToShow = isFavoritesTab
            ? favoritesList
            : _apiStations;

        if (radiosToShow.isEmpty) {
          return Center(
            child: Text(
              isFavoritesTab
                  ? "Aún no tienes antenas favoritas."
                  : "No se encontraron estaciones.",
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide =
                constraints.maxWidth > 600; // ✨ Adapta a pantallas grandes

            if (isWide) {
              return GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: 10,
                  left: 20,
                  right: 20,
                  bottom: bottomSpace,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 90, // Altura elegante para tarjetas
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: radiosToShow.length,
                itemBuilder: (context, index) {
                  final radio = radiosToShow[index];
                  bool isFav = favoritesList.any((fav) => fav.id == radio.id);
                  return _radioCard(theme, radio, isFav, isGrid: true);
                },
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: 10,
                left: 20,
                right: 20,
                bottom: bottomSpace,
              ),
              itemCount: radiosToShow.length,
              itemBuilder: (context, index) {
                final radio = radiosToShow[index];
                bool isFav = favoritesList.any((fav) => fav.id == radio.id);
                return _radioCard(theme, radio, isFav, isGrid: false);
              },
            );
          },
        );
      },
    );
  }

  Widget _radioCard(
    ThemeData theme,
    RadioStation radio,
    bool isFav, {
    bool isGrid = false,
  }) {
    return Container(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cardColor.withValues(alpha: 0.9),
            theme.cardColor.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(
          20,
        ), // ✨ iOS: Bordes "Super Ellipse"
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.06,
            ), // ✨ iOS: Sombra más amplia y difusa
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Material(
        color: Colors.transparent, // Permite ver el fondo de la tarjeta
        borderRadius: BorderRadius.circular(20),
        // ✨ NUEVO: Deslizar para interacción rápida (Swipe)
        child: Dismissible(
          key: Key(radio.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 25),
            decoration: BoxDecoration(
              color: isFav ? Colors.redAccent : Colors.green.shade400,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isFav ? Icons.heart_broken_rounded : Icons.favorite_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          confirmDismiss: (direction) async {
            // Realiza la acción pero cancela la animación de "eliminar" visualmente la tarjeta
            HapticFeedback.heavyImpact();
            PlayerManager.toggleRadioFavorite(radio, context);
            return false;
          },
          child: InkWell(
            // ✨ Animación nativa fluida al tocar
            borderRadius: BorderRadius.circular(20),
            splashFactory: InkSparkle
                .splashFactory, // ✨ Android 13+: Respuesta táctil inmersiva y cristalina
            onTap: () {
              HapticFeedback.selectionClick();
              PlayerManager.playRadio(radio);
            },
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 8,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  radio.favicon.isNotEmpty
                      ? radio.favicon
                      : 'https://via.placeholder.com/150',
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 55,
                    height: 55,
                    color: theme.primaryColor.withValues(alpha: 0.2),
                    child: Icon(Icons.radio, color: theme.primaryColor),
                  ),
                ),
              ),
              title: Text(
                radio.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              subtitle: Text(
                radio.country.isNotEmpty ? radio.country : "Global",
                maxLines: 1,
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // ✨ NUEVO: Botones agrupados (Grabar + Favorito)
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: PlayerManager.isRecording,
                    builder: (context, isRecording, _) {
                      // Si está grabando y es la radio actual, mostrar rojo palpitante
                      bool recordingThis =
                          isRecording &&
                          PlayerManager.currentArtwork.value == radio.favicon;
                      return IconButton(
                        icon: Icon(
                          recordingThis
                              ? Icons.stop_circle_rounded
                              : Icons.radio_button_checked_rounded,
                          color: recordingThis
                              ? Colors.redAccent
                              : Colors.grey.withValues(alpha: 0.4),
                          size: recordingThis ? 28 : 24,
                        ),
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          if (recordingThis) {
                            PlayerManager.stopRecording(context);
                          } else {
                            PlayerManager.playRadio(
                              radio,
                            ).then((_) => PlayerManager.startRecording());
                          }
                        },
                      );
                    },
                  ),
                  _FavoriteHeartButton(radio: radio, isFav: isFav),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ✨ WIDGET DEDICADO PARA EL BOTÓN DE CORAZÓN CON ANIMACIÓN DE LATIDO
class _FavoriteHeartButton extends StatefulWidget {
  final RadioStation radio;
  final bool isFav;

  const _FavoriteHeartButton({required this.radio, required this.isFav});

  @override
  State<_FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<_FavoriteHeartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Animación de latido: escala hacia arriba y luego vuelve a su tamaño original
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);

    HapticFeedback.heavyImpact(); // ✨ Respuesta táctil contundente
    await _controller.forward(from: 0.0);

    // Llama a la lógica de negocio con el contexto para mostrar SnackBars
    PlayerManager.toggleRadioFavorite(widget.radio, context);

    if (mounted) {
      setState(() => _isAnimating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(
          widget.isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: widget.isFav
              ? Colors.redAccent
              : Colors.grey.withValues(alpha: 0.4),
        ),
      ),
      onPressed: _onTap,
    );
  }
}
