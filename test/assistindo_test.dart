import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/services/assistindo_service.dart';

void main() {
  test('tipo do conteúdo pelo endereço do Xtream', () {
    expect(Assistindo.tipoDaUrl('http://srv:8080/live/u/p/7.ts'), 'canal');
    expect(Assistindo.tipoDaUrl('http://srv:8080/movie/u/p/9.mp4'), 'filme');
    expect(Assistindo.tipoDaUrl('http://srv:8080/series/u/p/11.mkv'), 'serie');
    expect(Assistindo.tipoDaUrl('http://srv/qualquer.m3u8', aoVivo: true), 'canal');
  });
}
