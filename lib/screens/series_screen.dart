import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../models/app_session.dart';
import '../models/series.dart';
import '../models/category.dart';
import '../services/xtream_service.dart';
import 'series_detail_screen.dart';

class SeriesScreen extends StatefulWidget {
  final AppSession session;
  const SeriesScreen({super.key, required this.session});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Series> _allSeries = [];
  List<Category> _categories = [];
  String _selectedCategoryId = 'all';
  bool _loading = true;
  String? _error;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    if (!widget.session.hasXtreamAccess) {
      setState(() {
        _error = 'Séries disponíveis apenas para contas Xtream Codes.';
        _loading = false;
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final service = XtreamService(
        host:     widget.session.effectiveXtreamHost!,
        username: widget.session.effectiveXtreamUsername!,
        password: widget.session.effectiveXtreamPassword!,
      );
      final results = await Future.wait([
        service.getSeriesCategories(),
        service.getAllSeries(),
      ]);
      setState(() {
        _categories = results[0] as List<Category>;
        _allSeries  = results[1] as List<Series>;
        _loading    = false;
      });
    } catch (e) {
      setState(() {
        _error   = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Series> get _filteredSeries {
    return _allSeries.where((s) {
      final matchCat = _selectedCategoryId == 'all' || s.categoryId == _selectedCategoryId;
      final matchSearch = _search.isEmpty || s.name.toLowerCase().contains(_search.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  void _openSeries(Series series) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SeriesDetailScreen(session: widget.session, series: series),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);

    if (_loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: primary),
        const SizedBox(height: 16),
        const Text('Carregando séries...', style: TextStyle(color: Colors.white54)),
      ]));
    }

    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.video_library_outlined, color: primary.withValues(alpha: 0.4), size: 64),
          const SizedBox(height: 16),
          Text(_error!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadContent,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
            style: ElevatedButton.styleFrom(backgroundColor: primary),
          ),
        ]),
      ));
    }

    return Column(children: [
      // Barra de busca
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white),
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Buscar série...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38),
                    onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                : null,
            filled: true,
            fillColor: const Color(0xFF1a1625),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),

      // Filtros de categoria
      SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _categories.length + 1,
          itemBuilder: (_, i) {
            final isAll   = i == 0;
            final catId   = isAll ? 'all' : _categories[i - 1].id;
            final catName = isAll ? 'Todos' : _categories[i - 1].name;
            final sel     = catId == _selectedCategoryId;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategoryId = catId),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? primary : const Color(0xFF1a1625),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? primary : const Color(0xFF2a2538)),
                ),
                child: Text(catName,
                    style: TextStyle(
                        color: sel ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 8),

      // Grade de séries
      Expanded(
        child: _filteredSeries.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                const Text('Nenhuma série encontrada',
                    style: TextStyle(color: Colors.white54)),
              ]))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _filteredSeries.length,
                itemBuilder: (_, i) => _buildCard(_filteredSeries[i], primary),
              ),
      ),
    ]);
  }

  Widget _buildCard(Series series, Color primary) {
    return GestureDetector(
      onTap: () => _openSeries(series),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Stack(children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1a1625),
              borderRadius: BorderRadius.circular(8),
            ),
            child: series.posterUrl != null && series.posterUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      series.posterUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.video_library,
                            color: primary.withValues(alpha: 0.4), size: 32)),
                    ))
                : Center(child: Icon(Icons.video_library,
                    color: primary.withValues(alpha: 0.4), size: 32)),
          ),
          // Badge de rating
          if (series.rating != null && series.rating! > 0)
            Positioned(top: 4, right: 4, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star, color: Colors.amber, size: 10),
                const SizedBox(width: 2),
                Text(series.rating!.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontSize: 9)),
              ]),
            )),
        ])),
        const SizedBox(height: 4),
        Text(series.name,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
