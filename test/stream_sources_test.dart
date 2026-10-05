import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/core/stream_sources.dart';

void main() {
  group('liveStreamSources', () {
    test('.ts gera .ts + .m3u8', () {
      expect(liveStreamSources(['http://srv:8080/live/u/p/123.ts']),
          ['http://srv:8080/live/u/p/123.ts', 'http://srv:8080/live/u/p/123.m3u8']);
    });

    test('.m3u8 gera .m3u8 + .ts', () {
      expect(liveStreamSources(['http://srv:8080/live/u/p/123.m3u8']),
          ['http://srv:8080/live/u/p/123.m3u8', 'http://srv:8080/live/u/p/123.ts']);
    });

    test('sem extensão gera original + .m3u8', () {
      expect(liveStreamSources(['http://srv:8080/u/p/123']),
          ['http://srv:8080/u/p/123', 'http://srv:8080/u/p/123.m3u8']);
    });

    test('extensão em maiúsculas e query string são preservadas', () {
      expect(liveStreamSources(['http://srv/live/u/p/1.TS?token=abc']),
          ['http://srv/live/u/p/1.TS?token=abc', 'http://srv/live/u/p/1.m3u8?token=abc']);
    });

    test('várias URLs, sem duplicatas, na ordem', () {
      expect(
        liveStreamSources([
          'http://a/live/u/p/1.ts',
          'http://a/live/u/p/1.m3u8',
          'http://b/live/u/p/1.m3u8',
        ]),
        ['http://a/live/u/p/1.ts', 'http://a/live/u/p/1.m3u8', 'http://b/live/u/p/1.m3u8', 'http://b/live/u/p/1.ts'],
      );
    });

    test('outras extensões e URLs sem caminho não ganham variante', () {
      expect(liveStreamSources(['http://srv/movie/u/p/9.mp4']), ['http://srv/movie/u/p/9.mp4']);
      expect(liveStreamSources(['http://srv:8080']), ['http://srv:8080']);
      expect(liveStreamSources(['http://srv:8080/']), ['http://srv:8080/']);
      expect(liveStreamSources(['', '  ']), isEmpty);
    });
  });

  group('maskStreamUrl', () {
    test('esconde usuário e senha do caminho /live/USUARIO/SENHA/', () {
      final m = maskStreamUrl('http://srv:8080/live/joao123/s3nh@/4567.ts');
      expect(m, 'http://srv:8080/live/***/***/4567.ts');
      expect(m, isNot(contains('joao123')));
      expect(m, isNot(contains('s3nh@')));
    });

    test('também em filmes, séries e parâmetros da query', () {
      expect(maskStreamUrl('http://srv/series/u1/p1/9.mkv'), 'http://srv/series/***/***/9.mkv');
      expect(maskStreamUrl('http://srv/get.php?username=u1&password=p1&type=m3u'),
          'http://srv/get.php?username=***&password=***&type=m3u');
    });

    test('URL sem credenciais não muda', () {
      expect(maskStreamUrl('http://srv/canal.m3u8'), 'http://srv/canal.m3u8');
    });
  });
}
