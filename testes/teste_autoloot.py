"""Executa o configurador real contra storages isolados por personagem."""
import json
import unittest
from pathlib import Path
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
class Autoloot(unittest.TestCase):
 def setUp(self):
  self.lua=LuaRuntime(unpack_returned_tuples=True)
  self.lua.execute('''
AUTOLOOT_STORAGE_START=100;AUTOLOOT_STORAGE_END=102;AUTO_LOOT_MAX_ITEMS=3;AUTOLOOT_STORAGE_GOLD=200
MESSAGE_STATUS_CONSOLE_BLUE=1
function TalkAction()return {separator=function()end,register=function()end}end
function CreatureEvent()return {register=function()end}end
names={[2148]='gold coin',[2152]='platinum coin',[2160]='crystal coin',[2376]='sword',[999]='item "especial"\\nlinha'}
function ItemType(ref)
 local id=tonumber(ref)
 if not id then for k,v in pairs(names)do if ref==v then id=k end end end
 id=names[id] and id or 0
 return {getId=function()return id end,getName=function()return names[id]end}
end
function player()
 local p={values={},packets={}}
 function p:getStorageValue(k)return self.values[k] or -1 end
 function p:setStorageValue(k,v)self.values[k]=v end
 function p:sendExtendedOpcode(op,data)assert(op==204);table.insert(self.packets,data)end
 function p:sendTextMessage(_,text)self.error=text end
 return p
end
p=player();other=player()
''')
  self.lua.execute((ROOT/'servidor-imagem/extras/data/scripts/custom/jv_autoloot_ui.lua').read_text())
 def call(self,param):
  self.lua.globals().JVAutolootUI.configurar(self.lua.globals().p,param)
  packets=self.lua.globals().p.packets
  return json.loads(packets[len(packets)])
 def storage(self,key):return self.lua.globals().p.getStorageValue(self.lua.globals().p,key)
 def test_persistent_selection_and_independent_players(self):
  self.call('take sword');self.assertEqual(self.storage(100),2376)
  self.assertEqual(self.lua.globals().other.getStorageValue(self.lua.globals().other,100),-1)
  self.assertTrue(next(i for i in self.call('list')['items'] if i['id']==2376)['collect'])
  self.call('ignore 2376');self.assertEqual(self.storage(100),0)
  self.assertFalse(next(i for i in self.call('find sword')['items'] if i['id']==2376)['collect'])
 def test_hole_does_not_duplicate_existing_item(self):
  self.lua.execute('p.values[101]=2376')
  self.call('take 2376');self.assertEqual(self.storage(100),-1);self.assertEqual(self.storage(101),2376)
 def test_full_and_unknown_items_do_not_overwrite(self):
  self.lua.execute('p.values[100]=2148;p.values[101]=2152;p.values[102]=2160')
  self.assertIn('cheia',self.call('take sword')['message']);self.assertEqual(self.storage(102),2160)
  for param in ['take','ignore','take xyz','ignore 0','take 1e300','take -2','take 2.2','invalid','x'*101]:self.call(param)
  self.assertEqual(self.storage(100),2148)
 def test_ignoring_coin_overrides_legacy_bank_mode(self):
  self.lua.execute('p.values[200]=1;p.values[101]=2152')
  data=self.call('list');self.assertTrue(next(i for i in data['items'] if i['id']==2148)['collect'])
  data=self.call('ignore 2148');self.assertFalse(data['goldBank']);self.assertEqual(self.storage(101),2152)
  self.assertFalse(next(i for i in data['items'] if i['id']==2148)['collect'])
 def test_wire_escapes_item_names(self):
  self.call('take 999');data=self.call('list')
  self.assertEqual(next(i for i in data['items'] if i['id']==999)['name'],'item "especial"\nlinha')
 def test_find_does_not_select_item(self):
  data=self.call('find sword');self.assertFalse(next(i for i in data['items'] if i['id']==2376)['collect']);self.assertEqual(self.storage(100),-1)
if __name__=='__main__':unittest.main()
