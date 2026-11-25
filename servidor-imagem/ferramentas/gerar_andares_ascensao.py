"""Gera variantes locais das hunts sem modificar mapa nem sprites.

Cada familia usa o XML existente como modelo. Os andares 1-4 sao mais faceis;
no 5 usa-se o proprio XML de base. Escrita idempotente na pasta Ascensao.
"""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

# arquivo, vida por andar, dano maximo corpo a corpo por andar
GRUPOS = [
    (('demonio_ascendido', 'arauto_das_brasas', 'master_snoop'), (7000, 10000, 14000, 19000, 25000), (180, 250, 330, 420, 550)),
    (('colosso_abissal', 'cavaleiro_do_abismo', 'dr_dre'), (14000, 20000, 28000, 38000, 50000), (350, 475, 625, 800, 1000)),
    (('guardiao_ancestral', 'vigia_da_cripta', 'mr_420'), (20000, 30000, 42000, 57000, 75000), (500, 700, 900, 1150, 1450)),
    (('tita_profanado', 'dragao_das_ruinas', 'og_chef'), (30000, 45000, 65000, 90000, 120000), (700, 950, 1250, 1600, 2000)),
    (('soberano_infernal',), (40000, 65000, 100000, 160000, 300000), (900, 1200, 1600, 2050, 2600)),
]


EXTRAS = ('batedor_das_cinzas', 'carrasco_das_cinzas', 'guardiao_das_ruinas', 'devastador_das_ruinas')
BOSSES = ('rei_das_cinzas', 'lorde_do_abismo', 'imperador_infernal')


def marcar(texto):
    texto=texto.replace('<!-- jv-vida-10x -->','')
    return texto.replace('<!-- jv-vida-2x -->','<!-- jv-vida-2x --><!-- jv-vida-10x -->',1)


def balancear(texto, nome, hp, dano, experiencia=None):
    texto, a = re.subn(r'(<monster\s+name=")[^"]+("\s+nameDescription=")[^"]+(")', lambda m:m[1]+nome+m[2]+nome+m[3], texto, count=1)
    texto, b = re.subn(r'<health\s+now="\d+"\s+max="\d+"\s*/>', f'<health now="{hp}" max="{hp}"/>', texto, count=1)
    def ataque(m):
        tipo=m[1]; maximo=dano if tipo=='melee' else max(1,round(dano*0.65))
        return m[0][:m.start(2)-m.start(0)] + str(-maximo//2) + m[0][m.end(2)-m.start(0):m.start(3)-m.start(0)] + str(-maximo) + m[0][m.end(3)-m.start(0):]
    texto, c = re.subn(r'<attack\s+name="(melee|fire)"[^>]*?\bmin="(-?\d+)"[^>]*?\bmax="(-?\d+)"[^>]*>', ataque, texto)
    if experiencia is not None:
        texto, d = re.subn(r'experience="\d+"', f'experience="{experiencia}"', texto, count=1)
    else:d=1
    if (a,b,c,d)!=(1,1,2,1):raise ValueError('XML nao tem o formato esperado: '+nome)
    if 'jv-vida-2x' not in texto:raise ValueError('Marcador de vida ausente: '+nome)
    ET.fromstring(texto)
    return texto


def gerar(data):
    pasta=Path(data)/'monster/Ascensao';alterados=0
    for arquivos, vidas, danos in GRUPOS:
        for arquivo in arquivos:
            base=(pasta/(arquivo+'.xml')).read_text(encoding='utf-8')
            raiz=ET.fromstring(base);nome=raiz.get('name');exp=int(raiz.get('experience'))
            for i in range(4):
                nome_andar=f'{nome} A{i+1}'
                # A vida em GRUPOS e a anterior: variantes sao geradas ja com 10x
                # e marcadas, para nao serem regravadas em toda atualizacao.
                gerado=balancear(base,nome_andar,vidas[i]*10,danos[i],max(1,round(exp*(0.55+0.1*i))))
                gerado=marcar(gerado)
                destino=pasta/(arquivo+f'_andar{i+1}.xml')
                if not destino.exists() or destino.read_text(encoding='utf-8')!=gerado:
                    destino.write_text(gerado,encoding='utf-8');alterados+=1
    # Os dois ultimos andares usam variantes independentes mais resistentes.
    normais=tuple(nome for grupo,_,_ in GRUPOS[:4] for nome in grupo)+EXTRAS
    for arquivos,andares in ((normais,(6,7)),(BOSSES,(7,8))):
        for arquivo in arquivos:
            base=(pasta/(arquivo+'.xml')).read_text(encoding='utf-8')
            raiz=ET.fromstring(base);nome=raiz.get('name');exp=int(raiz.get('experience'))
            hp=int(raiz.find('health').get('max'))
            if '<!-- jv-vida-10x -->' in base:
                if hp%10: raise ValueError('Vida ja aumentada nao divisivel por 10: '+nome)
                hp//=10
            melee=re.search(r'<attack\s+name="melee"[^>]*\bmax="-(\d+)"',base)
            if not melee: raise ValueError('Ataque corporal ausente: '+nome)
            dano=int(melee.group(1))
            for i,andar in enumerate(andares):
                fator_vida=(120,140)[i];fator_ataque=(115,130)[i]
                gerado=balancear(base,f'{nome} A{andar}',hp*10*fator_vida//100,
                                 dano*fator_ataque//100,exp*(110+10*i)//100)
                gerado=marcar(gerado)
                destino=pasta/(arquivo+f'_andar{andar}.xml')
                if not destino.exists() or destino.read_text(encoding='utf-8')!=gerado:
                    destino.write_text(gerado,encoding='utf-8');alterados+=1
    return alterados

if __name__=='__main__':print(gerar(sys.argv[1]))
