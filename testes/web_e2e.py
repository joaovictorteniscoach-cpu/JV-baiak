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
log = open(os.path.join(FOTOS, "console.txt"), "w", buffering=1)


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
        engine = os.environ.get('JV_BROWSER', 'chromium')
        nav = p.webkit.launch() if engine == 'webkit' else p.chromium.launch(args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                                      "--ignore-gpu-blocklist", "--enable-webgl"])
        ctx = nav.new_context(
            viewport={"width": 844, "height": 390}, device_scale_factor=3, is_mobile=True, has_touch=True,
            user_agent="Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 "
                       "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1")
        pg = ctx.new_page()
        layouts, game_ready, map_probes, map_releases, game_layouts = [], [], [], [], []
        game_ends, layout_logs = [], []
        janelas, tamanhos = [], []
        seen = set()
        def console(message):
            text = message.text
            # Alguns motores enviam o mesmo registro pelo worker e pela pagina.
            # Os registros nativos incluem timestamp, preservando as sondagens seguintes.
            if text in seen: return
            seen.add(text)
            log.write(f"[{message.type}] {text}\n")
            if 'JV_WEB_GAME_READY' in text:
                game_ready.append(True)
            if 'JV_JANELA root=' in text:
                janelas.append({k: tuple(map(int,v.split(','))) for k,v in re.findall(r'(root|rect)=([0-9,-]+)',text)})
            m2 = re.search(r'JV_JANELA_TAMANHO (\d+),(\d+)', text)
            if m2:
                tamanhos.append((int(m2.group(1)), int(m2.group(2))))
            if 'JV_GAME_END' in text:
                game_ends.append(time.time())
            m = re.search(r'JV_LAYOUT (livre|classico|paginas)', text)
            if m:
                layout_logs.append(m.group(1))
            if 'JV_GAME_LAYOUT ' in text:
                game_layouts.append({k: tuple(map(int,v.split(','))) for k,v in re.findall(r'(root|map|chat|shortcuts|right)=([0-9,-]+)',text)})
            if 'JV_MAP_PROBE ' in text:
                map_probes.append({k: tuple(map(int,v.split(','))) for k,v in re.findall(r'(root|rect|tile)=([0-9,-]+)',text)})
            if 'JV_MAP_RELEASE ' in text:
                map_releases.append({k: tuple(map(int,v.split(','))) for k,v in re.findall(r'(point|tile|button)=([0-9,-]+)',text)})
            if 'JV_LOGIN_LAYOUT ' in text:
                data = dict(re.findall(r'(root|win|account|password|login)=([0-9,-]+)', text))
                metrics = {key: tuple(map(int,value.split(','))) for key,value in data.items()}
                layouts.append(metrics)
        pg.on("console", console)
        def worker_created(worker):
            log.write(f"[worker] {worker.url}\n")
            worker.on("console", console)
        pg.on("worker", worker_created)
        pg.on("pageerror", lambda e: log.write(f"[pageerror] {e}\n"))
        def foto(name):
            pg.screenshot(path=os.path.join(FOTOS, name))
            # Estado minimo para distinguir erro grafico de falta de eventos no teste.
            state = pg.evaluate("""() => {
                const c=document.getElementById('canvas'),r=c.getBoundingClientRect();
                return {isolated:crossOriginIsolated,sharedMemory:typeof SharedArrayBuffer,
                    offscreen:typeof OffscreenCanvas,rect:{x:r.x,y:r.y,width:r.width,height:r.height},
                    buffer:{width:c.width,height:c.height},viewport:{width:innerWidth,height:innerHeight},
                    visualViewport:window.visualViewport?{width:visualViewport.width,height:visualViewport.height,
                        scale:visualViewport.scale,offsetLeft:visualViewport.offsetLeft,offsetTop:visualViewport.offsetTop}:null,
                    runtime:typeof Module==='object'?{calledRun:!!Module.calledRun}:null};
            }""")
            state['workers']=[w.url for w in pg.workers]
            with open(os.path.join(FOTOS,name+'.json'),'w') as output:
                json.dump(state,output,indent=2)


        def verificar_quadrados():
            # Nunca deduzir o tile a partir do mesmo conversor de entrada.
            # O renderer fornece o retangulo de cada tile; o navegador toca nele.
            for index in (0, 2, 4, 6, 8):
                map_probes.clear()
                pg.keyboard.press('Control+Shift+F7')
                pg.wait_for_timeout(700)
                assert len(map_probes) == 9, ('Faltam retangulos nativos',map_probes)
                probe = map_probes[index]
                rw,rh=probe['root'];x,y,w,h=probe['rect']
                rect=pg.locator('#canvas').bounding_box()
                cssx=rect['x']+(x+w/2)*rect['width']/rw
                cssy=rect['y']+(y+h/2)*rect['height']/rh
                map_releases.clear()
                pg.touchscreen.tap(cssx,cssy)
                pg.wait_for_timeout(500)
                assert map_releases, ('O toque nao chegou ao mapa',probe,cssx,cssy)
                actual=map_releases[-1]
                assert actual['tile']==probe['tile'], ('Quadrado incorreto',probe,actual,cssx,cssy)
                assert len(map_releases)==1 and actual['button']==(1,), ('Acao duplicada',map_releases)
                target=pg.locator('#jv-destino').bounding_box()
                assert target and target['x']<=cssx<=target['x']+target['width'] and target['y']<=cssy<=target['y']+target['height'], ('Marcador nao cobre o dedo',target,cssx,cssy)
                log.write(f"tile correto: viewport={pg.viewport_size} esperado={probe['tile']} recebido={actual['tile']}\n")
                pg.wait_for_timeout(1500)

        def conferir_margens():
            pg.evaluate("""() => {
                const s=document.documentElement.style;
                s.setProperty('--jv-safe-top','12px');s.setProperty('--jv-safe-bottom','18px');
                s.setProperty('--jv-safe-left','20px');s.setProperty('--jv-safe-right','20px');
                window.dispatchEvent(new Event('resize'));
            }""")
            pg.wait_for_timeout(1500)
            verificar_quadrados();foto('7b-toque-com-margens.png')
            pg.evaluate("""() => {
                const s=document.documentElement.style;
                ['top','bottom','left','right'].forEach(v=>s.removeProperty('--jv-safe-'+v));
                window.dispatchEvent(new Event('resize'));
            }""")
            pg.wait_for_timeout(1500)

        def conferir_retrato():
            pg.set_viewport_size({"width":390,"height":844});pg.wait_for_timeout(5000)
            verificar_quadrados()
            assert game_layouts, 'Falta geometria do jogo em retrato'
            geometry=game_layouts[-1]
            rw,rh=geometry['root'];mx,my,mw,mh=geometry['map'];cx,cy,cw,ch=geometry['chat'];sx,sy,sw,sh=geometry['shortcuts']
            assert mw>=rw*.9, ('Painel lateral ainda ocupa o mapa',geometry)
            assert cy>=my+mh-1 and sy>=cy+ch-1, ('Mapa, chat ou acoes se sobrepoem',geometry)
            pg.tap('#menu-botao');pg.tap('#jv-equipamento');pg.wait_for_timeout(1000)
            # Voltar ao mapa precisa desfazer a abertura do equipamento.
            pg.tap('#menu-botao');pg.tap('#jv-fechar-painel');pg.wait_for_timeout(1000)
            verificar_quadrados()
            assert game_layouts[-1]['map'][2]>=rw*.9, ('O painel nao fechou',game_layouts[-1])
            foto('9-retrato-mapa-chat-acoes.png')

        def fotos_layout(numero, nome, controles):
            """Fotos para escolher o layout: mapa limpo, janelas abertas e em pe."""
            pg.set_viewport_size({"width": 844, "height": 390}); time.sleep(3)
            foto(f'L{numero}-{nome}-1-mapa.png')
            for controle in controles:
                pg.tap('#menu-botao'); pg.tap('#' + controle); time.sleep(1.5)
            foto(f'L{numero}-{nome}-2-janelas.png')
            pg.set_viewport_size({"width": 390, "height": 844}); time.sleep(5)
            foto(f'L{numero}-{nome}-3-em-pe.png')
            pg.set_viewport_size({"width": 844, "height": 390}); time.sleep(4)
            pg.keyboard.press('Control+Shift+F12'); time.sleep(1)

        def trocar_layout(esperado):
            """Menu > Trocar layout: grava, recarrega e entra sozinho no mesmo personagem."""
            prontos, quedas = len(game_ready), len(game_ends)
            pg.tap('#menu-botao'); pg.tap('#jv-layout')
            t = time.time()
            while len(game_ready) <= prontos and time.time() - t < 240:
                pg.wait_for_timeout(1000)
            voltou_sozinho = len(game_ready) > prontos
            log.write(f"layout {esperado}: voltou sozinho ao jogo = {voltou_sozinho} em {time.time() - t:.0f}s\n")
            if not voltou_sozinho:
                foto(f'L-{esperado}-nao-voltou.png')
                for _ in range(3):
                    pg.keyboard.press('Enter'); time.sleep(4)
                t2 = time.time()
                while len(game_ready) <= prontos and time.time() - t2 < 60:
                    pg.wait_for_timeout(1000)
            assert len(game_ready) > prontos, f'Nao voltou ao jogo depois de trocar para {esperado}'
            time.sleep(6)
            assert layout_logs and layout_logs[-1] == esperado, ('Layout nao mudou', esperado, layout_logs[-5:])
            return voltou_sozinho

        def tour_layouts():
            fotos_layout(1, 'tela-cheia', ('jv-equipamento', 'jv-status'))
            resultado = {}
            for numero, nome, chave, controles in ((2, 'classico', 'classico', ('jv-status', 'jv-combate')),
                                                   (3, 'paginas', 'paginas', ('jv-status',))):
                resultado[chave] = trocar_layout(chave)
                fotos_layout(numero, nome, controles)
            # volta ao primeiro e confere que o personagem fica no jogo (nao entra e sai sozinho)
            resultado['livre'] = trocar_layout('livre')
            quedas = len(game_ends)
            time.sleep(75)
            foto('L1-tela-cheia-4-depois-de-75s.png')
            assert len(game_ends) == quedas, ('O jogo caiu sozinho depois de voltar', game_ends)
            log.write(f"volta automatica por layout: {resultado}; sem quedas em 75 s\n")
            assert all(resultado.values()), ('Nao entrou sozinho em todas as trocas', resultado)

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
            pg.tap('#menu-botao');pg.tap('#jv-ver-toque');time.sleep(0.5)
            verificar_quadrados()
            foto("7b-marcadores-toque.png")
            conferir_margens()
            # Paginas laterais: navega pelos botoes reais do menu de toque.
            for controle, nome in [('jv-combate', '7c-combate.png'), ('jv-minimapa', '7d-minimapa.png'),
                                    ('jv-opcoes', '7e-opcoes.png'), ('jv-status', '7e2-status.png'),
                                    ('jv-equipamento', '7f-equipamento.png')]:
                pg.tap('#menu-botao')
                pg.tap('#' + controle)
                time.sleep(1)
                foto(nome)
            foto('7g-janelas-abertas.png')
            pg.keyboard.press('Control+Shift+F12')  # fecha as janelas soltas (tela cheia)
            time.sleep(1)
            pg.touchscreen.tap(400 + 70, 150)  # toque no mapa: anda
            time.sleep(4)
            foto("8-depois-do-toque.png")
            pg.keyboard.press('Control+Shift+F12')  # Voltar ao mapa: fecha conversa de NPC aberta pelo toque
            time.sleep(1)
            # chat: abre o teclado pelo botao fixo e manda uma fala
            pg.tap("#menu-botao"); time.sleep(0.5)
            foto("8a-menu.png")
            pg.tap("#abrir-teclado")
            time.sleep(1)
            foto("8b-teclado-aberto.png")
            pg.tap('#fechar-teclado')
            time.sleep(1)
            if engine == 'webkit':
                # WebKit nao oferece CDP. Aqui usamos toque real nas duas orientacoes.
                conferir_retrato();foto('9-safari-em-pe.png')
                pg.set_viewport_size({"width":844,"height":390});time.sleep(4)
                verificar_quadrados();foto('10-safari-deitado.png')
                tour_layouts()
                nav.close();srv.shutdown();log.close();return
            # segurar o dedo no proprio personagem: menu com "Set Outfit" (trocar roupa)
            cdp = ctx.new_cdp_session(pg)
            map_probes.clear();pg.keyboard.press('Control+Shift+F7');pg.wait_for_timeout(700)
            assert len(map_probes)==9, ('Faltam quadrados antes do toque longo',map_probes)
            probe=map_probes[4];rw,rh=probe['root'];x,y,w,h=probe['rect']
            rect=pg.locator('#canvas').bounding_box()
            ponto = [{"x": rect['x']+(x+w/2)*rect['width']/rw, "y":rect['y']+(y+h/2)*rect['height']/rh}]
            map_releases.clear()
            cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": ponto})
            time.sleep(0.6)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            time.sleep(2)
            foto("8c-segurar-no-personagem.png")
            assert len(map_releases)==1 and map_releases[0]['button']==(2,), ('Toque longo tambem andou',map_releases)
            assert map_releases[0]['tile']==probe['tile'], ('Menu no quadrado errado',probe,map_releases)
            pg.keyboard.press("Escape")
            time.sleep(1)
            # tamanho da interface: A+ duas vezes (tudo maior), depois volta
            pg.tap("#menu-botao"); time.sleep(0.5)
            pg.tap("#zoom-mais"); time.sleep(0.5); pg.tap("#zoom-mais"); time.sleep(2)
            foto("8d-zoom-maior.png")
            verificar_quadrados()
            pg.tap("#menu-botao"); time.sleep(0.5)
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
            conferir_retrato()
            foto("9-em-pe.png")
            pg.touchscreen.tap(195, 300)
            time.sleep(3)
            foto("9b-em-pe-toque.png")
            pg.set_viewport_size({"width": 844, "height": 390})
            time.sleep(4)
            foto("10-deitado-de-novo.png")
            # tela cheia: puxar a alca do canto diminui a caixa do Equipamento
            pg.keyboard.press('Control+Shift+F12'); time.sleep(1)
            janelas.clear(); tamanhos.clear()
            for tentativa in range(3):
                pg.keyboard.press('Control+Shift+F8')
                for _ in range(10):
                    if janelas: break
                    time.sleep(0.5)
                if janelas: break
                foto(f'7h-tentativa-{tentativa}.png')
            assert janelas, 'A janela solta do Equipamento nao abriu'
            rw, rh = janelas[-1]['root']; x, y, w, h = janelas[-1]['rect']
            box = pg.locator('#canvas').bounding_box()
            gx = box['x'] + (x + w - 15) * box['width'] / rw
            gy = box['y'] + (y + h - 12) * box['height'] / rh
            cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": gx, "y": gy}]})
            for i in range(1, 11):
                cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": [{"x": gx - 6 * i, "y": gy - 4 * i}]})
                time.sleep(0.05)
            cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            time.sleep(1.5)
            foto('7h-janela-menor.png')
            log.write(f"janela antes={w}x{h} depois={tamanhos}\n")
            assert tamanhos and tamanhos[-1][0] < w and tamanhos[-1][1] < h, ('A caixa nao diminuiu', (w, h), tamanhos)
            pg.keyboard.press('Control+Shift+F12'); time.sleep(1)
            tour_layouts()
        if not ok:
            raise AssertionError('Nao foi possivel criar a conta de teste')
        nav.close()
    srv.shutdown()
    log.close()


if __name__ == "__main__":
    main()
