"""Comprova UIDs e actions nos tiles do mapa original; nao modifica o mapa."""
from pathlib import Path
import struct,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'servidor-imagem/ferramentas'))
from limpar_mapa import ler_arvore
mapa=Path(sys.argv[1]);raiz=ler_arvore(mapa.read_bytes())
esperados={
 (1145,186,7):(1740,5,5058),(1147,186,7):(1740,5,5059),(1149,186,7):(1740,5,5060),
 (1152,188,7):(1740,5,9978),(1154,188,7):(1740,5,5957),(1156,188,7):(1740,5,5956),
 (1160,188,7):(1740,5,5955),(1165,188,7):(1740,5,5954),(1167,188,7):(1740,5,5953),
 (1101,1375,7):(1740,4,13100),
 (1055,199,3):(1748,4,46572),(1055,201,3):(1748,4,46573),
 (1203,972,10):(2843,4,46571),
 (947,1427,8):(1740,4,34589),(949,1427,8):(1740,4,34590),
 (951,1427,8):(1740,4,34591),(953,1427,8):(1740,4,34592),
}
encontrados={}
for area in raiz[2][0][2]:
    if area[0]!=4:continue
    bx,by,z=struct.unpack_from('<HHB',area[1],0)
    for tile in area[2]:
        if tile[0] not in (5,14):continue
        pos=(bx+tile[1][0],by+tile[1][1],z)
        if pos not in esperados:continue
        for item in tile[2]:
            if item[0]!=6 or len(item[1])<5:continue
            valores=(struct.unpack_from('<H',item[1],0)[0],item[1][2],struct.unpack_from('<H',item[1],3)[0])
            if valores==esperados[pos]:encontrados[pos]=valores
assert encontrados==esperados, f'Baús diferentes ou ausentes: {set(esperados)-set(encontrados)}'
print(f'OK: {len(encontrados)} pontos de quest conferidos no OTBM original')
