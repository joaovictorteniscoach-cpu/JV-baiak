"""Testa o Lua real do login contra telas e escalas antigas, sem alterar credenciais."""
from pathlib import Path
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
function widget(id, parent)
 local w={id=id,width=380,height=229,visible=true,children={},anchors={},text=''}
 function w:getId()return self.id end
 function w:getClassName()return self.class or 'UIWidget' end
 function w:getChildren()return self.children end
 function w:setSize(s)self.width=s.width;self.height=s.height end
 function w:setImageRepeated()end
 function w:setPaddingRight(n)self.paddingRight=n end
 function w:getWidth()return self.width end
 function w:getHeight()return self.height end
 function w:setWidth(n)self.width=n end
 function w:setHeight(n)self.height=n end
 function w:breakAnchors()self.anchors={}end
 function w:addAnchor(a,id,edge)self.anchors[a]={id,edge}end
 function w:setMarginTop(n)self.mt=n end
 function w:setMarginLeft(n)self.ml=n end
 function w:setText(t)self.text=t end
 function w:setVisible(v)self.visible=v end
 function w:hide()self.visible=false end
 function w:show()self.visible=true end
 function w:isVisible()return self.visible end
 function w:setPosition(p)self.pos=p end
 function w:bindRectToParent()self.bound=true end
 if parent then parent[id]=w;table.insert(parent.children,w) end
 return w
end
rootWidget=widget('root');win=widget('enterGame',rootWidget)
function rootWidget:recursiveGetChildById(id)if id=='enterGame'then return win end end
for _,id in ipairs({'emailLabel','passwordLabel','accountNameTextEdit','accountPasswordTextEdit','rememberEmailBox','autoLoginBox','jvLoginButton','serverHostTextEdit','serverPortTextEdit'})do widget(id,win)end
win.accountNameTextEdit.text='conta preservada';win.accountPasswordTextEdit.text='senha preservada'
win.rememberEmailBox.checked=true;win.autoLoginBox.checked=true
local eye=widget('eye',win.accountNameTextEdit);eye.class='UIButton'
AnchorLeft=1;AnchorRight=2;AnchorTop=3;AnchorBottom=4
g_platform={isMobile=function()return true end}
online=false;hud=1.5;resizes=0
g_game={isOnline=function()return online end}
g_window={getDisplayDensity=function()return hud end}
g_app={setHUDScale=function(n)hud=n;resizes=resizes+1 end}
cycleEvent=function(fn)tick=fn end
connect=function()end
addEvent=function(fn)fn()end
''')
s=(Path(__file__).resolve().parents[1]/'web/otclientrc-extra.lua').read_text()
lua.execute(s[s.index('-- A escala de combate nao pode ampliar'):].split('-- Marcadores opcionais para conferir')[0])
lua.execute('''
for _,size in ipairs({{390,844},{402,874},{844,390},{874,402},{724,330},{667,280},{320,568}})do
 for _,old in ipairs({1,1.5,2,3})do
  rootWidget.width=size[1];rootWidget.height=size[2];hud=old;online=false
  JVLogin.ajustar()
  assert(hud==1)
  assert(win.width<=size[1]-24 and win.height<=size[2]-24)
  assert(win.pos.x>=0 and win.pos.y>=0)
  assert(win.pos.x+win.width<=size[1] and win.pos.y+win.height<=size[2])
  assert(win.accountNameTextEdit.height==44 and win.accountPasswordTextEdit.height==44 and win.jvLoginButton.height==44)
  assert(win.jvLoginButton.visible)
  assert(win.rememberEmailBox.checked and win.autoLoginBox.checked)
  assert(win.accountNameTextEdit.text=='conta preservada' and win.accountPasswordTextEdit.text=='senha preservada')
  assert(win.rememberEmailBox.visible==(size[2]>=360))
  -- Repetir a verificacao nao provoca um ciclo de redimensionamento.
  local before=resizes;JVLogin.ajustar();assert(before==resizes)
 end
end
online=true;hud=1.4;JVLogin.ajustar();assert(hud==1.4)
''')
print('OK: login em retrato/paisagem, HUD antigo 1/1.5/2/3, alvos 44, credenciais e idempotencia')
