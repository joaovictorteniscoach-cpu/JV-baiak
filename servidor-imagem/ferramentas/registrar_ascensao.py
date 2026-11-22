"""Registra somente os monstros de Ascensao; nao modifica mapa, spawns ou loot base."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


def registrar(data):
    data = Path(data)
    arquivo = data / 'monster/monsters.xml'
    raw = arquivo.read_bytes()
    texto = raw.decode('latin-1')
    novos = []
    for monstro in sorted((data / 'monster/Ascensao').glob('*.xml')):
        nome = ET.parse(monstro).getroot().get('name')
        caminho = 'Ascensao/' + monstro.name
        existente = re.search(r'<monster\s+name="' + re.escape(nome) + r'"\s+file="([^"]+)"\s*/>', texto, re.I)
        if existente:
            if existente[1] != caminho:
                raise ValueError('Nome de monstro ja usado por outro arquivo: ' + nome)
        else:
            novos.append(f'\t<monster name="{nome}" file="{caminho}"/>\n')
    if novos:
        if texto.count('</monsters>') != 1:
            raise ValueError('monsters.xml invalido')
        novo = texto.replace('</monsters>', ''.join(novos) + '</monsters>')
        ET.fromstring(novo)
        temporario = arquivo.with_suffix('.xml.ascensao.tmp')
        temporario.write_bytes(novo.encode('latin-1'))
        temporario.replace(arquivo)
    return len(novos)


if __name__ == '__main__':
    print(registrar(sys.argv[1]))
