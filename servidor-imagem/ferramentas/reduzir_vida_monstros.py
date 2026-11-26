#!/usr/bin/env python3
"""Reduz a vida atual em 1,8 uma vez por XML, sem alterar outros atributos."""
from pathlib import Path
import sys
from vida_monstros import HEALTH, ATRIBUTO, MONSTRO

MARCA = b'<!-- jv-vida-div-1.8 -->'

def reduzir(valor):
    return max(1, (valor * 5 + 4) // 9)

def atualizar(pasta):
    mudancas = []
    for caminho in sorted(Path(pasta).rglob('*.xml')):
        dados = caminho.read_bytes()
        if caminho.name == 'monsters.xml' or MARCA in dados or not MONSTRO.search(dados):
            continue
        health = HEALTH.search(dados)
        if not health:
            continue
        attrs = list(ATRIBUTO.finditer(health.group()))
        if len(attrs) != 2 or {a.group(1).lower() for a in attrs} != {b'now', b'max'}:
            raise ValueError(f'Vida invalida em {caminho}')
        def transformar(m):
            return m.group(0)[:m.start(3)-m.start(0)] + str(reduzir(int(m.group(3)))).encode() + m.group(2)
        novo = ATRIBUTO.sub(transformar, health.group())
        mudancas.append((caminho, dados[:health.start()] + novo + MARCA + dados[health.end():]))
    for caminho, dados in mudancas:
        tmp = caminho.with_name(caminho.name + '.vida.tmp')
        tmp.write_bytes(dados)
        tmp.chmod(caminho.stat().st_mode)
        tmp.replace(caminho)
    return len(mudancas)

if __name__ == '__main__':
    print(atualizar(sys.argv[1]))
