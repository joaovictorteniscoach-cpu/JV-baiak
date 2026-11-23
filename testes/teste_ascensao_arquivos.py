"""Dados reais, itens/outfits da versao fixada, registro idempotente e XML."""
from pathlib import Path
import importlib.util
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
FONTE = Path(sys.argv.pop(1)) if len(sys.argv)>1 else Path('/tmp/servidor-progressao')
spec = importlib.util.spec_from_file_location('registrar', ROOT/'servidor-imagem/ferramentas/registrar_ascensao.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class DadosAscensao(unittest.TestCase):
    def test_registro_idempotente_e_conflito(self):
        import shutil
        with tempfile.TemporaryDirectory() as tmp:
            data = Path(tmp)
            shutil.copytree(ROOT/'servidor-imagem/extras/data/monster/Ascensao',data/'monster/Ascensao')
            xml = data/'monster/monsters.xml'
            original = '<monsters><monster name="Demon" file="Demons/demon.xml"/></monsters>'
            xml.write_text(original)
            self.assertEqual(mod.registrar(data),5)
            primeira = xml.read_bytes()
            self.assertEqual(mod.registrar(data),0)
            self.assertEqual(xml.read_bytes(),primeira)
            self.assertIn(b'name="Demon" file="Demons/demon.xml"',primeira)
            texto=xml.read_text().replace('Ascensao/demonio_ascendido.xml','Demons/demon.xml')
            xml.write_text(texto)
            with self.assertRaises(ValueError):mod.registrar(data)
            self.assertEqual(xml.read_text(),texto)

    def test_itens_outfits_e_hunts(self):
        lua = LuaRuntime()
        p = lua.execute((ROOT/'servidor-imagem/extras/data/lib/jv_progressao.lua').read_text())
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
        hunts=list(p['hunts'].values())
        self.assertEqual(sum(bool(h['dupla']) for h in hunts),2)
        for i,a in enumerate(hunts):
            for b in hunts[i+1:]:
                self.assertGreater(abs(a['x']-b['x']),a['raio']+b['raio'])


if __name__ == '__main__':unittest.main()
