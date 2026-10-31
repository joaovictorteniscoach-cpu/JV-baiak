"""Limpa a sujeira decorativa do chao nas areas protegidas (templos/cidades) de um mapa OTBM.

So remove itens soltos que nao bloqueiam passagem (pedrinhas, ferragens, rachaduras,
poeira, entulho) de tiles com zona de protecao (PZ) que NAO sao de casa. Paredes,
portas, moveis, teleportes, casas, hunts e areas sem PZ ficam como estao.

Uso: python limpar_mapa.py entrada.otbm items.otb items.xml saida.otbm [relatorio.txt]
"""
import collections
import re
import struct
import sys

ESC, INI, FIM = 0xFD, 0xFE, 0xFF


def ler_arvore(dados):
    def no(p):
        p += 1
        tipo = dados[p]; p += 1
        props = bytearray(); filhos = []
        while True:
            b = dados[p]
            if b == ESC:
                props.append(dados[p + 1]); p += 2
            elif b == INI:
                f, p = no(p); filhos.append(f)
            elif b == FIM:
                return [tipo, bytes(props), filhos], p + 1
            else:
                props.append(b); p += 1
    return no(4)[0]


def escrever(no, saida):
    tipo, props, filhos = no
    saida.append(INI); saida.append(tipo)
    for b in props:
        if b in (ESC, INI, FIM):
            saida.append(ESC)
        saida.append(b)
    for f in filhos:
        escrever(f, saida)
    saida.append(FIM)


def faixa(a, b):
    return set(range(a, b + 1))


LIXO_SEMPRE = (faixa(5771, 5774) | {8046, 8047, 2360} | faixa(3607, 3631) | faixa(3648, 3656) | faixa(6374, 6379)
               | faixa(3226, 3241) | faixa(5814, 5851) | faixa(6285, 6299) | faixa(5619, 5624) | faixa(5707, 5709)
               | faixa(5866, 5868) | {5527, 5528, 5905, 5906, 6068} | faixa(9633, 9636))
# areia/grama soltas: so somem quando o chao e piso construido (pedra, marmore...)
LIXO_EM_PISO = (faixa(4596, 4607) | faixa(4760, 4783) | faixa(8033, 8045) | faixa(6216, 6219) | faixa(4526, 4553))
PISO = re.compile(r"stone floor|pavement|ornamented floor|marble floor|tiles?$|wooden floor", re.I)


def main():
    entrada, otb_arq, xml_arq, saida_arq = sys.argv[1:5]
    rel = sys.argv[5] if len(sys.argv) > 5 else None
    sys.setrecursionlimit(100000)
    dados = open(entrada, "rb").read()
    raiz = ler_arvore(dados)
    buf = bytearray(dados[:4]); escrever(raiz, buf)
    assert bytes(buf) == dados, "o leitor/escritor nao reproduz o mapa original"

    otb = ler_arvore(open(otb_arq, "rb").read())
    bloqueia = set()
    for _, props, _ in otb[2]:
        flags = struct.unpack_from("<I", props, 0)[0]; i = 4; sid = None
        while i < len(props):
            a = props[i]; n = struct.unpack_from("<H", props, i + 1)[0]
            if a == 0x10:
                sid = struct.unpack_from("<H", props, i + 3)[0]
            i += 3 + n
        if sid and flags & 1:
            bloqueia.add(sid)
    nomes = {}
    for m in re.finditer(r'<item (?:id="(\d+)"|fromid="(\d+)" toid="(\d+)")[^>]*name="([^"]*)"',
                         open(xml_arq, encoding="latin-1").read()):
        if m.group(1):
            nomes[int(m.group(1))] = m.group(4)
        else:
            for i in range(int(m.group(2)), int(m.group(3)) + 1):
                nomes[i] = m.group(4)

    sempre = LIXO_SEMPRE - bloqueia
    em_piso = LIXO_EM_PISO - bloqueia
    removidos = collections.Counter(); tiles_limpos = 0
    QUEBRADO = faixa(3226, 3241)
    PISO_ESCURO = faixa(10765, 10774)
    pisos_trocados = 0
    for area in raiz[2][0][2]:
        if area[0] != 4:
            continue
        bx, by, _ = struct.unpack_from("<HHB", area[1], 0)
        for t in area[2]:
            if t[0] != 5:  # tile de casa (14) nunca e mexido
                continue
            props = t[1][2:]
            flags = struct.unpack_from("<I", props, 1)[0] if props and props[0] == 3 else 0
            if not flags & 1:  # so zona de protecao
                continue
            chao = None
            i = 0
            while i < len(props):
                if props[i] == 3:
                    i += 5
                elif props[i] == 9:
                    chao = struct.unpack_from("<H", props, i + 1)[0]; i += 3
                else:
                    break
            filhos = t[2]
            if chao is None and filhos and filhos[0][0] == 6:
                chao = struct.unpack_from("<H", filhos[0][1], 0)[0]
            piso = bool(chao and PISO.search(nomes.get(chao, "")))
            novos = []
            tirou_quebrado = False
            for f in filhos:
                if f[0] == 6 and not f[2]:
                    iid = struct.unpack_from("<H", f[1], 0)[0]
                    if iid != chao and (iid in sempre or (piso and iid in em_piso)):
                        removidos[iid] += 1
                        tirou_quebrado |= iid in QUEBRADO
                        continue
                novos.append(f)
            if len(novos) != len(filhos):
                tiles_limpos += 1
                t[2] = novos
            if tirou_quebrado and chao in PISO_ESCURO:
                # sem o piso quebrado por cima, o chao escuro de baixo fica como um buraco:
                # troca pelo piso de pedra comum do templo (variando o desenho)
                x, y = bx + t[1][0], by + t[1][1]
                novo = 3152 + (x + 2 * y) % 4
                pr = bytearray(t[1]); i = 2
                while i < len(pr):
                    if pr[i] == 3:
                        i += 5
                    elif pr[i] == 9:
                        struct.pack_into("<H", pr, i + 1, novo); pisos_trocados += 1; break
                    else:
                        break
                else:
                    if novos and novos[0][0] == 6 and struct.unpack_from("<H", novos[0][1], 0)[0] == chao:
                        f0 = bytearray(novos[0][1]); struct.pack_into("<H", f0, 0, novo); novos[0][1] = bytes(f0)
                        pisos_trocados += 1
                t[1] = bytes(pr)
    buf = bytearray(dados[:4]); escrever(raiz, buf)
    open(saida_arq, "wb").write(bytes(buf))
    linhas = ["tiles limpos: %d, itens removidos: %d, pisos escuros trocados: %d" % (
        tiles_limpos, sum(removidos.values()), pisos_trocados)]
    linhas += ["  %5d x %s (%d)" % (q, nomes.get(i, "?"), i) for i, q in removidos.most_common()]
    print("\n".join(linhas[:25]))
    if rel:
        open(rel, "w").write("\n".join(linhas) + "\n")


if __name__ == "__main__":
    main()
