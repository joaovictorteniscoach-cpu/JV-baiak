"""Acrescenta a magia ao catalogo existente, sem substituir as demais magias."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

SPELL = '''\t<instant group="support" spellid="250" name="Vampirismo" words="utito vita sanguis" level="200" mana="250" premium="0" aggressive="0" selftarget="1" exhaustion="60000" groupcooldown="2000" needlearn="0" script="support/jv_vampirismo.lua">
\t</instant>
'''

def registrar(data):
    arquivo = Path(data) / 'spells/spells.xml'
    raw = arquivo.read_bytes()
    texto = raw.decode('latin-1')
    ET.fromstring(texto)
    existentes = re.findall(r'<instant\b[^>]*\b(?:name="Vampirismo"|words="utito vita sanguis")[^>]*>', texto, re.I)
    if existentes:
        if len(existentes) != 1 or 'script="support/jv_vampirismo.lua"' not in existentes[0]:
            raise ValueError('Nome ou palavras de Vampirismo ja usados por outra magia')
        return 0
    if re.search(r'\bspellid="250"', texto, re.I):
        raise ValueError('ID 250 de magia ja usado')
    if texto.count('</spells>') != 1:
        raise ValueError('Catalogo de magias invalido')
    novo = texto.replace('</spells>', SPELL + '</spells>')
    ET.fromstring(novo)
    temporario = arquivo.with_suffix('.xml.vampirismo.tmp')
    temporario.write_bytes(novo.encode('latin-1'))
    temporario.replace(arquivo)
    return 1

if __name__ == '__main__':
    print(registrar(sys.argv[1]))
