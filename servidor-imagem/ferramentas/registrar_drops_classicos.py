"""Registra o evento de drops sem substituir loot, stats ou scripts existentes."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

EVENTO = 'JVArsenalClassico'
ARQUIVOS = ('Demons/demon.xml', 'Demons/juggernaut.xml')


def registrar(data):
    modificados = 0
    for nome in ARQUIVOS:
        arquivo = Path(data) / 'monster' / nome
        original = arquivo.read_bytes()
        texto = original.decode('utf-8')
        raiz = ET.fromstring(texto)
        eventos = [e for e in raiz.findall('./script/event') if e.get('name') == EVENTO]
        if len(eventos) > 1:
            raise ValueError(f'Evento duplicado em {arquivo}')
        if eventos:
            continue
        if raiz.find('script') is None:
            novo, n = re.subn(r'</monster\s*>', f'  <script><event name="{EVENTO}"/></script>\n</monster>', texto, count=1)
        else:
            novo, n = re.subn(r'</script\s*>', f'  <event name="{EVENTO}"/>\n</script>', texto, count=1)
        if n != 1 or len(ET.fromstring(novo).findall('./script/event')) < 1:
            raise ValueError(f'Nao foi possivel registrar evento em {arquivo}')
        arquivo.write_bytes(novo.encode('utf-8'))
        modificados += 1
    return modificados


if __name__ == '__main__':
    print(registrar(sys.argv[1]))
