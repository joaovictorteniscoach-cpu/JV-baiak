"""Compila a comparacao real de itens aplicada pelos patches no motor."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
src=(Path(sys.argv[1])/'src/item.cpp').read_text()
metodo=re.search(r'bool Item::equals\(const Item\* otherItem\) const\n\{.*?\n\}',src,re.S)[0]
inicio=r'''
#include <cassert>
#include <cstdint>
#include <forward_list>
#include <memory>
#include <string>
#include <unordered_map>
#include <variant>
constexpr int ITEM_ATTRIBUTE_CUSTOM=1, ITEM_ATTRIBUTE_TEXT=2;
struct ItemAttributes {
 struct CustomAttribute { std::variant<int,std::string> value; };
 using Map=std::unordered_map<std::string,CustomAttribute>;
 struct Attribute { int type; union Value {int64_t integer; std::string* string; Map* custom; Value():integer(0){} } value; };
 std::forward_list<Attribute> attributes; uint32_t attributeBits=0;
 static bool isStrAttrType(int type){return type==ITEM_ATTRIBUTE_TEXT;}
};
struct Item {int id=100;std::unique_ptr<ItemAttributes> attributes;bool equals(const Item*)const;};
Item loot(int count) { Item a; a.attributes.reset(new ItemAttributes); a.attributes->attributeBits=1;
 ItemAttributes::Attribute attr;attr.type=ITEM_ATTRIBUTE_CUSTOM;attr.value.custom=new ItemAttributes::Map;
 (*attr.value.custom)["jvlootcoletado"].value=count;a.attributes->attributes.push_front(attr);return a; }
'''
testes=r'''
int main(){
 Item comprado, vazio; vazio.attributes.reset(new ItemAttributes);
 assert(comprado.equals(&vazio) && vazio.equals(&comprado));
 Item a=loot(1),b=loot(1),c=loot(2);
 assert(a.equals(&b) && b.equals(&a));
 assert(!a.equals(&c) && !a.equals(&comprado) && !comprado.equals(&a));
 a.attributes->attributes.front().value.custom->operator[]("jvlootdono").value=42;
 b.attributes->attributes.front().value.custom->operator[]("jvlootdono").value=43;
 assert(!a.equals(&b));
 b.attributes->attributes.front().value.custom->operator[]("jvlootdono").value=42;
 assert(a.equals(&b));
 b.attributes->attributes.front().value.custom->operator[]("jvlootraros").value=1;
 assert(!a.equals(&b));
 c.id=200;assert(!a.equals(&c));
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)/'test.cpp';p.write_text(inicio+metodo+'\n'+testes)
 subprocess.run(['g++','-std=c++17',str(p),'-o',str(Path(tmp)/'test')],check=True)
 subprocess.run([str(Path(tmp)/'test')],check=True)
print('OK: pilhas com mesma marca combinam; loot, raros e itens pessoais permanecem separados')
