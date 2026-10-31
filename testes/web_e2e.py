"""Teste do jogo no navegador como se fosse um iPhone deitado (roda no GitHub Actions).

Abre /jogar servido localmente (com os cabecalhos COOP/COEP que o jogo exige),
toca em Jogar, cria uma conta de teste no site de verdade, entra no jogo pelo
teclado e tira fotos de cada etapa. Uso: python web_e2e.py <pasta-do-site> <pasta-fotos>
"""
import http.cookiejar
import http.server
import json
import os
import random
import re
import string
import sys
import threading
import time
import urllib.parse
import urllib.request

from playwright.sync_api import sync_playwright

SITE, FOTOS = sys.argv[1], sys.argv[2]
PORTAL = os.environ.get("JV_PORTAL", "https://bayakjh.duckdns.org")
os.makedirs(FOTOS, exist_ok=True)
log = open(os.path.join(FOTOS, "console.txt"), "w")


class Servidor(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".webmanifest": "application/manifest+json"}

    def __init__(self, *a, **k):
        super().__init__(*a, directory=SITE, **k)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        super().end_headers()

    def log_message(self, *a):
        pass


def conta_de_teste():
    """Cria conta + personagem pelo formulario do site (como um jogador faria)."""
    jar = http.cookiejar.CookieJar()
    web = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    html = web.open(PORTAL + "/criar-conta", timeout=30).read().decode()
    csrf = re.search(r'name="csrf" value="([^"]+)"', html).group(1)
    letras = "bcdfgjklmnprstvz"
    vogais = "aeiou"
    nome = "Robo " + "".join(random.choice(letras) + random.choice(vogais) for _ in range(3)).capitalize()
    conta = "robo" + "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(8))
    senha = "".join(random.choice(string.ascii_letters + string.digits) for _ in range(12))
    dados = urllib.parse.urlencode(dict(csrf=csrf, conta=conta, senha=senha, senha2=senha, email="",
                                        personagem=nome, vocacao="4", sexo="1")).encode()
    resp = web.open(PORTAL + "/criar-conta", data=dados, timeout=30).read().decode()
    ok = "Tudo certo" in resp
    log.write(f"conta de teste: {conta} / personagem {nome} / criada={ok}\n")
    return conta, senha, ok


def main():
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 8080), Servidor)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with sync_playwright() as p:
        nav = p.chromium.launch(args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                                      "--ignore-gpu-blocklist", "--enable-webgl"])
        ctx = nav.new_context(
            viewport={"width": 844, "height": 390}, device_scale_factor=3, is_mobile=True, has_touch=True,
            user_agent="Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 "
                       "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1")
        pg = ctx.new_page()
        pg.on("console", lambda m: log.write(f"[{m.type}] {m.text}\n"))
        pg.on("pageerror", lambda e: log.write(f"[pageerror] {e}\n"))
        foto = lambda n: pg.screenshot(path=os.path.join(FOTOS, n))
        t0 = time.time()
        pg.goto("http://127.0.0.1:8080/", wait_until="load")
        foto("1-carregando.png")
        pg.wait_for_selector("#start", state="visible", timeout=240_000)
        log.write(f"pronto para jogar em {time.time() - t0:.0f}s\n")
        foto("2-capa.png")
        pg.tap("#start")
        time.sleep(25)
        foto("3-login.png")
        pg.set_viewport_size({"width": 390, "height": 844}); time.sleep(4)
        foto("3b-login-em-pe.png")
        pg.set_viewport_size({"width": 844, "height": 390}); time.sleep(4)
        conta, senha, ok = conta_de_teste()
        if ok:
            # como no iPhone: toca no campo da conta, aparece "Toque para digitar", toca nele
            pg.touchscreen.tap(440, 140)
            time.sleep(2)
            foto("4a-pediu-teclado.png")
            visivel = pg.is_visible("#digitar")
            log.write(f"botao 'Toque para digitar' apareceu: {visivel}\n")
            if visivel:
                pg.tap("#digitar")
            else:
                pg.tap("#abrir-teclado")
            time.sleep(1)
            log.write(f"campo do teclado com foco: {pg.evaluate('document.activeElement && document.activeElement.id')}\n")
            pg.keyboard.type(conta, delay=60)
            pg.keyboard.press("Tab")
            pg.keyboard.type(senha, delay=60)
            foto("4b-login-preenchido.png")
            pg.keyboard.press("Enter")
            time.sleep(12)
            foto("5-mensagem.png")
            pg.keyboard.press("Enter")  # fecha a mensagem do dia
            time.sleep(3)
            foto("6-personagens.png")
            pg.keyboard.press("Enter")  # entra com o personagem
            time.sleep(20)
            foto("7-no-jogo.png")
            pg.keyboard.press("Escape")  # fecha a janela de roupa da primeira vez
            time.sleep(2)
            foto("7b-sem-janela.png")
            pg.touchscreen.tap(400 + 70, 150)  # toque no mapa: anda
            time.sleep(4)
            foto("8-depois-do-toque.png")
            # chat: abre o teclado pelo botao fixo e manda uma fala
            pg.tap("#abrir-teclado")
            time.sleep(1)
            pg.keyboard.type("oi", delay=80)
            pg.keyboard.press("Enter")
            time.sleep(2)
            foto("8b-falou-oi.png")
            # segurar o dedo no proprio personagem: menu com "Set Outfit" (trocar roupa)
            cdp = ctx.new_cdp_session(pg)
            ponto = [{"x": 400, "y": 150}]
            cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": ponto})
            time.sleep(0.6)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            time.sleep(2)
            foto("8c-segurar-no-personagem.png")
            pg.keyboard.press("Escape")
            time.sleep(1)
            # tamanho da interface: A+ duas vezes (tudo maior), depois volta
            pg.tap("#menu-botao"); time.sleep(0.5)
            pg.tap("#zoom-mais"); time.sleep(0.5); pg.tap("#zoom-mais"); time.sleep(2)
            foto("8d-zoom-maior.png")
            pg.tap("#zoom-menos"); time.sleep(0.5); pg.tap("#zoom-menos"); time.sleep(2)
            foto("8e-zoom-normal.png")
            pg.set_viewport_size({"width": 390, "height": 844})  # celular em pe
            time.sleep(6)
            foto("9-em-pe.png")
            pg.touchscreen.tap(195, 300)
            time.sleep(3)
            foto("9b-em-pe-toque.png")
            pg.set_viewport_size({"width": 844, "height": 390})
            time.sleep(4)
            foto("10-deitado-de-novo.png")
        nav.close()
    srv.shutdown()
    log.close()


if __name__ == "__main__":
    main()
