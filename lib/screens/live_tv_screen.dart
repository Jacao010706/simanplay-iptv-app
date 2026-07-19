import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_session.dart';
import '../models/channel.dart';
import '../models/category.dart';
import '../core/app_config.dart';
import '../core/m3u_service.dart';
import '../services/xtream_service.dart';
import 'player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  final AppSession session;
  const LiveTvScreen({super.key, required this.session});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  List<Channel> _allChannels = [];
  List<Category> _categories = [];
  String _selectedCategoryId = 'all';
  bool _loading = true;
  String? _error;
  String _search = '';
  final _searchCtrl = TextEditingController();
  Set<String> _favoriteIds = {};
  static const _favsKey = 'sp_favs';

  @override
  void initState() {
    super.initState();
    _loadFavorites().then((_) => _loadContent());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favsKey) ?? [];
    if (mounted) setState(() => _favoriteIds = list.toSet());
  }

  Future<void> _toggleFavorite(Channel ch) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(ch.streamId)) {
        _favoriteIds.remove(ch.streamId);
      } else {
        _favoriteIds.add(ch.streamId);
      }
    });
    await prefs.setStringList(_favsKey, _favoriteIds.toList());
  }

  Future<void> _loadContent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.session.isXtream) {
        final service = XtreamService(
          host: widget.session.xtreamHost!,
          username: widget.session.xtreamUsername!,
          password: widget.session.xtreamPassword!,
        );
        final cats = await service.getLiveCategories();
        final List<Channel> allCh = [];
        for (final cat in cats) {
          final channels = await service.getLiveStreams(cat.id, cat.name);
          allCh.addAll(channels);
        }
        setState(() {
          _categories = cats;
          _allChannels = allCh;
          _loading = false;
        });
      } else {
        final url = widget.session.primaryM3uUrl ?? '';
        if (url.isEmpty) throw Exception('URL da playlist não configurada');
        final service = M3uService();
        final channels = await service.fetchAndParse(url);
        final cats = channels
            .map((c) => c.categoryName)
            .toSet()
            .map((name) => Category(id: name, name: name, type: 'live'))
            .toList();
        setState(() {
          _categories = cats;
          _allChannels = channels;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Channel> get _filteredChannels {
    List<Channel> base;
    if (_selectedCategoryId == '__favs__') {
      base = _allChannels.where((c) => _favoriteIds.contains(c.streamId)).toList();
    } else {
      base = _allChannels.where((c) {
        return _selectedCategoryId == 'all' ||
            c.categoryId == _selectedCategoryId ||
            c.categoryName == _selectedCategoryId;
      }).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      base = base.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    return base;
  }

  void _openPlayer(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          urls: [channel.streamUrl],
          title: channel.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 16),
            const Text('Carregando canais...',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadContent,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(backgroundColor: primary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Buscar canal...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      })
                  : null,
              filled: true,
              fillColor: const Color(0xFF1a1625),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 130,
                child: _buildCategoryList(primary),
              ),
              const VerticalDivider(color: Color(0xFF2a2538), width: 1),
              Expanded(child: _buildChannelList(primary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(Color primary) {
    final allCategories = [
      Category(id: '__favs__', name: '⭐ Favoritos (${_favoriteIds.length})', type: 'live'),
      Category(id: 'all', name: 'Todos (${_allChannels.length})', type: 'live'),
      ..._categories,
    ];
    return ListView.builder(
      itemCount: allCategories.length,
      itemBuilder: (_, i) {
        final cat = allCategories[i];
        final isSelected = cat.id == _selectedCategoryId;
        int count;
        if (cat.id == '__favs__') {
          count = _favoriteIds.length;
        } else if (cat.id == 'all') {
          count = _allChannels.length;
        } else {
          count = _allChannels
              .where((c) =>
                  c.categoryId == cat.id || c.categoryName == cat.id)
              .length;
        }
        return InkWell(
          onTap: () => setState(() => _selectedCategoryId = cat.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              border: isSelected
                  ? Border(left: BorderSide(color: primary, width: 3))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.id == 'all'
                      ? 'Todos'
                      : cat.id == '__favs__'
                          ? '⭐ Favoritos'
                          : cat.name,
                  style: TextStyle(
                    color: isSelected ? primary : Colors.white70,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (cat.id != 'all')
                  Text(
                    count.toString(),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelList(Color primary) {
    final channels = _filteredChannels;
    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedCategoryId == '__favs__'
                  ? Icons.star_border
                  : Icons.search_off,
              color: Colors.white24,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedCategoryId == '__favs__'
                  ? 'Nenhum favorito ainda.\nToque ★ em um canal para salvar.'
                  : 'Nenhum canal encontrado',
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (_, i) {
        final ch = channels[i];
        final isFav = _favoriteIds.contains(ch.streamId);
        return InkWell(
          onTap: () => _openPlayer(ch),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF1a1625), width: 0.5)),
            ),
            child: Row(
              children: [
                _buildLogo(ch.logoUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ch.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _toggleFavorite(ch),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? Colors.amber : Colors.white24,
                      size: 20,
                    ),
                  ),
                ),
                Icon(Icons.play_circle_outline, color: primary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo(String? logoUrl) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF2a2538),
        borderRadius: BorderRadius.circular(8),
      ),
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.live_tv,
                    color: Colors.white38,
                    size: 22),
              ),
            )
          : const Icon(Icons.live_tv, color: Colors.white38, size: 22),
    );
  }
}
