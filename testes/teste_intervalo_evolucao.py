"""Compila as funcoes reais do patch e confere temporizadores e cadencia.
Uso: python testes/teste_intervalo_evolucao.py /caminho/fonte-com-patches
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

src = (Path(sys.argv[1]) / 'src/player.cpp').read_text()
funcs = ''.join(re.search(r'void Player::' + nome + r'\([^\n]*\)\n\{.*?\n\}', src, re.S)[0]
                for nome in ['scheduleEvolutionAttack', 'doAttacking'])
header = r'''
#include <cassert>
#include <algorithm>
#include <functional>
#include <map>
#include <cstdint>
#include <iostream>
static int64_t now=10000;
#define OTSYS_TIME() now
#define CONDITION_PACIFIED 1
struct Player;
struct Item{};
struct Weapon {bool useWeapon(Player*,Item*,bool)const;static bool useFist(Player*,bool);};
struct Weapons {Weapon w;const Weapon* getWeapon(Item*){return &w;}} weapons;
Weapons* g_weapons=&weapons;
struct Task {uint32_t delay;std::function<void()> fn;};
Task* createSchedulerTask(uint32_t t,std::function<void()>fn){return new Task{t,fn};}
struct Scheduler {
 uint32_t id=0;std::map<uint32_t,std::pair<int64_t,std::function<void()>>> q;
 uint32_t addEvent(Task*t){q[++id]={now+t->delay,t->fn};delete t;return id;}
 void stopEvent(uint32_t i){q.erase(i);}
 void advance(int64_t end){while(true){auto best=q.end();for(auto it=q.begin();it!=q.end();++it)if(it->second.first<=end&&(best==q.end()||it->second.first<best->second.first))best=it;if(best==q.end())break;auto t=best->second;q.erase(best);now=t.first;t.second();}now=end;}
}g_scheduler;
struct Game {std::map<uint32_t,Player*> players;Player*getPlayerByID(uint32_t id){auto i=players.find(id);return i==players.end()?nullptr:i->second;}void checkCreatureAttack(uint32_t id); }g_game;
struct Player {
 uint32_t id,attackSpeed=0,evolutionAttackEvent=0;int64_t lastAttack=0;bool attackedCreature=true,pacified=false;int hits=0;
 explicit Player(uint32_t i):id(i){g_game.players[id]=this;}
 ~Player(){if(evolutionAttackEvent)g_scheduler.stopEvent(evolutionAttackEvent);g_game.players.erase(id);}
 uint32_t getID(){return id;}bool getAttackedCreature(){return attackedCreature;}uint32_t getAttackSpeed(){return attackSpeed?attackSpeed:350;}
 bool hasCondition(int){return pacified;}Item*getWeapon(){return nullptr;}
 void scheduleEvolutionAttack();void doAttacking(uint32_t);
};
bool Weapon::useWeapon(Player*p,Item*,bool)const{p->hits++;return true;}
bool Weapon::useFist(Player*p,bool){p->hits++;return true;}
void Game::checkCreatureAttack(uint32_t id){auto p=getPlayerByID(id);if(p&&p->attackedCreature)p->doAttacking(0);}
'''
tests = r'''
int main(){
 for(uint32_t interval:{320,285,250,220}) {
  now=10000; Player p(1);p.attackSpeed=interval;p.doAttacking(0);
  assert(g_scheduler.q.size()==1);p.doAttacking(0);assert(g_scheduler.q.size()==1&&p.hits==1);
  g_scheduler.advance(now+1000);assert(p.hits==1+1000/int(interval));
  p.attackedCreature=false;g_scheduler.advance(now+interval);assert(g_scheduler.q.empty());
 }
 {Player p(1);p.doAttacking(0);assert(g_scheduler.q.empty());}
 {Player p(1);p.attackSpeed=100;p.doAttacking(0);g_scheduler.advance(now+1000);assert(p.hits==6);}
 {Player p(1);p.attackSpeed=220;p.pacified=true;p.doAttacking(0);g_scheduler.advance(now+1000);assert(p.hits==0);}
 assert(g_scheduler.q.empty());
 {Player p(1);p.attackSpeed=220;p.doAttacking(0);g_game.players.erase(1);g_scheduler.advance(now+1000);assert(g_scheduler.q.empty());}
 std::cout<<"OK: cadencia real, um timer, Parar, sem bonus na base, piso 200ms, pacificacao e logout\n";
}
'''
with tempfile.TemporaryDirectory() as d:
    cpp=Path(d)/'teste.cpp';exe=Path(d)/'teste'
    cpp.write_text(header+funcs+tests)
    subprocess.run(['g++','-std=c++14','-Wall','-Wextra','-Werror',str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
