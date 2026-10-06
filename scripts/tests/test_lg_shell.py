"""Casca LG (webOS) white-label: scripts/generate_tv_apps.py + scripts/build_lg_ipk.py.

    pip install pillow pytest
    pytest scripts/tests/test_lg_shell.py
"""
import importlib
import io
import json
import os
import sys
import tarfile

import pytest
from PIL import Image

SCRIPTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(SCRIPTS)
BRAND_DIR = os.path.join(REPO, "tv_hosted", "lg_brands", "primetv")
sys.path.insert(0, SCRIPTS)

HLS = "https://cdn.jsdelivr.net/npm/hls.js@1.5.13/dist/hls.min.js"
FAKE_TV = (
    "<!DOCTYPE html><html><head><title>TV</title></head><body>"
    '<div id="app">MAC</div>'
    '<script src="/tv/qrcode.js"></script>'
    f'<script src="{HLS}"></script>'
    "<script>init();</script></body></html>"
)

LG_VARS = ("SLUG", "APP_NAME", "LOGO_URL", "TV_URL", "GITHUB_RUN_NUMBER", "LG_APP_ID", "LG_TITLE",
           "LG_ICON_URL", "LG_BG_URL", "LG_RESOLUTION", "LG_VERSION", "LG_MIN_VERSION", "LG_VENDOR",
           "LG_MODE", "PRIMARY_HEX", "BG_HEX")


@pytest.fixture
def gerar(tmp_path, monkeypatch):
    src = tmp_path / "tv_src"
    src.mkdir()
    (src / "index.html").write_text(FAKE_TV, encoding="utf-8")
    (src / "qrcode.js").write_bytes(b"// qrcode")
    monkeypatch.chdir(tmp_path)
    for v in LG_VARS:
        monkeypatch.delenv(v, raising=False)
    monkeypatch.setenv("TV_SRC_DIR", str(src))
    monkeypatch.setenv("GITHUB_RUN_NUMBER", "126")

    def run(**env):
        for k, v in env.items():
            monkeypatch.setenv(k, v)
        import generate_tv_apps
        gen = importlib.reload(generate_tv_apps)
        baixados = []

        def fake_fetch(url):
            baixados.append(url)
            if url == HLS:
                return b"// hls"
            if url.endswith(".png"):
                buf = io.BytesIO()
                Image.new("RGBA", (300, 200), (255, 0, 0, 255)).save(buf, "PNG")
                return buf.getvalue()
            raise OSError("sem rede no teste")

        monkeypatch.setattr(gen, "fetch", fake_fetch)
        gen._PACKAGED.clear()
        info = gen.build_lg(require_packaged=True)
        app = tmp_path / "build_tv" / "lg"
        gen.baixados = baixados
        return gen, info, app

    return run


def _brand(name):
    with open(os.path.join(BRAND_DIR, name), "rb") as f:
        return f.read()


def test_primetv_usa_id_titulo_e_icones_do_app_enviado(gerar):
    gen, info, app = gerar(SLUG="primetv", APP_NAME="PRIMETV")
    assert info["id"] == "com.primetv.app"
    assert info["title"] == "PrimeTV"
    assert info["vendor"] == "Akitemtech"
    assert info["icon"] == "icon.png" and info["largeIcon"] == "largeIcon.png" and info["bgImage"] == "bgImage.png"
    assert info["iconColor"] == "#0d0b14", "mesma cor de fundo do app enviado"
    # Mesmos ícones do .ipk 1.0.100 enviado à LG (byte a byte)
    for f in ("icon.png", "largeIcon.png", "bgImage.png"):
        assert (app / f).read_bytes() == _brand(f), f
    assert json.loads((app / "appinfo.json").read_text(encoding="utf-8")) == info


def test_versao_maior_que_a_enviada(gerar):
    gen, info, _ = gerar(SLUG="primetv")
    assert info["version"] == "1.1.126"
    assert gen.parse_version(info["version"]) > gen.parse_version("1.0.100")
    # A partir do run 1000 a versão continua crescendo (sem voltar a 1.0.0)
    gen2, info2, _ = gerar(SLUG="primetv", GITHUB_RUN_NUMBER="1003")
    assert info2["version"] == "1.2.3"


def test_versao_menor_ou_igual_a_enviada_falha(gerar):
    with pytest.raises(SystemExit, match="maior que a última enviada"):
        gerar(SLUG="primetv", LG_VERSION="1.0.100")
    with pytest.raises(SystemExit, match="maior que a última enviada"):
        gerar(SLUG="primetv", LG_VERSION="1.0.99")
    _, info, _ = gerar(SLUG="primetv", LG_VERSION="1.0.101")
    assert info["version"] == "1.0.101"
    with pytest.raises(SystemExit, match="versão inválida"):
        gerar(SLUG="primetv", LG_VERSION="1.0.1000")


def test_funciona_nas_duas_resolucoes(gerar):
    _, info, app = gerar(SLUG="primetv", LG_MODE="packaged")
    assert info["resolution"] == "1920x1080"
    page = (app / "index.html").read_text(encoding="utf-8")
    # Ajuste de tela antes de </body>: reduz o layout 1920x1080 em telas 1280x720
    assert "Math.min(window.innerWidth/1920, window.innerHeight/1080)" in page
    assert page.index("d.style.zoom=s") < page.index("window.PRIMETV_BRAND="), "ajuste antes dos scripts do app"
    assert "d.style.zoom='';" in page, "zera o zoom antes de medir (sem somar escalas no resize)"
    _, info720, app720 = gerar(SLUG="primetv", LG_RESOLUTION="1280x720")
    assert info720["resolution"] == "1280x720"
    assert "window.innerWidth/1920" in (app720 / "index.html").read_text(encoding="utf-8")
    with pytest.raises(SystemExit, match="resolução inválida"):
        gerar(SLUG="primetv", LG_RESOLUTION="3840x2160")


def test_app_empacotado_com_scripts_locais_e_marca(gerar):
    _, _, app = gerar(SLUG="primetv", APP_NAME="PRIMETV", LG_MODE="packaged")
    page = (app / "index.html").read_text(encoding="utf-8")
    assert '<script src="qrcode.js"></script>' in page and '<script src="hls.min.js"></script>' in page
    assert "/tv/qrcode.js" not in page and HLS not in page
    assert "window.PRIMETV_BRAND=" in page
    assert (app / "qrcode.js").read_bytes() == b"// qrcode"
    assert (app / "hls.min.js").read_bytes() == b"// hls"


def test_white_label_de_outro_revendedor_por_variaveis(gerar):
    _, info, app = gerar(
        SLUG="revendax", APP_NAME="Revenda X",
        LG_APP_ID="com.revendax.tv", LG_TITLE="Revenda X TV",
        LG_ICON_URL="https://cdn.revendax.com/icone.png", TV_URL="https://painel.revendax.com/tv",
        LG_VERSION="1.0.1", LG_VENDOR="Revenda X Ltda",
    )
    assert info["id"] == "com.revendax.tv"
    assert info["title"] == "Revenda X TV"
    assert info["vendor"] == "Revenda X Ltda"
    assert info["version"] == "1.0.1"
    assert Image.open(app / "icon.png").size == (80, 80)
    assert Image.open(app / "largeIcon.png").size == (130, 130)
    assert Image.open(app / "bgImage.png").size == (1920, 1080)
    assert (app / "icon.png").read_bytes() != _brand("icon.png")


def test_revendedor_sem_configuracao_usa_padrao_pelo_slug(gerar):
    _, info, _ = gerar(SLUG="loja2", APP_NAME="Loja Dois")
    assert info["id"] == "com.primetv.loja2"
    assert info["title"] == "Loja Dois"


def test_url_do_revendedor_vem_do_lg_brands(gerar):
    gen, _, _ = gerar(SLUG="primetv")
    assert gen.TV_URL == "https://simanplay-iptv-admin-panel.vercel.app/tv"
    gen2, _, _ = gerar(SLUG="primetv", TV_URL="https://outro.painel/tv")
    assert gen2.TV_URL == "https://outro.painel/tv"


def test_id_invalido_e_recusado(gerar):
    with pytest.raises(SystemExit, match="id de app inválido"):
        gerar(SLUG="x", LG_APP_ID="Com.PrimeTV.App")
    with pytest.raises(SystemExit, match="id de app inválido"):
        gerar(SLUG="x", LG_APP_ID="primetv")


def test_sem_app_de_tv_nao_gera_lancador_hospedado(gerar, monkeypatch):
    monkeypatch.setenv("TV_SRC_DIR", "/pasta/que/nao/existe")
    with pytest.raises(SystemExit, match="não consegui baixar o app de TV"):
        gerar(SLUG="primetv", LG_MODE="packaged")


def _read_ar(data):
    assert data[:8] == b"!<arch>\n"
    pos, out = 8, {}
    while pos < len(data):
        hdr = data[pos:pos + 60]
        assert hdr[58:60] == b"`\n"
        name, size = hdr[:16].decode().strip(), int(hdr[48:58])
        out[name] = data[pos + 60:pos + 60 + size]
        pos += 60 + size + (size % 2)
    return out


def test_ipk_no_formato_da_loja(gerar, tmp_path):
    import build_lg_ipk

    _, info, app = gerar(SLUG="primetv", LG_MODE="packaged")
    path, packed = build_lg_ipk.pack_ipk(str(app), str(tmp_path / "dist"), mtime=1790000000)
    assert os.path.basename(path) == "com.primetv.app_1.1.126_all.ipk"
    assert packed == info

    members = _read_ar(open(path, "rb").read())
    assert list(members) == ["debian-binary", "control.tar.gz", "data.tar.gz"]
    assert members["debian-binary"] == b"2.0\n"

    control = tarfile.open(fileobj=io.BytesIO(members["control.tar.gz"])).extractfile("control").read().decode()
    assert "Package: com.primetv.app\n" in control
    assert "Version: 1.1.126\n" in control
    assert "Architecture: all\n" in control

    data = tarfile.open(fileobj=io.BytesIO(members["data.tar.gz"]))
    names = data.getnames()
    base = "usr/palm/applications/com.primetv.app"
    for f in ("appinfo.json", "index.html", "icon.png", "largeIcon.png", "bgImage.png", "qrcode.js", "hls.min.js"):
        assert f"{base}/{f}" in names, f
    pkginfo = json.loads(data.extractfile("usr/palm/packages/com.primetv.app/packageinfo.json").read())
    assert pkginfo == {"id": "com.primetv.app", "version": "1.1.126", "app": "com.primetv.app"}
    assert data.extractfile(f"{base}/icon.png").read() == _brand("icon.png")
    assert json.loads(data.extractfile(f"{base}/appinfo.json").read())["title"] == "PrimeTV"


def test_main_gera_o_ipk(gerar, tmp_path):
    import build_lg_ipk

    gerar(SLUG="primetv")  # carrega o gerador com as variáveis e o fetch falso; main() reaproveita
    out = build_lg_ipk.main(["--out", str(tmp_path / "saida")])
    assert out.endswith("com.primetv.app_1.1.126_all.ipk") and os.path.exists(out)


# ── Modo "pela URL" (padrão da casca): as telas vêm do /tv do painel ──

def _launcher_target(page):
    import re
    m = re.search(r'var TARGET = "([^"]+)";', page)
    assert m, "lançador sem TARGET"
    return m.group(1)


def test_casca_carrega_as_telas_da_url_do_painel(gerar):
    gen, info, app = gerar(SLUG="primetv", APP_NAME="PRIMETV")
    assert gen.lg_mode() == "hosted"
    # Mantém id, título, ícones e resolução
    assert info["id"] == "com.primetv.app" and info["title"] == "PrimeTV"
    for f in ("icon.png", "largeIcon.png", "bgImage.png"):
        assert (app / f).read_bytes() == _brand(f), f
    # Só o lançador vai no pacote: nada do /tv nem hls/qrcode
    assert sorted(p.name for p in app.iterdir()) == ["appinfo.json", "bgImage.png", "icon.png", "index.html", "largeIcon.png"]
    assert gen.baixados == [], "no modo pela URL o build não baixa o /tv"
    page = (app / "index.html").read_text(encoding="utf-8")
    alvo = _launcher_target(page)
    assert alvo.startswith("https://simanplay-iptv-admin-panel.vercel.app/tv?")
    for parte in ("name=PRIMETV", "color=e94bff", "bg=0d0b14", "fit=1"):
        assert parte in alvo, parte
    assert "location.replace(TARGET)" in page


def test_casca_mantem_o_ajuste_de_tela(gerar):
    _, _, app = gerar(SLUG="primetv")
    page = (app / "index.html").read_text(encoding="utf-8")
    assert "Math.min(window.innerWidth/1920, window.innerHeight/1080)" in page, "o próprio lançador se ajusta"
    assert "fit=1" in _launcher_target(page), "e pede ao /tv o mesmo ajuste"


def test_tela_sem_conexao_navegavel_pelo_controle(gerar):
    _, _, app = gerar(SLUG="primetv")
    page = (app / "index.html").read_text(encoding="utf-8")
    assert "Sem conexão" in page
    assert 'id="btnRetry"' in page and "Tentar novamente" in page
    assert 'id="btnExit"' in page and "Sair" in page
    assert 'class="btn on" id="btnRetry"' in page, "Tentar novamente já vem selecionado"
    for codigo in ("k === 13", "k === 37", "k === 39", "k === 461"):
        assert codigo in page, f"tecla {codigo} sem tratamento"
    assert ".btn.on{" in page, "botão selecionado precisa de destaque visível"
    assert "setTimeout(retryNow, 30000)" in page, "também tenta sozinho"


def test_url_do_revendedor_na_casca(gerar):
    _, _, app = gerar(SLUG="revendax", APP_NAME="Revenda X", LG_APP_ID="com.revendax.tv",
                      LG_VERSION="1.0.1", TV_URL="https://painel.revendax.com/tv", PRIMARY_HEX="00ff00")
    alvo = _launcher_target((app / "index.html").read_text(encoding="utf-8"))
    assert alvo.startswith("https://painel.revendax.com/tv?")
    assert "name=Revenda+X" in alvo and "color=00ff00" in alvo and "fit=1" in alvo


def test_ipk_da_casca(gerar, tmp_path):
    import build_lg_ipk

    _, info, app = gerar(SLUG="primetv")
    path, _ = build_lg_ipk.pack_ipk(str(app), str(tmp_path / "dist"), mtime=1790000000)
    data = tarfile.open(fileobj=io.BytesIO(_read_ar(open(path, "rb").read())["data.tar.gz"]))
    base = "usr/palm/applications/com.primetv.app"
    arquivos = sorted(n for n in data.getnames() if n.startswith(base + "/"))
    assert arquivos == [f"{base}/{f}" for f in ("appinfo.json", "bgImage.png", "icon.png", "index.html", "largeIcon.png")]


def test_javascript_do_lancador_e_valido(gerar, tmp_path):
    import re
    import shutil
    import subprocess

    node = shutil.which("node")
    if not node:
        pytest.skip("node não instalado")
    _, _, app = gerar(SLUG="primetv")
    page = (app / "index.html").read_text(encoding="utf-8")
    for i, js in enumerate(re.findall(r"<script>(.*?)</script>", page, re.S)):
        f = tmp_path / f"s{i}.js"
        f.write_text(js, encoding="utf-8")
        r = subprocess.run([node, "--check", str(f)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr


def test_lancador_migra_a_identidade_da_1_0_100_por_post(gerar):
    _, _, app = gerar(SLUG="primetv")
    page = (app / "index.html").read_text(encoding="utf-8")
    assert 'var MIG_FLAG = "mig_v1_done";' in page
    assert '/^(dev_|sp_)/' in page, "migra só as chaves do aparelho e do login"
    assert 'f.method = "POST";' in page and '"/api/tv-migrate"' in page, "envia por POST para o painel"
    assert "data: JSON.stringify(data)" in page, "dados no corpo do formulário"
    # A URL do /tv continua só com a marca (nada do aparelho)
    alvo = _launcher_target(page)
    assert "dev_" not in alvo and "sp_" not in alvo
    assert "openApp();" in page, "abre o /tv (ou migra) depois de conferir a conexão"


def test_voltar_na_entrada_usa_o_platformback_da_lg(gerar):
    _, _, app = gerar(SLUG="primetv")
    page = (app / "index.html").read_text(encoding="utf-8")
    i_web, i_palm, i_close = page.index("webOS.platformBack()"), page.index("PalmSystem.platformBack()"), page.index("window.close()")
    assert i_web < i_palm < i_close, "platformBack (popup de saída/Home) antes do window.close"
    assert "k === 461" in page

