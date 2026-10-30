"""Testes do robo da Oracle com uma imitacao do SDK (sem rede)."""
import base64
import json
import os
import sys
import types
import unittest

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "oracle"))
import criar_vps as robo  # noqa: E402


# ------------------------------------------------------------ imitacao do oci
class ServiceError(Exception):
    def __init__(self, status, code, message):
        super().__init__(message)
        self.status, self.code, self.message = status, code, message


class Modelo:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def fake_oci():
    m = types.SimpleNamespace(**{n: type(n, (Modelo,), {}) for n in (
        "LaunchInstanceDetails", "LaunchInstanceShapeConfigDetails", "InstanceSourceViaImageDetails",
        "CreateVnicDetails", "InstanceOptions", "IngressSecurityRule", "TcpOptions", "PortRange",
        "UpdateSecurityListDetails")})
    oci = types.SimpleNamespace(core=types.SimpleNamespace(models=m),
                                exceptions=types.SimpleNamespace(ServiceError=ServiceError))
    oci.esperas = []
    oci.wait_until = lambda *a, **k: oci.esperas.append(k)
    return oci


def resp(data):
    return types.SimpleNamespace(data=data)


class Compute:
    def __init__(self, existentes=(), falhas=()):
        self.existentes = list(existentes)
        self.falhas = list(falhas)  # um item por tentativa: ServiceError ou None (= sucesso)
        self.lancadas = []

    def list_instances(self, comp):
        return resp(self.existentes)

    def list_images(self, comp, **kw):
        return resp([Modelo(id="img-2404")] if kw["operating_system_version"] == "24.04" else [])

    def launch_instance(self, det):
        self.lancadas.append(det)
        erro = self.falhas.pop(0) if self.falhas else None
        if erro:
            raise erro
        inst = Modelo(id="inst-1", display_name=det.display_name, shape=det.shape, lifecycle_state="PROVISIONING")
        self.existentes.append(inst)
        return resp(inst)

    def get_instance(self, iid):
        return resp(Modelo(id=iid))

    def list_vnic_attachments(self, comp, instance_id):
        return resp([Modelo(lifecycle_state="ATTACHED", vnic_id="vnic-1")])


class Rede:
    def __init__(self, regras=None, subnets=None):
        self.lista = Modelo(id="sl-1", ingress_security_rules=regras or [])
        self.subnets = subnets if subnets is not None else [
            Modelo(id="sub-priv", display_name="private subnet-jvbaiak", lifecycle_state="AVAILABLE",
                   prohibit_public_ip_on_vnic=True, security_list_ids=["sl-2"]),
            Modelo(id="sub-pub", display_name="public subnet-jvbaiak", lifecycle_state="AVAILABLE",
                   prohibit_public_ip_on_vnic=False, security_list_ids=["sl-1"])]
        self.atualizacoes = []

    def list_subnets(self, comp):
        return resp(self.subnets)

    def get_security_list(self, sid):
        return resp(self.lista)

    def update_security_list(self, sid, det):
        self.atualizacoes.append(det)
        self.lista.ingress_security_rules = det.ingress_security_rules

    def get_vnic(self, vid):
        return resp(Modelo(public_ip="129.151.1.2"))


class Identidade:
    def list_availability_domains(self, comp):
        return resp([Modelo(name="xyz:SA-SAOPAULO-1-AD-1")])


class GH:
    def __init__(self, corpo=""):
        self.corpo, self.comentarios, self.desligado = corpo, [], False

    def issue(self):
        return {"number": 1, "body": self.corpo}

    def status(self, t):
        self.corpo = t

    def comentar(self, t):
        self.comentarios.append(t)

    def desligar_robo(self):
        self.desligado = True


CFG = {"tenancy": "ocid1.tenancy.oc1..x", "user_data": "#!/bin/bash\necho oi\n", "ssh_pub": "ssh-rsa AAA"}
SEM_VAGA = ServiceError(500, "InternalError", "Out of host capacity.")


class TesteRobo(unittest.TestCase):
    def rodar(self, compute, rede=None, gh=None):
        self.oci, self.rede, self.gh = fake_oci(), rede or Rede(), gh or GH()
        return robo.tentar(self.oci, CFG, compute, self.rede, Identidade(), self.gh)

    def test_sem_vaga_tenta_dois_tamanhos_e_continua(self):
        c = Compute(falhas=[SEM_VAGA, SEM_VAGA])
        self.assertEqual(self.rodar(c), robo.ESPERAR)
        self.assertEqual([(d.shape_config.ocpus, d.shape_config.memory_in_gbs) for d in c.lancadas], [(2.0, 12.0), (1.0, 6.0)])
        self.assertIn("procurando vaga", self.gh.corpo)
        self.assertFalse(self.gh.desligado)
        self.assertEqual(self.gh.comentarios, [])

    def test_consegue_no_segundo_tamanho_e_desliga(self):
        c = Compute(falhas=[SEM_VAGA, None])
        self.assertEqual(self.rodar(c), robo.PRONTO)
        d = c.lancadas[-1]
        self.assertEqual((d.shape, d.display_name, d.create_vnic_details.subnet_id), ("VM.Standard.A1.Flex", "jvbaiak", "sub-pub"))
        self.assertTrue(d.create_vnic_details.assign_public_ip)
        self.assertEqual(d.source_details.image_id, "img-2404")
        self.assertEqual(base64.b64decode(d.metadata["user_data"]).decode(), CFG["user_data"])
        self.assertEqual(d.metadata["ssh_authorized_keys"], "ssh-rsa AAA")
        self.assertIn("129.151.1.2", self.gh.corpo)
        self.assertIn(robo.MARCA_PRONTO, self.gh.corpo)
        self.assertEqual(len(self.gh.comentarios), 1)
        self.assertTrue(self.gh.desligado)
        self.assertEqual(self.oci.esperas[0]["max_wait_seconds"], 420)

    def test_maquina_ja_existe_nao_cria_outra(self):
        viva = Modelo(id="inst-9", display_name="instance-20261030-1622", shape="VM.Standard.A1.Flex", lifecycle_state="RUNNING")
        c = Compute(existentes=[viva])
        self.assertEqual(self.rodar(c), robo.PRONTO)
        self.assertEqual(c.lancadas, [])
        self.assertTrue(self.gh.desligado)
        self.assertIn("instance-20261030-1622", self.gh.corpo)
        # segunda passada nao comenta de novo
        self.rodar(c, gh=self.gh)
        self.assertEqual(len(self.gh.comentarios), 1)

    def test_terminada_nao_conta(self):
        morta = Modelo(id="i", display_name="x", shape="VM.Standard.A1.Flex", lifecycle_state="TERMINATED")
        c = Compute(existentes=[morta], falhas=[SEM_VAGA, SEM_VAGA])
        self.rodar(c)
        self.assertEqual(len(c.lancadas), 2)

    def test_abre_portas_que_faltam_sem_duplicar(self):
        m = fake_oci().core.models
        ssh = m.IngressSecurityRule(protocol="6", source="0.0.0.0/0", tcp_options=m.TcpOptions(destination_port_range=m.PortRange(min=22, max=22)))
        web = m.IngressSecurityRule(protocol="6", source="0.0.0.0/0", tcp_options=m.TcpOptions(destination_port_range=m.PortRange(min=80, max=80)))
        rede = Rede(regras=[ssh, web])
        self.rodar(Compute(falhas=[SEM_VAGA, SEM_VAGA]), rede=rede)
        faixas = [(r.tcp_options.destination_port_range.min, r.tcp_options.destination_port_range.max)
                  for r in rede.lista.ingress_security_rules]
        self.assertEqual(faixas, [(22, 22), (80, 80), (443, 443), (7171, 7172)])
        self.rodar(Compute(falhas=[SEM_VAGA, SEM_VAGA]), rede=rede)
        self.assertEqual(len(rede.atualizacoes), 1)

    def test_sem_subnet_publica(self):
        rede = Rede(subnets=[])
        self.assertEqual(self.rodar(Compute(), rede=rede), robo.ERRO)
        self.assertIn("sub-rede pública", self.gh.corpo)

    def test_limite_e_erro_desconhecido(self):
        lim = ServiceError(400, "LimitExceeded", "limit")
        self.assertEqual(self.rodar(Compute(falhas=[lim, lim])), robo.ESPERAR)
        self.assertIn("limite grátis", self.gh.corpo)
        outro = ServiceError(400, "InvalidParameter", "segredo=nao-vaza " + "x" * 500)
        self.assertEqual(self.rodar(Compute(falhas=[outro])), robo.ERRO)
        self.assertIn("InvalidParameter", self.gh.corpo)
        self.assertLess(len(self.gh.corpo), 500)

    def test_muitas_requisicoes_para(self):
        c = Compute(falhas=[ServiceError(429, "TooManyRequests", "slow down")])
        self.assertEqual(self.rodar(c), robo.ESPERAR)
        self.assertEqual(len(c.lancadas), 1)


class TesteUserData(unittest.TestCase):
    TEXTO = ("#!/bin/bash\nexport NOME_SERVIDOR=\"JV Baiak\"\nexport DOMINIO=\"x.duckdns.org\"\n"
             "export DUCKDNS_TOKEN=\"abc\"\nbash /root/instalar.sh\n")

    def test_sem_dominio_tira_so_as_duas_linhas(self):
        out = robo.preparar_user_data(self.TEXTO, True)
        self.assertNotIn("DOMINIO=", out)
        self.assertNotIn("DUCKDNS_TOKEN", out)
        self.assertIn('export NOME_SERVIDOR="JV Baiak"', out)
        self.assertTrue(out.endswith("bash /root/instalar.sh\n"))
        self.assertEqual(robo.preparar_user_data(self.TEXTO, False), self.TEXTO)

    def test_launch_usa_variavel(self):
        os.environ["SEM_DOMINIO"] = "1"
        try:
            c = Compute(falhas=[None])
            robo.tentar(fake_oci(), dict(CFG, user_data=self.TEXTO), c, Rede(), Identidade(), GH())
            enviado = base64.b64decode(c.lancadas[0].metadata["user_data"]).decode()
            self.assertNotIn("duckdns", enviado)
        finally:
            os.environ.pop("SEM_DOMINIO")


class Relogio:
    def __init__(self):
        self.t = 0.0
        self.sonos = []

    def agora(self):
        return self.t

    def dormir(self, s):
        self.sonos.append(s)
        self.t += s


class TesteRepetir(unittest.TestCase):
    def setUp(self):
        import tempfile
        fd, self.saida = tempfile.mkstemp()
        os.close(fd)
        os.environ["GITHUB_OUTPUT"] = self.saida

    def tearDown(self):
        os.environ.pop("GITHUB_OUTPUT", None)
        os.remove(self.saida)

    def repetir(self, compute, duracao=600, intervalo=120, gh=None):
        self.rel, self.gh = Relogio(), gh or GH()
        return robo.repetir(fake_oci(), CFG, compute, Rede(), Identidade(), self.gh, duracao_s=duracao,
                            intervalo_s=intervalo, dormir=self.rel.dormir, relogio=self.rel.agora)

    def saida_txt(self):
        return open(self.saida).read()

    def test_tenta_ate_acabar_o_tempo_e_pede_proxima(self):
        c = Compute(falhas=[SEM_VAGA] * 100)
        self.assertEqual(self.repetir(c, duracao=600, intervalo=120), 0)
        self.assertEqual(len(c.lancadas), 2 * 6)  # 6 rodadas (0,120,...,600), 2 tamanhos cada
        self.assertEqual(self.rel.sonos, [120] * 5)
        self.assertIn("continuar=1", self.saida_txt())

    def test_para_quando_consegue_sem_pedir_proxima(self):
        c = Compute(falhas=[SEM_VAGA, SEM_VAGA, SEM_VAGA, None])
        self.assertEqual(self.repetir(c), 0)
        self.assertTrue(self.gh.desligado)
        self.assertEqual(self.saida_txt(), "")

    def test_erro_de_chave_para_tudo(self):
        class Quebrado(Compute):
            def list_instances(self, comp):
                raise ServiceError(401, "NotAuthenticated", "no")
        self.assertEqual(self.repetir(Quebrado()), 1)
        self.assertIn("não aceitou a chave", self.gh.corpo)
        self.assertEqual(self.saida_txt(), "")

    def test_falha_temporaria_nao_derruba(self):
        class Instavel(Compute):
            vezes = 0

            def list_instances(self, comp):
                Instavel.vezes += 1
                if Instavel.vezes == 1:
                    raise ConnectionError("rede")
                if Instavel.vezes == 2:
                    raise ServiceError(503, "ServiceUnavailable", "x")
                return resp(self.existentes)
        c = Instavel(falhas=[SEM_VAGA] * 10)
        self.assertEqual(self.repetir(c, duracao=240, intervalo=120), 0)
        self.assertEqual(Instavel.vezes, 3)
        self.assertIn("continuar=1", self.saida_txt())

    def test_execucao_unica(self):
        c = Compute(falhas=[SEM_VAGA, SEM_VAGA])
        self.assertEqual(self.repetir(c, duracao=0), 0)
        self.assertEqual(self.rel.sonos, [])


class TesteSegredo(unittest.TestCase):
    def test_formatos(self):
        self.assertIsNone(robo.carregar_segredo(""))
        bom = {"user": "u", "fingerprint": "f", "tenancy": "t", "region": "sa-saopaulo-1", "key_pem": "k", "user_data": "s"}
        self.assertEqual(robo.carregar_segredo(base64.b64encode(json.dumps(bom).encode()).decode() + "\n"), bom)
        with self.assertRaises(ValueError):
            robo.carregar_segredo(base64.b64encode(json.dumps({"user": "u"}).encode()).decode())

    def test_main_sem_segredo_nao_faz_nada(self):
        os.environ.pop("OCI_JVBAIAK", None)
        os.environ.pop("GITHUB_TOKEN", None)
        os.environ.pop("GH_TOKEN", None)
        self.assertEqual(robo.main(), 0)


class TesteGitHub(unittest.TestCase):
    def test_cria_issue_uma_vez_e_atualiza(self):
        chamadas = []

        class R:
            def __init__(self, dados):
                self.dados = dados

            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

            def read(self):
                return json.dumps(self.dados).encode()

        def abrir(req, timeout):
            chamadas.append((req.get_method(), req.full_url.split("/repos/x/y")[1]))
            if req.get_method() == "GET":
                return R([{"number": 7, "title": "outra"}])
            return R({"number": 9})

        gh = robo.GitHub("tok", "x/y", abrir=abrir)
        gh.status("a")
        gh.status("b")
        gh.comentar("c")
        gh.desligar_robo()
        self.assertEqual(chamadas, [("GET", "/issues?state=all&per_page=100"), ("POST", "/issues"),
                                    ("PATCH", "/issues/9"), ("GET", "/issues/9"), ("PATCH", "/issues/9"),
                                    ("GET", "/issues/9"), ("POST", "/issues/9/comments"),
                                    ("PUT", "/actions/workflows/criar-vps-oracle.yml/disable")])


if __name__ == "__main__":
    unittest.main(verbosity=1)
