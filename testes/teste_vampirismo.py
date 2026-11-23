"""Cadastro idempotente, magia Lua e trecho real do motor de vampirismo."""
from pathlib import Path
import importlib.util
import subprocess
import tempfile
import unittest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('vampirismo', ROOT/'servidor-imagem/ferramentas/registrar_vampirismo.py')
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

class Vampirismo(unittest.TestCase):
    def test_registro_preserva_catalogo(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'spells/spells.xml';p.parent.mkdir()
            p.write_text('<spells><instant name="Outra" words="outra"/></spells>')
            self.assertEqual(mod.registrar(temp), 1)
            antes=p.read_bytes();self.assertEqual(mod.registrar(temp), 0);self.assertEqual(p.read_bytes(), antes)
            self.assertIn(b'name="Outra"',antes)
            p.write_text('<spells><instant name="Outra" spellid="250"/></spells>')
            with self.assertRaises(ValueError):mod.registrar(temp)

    def test_magia_ativa_a_condicao_correta(self):
        lua=LuaRuntime();lua.execute('''
          CONDITION_ATTRIBUTES=1; CONDITION_PARAM_SUBID=2; CONDITION_PARAM_TICKS=3
          CONDITION_PARAM_BUFF_SPELL=4; CONST_ME_MAGIC_RED=5
          function Condition() return {params={},setParameter=function(s,k,v)s.params[k]=v end} end
          p={addCondition=function(s,c)s.condition=c end,getPosition=function()return {sendMagicEffect=function()end} end}
        ''')
        lua.execute((ROOT/'servidor-imagem/extras/data/spells/scripts/support/jv_vampirismo.lua').read_text())
        self.assertTrue(lua.globals().onCastSpell(lua.globals().p,None))
        c=lua.globals().p.condition.params
        self.assertEqual(c[2],8420);self.assertEqual(c[3],20000)

    def test_regras_do_motor(self):
        diff=(ROOT/'servidor-imagem/patches/0008-magia-vampirismo.patch').read_text()
        lines=[x[1:] for x in diff.splitlines() if x.startswith('+') and not x.startswith('+++')]
        source='\n'.join(lines)
        source=source[source.index('Monster* vampTarget'):]
        source=source[:source.rindex('\n\t\t}')+4]
        cpp='''#include <algorithm>\n#include <cstdint>\n#include <cassert>\nconstexpr int CONDITION_ATTRIBUTES=1,CONDITIONID_COMBAT=0;\nstruct Monster {bool summon=false; void* getMaster(){return summon ? this : nullptr;}};\nstruct Target {Monster* m; Monster* getMonster(){return m;}};\nstruct Player {int hp=500,maxhp=1000; bool active=true; int getHealth(){return hp;} int getMaxHealth(){return maxhp;} bool getCondition(int,int,int id){return active && id==8420;} void gainHealth(Player*,int n){hp=std::min(maxhp,hp+n);}};\nvoid aplicar(Player* attackerPlayer,Target* target,int32_t realDamage){\n'''+source+'''\n}\nint main(){Player p;Monster m;Target t{&m};aplicar(&p,&t,300);assert(p.hp==530);aplicar(&p,&t,5000);assert(p.hp==630);p.active=false;aplicar(&p,&t,500);assert(p.hp==630);p.active=true;m.summon=true;aplicar(&p,&t,500);assert(p.hp==630);m.summon=false;t.m=nullptr;aplicar(&p,&t,500);assert(p.hp==630);}\n'''
        with tempfile.TemporaryDirectory() as temp:
            f=Path(temp)/'teste.cpp';f.write_text(cpp)
            subprocess.run(['g++','-std=c++17',str(f),'-o',str(Path(temp)/'teste')],check=True)
            subprocess.run([str(Path(temp)/'teste')],check=True)

if __name__=='__main__':unittest.main()
