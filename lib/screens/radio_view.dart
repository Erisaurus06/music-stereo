import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_stereo/services/radio_engine.dart';
import '../services/app_state.dart';
import '../services/player_manager.dart';
import '../models/app_models.dart';

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
    _tabController = TabController(length: 2, vsync: this);
    _cargarRadios(); // Carga las top al iniciar
  }

  Future<void> _cargarRadios([String query = ""]) async {
    setState(() => _isLoading = true);
    if (query.isEmpty) {
      _apiStations = await RadioEngine.getTopStations();
    } else {
      _apiStations = await RadioEngine.searchStations(query);
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

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              "Radio Global",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 34,
                color: theme.textTheme.bodyLarge?.color,
                letterSpacing: -1,
              ),
            ),
          ),

          // 🔎 BARRA DE BÚSQUEDA CONECTADA A LA API
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
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
            tabs: const [
              Tab(text: "EXPLORAR"),
              Tab(text: "FAVORITAS"),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildRadioList(theme, isFavoritesTab: false),
                _buildRadioList(theme, isFavoritesTab: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioList(ThemeData theme, {required bool isFavoritesTab}) {
    if (_isLoading && !isFavoritesTab) {
      return const Center(child: CircularProgressIndicator());
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

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            top: 10,
            left: 20,
            right: 20,
            bottom: 150,
          ),
          itemCount: radiosToShow.length,
          itemBuilder: (context, index) {
            final radio = radiosToShow[index];
            // Verificamos si la tarjeta actual existe en la base de datos de favoritos
            bool isFav = favoritesList.any((fav) => fav.id == radio.id);

            return _radioCard(theme, radio, isFav);
          },
        );
      },
    );
  }

  Widget _radioCard(ThemeData theme, RadioStation radio, bool isFav) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        PlayerManager.playRadio(radio);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
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
                color: theme.primaryColor.withOpacity(0.2),
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
          trailing: IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? Colors.redAccent : Colors.grey.withOpacity(0.5),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              // ✨ GUARDAMOS EL OBJETO COMPLETO EN LA MEMORIA, NO SOLO EL NOMBRE
              PlayerManager.toggleRadioFavorite(radio);
            },
          ),
        ),
      ),
    );
  }
}
