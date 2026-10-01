import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:simanplay_iptv/core/text_fix.dart';

void main() {
  group('fixMojibake (nomes já corrompidos no provedor)', () {
    test('casos relatados', () {
      expect(fixMojibake('BrasileirÃ£o'), 'Brasileirão');
      expect(fixMojibake('ESPORTES SDÂ²'), 'ESPORTES SD²');
      expect(fixMojibake('GLOBO FHDÂ²'), 'GLOBO FHD²');
    });
    test('outros acentos e aspas do Windows', () {
      expect(fixMojibake('AÃ§Ã£o e FicÃ§Ã£o'), 'Ação e Ficção');
      expect(fixMojibake('SÃ©ries'), 'Séries');
      expect(fixMojibake('Greyâ€™s Anatomy'), 'Grey’s Anatomy');
    });
    test('corrupção dupla (nome já salvo corrompido no painel)', () {
      expect(fixMojibake('BrasileirÃƒÂ£o'), 'Brasileirão');
      expect(fixMojibake('SDÃ‚Â²'), 'SD²');
      expect(fixMojibake('AÃƒÂ§ÃƒÂ£o'), 'Ação');
      expect(fixMojibake('BrasileirÃ\u0083Â£o'), 'Brasileirão'); // Latin-1 puro
    });
    test('texto correto não muda', () {
      for (final s in ['Brasileirão', 'SD²', 'Ação', 'Canal 24h', 'ÂNGULO', 'Ângela', 'Ã']) {
        expect(fixMojibake(s), s);
      }
    });
  });

  group('decodeBody (servidor sem charset)', () {
    test('UTF-8 sem charset no cabeçalho vira texto certo', () {
      final r = http.Response.bytes(utf8.encode('[{"name":"Brasileirão FHD²"}]'), 200,
          headers: {'content-type': 'text/html'});
      expect(r.body, isNot(contains('Brasileirão'))); // o que o app fazia antes
      expect(decodeJson(r)[0]['name'], 'Brasileirão FHD²');
    });
    test('servidor realmente em Latin-1 continua funcionando', () {
      final r = http.Response.bytes(latin1.encode('Ação'), 200);
      expect(decodeBody(r), 'Ação');
    });
    test('BOM é ignorado', () {
      final r = http.Response.bytes([0xEF, 0xBB, 0xBF, ...utf8.encode('{"a":"é"}')], 200);
      expect(decodeJson(r)['a'], 'é');
    });
  });
}
