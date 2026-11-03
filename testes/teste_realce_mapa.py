"""Compila updateRect e getPosition reais para comparar realce e clique no HUD escalado."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

if __name__ == '__main__':
    source = (Path(sys.argv[1]) / 'src/client/mapview.cpp').read_text()
    update = re.search(r'void MapView::updateRect\(const Rect& rect\) \{.*?\n}', source, re.S)[0]
    position = re.search(r'Position MapView::getPosition\(const Point& mousePos\).*?\n}', source, re.S)[0]
    code = r'''
    #include <cassert>
    #include <iostream>
    struct Point {
     int x=0,y=0;
     Point()=default; Point(int x,int y):x(x),y(y){}
     Point operator*(float v)const{return {int(x*v),int(y*v)};}
     Point operator-(Point p)const{return {x-p.x,y-p.y};}
     bool operator==(Point p)const{return x==p.x&&y==p.y;}
     bool operator!=(Point p)const{return !(*this==p);}
     Point scale(float v){if(v!=1.f){float factor=1.f-1.f/v;x-=x*factor;y-=y*factor;}return *this;}
    };
    using Position=Point;
    struct Size {int w=1,h=1;};
    struct Rect {
     int x=0,y=0,w=1,h=1;
     bool operator!=(Rect r)const{return x!=r.x||y!=r.y||w!=r.w||h!=r.h;}
     Point topLeft()const{return {x,y};}
     Size size()const{return {w,h};}
     int width()const{return w;} int height()const{return h;}
     bool contains(Point p)const{return p.x>=x&&p.y>=y&&p.x<x+w&&p.y<y+h;}
    };
    struct Window {float density=1;Point mouse;float getDisplayDensity(){return density;}Point getMousePosition(){return mouse;}}g_window;
    struct App {float getHUDScale(){return g_window.density;}}g_app;
    constexpr float DEFAULT_DISPLAY_DENSITY=1;
    struct MapView {
     struct Info {Position camera;Rect rect,srcRect;Point drawOffset;float horizontalStretchFactor=1,verticalStretchFactor=1;}m_posInfo;
     bool m_updateMapPosInfo=true;Position m_mousePosition;
     Position getCameraPosition(){return {1000,1000};}
     void requestUpdateVisibleTiles(){} void requestUpdateMapPosInfo(){m_updateMapPosInfo=true;}
     Rect calcFramebufferSource(Size size){return {0,0,size.w,size.h};}
     void onMouseMove(Position p,bool){m_mousePosition=p;}
     // O teste compara os pontos do mesmo mapa antes da projecao em coordenadas mundiais.
     Position getPosition(Point p,Size){return p;}
     Position getPosition(const Point& mousePos);
     void updateRect(const Rect& rect);
    };
    '''
    tests = r'''
    int main(){
     for(float density:{1.f,1.25f,1.4f,1.5f,2.f}) {
      g_window.density=density;
      for(Point mouse:{Point{50,60},Point{160,100},Point{240,180}}) {
       g_window.mouse=mouse;MapView map;map.updateRect({10,15,1000,800});
       auto clicked=map.getPosition(mouse);
       assert(map.m_mousePosition==clicked);
       // Atualizar a camera com o dedo parado deve preservar a mesma selecao.
       map.m_updateMapPosInfo=true;map.updateRect({10,15,1000,800});
       assert(map.m_mousePosition==clicked);
      }
     }
     std::cout<<"OK: realce e clique coincidem em HUD 1/1.25/1.4/1.5/2, inclusive ao atualizar a camera\n";
    }
    '''
    with tempfile.TemporaryDirectory() as directory:
        cpp=Path(directory)/'map.cpp';exe=Path(directory)/'map'
        cpp.write_text(code+position+'\n'+update+'\n'+tests)
        subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(cpp),'-o',str(exe)],check=True)
        subprocess.run([str(exe)],check=True)
