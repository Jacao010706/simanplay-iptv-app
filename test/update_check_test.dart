import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/core/update_check.dart';

const _sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _cert = certAssinatura; // a chave oficial
// SHA-256 do certificado da chave nova, como o keytool mostra (fixado no app e no workflow)
const _certDoKeytool = '5B:72:EE:8D:79:63:BF:6F:53:C7:7C:64:49:C5:98:0A:7A:C4:76:5C:C0:0A:B2:9D:C3:94:40:54:3F:10:B2:32';
const _outroCert = '2222222222222222222222222222222222222222222222222222222222222222';

const _instalado = ApkInfo(package: 'com.sofae.app', versionCode: 131, certs: [_cert]);
const _anunciada = VersaoServidor(
  versionCode: 132,
  apkUrl: 'https://github.com/Jacao010706/simanplay-iptv-app/releases/download/apk-sofae-132/sofae-simanplay.apk',
  sha256: _sha,
  applicationId: 'com.sofae.app',
);

ApkInfo _baixado({String pkg = 'com.sofae.app', int vc = 132, List<String> certs = const [_cert], String sha = _sha}) =>
    ApkInfo(package: pkg, versionCode: vc, certs: certs, sha256: sha);

String? _recusa(ApkInfo b) => motivoRecusa(anunciada: _anunciada, instalado: _instalado, baixado: b);

void main() {
  group('oferecer atualização', () {
    test('versão maior do mesmo app, com hash e https: oferece', () {
      expect(deveOferecer(_anunciada, _instalado), isTrue);
    });
    test('versão igual ou menor: não oferece (sem downgrade)', () {
      for (final vc in [131, 100, 0]) {
        final v = VersaoServidor(versionCode: vc, apkUrl: _anunciada.apkUrl, sha256: _sha, applicationId: 'com.sofae.app');
        expect(deveOferecer(v, _instalado), isFalse, reason: '$vc');
      }
    });
    test('sem hash, link sem https ou de outro app: não oferece', () {
      expect(deveOferecer(const VersaoServidor(versionCode: 200, apkUrl: 'https://x/a.apk', sha256: '', applicationId: 'com.sofae.app'), _instalado), isFalse);
      expect(deveOferecer(const VersaoServidor(versionCode: 200, apkUrl: 'http://x/a.apk', sha256: _sha, applicationId: 'com.sofae.app'), _instalado), isFalse);
      expect(deveOferecer(const VersaoServidor(versionCode: 200, apkUrl: 'https://x/a.apk', sha256: _sha, applicationId: 'com.simanplay.martinstv'), _instalado), isFalse);
    });
  });

  group('instalar o APK baixado', () {
    test('tudo certo: instala', () {
      expect(_recusa(_baixado()), isNull);
    });
    test('hash diferente: recusa', () {
      expect(_recusa(_baixado(sha: 'b' * 64)), contains('não confere'));
    });
    test('APK de outro app (outro revendedor): recusa', () {
      expect(_recusa(_baixado(pkg: 'com.simanplay.iptvplayer.iptv_player')), contains('outro app'));
    });
    test('assinatura de outra chave, ausente ou com dois certificados: recusa', () {
      expect(_recusa(_baixado(certs: [_outroCert])), contains('chave oficial'));
      expect(_recusa(_baixado(certs: const [])), contains('chave oficial'));
      expect(_recusa(_baixado(certs: [_cert, _outroCert])), contains('chave oficial'));
    });
    test('app instalado com outra chave e APK com a oficial: recusa', () {
      // o Android também recusaria; aqui a mensagem é clara e o instalador nem abre
      const instaladoOutraChave = ApkInfo(package: 'com.sofae.app', versionCode: 131, certs: [_outroCert]);
      expect(motivoRecusa(anunciada: _anunciada, instalado: instaladoOutraChave, baixado: _baixado()),
          contains('diferente da deste app'));
    });
    test('mesmo app e mesma chave, mas não a oficial: recusa', () {
      const instaladoOutraChave = ApkInfo(package: 'com.sofae.app', versionCode: 131, certs: [_outroCert]);
      expect(motivoRecusa(anunciada: _anunciada, instalado: instaladoOutraChave, baixado: _baixado(certs: [_outroCert])),
          contains('chave oficial'));
    });
    test('a chave fixada é a do keytool (5B:72:...:B2:32)', () {
      expect(certAssinatura, _certDoKeytool.replaceAll(':', '').toLowerCase());
    });
    test('versão igual ou menor que a instalada: recusa', () {
      expect(_recusa(_baixado(vc: 131)), contains('mais nova'));
      expect(_recusa(_baixado(vc: 90)), contains('mais nova'));
    });
    test('versão diferente da anunciada: recusa', () {
      expect(_recusa(_baixado(vc: 140)), contains('anunciada'));
    });
  });

  test('lê o mapa do canal nativo', () {
    final a = ApkInfo.fromMap({'package': 'com.sofae.app', 'versionCode': 131, 'certs': ['ABC'], 'sha256': 'DEF'});
    expect([a.package, a.versionCode, a.certs, a.sha256], ['com.sofae.app', 131, ['abc'], 'def']);
  });
}
