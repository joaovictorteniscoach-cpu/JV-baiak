"""JV Baiak - portal do servidor (criar conta, personagens, ranking, downloads).

Pensado para celular primeiro. Fala direto com o banco do TFS 1.3 (Baiak Thunder).
"""
from __future__ import annotations

import hashlib
import hmac
import os
import re
import secrets
import socket
import threading
import time
from collections import defaultdict, deque
from contextlib import contextmanager

from flask import Flask, abort, render_template, request, send_from_directory, session

NOME_SERVIDOR = os.environ.get("NOME_SERVIDOR", "JV Baiak")
ENDERECO = os.environ.get("ENDERECO_SERVIDOR", "127.0.0.1")
SERVIDOR_JOGO = os.environ.get("SERVIDOR_JOGO", "servidor")
PASTA_DOWNLOADS = os.environ.get("PASTA_DOWNLOADS", os.path.join(os.path.dirname(__file__), "downloads"))
ARQ_BASE = re.sub(r"[^A-Za-z0-9]", "", NOME_SERVIDOR)

VOCACOES = {
    0: "Sem vocacao", 1: "Sorcerer", 2: "Druid", 3: "Paladin", 4: "Knight",
    5: "Master Sorcerer", 6: "Elder Druid", 7: "Royal Paladin", 8: "Elite Knight",
}
RANKINGS = {
    "level": ("Level", "level", "experience"),
    "magia": ("Magic Level", "maglevel", "manaspent"),
    "sword": ("Sword", "skill_sword", "skill_sword_tries"),
    "axe": ("Axe", "skill_axe", "skill_axe_tries"),
    "club": ("Club", "skill_club", "skill_club_tries"),
    "distance": ("Distance", "skill_dist", "skill_dist_tries"),
    "shielding": ("Shielding", "skill_shielding", "skill_shielding_tries"),
    "fist": ("Fist", "skill_fist", "skill_fist_tries"),
}
# Personagem novo: level 8 (mesmos valores dos "samples" classicos do TFS 8.60)
NOVO_PERSONAGEM = {"level": 8, "experience": 4200, "health": 185, "healthmax": 185,
                   "mana": 35, "manamax": 35, "cap": 470, "soul": 100, "town_id": 1}
VISUAL = {0: 136, 1: 128}  # sexo 0 = feminino, 1 = masculino
MAX_PERSONAGENS = 10
PALAVRAS_PROIBIDAS = {"gm", "god", "cm", "adm", "admin", "administrador", "tutor", "owner",
                      "dono", "staff", "suporte", "support", "gamemaster", "account", "manager"}

app = Flask(__name__)
app.secret_key = os.environ.get("PORTAL_SEGREDO") or secrets.token_hex(32)
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax",
                  MAX_CONTENT_LENGTH=64 * 1024)


# --------------------------------------------------------------------------- banco
class Banco:
    """Conexao simples por requisicao. Em producao usa PyMySQL."""

    def __init__(self, conectar, marcador="%s"):
        self._conectar = conectar
        self._marcador = marcador

    def _sql(self, sql):
        return sql if self._marcador == "%s" else sql.replace("%s", self._marcador)

    @contextmanager
    def transacao(self):
        con = self._conectar()
        try:
            cur = con.cursor()
            yield _Cursor(cur, self._sql)
            con.commit()
        except Exception:
            con.rollback()
            raise
        finally:
            con.close()

    def um(self, sql, params=()):
        with self.transacao() as c:
            return c.um(sql, params)

    def todos(self, sql, params=()):
        with self.transacao() as c:
            return c.todos(sql, params)


class _Cursor:
    def __init__(self, cur, conv):
        self._cur, self._conv = cur, conv

    def executa(self, sql, params=()):
        self._cur.execute(self._conv(sql), params)
        return self._cur.lastrowid

    def um(self, sql, params=()):
        self._cur.execute(self._conv(sql), params)
        return self._cur.fetchone()

    def todos(self, sql, params=()):
        self._cur.execute(self._conv(sql), params)
        return self._cur.fetchall()


def _conectar_mysql():
    import pymysql  # importado aqui para os testes nao precisarem dele

    return pymysql.connect(host=os.environ.get("DB_HOST", "db"), user=os.environ.get("DB_USUARIO", "jvbaiak"),
                           password=os.environ.get("DB_SENHA", ""), database=os.environ.get("DB_NOME", "jvbaiak"),
                           charset="utf8", connect_timeout=5, autocommit=False)


banco = Banco(_conectar_mysql)


# ------------------------------------------------------------------- utilidades
class LimiteDeTaxa:
    """Limita quantas contas/personagens um mesmo IP cria por janela de tempo."""

    def __init__(self, maximo, janela_s):
        self.maximo, self.janela = maximo, janela_s
        self._hist = defaultdict(deque)
        self._trava = threading.Lock()

    def permite(self, chave):
        agora = time.monotonic()
        with self._trava:
            fila = self._hist[chave]
            while fila and agora - fila[0] > self.janela:
                fila.popleft()
            if len(fila) >= self.maximo:
                return False
            fila.append(agora)
            return True


limite_criacao = LimiteDeTaxa(maximo=5, janela_s=3600)
_status_cache = {"t": 0.0, "online": False}


def servidor_online():
    agora = time.monotonic()
    if agora - _status_cache["t"] > 15:
        try:
            with socket.create_connection((SERVIDOR_JOGO, 7171), timeout=1.5):
                _status_cache["online"] = True
        except OSError:
            _status_cache["online"] = False
        _status_cache["t"] = agora
    return _status_cache["online"]


def sha1(texto):
    return hashlib.sha1(texto.encode("utf-8")).hexdigest()


def validar_conta(nome):
    nome = (nome or "").strip().lower()
    if not re.fullmatch(r"[a-z0-9]{4,20}", nome):
        return None, "A conta deve ter de 4 a 20 letras ou numeros, sem espacos."
    return nome, None


def validar_senha(senha, repetida):
    senha = senha or ""
    if not re.fullmatch(r"[\x21-\x7e]{6,29}", senha):
        return "A senha deve ter de 6 a 29 caracteres, sem espacos e sem acentos."
    if senha != repetida:
        return "As senhas nao conferem."
    return None


def validar_personagem(nome):
    nome = re.sub(r"\s+", " ", (nome or "").strip())
    if not re.fullmatch(r"[A-Za-z ]{3,20}", nome):
        return None, "O nome do personagem deve ter de 3 a 20 letras (sem acentos ou numeros)."
    palavras = nome.split(" ")
    if len(palavras) > 3 or any(len(p) < 2 for p in palavras):
        return None, "Use no maximo 3 palavras, cada uma com pelo menos 2 letras."
    if any(p.lower() in PALAVRAS_PROIBIDAS for p in palavras):
        return None, "Esse nome nao e permitido."
    if re.search(r"(.)\1\1", nome.lower()):
        return None, "O nome nao pode repetir a mesma letra 3 vezes seguidas."
    return " ".join(p[:1].upper() + p[1:].lower() for p in palavras), None


def ler_escolhas(form):
    try:
        vocacao = int(form.get("vocacao", ""))
        sexo = int(form.get("sexo", ""))
    except ValueError:
        return None, None, "Escolha a vocacao e o sexo."
    if vocacao not in (1, 2, 3, 4) or sexo not in (0, 1):
        return None, None, "Escolha a vocacao e o sexo."
    return vocacao, sexo, None


def inserir_personagem(cur, conta_id, nome, vocacao, sexo):
    v = NOVO_PERSONAGEM
    cur.executa(
        "INSERT INTO players (name, account_id, group_id, vocation, sex, level, experience, health, healthmax,"
        " mana, manamax, cap, soul, town_id, looktype, lookhead, lookbody, looklegs, lookfeet, conditions)"
        " VALUES (%s, %s, 1, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 78, 68, 58, 76, %s)",
        (nome, conta_id, vocacao, sexo, v["level"], v["experience"], v["health"], v["healthmax"],
         v["mana"], v["manamax"], v["cap"], v["soul"], v["town_id"], VISUAL[sexo], b""),
    )


def ip_cliente():
    return request.remote_addr or "?"


# ----------------------------------------------------------------- seguranca
@app.before_request
def _csrf():
    if "csrf" not in session:
        session["csrf"] = secrets.token_urlsafe(24)
    if request.method == "POST":
        enviado = request.form.get("csrf", "")
        if not hmac.compare_digest(enviado, session["csrf"]):
            abort(400)


@app.after_request
def _cabecalhos(resp):
    resp.headers["Content-Security-Policy"] = "default-src 'self'; img-src 'self' data:; style-src 'self'"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["Referrer-Policy"] = "same-origin"
    return resp


@app.context_processor
def _globais():
    return {"nome_servidor": NOME_SERVIDOR, "endereco": ENDERECO, "csrf": session.get("csrf", ""),
            "vocacoes": VOCACOES}


# --------------------------------------------------------------------- paginas
@app.get("/")
def inicio():
    online = None
    try:
        linha = banco.um("SELECT COUNT(*) FROM players_online")
        online = linha[0] if linha else 0
    except Exception:  # banco ainda subindo
        pass
    return render_template("inicio.html", no_ar=servidor_online(), online=online)


@app.route("/criar-conta", methods=["GET", "POST"])
def criar_conta():
    if request.method == "GET":
        return render_template("criar_conta.html", erro=None, f={})
    f = request.form
    conta, erro = validar_conta(f.get("conta"))
    erro = erro or validar_senha(f.get("senha"), f.get("senha2"))
    personagem, erro_p = validar_personagem(f.get("personagem"))
    erro = erro or erro_p
    vocacao, sexo, erro_v = ler_escolhas(f)
    erro = erro or erro_v
    email = (f.get("email") or "").strip()[:255]
    if not erro and email and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        erro = "E-mail invalido (ou deixe em branco)."
    if not erro and not limite_criacao.permite(ip_cliente()):
        erro = "Muitas contas criadas a partir da sua conexao. Tente de novo mais tarde."
    if not erro:
        try:
            with banco.transacao() as cur:
                if cur.um("SELECT id FROM accounts WHERE name = %s", (conta,)):
                    erro = "Essa conta ja existe. Escolha outro nome."
                elif cur.um("SELECT id FROM players WHERE name = %s", (personagem,)):
                    erro = "Ja existe um personagem com esse nome."
                else:
                    conta_id = cur.executa(
                        "INSERT INTO accounts (name, password, type, premdays, email, creation)"
                        " VALUES (%s, %s, 1, 0, %s, %s)", (conta, sha1(f.get("senha")), email, int(time.time())))
                    inserir_personagem(cur, conta_id, personagem, vocacao, sexo)
        except Exception:
            app.logger.exception("falha ao criar conta")
            erro = "Nao foi possivel criar a conta agora. Tente de novo em instantes."
    if erro:
        return render_template("criar_conta.html", erro=erro, f=f), 400
    return render_template("pronto.html", conta=conta, personagem=personagem)


@app.route("/novo-personagem", methods=["GET", "POST"])
def novo_personagem():
    if request.method == "GET":
        return render_template("novo_personagem.html", erro=None, f={})
    f = request.form
    conta, erro = validar_conta(f.get("conta"))
    personagem, erro_p = validar_personagem(f.get("personagem"))
    erro = erro or erro_p
    vocacao, sexo, erro_v = ler_escolhas(f)
    erro = erro or erro_v
    if not erro and not limite_criacao.permite(ip_cliente()):
        erro = "Muitas tentativas a partir da sua conexao. Tente de novo mais tarde."
    if not erro:
        try:
            with banco.transacao() as cur:
                linha = cur.um("SELECT id, password FROM accounts WHERE name = %s", (conta,))
                if not linha or not hmac.compare_digest(linha[1], sha1(f.get("senha") or "")):
                    erro = "Conta ou senha incorretas."
                elif cur.um("SELECT COUNT(*) FROM players WHERE account_id = %s", (linha[0],))[0] >= MAX_PERSONAGENS:
                    erro = f"Cada conta pode ter no maximo {MAX_PERSONAGENS} personagens."
                elif cur.um("SELECT id FROM players WHERE name = %s", (personagem,)):
                    erro = "Ja existe um personagem com esse nome."
                else:
                    inserir_personagem(cur, linha[0], personagem, vocacao, sexo)
        except Exception:
            app.logger.exception("falha ao criar personagem")
            erro = "Nao foi possivel criar o personagem agora. Tente de novo em instantes."
    if erro:
        return render_template("novo_personagem.html", erro=erro, f=f), 400
    return render_template("pronto.html", conta=conta, personagem=personagem)


@app.get("/ranking")
def ranking():
    tipo = request.args.get("tipo", "level")
    if tipo not in RANKINGS:
        tipo = "level"
    titulo, coluna, desempate = RANKINGS[tipo]
    linhas = []
    try:
        # coluna vem de uma lista fixa (RANKINGS), nunca do usuario
        linhas = banco.todos(
            f"SELECT name, vocation, level, {coluna} FROM players WHERE group_id < 2"
            f" ORDER BY {coluna} DESC, {desempate} DESC LIMIT 50")
    except Exception:
        app.logger.exception("falha no ranking")
    return render_template("ranking.html", linhas=linhas, tipo=tipo, titulo=titulo, rankings=RANKINGS)


@app.get("/baixar")
def baixar():
    ua = (request.headers.get("User-Agent") or "").lower()
    if "iphone" in ua or "ipad" in ua:
        aparelho = "ios"
    elif "android" in ua:
        aparelho = "android"
    else:
        aparelho = "pc"
    arquivos = {
        "android": f"{ARQ_BASE}-Android.apk",
        "windows": f"{ARQ_BASE}-Windows.zip",
    }
    disponivel = {k: os.path.isfile(os.path.join(PASTA_DOWNLOADS, v)) for k, v in arquivos.items()}
    return render_template("baixar.html", aparelho=aparelho, arquivos=arquivos, disponivel=disponivel)


@app.get("/downloads/<path:arquivo>")
def downloads(arquivo):
    if arquivo not in (f"{ARQ_BASE}-Android.apk", f"{ARQ_BASE}-Windows.zip", "SHA256SUMS.txt"):
        abort(404)
    return send_from_directory(PASTA_DOWNLOADS, arquivo, as_attachment=True, max_age=300)


@app.get("/saude")
def saude():
    return {"ok": True}


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000, debug=False)
