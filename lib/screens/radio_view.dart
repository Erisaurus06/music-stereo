import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_stereo/services/radio_engine.dart';
import '../services/app_state.dart';
import '../services/player_manager.dart';
import '../models/app_models.dart';

// --- 📻 VISTA DE RADIO GLOBAL (CON FAVORITOS) ---
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

  // ✨ LA BASE DE DATOS REAL CONECTADA AL MOTOR
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
    if (_isLoading && !isFavoritesTab)
      return const Center(child: CircularProgressIndicator());

    return ValueListenableBuilder<List<String>>(
      valueListenable: AppState.favoriteRadios!,
      builder: (context, favorites, _) {
        List<RadioStation> radiosToShow = isFavoritesTab
            ? _apiStations.where((r) => favorites.contains(r.name)).toList()
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
            return _radioCard(
              theme,
              radio.name,
              radio.url,
              radio.favicon,
              radio.country,
              favorites.contains(radio.name),
            );
          },
        );
      },
    );
  }

  Widget _radioCard(
    ThemeData theme,
    String title,
    String url,
    String imagePath,
    String country,
    bool isFav,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        PlayerManager.playRadio(
          RadioStation(
            id: title,
            name: title,
            url: url,
            favicon: imagePath,
            country: country,
            tags: '',
          ),
        );
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
              imagePath.isNotEmpty
                  ? imagePath
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
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: Text(
            country.isNotEmpty ? country : "Global",
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
              AppState.toggleFavoriteRadio(title);
            },
          ),
        ),
      ),
    );
  }
}
