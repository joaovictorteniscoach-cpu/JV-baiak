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
    helper = re.search(r'static Point jvInputPosition[\s\S]*?\n}', source)[0]
    helper = re.sub(r'MAIN_THREAD_EM_ASM\(\{[\s\S]*?\}, clientX, clientY, point\);',
                    'testNormalize(clientX, clientY, point);', helper)
    header = r'''
    #include <cassert>
    #include <cmath>
    #include <functional>
    #include <vector>
    #include <iostream>
    struct Point { int x=0,y=0; Point()=default; Point(int x,int y):x(x),y(y){} Point operator-(const Point& b)const{return Point(x-b.x,y-b.y);} };
    namespace Fw { enum {NoInputEvent,MouseMoveInputEvent,MousePressInputEvent,MouseReleaseInputEvent,MouseWheelInputEvent}; enum {MouseLeftButton,MouseRightButton,MouseMidButton}; enum {MouseWheelDown,MouseWheelUp}; }
    enum {EMSCRIPTEN_EVENT_TOUCHSTART,EMSCRIPTEN_EVENT_TOUCHMOVE,EMSCRIPTEN_EVENT_TOUCHEND,EMSCRIPTEN_EVENT_TOUCHCANCEL};
    struct EmscriptenTouchPoint {double targetX=0,targetY=0; bool isChanged=false; double clientX=0,clientY=0; EmscriptenTouchPoint()=default; EmscriptenTouchPoint(double x,double y,bool changed):targetX(x),targetY(y),isChanged(changed),clientX(x),clientY(y){} };
    struct EmscriptenTouchEvent {int numTouches=0; EmscriptenTouchPoint touches[3];};
    struct EmscriptenMouseEvent {double clientX=0,clientY=0;};
    struct EmscriptenWheelEvent {EmscriptenMouseEvent mouse; double deltaY=0;};
    struct Input {int type=0,mouseButton=0,wheelDirection=0;Point mousePos,mouseMoved;void reset(){*this=Input();}};
    struct Timer {bool active=false;int elapsed=0;void stop(){active=false;}void restart(){active=true;elapsed=0;}bool running(){return active;}int ticksElapsed(){return elapsed;}};
    struct Dispatcher {std::vector<std::function<void()>> q;template<class T>void addEvent(T f){q.push_back(f);}void run(){while(!q.empty()){auto f=q.front();q.erase(q.begin());f();}}}g_dispatcher;
    static bool s_pinca=false;
    static double s_touchStartX=0,s_touchStartY=0;
    struct Size {int w=100,h=100; int width() const{return w;} int height() const{return h;}};
    void testNormalize(double x,double y,double* point){point[0]=x/100;point[1]=y/100;}
    // HELPER_REAL
    static constexpr double JV_TOQUE_TOLERANCIA=12;
    struct BrowserWindow {
     Size m_size;bool m_usingTouch=false;double m_displayDensity=1;unsigned m_mouseButtonStates=0;Timer m_clickTimer;Input m_inputEvent;
     std::function<void(Input)> m_onInputEvent;
     void handleTouchCallback(int,const EmscriptenTouchEvent*);
     void handleMouseWheelCallback(const EmscriptenWheelEvent*);
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
     {int leftReleases=0;for(auto e:events)if(e.mouseButton==Fw::MouseLeftButton&&e.type==Fw::MouseReleaseInputEvent){++leftReleases;assert(e.mousePos.x==-10000&&e.mousePos.y==-10000);}assert(leftReleases==1);}
     events.clear();send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);w.m_clickTimer.elapsed=300;send(EMSCRIPTEN_EVENT_TOUCHEND,&t);assert(right()==0);assert(events.back().mousePos.x==50);

     for(int count:{0,1}){
      events.clear();t.numTouches=1;send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);w.m_clickTimer.elapsed=500;t.numTouches=count;
      send(EMSCRIPTEN_EVENT_TOUCHCANCEL,&t);assert(right()==0);assert(w.m_mouseButtonStates==0);assert(!w.m_clickTimer.running());
      assert(events.back().mousePos.x==-10000&&events.back().mousePos.y==-10000);
     }
     events.clear();t.numTouches=1;send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);t.touches[0].targetX+=20;send(EMSCRIPTEN_EVENT_TOUCHMOVE,&t);send(EMSCRIPTEN_EVENT_TOUCHEND,&t);assert(right()==0);
     events.clear();t.numTouches=1;send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);t.numTouches=2;send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);assert(s_pinca);
     send(EMSCRIPTEN_EVENT_TOUCHCANCEL,nullptr);assert(!s_pinca);assert(w.m_mouseButtonStates==0);assert(right()==0);
     w.m_size={200,200};t.numTouches=1;t.touches[0]={0,10,true};events.clear();send(EMSCRIPTEN_EVENT_TOUCHSTART,&t);assert(events.back().mousePos.x==0&&events.back().mousePos.y==20);
     t.touches[0].targetX=999;g_dispatcher.run();assert(events.back().mousePos.x==0);
     // Regressao: roda na borda aceita zero; o evento pode ser reutilizado
     // antes de o dispatcher executar e a posicao tem que continuar correta.
     events.clear();EmscriptenWheelEvent wheel;wheel.mouse={0,10};wheel.deltaY=1;
     w.handleMouseWheelCallback(&wheel);wheel.mouse={90,90};wheel.deltaY=-1;g_dispatcher.run();
     assert(events.size()==1);assert(events[0].mousePos.x==0&&events[0].mousePos.y==20);
     assert(events[0].type==Fw::MouseWheelInputEvent&&events[0].wheelDirection==Fw::MouseWheelDown);
     w.handleMouseWheelCallback(&wheel);g_dispatcher.run();assert(events.back().wheelDirection==Fw::MouseWheelUp);
     auto count=events.size();wheel.deltaY=0;w.handleMouseWheelCallback(&wheel);w.handleMouseWheelCallback(nullptr);g_dispatcher.run();assert(count==events.size());
     std::cout<<"OK: scroll com coordenadas capturadas, toque curto, segurar, arrastar, cancelamento 0/1 ponto, cancelamento da pinça e coordenadas escaladas\n";
    }
    '''
    tests=tests.replace('int main(){', r'''
    int main(){
     for(double density:{1.0,1.25,1.4,1.5,2.0}) for(Size size: {Size{607,281},Size{281,607},Size{2726,1872}}) {
      for(double x:{0.,5.,50.,99.,100.}) for(double y:{0.,5.,50.,99.,100.}) {
       auto p=jvInputPosition(x,y,size,density);
       assert(p.x==int(x/100*size.width()/density));
       assert(p.y==int(y/100*size.height()/density));
      }
     }
     assert(jvInputPosition(50,50,Size{0,0},1).x==-10000);
     assert(jvInputPosition(50,50,Size{100,100},0).x==-10000);
     assert(jvInputPosition(-1,50,Size{100,100},1).x==-10000);
    ''')
    header=header.replace('// HELPER_REAL',helper)
    with tempfile.TemporaryDirectory() as tmp:
        cpp=Path(tmp)/'toque.cpp';exe=Path(tmp)/'toque'
        wheel = re.search(r'void BrowserWindow::handleMouseWheelCallback\(.*?\n}\n', source, re.S)
        cpp.write_text(header+match[0]+wheel[0]+tests)
        subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(cpp),'-o',str(exe)],check=True)
        subprocess.run([str(exe)],check=True)
