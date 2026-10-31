"""JV Baiak - portal do servidor.

Contas, personagens, quem esta online, ranking, mortes, guilds, casas,
informacoes do servidor (rates, eventos, comandos) e downloads.

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

from datetime import datetime
from zoneinfo import ZoneInfo

from flask import Flask, abort, redirect, render_template, request, send_from_directory, session, url_for

import infos

NOME_SERVIDOR = os.environ.get("NOME_SERVIDOR", "JV Baiak")
ENDERECO = os.environ.get("ENDERECO_SERVIDOR", "127.0.0.1")
SERVIDOR_JOGO = os.environ.get("SERVIDOR_JOGO", "servidor")
PASTA_DOWNLOADS = os.environ.get("PASTA_DOWNLOADS", os.path.join(os.path.dirname(__file__), "downloads"))
ARQ_BASE = re.sub(r"[^A-Za-z0-9]", "", NOME_SERVIDOR)
URL_WEB = os.environ.get("URL_WEB", "")  # cliente web (modo HTTPS), se ativado
ATRAS_DE_PROXY = os.environ.get("ATRAS_DE_PROXY") == "1"
# Identidade do site: os fundadores e a familia (mude no .env se quiser)
FUNDADORES = os.environ.get("FUNDADORES", "João Victor e Henrique")
FAMILIA = os.environ.get("FAMILIA", "Carnicini Soubhi")
CONFIG_LUA = os.environ.get("CONFIG_LUA", "/srv/config.lua")
PASTA_DATA = os.environ.get("PASTA_DATA", "/srv/data")
FUSO = ZoneInfo(infos.FUSO)
CIDADES = {1: "Thunder City", 2: "Jamila Island", 3: "Akravi", 4: "Al Arar", 5: "Bhark",
           6: "Wintermere", 7: "Shadow Wood", 8: "Premia"}
GRUPOS_VOCACAO = {"sorcerer": (1, 5), "druid": (2, 6), "paladin": (3, 7), "knight": (4, 8)}

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
if ATRAS_DE_PROXY:
    # Atras do Caddy (HTTPS): o IP real do jogador vem no X-Forwarded-For
    from werkzeug.middleware.proxy_fix import ProxyFix

    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)
    app.config["SESSION_COOKIE_SECURE"] = True


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

    def _fila(self, chave):
        agora = time.monotonic()
        fila = self._hist[chave]
        while fila and agora - fila[0] > self.janela:
            fila.popleft()
        return fila, agora

    def permite(self, chave):
        """Conta uma tentativa; False se o limite ja foi atingido."""
        with self._trava:
            fila, agora = self._fila(chave)
            if len(fila) >= self.maximo:
                return False
            fila.append(agora)
            return True

    def esgotado(self, chave):
        """So consulta, sem contar tentativa."""
        with self._trava:
            return len(self._fila(chave)[0]) >= self.maximo


limite_criacao = LimiteDeTaxa(maximo=10, janela_s=3600)  # contas/personagens criados com sucesso por IP
limite_login = LimiteDeTaxa(maximo=10, janela_s=900)  # tentativas de login erradas por IP
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


def _iniciais(texto, separador=None):
    partes = [p for p in (re.split(separador, texto) if separador else texto.split()) if p.strip()]
    letras = [p.strip()[0].upper() for p in partes][:2]
    return (letras + ["", ""])[:2]


INICIAIS_FUNDADORES = _iniciais(FUNDADORES, r"\s+e\s+|\s*&\s*|\s*,\s*")
INICIAIS_FAMILIA = "".join(_iniciais(FAMILIA))


@app.context_processor
def _globais():
    return {"nome_servidor": NOME_SERVIDOR, "endereco": ENDERECO, "csrf": session.get("csrf", ""),
            "vocacoes": VOCACOES, "url_web": URL_WEB, "cidades": CIDADES,
            "conta_logada": session.get("conta_nome"), "pagina": request.endpoint,
            "fundadores": FUNDADORES, "familia": FAMILIA, "iniciais": INICIAIS_FUNDADORES,
            "iniciais_familia": INICIAIS_FAMILIA}


@app.template_filter("data")
def _filtro_data(ts):
    if not ts:
        return "nunca"
    return datetime.fromtimestamp(int(ts), FUSO).strftime("%d/%m/%Y %H:%M")


@app.template_filter("ha")
def _filtro_ha(ts):
    """'há 5 min', 'há 2 h', 'há 3 dias'."""
    if not ts:
        return "nunca"
    seg = max(0, int(time.time()) - int(ts))
    if seg < 60:
        return "agora"
    if seg < 3600:
        return f"há {seg // 60} min"
    if seg < 86400:
        return f"há {seg // 3600} h"
    return f"há {seg // 86400} dia{'s' if seg >= 172800 else ''}"


@app.template_filter("milhar")
def _filtro_milhar(n):
    return f"{int(n or 0):,}".replace(",", ".")


@app.template_filter("horas")
def _filtro_horas(seg):
    seg = int(seg or 0)
    return f"{seg // 3600} h {seg % 3600 // 60} min"


def consulta(sql, params=(), padrao=None, um=False):
    """Consulta que nunca derruba a pagina (banco ainda subindo, tabela vazia etc.)."""
    try:
        return banco.um(sql, params) if um else banco.todos(sql, params)
    except Exception:
        app.logger.exception("falha na consulta")
        return padrao


# --------------------------------------------------------------------- paginas
@app.get("/")
def inicio():
    online = consulta("SELECT COUNT(*) FROM players_online", um=True)
    recorde = consulta("SELECT value FROM server_config WHERE config = 'players_record'", um=True)
    top = consulta("SELECT name, level, vocation FROM players WHERE group_id < 2 ORDER BY experience DESC LIMIT 5", padrao=[])
    mortes = consulta(SQL_MORTES + " LIMIT 5", padrao=[])
    eventos = infos.proximos_eventos(infos.agenda(PASTA_DATA))
    return render_template("inicio.html", no_ar=servidor_online(), online=online[0] if online else None,
                           recorde=recorde[0] if recorde else None, top=top, mortes=mortes, eventos=eventos,
                           srv=infos.info_servidor(CONFIG_LUA))


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
    if not erro and limite_criacao.esgotado(ip_cliente()):
        erro = "Muitas contas criadas a partir da sua internet na última hora. Tente de novo mais tarde."
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
            if not erro:
                limite_criacao.permite(ip_cliente())
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
    ip = ip_cliente()
    if not erro and limite_login.esgotado(ip):
        erro = "Muitas senhas erradas seguidas. Espere 15 minutos e tente de novo."
    if not erro and limite_criacao.esgotado(ip):
        erro = "Muitos personagens criados a partir da sua internet na última hora. Tente de novo mais tarde."
    if not erro:
        try:
            with banco.transacao() as cur:
                linha = cur.um("SELECT id, password FROM accounts WHERE name = %s", (conta,))
                if not linha or not hmac.compare_digest(linha[1], sha1(f.get("senha") or "")):
                    limite_login.permite(ip)
                    erro = "Conta ou senha incorretas."
                elif cur.um("SELECT COUNT(*) FROM players WHERE account_id = %s", (linha[0],))[0] >= MAX_PERSONAGENS:
                    erro = f"Cada conta pode ter no maximo {MAX_PERSONAGENS} personagens."
                elif cur.um("SELECT id FROM players WHERE name = %s", (personagem,)):
                    erro = "Ja existe um personagem com esse nome."
                else:
                    inserir_personagem(cur, linha[0], personagem, vocacao, sexo)
            if not erro:
                limite_criacao.permite(ip)
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
    voc = request.args.get("voc", "")
    if voc not in GRUPOS_VOCACAO:
        voc = ""
    titulo, coluna, desempate = RANKINGS[tipo]
    # coluna vem de uma lista fixa (RANKINGS), nunca do usuario
    sql = f"SELECT name, vocation, level, {coluna} FROM players WHERE group_id < 2"
    params = ()
    if voc:
        sql += " AND vocation IN (%s, %s)"
        params = GRUPOS_VOCACAO[voc]
    linhas = consulta(sql + f" ORDER BY {coluna} DESC, {desempate} DESC LIMIT 50", params, padrao=[])
    return render_template("ranking.html", linhas=linhas, tipo=tipo, titulo=titulo, rankings=RANKINGS,
                           voc=voc, grupos=GRUPOS_VOCACAO)


SQL_MORTES = ("SELECT p.name, d.time, d.level, d.killed_by, d.is_player, d.mostdamage_by, "
              "d.mostdamage_is_player, d.unjustified FROM player_deaths d JOIN players p ON p.id = d.player_id "
              "ORDER BY d.time DESC")


@app.get("/online")
def online():
    jogadores = consulta("SELECT p.name, p.level, p.vocation FROM players p "
                         "JOIN players_online o ON o.player_id = p.id ORDER BY p.level DESC", padrao=[])
    recorde = consulta("SELECT value FROM server_config WHERE config = 'players_record'", um=True)
    return render_template("online.html", jogadores=jogadores, recorde=recorde[0] if recorde else None,
                           no_ar=servidor_online())


@app.get("/personagem")
def personagem():
    nome = re.sub(r"\s+", " ", (request.args.get("nome") or "").strip())[:30]
    if not nome:
        return render_template("personagem.html", p=None, nome="", sugestoes=[])
    p = consulta("SELECT id, name, level, vocation, maglevel, skill_fist, skill_club, skill_sword, skill_axe, "
                 "skill_dist, skill_shielding, skill_fishing, town_id, lastlogin, sex, onlinetime, group_id "
                 "FROM players WHERE name = %s", (nome,), um=True)
    if not p:
        sugestoes = consulta("SELECT name FROM players WHERE name LIKE %s ORDER BY level DESC LIMIT 10",
                             ("%" + nome.replace("%", "").replace("_", "") + "%",), padrao=[])
        return render_template("personagem.html", p=None, nome=nome, sugestoes=sugestoes), 404
    pid = p[0]
    guild = consulta("SELECT g.id, g.name, r.name FROM guild_membership m JOIN guilds g ON g.id = m.guild_id "
                     "JOIN guild_ranks r ON r.id = m.rank_id WHERE m.player_id = %s", (pid,), um=True)
    mortes = consulta("SELECT time, level, killed_by, is_player, mostdamage_by, mostdamage_is_player, unjustified "
                      "FROM player_deaths WHERE player_id = %s ORDER BY time DESC LIMIT 10", (pid,), padrao=[])
    casa = consulta("SELECT name, town_id FROM houses WHERE owner = %s", (pid,), um=True)
    esta_online = consulta("SELECT 1 FROM players_online WHERE player_id = %s", (pid,), um=True)
    return render_template("personagem.html", p=p, nome=nome, guild=guild, mortes=mortes, casa=casa,
                           esta_online=bool(esta_online), sugestoes=[])


@app.get("/mortes")
def mortes():
    return render_template("mortes.html", mortes=consulta(SQL_MORTES + " LIMIT 50", padrao=[]))


@app.get("/guilds")
def guilds():
    lista = consulta("SELECT g.id, g.name, g.motd, g.creationdata, p.name, COUNT(m.player_id) AS membros "
                     "FROM guilds g JOIN players p ON p.id = g.ownerid "
                     "LEFT JOIN guild_membership m ON m.guild_id = g.id "
                     "GROUP BY g.id, g.name, g.motd, g.creationdata, p.name ORDER BY membros DESC, g.name",
                     padrao=[])
    return render_template("guilds.html", guilds=lista)


@app.get("/guild/<int:gid>")
def guild(gid):
    g = consulta("SELECT g.id, g.name, g.motd, g.creationdata, p.name FROM guilds g "
                 "JOIN players p ON p.id = g.ownerid WHERE g.id = %s", (gid,), um=True)
    if not g:
        abort(404)
    membros = consulta("SELECT p.name, p.level, p.vocation, r.name, m.nick, "
                       "(SELECT COUNT(*) FROM players_online o WHERE o.player_id = p.id) "
                       "FROM guild_membership m JOIN players p ON p.id = m.player_id "
                       "JOIN guild_ranks r ON r.id = m.rank_id WHERE m.guild_id = %s "
                       "ORDER BY r.level DESC, p.level DESC", (gid,), padrao=[])
    guerras = consulta("SELECT name1, name2, status, started FROM guild_wars "
                       "WHERE (guild1 = %s OR guild2 = %s) ORDER BY started DESC LIMIT 10", (gid, gid), padrao=[])
    return render_template("guild.html", g=g, membros=membros, guerras=guerras)


@app.get("/casas")
def casas():
    try:
        cidade = int(request.args.get("cidade", "0"))
    except ValueError:
        cidade = 0
    sql = ("SELECT h.name, h.town_id, h.size, h.rent, h.beds, p.name FROM houses h "
           "LEFT JOIN players p ON p.id = h.owner")
    params = ()
    if cidade:
        sql += " WHERE h.town_id = %s"
        params = (cidade,)
    lista = consulta(sql + " ORDER BY h.town_id, h.name", params, padrao=[])
    livres = sum(1 for c in lista if not c[5])
    return render_template("casas.html", casas=lista, cidade=cidade, livres=livres)


@app.get("/servidor")
def servidor():
    eventos = infos.agenda(PASTA_DATA)
    return render_template("servidor.html", srv=infos.info_servidor(CONFIG_LUA), eventos=eventos,
                           resumo_dias=infos.resumo_dias, comandos=infos.COMANDOS,
                           save=infos.horario_save(PASTA_DATA))


# ------------------------------------------------------------------ minha conta
def conta_atual():
    cid = session.get("conta_id")
    if not cid:
        return None
    return consulta("SELECT id, name, email, creation FROM accounts WHERE id = %s", (cid,), um=True)


@app.route("/conta", methods=["GET", "POST"])
def conta():
    if request.method == "POST":
        nome = (request.form.get("conta") or "").strip().lower()
        senha = request.form.get("senha") or ""
        ip = ip_cliente()
        if limite_login.esgotado(ip):
            return render_template("login.html", erro="Muitas tentativas erradas. Espere 15 minutos.", nome=nome), 429
        linha = consulta("SELECT id, name, password FROM accounts WHERE name = %s", (nome,), um=True)
        if not linha or not hmac.compare_digest(linha[2], sha1(senha)):
            limite_login.permite(ip)
            return render_template("login.html", erro="Conta ou senha incorretas.", nome=nome), 401
        session.clear()
        session.update(conta_id=linha[0], conta_nome=linha[1], csrf=secrets.token_urlsafe(24))
        return redirect(url_for("conta"))
    c = conta_atual()
    if not c:
        session.pop("conta_id", None)
        session.pop("conta_nome", None)
        return render_template("login.html", erro=None, nome="")
    personagens = consulta("SELECT p.name, p.level, p.vocation, p.lastlogin, "
                           "(SELECT COUNT(*) FROM players_online o WHERE o.player_id = p.id) "
                           "FROM players p WHERE p.account_id = %s ORDER BY p.level DESC", (c[0],), padrao=[])
    return render_template("conta.html", c=c, personagens=personagens, msg=request.args.get("msg"),
                           max_personagens=MAX_PERSONAGENS, erro=None, f={})


@app.post("/conta/sair")
def sair():
    session.clear()
    return redirect(url_for("inicio"))


@app.post("/conta/senha")
def trocar_senha():
    c = conta_atual()
    if not c:
        return redirect(url_for("conta"))
    f = request.form
    erro = None
    linha = consulta("SELECT password FROM accounts WHERE id = %s", (c[0],), um=True)
    if not linha or not hmac.compare_digest(linha[0], sha1(f.get("atual") or "")):
        erro = "A senha atual está errada."
    erro = erro or validar_senha(f.get("nova"), f.get("nova2"))
    if not erro:
        try:
            with banco.transacao() as cur:
                cur.executa("UPDATE accounts SET password = %s WHERE id = %s", (sha1(f.get("nova")), c[0]))
        except Exception:
            app.logger.exception("falha ao trocar senha")
            erro = "Não foi possível trocar a senha agora."
    if erro:
        personagens = consulta("SELECT p.name, p.level, p.vocation, p.lastlogin, 0 FROM players p "
                               "WHERE p.account_id = %s ORDER BY p.level DESC", (c[0],), padrao=[])
        return render_template("conta.html", c=c, personagens=personagens, msg=None, erro=erro,
                               max_personagens=MAX_PERSONAGENS, f={}), 400
    return redirect(url_for("conta", msg="Senha alterada."))


@app.post("/conta/personagem")
def criar_personagem_logado():
    c = conta_atual()
    if not c:
        return redirect(url_for("conta"))
    f = request.form
    personagem, erro = validar_personagem(f.get("personagem"))
    vocacao, sexo, erro_v = ler_escolhas(f)
    erro = erro or erro_v
    if not erro and limite_criacao.esgotado(ip_cliente()):
        erro = "Muitos personagens criados a partir da sua internet na última hora. Tente de novo mais tarde."
    if not erro:
        try:
            with banco.transacao() as cur:
                if cur.um("SELECT COUNT(*) FROM players WHERE account_id = %s", (c[0],))[0] >= MAX_PERSONAGENS:
                    erro = f"Cada conta pode ter no máximo {MAX_PERSONAGENS} personagens."
                elif cur.um("SELECT id FROM players WHERE name = %s", (personagem,)):
                    erro = "Já existe um personagem com esse nome."
                else:
                    inserir_personagem(cur, c[0], personagem, vocacao, sexo)
            if not erro:
                limite_criacao.permite(ip_cliente())
        except Exception:
            app.logger.exception("falha ao criar personagem")
            erro = "Não foi possível criar o personagem agora."
    if erro:
        personagens = consulta("SELECT p.name, p.level, p.vocation, p.lastlogin, 0 FROM players p "
                               "WHERE p.account_id = %s ORDER BY p.level DESC", (c[0],), padrao=[])
        return render_template("conta.html", c=c, personagens=personagens, msg=None, erro=erro,
                               max_personagens=MAX_PERSONAGENS, f=f), 400
    return redirect(url_for("conta", msg=f"Personagem {personagem} criado."))


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
