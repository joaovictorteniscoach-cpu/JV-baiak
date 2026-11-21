#!/usr/bin/env python3
"""JV Baiak: monstros com o DOBRO de vida (experiencia e loot iguais).

Uso: vida_monstros.py <pasta data/monster>
Dobra <health now=".." max=".."> de cada arquivo de monstro e marca o arquivo com
<!-- jv-vida-2x --> para nao dobrar de novo. Roda em toda atualizacao: arquivos que o
instalador recoloca (extras) voltam sem a marca e sao dobrados outra vez.
Imprime quantos arquivos mudaram.
"""
import os
import re
import sys

MARCA = "<!-- jv-vida-2x -->"
VIDA = re.compile(r'(<health\s+now=")(\d+)("\s+max=")(\d+)(")')


def dobrar(m):
    return "%s%d%s%d%s" % (m.group(1), int(m.group(2)) * 2, m.group(3), int(m.group(4)) * 2, m.group(5))


def main(pasta):
    mudou = 0
    for raiz, _, arquivos in os.walk(pasta):
        for nome in arquivos:
            if not nome.endswith(".xml") or nome == "monsters.xml":
                continue
            caminho = os.path.join(raiz, nome)
            texto = open(caminho, encoding="latin-1").read()
            if MARCA in texto or not VIDA.search(texto):
                continue
            novo, n = VIDA.subn(dobrar, texto, count=1)
            fim = novo.find(">", VIDA.search(novo).start()) + 1
            novo = novo[:fim] + MARCA + novo[fim:]
            open(caminho, "w", encoding="latin-1").write(novo)
            mudou += 1
    print(mudou)


if __name__ == "__main__":
    main(sys.argv[1])
