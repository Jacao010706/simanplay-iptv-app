#!/usr/bin/env python3
"""
build_lg_ipk.py
Gera a casca LG (webOS) do revendedor e empacota o .ipk pronto para a LG Content Store,
no mesmo formato do ares-package (debian-binary + control.tar.gz + data.tar.gz).

Uso (na raiz do repositório):
  SLUG=primetv python3 scripts/build_lg_ipk.py            # PrimeTV: com.primetv.app
  SLUG=revenda LG_APP_ID=com.revenda.tv LG_TITLE="Revenda TV" \\
    LG_ICON_URL=https://.../logo.png TV_URL=https://painel-da-revenda/tv \\
    LG_VERSION=1.0.1 python3 scripts/build_lg_ipk.py

Configuração por revendedor: tv_hosted/lg_brands.json (veja scripts/generate_tv_apps.py).
Saída: dist_lg/<app_id>_<versão>_all.ipk
"""
import argparse
import gzip
import io
import json
import os
import sys
import tarfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))


def _tar_gz(entries, mtime):
    """entries: lista de (caminho, bytes ou None para pasta), em ordem."""
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w", format=tarfile.GNU_FORMAT) as tar:
        for path, data in entries:
            info = tarfile.TarInfo(path)
            info.mtime = mtime
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            if data is None:
                info.type = tarfile.DIRTYPE
                info.mode = 0o777
                tar.addfile(info)
            else:
                info.mode = 0o666
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
    out = io.BytesIO()
    with gzip.GzipFile(fileobj=out, mode="wb", mtime=mtime) as gz:
        gz.write(raw.getvalue())
    return out.getvalue()


def _ar(members, mtime):
    """Arquivo 'ar' (formato do .ipk/.deb): membros (nome, bytes)."""
    out = io.BytesIO()
    out.write(b"!<arch>\n")
    for name, data in members:
        header = (f"{name:<16}{mtime:<12}{0:<6}{0:<6}{'100644':<8}{len(data):<10}`\n").encode("ascii")
        assert len(header) == 60
        out.write(header)
        out.write(data)
        if len(data) % 2:
            out.write(b"\n")
    return out.getvalue()


def pack_ipk(app_dir, out_dir, mtime=None):
    """Empacota a pasta do app (com appinfo.json) em <id>_<versão>_all.ipk."""
    with open(os.path.join(app_dir, "appinfo.json"), encoding="utf-8") as f:
        info = json.load(f)
    app_id, version = info["id"], info["version"]
    mtime = int(time.time()) if mtime is None else int(mtime)

    files = []
    for root, dirs, names in os.walk(app_dir):
        dirs.sort()
        for n in sorted(names):
            full = os.path.join(root, n)
            rel = os.path.relpath(full, app_dir).replace(os.sep, "/")
            with open(full, "rb") as f:
                files.append((rel, f.read()))
    for rel, _ in files:
        if rel.split("/")[0] in ("..", "") or rel.startswith("/"):
            raise SystemExit(f"caminho inválido no app: {rel}")

    app_base = f"usr/palm/applications/{app_id}"
    pkg_base = f"usr/palm/packages/{app_id}"
    packageinfo = json.dumps({"id": app_id, "version": version, "app": app_id}, indent=2).encode("utf-8")

    subdirs = sorted({"/".join(rel.split("/")[:i]) for rel, _ in files for i in range(1, rel.count("/") + 1)})
    entries = [("usr", None), ("usr/palm", None), ("usr/palm/applications", None),
               ("usr/palm/packages", None), (app_base, None), (pkg_base, None)]
    entries += [(f"{app_base}/{d}", None) for d in subdirs]
    entries += [(f"{app_base}/{rel}", data) for rel, data in files]
    entries.append((f"{pkg_base}/packageinfo.json", packageinfo))

    installed = sum(len(d) for _, d in files) + len(packageinfo)
    control = (
        f"Package: {app_id}\n"
        f"Version: {version}\n"
        "Section: misc\n"
        "Priority: optional\n"
        "Architecture: all\n"
        f"Installed-Size: {installed}\n"
        "Maintainer: N/A <nobody@example.com>\n"
        "Description: This is a webOS application.\n"
        "webOS-Package-Format-Version: 2\n"
        "webOS-Packager-Version: x.y.x\n"
    ).encode("utf-8")

    ipk = _ar([
        ("debian-binary", b"2.0\n"),
        ("control.tar.gz", _tar_gz([("control", control)], mtime)),
        ("data.tar.gz", _tar_gz(entries, mtime)),
    ], mtime)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"{app_id}_{version}_all.ipk")
    with open(out, "wb") as f:
        f.write(ipk)
    return out, info


def main(argv=None):
    ap = argparse.ArgumentParser(description="Gera e empacota a casca LG (.ipk) do revendedor.")
    ap.add_argument("--out", default="dist_lg", help="pasta de saída (padrão: dist_lg)")
    ap.add_argument("--allow-hosted", action="store_true",
                    help="no modo packaged, aceita o lançador se o app de TV não puder ser baixado")
    args = ap.parse_args(argv)

    sys.path.insert(0, HERE)
    import generate_tv_apps as gen  # lê as variáveis de ambiente ao importar

    gen.build_lg(require_packaged=not args.allow_hosted)
    out, info = pack_ipk(os.path.join(gen.OUT, "lg"), args.out)
    print(f"LG pronto: {out}  (id {info['id']}, título {info['title']!r}, versão {info['version']}, "
          f"{info['resolution']}, modo {gen.lg_mode()})")
    return out


if __name__ == "__main__":
    main()
