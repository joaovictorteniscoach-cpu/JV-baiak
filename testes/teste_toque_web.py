"""Compila a função real de toque já com os patches, com dependências mínimas.
Uso: python testes/teste_toque_web.py /caminho/otclient-com-patches
Não simula o renderizador nem comprova o comportamento do Safari.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

if __name__ == '__main__':
    source = (Path(sys.argv[1]) / 'src/framework/platform/browserwindow.cpp').read_text()
    match = re.search(r'void BrowserWindow::handleTouchCallback\(.*?\n}\n', source, re.S)
    if not match:
        raise SystemExit('Função de toque não encontrada')
    header = r'''
    #include <cassert>
    #include <cmath>
    #include <functional>
    #include <vector>
    #include <iostream>
    struct Point { int x=0,y=0; Point()=default; Point(int x,int y):x(x),y(y){} Point operator-(const Point& b)const{return Point(x-b.x,y-b.y);} };
    namespace Fw { enum {NoInputEvent,MouseMoveInputEvent,MousePressInputEvent,MouseReleaseInputEvent}; enum {MouseLeftButton,MouseRightButton}; }
    enum {EMSCRIPTEN_EVENT_TOUCHSTART,EMSCRIPTEN_EVENT_TOUCHMOVE,EMSCRIPTEN_EVENT_TOUCHEND,EMSCRIPTEN_EVENT_TOUCHCANCEL};
    struct EmscriptenTouchPoint {double targetX=0,targetY=0; bool isChanged=false;};
    struct EmscriptenTouchEvent {int numTouches=0; EmscriptenTouchPoint touches[3];};
    struct Input {int type=0,mouseButton=0;Point mousePos,mouseMoved;void reset(){*this=Input();}};
    struct Timer {bool active=false;int elapsed=0;void stop(){active=false;}void restart(){active=true;elapsed=0;}bool running(){return active;}int ticksElapsed(){return elapsed;}};
    struct Dispatcher {std::vector<std::function<void()>> q;template<class T>void addEvent(T f){q.push_back(f);}void run(){while(!q.empty()){auto f=q.front();q.erase(q.begin());f();}}}g_dispatcher;
    static bool s_pinca=false;
    static double s_pixelRatio=1,s_touchStartX=0,s_touchStartY=0;
    static constexpr double JV_TOQUE_TOLERANCIA=12;
    struct BrowserWindow {
     bool m_usingTouch=false;double m_displayDensity=1;unsigned m_mouseButtonStates=0;Timer m_clickTimer;Input m_inputEvent;
     std::function<void(Input)> m_onInputEvent;
     void handleTouchCallback(int,const EmscriptenTouchEvent*);
    };
    '''
    tests = r'''
    int main(){
     BrowserWindow w;std::vector<Input> events;w.m_onInputEvent=[&](Input e){events.push_back(e);};
     EmscriptenTouchEvent t;t.numTouches=1;t.touches[0]={50,60,true};
     auto send=[&](int kind,EmscriptenTouchEvent* p){w.handleTouchCallback(kind,p);g_dispatcher.run();};
     auto right=[&](){int n=0;for(auto e:events)if(e.mouseButton==Fw::MouseRightButton&&e.type==Fw::MousePressInputEvent)++n;return n;};
     send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);w.m_clickTimer.elapsed=50;send(EMSCRIPTEN_EVENT_TOUCHEND,&t);
     assert(right()==0);assert(w.m_mouseButtonStates==0);
     events.clear();send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);w.m_clickTimer.elapsed=500;send(EMSCRIPTEN_EVENT_TOUCHEND,&t);assert(right()==1);
     for(int count:{0,1}){
      events.clear();t.numTouches=1;send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);w.m_clickTimer.elapsed=500;t.numTouches=count;
      send(EMSCRIPTEN_EVENT_TOUCHCANCEL,&t);assert(right()==0);assert(w.m_mouseButtonStates==0);assert(!w.m_clickTimer.running());
      assert(events.back().mousePos.x==-10000&&events.back().mousePos.y==-10000);
     }
     events.clear();t.numTouches=1;send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);t.touches[0].targetX+=20;send(EMSCRIPTEN_EVENT_TOUCHMOVE,&t);send(EMSCRIPTEN_EVENT_TOUCHEND,&t);assert(right()==0);
     events.clear();t.numTouches=1;send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);t.numTouches=2;send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);assert(s_pinca);
     send(EMSCRIPTEN_EVENT_TOUCHCANCEL,nullptr);assert(!s_pinca);assert(w.m_mouseButtonStates==0);assert(right()==0);
     s_pixelRatio=2;t.numTouches=1;t.touches[0]={0,10,true};events.clear();send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);assert(events.back().mousePos.x==0&&events.back().mousePos.y==20);
     t.touches[0].targetX=999;g_dispatcher.run();assert(events.back().mousePos.x==0);
     std::cout<<"OK: toque curto, segurar, arrastar, cancelamento 0/1 ponto, cancelamento da pinça e coordenadas escaladas\n";
    }
    '''
    with tempfile.TemporaryDirectory() as tmp:
        cpp=Path(tmp)/'toque.cpp';exe=Path(tmp)/'toque'
        cpp.write_text(header+match[0]+tests)
        subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(cpp),'-o',str(exe)],check=True)
        subprocess.run([str(exe)],check=True)
