# Gráficos da Google Play (Sofae)

Gerados em 23/10/2026 a partir dos assets da marca (nada de imagens de filmes, canais ou times).

| Gráfico | Exigência da Play | Arquivo | Estado |
|---|---|---|---|
| Ícone do app | 512x512, PNG 32 bits, até 1 MB | `icone-512.png` (de `admin-panel/public/sofae/icone.png`, mesmo desenho do ícone do app) | ✅ pronto |
| Imagem de destaque | 1024x500, JPG ou PNG 24 bits sem alfa | `destaque-1024x500.png` (logo horizontal sobre o roxo da marca) | ✅ pronto |
| Capturas de celular | **mínimo 2**, até 8; 16:9 ou 9:16; lado entre 320 e 3840 px | — | ❌ **faltam** (ver abaixo) |
| Capturas de tablet 7" e 10" | opcionais | — | opcional |
| Banner de Android TV | 1280x720, JPG ou PNG 24 bits | `banner-tv-1280x720.png` (o mesmo `tv_banner` do app) | ✅ pronto (só se ativar Android TV) |
| Capturas de Android TV | **mínimo 1** para distribuir em TV | — | ❌ faltam (só se ativar Android TV) |

**Atenção:** `store/android/icone-512.png` é o ícone do **PRIMETV**, não da Sofae. Não use.
As capturas em `store/lg-tv`, `store/samsung-tv` e `store/roku` são do app web das TVs (outro
app, e algumas mostram a tela de renovar/pagar): **não servem** para a Play.

## Capturas de celular: como tirar (não dá para gerar sem um aparelho)
Não há emulador nem celular ligado neste PC, e capturas montadas não mostrariam o app de verdade.
Instale o AAB do teste fechado (ou o APK de debug `--flavor play`) num celular e tire de 4 a 6
capturas em pé (9:16), **usando só a demonstração**:

1. Tela de ativação com o código do aparelho (MAC) e o botão "Ver demonstração".
2. Início da demonstração (tela inicial do tema Sofae).
3. Filmes da demonstração (pôsteres da Blender: são Creative Commons, podem aparecer).
4. Um filme da demonstração tocando no player.
5. TV ao Vivo da demonstração.
6. (Opcional) Tela de Xtream/M3U vazia, sem dados de ninguém.

Nunca use listas reais: nada de logos de emissoras, pôsteres de filmes comerciais ou escudos.
Salve aqui como `celular-1.png` … `celular-6.png`.
