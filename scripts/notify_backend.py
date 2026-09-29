#!/usr/bin/env python3
"""
notify_backend.py
Avisa o backend SimanPlay sobre o andamento do build (JSON montado com json.dumps,
sem interpolar texto do usuário no shell).

Uso:
  python notify_backend.py progress <plataforma> <status>
  python notify_backend.py complete <success|error>

Lê de ambiente: API_URL, RESELLER_ID, APP_NAME, RELEASE_URL e DL_<PLATAFORMA>.
Falhas de rede não derrubam o build.
"""
import json
import os
import sys
import urllib.request

api = os.environ.get("API_URL", "").rstrip("/")
reseller_id = os.environ.get("RESELLER_ID", "")
if not api or not reseller_id:
    print("Sem API_URL/RESELLER_ID: notificação ignorada")
    sys.exit(0)

kind = sys.argv[1]
if kind == "progress":
    path = "/api/builds/progress"
    body = {"resellerId": reseller_id, "platform": sys.argv[2], "status": sys.argv[3]}
else:
    path = "/api/builds/complete"
    status = sys.argv[2]
    downloads = {}
    for plat in ("android", "googleplay", "ios", "windows", "roku", "samsung", "lg"):
        v = os.environ.get(f"DL_{plat.upper()}", "")
        if v:
            downloads[plat] = v
    body = {
        "resellerId": reseller_id,
        "appName": os.environ.get("APP_NAME", ""),
        "status": status,
        "releaseUrl": os.environ.get("RELEASE_URL", "") or None,
        "downloads": downloads if status == "success" else None,
    }

req = urllib.request.Request(api + path, data=json.dumps(body).encode("utf-8"),
                             headers={"Content-Type": "application/json"}, method="POST")
try:
    with urllib.request.urlopen(req, timeout=20) as r:
        print(path, r.status, r.read(300).decode("utf-8", "replace"))
except Exception as e:
    print(f"Aviso: notificação {path} falhou: {e}")
