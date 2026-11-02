"""Executa o codigo Lua dos paineis de toque e confere alvos e exclusao mutua."""
from pathlib import Path
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
function w(id, width, height, class, parent)
 local x={id=id, width=width or 176, height=height or 162,class=class or 'UIWidget',children={},visible=true,on=true}
 function x:getId()return self.id end
 function x:setId(n)self.id=n;if self.parent then self.parent[n]=self end end
 function x:getClassName()return self.class end
 function x:getChildren()return self.children end
 function x:getChildById(n)for _,c in ipairs(self.children)do if c.id==n then return c end end end
 function x:setSize(t)self.width=t.width;self.height=t.height end
 function x:setHeight(n)self.height=n end
 function x:setWidth(n)self.width=n end
 function x:getHeight()return self.height end
 function x:getWidth()return self.width end
 function x:addAnchor()end
 function x:setMarginLeft(n)self.left=n end
 function x:setMarginTop(n)self.top=n end
 function x:setText(t)self.text=t end
 function x:show()self.visible=true end
 function x:hide()self.visible=false end
 function x:setVisible(v)self.visible=v end
 function x:isVisible()return self.visible end
 function x:isOn()return self.on end
 function x:setOn(v)self.on=v end
 function x:setClipping(v)self.clipping=v end
 function x:setDraggable(v)self.draggable=v end
 function x:setImageRepeated(v)self.repeated=v end
 function x:getLayout()return {setCellSize=function(_,size)self.cell=size end} end
 if parent then x.parent=parent;table.insert(parent.children,x);parent[id]=x end
 return x
end
rootWidget=w('root')
rightPanel=w('rightPanel');main=w('main'); inv=w('maininventorypanel',176,162,nil,main)
on=w('onPanel',176,162,nil,inv);w('slot',32,32,'UIItem',on);w('tinyCombat',20,20,'UIButton',on)
mini=w('mainmappanel',176,116,nil,main);w('minimapBorder',115,111,nil,mini);w('zoomIn',20,20,'UIButton',mini)
opts=w('mainoptionspanel',176,28,nil,main);op=w('onPanel',176,160,nil,opts);w('offPanel',176,28,nil,opts)
options=w('options',108,100,nil,op);specials=w('specials',44,100,nil,op);store=w('store',108,20,nil,op);w('resizer',44,20,'UIButton',op)
for i=1,9 do w('option'..i,20,20,'UIButton',options) end
for i=1,2 do w('special'..i,20,20,'UIButton',specials) end
w('storeButton',108,20,'UIButton',store)
g_platform={isMobile=function()return true end}
g_ui={createWidget=function(class,parent)return w('',0,0,class,parent)end}
AnchorLeft=1;AnchorRight=2;AnchorTop=3
bindings={};events={};timers={}
g_keyboard={bindKeyDown=function(key,fn)bindings[key]=fn end}
connect=function(obj,t)events[obj]=t end
scheduleEvent=function(fn)timers[#timers+1]=fn end
updates=0
local function nothing()end
modules={game_interface={getMainRightPanel=function()return main end,getRightPanel=function()return rightPanel end,updateStretchShrink=function()updates=updates+1 end},
 game_inventory={changeInventorySize=nothing,selectCombat=nothing,selectPosture=nothing},
 game_minimap={zoomIn=nothing,zoomOut=nothing,resetMap=nothing,upLayer=nothing,downLayer=nothing}}
g_game={isOnline=function()return true end,setSafeFight=nothing,isSafeFight=function()return true end,cancelAttack=nothing,cancelFollow=nothing}
''')
s=(Path(__file__).resolve().parents[1]/'web/otclientrc-extra.lua').read_text()
lua.execute(s[s.index('-- Interface de toque:'):s.index('-- A escala de combate nao pode ampliar')])
lua.execute('''
events[g_game].onGameStart()
for _,fn in ipairs(timers)do fn() end
assert(inv.visible and not mini.visible and not opts.visible)
assert(not on.tinyCombat.visible and on.slot.visible)
for _,key in ipairs({'F8','F9','F10','F11'}) do assert(bindings['Ctrl+Shift+'..key]) end
for _,page in ipairs({'maininventorypanel','mainmappanel','mainoptionspanel','jvCombate'}) do
 JVToque.selecionar(page)
 local visible=0
 for _,child in ipairs(main.children)do if child.visible then visible=visible+1;assert(child.id==page) end end
 assert(visible==1 and rightPanel.clipping)
 assert(main.height<=235) -- 235*1.4 + faixa dos atalhos (42*1.4) cabe em 390 pontos
end
for _,parent in ipairs({options,specials,store,main.jvCombate}) do
 for _,b in ipairs(parent.children)do
  assert(b.width*1.4>=44 and b.height*1.4>=44)
 end
end
-- Os botoes criados no mesmo painel nao se sobrepoem.
for _,parent in ipairs({main.jvCombate,mini}) do
 local buttons={}
 for _,b in ipairs(parent.children)do if b.class=='Button' and b.visible then buttons[#buttons+1]=b end end
 for i,a in ipairs(buttons) do for j,b in ipairs(buttons)do if i<j then
  assert(a.left+a.width<=b.left or b.left+b.width<=a.left or a.top+a.height<=b.top or b.top+b.height<=a.top)
 end end end
end
''')
print('OK: paginas exclusivas, equipamento acessivel, botoes >=44 pontos e sem sobreposicao')
