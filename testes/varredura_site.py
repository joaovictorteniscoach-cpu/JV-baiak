"""Varredura do site: todas as paginas, downloads (PC e Android) e arquivos do jogo no navegador.

Uso: python varredura_site.py <url-do-site> <pasta-saida> [--com-jogar]
Cria tambem uma conta de teste (como um jogador) e grava em <pasta>/conta.json.
"""
import http.cookiejar
import io
import json
import os
import random
import re
import string
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

SITE = sys.argv[1].rstrip("/")
SAIDA = sys.argv[2]
COM_JOGAR = "--com-jogar" in sys.argv
os.makedirs(SAIDA, exist_ok=True)
resultado = {"site": SITE, "itens": [], "ok": True}
jar = http.cookiejar.CookieJar()
web = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
web.addheaders = [("User-Agent", "Mozilla/5.0 (JV Baiak robo de teste)")]


def anota(nome, ok, **info):
    resultado["itens"].append({"item": nome, "ok": bool(ok), **info})
    if not ok:
        resultado["ok"] = False
    print(("OK   " if ok else "FALHA"), nome, json.dumps(info, ensure_ascii=False), flush=True)


def baixar(caminho, data=None, limite=60):
    t = time.time()
    try:
        r = web.open(SITE + caminho, data=data, timeout=limite)
        corpo = r.read()
        return r.status, corpo, dict(r.headers), int((time.time() - t) * 1000)
    except urllib.error.HTTPError as e:
        return e.code, e.read(), dict(e.headers), int((time.time() - t) * 1000)
    except Exception as e:  # noqa: BLE001
        return 0, repr(e).encode(), {}, int((time.time() - t) * 1000)


# ---------------------------------------------------------------- paginas
PAGINAS = ["/", "/criar-conta", "/novo-personagem", "/ranking", "/online", "/mortes", "/guilds", "/casas",
           "/servidor", "/conta", "/baixar", "/saude"]
links_internos = set()
for pg in PAGINAS:
    st, corpo, cab, ms = baixar(pg)
    txt = corpo.decode("utf-8", "replace")
    ruim = [m for m in ("Traceback", "Internal Server Error", "jinja2", "UndefinedError") if m in txt]
    anota(f"pagina {pg}", st == 200 and not ruim, status=st, ms=ms, kb=len(corpo) // 1024, erros=ruim or None)
    for href in re.findall(r'(?:href|src)="(/[^"#?]*)', txt):
        links_internos.add(href)

# links que aparecem nas paginas (css, imagens, personagens, guilds...)
for href in sorted(links_internos):
    if href.startswith(("/conta/", "/downloads/", "/jogar")) or href in PAGINAS:
        continue
    st, corpo, cab, ms = baixar(href)
    anota(f"link {href}", st == 200, status=st, ms=ms)

# ------------------------------------------------------------ conta de teste
st, corpo, cab, ms = baixar("/criar-conta")
csrf = re.search(rb'name="csrf" value="([^"]+)"', corpo)
letras, vogais = "bcdfgjklmnprstvz", "aeiou"
nome = "Robo " + "".join(random.choice(letras) + random.choice(vogais) for _ in range(3)).capitalize()
conta = "robo" + "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(8))
senha = "".join(random.choice(string.ascii_letters + string.digits) for _ in range(12))
if csrf:
    dados = urllib.parse.urlencode(dict(csrf=csrf.group(1).decode(), conta=conta, senha=senha, senha2=senha,
                                        email="", personagem=nome, vocacao="4", sexo="1")).encode()
    st, corpo, cab, ms = baixar("/criar-conta", data=dados)
    criada = "Tudo certo" in corpo.decode("utf-8", "replace")
else:
    criada = False
anota("criar conta pelo site", criada, status=st, ms=ms, conta=conta)
with open(os.path.join(SAIDA, "conta.json"), "w") as f:
    json.dump({"conta": conta, "senha": senha, "personagem": nome, "criada": criada}, f)

if criada:
    dados = urllib.parse.urlencode(dict(csrf=csrf.group(1).decode(), conta=conta, senha=senha)).encode()
    st, corpo, cab, ms = baixar("/conta")
    c2 = re.search(rb'name="csrf" value="([^"]+)"', corpo)
    if c2:
        dados = urllib.parse.urlencode(dict(csrf=c2.group(1).decode(), conta=conta, senha=senha)).encode()
        st, corpo, cab, ms = baixar("/conta", data=dados)
        anota("entrar em Minha conta", st == 200 and nome.encode() in corpo, status=st, ms=ms)
    st, corpo, cab, ms = baixar("/personagem?nome=" + urllib.parse.quote(nome))
    anota("pagina do personagem novo", st == 200 and nome.encode() in corpo, status=st, ms=ms)

# ---------------------------------------------------------------- downloads
st, corpo, cab, ms = baixar("/baixar")
arquivos = sorted(set(re.findall(rb'/downloads/([A-Za-z0-9.-]+\.(?:apk|zip))', corpo)))
anota("links de download na pagina", len(arquivos) >= 2, arquivos=[a.decode() for a in arquivos])
endereco = urllib.parse.urlparse(SITE).hostname
for a in arquivos:
    a = a.decode()
    st, corpo, cab, ms = baixar("/downloads/" + a, limite=300)
    ok = st == 200 and len(corpo) > 1_000_000
    info = {"status": st, "mb": round(len(corpo) / 1e6, 1), "s": round(ms / 1000, 1)}
    if ok:
        with open(os.path.join(SAIDA, a), "wb") as f:
            f.write(corpo)
        try:
            z = zipfile.ZipFile(io.BytesIO(corpo))
            ruim = z.testzip()
            nomes = z.namelist()
            if a.endswith(".apk"):
                interno = zipfile.ZipFile(io.BytesIO(z.read("assets/data.zip")))
                init = interno.read("init.lua").decode("latin-1")
                info["tem_sprites_860"] = any("things/860/Tibia.spr" in n for n in interno.namelist())
                info["assinado"] = any(n.startswith("META-INF/") for n in nomes)
            else:
                init = z.read([n for n in nomes if n.endswith("/init.lua") and n.count("/") == 1][0]).decode("latin-1")
                info["tem_sprites_860"] = any("things/860/Tibia.spr" in n for n in nomes)
                info["exe"] = [n.split("/")[-1] for n in nomes if n.endswith(".exe")]
            servidores = re.findall(r'"([A-Za-z0-9.-]+:7171:860)"', init)
            info["servidor_no_cliente"] = servidores
            info["zip_integro"] = ruim is None
            ok = ruim is None and info["tem_sprites_860"] and any(s.split(":")[0] in (endereco,) or
                                                                 re.match(r"\d+\.\d+\.\d+\.\d+", s) for s in servidores)
        except Exception as e:  # noqa: BLE001
            ok, info["erro"] = False, repr(e)
    anota(f"download {a}", ok, **info)

# ------------------------------------------------------- jogo no navegador
if COM_JOGAR:
    st, corpo, cab, ms = baixar("/jogar/")
    cabl = {k.lower(): v for k, v in cab.items()}
    isolado = cabl.get("cross-origin-opener-policy") == "same-origin" and \
        cabl.get("cross-origin-embedder-policy") == "require-corp"
    anota("/jogar abre com isolamento (threads)", st == 200 and isolado, status=st, ms=ms)
    for arq in ("otclient.js", "otclient.wasm", "otclient.data", "manifest.webmanifest", "atualizacao.txt"):
        st, corpo, cab, ms = baixar("/jogar/" + arq, limite=300)
        anota(f"/jogar/{arq}", st == 200 and len(corpo) > 0, status=st, mb=round(len(corpo) / 1e6, 2),
              s=round(ms / 1000, 1))

with open(os.path.join(SAIDA, "site.json"), "w") as f:
    json.dump(resultado, f, ensure_ascii=False, indent=1)
sys.exit(0 if resultado["ok"] else 1)
