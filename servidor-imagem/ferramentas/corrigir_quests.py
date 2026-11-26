#!/usr/bin/env python3
"""Atualiza apenas scripts originais conhecidos, preservando versoes customizadas."""
from pathlib import Path
from hashlib import sha256
import sys

ORIGINAIS = {
    'quests.lua': '4a502841cceae49d9bbd002bbb017ceeab418f20507b2a83374bd94f5a356f09',
    'medusaAnihiPremio.lua': 'b010164a68c977cb1c3598a8fa1222d0f8026299632e3eeee5a9e34f091b7292',
    'medusaAnihi.lua': 'd217c672275c6ae667357686cce20a612a4bc745f30a2c026ed40239784d5401',
}
VERSOES_ANTERIORES = {'medusaAnihi.lua': {'e7c6eabd24398d631ee6e954f4a95ffb5b36fa186bc1c3fe1b94437bc9282d9f'}}
MODELOS = Path(__file__).resolve().parent.parent / 'ajustes/quests'

def aplicar(data):
    atualizados=[]
    for nome, esperado in ORIGINAIS.items():
        destino=Path(data)/'actions/scripts/quests'/nome
        if not destino.exists():
            raise ValueError(f'Quest ausente: {destino}')
        atual=destino.read_bytes(); novo=(MODELOS/nome).read_bytes()
        if atual == novo: continue
        if sha256(atual).hexdigest() not in {esperado, *VERSOES_ANTERIORES.get(nome, set())}:
            raise ValueError(f'Quest personalizada nao foi substituida: {destino}')
        atualizados.append((destino,novo))
    for destino,novo in atualizados:
        tmp=destino.with_name(destino.name+'.jv.tmp')
        tmp.write_bytes(novo);tmp.chmod(destino.stat().st_mode);tmp.replace(destino)
    return len(atualizados)

if __name__ == '__main__':print(aplicar(sys.argv[1]))
