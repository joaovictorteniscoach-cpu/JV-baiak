"""Dados reais, itens/outfits da versao fixada, registro idempotente e XML."""
from pathlib import Path
import importlib.util
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "servidor-imagem/ferramentas"))
FONTE = Path(sys.argv.pop(1)) if len(sys.argv)>1 else Path('/tmp/servidor-progressao')
spec = importlib.util.spec_from_file_location('registrar', ROOT/'servidor-imagem/ferramentas/registrar_ascensao.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
andares_spec=importlib.util.spec_from_file_location('andares',ROOT/'servidor-imagem/ferramentas/gerar_andares_ascensao.py')
andares=importlib.util.module_from_spec(andares_spec);andares_spec.loader.exec_module(andares)


class DadosAscensao(unittest.TestCase):
    def test_registro_loot_multiplo_idempotente_e_seguro(self):
        spec2=importlib.util.spec_from_file_location('loot8',ROOT/'servidor-imagem/ferramentas/registrar_loot_multiplo.py')
        loot8=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(loot8)
        with tempfile.TemporaryDirectory() as tmp:
            pasta=Path(tmp)
            for arquivo,trocas in loot8.MUDANCAS.items():
                p=pasta/arquivo;p.parent.mkdir(parents=True,exist_ok=True)
                p.write_bytes(b'\n'.join(a for a,_ in trocas)+b'\n')
            self.assertEqual(loot8.registrar(pasta),2)
            antes={str(p):p.read_bytes() for p in pasta.rglob('*.lua')}
            self.assertEqual(loot8.registrar(pasta),0)
            self.assertEqual(antes,{str(p):p.read_bytes() for p in pasta.rglob('*.lua')})
            p=pasta/'events/scripts/monster.lua';p.write_bytes(b'script customizado')
            with self.assertRaises(ValueError):loot8.registrar(pasta)
            self.assertEqual(p.read_bytes(),b'script customizado')

    def test_reducao_vida_uma_vez_e_preserva_restante(self):
        import reduzir_vida_monstros as r
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'animal.xml'
            p.write_text('<monster name="Sheep"><health now="90" max="180"/><loot/></monster>')
            self.assertEqual(r.atualizar(tmp),1)
            self.assertIn('now="50" max="100"',p.read_text())
            antes=p.read_bytes()
            self.assertEqual(r.atualizar(tmp),0)
            self.assertEqual(p.read_bytes(),antes)
            self.assertEqual(r.reduzir(1),1)

    def test_corrigir_quests_preserva_personalizacoes(self):
        import corrigir_quests as c, shutil
        with tempfile.TemporaryDirectory() as tmp:
            destino=Path(tmp)/'actions/scripts/quests';destino.mkdir(parents=True)
            for nome in c.ORIGINAIS:
                shutil.copyfile(FONTE/'data/actions/scripts/quests'/nome,destino/nome)
            self.assertEqual(c.aplicar(tmp),3)
            self.assertEqual(c.aplicar(tmp),0)
            shutil.copyfile(ROOT/'testes/fixtures/medusa_versao_anterior.lua',destino/'medusaAnihi.lua')
            self.assertEqual(c.aplicar(tmp),1, 'nao atualizou a versao anterior da Medusa')
            self.assertEqual(c.aplicar(tmp),0)
            p=destino/'quests.lua';p.write_text('customizado')
            with self.assertRaises(ValueError): c.aplicar(tmp)
            self.assertEqual(p.read_text(),'customizado')

    def test_vida_10x_existente_nova_idempotente_e_limite(self):
        spec2=importlib.util.spec_from_file_location('vida',ROOT/'servidor-imagem/ferramentas/vida_monstros.py')
        vida=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(vida)
        with tempfile.TemporaryDirectory() as tmp:
            pasta=Path(tmp)
            antigo=pasta/'animal.xml';antigo.write_bytes(b'<monster name="Sheep"><health now="20" max="30"/><!-- jv-vida-2x --><loot/></monster>')
            livre=pasta/'custom.xml';livre.write_bytes(b"<monster><health max='9' now='7'/><attacks/></monster>")
            self.assertEqual(vida.atualizar(pasta),2)
            self.assertEqual((ET.parse(antigo).getroot().find('health').get('max')), '300')
            self.assertEqual((ET.parse(livre).getroot().find('health').get('now')), '70')
            antes={p:p.read_bytes() for p in pasta.iterdir()}
            self.assertEqual(vida.atualizar(pasta),0)
            self.assertEqual(antes,{p:p.read_bytes() for p in pasta.iterdir()})
            novo=pasta/'novo.xml';novo.write_bytes(b'<monster><health now="5" max="5"/></monster>')
            self.assertEqual(vida.atualizar(pasta,instalacao_nova=True),1)
            self.assertEqual(ET.parse(novo).getroot().find('health').get('max'),'100')
            transacao=pasta/'a.xml';transacao.write_bytes(b'<monster><health now="1" max="1"/></monster>')
            overflow=pasta/'z.xml';overflow.write_bytes(b'<monster><health now="214748365" max="214748365"/></monster>')
            antes=transacao.read_bytes()
            with self.assertRaises(ValueError):vida.atualizar(pasta)
            self.assertEqual(transacao.read_bytes(),antes)

    def test_respawn_bosses_idempotente_e_sem_alterar_comuns(self):
        spec2=importlib.util.spec_from_file_location('bosses',ROOT/'servidor-imagem/ferramentas/acelerar_bosses.py')
        bosses=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(bosses)
        with tempfile.TemporaryDirectory() as tmp:
            data=Path(tmp);(data/'monster/Bosses').mkdir(parents=True);(data/'monster/Outros').mkdir()
            (data/'monster/monsters.xml').write_text('<monsters><monster name="Ferumbras" file="Bosses/f.xml"/><monster name="Chef Especial" file="Outros/b.xml"/><monster name="Rat" file="Outros/r.xml"/></monsters>')
            (data/'monster/Bosses/f.xml').write_text('<monster/>')
            (data/'monster/Outros/b.xml').write_text('<monster><flags><flag isboss="1"/></flags></monster>')
            (data/'monster/Outros/r.xml').write_text('<monster/>')
            sp=data/'spawn.xml';sp.write_text('<spawns><spawn><monster name="Ferumbras" spawntime="30"/><monster name="Chef Especial" spawntime="45"/><monster name="Juggernaut" spawntime="60"/><monster name="Rat" spawntime="30"/><npc name="Ferumbras" spawntime="60"/></spawn></spawns>')
            self.assertEqual(bosses.aplicar(data,[sp]),3)
            once=sp.read_bytes();self.assertEqual(bosses.aplicar(data,[sp]),0);self.assertEqual(sp.read_bytes(),once)
            tree=ET.fromstring(once);items=list(tree.find('spawn'))
            self.assertEqual([e.get('spawntime') for e in items],['15','23','30','30','60'])

    def test_registro_drops_classicos_sem_substituir_loot(self):
        caminho=ROOT/'servidor-imagem/ferramentas/registrar_drops_classicos.py'
        spec2=importlib.util.spec_from_file_location('classicos',caminho)
        reg=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(reg)
        with tempfile.TemporaryDirectory() as tmp:
            destino=Path(tmp)/'monster/Demons';destino.mkdir(parents=True)
            # Inclui um XML com evento preexistente para proteger outros sistemas.
            (destino/'demon.xml').write_text('<monster name="Demon"><script><event name="Outro"/></script><loot><item id="1"/></loot></monster>')
            (destino/'juggernaut.xml').write_text('<monster name="Juggernaut"><loot><item id="2"/></loot></monster>')
            self.assertEqual(reg.registrar(tmp),2)
            antes=[p.read_bytes() for p in sorted(destino.glob('*.xml'))]
            self.assertEqual(reg.registrar(tmp),0)
            self.assertEqual(antes,[p.read_bytes() for p in sorted(destino.glob('*.xml'))])
            demon=ET.parse(destino/'demon.xml').getroot()
            self.assertEqual({e.get('name') for e in demon.findall('./script/event')},{'Outro','JVArsenalClassico'})
            self.assertEqual(demon.find('./loot/item').get('id'),'1')

    def test_registro_idempotente_e_conflito(self):
        import shutil
        with tempfile.TemporaryDirectory() as tmp:
            data = Path(tmp)
            shutil.copytree(ROOT/'servidor-imagem/extras/data/monster/Ascensao',data/'monster/Ascensao')
            self.assertEqual(andares.gerar(data),90)
            self.assertEqual(andares.gerar(data),0)
            for arquivos,vidas,danos in andares.GRUPOS:
                for arquivo in arquivos:
                    for i in range(4):
                        raiz=ET.parse(data/'monster/Ascensao'/f'{arquivo}_andar{i+1}.xml').getroot()
                        self.assertEqual(int(raiz.find('health').get('max')),andares.reduzir(vidas[i]*10))
                        self.assertIn('<!-- jv-vida-10x -->',(data/'monster/Ascensao'/f'{arquivo}_andar{i+1}.xml').read_text())
                        self.assertEqual(int(raiz.find('./attacks/attack').get('max')),-danos[i])
                        self.assertEqual(raiz.find('./script/event').get('name'),'JVAscensaoMorte')
                    raiz=ET.parse(data/'monster/Ascensao'/f'{arquivo}.xml').getroot()
                    self.assertEqual(int(raiz.find('health').get('max')),vidas[4])
                    self.assertEqual(int(raiz.find('./attacks/attack').get('max')),-danos[4])
            for nomes,faixas in [(tuple(n for g,_,_ in andares.GRUPOS[:4] for n in g)+andares.EXTRAS,(6,7)),(andares.BOSSES,(7,8))]:
                for nome in nomes:
                    base=ET.parse(data/'monster/Ascensao'/f'{nome}.xml').getroot()
                    anterior=andares.reduzir(int(base.find('health').get('max'))*10)
                    for n in faixas:
                        monstro=ET.parse(data/'monster/Ascensao'/f'{nome}_andar{n}.xml').getroot()
                        vida_atual=int(monstro.find('health').get('max'))
                        self.assertGreater(vida_atual,anterior)
                        self.assertTrue(monstro.get('name').endswith(f' A{n}'))
                        anterior=vida_atual
            spec_vida=importlib.util.spec_from_file_location('vida_instalacao',ROOT/'servidor-imagem/ferramentas/vida_monstros.py')
            vida=importlib.util.module_from_spec(spec_vida);spec_vida.loader.exec_module(vida)
            import reduzir_vida_monstros as reducao
            vida.atualizar(data/'monster')
            reducao.atualizar(data/'monster')
            self.assertEqual(andares.gerar(data),0, 'regerou os andares ja aumentados')
            arquivos={p.name:p.read_bytes() for p in (data/'monster/Ascensao').glob('*.xml')}
            shutil.copytree(ROOT/'servidor-imagem/extras/data/monster/Ascensao',data/'monster/Ascensao',dirs_exist_ok=True)
            self.assertEqual(andares.gerar(data),0)
            vida.atualizar(data/'monster')
            reducao.atualizar(data/'monster')
            self.assertEqual(arquivos,{p.name:p.read_bytes() for p in (data/'monster/Ascensao').glob('*.xml')},'segunda atualizacao alterou a vida')
            xml = data/'monster/monsters.xml'
            original = '<monsters><monster name="Demon" file="Demons/demon.xml"/></monsters>'
            xml.write_text(original)
            self.assertEqual(mod.registrar(data),122)
            primeira = xml.read_bytes()
            self.assertEqual(mod.registrar(data),0)
            self.assertEqual(xml.read_bytes(),primeira)
            self.assertIn(b'name="Demon" file="Demons/demon.xml"',primeira)
            texto=xml.read_text().replace('Ascensao/demonio_ascendido.xml','Demons/demon.xml')
            xml.write_text(texto)
            with self.assertRaises(ValueError):mod.registrar(data)
            self.assertEqual(xml.read_text(),texto)

    def test_monstros_novos_loot_util_e_bosses_mais_fortes(self):
        pasta=ROOT/'servidor-imagem/extras/data/monster/Ascensao'
        dados={p.stem:ET.parse(p).getroot() for p in pasta.glob('*.xml')}
        faciles=['batedor_das_cinzas','guardiao_das_ruinas']
        fortes=['carrasco_das_cinzas','devastador_das_ruinas']
        for facil,forte in zip(faciles,fortes):
            self.assertLess(int(dados[facil].find('health').get('max')),int(dados[forte].find('health').get('max')))
        soberano=int(dados['soberano_infernal'].find('health').get('max'))
        for nome in ['rei_das_cinzas','lorde_do_abismo','imperador_infernal']:
            self.assertGreater(int(dados[nome].find('health').get('max')),soberano)
        for nome in faciles+fortes+['rei_das_cinzas','lorde_do_abismo','imperador_infernal']:
            raiz=dados[nome]
            self.assertEqual(raiz.find('./script/event').get('name'),'JVAscensaoMorte')
            loot={int(e.get('id')) for e in raiz.findall('./loot/item')}
            self.assertTrue(loot <= {2152,2160,2493,2494,2472,2522})
            self.assertIn(2160,loot)
            self.assertTrue(loot & {2493,2494,2472,2522})

    def test_itens_outfits_e_hunts(self):
        lua = LuaRuntime()
        p = lua.execute((ROOT/'servidor-imagem/extras/data/lib/jv_progressao.lua').read_text())
        elites=list((ROOT/'servidor-imagem/extras/data/monster/Ascensao').glob('elite_*.xml'))
        self.assertEqual(len(elites),8)
        nomes={ET.parse(f).getroot().get('name') for f in elites}
        for f in elites:
            r=ET.parse(f).getroot()
            self.assertGreater(int(r.find('health').get('max')),0)
            self.assertIn('<!-- jv-vida-2x -->',f.read_text())
        self.assertEqual(len(p['entradasReforcadas']),10)
        for entrada in p['entradasReforcadas'].values():self.assertIn(entrada['monstro'],nomes)
        raiz=ET.fromstring((FONTE/'data/items/items.xml').read_bytes().decode('latin-1'))
        ids={}
        for i in raiz:
            a=int(i.get('id') or i.get('fromid'))
            b=int(i.get('id') or i.get('toid'))
            for j in range(a,b+1):ids[j]=i
        for i in p['itens'].values():self.assertIn(i,ids)
        arsenal=lua.execute((ROOT/'servidor-imagem/extras/data/lib/jv_arsenal.lua').read_text())
        tipos=['sword','axe','club','distance','distance','wand','wand']
        for f,tipo in zip(arsenal['familias'].values(),tipos):
            self.assertIn(f['item'],ids)
            attrs={a.get('key'):a.get('value') for a in ids[f['item']].findall('attribute')}
            self.assertEqual(attrs['weaponType'],tipo)
            self.assertGreater(f['ataque'][4],f['ataque'][1])
        self.assertEqual(len(arsenal['familias']),7)
        self.assertTrue(set(range(arsenal['fragmentosStorage'],arsenal['fragmentosStorage']+4)).isdisjoint({p['storage'],p['storageAbates']}))
        for i in [407,1050,1387,5995]:self.assertIn(i,ids)
        outfits={int(i.get('looktype')) for i in ET.parse(FONTE/'data/XML/outfits.xml').getroot()}
        for c in p['classes'].values():
            for o in c['outfits'].values():self.assertIn(o,outfits)
        arquivos={ET.parse(f).getroot().get('name'):f for f in (ROOT/'servidor-imagem/extras/data/monster/Ascensao').glob('*.xml')}
        for h in p['hunts'].values():
            f=arquivos[h['monstro']];r=ET.parse(f).getroot()
            self.assertGreater(int(r.find('health').get('max')),16400)
            self.assertIn('jv-vida-2x',f.read_text())
            self.assertLessEqual(h['chance'],0.15)
            self.assertEqual(r.find('script/event').get('name'),'JVAscensaoMorte')
            if h['convidado']:
                convidado=ET.parse(arquivos[h['convidado']]).getroot()
                self.assertEqual(convidado.find('health').get('max'),r.find('health').get('max'))
                self.assertEqual(convidado.find('script/event').get('name'),'JVAscensaoMorte')
        hunts=list(p['hunts'].values())
        self.assertEqual(len(hunts),9)
        self.assertEqual(sum(bool(h['dupla']) for h in hunts),4)
        for i in range(4):
            self.assertEqual(hunts[i+5]['arsenalBase'],i+1)
            self.assertEqual(hunts[i+5]['monstro'],hunts[i]['monstro'])
            self.assertEqual(hunts[i+5]['tier'],hunts[i]['tier'])
        self.assertEqual(hunts[4]['respawn'],150)
        for i,a in enumerate(hunts):
            for b in hunts[i+1:]:
                self.assertGreater(abs(a['x']-b['x']),a['raio']+b['raio'])


if __name__ == '__main__':unittest.main()
