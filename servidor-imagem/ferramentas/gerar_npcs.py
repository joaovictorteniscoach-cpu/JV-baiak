"""Gera os NPCs de loja que faltavam no JV Baiak (estilo Tibia 8.60) e diz onde ficam.

Os ids dos itens saem do items.xml do proprio servidor (pelo nome), entao nada fica
com id errado. Uso: python gerar_npcs.py items.xml pasta_npc/ saida_posicoes.txt
Precos parecidos com os NPCs do Tibia 8.60 (compra = o que o jogador paga;
venda = o que o NPC paga pelo item do jogador).
"""
import re
import sys

# nome do item: (preco de compra pelo jogador ou 0 = nao vende, preco que o NPC paga ou 0)
ARMAS = {
    "sword": (85, 25), "longsword": (160, 51), "two handed sword": (950, 450), "carlin sword": (473, 118),
    "spike sword": (8000, 1000), "broadsword": (0, 500), "serpent sword": (0, 900), "fire sword": (0, 4000),
    "bright sword": (0, 6000), "giant sword": (0, 17000), "ice rapier": (0, 1000), "magic longsword": (0, 0),
    "axe": (20, 7), "hatchet": (25, 25), "battle axe": (235, 80), "double axe": (0, 260), "halberd": (0, 400),
    "barbarian axe": (0, 185), "knight axe": (0, 2000), "fire axe": (0, 8000), "dragon lance": (0, 9000),
    "war axe": (0, 12000), "guardian halberd": (0, 11000), "naginata": (0, 2000),
    "club": (5, 1), "mace": (90, 30), "morning star": (430, 100), "war hammer": (10000, 470),
    "clerical mace": (0, 170), "dragon hammer": (0, 2000), "skull staff": (0, 6000), "crystal mace": (0, 12000),
    "battle hammer": (350, 120), "spiked squelcher": (0, 5000),
    "spear": (10, 3), "throwing star": (42, 0), "throwing knife": (25, 2), "small stone": (0, 0),
    "bow": (400, 100), "crossbow": (500, 120), "arrow": (3, 0), "bolt": (4, 0), "power bolt": (14, 0),
    "royal spear": (15, 0), "enchanted spear": (30, 0), "onyx arrow": (7, 0), "piercing bolt": (5, 0),
    "sniper arrow": (5, 0), "infernal bolt": (12, 0),
}
ESCUDOS = {
    "wooden shield": (15, 5), "brass shield": (65, 25), "plate shield": (125, 45), "copper shield": (0, 50),
    "steel shield": (240, 80), "dwarven shield": (500, 100), "battle shield": (0, 95), "guardian shield": (0, 2000),
    "dragon shield": (0, 4000), "crown shield": (0, 8000), "tower shield": (0, 8000), "beholder shield": (0, 1200),
    "black shield": (0, 800), "medusa shield": (0, 9000), "vampire shield": (0, 15000), "demon shield": (0, 30000),
    "mastermind shield": (0, 50000), "phoenix shield": (0, 16000), "spellbook": (150, 0),
}
ARMADURAS = {
    "leather armor": (25, 12), "chain armor": (200, 70), "brass armor": (450, 150), "plate armor": (1200, 400),
    "scale armor": (0, 75), "dark armor": (0, 400), "noble armor": (0, 900), "knight armor": (0, 5000),
    "crown armor": (0, 12000), "golden armor": (0, 20000), "blue robe": (0, 10000), "dragon scale mail": (0, 40000),
    "magic plate armor": (0, 90000), "focus cape": (0, 6000), "lightning robe": (0, 11000), "magma coat": (0, 11000),
    "glacier robe": (0, 11000), "terra mantle": (0, 11000), "paladin armor": (0, 15000),
    "leather legs": (10, 9), "chain legs": (80, 25), "brass legs": (195, 49), "plate legs": (0, 115),
    "knight legs": (0, 5000), "crown legs": (0, 12000), "golden legs": (0, 30000), "blue legs": (0, 15000),
    "leather helmet": (12, 4), "chain helmet": (52, 17), "brass helmet": (120, 30), "steel helmet": (580, 293),
    "viking helmet": (265, 66), "dark helmet": (0, 250), "strange helmet": (0, 500), "mystic turban": (0, 150),
    "devil helmet": (0, 1000), "crown helmet": (0, 2500), "warrior helmet": (0, 5000), "crusader helmet": (0, 6000),
    "royal helmet": (0, 30000), "demon helmet": (0, 40000),
    "leather boots": (10, 2), "steel boots": (0, 30000), "boots of haste": (0, 30000),
}
MAGO = {
    "wand of vortex": (500, 100), "wand of dragonbreath": (1000, 200), "wand of decay": (5000, 1000),
    "wand of cosmic energy": (10000, 2000), "wand of inferno": (15000, 3000),
    "snakebite rod": (500, 100), "moonlight rod": (1000, 200), "necrotic rod": (5000, 1000),
    "terra rod": (10000, 2000), "hailstorm rod": (15000, 3000), "spellbook": (150, 0),
    "health potion": (45, 0), "mana potion": (50, 0), "strong health potion": (100, 0),
    "strong mana potion": (80, 0), "great health potion": (190, 0), "great mana potion": (120, 0),
    "great spirit potion": (190, 0), "ultimate health potion": (310, 0), "blank rune": (10, 0),
    "life ring": (900, 50), "ring of healing": (0, 100), "might ring": (0, 250), "energy ring": (0, 100),
    "stealth ring": (0, 200), "time ring": (0, 100), "sword ring": (0, 100), "axe ring": (0, 100),
    "club ring": (0, 100), "dwarven ring": (0, 100), "platinum amulet": (0, 2500), "stone skin amulet": (0, 500),
    "protection amulet": (0, 100), "elven amulet": (0, 100), "silver amulet": (0, 50),
}

NPCS = [
    # nome, script, aparencia (type, head, body, legs, feet, addons), saudacao, tabelas, posicao
    ("Ferreiro Joaquim", (131, 78, 57, 76, 95, 1), "Ola |PLAYERNAME|! Faco e compro {armas} e {escudos}. Diga {trade} para ver tudo.",
     [ARMAS, ESCUDOS], (1006, 1209, 7)),
    ("Armeira Lucia", (139, 96, 94, 114, 95, 1), "Ola |PLAYERNAME|! Vendo e compro {armaduras}, {calcas}, {capacetes} e {botas}. Diga {trade}.",
     [ARMADURAS], (1006, 1213, 7)),
    ("Mercador Ze", (128, 77, 63, 58, 115, 0), "Ola |PLAYERNAME|! Compro quase todo o loot de equipamento: armas, escudos e armaduras. Diga {trade}.",
     [{k: (0, v[1]) for t in (ARMAS, ESCUDOS, ARMADURAS) for k, v in t.items()}], (1005, 1206, 7)),
    ("Maga Iris", (138, 0, 86, 86, 86, 2), "Ola |PLAYERNAME|! Vendo {wands}, {rods}, {pocoes}, aneis e amuletos. Diga {trade}.",
     [MAGO], (1006, 1211, 7)),
]
# NPCs que ja existiam nos arquivos do Baiak, mas nao estavam no mapa
EXISTENTES = [("Riona", (978, 1209, 7)), ("Tyoric", (981, 1213, 7)), ("The Forgotten King", (976, 1206, 7))]


def ids_por_nome(xml):
    nomes = {}
    t = open(xml, encoding="latin-1").read()
    for m in re.finditer(r'<item (?:id="(\d+)"|fromid="(\d+)" toid="(\d+)")([^>]*)>', t):
        nome = re.search(r'name="([^"]*)"', m.group(4))
        if not nome:
            continue
        nome = nome.group(1).lower()
        i = int(m.group(1) or m.group(2))
        if i <= 11703 and nome not in nomes:
            nomes[nome] = i
    return nomes


def main():
    xml, pasta, saida = sys.argv[1:4]
    ids = ids_por_nome(xml)
    faltou = []
    posicoes = []
    for nome, look, saudacao, tabelas, pos in NPCS:
        compra, venda = [], []
        for tab in tabelas:
            for item, (pc, pv) in tab.items():
                if item not in ids:
                    faltou.append(item)
                    continue
                if pc:
                    compra.append("%s,%d,%d" % (item, ids[item], pc))
                if pv:
                    venda.append("%s,%d,%d" % (item, ids[item], pv))
        conteudo = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                    '<npc name="%s" script="default.lua" walkinterval="0" floorchange="0">\n'
                    '\t<health now="100" max="100" />\n'
                    '\t<look type="%d" head="%d" body="%d" legs="%d" feet="%d" addons="%d" />\n'
                    '\t<parameters>\n'
                    '\t\t<parameter key="module_shop" value="1" />\n'
                    '\t\t<parameter key="message_greet" value="%s" />\n'
                    '%s%s'
                    '\t</parameters>\n</npc>\n') % (
            nome, *look, saudacao,
            ('\t\t<parameter key="shop_buyable" value="%s" />\n' % ";".join(sorted(set(compra)))) if compra else "",
            ('\t\t<parameter key="shop_sellable" value="%s" />\n' % ";".join(sorted(set(venda)))) if venda else "")
        open("%s/%s.xml" % (pasta, nome), "w", encoding="latin-1").write(conteudo)
        posicoes.append((nome, pos))
        print("%s: vende %d, compra %d" % (nome, len(set(compra)), len(set(venda))))
    # tabela de precos para o !venderloot (o que o Mercador Ze paga)
    precos = {}
    for tab in (ARMAS, ESCUDOS, ARMADURAS, MAGO):
        for item, (pc, pv) in tab.items():
            if pv and item in ids:
                precos[ids[item]] = max(pv, precos.get(ids[item], 0))
    with open("%s/../scripts/custom/jv_precos.lua" % pasta, "w") as f:
        f.write("-- Gerado por servidor-imagem/ferramentas/gerar_npcs.py: id do item -> preco pago no !venderloot\n")
        f.write("JV_PRECOS = {\n")
        for i in sorted(precos):
            f.write("\t[%d] = %d,\n" % (i, precos[i]))
        f.write("}\n")
    posicoes += EXISTENTES
    with open(saida, "w") as f:
        for nome, (x, y, z) in posicoes:
            f.write("%s;%d;%d;%d\n" % (nome, x, y, z))
    if faltou:
        print("itens sem id (ignorados):", ", ".join(sorted(set(faltou))))


if __name__ == "__main__":
    main()
