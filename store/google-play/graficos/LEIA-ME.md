# Gráficos da Google Play (Sofae)

Gerados em 23/10/2026 a partir dos assets da marca (nada de imagens de filmes, canais ou times).

| Gráfico | Exigência da Play | Arquivo | Estado |
|---|---|---|---|
| Ícone do app | 512x512, PNG 32 bits, até 1 MB | `icone-512.png` (de `admin-panel/public/sofae/icone.png`, mesmo desenho do ícone do app) | ✅ pronto |
| Imagem de destaque | 1024x500, JPG ou PNG 24 bits sem alfa | `destaque-1024x500.png` (logo horizontal sobre o roxo da marca) | ✅ pronto |
| Capturas de celular | **mínimo 2**, até 8; 16:9 ou 9:16; lado entre 320 e 3840 px | `../capturas/celular-*.png` (4, 1080x1920) | ✅ prontas (24/10/2026) |
| Capturas de tablet 7" e 10" | opcionais | — | opcional |
| Banner de Android TV | 1280x720, JPG ou PNG 24 bits | `banner-tv-1280x720.png` (o mesmo `tv_banner` do app) | ✅ pronto (só se ativar Android TV) |
| Capturas de Android TV | **mínimo 1** para distribuir em TV | `../capturas/tv-*.png` (3, 1920x1080) | ✅ prontas (24/10/2026) |

**Atenção:** `store/android/icone-512.png` é o ícone do **PRIMETV**, não da Sofae. Não use.
As capturas em `store/lg-tv`, `store/samsung-tv` e `store/roku` são do app web das TVs (outro
app, e algumas mostram a tela de renovar/pagar): **não servem** para a Play.

## Capturas de celular
Geradas a partir das telas reais da variante play: ver `../capturas/LEIA-ME.md`.
