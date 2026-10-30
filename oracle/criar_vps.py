#!/usr/bin/env python3
"""JV Baiak - robo que tenta criar a VPS gratis (Ampere A1) na Oracle ate conseguir.

Roda no GitHub Actions a cada 10 minutos. Precisa do segredo OCI_JVBAIAK
(base64 de um JSON com a chave de API da Oracle e o script de instalacao).
O andamento aparece numa issue do repositorio; quando a maquina e criada,
o robo comenta na issue (o dono recebe e-mail) e se desliga sozinho.
Nada secreto e impresso no log.
"""
from __future__ import annotations

import base64
import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.request

NOME_VPS = "jvbaiak"
SUBNET_PREFERIDA = "public subnet-jvbaiak"
SHAPE = "VM.Standard.A1.Flex"
FORMATOS = [(2, 12), (1, 6)]  # (OCPUs, GB) - dentro do Always Free
PORTAS = [(80, 80), (443, 443), (7171, 7172)]
DISCO_GB = 50
TITULO_ISSUE = "Robô da Oracle: criação da VPS"
WORKFLOW = "criar-vps-oracle.yml"
MARCA_PRONTO = "<!-- jvbaiak:pronto -->"
ESTADOS_VIVOS = {"PROVISIONING", "STARTING", "RUNNING", "STOPPING", "STOPPED", "CREATING_IMAGE", "MOVING"}


def agora() -> str:
    br = datetime.timezone(datetime.timedelta(hours=-3))
    return datetime.datetime.now(br).strftime("%d/%m %H:%M")


# --------------------------------------------------------------------- GitHub
class GitHub:
    def __init__(self, token: str | None, repo: str | None, abrir=urllib.request.urlopen):
        self.token, self.repo, self._abrir = token, repo, abrir
        self._numero = None

    @property
    def ativo(self) -> bool:
        return bool(self.token and self.repo)

    def _req(self, metodo, caminho, corpo=None):
        req = urllib.request.Request(
            f"https://api.github.com/repos/{self.repo}{caminho}", method=metodo,
            data=json.dumps(corpo).encode() if corpo is not None else None,
            headers={"Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json",
                     "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "jvbaiak-robo"})
        with self._abrir(req, timeout=20) as r:
            dados = r.read()
            return json.loads(dados) if dados else None

    def issue(self) -> dict:
        if not self.ativo:
            return {"number": 0, "body": ""}
        if self._numero is None:
            for item in self._req("GET", "/issues?state=all&per_page=100") or []:
                if item.get("title") == TITULO_ISSUE and "pull_request" not in item:
                    self._numero = item["number"]
                    return item
            criada = self._req("POST", "/issues", {"title": TITULO_ISSUE, "body": "Iniciando..."})
            self._numero = criada["number"]
            return criada
        return self._req("GET", f"/issues/{self._numero}")

    def status(self, texto: str):
        if not self.ativo:
            print(texto)
            return
        self.issue()
        self._req("PATCH", f"/issues/{self._numero}", {"body": texto})

    def comentar(self, texto: str):
        if self.ativo:
            self.issue()
            self._req("POST", f"/issues/{self._numero}/comments", {"body": texto})

    def desligar_robo(self):
        if self.ativo:
            try:
                self._req("PUT", f"/actions/workflows/{WORKFLOW}/disable")
            except urllib.error.HTTPError as e:  # sem permissao: o robo so continua checando
                print(f"aviso: nao consegui desligar o workflow ({e.code})")


def texto_tentando(detalhe: str) -> str:
    return (f"**Status: procurando vaga** ({agora()}: {detalhe})\n\n"
            "O robô tenta criar a máquina grátis na Oracle a cada 10 minutos, dia e noite. "
            "Não precisa fazer nada: quando conseguir, este aviso muda e você recebe um e-mail.")


# -------------------------------------------------------------------- segredo
def carregar_segredo(bruto: str | None) -> dict | None:
    if not bruto:
        return None
    dados = json.loads(base64.b64decode(bruto.strip()).decode())
    faltando = [k for k in ("user", "fingerprint", "tenancy", "region", "key_pem", "user_data") if not dados.get(k)]
    if faltando:
        raise ValueError("segredo incompleto: falta " + ", ".join(faltando))
    return dados


# ----------------------------------------------------------------------- Oracle
def instancia_existente(compute, compartimento):
    for inst in compute.list_instances(compartimento).data:
        if inst.shape == SHAPE and inst.lifecycle_state in ESTADOS_VIVOS:
            return inst
    return None


def ip_publico(compute, rede, compartimento, instancia_id):
    for anexo in compute.list_vnic_attachments(compartimento, instance_id=instancia_id).data:
        if anexo.lifecycle_state == "ATTACHED":
            ip = rede.get_vnic(anexo.vnic_id).data.public_ip
            if ip:
                return ip
    return None


def escolher_subnet(rede, compartimento):
    subnets = [s for s in rede.list_subnets(compartimento).data if s.lifecycle_state == "AVAILABLE"]
    publicas = [s for s in subnets if not s.prohibit_public_ip_on_vnic]
    for s in publicas:
        if s.display_name == SUBNET_PREFERIDA:
            return s
    return publicas[0] if publicas else None


def abrir_portas(oci, rede, subnet) -> list[str]:
    """Garante TCP 80, 443 e 7171-7172 liberados (0.0.0.0/0) na security list da subnet."""
    if not subnet.security_list_ids:
        return []
    lista = rede.get_security_list(subnet.security_list_ids[0]).data
    regras = list(lista.ingress_security_rules or [])

    def coberta(lo, hi):
        for r in regras:
            if r.protocol in ("6", "all") and r.source == "0.0.0.0/0":
                if r.protocol == "all" or not r.tcp_options or not r.tcp_options.destination_port_range:
                    return True
                faixa = r.tcp_options.destination_port_range
                if faixa.min <= lo and faixa.max >= hi:
                    return True
        return False

    m = oci.core.models
    novas = []
    for lo, hi in PORTAS:
        if not coberta(lo, hi):
            novas.append(m.IngressSecurityRule(
                protocol="6", source="0.0.0.0/0", source_type="CIDR_BLOCK", is_stateless=False,
                description="JV Baiak", tcp_options=m.TcpOptions(destination_port_range=m.PortRange(min=lo, max=hi))))
    if novas:
        rede.update_security_list(lista.id, m.UpdateSecurityListDetails(ingress_security_rules=regras + novas))
    return [_faixa(r.tcp_options.destination_port_range) for r in novas]


def _faixa(f) -> str:
    return str(f.min) if f.min == f.max else f"{f.min}-{f.max}"


def imagem_ubuntu(compute, compartimento):
    imagens = compute.list_images(compartimento, operating_system="Canonical Ubuntu", operating_system_version="24.04",
                                  shape=SHAPE, sort_by="TIMECREATED", sort_order="DESC").data
    if not imagens:
        imagens = compute.list_images(compartimento, operating_system="Canonical Ubuntu", operating_system_version="22.04",
                                      shape=SHAPE, sort_by="TIMECREATED", sort_order="DESC").data
    return imagens[0] if imagens else None


def sem_capacidade(erro) -> bool:
    msg = (getattr(erro, "message", "") or "").lower()
    return "capacity" in msg or getattr(erro, "code", "") == "OutOfHostCapacity"


def anunciar_pronto(gh, ip, formato):
    atual = gh.issue().get("body") or ""
    texto = (f"{MARCA_PRONTO}\n**Status: VPS criada!** ({agora()})\n\n"
             f"- Máquina: {formato}\n- IP público: `{ip or 'aguardando'}`\n\n"
             "A instalação do servidor já começou sozinha. Em uns 40 minutos o site abre no seu domínio "
             "do DuckDNS. O robô se desligou.")
    gh.status(texto)
    if MARCA_PRONTO not in atual:
        gh.comentar(f"Consegui a máquina grátis na Oracle! IP público: `{ip or 'aguardando'}`. "
                    "A instalação está rodando sozinha; em uns 40 minutos o site abre.")
    gh.desligar_robo()


def tentar(oci, cfg, compute, rede, identidade, gh) -> int:
    comp = cfg["tenancy"]

    existente = instancia_existente(compute, comp)
    if existente:
        ip = ip_publico(compute, rede, comp, existente.id)
        anunciar_pronto(gh, ip, f"{existente.display_name} ({existente.lifecycle_state})")
        return 0

    subnet = escolher_subnet(rede, comp)
    if not subnet:
        gh.status(f"**Status: erro** ({agora()})\n\nNão achei uma sub-rede pública. Crie a rede pelo "
                  "*Start VCN Wizard → Create VCN with Internet Connectivity* com o nome `jvbaiak`.")
        return 1
    abertas = abrir_portas(oci, rede, subnet)
    if abertas:
        print("portas liberadas:", ", ".join(abertas))

    imagem = imagem_ubuntu(compute, comp)
    if not imagem:
        gh.status(f"**Status: erro** ({agora()})\n\nNão achei a imagem Ubuntu para ARM nesta região.")
        return 1

    m = oci.core.models
    ads = [ad.name for ad in identidade.list_availability_domains(comp).data]
    motivo = "sem vaga na Oracle"
    for ocpus, gb in FORMATOS:
        for ad in ads:
            detalhes = m.LaunchInstanceDetails(
                availability_domain=ad, compartment_id=comp, display_name=NOME_VPS, shape=SHAPE,
                shape_config=m.LaunchInstanceShapeConfigDetails(ocpus=float(ocpus), memory_in_gbs=float(gb)),
                source_details=m.InstanceSourceViaImageDetails(image_id=imagem.id, boot_volume_size_in_gbs=DISCO_GB),
                create_vnic_details=m.CreateVnicDetails(subnet_id=subnet.id, assign_public_ip=True),
                metadata={"user_data": base64.b64encode(cfg["user_data"].encode()).decode(),
                          **({"ssh_authorized_keys": cfg["ssh_pub"]} if cfg.get("ssh_pub") else {})},
                instance_options=m.InstanceOptions(are_legacy_imds_endpoints_disabled=True))
            try:
                inst = compute.launch_instance(detalhes).data
            except oci.exceptions.ServiceError as e:
                if e.status == 429:
                    gh.status(texto_tentando("Oracle pediu para esperar; tento de novo daqui a pouco"))
                    return 0
                if sem_capacidade(e):
                    print(f"sem capacidade: {ocpus} OCPU/{gb} GB em {ad}")
                    continue
                if e.code == "LimitExceeded":
                    motivo = "limite grátis ocupado (existe outra máquina?)"
                    print(f"limite: {ocpus} OCPU/{gb} GB")
                    continue
                gh.status(f"**Status: erro** ({agora()})\n\nA Oracle respondeu: `{e.status} {e.code}` "
                          f"{(e.message or '')[:300]}")
                return 1
            print(f"criada: {ocpus} OCPU/{gb} GB")
            try:
                oci.wait_until(compute, compute.get_instance(inst.id), "lifecycle_state", "RUNNING", max_wait_seconds=420)
            except Exception as e:  # nao conseguiu esperar: anuncia mesmo assim
                print(f"aviso: {type(e).__name__} esperando a maquina ligar")
            anunciar_pronto(gh, ip_publico(compute, rede, comp, inst.id), f"{ocpus} núcleo(s), {gb} GB")
            return 0

    gh.status(texto_tentando(motivo))
    return 0


def main() -> int:
    gh = GitHub(os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN"), os.environ.get("GITHUB_REPOSITORY"))
    try:
        cfg = carregar_segredo(os.environ.get("OCI_JVBAIAK"))
    except Exception as e:
        gh.status(f"**Status: erro** ({agora()})\n\nO segredo `OCI_JVBAIAK` está com formato inválido ({type(e).__name__}). "
                  "Cole de novo o texto completo que o Claude enviou.")
        return 1
    if cfg is None:
        print("Segredo OCI_JVBAIAK ainda nao configurado: nada a fazer.")
        return 0

    import oci  # instalado pelo workflow

    config = {"user": cfg["user"], "fingerprint": cfg["fingerprint"], "tenancy": cfg["tenancy"],
              "region": cfg["region"], "key_content": cfg["key_pem"]}
    oci.config.validate_config(config)
    compute = oci.core.ComputeClient(config)
    rede = oci.core.VirtualNetworkClient(config)
    identidade = oci.identity.IdentityClient(config)
    try:
        return tentar(oci, cfg, compute, rede, identidade, gh)
    except oci.exceptions.ServiceError as e:
        if e.status in (401, 404) and e.code in ("NotAuthenticated", "NotAuthorizedOrNotFound"):
            gh.status(f"**Status: erro** ({agora()})\n\nA Oracle não aceitou a chave de API ({e.code}). "
                      "Confira se a chave pública foi adicionada em *My profile → API keys*.")
            return 1
        raise


if __name__ == "__main__":
    inicio = time.time()
    codigo = main()
    print(f"fim em {time.time() - inicio:.0f}s (codigo {codigo})")
    sys.exit(codigo)
