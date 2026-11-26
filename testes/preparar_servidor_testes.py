"""Baixa os arquivos de fonte necessarios e aplica TODOS os patches do servidor.
Nao instala nem inicia servicos. Uso: python testes/preparar_servidor_testes.py /tmp/fonte
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import subprocess
import sys
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]


def preparar(destino):
    destino = Path(destino)
    destino.mkdir(parents=True, exist_ok=True)
    commit = re.search(r'BAIAK_COMMIT="([a-f0-9]{40})"', (ROOT/'instalar.sh').read_text())[1]
    patches = sorted((ROOT/'servidor-imagem/patches').glob('*.patch'))
    arquivos = {'data/items/items.xml', 'data/XML/outfits.xml',
                'data/actions/scripts/quests/quests.lua',
                'data/actions/scripts/quests/medusaAnihiPremio.lua',
                'data/actions/scripts/quests/medusaAnihi.lua'}
    for patch in patches:
        arquivos.update(re.findall(r'^--- a/(.+)$', patch.read_text(), re.M))

    def baixar(nome):
        if '..' in Path(nome).parts or Path(nome).is_absolute():
            raise ValueError('Caminho fora da fonte')
        arquivo = destino/nome
        arquivo.parent.mkdir(parents=True, exist_ok=True)
        url = f'https://raw.githubusercontent.com/moviebr/baiakthunder/{commit}/{nome}'
        with urlopen(url, timeout=60) as resposta:
            arquivo.write_bytes(resposta.read())

    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(baixar, sorted(arquivos)))
    subprocess.run(['git','init','-q',str(destino)],check=True)
    for patch in patches:
        subprocess.run(['git','-C',str(destino),'apply','--check',str(patch)],check=True)
        subprocess.run(['git','-C',str(destino),'apply',str(patch)],check=True)
    print(f'Fonte {commit[:7]} com {len(patches)} patches conferidos')


if __name__ == '__main__':
    preparar(sys.argv[1])
