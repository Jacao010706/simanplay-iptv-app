import 'package:flutter/material.dart';
import '../models/app_session.dart';
import '../models/channel.dart';
import '../models/category.dart';
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
          final channels =
              await service.getLiveStreams(cat.id, cat.name);
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
    return _allChannels.where((c) {
      final matchCat = _selectedCategoryId == 'all' ||
          c.categoryId == _selectedCategoryId ||
          c.categoryName == _selectedCategoryId;
      final matchSearch = _search.isEmpty ||
          c.name.toLowerCase().contains(_search.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
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
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFe94bff)),
            SizedBox(height: 16),
            Text('Carregando canais...',
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe94bff)),
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
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white38),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white38),
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
                child: _buildCategoryList(),
              ),
              const VerticalDivider(
                  color: Color(0xFF2a2538), width: 1),
              Expanded(child: _buildChannelList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList() {
    final allCategories = [
      Category(id: 'all', name: 'Todos (${_allChannels.length})', type: 'live'),
      ..._categories,
    ];
    return ListView.builder(
      itemCount: allCategories.length,
      itemBuilder: (_, i) {
        final cat = allCategories[i];
        final isSelected = cat.id == _selectedCategoryId;
        final count = cat.id == 'all'
            ? _allChannels.length
            : _allChannels
                .where((c) =>
                    c.categoryId == cat.id ||
                    c.categoryName == cat.id)
                .length;
        return InkWell(
          onTap: () => setState(() => _selectedCategoryId = cat.id),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFe94bff).withValues(alpha: 0.15)
                  : Colors.transparent,
              border: isSelected
                  ? const Border(
                      left: BorderSide(
                          color: Color(0xFFe94bff), width: 3))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.id == 'all' ? 'Todos' : cat.name,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFe94bff)
                        : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (cat.id != 'all')
                  Text(
                    count.toString(),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelList() {
    final channels = _filteredChannels;
    if (channels.isEmpty) {
      return const Center(
        child: Text('Nenhum canal encontrado',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (_, i) {
        final ch = channels[i];
        return InkWell(
          onTap: () => _openPlayer(ch),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: Color(0xFF1a1625), width: 0.5)),
            ),
            child: Row(
              children: [
                _buildLogo(ch.logoUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ch.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.play_circle_outline,
                    color: Color(0xFFe94bff), size: 20),
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
