"""Cliente minimo do protocolo Tibia 8.60 (o mesmo caminho dos clientes de PC e Android).

Faz o que um jogador faz: login (porta 7171) -> lista de personagens -> entra no
mundo (porta 7172) -> anda -> fala -> (se for GM) testa comandos de administrador
-> sai. Mede o tempo de cada etapa. Sem dependencias alem do Python 3.

Uso: python protocolo_860.py <host> <conta> <senha> [--gm] [--saida resultado.json]
"""
import json
import os
import socket
import struct
import sys
import time
import zlib

# Chave publica RSA padrao do OTServ (a mesma do key.pem do Baiak Thunder e dos clientes)
RSA_N = int(
    "109120132967399429278860960508995541528237502902798129123468757937266291492576446330739696001110603907230888610072655818825358503429057592827629436413108566029093628212635953836686562675849720620786279431090218017681061521755056710823876476444260558147179707119674283982419152118103759076030616683978566631413")
RSA_E = 65537
VERSAO = 860
OS_WINDOWS = 2


def adler32(dados):
    return zlib.adler32(dados) & 0xFFFFFFFF


def xtea_cifra(dados, chave):
    delta, saida = 0x9E3779B9, bytearray()
    for i in range(0, len(dados), 8):
        v0, v1 = struct.unpack_from("<2I", dados, i)
        soma = 0
        for _ in range(32):
            v0 = (v0 + ((((v1 << 4) ^ (v1 >> 5)) + v1) ^ (soma + chave[soma & 3]))) & 0xFFFFFFFF
            soma = (soma + delta) & 0xFFFFFFFF
            v1 = (v1 + ((((v0 << 4) ^ (v0 >> 5)) + v0) ^ (soma + chave[(soma >> 11) & 3]))) & 0xFFFFFFFF
        saida += struct.pack("<2I", v0, v1)
    return bytes(saida)


def xtea_decifra(dados, chave):
    delta, saida = 0x9E3779B9, bytearray()
    for i in range(0, len(dados), 8):
        v0, v1 = struct.unpack_from("<2I", dados, i)
        soma = (delta * 32) & 0xFFFFFFFF
        for _ in range(32):
            v1 = (v1 - ((((v0 << 4) ^ (v0 >> 5)) + v0) ^ (soma + chave[(soma >> 11) & 3]))) & 0xFFFFFFFF
            soma = (soma - delta) & 0xFFFFFFFF
            v0 = (v0 - ((((v1 << 4) ^ (v1 >> 5)) + v1) ^ (soma + chave[soma & 3]))) & 0xFFFFFFFF
        saida += struct.pack("<2I", v0, v1)
    return bytes(saida)


def texto(s):
    b = s.encode("latin-1")
    return struct.pack("<H", len(b)) + b


def rsa(bloco):
    assert len(bloco) == 128 and bloco[0] == 0
    return pow(int.from_bytes(bloco, "big"), RSA_E, RSA_N).to_bytes(128, "big")


class Conexao:
    def __init__(self, host, porta, chave):
        self.s = socket.create_connection((host, porta), timeout=20)
        self.chave = chave
        self.cifrado = False

    def ler_quadro(self, limite=20):
        self.s.settimeout(limite)
        cab = self._ler(2)
        (tam,) = struct.unpack("<H", cab)
        return self._ler(tam)

    def _ler(self, n):
        b = b""
        while len(b) < n:
            parte = self.s.recv(n - len(b))
            if not parte:
                raise ConnectionError("o servidor fechou a conexao")
            b += parte
        return b

    def ler_mensagem(self, limite=20):
        """Le um quadro decifrado: devolve os bytes das mensagens (comecam pelo opcode)."""
        q = self.ler_quadro(limite)
        (soma,) = struct.unpack_from("<I", q, 0)
        corpo = q[4:]
        if not self.cifrado:
            return corpo
        claro = xtea_decifra(corpo, self.chave)
        (tam,) = struct.unpack_from("<H", claro, 0)
        dados = claro[2:2 + tam]
        if soma == 0 and dados:  # pacote comprimido (deflate cru)
            try:
                dados = zlib.decompress(dados, -15)
            except zlib.error:
                pass
        return dados

    def enviar_claro(self, corpo):
        self.s.sendall(struct.pack("<HI", len(corpo) + 4, adler32(corpo)) + corpo)

    def enviar(self, dados):
        claro = struct.pack("<H", len(dados)) + dados
        claro += b"\x00" * ((8 - len(claro) % 8) % 8)
        cif = xtea_cifra(claro, self.chave)
        self.s.sendall(struct.pack("<HI", len(cif) + 4, adler32(cif)) + cif)

    def fechar(self):
        try:
            self.s.close()
        except OSError:
            pass


def nova_chave():
    return list(struct.unpack("<4I", os.urandom(16)))


def login(host, conta, senha, porta=7171):
    chave = nova_chave()
    c = Conexao(host, porta, chave)
    bloco = b"\x00" + struct.pack("<4I", *chave) + texto(conta) + texto(senha)
    bloco += os.urandom(128 - len(bloco))
    bloco = b"\x00" + bloco[1:]
    corpo = b"\x01" + struct.pack("<HH", OS_WINDOWS, VERSAO) + b"\x00" * 12 + rsa(bloco)
    c.enviar_claro(corpo)
    c.cifrado = True
    dados = c.ler_mensagem()
    c.fechar()
    i, motd, personagens, erro = 0, None, [], None
    while i < len(dados):
        op = dados[i]; i += 1
        if op in (0x0A, 0x0B):  # erro
            (n,) = struct.unpack_from("<H", dados, i)
            erro = dados[i + 2:i + 2 + n].decode("latin-1"); break
        if op == 0x14:
            (n,) = struct.unpack_from("<H", dados, i)
            motd = dados[i + 2:i + 2 + n].decode("latin-1"); i += 2 + n
        elif op == 0x64:
            qtd = dados[i]; i += 1
            for _ in range(qtd):
                (n,) = struct.unpack_from("<H", dados, i); nome = dados[i + 2:i + 2 + n].decode("latin-1"); i += 2 + n
                (n,) = struct.unpack_from("<H", dados, i); mundo = dados[i + 2:i + 2 + n].decode("latin-1"); i += 2 + n
                ip, porta_jogo = struct.unpack_from("<IH", dados, i); i += 6
                personagens.append({"nome": nome, "mundo": mundo, "ip": socket.inet_ntoa(struct.pack("<I", ip)),
                                    "porta": porta_jogo})
            i += 2  # dias de premium
        else:
            break
    return {"motd": motd, "personagens": personagens, "erro": erro}


class Jogo:
    def __init__(self, host, porta, conta, senha, personagem, gm=False):
        self.chave = nova_chave()
        self.c = Conexao(host, porta, self.chave)
        desafio = self.c.ler_mensagem()  # [tam 2][0x1F][timestamp 4][aleatorio 1]
        if desafio[2] != 0x1F:
            raise RuntimeError("o servidor nao mandou o desafio de entrada")
        ts, aleat = struct.unpack_from("<IB", desafio, 3)
        bloco = (b"\x00" + struct.pack("<4I", *self.chave) + bytes([1 if gm else 0]) + texto(conta)
                 + texto(personagem) + texto(senha) + struct.pack("<IB", ts, aleat))
        bloco += b"\x00" * (128 - len(bloco))
        self.c.enviar_claro(b"\x0A" + struct.pack("<HH", OS_WINDOWS, VERSAO) + rsa(bloco))
        self.c.cifrado = True
        self.recebidos = []

    def receber(self, segundos):
        """Junta tudo que chegar por alguns segundos (e responde ao ping)."""
        fim, pacotes = time.time() + segundos, []
        while time.time() < fim:
            try:
                d = self.c.ler_mensagem(limite=max(0.1, fim - time.time()))
            except socket.timeout:
                break
            if d and d[0] == 0x1E:
                self.c.enviar(b"\x1E")
            pacotes.append((time.time(), d))
        self.recebidos += pacotes
        return pacotes

    def esperar(self, condicao, segundos):
        fim = time.time() + segundos
        while time.time() < fim:
            for t, d in self.receber(min(1.0, fim - time.time())):
                if condicao(d):
                    return t, d
        return None, None

    def falar(self, frase):
        self.c.enviar(b"\x96\x01" + texto(frase))

    def andar(self, direcao):  # 0x65 norte, 0x66 leste, 0x67 sul, 0x68 oeste
        self.c.enviar(bytes([direcao]))

    def sair(self):
        try:
            self.c.enviar(b"\x14")
            time.sleep(1)
        finally:
            self.c.fechar()


def erro_de(d):
    if d and d[0] == 0x14 and len(d) > 3:
        (n,) = struct.unpack_from("<H", d, 1)
        return d[3:3 + n].decode("latin-1", "replace")
    return None


def testar(host, conta, senha, gm=False, clonar=True):
    r = {"host": host, "etapas": [], "ok": True}

    def etapa(nome, ok, **info):
        r["etapas"].append({"etapa": nome, "ok": bool(ok), **info})
        if not ok:
            r["ok"] = False
        print(("OK   " if ok else "FALHA"), nome, json.dumps(info, ensure_ascii=False), flush=True)

    t = time.time()
    try:
        lg = login(host, conta, senha)
    except Exception as e:  # noqa: BLE001
        etapa("login 7171", False, erro=repr(e))
        return r
    ms = int((time.time() - t) * 1000)
    etapa("login 7171", not lg["erro"] and lg["personagens"], ms=ms, erro=lg["erro"],
          personagens=[p["nome"] for p in lg["personagens"]])
    if not lg["personagens"]:
        return r
    p = lg["personagens"][0]
    etapa("lista aponta para o servidor certo", p["porta"] == 7172, ip=p["ip"], porta=p["porta"], mundo=p["mundo"])
    destino = host  # o IP da lista pode ser o publico; o teste usa o mesmo host do login
    t = time.time()
    try:
        jg = Jogo(destino, p["porta"], conta, senha, p["nome"], gm=gm)
        tt, d = jg.esperar(lambda d: d and d[0] in (0x0A, 0x14, 0x16), 30)
    except Exception as e:  # noqa: BLE001
        etapa("entrar no mundo 7172", False, erro=repr(e))
        return r
    entrou = d is not None and d[0] == 0x0A
    etapa("entrar no mundo 7172", entrou, ms=int(((tt or time.time()) - t) * 1000), erro=erro_de(d),
          primeiro_opcode=hex(d[0]) if d else None)
    if not entrou:
        return r
    jg.receber(3)
    mapa = sum(len(x) for _, x in jg.recebidos)
    etapa("recebeu o mapa", mapa > 2000, bytes=mapa)

    # andar: tenta as 4 direcoes ate uma andar (0x6D = criatura andou)
    andou, tempos = False, []
    for direcao in (0x66, 0x68, 0x67, 0x65, 0x66, 0x68):
        t = time.time()
        jg.andar(direcao)
        tt, d = jg.esperar(lambda d: d and d[0] in (0x6D, 0xB5), 3)
        if d and d[0] == 0x6D:
            andou = True
            tempos.append(int((tt - t) * 1000))
            time.sleep(0.4)
    etapa("andar (resposta do servidor)", andou, passos=len(tempos), ms_por_passo=tempos)

    t = time.time()
    jg.falar("oi, teste do robo")
    tt, d = jg.esperar(lambda d: d and d[0] == 0xAA, 5)
    etapa("falar no chat", d is not None, ms=int(((tt or time.time()) - t) * 1000) if d else None)

    if gm:
        jg.falar("/comandos")
        tt, d = jg.esperar(lambda d: d and d[0] == 0x96, 5)
        etapa("admin: /comandos abre a lista", d is not None and b"Comandos de administrador" in d)
        antes = len(jg.recebidos)
        jg.falar("/i 2160, 1")  # cria 1 crystal coin
        jg.receber(3)
        novos = [x for _, x in jg.recebidos[antes:] if x]
        criou = any(op in x for x in novos for op in (b"\x78", b"\x70", b"\x83")) and not any(
            b"There is no item" in x for x in novos)
        etapa("admin: /i cria item", criou, pacotes=len(novos))
        jg.falar("/i 2400")  # magic sword (vai para a mao se estiver livre)
        jg.receber(2)
        antes = len(jg.recebidos)
        jg.falar("/clonar 2" if clonar else "oi")
        jg.receber(3)
        txt = b"".join(x for _, x in jg.recebidos[antes:])
        pos = txt.find(b"Clonado")
        etapa("admin: /clonar copia o item da mao", pos >= 0,
              resposta=txt[pos:pos + 40].decode("latin-1", "replace") if pos >= 0 else None,
              pediu_item_na_mao=b"Segure" in txt)
        antes = len(jg.recebidos)
        jg.falar("/a 1")
        jg.receber(2)
        moveu = any(x and x[0] in (0x6C, 0x6D, 0x64, 0x65, 0x66, 0x67, 0x68) for _, x in jg.recebidos[antes:])
        etapa("admin: /a teletransporta", moveu)
        jg.falar("/t")
        jg.receber(2)

    jg.receber(2)
    jg.sair()
    etapa("sair do jogo", True)
    return r


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    saida = None
    if "--saida" in sys.argv:
        saida = sys.argv[sys.argv.index("--saida") + 1]
        args.remove(saida)
    res = testar(args[0], args[1], args[2], gm="--gm" in sys.argv, clonar="--sem-clonar" not in sys.argv)
    if saida:
        with open(saida, "w") as f:
            json.dump(res, f, ensure_ascii=False, indent=1)
    sys.exit(0 if res["ok"] else 1)
