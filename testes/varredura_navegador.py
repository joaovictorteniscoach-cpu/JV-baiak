"""Joga no site de verdade (https://.../jogar) como iPhone, Android ou PC e tira fotos.

Uso: python varredura_navegador.py <perfil> <url-do-site> <pasta-saida>
Perfis: iphone-safari (motor WebKit, o do Safari), iphone (Chrome com tela de iPhone),
        android (Chrome de celular, Pixel 7), pc (Chrome de computador), pc-firefox
"""
import http.cookiejar
import json
import os
import random
import re
import string
import sys
import time
import urllib.parse
import urllib.request

from playwright.sync_api import sync_playwright

PERFIL, SITE, SAIDA = sys.argv[1], sys.argv[2].rstrip("/"), sys.argv[3]
os.makedirs(SAIDA, exist_ok=True)
log = open(os.path.join(SAIDA, "console.txt"), "w")
res = {"perfil": PERFIL, "etapas": [], "ok": True}
UA_IPHONE = ("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 "
             "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1")


def etapa(nome, ok, **info):
    res["etapas"].append({"etapa": nome, "ok": bool(ok), **info})
    if not ok:
        res["ok"] = False
    print(("OK   " if ok else "FALHA"), nome, json.dumps(info, ensure_ascii=False), flush=True)


def conta_de_teste():
    jar = http.cookiejar.CookieJar()
    web = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    html = web.open(SITE + "/criar-conta", timeout=30).read().decode()
    csrf = re.search(r'name="csrf" value="([^"]+)"', html).group(1)
    letras, vogais = "bcdfgjklmnprstvz", "aeiou"
    nome = "Robo " + "".join(random.choice(letras) + random.choice(vogais) for _ in range(3)).capitalize()
    conta = "robo" + "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(8))
    senha = "".join(random.choice(string.ascii_letters + string.digits) for _ in range(12))
    dados = urllib.parse.urlencode(dict(csrf=csrf, conta=conta, senha=senha, senha2=senha, email="",
                                        personagem=nome, vocacao="4", sexo="1")).encode()
    ok = "Tudo certo" in web.open(SITE + "/criar-conta", data=dados, timeout=30).read().decode()
    return conta, senha, nome, ok


def main():
    with sync_playwright() as p:
        gl = ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--enable-webgl"]
        celular = PERFIL in ("iphone-safari", "iphone", "android")
        if PERFIL == "iphone-safari":
            nav = p.webkit.launch()
            ctx = nav.new_context(**p.devices["iPhone 13 landscape"])
        elif PERFIL == "iphone":
            nav = p.chromium.launch(args=gl)
            ctx = nav.new_context(viewport={"width": 844, "height": 390}, device_scale_factor=3, is_mobile=True,
                                  has_touch=True, user_agent=UA_IPHONE)
        elif PERFIL == "android":
            nav = p.chromium.launch(args=gl)
            ctx = nav.new_context(**p.devices["Pixel 7 landscape"])
        elif PERFIL == "pc-firefox":
            nav = p.firefox.launch()
            ctx = nav.new_context(viewport={"width": 1366, "height": 768})
        else:
            nav = p.chromium.launch(args=gl)
            ctx = nav.new_context(viewport={"width": 1366, "height": 768})
        pg = ctx.new_page()
        erros = []
        pg.on("console", lambda m: log.write(f"[{m.type}] {m.text}\n"))
        pg.on("pageerror", lambda e: (erros.append(str(e)), log.write(f"[pageerror] {e}\n")))
        L, A = pg.viewport_size["width"], pg.viewport_size["height"]
        n = [0]

        def foto(nome):
            n[0] += 1
            pg.screenshot(path=os.path.join(SAIDA, f"{n[0]:02d}-{nome}.png"))

        def toque(fx, fy):
            x, y = int(L * fx), int(A * fy)
            if celular:
                pg.touchscreen.tap(x, y)
            else:
                pg.mouse.click(x, y)

        t0 = time.time()
        pg.goto(SITE + "/jogar/", wait_until="load", timeout=120_000)
        foto("carregando")
        try:
            pg.wait_for_selector("#start", state="visible", timeout=300_000)
            etapa("baixou e preparou o jogo", True, s=round(time.time() - t0))
        except Exception as e:  # noqa: BLE001
            etapa("baixou e preparou o jogo", False, s=round(time.time() - t0), erro=str(e)[:200])
            foto("nao-carregou")
            return
        foto("capa")
        (pg.tap if celular else pg.click)("#start")
        t1 = time.time()
        time.sleep(25)
        foto("tela-de-login")
        conta, senha, nome, criada = conta_de_teste()
        etapa("conta de teste criada no site", criada, conta=conta)
        if not criada:
            return
        if celular:
            toque(440 / 844, 140 / 390)  # campo da conta: aparece "Toque para digitar"
            time.sleep(2)
            visivel = pg.is_visible("#digitar")
            etapa("toque no campo mostra 'Toque para digitar'", visivel)
            if visivel:
                pg.tap("#digitar")
            else:
                pg.tap("#menu-botao"); time.sleep(0.5); pg.tap("#abrir-teclado")
            time.sleep(1)
            foco = pg.evaluate("document.activeElement && document.activeElement.id")
            etapa("teclado do celular abriu (campo com foco)", foco == "teclado", foco=foco)
        pg.keyboard.type(conta, delay=50)
        pg.keyboard.press("Tab")
        pg.keyboard.type(senha, delay=50)
        foto("login-preenchido")
        pg.keyboard.press("Enter")
        time.sleep(10)
        foto("mensagem-do-dia")
        pg.keyboard.press("Enter")
        time.sleep(3)
        foto("lista-de-personagens")
        pg.keyboard.press("Enter")
        t2 = time.time()
        time.sleep(15)
        foto("entrou-no-jogo")
        pg.keyboard.press("Escape")
        time.sleep(2)
        foto("no-jogo")

        # fluidez: quantos quadros novos a tela mostra por segundo enquanto anda (so no Chrome)
        quadros = None
        cdp = None
        if PERFIL in ("iphone", "android", "pc"):
            cdp = ctx.new_cdp_session(pg)
            contagem = [0]

            def quadro(ev):
                contagem[0] += 1
                cdp.send("Page.screencastFrameAck", {"sessionId": ev["sessionId"]})
            cdp.on("Page.screencastFrame", quadro)
            cdp.send("Page.startScreencast", {"format": "jpeg", "quality": 10, "maxWidth": 320, "maxHeight": 240,
                                              "everyNthFrame": 1})
        ta = time.time()
        if celular:
            for fx in (0.58, 0.42, 0.58, 0.42):  # toques no mapa: anda para os lados
                toque(fx, 0.38)
                time.sleep(1.5)
        else:
            for tecla in ("ArrowRight", "ArrowLeft", "ArrowDown", "ArrowUp", "ArrowRight", "ArrowLeft"):
                pg.keyboard.down(tecla); time.sleep(0.8); pg.keyboard.up(tecla); time.sleep(0.3)
            toque(0.55, 0.4)
            time.sleep(1.5)
        if cdp:
            quadros = round(contagem[0] / (time.time() - ta), 1)
            cdp.send("Page.stopScreencast")
        foto("depois-de-andar")
        etapa("andou pelo mapa", True, quadros_por_segundo_na_tela=quadros)

        # chat
        if celular:
            pg.tap("#menu-botao"); time.sleep(0.6)
            foto("menu")
            pg.tap("#abrir-teclado"); time.sleep(1)
        else:
            pg.keyboard.press("Enter"); time.sleep(0.5)
        pg.keyboard.type("oi robo", delay=60)
        pg.keyboard.press("Enter")
        time.sleep(2)
        foto("falou-oi")

        if celular:
            # segurar o dedo no personagem: menu de opcoes (roupa, etc.)
            if cdp is None and PERFIL != "iphone-safari":
                cdp = ctx.new_cdp_session(pg)
            if cdp:
                pt = [{"x": L // 2, "y": int(A * 0.38)}]
                cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": pt})
                time.sleep(0.7)
                cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
                time.sleep(2)
                foto("segurou-no-personagem")
                pg.keyboard.press("Escape"); time.sleep(1)
            pg.tap("#menu-botao"); time.sleep(0.5)
            pg.tap("#zoom-mais"); time.sleep(2)
            foto("interface-maior")
            pg.tap("#zoom-menos"); time.sleep(2)
            pg.keyboard.press("Escape")
            # gira o celular: em pe e deitado de novo
            pg.set_viewport_size({"width": A, "height": L}); time.sleep(6)
            foto("em-pe")
            pg.touchscreen.tap(A // 2, int(L * 0.3)); time.sleep(3)
            foto("em-pe-depois-do-toque")
            pg.set_viewport_size({"width": L, "height": A}); time.sleep(5)
            foto("deitado-de-novo")
        else:
            pg.set_viewport_size({"width": 1024, "height": 640}); time.sleep(4)
            foto("janela-menor")
            pg.set_viewport_size({"width": 1920, "height": 1080}); time.sleep(4)
            foto("tela-cheia")
        etapa("sem erros de pagina", not erros, erros=erros[:5])
        etapa("tempo ate a tela de login", True, s=round(t1 - t0))
        nav.close()


try:
    main()
except Exception as e:  # noqa: BLE001
    etapa("o teste terminou", False, erro=repr(e)[:300])
finally:
    with open(os.path.join(SAIDA, "resultado.json"), "w") as f:
        json.dump(res, f, ensure_ascii=False, indent=1)
    log.close()
