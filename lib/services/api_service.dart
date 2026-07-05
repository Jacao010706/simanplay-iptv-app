import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/client_session.dart';
import '../core/app_config.dart';

class ApiService {
  static Future<ClientSession> login({
    required String username,
    required String password,
    String? macAddress,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.backendUrl}/app/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        if (macAddress != null) 'mac_address': macAddress,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ClientSession.fromJson(json);
    } else if (response.statusCode == 401) {
      throw Exception('Usuário ou senha inválidos');
    } else {
      throw Exception('Erro ao conectar ao servidor (${response.statusCode})');
    }
  }
}
