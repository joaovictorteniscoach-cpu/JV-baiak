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
        layouts, game_ready = [], []
        def console(message):
            text = message.text
            log.write(f"[{message.type}] {text}\n")
            if 'JV_WEB_GAME_READY' in text:
                game_ready.append(True)
            if 'JV_LOGIN_LAYOUT ' in text:
                data = dict(re.findall(r'(root|win|account|password|login)=([0-9,-]+)', text))
                metrics = {key: tuple(map(int,value.split(','))) for key,value in data.items()}
                layouts.append(metrics)
        pg.on("console", console)
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
        assert len(layouts)>=2, 'Faltam medidas nativas do login nas duas orientacoes'
        for geometry in layouts:
            rw,rh=geometry['root'];wx,wy,ww,wh=geometry['win']
            assert wx>=0 and wy>=0 and wx+ww<=rw+1 and wy+wh<=rh+1, geometry
            for name in ('account','password','login'):
                x,y,w,h=geometry[name]
                assert w>=44 and h>=44 and x>=wx and y>=wy and x+w<=wx+ww+1 and y+h<=wy+wh+1, (name,geometry)
        pg.set_viewport_size({"width": 844, "height": 390}); time.sleep(4)
        conta, senha, ok = conta_de_teste()
        if ok:
            # como no iPhone: toca no campo da conta, aparece "Toque para digitar", toca nele
            pg.touchscreen.tap(440, 100)
            time.sleep(2)
            foto("4a-pediu-teclado.png")
            visivel = pg.is_visible("#digitar")
            log.write(f"botao 'Toque para digitar' apareceu: {visivel}\n")
            if visivel:
                pg.tap("#digitar")
            else:
                pg.tap("#menu-botao"); time.sleep(0.5)
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
            assert game_ready, 'O teste nao entrou no jogo; rever login e teclado'
            pg.keyboard.press("Escape")  # fecha a janela de roupa da primeira vez
            time.sleep(2)
            foto("7b-sem-janela.png")
            # Paginas laterais: navega pelos botoes reais do menu de toque.
            for controle, nome in [('jv-combate', '7c-combate.png'), ('jv-minimapa', '7d-minimapa.png'),
                                    ('jv-opcoes', '7e-opcoes.png'), ('jv-equipamento', '7f-equipamento.png')]:
                pg.tap('#menu-botao')
                pg.tap('#' + controle)
                time.sleep(1)
                foto(nome)
            pg.touchscreen.tap(400 + 70, 150)  # toque no mapa: anda
            time.sleep(4)
            foto("8-depois-do-toque.png")
            # chat: abre o teclado pelo botao fixo e manda uma fala
            pg.tap("#menu-botao"); time.sleep(0.5)
            foto("8a-menu.png")
            pg.tap("#abrir-teclado")
            time.sleep(1)
            foto("8b-teclado-aberto.png")
            pg.tap('#fechar-teclado')
            time.sleep(1)
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
            # pinça com dois dedos: abre (tudo maior) e depois fecha
            def pinca(d0, d1):
                pts = lambda d: [{"x": 422 - d / 2, "y": 200}, {"x": 422 + d / 2, "y": 200}]
                cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": pts(d0)})
                for i in range(1, 9):
                    cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": pts(d0 + (d1 - d0) * i / 8)})
                    time.sleep(0.05)
                cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
                time.sleep(2.5)
            pinca(100, 160)
            foto("8f-pinca-abrir.png")
            pinca(160, 100)
            foto("8g-pinca-fechar.png")
            log.write(f"zoom depois da pinca: {pg.evaluate('lerZoom()')}\n")
            pg.set_viewport_size({"width": 390, "height": 844})  # celular em pe
            time.sleep(6)
            foto("9-em-pe.png")
            pg.touchscreen.tap(195, 300)
            time.sleep(3)
            foto("9b-em-pe-toque.png")
            pg.set_viewport_size({"width": 844, "height": 390})
            time.sleep(4)
            foto("10-deitado-de-novo.png")
        if not ok:
            raise AssertionError('Nao foi possivel criar a conta de teste')
        nav.close()
    srv.shutdown()
    log.close()


if __name__ == "__main__":
    main()
