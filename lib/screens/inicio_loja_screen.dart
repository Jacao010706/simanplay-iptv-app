import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/marca.dart';
import '../models/app_session.dart';
import 'activation_screen_v3.dart';
import 'device_home_screen.dart' show openHome;

/// Abertura da versão de loja (Google Play / Amazon): o Sofae é só um player.
/// Sem licença, sem código do aparelho e sem conta: se houver uma lista salva, entra nela;
/// senão, mostra a tela para informar a lista (Xtream ou M3U) ou abrir a demonstração.
class InicioLoja extends StatefulWidget {
  /// false ao sair da lista (não entra sozinho de novo).
  final bool autoEnter;
  const InicioLoja({super.key, this.autoEnter = true});

  @override
  State<InicioLoja> createState() => _InicioLojaState();
}

class _InicioLojaState extends State<InicioLoja> {
  bool _verificando = true;

  @override
  void initState() {
    super.initState();
    _entrar();
  }

  Future<void> _entrar() async {
    if (widget.autoEnter) {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString('session');
      if (salvo != null) {
        try {
          final session = AppSession.fromJson(jsonDecode(salvo) as Map<String, dynamic>);
          // Só listas próprias (Xtream ou M3U); sessão de conta de outro build não vale aqui
          if (session.isXtream || (session.primaryM3uUrl ?? '').isNotEmpty) {
            if (!mounted) return;
            await openHome(context, session);
            return;
          }
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _verificando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_verificando) {
      return Scaffold(
        backgroundColor: Color(Marca.backgroundColor),
        body: Center(child: CircularProgressIndicator(color: Color(Marca.primaryColor))),
      );
    }
    return const ActivationScreen();
  }
}
