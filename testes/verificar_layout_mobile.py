"""Executa o Lua real do layout com widgets mínimos; não substitui renderização no cliente."""
from pathlib import Path
import sys
from lupa import LuaRuntime

fonte=Path(sys.argv[1])
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((fonte/'modules/game_interface/gameinterface.lua').read_text())
lua.execute('''
function widget(h)
 local w={h=h or 0, margin=0,enabled=true,draggable=true}
 function w:getHeight() return self.h end
 function w:getMarginBottom() return self.margin end
 function w:setMarginBottom(n) self.margin=n end
 function w:setEnabled(n) self.enabled=n end
 function w:setDraggable(n) self.draggable=n end
 return w
end
mobile=true
optionCalls=0
g_platform={isMobile=function() return mobile end}
modules={client_options={getOption=function() optionCalls=optionCalls+1;return false end},game_actionbar={getActiveBottomBars=function() return bars end}}
for _,height in ipairs({300,390,600,844}) do
 for _,count in ipairs({0,1,2,3}) do
  bars=count
  gameRootPanel=widget(height);gameBottomPanel=widget();gameBottomStatsBarPanel=widget(0);bottomSplitter=widget()
  updateStretchShrink()
  assert(not gameBottomPanel.draggable)
  assert(not bottomSplitter.enabled)
  assert(bottomSplitter.margin==math.min(80+35*count,math.max(64,height-160)))
  assert(height-bottomSplitter.margin>=160)
  local before=bottomSplitter.margin
  updateStretchShrink();assert(before==bottomSplitter.margin)
 end
end
assert(optionCalls==0)
-- Um modo estendido salvo também é convertido em acoplado.
currentViewMode=1
setupViewMode(2)
assert(currentViewMode==1)
-- Desktop continua respeitando as opções originais.
mobile=false
updateStretchShrink()
assert(optionCalls==1)
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
