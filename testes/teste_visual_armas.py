"""Compila o seletor C++ real e confere a compatibilidade das imagens 8.60."""
from pathlib import Path
import re, subprocess, sys, tempfile, struct
import xml.etree.ElementTree as ET
fonte=Path(sys.argv[1])
item=(fonte/'src/item.cpp').read_text(encoding='latin-1')
metodo=re.search(r'uint16_t Item::getClientID\(\) const\n\{.*?\n\}',item,re.S)
assert metodo, 'funcao de visual ausente'
rows=re.findall(r'\{"(\w+)",\s*(\d+),\s*\{([\d, ]+)\}\}',metodo[0]);assert len(rows)==7
root=ET.fromstring((fonte/'data/items/items.xml').read_text(encoding='latin-1'))
tipos={int(e.get('id')):e for e in root if e.get('id')}
visuais=set()
for chave,base,variantes in rows:
    base=int(base);variantes=[int(x) for x in variantes.split(',')]
    assert len(variantes)==4 and variantes[-1]==base
    def attrs(i):return {a.get('key'):a.get('value') for a in tipos[i].findall('attribute')}
    esperado=attrs(base)
    for vid in variantes:
        assert vid not in visuais, f'imagem repetida: {vid}'
        visuais.add(vid);atual=attrs(vid)
        for atributo in ('weaponType','ammoType','slotType'):
            assert atual.get(atributo)==esperado.get(atributo),(chave,base,vid,atributo)
assert len(visuais)==28
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'servidor-imagem/ferramentas'))
from limpar_mapa import ler_arvore
client_ids={}
for _,props,_ in ler_arvore((fonte/'data/items/items.otb').read_bytes())[2]:
    if len(props)<4:continue
    i=4;sid=cid=None
    while i+3<=len(props):
        attr=props[i];n=struct.unpack_from('<H',props,i+1)[0]
        if attr==0x10 and n==2:sid=struct.unpack_from('<H',props,i+3)[0]
        if attr==0x11 and n==2:cid=struct.unpack_from('<H',props,i+3)[0]
        i+=3+n
    if sid in visuais:client_ids[sid]=cid
assert set(client_ids)==visuais and all(client_ids.values())
assert len(set(client_ids.values()))==28, 'o cliente recebe sprites repetidos'
network=(fonte/'src/networkmessage.cpp').read_text(encoding='latin-1')
assert re.search(r'void NetworkMessage::addItem\(const Item\*.*?add<uint16_t>\(item->getClientID\(\)\)',network,re.S)
game=(fonte/'src/game.cpp').read_text(encoding='latin-1')
assert 'item->getClientID() != spriteId' in game and 'item->getClientID() == spriteId' in game
inicio=game.index('Item* original = findItemOfType(player, it.id, true, subType);')
fim=game.index('\n\t\treturn nullptr;',inicio)+len('\n\t\treturn nullptr;')
busca=game[inicio:fim]
codigo=r'''
#include <cstdint>
#include <cassert>
#include <string>
#include <variant>
#include <set>
namespace boost {template<class T>const T*get(const std::variant<int64_t,std::string>*v){return std::get_if<T>(v);}}
const int ITEM_ATTRIBUTE_CUSTOM=1;
struct Attr {std::variant<int64_t,std::string> value;};
struct Tipo {uint16_t clientId=0;};
struct Item {static Tipo items[10000];uint16_t id;bool marcado=false;Attr attr;
 bool hasAttribute(int)const{return marcado;}
 const Attr* getCustomAttribute(const std::string&){return marcado?&attr:nullptr;}
 uint16_t getClientID()const;
};
Tipo Item::items[10000];
'''+metodo[0]+r'''
int main(){
 for(int i=0;i<10000;i++)Item::items[i].clientId=i;
 struct R{const char* nome;uint16_t base;uint16_t visuais[4];};
 R rows[]={
'''+''.join('{"%s",%s,{%s}},\n'%row for row in rows)+r'''
 };
 std::set<uint16_t> ids;
 for (auto &r:rows){
  Item i;i.id=r.base;assert(i.getClientID()==r.base);i.marcado=true;
  for(int n=1;n<=4;n++){
   i.attr.value=std::string(r.nome)+":"+std::to_string(n);
   assert(i.id==r.base && i.getClientID()==r.visuais[n-1]);
   assert(ids.insert(i.getClientID()).second);
  }
  i.attr.value=std::string(r.nome)+":5";assert(i.getClientID()==r.base);
  i.attr.value=std::string("outra:1");assert(i.getClientID()==r.base);
  i.attr.value=std::string(r.nome)+":1";i.id=100;assert(i.getClientID()==100);
 }
 assert(ids.size()==28);
}
'''
with tempfile.TemporaryDirectory() as tmp:
    cpp=Path(tmp)/'teste.cpp';exe=Path(tmp)/'teste';cpp.write_text(codigo)
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
codigo_busca=r'''
#include <cassert>
#include <vector>
#include <cstdint>
#include <cstddef>
using std::size_t;
const int ITEM_ATTRIBUTE_CUSTOM=1;
struct Item;struct Container;
struct Thing{virtual Item*getItem(){return nullptr;}virtual ~Thing()=default;};
struct Item:Thing{
 int id,client,sub=1;bool custom;Container*contents=nullptr;
 Item(int i,int c,bool t):id(i),client(c),custom(t){}
 Item*getItem()override{return this;}int getID()const{return id;}uint16_t getClientID()const{return static_cast<uint16_t>(client);}
 int getSubType()const{return sub;}bool hasAttribute(int)const{return custom;}
 Container*getContainer(){return contents;}
};
struct Container{
 std::vector<Item*> itens;
 size_t getFirstIndex()const{return 0;}size_t getLastIndex()const{return itens.size();}
 Thing*getThing(size_t n){return itens[n];}std::vector<Item*>&getItemList(){return itens;}
};
using Player=Container;struct Tipo{int id;};
Item*findItemOfType(Player*p,int id,bool,int sub){
 for(auto*i:p->itens)if(i->getID()==id&&(sub==-1||i->getSubType()==sub))return i;
 return nullptr;
}
Item*buscar(Player*player,Tipo it,uint32_t spriteId,int subType){
'''+busca+r'''
}
int main(){
 Item antigo(2400,7383,true),normal(2400,3288,false),outra(7383,7383,false);
 Player p;p.itens={&antigo,&normal};
 assert(buscar(&p,{2400},3288,-1)==&normal);
 assert(buscar(&p,{7383},7383,-1)==&antigo);
 p.itens.push_back(&outra);assert(buscar(&p,{7383},7383,-1)==&outra);
 assert(buscar(&p,{2400},3288,2)==nullptr);
}
'''
with tempfile.TemporaryDirectory() as tmp:
    cpp=Path(tmp)/'busca.cpp';exe=Path(tmp)/'busca';cpp.write_text(codigo_busca)
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
print('OK: 28 imagens diferentes; ID real, familia, municao, slots e busca por hotkey')
