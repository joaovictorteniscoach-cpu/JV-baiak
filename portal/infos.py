"""Le informacoes do servidor direto dos arquivos do jogo (somente leitura).

- config.lua: rates, estagios de experiencia, regras de PvP
- data/lib/events/*.lua e globalevents.xml: agenda de eventos
Tudo com cache curto e tolerante a arquivo ausente (o site nunca quebra por isso).
"""
from __future__ import annotations

import os
import re
import time

DIAS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
DIAS_PT = {"Sunday": "Domingo", "Monday": "Segunda", "Tuesday": "Terça", "Wednesday": "Quarta",
           "Thursday": "Quinta", "Friday": "Sexta", "Saturday": "Sábado"}
NOMES_EVENTOS = {
    "battlefield": "Battlefield", "firestorm": "Fire Storm", "safezone": "Safe Zone",
    "snowball": "Snowball", "castle48": "Castle 48h", "castle": "Castle War",
    "monsterHunt": "Monster Hunt", "bosses": "Bosses", "lottery": "Loteria",
}
MUNDOS = {"pvp": "PvP", "no-pvp": "Sem PvP", "pvp-enforced": "PvP Enforced",
          "retro-pvp": "Retro PvP", "expert-pvp": "Expert PvP"}

_cache: dict[str, tuple[float, object]] = {}


def _memo(chave, segundos, fn):
    agora = time.monotonic()
    if chave in _cache and agora - _cache[chave][0] < segundos:
        return _cache[chave][1]
    valor = fn()
    _cache[chave] = (agora, valor)
    return valor


def _ler(caminho: str) -> str:
    try:
        with open(caminho, encoding="latin-1") as f:
            return f.read()
    except OSError:
        return ""


def _sem_comentarios(lua: str) -> str:
    lua = re.sub(r"--\[\[.*?\]\]", "", lua, flags=re.S)
    return re.sub(r"--[^\n]*", "", lua)


def ler_config(texto: str) -> dict:
    """Extrai do config.lua o que interessa ao jogador."""
    texto = _sem_comentarios(texto)
    valores = {}
    for chave, valor in re.findall(r"^\s*([A-Za-z_]\w*)\s*=\s*([^\n{]+?)\s*$", texto, flags=re.M):
        valor = valor.strip().rstrip(",")
        if valor.startswith('"') and valor.endswith('"'):
            valores[chave] = valor[1:-1]
        elif valor in ("true", "false"):
            valores[chave] = valor == "true"
        else:
            try:
                valores[chave] = float(valor) if "." in valor else int(valor)
            except ValueError:
                try:  # expressoes simples como 24 * 60 * 60 * 1000
                    if re.fullmatch(r"[\d\s*+]+", valor):
                        valores[chave] = int(eval(valor, {"__builtins__": {}}))  # noqa: S307 - so digitos e * +
                except Exception:
                    pass
    estagios = []
    bloco = re.search(r"experienceStages\s*=\s*\{(.*?)\n\}", texto, flags=re.S)
    if bloco:
        for item in re.findall(r"\{([^{}]*)\}", bloco.group(1)):
            campos = dict(re.findall(r"(\w+)\s*=\s*([\d.]+)", item))
            if "minlevel" in campos and "multiplier" in campos:
                mult = float(campos["multiplier"])
                estagios.append({"de": int(campos["minlevel"]),
                                 "ate": int(campos["maxlevel"]) if "maxlevel" in campos else None,
                                 "multiplicador": int(mult) if mult.is_integer() else mult})
    valores["experienceStages"] = estagios
    return valores


def resumo_config(cfg: dict) -> dict:
    def num(chave, padrao=None):
        v = cfg.get(chave, padrao)
        return int(v) if isinstance(v, float) and v.is_integer() else v

    pz = cfg.get("pzLocked")
    return {
        "mundo": MUNDOS.get(str(cfg.get("worldType", "")).lower(), cfg.get("worldType")),
        "estagios": cfg.get("experienceStages") or [],
        "rate_exp": num("rateExp"),
        "rate_skill": num("rateSkill"),
        "rate_magia": num("rateMagic"),
        "rate_loot": num("rateLoot"),
        "protecao": num("protectionLevel"),
        "red_skull": num("killsToRedSkull"),
        "black_skull": num("killsToBlackSkull"),
        "pz_segundos": int(pz / 1000) if isinstance(pz, (int, float)) else None,
        "premium_gratis": cfg.get("freePremium"),
        "max_jogadores": num("maxPlayers"),
    }


def info_servidor(caminho_config: str) -> dict:
    return _memo(("cfg", caminho_config), 60, lambda: resumo_config(ler_config(_ler(caminho_config))))


def ler_dias(lua: str) -> dict:
    """Le blocos `days = { ["Sunday"] = {"15:00"}, ... }` de um script de evento."""
    lua = _sem_comentarios(lua)
    m = re.search(r"days\s*=\s*\{(.*?)\n\s*\}", lua, flags=re.S)
    if not m:
        return {}
    dias = {}
    for dia, horas in re.findall(r'\[\s*"(\w+)"\s*\]\s*=\s*\{([^}]*)\}', m.group(1)):
        if dia in DIAS:
            dias[dia] = sorted(re.findall(r'"(\d{1,2}:\d{2})', horas))
    return dias


def agenda(pasta_data: str) -> list[dict]:
    """Lista de eventos: [{'nome', 'dias': {dia: [horas]}}], ordenada pelo nome."""
    def montar():
        eventos = {}
        for sub in ("lib/events", "lib/custom"):
            pasta = os.path.join(pasta_data, sub)
            try:
                arquivos = sorted(os.listdir(pasta))
            except OSError:
                continue
            for arq in arquivos:
                if not arq.endswith(".lua"):
                    continue
                base = arq[:-4]
                dias = ler_dias(_ler(os.path.join(pasta, arq)))
                if dias:
                    eventos[base] = {"nome": NOMES_EVENTOS.get(base, base.capitalize()), "dias": dias}
        xml = _ler(os.path.join(pasta_data, "globalevents", "globalevents.xml"))
        for nome, hora in re.findall(r'<globalevent\s+name="([^"]+)"\s+time="(\d{1,2}:\d{2})', xml):
            if nome.lower() == "lottery":
                eventos["lottery"] = {"nome": "Loteria", "dias": {d: [hora] for d in DIAS}}
        return sorted(eventos.values(), key=lambda e: e["nome"])

    return _memo(("agenda", pasta_data), 300, montar)


def horario_save(pasta_data: str) -> str | None:
    xml = _ler(os.path.join(pasta_data, "globalevents", "globalevents.xml"))
    m = re.search(r'name="Server Save"\s+time="(\d{1,2}:\d{2})', xml)
    return m.group(1) if m else None


FUSO = "America/Sao_Paulo"


def agora_local():
    """Hora de Brasilia, mesmo se o container nao tiver o fuso instalado (usa o pacote tzdata)."""
    from datetime import datetime
    from zoneinfo import ZoneInfo

    return datetime.now(ZoneInfo(FUSO)).timetuple()


def resumo_dias(dias: dict) -> str:
    """{'Sunday': ['15:00'], 'Wednesday': ['15:00', '21:30']} -> 'Domingo e quarta, 15:00 · Quarta, 21:30'."""
    por_hora: dict[str, list[str]] = {}
    for dia in DIAS:
        for hora in dias.get(dia, []):
            por_hora.setdefault(hora, []).append(dia)
    partes = []
    for hora in sorted(por_hora, key=lambda h: tuple(map(int, h.split(":")))):
        lista = por_hora[hora]
        if len(lista) == 7:
            quando = "Todo dia"
        else:
            nomes = [DIAS_PT[d].lower() for d in lista]
            quando = nomes[0] if len(nomes) == 1 else ", ".join(nomes[:-1]) + " e " + nomes[-1]
            quando = quando[:1].upper() + quando[1:]
        partes.append(f"{quando}, {hora}")
    return " · ".join(partes)


def proximos_eventos(eventos: list[dict], agora_struct=None, limite=4) -> list[dict]:
    """Proxima vez de cada evento a partir de agora (hora de Brasilia, a mesma do servidor)."""
    t = agora_struct or agora_local()
    hoje = (t.tm_wday + 1) % 7  # time: segunda=0; DIAS: domingo=0
    agora_min = t.tm_hour * 60 + t.tm_min
    saida = []
    for desloc in range(0, 8):
        dia = DIAS[(hoje + desloc) % 7]
        for ev in eventos:
            for hora in ev["dias"].get(dia, []):
                h, m = map(int, hora.split(":"))
                if desloc == 0 and h * 60 + m < agora_min:
                    continue
                quando = "Hoje" if desloc == 0 else ("Amanhã" if desloc == 1 else DIAS_PT[dia])
                saida.append({"nome": ev["nome"], "quando": quando, "hora": hora, "ordem": desloc * 1440 + h * 60 + m})
    saida.sort(key=lambda e: e["ordem"])
    vistos, unicos = set(), []
    for e in saida:  # cada evento aparece uma vez (a loteria e todo dia e lotaria a lista)
        if e["nome"] not in vistos:
            vistos.add(e["nome"])
            unicos.append(e)
    return unicos[:limite]


# Comandos dos jogadores no Baiak Thunder (conferidos nos scripts do servidor)
COMANDOS = [
    ("Treino e personagem", [
        ("!treino", "Mostra o treino automático (entre numa sala de trainers)."),
        ("!spells", "Lista as magias da sua vocação."),
        ("!bless", "Compra as bênçãos (protege skills e itens ao morrer)."),
        ("!aol", "Compra um Amulet of Loss."),
        ("!autoloot", "Gerencia a lista de itens que você pega automaticamente."),
        ("!dodge / !critical", "Mostra e evolui seus níveis de dodge e critical."),
        ("!onlinebonus", "Mostra o bônus por tempo online."),
        ("!deathlist nome", "Mostra as últimas mortes de um personagem."),
        ("!kills", "Mostra suas mortes injustificadas (skull)."),
    ]),
    ("Dinheiro e itens", [
        ("!bank", "Banco: depositar, sacar e ver saldo."),
        ("!offer", "Leilão entre jogadores (use em área protegida)."),
        ("!addon", "Troca o addon doll por um addon."),
        ("!machete", "Compra uma machete."),
        ("!sellpoints", "Vende seus premium points."),
    ]),
    ("Guild e PvP", [
        ("!war", "Declara e gerencia guerras entre guilds."),
        ("!guildoutfit", "Copia a sua roupa para a guild."),
        ("!alvo nome", "Líder da guild marca um alvo para todos."),
        ("!hunted", "Coloca recompensa na cabeça de um jogador."),
        ("!castle48", "Votação do Castle 48h."),
    ]),
    ("Casas", [
        ("!buyhouse", "Compra a casa (olhando para a porta)."),
        ("!sellhouse nome", "Vende/transfere a casa para outro jogador."),
        ("!leavehouse", "Abandona a casa."),
    ]),
    ("Informações", [
        ("!online", "Quantos jogadores estão online."),
        ("!serverinfo", "Rates e informações do servidor."),
        ("!uptime", "Há quanto tempo o servidor está ligado."),
        ("!rank", "Rankings dentro do jogo."),
        ("!boostcreature", "Criatura com bônus de experiência e loot."),
    ]),
]
