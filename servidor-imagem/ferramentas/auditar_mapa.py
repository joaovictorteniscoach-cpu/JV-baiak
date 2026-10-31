"""Auditoria estrutural offline. Não substitui abrir o mundo no motor do jogo."""
import argparse
import collections
import json
import re
import struct
from pathlib import Path
import xml.etree.ElementTree as ET


def nodes(path):
    data = Path(path).read_bytes()
    if data[:4] not in (b'\0\0\0\0', b'OTBM'):
        raise ValueError('Assinatura OTBM inválida')
    stack = []
    i = 4
    while i < len(data):
        b = data[i]; i += 1
        if b == 0xFE:
            if stack and not stack[-1][1]:
                stack[-1][1] = True
                yield 'start', bytes(stack[-1][0])
            stack.append([bytearray(), False])
        elif b == 0xFF:
            if not stack:
                raise ValueError('Fechamento OTBM sem abertura')
            content, started = stack.pop()
            if not started:
                yield 'start', bytes(content)
            yield 'end', bytes(content)
        else:
            if b == 0xFD:
                if i == len(data):
                    raise ValueError('Escape OTBM truncado')
                b = data[i]; i += 1
            if not stack or stack[-1][1]:
                raise ValueError('Dados OTBM fora das propriedades de um nó')
            stack[-1][0].append(b)
    if stack:
        raise ValueError('OTBM truncado: nós não fechados')


def map_tiles(path):
    tiles, houses, towns, areas = set(), set(), [], []
    header = None
    roots = 0
    for event, data in nodes(path):
        if not data:
            raise ValueError('Nó OTBM vazio')
        kind = data[0]
        if event == 'start':
            if header is None:
                header = dict(zip(('version','width','height','items_major','items_minor'), struct.unpack('<IHHII',data[1:17])))
                roots += 1
            elif kind == 4:
                areas.append(struct.unpack('<HHB',data[1:6]))
            elif kind in (5,14):
                if not areas:
                    raise ValueError('Tile sem área')
                x,y,z = areas[-1]
                tiles.add((x+data[1],y+data[2],z))
                if kind == 14:
                    houses.add(struct.unpack('<I',data[3:7])[0])
            elif kind == 13:
                name_len=struct.unpack('<H',data[5:7])[0]
                towns.append(struct.unpack('<HHB',data[7+name_len:12+name_len]))
        elif kind == 4:
            areas.pop()
    if header is None:
        raise ValueError('OTBM vazio')
    return header, tiles, houses, towns


def audit(server, world_dir=None, map_name=None):
    server=Path(server)
    config=(server/'config.lua').read_text(errors='replace')
    match=re.search(r'^mapName\s*=\s*[\"\']([^\"\']+)',config,re.M)
    if not match:
        raise ValueError('mapName não encontrado')
    world=Path(world_dir) if world_dir else server/'data/world'; name=map_name or match[1]
    registry=ET.parse(server/'data/monster/monsters.xml').getroot()
    registered={}; errors=[]
    for el in registry.findall('monster'):
        key=el.attrib['name'].casefold()
        if key in registered: errors.append({'tipo':'registro_duplicado','nome':key})
        registered[key]=el.attrib['file']
        path=server/'data/monster'/el.attrib['file']
        try:
            root=ET.parse(path).getroot()
            if root.tag!='monster': raise ValueError('Raiz diferente de monster')
        except (OSError,ET.ParseError,ValueError) as exc:
            errors.append({'tipo':'arquivo_monstro','nome':key,'arquivo':el.attrib['file'],'erro':str(exc)})
    spawns=ET.parse(world/(name+'-spawn.xml')).getroot()
    header,tiles,houses,towns=map_tiles(world/(name+'.otbm'))
    count=collections.Counter(); positions=collections.Counter(); absent=[]; bad_intervals=[]
    for area in spawns.findall('spawn'):
        cx,cy,cz=(int(area.attrib[k]) for k in ('centerx','centery','centerz'))
        for monster in area.findall('monster'):
            key=monster.attrib['name'].casefold(); count[key]+=1
            pos=(cx+int(monster.get('x',0)),cy+int(monster.get('y',0)),cz)
            positions[pos]+=1
            if pos not in tiles: absent.append({'nome':key,'posicao':pos})
            if not 1 < int(monster.attrib['spawntime']) <= 86400:
                bad_intervals.append({'nome':key,'tempo':monster.attrib['spawntime']})
    npc_names={p.stem.casefold() for p in (server/'data/npc').glob('*.xml')}
    missing_npcs=sorted({el.attrib['name'].casefold() for el in spawns.iter('npc')}-npc_names)
    defined_houses={int(h.attrib['houseid']) for h in ET.parse(world/(name+'-house.xml')).getroot()}
    recent=['cobra assassin','cobra scout','falcon knight','falcon paladin','gazer spectre','burster spectre','ripper spectre','lavafungus','turbulent elemental','bony sea devil','many faces','branchy crawler','rotten golem','cloak of terror']
    return {'mapa':name,'cabecalho':header,'tiles':len(tiles),'monstros_cadastrados':len(registered),
            'posicoes_monstros':sum(count.values()),'especies_no_mapa':len(count),
            'erros_arquivos_monstros':errors,'spawns_sem_cadastro':sorted(set(count)-set(registered)),
            'spawns_sem_tile':absent,'posicoes_sobrepostas':[{'posicao':p,'quantidade':n} for p,n in positions.items() if n>1],
            'npcs_sem_arquivo':missing_npcs,'tempos_invalidos':bad_intervals,'casas_sem_definicao':sorted(houses-defined_houses),
            'templos_sem_tile':[p for p in towns if p not in tiles],
            'amostra_monstros_modernos':{n:{'cadastrado':n in registered,'spawns':count[n]} for n in recent},
            'limites':'Auditoria estática da cópia informada. Não verifica walkability, scripts em execução, sprites, loot, quests, banco ou a instância Oracle.'}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('servidor',type=Path);p.add_argument('--mundo',type=Path);p.add_argument('--mapa');p.add_argument('--exigir-aprovado',action='store_true');args=p.parse_args()
    resultado=audit(args.servidor,args.mundo,args.mapa)
    print(json.dumps(resultado,ensure_ascii=False,indent=2))
    if args.exigir_aprovado and any(resultado[k] for k in ['erros_arquivos_monstros','spawns_sem_cadastro','spawns_sem_tile','tempos_invalidos','casas_sem_definicao','templos_sem_tile','npcs_sem_arquivo']):
        raise SystemExit(2)
