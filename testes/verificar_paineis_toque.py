"""Executa o Lua real das janelas e do cliente autoloot, sem rede de jogo."""
from pathlib import Path
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
function w(id,width,height,parent)
 local t={id=id or '',width=width or 176,height=height or 162,children={},visible=true,on=true,x=0,y=0}
 function t:getId()return self.id end
 function t:setId(v)self.id=v end
 function t:getWidth()return self.width end
 function t:getHeight()return self.height end
 function t:setWidth(v)self.width=v end
 function t:setHeight(v)self.height=v end
 function t:setSize(v)self.width=v.width;self.height=v.height end
 function t:getPosition()return {x=self.x,y=self.y}end
 function t:getY()return self.y end
 function t:getX()return self.x end
 function t:setPosition(v)self.x=v.x;self.y=v.y end
 function t:getParent()return self.parent end
 function t:setParent(p)self.parent=p;table.insert(p.children,self)end
 function t:bindRectToParent()
  if self.parent then self.x=math.max(0,math.min(self.x,self.parent.width-self.width));self.y=math.max(0,math.min(self.y,self.parent.height-self.height))end
 end
 function t:getChildById(id)for _,c in ipairs(self.children)do if c.id==id then return c end end end
 function t:isOn()return self.on end
 function t:isDestroyed()return false end
 function t:show()self.visible=true end
 function t:hide()self.visible=false end
 function t:isVisible()return self.visible end
 function t:setVisible(v)self.visible=v end
 function t:setText(v)self.text=v end
 function t:getText()return self.text or '' end
 function t:destroyChildren()self.children={}end
 function t:addOption()end
 function t:setCurrentOption(v)self.option=v end
 for _,m in ipairs({'breakAnchors','addAnchor','setMarginLeft','setMarginRight','setMarginTop','setMarginBottom','setImageSize','setImageSource','setImageRepeated','setPhantom','setDraggable','raise','focus','setVerticalScrollBar','setTextWrap','setPercent','setBackgroundColor'})do t[m]=function()end end
 if parent then t:setParent(parent)end
 return t
end
Container={};LocalPlayer={}
rootWidget=w('root',670,275);main=w('main');right=w('right')
inv=w('maininventorypanel',176,162,main);mini=w('mainmappanel',176,116,main);chat=w('chat',670,80,rootWidget);shortcuts=w('shortcuts')
settings={};g_settings={getNode=function(k)return settings[k]end,setNode=function(k,v)settings[k]=v end}
AnchorLeft=1;AnchorRight=2;AnchorTop=3;AnchorBottom=4;AnchorHorizontalCenter=5
opened=0;online=true;char='A';containers={};queue={};events={};bindings={}
g_game={isOnline=function()return online end,getCharacterName=function()return char end,getContainers=function()return containers end,getLocalPlayer=function()return {getInventoryItem=function()return {}end,getHealth=function()return 100 end,getMaxHealth=function()return 100 end,getMana=function()return 50 end,getMaxMana=function()return 100 end}end,open=function()opened=opened+1 end,cancelAttack=function()end,cancelFollow=function()end}
g_platform={isMobile=function()return true end}
g_ui={createWidget=function(_,parent)return w('',176,162,parent)end}
g_logger={info=function()end}
g_keyboard={bindKeyDown=function(k,v)bindings[k]=v end}
UIWindow={onDragEnter=function()return true end}
function connect(obj,t)events[obj]=events[obj]or{};for k,v in pairs(t)do local before=events[obj][k];local fn=v;events[obj][k]=function(...)if before then before(...)end;fn(...)end end end
function scheduleEvent(fn)table.insert(queue,fn);return #queue end
function addEvent(fn)table.insert(queue,fn)end
function removeEvent()end
function flush()local q=queue;queue={};for _,fn in ipairs(q)do fn()end end
modules={game_interface={getRootPanel=function()return rootWidget end,getMainRightPanel=function()return main end,getRightPanel=function()return right end,getBottomPanel=function()return chat end,updateStretchShrink=function()end},game_inventory={changeInventorySize=function()end,selectCombat=function()end,selectPosture=function()end},game_shortcuts={getPanel=function()return shortcuts end},game_console={getConsole=function()return chat end},client_options={toggle=function()end},game_hotkeys={toggle=function()end}}
ProtocolGame={registerExtendedOpcode=function(_,cb)opcode=cb end};json={decode=function()return {}end}
''')
lua.execute((ROOT/'web/jv_interface.lua').read_text())
lua.execute((ROOT/'web/jv_autoloot.lua').read_text())
lua.execute('''
events[g_game].onGameStart();flush()
assert(JVToque.pronto and main.width==0 and right.width==0)
assert(inv.parent~=main and mini.parent~=main)
assert(opened==1)
local e=JVToque.janelas.jvEquipamento
assert(e:isVisible())
e:getChildById('jvFechar').onClick();assert(not e:isVisible())
bindings['Ctrl+Shift+F8']();assert(e:isVisible())
e:getChildById('jvMinimizar').onClick();assert(e.height==32)
e:getChildById('jvMinimizar').onClick();assert(e.height==194)
e:setPosition({x=14,y=36});e.onDragLeave(e)
e:setPosition({x=99,y=99});JVToque.posicionar(e);assert(e.x==14 and e.y==36)
char='B';JVToque.posicionar(e);assert(e.x~=14)
char='A';JVToque.posicionar(e);assert(e.x==14)
for _,key in ipairs({'F2','F3','F4','F5','F8','F9','F10','F11','F12'})do assert(bindings['Ctrl+Shift+'..key])end
-- O cliente pede os dados; nunca afirma que uma escolha foi salva antes da resposta.
requests={};JVAutoloot.abrir();assert(not JVAutoloot.pendente and JVAutoloot.estado==nil);JVAutoloot.window:hide()
JVAutoloot.transporte=function(a,r)table.insert(requests,{a,r})end
bindings['Ctrl+Shift+F3']();assert(requests[1][1]=='list' and JVAutoloot.pendente)
local data={message='',goldBank=false,items={{id=2148,name='gold coin',collect=true}}}
assert(JVAutoloot.receber(data));assert(not JVAutoloot.pendente)
local row=JVAutoloot.lista.children[1];local choice=row.children[2]
choice.onOptionChange(choice,'Ignorar','ignore')
assert(requests[2][1]=='ignore' and requests[2][2]=='2148')
assert(JVAutoloot.estado.items[1].collect) -- espera a confirmacao
assert(not JVAutoloot.receber({items={{id=2148,name='gold',collect='sim'}}}))
assert(JVAutoloot.estado.items[1].collect)
assert(JVAutoloot.receber({message='',goldBank=false,items={{id=2148,name='gold coin',collect=false}}}))
assert(not JVAutoloot.estado.items[1].collect)
events[g_game].onGameEnd();assert(JVAutoloot.estado==nil and not JVAutoloot.window:isVisible() and not JVToque.pronto)
events[g_game].onGameStart();flush();assert(JVToque.pronto and JVToque.janelas.jvEquipamento==e)
''')
print('OK: widgets nativos flutuantes, fechar/reabrir, minimizar, posicoes por personagem e autoloot confirmado pelo servidor')
