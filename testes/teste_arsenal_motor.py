"""Compila funcoes reais do motor: requisitos, wands e atributos persistidos.
Uso: python testes/teste_arsenal_motor.py /caminho/fonte-com-patches
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

fonte = Path(sys.argv[1]) / 'src'
player = (fonte/'player.cpp').read_text()
weapons = (fonte/'weapons.cpp').read_text()
item = (fonte/'item.h').read_text()
requisito = re.search(r'ReturnValue Player::checkArsenalItem\(.*?\n\}', player, re.S)[0]
wand = re.search(r'int32_t WeaponWand::getWeaponDamage\(.*?\n\}', weapons, re.S)[0]
metodos = '\n'.join(re.search(r'\t\t' + assinatura + r'.*?\n\t\t\}', item, re.S)[0]
                    for assinatura in [r'const CustomAttribute\* getCustomAttribute\(const std::string& key\)',
                                       r'bool removeCustomAttribute\(const std::string& key\)'])
header = r'''
#include <algorithm>
#include <cassert>
#include <cstdint>
#include <iostream>
#include <string>
#include <unordered_map>
#include <variant>
namespace boost {template<class T>const T*get(const std::variant<int64_t,std::string>*v){return std::get_if<T>(v);}}
std::string asLowerCaseString(std::string s){for(auto&c:s)c=std::tolower(static_cast<unsigned char>(c));return s;}
const int ITEM_ATTRIBUTE_CUSTOM=1;
enum ReturnValue {RETURNVALUE_NOERROR,RETURNVALUE_CANNOTBEDRESSED,RETURNVALUE_YOUDONTHAVEREQUIREDPROFESSION,RETURNVALUE_NOTENOUGHLEVEL};
struct Item {
 struct CustomAttribute{std::variant<int64_t,std::string>value;};
 using CustomAttributeMap=std::unordered_map<std::string,CustomAttribute>;
 CustomAttributeMap attrs;int attack=310;
 bool hasAttribute(int)const{return !attrs.empty();}int getAttack()const{return attack;}
 CustomAttributeMap*getCustomAttributeMap(){return &attrs;}
 void set(const char*k,int64_t n){attrs[k].value=n;}
'''
middle = r'''
};
struct Vocation{int id=3;int getClientId()const{return id;}};
struct Player{
 Vocation v;const Vocation*vocation=&v;int level=1000,evo=4;
 int getLevel()const{return level;}
 bool getStorageValue(uint32_t k,int32_t&out)const{assert(k==79500);out=evo;return true;}
 ReturnValue checkArsenalItem(const Item*)const;
};
struct Creature{};
int randomMin=-1,randomMax=-1;
int normal_random(int a,int b){randomMin=a;randomMax=b;return b;}
struct WeaponWand {int minChange=70,maxChange=100;int32_t getWeaponDamage(const Player*,const Creature*,const Item*,bool=false)const;};
'''
tests = r'''
int main(){
 Item i;i.attrs["jvarmaid"].value=std::string("cetro:4");
 i.set("jvarmaclasse",3);i.set("jvarmalevel",1000);i.set("jvarmaevolucao",4);i.set("jvarmaevostorage",79500);
 Player p;assert(p.checkArsenalItem(&i)==RETURNVALUE_NOERROR);
 p.v.id=4;assert(p.checkArsenalItem(&i)==RETURNVALUE_YOUDONTHAVEREQUIREDPROFESSION);p.v.id=3;
 p.level=999;assert(p.checkArsenalItem(&i)==RETURNVALUE_NOTENOUGHLEVEL);p.level=1000;
 p.evo=3;assert(p.checkArsenalItem(&i)==RETURNVALUE_CANNOTBEDRESSED);p.evo=4;
 i.set("jvarmaevostorage",4294967296LL);assert(p.checkArsenalItem(&i)==RETURNVALUE_CANNOTBEDRESSED);i.set("jvarmaevostorage",79500);
 i.attrs["jvarmalevel"].value=std::string("1000");assert(p.checkArsenalItem(&i)==RETURNVALUE_CANNOTBEDRESSED);i.set("jvarmalevel",1000);
 i.attrs.erase("jvarmaevolucao");assert(p.checkArsenalItem(&i)==RETURNVALUE_CANNOTBEDRESSED);i.set("jvarmaevolucao",4);
 Item normal;assert(p.checkArsenalItem(&normal)==RETURNVALUE_NOERROR);assert(p.checkArsenalItem(nullptr)==RETURNVALUE_NOERROR);
 normal.set("outro",1);assert(p.checkArsenalItem(&normal)==RETURNVALUE_NOERROR);
 WeaponWand w;assert(w.getWeaponDamage(&p,nullptr,&i,true)==-310);
 assert(w.getWeaponDamage(&p,nullptr,&i)==-310);assert(randomMin==217&&randomMax==310);
 i.attack=300;w.getWeaponDamage(&p,nullptr,&i);assert(randomMin==210&&randomMax==300);
 i.attack=20000;assert(w.getWeaponDamage(&p,nullptr,&i,true)==-10000);
 i.attack=-10;assert(w.getWeaponDamage(&p,nullptr,&i,true)==0);
 assert(w.getWeaponDamage(&p,nullptr,&normal)==-100);assert(randomMin==70&&randomMax==100);
 assert(w.getWeaponDamage(&p,nullptr,nullptr,true)==-100);
 Item legado;legado.set("jvAscensaoTier",4);
 assert(legado.getCustomAttribute("jvascensaotier")!=nullptr);
 assert(legado.getCustomAttribute("JVASCENSAOTIER")!=nullptr);
 legado.set("jvascensaotier",3);assert(legado.removeCustomAttribute("JVASCENSAOTIER"));assert(legado.attrs.empty());
 assert(!legado.removeCustomAttribute("jvascensaotier"));
 std::cout<<"OK: funcoes C++ reais: classe, level, evolucao, metadados, dano wand/rod, limites e atributos antigos\n";
}
'''
with tempfile.TemporaryDirectory() as tmp:
    cpp=Path(tmp)/'teste.cpp';exe=Path(tmp)/'teste'
    cpp.write_text(header+metodos+middle+requisito+wand+tests)
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
