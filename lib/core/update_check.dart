// Regras de segurança do atualizador: só instala um APK baixado se ele for
// exatamente o que o servidor anunciou (SHA-256), do mesmo app (applicationId),
// com a mesma assinatura do app instalado e com versão maior. O Android também
// recusa assinatura diferente e downgrade, mas conferir antes dá uma mensagem
// clara e não abre o instalador à toa.

class ApkInfo {
  final String package;
  final int versionCode;
  final List<String> certs; // SHA-256 dos certificados de assinatura
  final String sha256; // SHA-256 do arquivo (só no APK baixado)

  const ApkInfo({
    required this.package,
    required this.versionCode,
    required this.certs,
    this.sha256 = '',
  });

  factory ApkInfo.fromMap(Map<dynamic, dynamic> m) => ApkInfo(
        package: (m['package'] as String?) ?? '',
        versionCode: (m['versionCode'] as num?)?.toInt() ?? 0,
        certs: ((m['certs'] as List?) ?? const []).map((e) => '$e'.toLowerCase()).toList(),
        sha256: ((m['sha256'] as String?) ?? '').toLowerCase(),
      );
}

/// Versão anunciada pelo servidor (/app/versao).
class VersaoServidor {
  final int versionCode;
  final String apkUrl;
  final String sha256;
  final String applicationId;

  const VersaoServidor({
    required this.versionCode,
    required this.apkUrl,
    required this.sha256,
    required this.applicationId,
  });

  factory VersaoServidor.fromJson(Map<String, dynamic> j) => VersaoServidor(
        versionCode: (j['version_code'] as num?)?.toInt() ?? 0,
        apkUrl: (j['apk_url'] as String?) ?? '',
        sha256: ((j['sha256'] as String?) ?? '').toLowerCase(),
        applicationId: (j['application_id'] as String?) ?? '',
      );
}

final _hex64 = RegExp(r'^[0-9a-f]{64}$');

/// Se vale oferecer a atualização (antes de baixar).
bool deveOferecer(VersaoServidor v, ApkInfo instalado) =>
    v.versionCode > instalado.versionCode &&
    v.apkUrl.startsWith('https://') &&
    _hex64.hasMatch(v.sha256) &&
    v.applicationId == instalado.package;

/// Motivo para NÃO instalar o APK baixado, ou null se está tudo certo.
String? motivoRecusa({
  required VersaoServidor anunciada,
  required ApkInfo instalado,
  required ApkInfo baixado,
}) {
  if (!_hex64.hasMatch(anunciada.sha256) || baixado.sha256 != anunciada.sha256) {
    return 'O arquivo baixado não confere (download incompleto ou alterado). Tente novamente.';
  }
  if (baixado.package.isEmpty || baixado.package != instalado.package) {
    return 'O arquivo baixado é de outro app. Atualização cancelada.';
  }
  final a = instalado.certs.toSet(), b = baixado.certs.toSet();
  if (a.isEmpty || b.isEmpty || a.length != b.length || !a.containsAll(b)) {
    return 'A assinatura do arquivo baixado é diferente da deste app. Atualização cancelada.';
  }
  if (baixado.versionCode <= instalado.versionCode) {
    return 'O arquivo baixado não é uma versão mais nova. Atualização cancelada.';
  }
  if (baixado.versionCode != anunciada.versionCode) {
    return 'A versão do arquivo baixado não é a anunciada. Atualização cancelada.';
  }
  return null;
}
