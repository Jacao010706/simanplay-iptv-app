// Erros do servidor IPTV e textos de erro seguros para mostrar na tela.
//
// Regra: nenhuma mensagem mostrada ao usuário pode ter URL, usuário ou senha. Exceções do
// pacote http (ClientException) e do dart:io trazem a URL completa, com usuário e senha do
// Xtream, então toda mensagem passa por [mensagemDeErro] antes de ir para a tela.

/// O servidor recusou a conta agora (user_info.auth == 0, 401 ou 403).
class ContaRecusadaException implements Exception {
  const ContaRecusadaException();

  static const String mensagem =
      'O servidor recusou a conta agora (pode estar em uso em outro aparelho ou bloqueada '
      'temporariamente). Feche outros apps com esta lista e tente em alguns minutos.';

  @override
  String toString() => mensagem;
}

/// O servidor respondeu com erro HTTP (fora 401/403) ou com conteúdo que não dá para ler.
class ServidorException implements Exception {
  final String mensagem;
  const ServidorException(this.mensagem);

  @override
  String toString() => mensagem;
}

final RegExp _url = RegExp(r'''[a-zA-Z][a-zA-Z0-9+.-]*://[^\s'"<>)\]]+''');
final RegExp _caminhoXtream = RegExp(r'/(live|movie|series|timeshift)/[^/\s]+/[^/\s]+/');
final RegExp _credenciais = RegExp(r'((?:username|password|user|pass|senha)=)[^&\s]*', caseSensitive: false);

/// Tira de um texto qualquer URL e credencial (usuário/senha do Xtream).
String semCredenciais(String texto) => texto
    .replaceAll(_url, '[endereço oculto]')
    .replaceAllMapped(_caminhoXtream, (m) => '/${m[1]}/***/***/')
    .replaceAllMapped(_credenciais, (m) => '${m[1]}***');

/// Texto para a tela a partir de qualquer erro: amigável e sem URL, usuário ou senha.
String mensagemDeErro(Object erro) {
  if (erro is ContaRecusadaException) return ContaRecusadaException.mensagem;
  if (erro is ServidorException) return semCredenciais(erro.mensagem);
  final bruto = erro.toString();
  final t = bruto.toLowerCase();
  if (erro is FormatException || t.contains('formatexception')) {
    return 'O servidor enviou uma resposta inválida. Tente novamente em alguns minutos.';
  }
  if (t.contains('timeoutexception') || t.contains('timed out')) {
    return 'O servidor demorou demais para responder. Verifique a internet e tente novamente.';
  }
  if (t.contains('socketexception') ||
      t.contains('clientexception') ||
      t.contains('handshakeexception') ||
      t.contains('connection')) {
    return 'Não foi possível conectar ao servidor. Verifique a internet e o endereço da lista.';
  }
  final limpo = semCredenciais(bruto.replaceFirst(RegExp(r'^(Exception|Error): '), ''));
  return limpo.trim().isEmpty ? 'Ocorreu um erro. Tente novamente.' : limpo;
}
