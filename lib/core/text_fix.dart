import 'dart:convert';

import 'package:http/http.dart' as http;

/// Texto da resposta sempre como UTF-8.
///
/// `response.body` do pacote http usa Latin-1 quando o servidor não informa o charset
/// (muito comum em painéis IPTV), e aí "Brasileirão" vira "BrasileirÃ£o" e "SD²" vira
/// "SDÂ²". Aqui decodificamos os bytes como UTF-8; só se não forem UTF-8 válido
/// (servidor realmente em Latin-1) usamos Latin-1.
String decodeBody(http.Response response) {
  var bytes = response.bodyBytes;
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    bytes = bytes.sublist(3); // BOM
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// JSON da resposta com os textos já corrigidos.
dynamic decodeJson(http.Response response) => fixTextTree(json.decode(decodeBody(response)));

// Caracteres do Windows-1252 (0x80-0x9F) que aparecem em textos corrompidos, ex.: "â€™".
const Map<int, int> _cp1252 = {
  0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86,
  0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C,
  0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95,
  0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B,
  0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
};

// "Â", "Ã" ou "â" seguido de um byte de continuação do UTF-8 lido como Latin-1/Windows-1252.
final RegExp _mojibake =
    RegExp('[ÂÃâ][\u0080-¿${String.fromCharCodes(_cp1252.keys)}]');

/// Conserta texto que já veio corrompido do provedor (UTF-8 lido como Latin-1):
/// "BrasileirÃ£o" -> "Brasileirão", "FHDÂ²" -> "FHD²". Texto correto não é alterado.
/// Também desfaz corrupção dupla ("BrasileirÃƒÂ£o"), comum quando o painel já
/// salvou o nome corrompido e ele é corrompido de novo no caminho.
String fixMojibake(String text) {
  var current = text;
  for (var i = 0; i < 3; i++) {
    final next = _fixMojibakeOnce(current);
    if (next == current) break;
    current = next;
  }
  return current;
}

String _fixMojibakeOnce(String text) {
  if (!_mojibake.hasMatch(text)) return text;
  final bytes = <int>[];
  for (final rune in text.runes) {
    if (rune <= 0xFF) {
      bytes.add(rune);
    } else if (_cp1252.containsKey(rune)) {
      bytes.add(_cp1252[rune]!);
    } else {
      return text; // tem caractere que não veio de Latin-1: não mexe
    }
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return text;
  }
}

/// Aplica [fixMojibake] em todos os textos de um JSON (listas e mapas).
dynamic fixTextTree(dynamic value) {
  if (value is String) return fixMojibake(value);
  if (value is List) return value.map(fixTextTree).toList();
  if (value is Map) return value.map((k, v) => MapEntry(k, fixTextTree(v)));
  return value;
}
