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
import app as portal  # noqa: E402

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
  skill_dist_tries INT DEFAULT 0, skill_shielding INT DEFAULT 10, skill_shielding_tries INT DEFAULT 0);
CREATE TABLE players_online (player_id INT PRIMARY KEY);
"""


class TestePortal(unittest.TestCase):
    def setUp(self):
        fd, self.arq = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        con = sqlite3.connect(self.arq)
        con.executescript(DDL)
        con.close()
        portal.banco = portal.Banco(lambda: sqlite3.connect(self.arq), marcador="?")
        portal.limite_criacao = portal.LimiteDeTaxa(maximo=5, janela_s=3600)
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


if __name__ == "__main__":
    unittest.main(verbosity=1)
