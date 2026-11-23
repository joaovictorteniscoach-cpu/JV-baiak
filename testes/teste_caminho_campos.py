"""Compila a classificacao real do cliente e verifica campos/obstaculos.
Uso: python testes/teste_caminho_campos.py /caminho/otclient-patcheado
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

fonte=Path(sys.argv[1])/'src/client'
mapa=(fonte/'map.cpp').read_text()
jogador=(fonte/'localplayer.cpp').read_text()
funcoes='\n'.join(re.search(p, mapa, re.S)[0] for p in [
    r'    bool jvCampoTransponivel\(.*?\n    \}',
    r'    bool jvCaminhoComCampo\(.*?\n    \}',
])
assert 'tile->getGroundSpeed() + (campo ? 10000.0f : 0.0f)' in mapa
assert 'const bool campo = !isNotWalkable' in mapa
assert 'const bool caminhoParcial = result->path.size() > 127' in jogador
assert 'fim = fim.translatedToDirection(direction)' in jogador
codigo=r'''
#include <cassert>
#include <cstdint>
#include <memory>
#include <vector>
struct Thing {uint32_t id;bool item,path;bool isNotPathable(){return path;}bool isItem(){return item;}uint32_t getId(){return id;}};
struct Tile {std::vector<std::shared_ptr<Thing>> things;const auto&getThings(){return things;}};
using TilePtr=std::shared_ptr<Tile>;
'''+funcoes+r'''
int main(){
 auto t=std::make_shared<Tile>();
 auto add=[&](int id,bool item,bool block){t->things.push_back(std::make_shared<Thing>(Thing{uint32_t(id),item,block}));};
 assert(!jvCaminhoComCampo(t));add(2118,true,true);assert(jvCaminhoComCampo(t));
 add(2121,true,true);assert(jvCaminhoComCampo(t));add(9999,true,false);assert(jvCaminhoComCampo(t));
 add(9999,true,true);assert(!jvCaminhoComCampo(t));t->things.pop_back();
 add(2118,false,true);assert(!jvCaminhoComCampo(t));
 t->things.clear();add(2118,true,false);assert(jvCaminhoComCampo(t));
 assert(jvCampoTransponivel(105)&&jvCampoTransponivel(10071));
 assert(!jvCampoTransponivel(2122)&&!jvCampoTransponivel(2129));
}
'''
with tempfile.TemporaryDirectory() as d:
    p=Path(d)/'teste.cpp';exe=Path(d)/'teste';p.write_text(codigo)
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(p),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
print('OK: campos reconhecidos, obstaculos preservados, custo de rota e continuacao longa')
