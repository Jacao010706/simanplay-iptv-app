#!/usr/bin/env python3
"""Conferências da versão de loja (Sofae na Google Play e na Amazon). Falha (exit 1) se:
- o pacote não for com.sofae.app;
- aparecer permissão de instalar APK, serviço em primeiro plano, notificação ou wake lock;
- o código do app (libapp.so) tiver textos de pagamento, teste grátis ou assinatura.
Uso: conferir-loja.py <arquivo .aab ou .apk> <manifesto_em_texto_ou_vazio>
O manifesto do APK vem em texto (aapt2 dump); o do AAB é protobuf e é lido em bytes.
"""
import sys
import zipfile

PACOTE = b"com.sofae.app"
PERMISSOES_PROIBIDAS = [
    "android.permission.REQUEST_INSTALL_PACKAGES",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.WAKE_LOCK",
]
# Textos das telas de pagamento/licença do APK do painel (não podem ir para a loja)
TEXTOS_PROIBIDOS = [
    "Pagar pelo site",
    "assine um plano pelo site com PIX",
    "Teste grátis",
    "teste grátis terminou",
    "Ainda não identificamos o pagamento",
    "Sua assinatura expirou",
    "Assinatura expirada",
    "Sua assinatura venceu",
]
# Texto que precisa estar lá (prova de que a busca no libapp.so funciona)
TEXTO_OBRIGATORIO = "O Sofae é um player"


def codificacoes(texto):
    # O snapshot do Dart guarda strings de 1 byte em Latin-1 e as outras em UTF-16
    out = []
    for enc in ("utf-8", "latin-1", "utf-16-le"):
        try:
            out.append(texto.encode(enc))
        except UnicodeEncodeError:
            pass
    return out


def main():
    caminho = sys.argv[1]
    manifesto_texto = open(sys.argv[2], encoding="utf-8").read() if len(sys.argv) > 2 and sys.argv[2] else ""
    erros = []
    z = zipfile.ZipFile(caminho)
    nomes = z.namelist()

    if caminho.endswith(".aab"):
        manifesto = z.read("base/manifest/AndroidManifest.xml")
        libs = [n for n in nomes if n.startswith("base/lib/") and n.endswith("/libapp.so")]
    else:
        manifesto = manifesto_texto.encode()
        libs = [n for n in nomes if n.startswith("lib/") and n.endswith("/libapp.so")]

    if PACOTE not in manifesto:
        erros.append("pacote com.sofae.app não encontrado no manifesto")
    for p in PERMISSOES_PROIBIDAS:
        if p.encode() in manifesto:
            erros.append(f"permissão proibida no manifesto: {p}")

    if not libs:
        erros.append("libapp.so não encontrado")
    for lib in libs:
        dados = z.read(lib)
        if not any(c in dados for c in codificacoes(TEXTO_OBRIGATORIO)):
            erros.append(f"{lib}: texto de referência ausente (a busca não está funcionando)")
        for t in TEXTOS_PROIBIDOS:
            if any(c in dados for c in codificacoes(t)):
                erros.append(f"{lib}: texto de pagamento/licença encontrado: \"{t}\"")

    print(f"{caminho}: {len(libs)} libapp.so conferido(s)")
    if erros:
        for e in erros:
            print(f"::error::{e}")
        sys.exit(1)
    print("ok: com.sofae.app, sem permissões proibidas, sem textos de pagamento")


if __name__ == "__main__":
    main()
