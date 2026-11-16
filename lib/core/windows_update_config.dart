// Aviso de nova versão do app de PC (Windows).
//
// URL de um JSON público, só leitura, com a versão mais recente do app Windows da marca:
//   {"version": "1.0.0+N", "url": "https://...", "obrigatoria": false}
// N é o número do build (o mesmo --build-number do workflow). Vazio = sem verificação.
// O workflow do Windows preenche este valor com sed; as outras marcas ficam com ''.
const String kWindowsVersionUrl = '';
