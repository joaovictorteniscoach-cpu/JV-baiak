"""Conecta as oito rolagens aos eventos existentes sem substituir scripts locais."""
from pathlib import Path
import sys

MUDANCAS = {
    'events/scripts/monster.lua': [(b'corpse:createLootItem(monsterLoot[i])', b'JV_LOOT_MULTIPLO.gerar(corpse, monsterLoot[i])')],
    'creaturescripts/scripts/custom/reward/reward.lua': [
        (b'bag:addItem(p[1], p[2])', b'JV_LOOT_MULTIPLO.adicionar(bag, p[1], p[2])'),
        (b'reward:addItem(p[1], p[2])', b'JV_LOOT_MULTIPLO.adicionar(reward, p[1], p[2])'),
    ],
}


def registrar(data):
    alteracoes=[]
    for arquivo,trocas in MUDANCAS.items():
        path=Path(data)/arquivo
        original=path.read_bytes();novo=original
        for antes,depois in trocas:
            if novo.count(depois)==1 and antes not in novo:
                continue
            if novo.count(antes)!=1 or depois in novo:
                raise ValueError(f'Script diferente do esperado: {path}')
            novo=novo.replace(antes,depois,1)
        if novo!=original:alteracoes.append((path,novo))
    for path,novo in alteracoes:
        tmp=path.with_name(path.name+'.loot8.tmp');tmp.write_bytes(novo)
        tmp.chmod(path.stat().st_mode);tmp.replace(path)
    return len(alteracoes)


if __name__=='__main__':
    print(registrar(sys.argv[1]))
