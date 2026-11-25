#!/usr/bin/env python3
"""Multiplica por 10 a vida atual de animais e monstros, uma unica vez por arquivo.

Na primeira instalacao, arquivos originais ainda sem a marca anterior recebem 20x
para reproduzir o dobro historico seguido dos 10x. Em instalacoes existentes,
arquivos sem marca recebem 10x sobre o valor efetivamente presente.
"""
from pathlib import Path
import re
import sys

MARCA_ANTIGA = b'<!-- jv-vida-2x -->'
MARCA_NOVA = b'<!-- jv-vida-10x -->'
LIMITE = 2147483647  # Creature usa int32_t.
HEALTH = re.compile(rb'<health\b[^>]*>', re.IGNORECASE)
ATRIBUTO = re.compile(rb'\b(now|max)\s*=\s*(["\'])(\d+)\2', re.IGNORECASE)
MONSTRO = re.compile(rb'<monster\b', re.IGNORECASE)


def atualizar(pasta, instalacao_nova=False):
    mudancas = []
    for caminho in sorted(Path(pasta).rglob('*.xml')):
        if caminho.name == 'monsters.xml':
            continue
        dados = caminho.read_bytes()
        if MARCA_NOVA in dados or not MONSTRO.search(dados):
            continue
        health = HEALTH.search(dados)
        if not health:
            continue
        tag = health.group()
        atributos = list(ATRIBUTO.finditer(tag))
        if {a.group(1).lower() for a in atributos} != {b'now', b'max'} or len(atributos) != 2:
            raise ValueError(f'Vida invalida em {caminho}')
        fator = 20 if instalacao_nova and MARCA_ANTIGA not in dados else 10
        for a in atributos:
            if int(a.group(3)) * fator > LIMITE:
                raise ValueError(f'Vida excede limite do servidor em {caminho}')
        def aumentar(m):
            return m.group(0)[:m.start(3)-m.start(0)] + str(int(m.group(3))*fator).encode() + m.group(2)
        nova_tag = ATRIBUTO.sub(aumentar, tag)
        marcas = (b'' if MARCA_ANTIGA in dados else MARCA_ANTIGA) + MARCA_NOVA
        novo = dados[:health.start()] + nova_tag + marcas + dados[health.end():]
        mudancas.append((caminho, novo))
    # Validar todos os arquivos antes de alterar qualquer um.
    for caminho, novo in mudancas:
        tmp = caminho.with_name(caminho.name + '.vida.tmp')
        tmp.write_bytes(novo)
        tmp.chmod(caminho.stat().st_mode)
        tmp.replace(caminho)
    return len(mudancas)


if __name__ == '__main__':
    print(atualizar(sys.argv[1], len(sys.argv) > 2 and sys.argv[2] == 'nova'))
