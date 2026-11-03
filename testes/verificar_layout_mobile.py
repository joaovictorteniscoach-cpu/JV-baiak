"""Executa o Lua real do layout com widgets mínimos; não substitui renderização no cliente."""
from pathlib import Path
import sys
from lupa import LuaRuntime

fonte=Path(sys.argv[1])
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((fonte/'modules/game_interface/gameinterface.lua').read_text())
lua.execute('''
function widget(h,width)
 local w={h=h or 0,w=width or 500,margin=0,enabled=true,draggable=true,dim={width=15,height=11}}
 function w:getHeight() return self.h end
 function w:getWidth() return self.w end
 function w:getVisibleDimension() return self.dim end
 function w:setVisibleDimension(d) self.dim=d end
 function w:setZoom(n) self.zoom=n end
 function w:setKeepAspectRatio(n) self.keep=n end
 function w:getMarginBottom() return self.margin end
 function w:setMarginBottom(n) self.margin=n end
 function w:setEnabled(n) self.enabled=n end
 function w:setDraggable(n) self.draggable=n end
 function w:setVisible(n) self.visible=n end
 function w:hide() self.visible=false end
 function w:setHeight(n) self.h=n end
 function w:breakAnchors()end
 function w:removeAnchor()end
 function w:setLimitVisibleDimension()end
 function w:addAnchor()end
 function w:setMarginRight(n)self.right=n end
 return w
end
mobile=true
optionCalls=0
g_platform={isMobile=function() return mobile end}
modules={client_options={getOption=function() optionCalls=optionCalls+1;return false end},game_actionbar={getActiveBottomBars=function() return bars end}}
for _,height in ipairs({300,390,600,844}) do
 for _,count in ipairs({0,1,2,3}) do
  bars=count
  gameRootPanel=widget(height,height>500 and 278 or 602);gameBottomPanel=widget();gameBottomStatsBarPanel=widget(0);bottomSplitter=widget()
  gameMapPanel=widget(height-130,300)
  updateStretchShrink()
  assert(gameMapPanel.keep==false)
  assert(gameMapPanel.dim.width>=3 and gameMapPanel.dim.width<=17 and gameMapPanel.dim.width%2==1)
  assert(gameMapPanel.dim.height>=3 and gameMapPanel.dim.height<=13 and gameMapPanel.dim.height%2==1)
  assert(not gameBottomPanel.draggable)
  assert(not bottomSplitter.enabled)
  assert(bottomSplitter.margin==math.max(42,35*count+2))
  assert(bottomSplitter.margin>=35*count) -- varias barras tambem cabem
  if height>=300 then assert(height-bottomSplitter.margin>=100) end
  assert(gameBottomPanel.visible==false)
  local before=bottomSplitter.margin
  updateStretchShrink();assert(before==bottomSplitter.margin)
 end
end
assert(optionCalls==0)
-- Um modo estendido salvo também é convertido em acoplado.
addEvent=function(fn) fn() end
currentViewMode=1
setupViewMode(2)
assert(currentViewMode==1)
-- Desktop continua respeitando as opções originais.
mobile=false
updateStretchShrink()
assert(optionCalls==1)
-- Mais alto ou mais largo: conserva quadrados sem impor 15x11 esticado.
mobile=true
for _,size in ipairs({{150,650},{500,220},{800,250},{300,600}}) do
 gameMapPanel=widget(size[2],size[1])
 updateStretchShrink()
 local d=gameMapPanel.dim
 assert(gameMapPanel.keep==false and d.width%2==1 and d.height%2==1)
 local before=gameMapPanel.dim
 updateStretchShrink()
 assert(before==gameMapPanel.dim)
end
''')
# Syntax-check the actual console module without evaluating unrelated initializers.
lua.compile((fonte/'modules/game_console/console.lua').read_text())
console=(fonte/'modules/game_console/console.lua').read_text()
start=console.index('function extendedViewDraggable(bool)')
end=console.index('\nend',start)+4
lua.execute(console[start:end])
lua.execute('''
mobile=true
gameBottomPanel=widget()
extendedViewDraggable(false);assert(not gameBottomPanel.draggable)
extendedViewDraggable(true);assert(not gameBottomPanel.draggable)
mobile=false
extendedViewDraggable(false);assert(gameBottomPanel.draggable)
extendedViewDraggable(true);assert(not gameBottomPanel.draggable)
''')
print('OK: Lua real do layout, chat fixo, alturas, hotbars, rotação, modo salvo e desktop preservado')
