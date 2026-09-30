# Apps de Smart TV — PRIMETV

Todo build do painel ("Gerar APK") produz, além do APK, os apps de TV com o nome,
as cores e a logo do revendedor. O nome padrão é **PRIMETV**.

| Plataforma | Arquivo gerado | Como funciona |
|---|---|---|
| Android TV / TV Box / Fire TV | `<nome>.apk` | O mesmo app do celular; aparece no menu da TV (Leanback) |
| Samsung (Tizen 2.3+, TVs de 2015 em diante) | `<nome>_samsung_nao_assinado.wgt` | App **empacotado**: todas as telas dentro do .wgt |
| LG (webOS 1.0+, TVs de 2014 em diante) | `<nome>_lg.ipk` | App **empacotado**: todas as telas dentro do .ipk |
| Roku (qualquer Roku com SceneGraph) | `<nome>_roku.zip` | Canal nativo (BrightScript): mesmas telas, grade com Favoritos (botão ✱) |

Todos seguem o mesmo fluxo: a tela inicial mostra o **MAC** e a **chave** do aparelho
(gerados pelo sistema) e um QR Code para `/dispositivo`, onde o cliente cadastra as
listas; o revendedor ativa pelo MAC no painel. Depois: grade TV ao Vivo, Filmes,
Séries e Favoritos. Com a licença vencida aparece o QR Code do PIX ("Acesse o site para renovar").

- **Samsung e LG:** apps **empacotados** (as lojas recusam apps que só abrem um site). O build
  baixa o app de TV do painel (`public/tv/index.html` + `qrcode.js`) e o `hls.min.js` e coloca
  tudo dentro do `.wgt` e do `.ipk` (`scripts/generate_tv_apps.py`). Mudanças no `/tv` só
  chegam às TVs numa versão nova do pacote. A versão no navegador (`/tv`) continua igual.

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

#### Publicar na LG Content Store (LG Seller Lounge)
O `.ipk` já sai pronto para envio: a LG **não** exige assinatura do desenvolvedor
(ela assina na publicação).
1. Crie a conta em `seller.lgappstv.com` (LG Seller Lounge) e complete o cadastro de
   vendedor (a LG pode pedir dados de empresa/CNPJ).
2. **Apps > App Registration** > tipo **Web App**, id `com.primetv.app`, e envie o `.ipk`.
3. Preencha:
   - nome **PRIMETV**, categoria **Entertainment/Video**, países Brasil, idioma Português;
   - ícones 80x80 e 130x130 (já estão dentro do `.ipk`) e capturas 1920x1080;
   - **Política de privacidade:** `https://simanplay-iptv-admin-panel.vercel.app/privacidade`;
   - vendedor/desenvolvedor: **Akitemtech**, suporte `akitemtech@gmail.com`.
4. **Instruções para os testadores** (as mesmas da Samsung): o app não traz canais; ao abrir
   mostra MAC e chave; em `simanplay-iptv-admin-panel.vercel.app/dispositivo` digite o MAC e a
   chave e adicione a lista pública `https://iptv-org.github.io/iptv/countries/br.m3u`.
5. A LG testa com controle comum e Magic Remote; a análise costuma levar de 2 a 6 semanas.

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
#### Publicar na Samsung (Seller Office — apps de TV)
A loja de TVs é o **Samsung Apps TV Seller Office** (`seller.samsungapps.com/tv`), não a
Galaxy Store (que é de celular).
1. Crie a conta no Seller Office e peça a parceria de **distribuição** (a Samsung pode
   pedir dados de empresa/CNPJ e leva alguns dias para aprovar).
2. No Tizen Studio, crie o certificado **Samsung** com privilégio **Public** para
   distribuição e assine o `.wgt` (passo 4 acima, sem DUID de TV).
3. Em **Applications > Create App**, preencha:
   - nome **PRIMETV**, categoria **Video**, idioma Português;
   - ícone 512x423 (já está dentro do `.wgt`) e capturas 1920x1080;
   - **Política de privacidade:** `https://simanplay-iptv-admin-panel.vercel.app/privacidade`;
   - envie o `.wgt` **assinado**.
4. **Instruções para os revisores** (sem isso o app é recusado por "não funciona"):
   "O PRIMETV é um player: não traz canais. Ao abrir, o app mostra o MAC e a chave.
   Acesse simanplay-iptv-admin-panel.vercel.app/dispositivo, digite o MAC e a chave e
   adicione a lista M3U de teste https://iptv-org.github.io/iptv/countries/br.m3u
   (canais abertos, públicos). Em até 20 s a lista aparece na TV."
5. A Samsung testa em TVs de vários anos; a análise costuma levar de 2 a 4 semanas.

### Roku
1. No controle da Roku: Home 3x, Cima 2x, Direita, Esquerda, Direita, Esquerda,
   Direita. Ative o **Developer Mode** e defina uma senha.
2. No navegador do computador abra `http://<IP_DA_ROKU>`, usuário `rokudev`.
3. Em "Development Application Installer", envie o `<nome>_roku.zip` e clique em Install.

Só um canal de desenvolvedor por Roku fica instalado por vez. Para distribuir
(canal público ou não listado), publique no **Roku Developer Dashboard**.

No canal: setas + OK na grade; na lista de canais ao vivo o botão **✱** (asterisco)
liga/desliga o favorito; Voltar na tela inicial fecha o canal.

#### Publicar na Roku Channel Store
A Roku **não aceita o .zip**: ele vira um pacote assinado (.pkg) gerado **num Roku seu**.
1. Instale o `<nome>_roku.zip` no Roku em modo desenvolvedor (passos acima).
2. No computador: `telnet <IP_DA_ROKU> 8080` e digite `genkey`. Anote a **senha** e o
   **DevID** que aparecem — guarde junto com a chave do APK: toda atualização do canal
   precisa ser assinada com a mesma chave (para usar em outro Roku: `rekey`).
3. No navegador, `http://<IP_DA_ROKU>` > **Packager**: nome PRIMETV, a senha do `genkey` >
   **Package** e baixe o `.pkg`.
4. Em `developer.roku.com` > **Manage Channels** > **Add Channel** (tipo SDK):
   - envie o `.pkg`; pôster do canal 540x405 (FHD) e 290x218 (HD) — os mesmos de
     `roku_channel/images/icon_focus_*.png`;
   - **Política de privacidade:** `https://simanplay-iptv-admin-panel.vercel.app/privacidade`;
   - instruções para os testadores iguais às da Samsung/LG (MAC + chave + lista pública).
5. A certificação da Roku costuma levar de 1 a 4 semanas.

**Atenção (política da Roku):** a Roku exige o **Roku Pay** para assinaturas oferecidas
dentro do canal. O PRIMETV manda pagar por PIX no site (QR Code), então a publicação
**pública** pode ser recusada por isso. Alternativas: canal **beta** (até 20 aparelhos,
por link, sem loja) ou publicar como player gratuito e cobrar a assinatura só fora
da Roku (pelo revendedor). Verifique as regras atuais no Developer Dashboard antes de enviar.

## Lojas (Samsung / LG / Roku / Google Play)

Todas analisam apps de IPTV com rigor: o app precisa ser um **player sem conteúdo
embutido** (o usuário entra com o próprio acesso). Conteúdo sem licença leva a
recusa ou remoção e pode suspender a conta de desenvolvedor.
