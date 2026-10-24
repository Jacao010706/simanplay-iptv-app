# Capturas de tela do celular (Google Play)

4 capturas de celular 1080x1920 (9:16) e 3 de Android TV 1920x1080 (16:9), PNG 24 bits sem alfa, geradas em 24/10/2026 a partir das **telas
reais** da variante `play` (mesmo código do app), num teste de widget com as fontes do Android
(Roboto). Só a demonstração: filmes abertos da Blender Foundation (Creative Commons). Sem dados
reais, sem credenciais; o código do aparelho é fictício.

| Arquivo | Tela |
|---|---|
| `celular-1-codigo-do-aparelho.png` | Aparelho sem acesso: código, "Verificar novamente" e "Ver demonstração" |
| `celular-2-inicio-demonstracao.png` | Início da demonstração |
| `celular-3-filmes-abertos.png` | Filmes abertos da Blender |
| `celular-4-tv-ao-vivo-demonstracao.png` | TV ao vivo da demonstração (favoritos e busca) |

| `tv-1-codigo-do-aparelho.png` | TV: aparelho sem acesso (código e demonstração) |
| `tv-2-inicio.png` | TV: tela de 4 blocos da Sofae, foco do controle em "TV ao Vivo" |
| `tv-3-filmes-abertos.png` | TV: filmes abertos da Blender |

Ordem sugerida na Play: celular 2, 3, 4, 1; TV 2, 3, 1.

Diferenças em relação a um print do aparelho: não há barra de status do Android, e o símbolo ⭐
usa a fonte de emoji do Windows (no aparelho, usa a do sistema).

## Gerar de novo
```
flutter test tool/capturas/capturas_play_test.dart --flavor play
```
O teste só deixa a rede aberta para o Wikimedia Commons (capas da demonstração): o servidor de
licença fica inalcançável e o teste para se conseguir falar com ele. Saída em `capturas/bruto/`
(PNG com alfa). Para converter para PNG 24 bits (exigência da Play), no PowerShell:
```powershell
Add-Type -AssemblyName System.Drawing
$base = "D:\projetos\simanplay-iptv\simanplay-iptv-app\store\google-play\capturas"
Get-ChildItem "$base\bruto" -Filter *.png | ForEach-Object {
  $s = [System.Drawing.Image]::FromFile($_.FullName)
  $b = New-Object System.Drawing.Bitmap($s.Width, $s.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($b); $g.DrawImage($s, 0, 0, $s.Width, $s.Height); $g.Dispose(); $s.Dispose()
  $n = if ($_.Name -like 'tv-*') { $_.Name } else { "celular-$($_.Name)" }
  $b.Save("$base\$n", [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
}
```

## Se preferir prints do aparelho
Instale a versão de teste, abra a demonstração e tire os prints das mesmas 4 telas (botões de
volume para baixo + liga). Nunca use listas reais.
