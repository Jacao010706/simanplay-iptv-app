import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_session.dart';
import '../models/channel.dart';
import '../models/category.dart';
import '../core/app_config.dart';
import '../core/m3u_service.dart';
import '../services/xtream_service.dart';
import '../services/recording_service.dart';
import 'player_screen.dart';
import 'recordings_screen.dart';

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
    // Update UI when recording state changes
    RecordingService.instance.onUpdate = () {
      if (mounted) setState(() {});
    };
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
      if (_favoriteIds.contains(ch.id)) {
        _favoriteIds.remove(ch.id);
      } else {
        _favoriteIds.add(ch.id);
      }
    });
    await prefs.setStringList(_favsKey, _favoriteIds.toList());
  }

  Future<void> _loadContent() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (widget.session.isXtream) {
        final service = XtreamService(
          host: widget.session.xtreamHost!,
          username: widget.session.effectiveXtreamUsername!,
          password: widget.session.effectiveXtreamPassword!,
        );
        final cats = await service.getLiveCategories();
        final List<Channel> allCh = [];
        for (final cat in cats) {
          final channels = await service.getLiveStreams(cat.id, cat.name);
          allCh.addAll(channels);
        }
        setState(() { _categories = cats; _allChannels = allCh; _loading = false; });
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
        setState(() { _categories = cats; _allChannels = channels; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  List<Channel> get _filteredChannels {
    List<Channel> base;
    if (_selectedCategoryId == '__favs__') {
      base = _allChannels.where((c) => _favoriteIds.contains(c.id)).toList();
    } else {
      base = _allChannels.where((c) =>
          _selectedCategoryId == 'all' ||
          c.categoryId == _selectedCategoryId ||
          c.categoryName == _selectedCategoryId).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      base = base.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    return base;
  }

  void _openPlayer(Channel channel) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(urls: [channel.streamUrl], title: channel.name),
    ));
  }

  void _showChannelSheet(Channel channel, Color primary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1625),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ChannelEpgSheet(
        channel: channel,
        session: widget.session,
        primary: primary,
        isFav: _favoriteIds.contains(channel.id),
        onFavToggle: () => _toggleFavorite(channel),
        onPlay: () {
          Navigator.pop(context);
          _openPlayer(channel);
        },
        onGoToRecordings: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const RecordingsScreen(),
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final isRecording = RecordingService.instance.isRecording;

    if (_loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: primary),
        const SizedBox(height: 16),
        const Text('Carregando canais...', style: TextStyle(color: Colors.white54)),
      ]));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadContent,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
          style: ElevatedButton.styleFrom(backgroundColor: primary),
        ),
      ]));
    }
    return Column(children: [
      // ── Barra de busca + botão Gravações ───────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
        child: Row(children: [
          Expanded(child: TextField(
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
                      onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
              filled: true,
              fillColor: const Color(0xFF1a1625),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          )),
          const SizedBox(width: 4),
          // Botão Gravações
          Tooltip(
            message: 'Minhas Gravações',
            child: Stack(alignment: Alignment.topRight, children: [
              IconButton(
                icon: const Icon(Icons.video_library_outlined, color: Colors.white70),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecordingsScreen()),
                ),
              ),
              if (isRecording)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(child: Row(children: [
        SizedBox(width: 130, child: _buildCategoryList(primary)),
        const VerticalDivider(color: Color(0xFF2a2538), width: 1),
        Expanded(child: _buildChannelList(primary)),
      ])),
    ]);
  }

  Widget _buildCategoryList(Color primary) {
    final allCategories = [
      Category(id: '__favs__', name: '⭐ Favoritos', type: 'live'),
      Category(id: 'all', name: 'Todos', type: 'live'),
      ..._categories,
    ];
    return ListView.builder(
      itemCount: allCategories.length,
      itemBuilder: (_, i) {
        final cat = allCategories[i];
        final isSelected = cat.id == _selectedCategoryId;
        final count = cat.id == '__favs__'
            ? _favoriteIds.length
            : cat.id == 'all'
                ? _allChannels.length
                : _allChannels
                    .where((c) => c.categoryId == cat.id || c.categoryName == cat.id)
                    .length;
        return InkWell(
          onTap: () => setState(() => _selectedCategoryId = cat.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? primary.withValues(alpha: 0.15) : Colors.transparent,
              border: isSelected
                  ? Border(left: BorderSide(color: primary, width: 3))
                  : null,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                cat.id == '__favs__' ? '⭐ Favoritos' : cat.id == 'all' ? 'Todos' : cat.name,
                style: TextStyle(
                  color: isSelected ? primary : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              Text(count.toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildChannelList(Color primary) {
    final channels = _filteredChannels;
    if (channels.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          _selectedCategoryId == '__favs__' ? Icons.star_border : Icons.search_off,
          color: Colors.white24, size: 48),
        const SizedBox(height: 12),
        Text(
          _selectedCategoryId == '__favs__'
              ? 'Nenhum favorito ainda.\nToque ★ para salvar um canal.'
              : 'Nenhum canal encontrado',
          style: const TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      ]));
    }
    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (_, i) {
        final ch    = channels[i];
        final isFav = _favoriteIds.contains(ch.id);
        final isThisRecording = RecordingService.instance.activeRecording?.channelName == ch.name;

        return InkWell(
          onTap: () => _showChannelSheet(ch, primary),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isThisRecording
                  ? Colors.red.withValues(alpha: 0.05)
                  : Colors.transparent,
              border: const Border(
                  bottom: BorderSide(color: Color(0xFF1a1625), width: 0.5)),
            ),
            child: Row(children: [
              _buildLogo(ch.logoUrl),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ch.name,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (isThisRecording)
                    Row(children: [
                      const Icon(Icons.circle, color: Colors.red, size: 8),
                      const SizedBox(width: 4),
                      Text(
                        'Gravando • ${RecordingService.instance.activeRecording!.sizeFormatted}',
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ]),
                ],
              )),
              GestureDetector(
                onTap: () => _toggleFavorite(ch),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(isFav ? Icons.star : Icons.star_border,
                      color: isFav ? Colors.amber : Colors.white24, size: 20),
                ),
              ),
              Icon(Icons.chevron_right, color: primary, size: 20),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildLogo(String? logoUrl) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
          color: const Color(0xFF2a2538), borderRadius: BorderRadius.circular(8)),
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(logoUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.live_tv, color: Colors.white38, size: 22)))
          : const Icon(Icons.live_tv, color: Colors.white38, size: 22),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Bottom sheet do canal: EPG + favorito + gravar + assistir
// ═══════════════════════════════════════════════════════════════════════════════

class _ChannelEpgSheet extends StatefulWidget {
  final Channel channel;
  final AppSession session;
  final Color primary;
  final bool isFav;
  final VoidCallback onFavToggle;
  final VoidCallback onPlay;
  final VoidCallback onGoToRecordings;

  const _ChannelEpgSheet({
    required this.channel,
    required this.session,
    required this.primary,
    required this.isFav,
    required this.onFavToggle,
    required this.onPlay,
    required this.onGoToRecordings,
  });

  @override
  State<_ChannelEpgSheet> createState() => _ChannelEpgSheetState();
}

class _ChannelEpgSheetState extends State<_ChannelEpgSheet> {
  List<Map<String, dynamic>> _epgList = [];
  bool _loadingEpg = true;
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFav;
    _loadEpg();
    RecordingService.instance.onUpdate = () {
      if (mounted) setState(() {});
    };
  }

  Future<void> _loadEpg() async {
    if (!widget.session.hasXtreamAccess) {
      setState(() => _loadingEpg = false);
      return;
    }
    try {
      final service = XtreamService(
        host:     widget.session.effectiveXtreamHost!,
        username: widget.session.effectiveXtreamUsername!,
        password: widget.session.effectiveXtreamPassword!,
      );
      final data    = await service.getShortEpg(widget.channel.id);
      final entries = data['epg_listings'];
      if (entries is List) {
        setState(() {
          _epgList   = List<Map<String, dynamic>>.from(entries);
          _loadingEpg = false;
        });
      } else {
        setState(() => _loadingEpg = false);
      }
    } catch (_) {
      setState(() => _loadingEpg = false);
    }
  }

  String _formatEpgTime(String? t) {
    if (t == null || t.isEmpty) return '';
    try {
      final dt = DateTime.parse(t).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  String _decodeTitle(String? title) {
    if (title == null || title.isEmpty) return '';
    try { return utf8.decode(base64.decode(title)); } catch (_) { return title; }
  }

  Future<void> _toggleRecording() async {
    final rs = RecordingService.instance;
    if (rs.isRecording &&
        rs.activeRecording?.channelName == widget.channel.name) {
      // Parar a gravação deste canal
      await rs.stopRecording();
      setState(() {});
    } else {
      // Iniciar gravação
      await rs.startRecording(widget.channel.name, widget.channel.streamUrl);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs          = RecordingService.instance;
    final isThisRec   = rs.isRecording &&
        rs.activeRecording?.channelName == widget.channel.name;
    final otherRec    = rs.isRecording && !isThisRec;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Handle
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),

        // ── Cabeçalho do canal ──────────────────────────────────────────────
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: const Color(0xFF2a2538),
                borderRadius: BorderRadius.circular(10)),
            child: widget.channel.logoUrl != null && widget.channel.logoUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(widget.channel.logoUrl!, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.live_tv, color: Colors.white38)))
                : const Icon(Icons.live_tv, color: Colors.white38),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.channel.name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            Row(children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.red, borderRadius: BorderRadius.circular(4)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, color: Colors.white, size: 6),
                  SizedBox(width: 4),
                  Text('AO VIVO',
                      style: TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              if (isThisRec) ...[
                const SizedBox(width: 6),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.fiber_manual_record,
                        color: Colors.red, size: 8),
                    const SizedBox(width: 4),
                    Text(
                      'REC ${rs.activeRecording!.elapsedFormatted}',
                      style: const TextStyle(
                          color: Colors.red, fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
              ],
            ]),
          ])),
          IconButton(
            icon: Icon(_isFav ? Icons.star : Icons.star_border,
                color: _isFav ? Colors.amber : Colors.white38),
            onPressed: () {
              setState(() => _isFav = !_isFav);
              widget.onFavToggle();
            },
          ),
        ]),

        const SizedBox(height: 16),

        // ── EPG ─────────────────────────────────────────────────────────────
        if (_loadingEpg)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
              SizedBox(width: 10),
              Text('Carregando programação...',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ]),
          ))
        else if (_epgList.isNotEmpty) ...[
          const Text('PROGRAMAÇÃO',
              style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 8),
          ..._epgList.take(2).toList().asMap().entries.map((entry) {
            final i     = entry.key;
            final ep    = entry.value;
            final title = _decodeTitle(ep['title']?.toString());
            final start = _formatEpgTime(ep['start']?.toString());
            final end   = _formatEpgTime(ep['end']?.toString());
            final isNow = i == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isNow
                    ? widget.primary.withValues(alpha: 0.12)
                    : const Color(0xFF0d0b14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isNow
                      ? widget.primary.withValues(alpha: 0.3)
                      : const Color(0xFF2a2538),
                ),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isNow ? 'AGORA' : 'PRÓXIMO',
                      style: TextStyle(
                          color: isNow ? widget.primary : Colors.white38,
                          fontSize: 10, fontWeight: FontWeight.bold)),
                  if (start.isNotEmpty)
                    Text('$start${end.isNotEmpty ? ' - $end' : ''}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  title.isNotEmpty ? title : 'Sem informação',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                )),
              ]),
            );
          }),
        ] else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFF0d0b14),
                borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.white24, size: 16),
              SizedBox(width: 8),
              Text('Sem informação de programação disponível',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ]),
          ),

        const SizedBox(height: 20),

        // ── Botões de ação ──────────────────────────────────────────────────
        Row(children: [
          // Assistir
          Expanded(child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: widget.onPlay,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text('Assistir',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )),
          const SizedBox(width: 10),
          // Gravar / Parar
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: otherRec ? null : _toggleRecording,
              icon: Icon(
                isThisRec ? Icons.stop : Icons.fiber_manual_record,
                color: Colors.white, size: 18,
              ),
              label: Text(
                isThisRec ? 'Parar' : 'Gravar',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isThisRec
                    ? Colors.red.shade800
                    : otherRec
                        ? Colors.grey.shade700
                        : const Color(0xFF2d1f3d),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ]),

        // Link "Ver gravações" após iniciar gravação
        if (isThisRec) ...[
          const SizedBox(height: 8),
          Center(child: TextButton.icon(
            onPressed: widget.onGoToRecordings,
            icon: const Icon(Icons.video_library_outlined,
                color: Colors.white54, size: 16),
            label: const Text('Ver minhas gravações',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          )),
        ],

        const SizedBox(height: 4),
      ]),
    );
  }
}
