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
    if (mounted) setState(() => _favoriteIds = list.toSet(
