"""Dobra uma vez a frequencia dos bosses dos arquivos de spawn, preservando o XML."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

MARCA = b'<!-- jv-boss-respawn-2x -->'
TAG = re.compile(rb'<monster\b[^>]*?/\s*>')
NOME = re.compile(rb'\bname="([^"]+)"')
TEMPO = re.compile(rb'\bspawntime="(\d+)"')


def bosses(data):
    data = Path(data)
    root = ET.parse(data / 'monster/monsters.xml').getroot()
    nomes = {'juggernaut'}
    for reg in root.findall('monster'):
        nome, arquivo = reg.get('name'), reg.get('file')
        if not nome or not arquivo:
            continue
        path = data / 'monster' / arquivo
        boss = arquivo.replace('\\', '/').lower().startswith('bosses/')
        if not boss and path.is_file():
            try:
                monstro = ET.parse(path).getroot()
                boss = any(f.get('isboss') == '1' for f in monstro.findall('./flags/flag'))
            except ET.ParseError:
                continue
        if boss:
            nomes.add(nome.lower())
    return nomes


def aplicar(data, arquivos):
    nomes = bosses(data)
    total = 0
    for path in map(Path, arquivos):
        raw = path.read_bytes()
        ET.fromstring(raw)  # Falha antes de escrever caso o arquivo seja invalido.
        def trocar(m):
            nonlocal total
            tag = m.group()
            if raw[m.end():].startswith(MARCA):
                return tag
            nome, tempo = NOME.search(tag), TEMPO.search(tag)
            if not nome or not tempo or nome.group(1).decode('latin-1').lower() not in nomes:
                return tag
            antigo = int(tempo.group(1))
            if antigo < 4:
                return tag  # O motor exige mais de um segundo.
            novo = max(2, (antigo + 1) // 2)
            total += 1
            return tag[:tempo.start(1)] + str(novo).encode() + tag[tempo.end(1):] + MARCA
        novo = TAG.sub(trocar, raw)
        if novo != raw:
            ET.fromstring(novo)
            tmp = path.with_name(path.name + '.bosses.tmp')
            tmp.write_bytes(novo)
            tmp.chmod(path.stat().st_mode)
            tmp.replace(path)
    return total


if __name__ == '__main__':
    print(aplicar(sys.argv[1], sys.argv[2:]))
