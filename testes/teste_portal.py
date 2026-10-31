"""Testes do portal usando SQLite no lugar do MariaDB (mesmas consultas)."""
import hashlib
import os
import re
import sqlite3
import sys
import tempfile
import unittest

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "portal"))

DOWN = tempfile.mkdtemp()
os.environ.update(NOME_SERVIDOR="JV Baiak", ENDERECO_SERVIDOR="203.0.113.10", PASTA_DOWNLOADS=DOWN,
                  SERVIDOR_JOGO="127.0.0.1", PORTAL_SEGREDO="teste")

DDL = """
CREATE TABLE accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password TEXT NOT NULL, type INT NOT NULL DEFAULT 1, premdays INT NOT NULL DEFAULT 0,
  email TEXT NOT NULL DEFAULT '', creation INT NOT NULL DEFAULT 0);
CREATE TABLE players (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE COLLATE NOCASE,
  group_id INT NOT NULL DEFAULT 1, account_id INT NOT NULL, level INT NOT NULL DEFAULT 1,
  vocation INT NOT NULL DEFAULT 0, health INT, healthmax INT, experience INT NOT NULL DEFAULT 0,
  lookbody INT, lookfeet INT, lookhead INT, looklegs INT, looktype INT, maglevel INT NOT NULL DEFAULT 0,
  mana INT, manamax INT, manaspent INT NOT NULL DEFAULT 0, soul INT, town_id INT, conditions BLOB NOT NULL,
  cap INT, sex INT, skill_fist INT DEFAULT 10, skill_fist_tries INT DEFAULT 0, skill_club INT DEFAULT 10,
  skill_club_tries INT DEFAULT 0, skill_sword INT DEFAULT 10, skill_sword_tries INT DEFAULT 0,
  skill_axe INT DEFAULT 10, skill_axe_tries INT DEFAULT 0, skill_dist INT DEFAULT 10,
  skill_dist_tries INT DEFAULT 0, skill_shielding INT DEFAULT 10, skill_shielding_tries INT DEFAULT 0,
  skill_fishing INT DEFAULT 10, lastlogin INT NOT NULL DEFAULT 0, onlinetime INT NOT NULL DEFAULT 0);
CREATE TABLE players_online (player_id INT PRIMARY KEY);
CREATE TABLE player_deaths (player_id INT, time INT, level INT, killed_by TEXT, is_player INT,
  mostdamage_by TEXT, mostdamage_is_player INT, unjustified INT, mostdamage_unjustified INT);
CREATE TABLE guilds (id INTEGER PRIMARY KEY, name TEXT, ownerid INT, creationdata INT, motd TEXT DEFAULT '');
CREATE TABLE guild_ranks (id INTEGER PRIMARY KEY, guild_id INT, name TEXT, level INT);
CREATE TABLE guild_membership (player_id INT PRIMARY KEY, guild_id INT, rank_id INT, nick TEXT DEFAULT '');
CREATE TABLE guild_wars (id INTEGER PRIMARY KEY, guild1 INT, guild2 INT, name1 TEXT, name2 TEXT, status INT,
  started INT, ended INT);
CREATE TABLE houses (id INTEGER PRIMARY KEY, owner INT DEFAULT 0, paid INT, warnings INT, name TEXT, rent INT,
  town_id INT, bid INT, bid_end INT, last_bid INT, highest_bidder INT, size INT, beds INT);
CREATE TABLE server_config (config TEXT PRIMARY KEY, value TEXT);
"""

# Arquivos do jogo de mentira (o portal le rates e eventos deles)
JOGO = tempfile.mkdtemp()
os.makedirs(os.path.join(JOGO, "data", "lib", "events"))
os.makedirs(os.path.join(JOGO, "data", "globalevents"))
with open(os.path.join(JOGO, "config.lua"), "w") as f:
    f.write('''-- teste
worldType = "pvp"
protectionLevel = 50
killsToRedSkull = 100
pzLocked = 30 * 1000
mysqlPass = "nao-pode-aparecer"
rateExp = 5
rateSkill = 3
rateMagic = 3
rateLoot = 2
experienceStages = {
	{ minlevel = 1, maxlevel = 50, multiplier = 400 },
	{ minlevel = 51, multiplier = 0.5 }
}
''')
with open(os.path.join(JOGO, "data", "lib", "events", "battlefield.lua"), "w") as f:
    f.write('BATTLEFIELD = {\n  days = {\n    ["Sunday"] = {"15:00"},\n    ["Wednesday"] = {"15:00", "21:30"},\n  },\n}\n')
with open(os.path.join(JOGO, "data", "globalevents", "globalevents.xml"), "w") as f:
    f.write('<globalevents>\n<globalevent name="Server Save" time="05:55:00" script="save.lua"/>\n'
            '<globalevent name="Lottery" time="15:00:00" script="lottery.lua"/>\n</globalevents>')
os.environ.update(CONFIG_LUA=os.path.join(JOGO, "config.lua"), PASTA_DATA=os.path.join(JOGO, "data"))
import app as portal  # noqa: E402


class TestePortal(unittest.TestCase):
    def setUp(self):
        fd, self.arq = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        con = sqlite3.connect(self.arq)
        con.executescript(DDL)
        con.close()
        portal.banco = portal.Banco(lambda: sqlite3.connect(self.arq), marcador="?")
        portal.limite_criacao = portal.LimiteDeTaxa(maximo=5, janela_s=3600)
        portal.limite_login = portal.LimiteDeTaxa(maximo=10, janela_s=900)
        portal._status_cache.update(t=1e18, online=True)
        self.c = portal.app.test_client()

    def tearDown(self):
        os.remove(self.arq)

    def csrf(self, caminho="/criar-conta"):
        html = self.c.get(caminho).get_data(as_text=True)
        return re.search(r'name="csrf" value="([^"]+)"', html).group(1)

    def criar(self, **extra):
        dados = dict(conta="joao123", senha="segredo1", senha2="segredo1", email="",
                     personagem="sir   joao  victor", vocacao="4", sexo="1")
        dados.update(extra)
        dados.setdefault("csrf", self.csrf())
        return self.c.post("/criar-conta", data=dados)

    def sql(self, q, p=()):
        con = sqlite3.connect(self.arq)
        try:
            return con.execute(q, p).fetchall()
        finally:
            con.close()

    def test_paginas_abrem(self):
        for caminho in ("/", "/criar-conta", "/novo-personagem", "/ranking", "/baixar", "/saude"):
            r = self.c.get(caminho)
            self.assertEqual(r.status_code, 200, caminho)
        self.assertIn("default-src 'self'", self.c.get("/").headers["Content-Security-Policy"])

    def test_cria_conta_e_personagem_level_8(self):
        r = self.criar()
        self.assertEqual(r.status_code, 200, r.get_data(as_text=True))
        self.assertIn("Sir Joao Victor", r.get_data(as_text=True))
        conta = self.sql("SELECT name, password, type FROM accounts")[0]
        self.assertEqual(conta, ("joao123", hashlib.sha1(b"segredo1").hexdigest(), 1))
        p = self.sql("SELECT name, vocation, sex, level, experience, health, mana, cap, town_id, looktype, conditions,"
                     " group_id FROM players")[0]
        self.assertEqual(p, ("Sir Joao Victor", 4, 1, 8, 4200, 185, 35, 470, 1, 128, b"", 1))

    def test_sem_csrf_recusa(self):
        r = self.c.post("/criar-conta", data={"conta": "x"})
        self.assertEqual(r.status_code, 400)
        self.assertEqual(self.sql("SELECT COUNT(*) FROM accounts")[0][0], 0)

    def test_validacoes(self):
        casos = [
            dict(conta="ab"), dict(conta="com espaco"), dict(senha2="outra123"), dict(senha="curta", senha2="curta"),
            dict(personagem="GM Joao"), dict(personagem="Jo4o"), dict(personagem="Aaaron"), dict(vocacao="9"),
            dict(sexo="x"), dict(email="sem-arroba"), dict(personagem="Um Dois Tres Quatro"),
        ]
        for caso in casos:
            r = self.criar(**caso)
            self.assertEqual(r.status_code, 400, caso)
        self.assertEqual(self.sql("SELECT COUNT(*) FROM accounts")[0][0], 0)

    def test_duplicados(self):
        self.assertEqual(self.criar().status_code, 200)
        r = self.criar(conta="JOAO123", personagem="Outro Nome")
        self.assertIn("Essa conta ja existe", r.get_data(as_text=True))
        r = self.criar(conta="maria99", personagem="Sir Joao Victor")
        self.assertIn("Ja existe um personagem", r.get_data(as_text=True))
        self.assertEqual(self.sql("SELECT COUNT(*) FROM accounts")[0][0], 1)

    def test_novo_personagem(self):
        self.criar()
        t = self.csrf("/novo-personagem")
        base = dict(csrf=t, conta="joao123", senha="segredo1", personagem="Druida Boa", vocacao="2", sexo="0")
        r = self.c.post("/novo-personagem", data=dict(base, senha="errada11"))
        self.assertIn("Conta ou senha incorretas", r.get_data(as_text=True))
        r = self.c.post("/novo-personagem", data=base)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.sql("SELECT vocation, looktype FROM players WHERE name='Druida Boa'"), [(2, 136)])

    def test_limite_por_ip(self):
        for i in range(5):
            self.assertEqual(self.criar(conta=f"conta{i}x", personagem=f"Heroi {'abcde'[i]}x").status_code, 200)
        r = self.criar(conta="conta9x", personagem="Heroi Zz")
        self.assertIn("Muitas contas", r.get_data(as_text=True))

    def test_ranking_e_status(self):
        self.criar()
        self.sql("SELECT 1")
        con = sqlite3.connect(self.arq)
        con.execute("UPDATE players SET maglevel = 30")
        con.execute("INSERT INTO players_online VALUES (1)")
        con.commit()
        con.close()
        html = self.c.get("/ranking?tipo=magia").get_data(as_text=True)
        self.assertIn("Sir Joao Victor", html)
        self.assertIn(">30<", html)
        self.assertEqual(self.c.get("/ranking?tipo=;drop table players").status_code, 200)
        self.assertIn("1 jogando", self.c.get("/").get_data(as_text=True))

    def test_downloads(self):
        self.assertEqual(self.c.get("/downloads/../app.py").status_code, 404)
        self.assertEqual(self.c.get("/downloads/JVBaiak-Android.apk").status_code, 404)
        with open(os.path.join(DOWN, "JVBaiak-Android.apk"), "wb") as f:
            f.write(b"apk")
        r = self.c.get("/downloads/JVBaiak-Android.apk")
        self.assertEqual((r.status_code, r.data), (200, b"apk"))
        ios = self.c.get("/baixar", headers={"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)"})
        self.assertIn("Ainda nao existe cliente 8.60 para iPhone", ios.get_data(as_text=True))
        andr = self.c.get("/baixar", headers={"User-Agent": "Mozilla/5.0 (Linux; Android 15)"}).get_data(as_text=True)
        self.assertIn("Baixar APK", andr)
        self.assertIn("O cliente ainda esta sendo gerado", andr)

    # ------------------------------------------------------------- site v2
    def popular(self):
        """Dois personagens, uma guild, uma morte PvP, casas e recorde."""
        self.criar()
        self.criar(conta="henrique1", personagem="Henrique Mago", vocacao="1", csrf=self.csrf())
        con = sqlite3.connect(self.arq)
        con.executescript("""
            UPDATE players SET level = 120, maglevel = 15, skill_sword = 90, lastlogin = 1700000000,
              onlinetime = 7260 WHERE id = 1;
            INSERT INTO players_online VALUES (2);
            INSERT INTO player_deaths VALUES (2, 1700000500, 40, 'Sir Joao Victor', 1, 'a dragon', 0, 1, 0);
            INSERT INTO player_deaths VALUES (1, 1700000400, 119, 'a demon', 0, 'a demon', 0, 0, 0);
            INSERT INTO guilds VALUES (1, 'Irmandade', 1, 1700000000, 'Bem-vindos');
            INSERT INTO guild_ranks VALUES (1, 1, 'Leader', 3), (2, 1, 'Member', 1);
            INSERT INTO guild_membership VALUES (1, 1, 1, 'JV'), (2, 1, 2, '');
            INSERT INTO guild_wars VALUES (1, 1, 2, 'Irmandade', 'Rivais', 1, 1700000000, 0);
            INSERT INTO houses (id, owner, name, rent, town_id, size, beds) VALUES
              (1, 1, 'Rua do Ouro 1', 1000, 1, 40, 2), (2, 0, 'Beco Escuro 2', 500, 1, 20, 1),
              (3, 0, 'Torre Norte', 900, 2, 30, 1);
            INSERT INTO server_config VALUES ('players_record', '7');
        """)
        con.commit()
        con.close()

    def test_paginas_novas_abrem(self):
        self.popular()
        for caminho in ("/online", "/personagem", "/mortes", "/guilds", "/guild/1", "/casas", "/casas?cidade=2",
                        "/servidor", "/conta", "/ranking?voc=knight", "/ranking?voc=xx&tipo=sword"):
            r = self.c.get(caminho)
            self.assertEqual(r.status_code, 200, caminho)
        self.assertEqual(self.c.get("/guild/99").status_code, 404)

    def test_identidade_e_inicio(self):
        self.popular()
        html = self.c.get("/").get_data(as_text=True)
        for trecho in ("Família Carnicini Soubhi", "João Victor e Henrique", "Sir Joao Victor", "recorde online",
                       "Últimas mortes", "brasao-letra", ">J<", ">H<", ">CS<", "400x"):
            self.assertIn(trecho, html)

    def test_personagem(self):
        self.popular()
        html = self.c.get("/personagem?nome=sir joao victor").get_data(as_text=True)
        for trecho in ("Knight", "Irmandade", "Rua do Ouro 1", "Thunder City", ">90<",
                       "2 h 1 min", "a demon"):
            self.assertIn(trecho, html)
        r = self.c.get("/personagem?nome=Joao")
        self.assertEqual(r.status_code, 404)
        self.assertIn("Sir Joao Victor", r.get_data(as_text=True))  # sugestao
        self.assertIn('class="selo on"', self.c.get("/personagem?nome=Henrique Mago").get_data(as_text=True))

    def test_mortes_guild_casas(self):
        self.popular()
        mortes = self.c.get("/mortes").get_data(as_text=True)
        self.assertIn("PvP", mortes)
        self.assertLess(mortes.index("Henrique Mago"), mortes.index("a demon"))  # mais recente primeiro
        guild = self.c.get("/guild/1").get_data(as_text=True)
        self.assertIn("Leader", guild)
        self.assertIn("em guerra", guild)
        casas = self.c.get("/casas").get_data(as_text=True)
        self.assertIn("2 livres de 3", casas)
        self.assertIn("1 livre de 2", self.c.get("/casas?cidade=1").get_data(as_text=True))

    def test_servidor_le_config(self):
        html = self.c.get("/servidor").get_data(as_text=True)
        for trecho in ("Battlefield", "Domingo e quarta, 15:00 · Quarta, 21:30", "Loteria", "Todo dia, 15:00",
                       "05:55", "50", "100 mortes", "30 segundos", "!treino", "0.5x"):
            self.assertIn(trecho, html)
        self.assertNotIn("nao-pode-aparecer", html)

    def test_proximos_eventos_sem_repetir(self):
        import time as _t
        import infos
        ev = infos.agenda(os.path.join(JOGO, "data"))
        sabado_16h = _t.struct_time((2026, 10, 31, 16, 0, 0, 5, 304, 0))  # sabado
        prox = infos.proximos_eventos(ev, sabado_16h)
        self.assertEqual([(e["nome"], e["quando"], e["hora"]) for e in prox],
                         [("Battlefield", "Amanhã", "15:00"), ("Loteria", "Amanhã", "15:00")])

    def test_ranking_por_vocacao(self):
        self.popular()
        html = self.c.get("/ranking?voc=sorcerer").get_data(as_text=True)
        self.assertIn("Henrique Mago", html)
        self.assertNotIn("Sir Joao Victor", html)

    def test_minha_conta(self):
        self.popular()
        t = self.csrf("/conta")
        r = self.c.post("/conta", data=dict(csrf=t, conta="joao123", senha="errada99"))
        self.assertEqual(r.status_code, 401)
        r = self.c.post("/conta", data=dict(csrf=t, conta="JOAO123", senha="segredo1"))
        self.assertEqual(r.status_code, 302)
        html = self.c.get("/conta").get_data(as_text=True)
        self.assertIn("Olá, joao123", html)
        self.assertIn("Sir Joao Victor", html)
        t = re.search(r'name="csrf" value="([^"]+)"', html).group(1)
        # novo personagem pela conta, sem digitar a senha de novo
        r = self.c.post("/conta/personagem", data=dict(csrf=t, personagem="Paladino Bom", vocacao="3", sexo="1"))
        self.assertEqual(r.status_code, 302)
        self.assertEqual(self.sql("SELECT account_id FROM players WHERE name='Paladino Bom'"), [(1,)])
        # trocar senha
        r = self.c.post("/conta/senha", data=dict(csrf=t, atual="errada", nova="novasenha1", nova2="novasenha1"))
        self.assertIn("A senha atual está errada", r.get_data(as_text=True))
        r = self.c.post("/conta/senha", data=dict(csrf=t, atual="segredo1", nova="novasenha1", nova2="novasenha1"))
        self.assertEqual(r.status_code, 302)
        self.assertEqual(self.sql("SELECT password FROM accounts WHERE id=1")[0][0],
                         hashlib.sha1(b"novasenha1").hexdigest())
        self.c.post("/conta/sair", data=dict(csrf=t))
        self.assertIn('name="senha"', self.c.get("/conta").get_data(as_text=True))

    def test_login_bloqueia_so_senha_errada(self):
        self.popular()
        portal.limite_login = portal.LimiteDeTaxa(maximo=3, janela_s=900)
        for _ in range(5):  # entrar certo nao gasta tentativas
            t = self.csrf("/conta")
            self.assertEqual(self.c.post("/conta", data=dict(csrf=t, conta="joao123", senha="segredo1")).status_code, 302)
            self.c.post("/conta/sair", data=dict(csrf=self.csrf("/conta")))
        t = self.csrf("/conta")
        for _ in range(3):
            self.assertEqual(self.c.post("/conta", data=dict(csrf=t, conta="joao123", senha="xxxxxx1")).status_code, 401)
        self.assertEqual(self.c.post("/conta", data=dict(csrf=t, conta="joao123", senha="segredo1")).status_code, 429)

    def test_tentativas_que_falham_nao_gastam_limite(self):
        # senha errada / nome repetido nao contam como "conta criada" (era o erro do print do celular)
        self.criar()
        for _ in range(8):
            self.assertEqual(self.criar(personagem="Outro Heroi").status_code, 400)  # conta repetida
        self.assertEqual(self.criar(conta="novaconta", personagem="Outro Heroi").status_code, 200)


class TesteModoWeb(unittest.TestCase):
    def test_botao_iphone_e_ip_real(self):
        import importlib
        os.environ.update(URL_WEB="https://meubaiak.duckdns.org/jogar/", ATRAS_DE_PROXY="1")
        try:
            web = importlib.reload(portal)
            vistos = []

            @web.app.get("/_ip")
            def _ip():
                vistos.append(web.ip_cliente())
                return "ok"

            c = web.app.test_client()
            html = c.get("/baixar", headers={"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)"}).get_data(as_text=True)
            self.assertIn("Jogar no navegador", html)
            self.assertIn("https://meubaiak.duckdns.org/jogar/", html)
            self.assertNotIn("Ainda nao existe cliente 8.60", html)
            c.get("/_ip", headers={"X-Forwarded-For": "198.51.100.7"}, environ_base={"REMOTE_ADDR": "172.18.0.5"})
            self.assertEqual(vistos, ["198.51.100.7"])
            self.assertTrue(web.app.config["SESSION_COOKIE_SECURE"])
        finally:
            os.environ.pop("URL_WEB")
            os.environ.pop("ATRAS_DE_PROXY")
            importlib.reload(portal)


if __name__ == "__main__":
    unittest.main(verbosity=1)
