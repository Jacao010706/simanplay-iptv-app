# Apps de Smart TV — PRIMETV

Todo build do painel ("Gerar APK") produz, além do APK, os apps de TV com o nome,
as cores e a logo do revendedor. O nome padrão é **PRIMETV**.

| Plataforma | Arquivo gerado | Como funciona |
|---|---|---|
| Android TV / TV Box / Fire TV | `<nome>.apk` | O mesmo app do celular; aparece no menu da TV (Leanback) |
| Samsung (Tizen 2.3+, TVs de 2015 em diante) | `<nome>_samsung_nao_assinado.wgt` | Lançador que abre o app de TV do painel (`/tv`) |
| LG (webOS 1.0+, TVs de 2014 em diante) | `<nome>_lg.ipk` | Lançador que abre o app de TV do painel (`/tv`) |
| Roku (qualquer Roku com SceneGraph) | `<nome>_roku.zip` | Canal nativo; usa as mesmas rotas do painel |

Samsung e LG são **apps hospedados**: o pacote instalado só abre
`https://simanplay-iptv-admin-panel.vercel.app/tv/?name=...&color=...`. Correções
no painel chegam a todas as TVs sem reinstalar nada.

## Compatibilidade com TVs antigas

- O app `/tv` usa só JavaScript ES5 (checado no build) e CSS com prefixos `-webkit-`.
- Vídeo HLS usa o **player nativo** da TV quando existe (Samsung e LG, inclusive
  antigas); `hls.js` só é usado em aparelhos sem HLS nativo. Filmes MP4/MKV tocam direto.
- O lançador Samsung/LG não usa flexbox nem recursos novos.
- Roku: só componentes SceneGraph básicos (LabelList, Video, KeyboardDialog, Task).
- Android: mínimo Android 5.0 (API 21), limite do Flutter.

## Instalação para testes (sem loja)

### Android TV / TV Box / Fire TV
Instale o `.apk` pelo app **Downloader** (link curto do painel) ou por pendrive.
Em aparelhos com APK antigo de outra assinatura, desinstale o antigo antes.

### LG (webOS)
1. Na TV, instale o app **Developer Mode** (LG Content Store) e entre com uma conta
   gratuita de desenvolvedor LG. Ative "Dev Mode Status" e reinicie a TV.
2. No computador: `npm i -g @webos-tools/cli`
3. `ares-setup-device` (cadastre o IP da TV) e `ares-novacom --device tv --getkey`
4. `ares-install --device tv <nome>_lg.ipk`

O Developer Mode expira a cada 1000 horas (renovável no app). Para distribuição
sem essa limitação é preciso publicar na LG Content Store (LG Seller Lounge).

### Samsung (Tizen)
A Samsung **exige assinatura** com certificado emitido pela Samsung; o arquivo
sai do build como `_nao_assinado.wgt`.
1. Instale o **Tizen Studio** com a extensão **Samsung Certificate Extension**.
2. Em Tools > Certificate Manager, crie um perfil **Samsung** (certificado de autor +
   distribuidor). Para testes, adicione o **DUID** da TV (visível na TV em modo desenvolvedor).
3. Ative o modo desenvolvedor na TV: em Apps, digite `12345` no controle, ligue
   "Developer mode" e informe o IP do computador. Reinicie a TV.
4. Assine e instale:
   ```
   tizen package -t wgt -s <perfil> -- <nome>_samsung_nao_assinado.wgt
   sdb connect <IP_DA_TV>
   tizen install -n <nome>_samsung_nao_assinado.wgt -t <id_da_tv>
   ```
Para lojas, envie ao **Samsung Seller Office**, que faz a assinatura de distribuição.

### Roku
1. No controle da Roku: Home 3x, Cima 2x, Direita, Esquerda, Direita, Esquerda,
   Direita. Ative o **Developer Mode** e defina uma senha.
2. No navegador do computador abra `http://<IP_DA_ROKU>`, usuário `rokudev`.
3. Em "Development Application Installer", envie o `<nome>_roku.zip` e clique em Install.

Só um canal de desenvolvedor por Roku fica instalado por vez. Para distribuir
(canal público ou não listado), publique no **Roku Developer Dashboard**.

## Lojas (Samsung / LG / Roku / Google Play)

Todas analisam apps de IPTV com rigor: o app precisa ser um **player sem conteúdo
embutido** (o usuário entra com o próprio acesso). Conteúdo sem licença leva a
recusa ou remoção e pode suspender a conta de desenvolvedor.
