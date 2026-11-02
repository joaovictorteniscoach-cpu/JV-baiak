"""Executa a acao real de HUD Scale, incluindo a aplicacao atrasada das opcoes."""
from pathlib import Path
import sys
from lupa import LuaRuntime
s=(Path(sys.argv[1])/'modules/client_options/data_options.lua').read_text()
a=s.index('    hudScale ');b=s.index('    creatureInformationScale ',a)
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
mobile=true;online=false;last=0
scheduleEvent=function(fn)pending=fn;return 1 end
removeEvent=function()end
g_platform={isMobile=function()return mobile end}
g_game={isOnline=function()return online end}
g_app={setHUDScale=function(value)last=value end}
label={setText=function(_,text)caption=text end}
panels={interfaceHUD={recursiveGetChildById=function()return label end}}
''')
lua.globals().options=lua.execute('return {\n'+s[a:b]+'\n}')
lua.execute('''
for _,value in ipairs({0,2,4,6})do
 mobile=true;online=false;options.hudScale.action(value,options,nil,panels,nil);pending();assert(last==1)
 online=true;options.hudScale.action(value,options,nil,panels,nil);pending();assert(last==1.4)
 -- Entrar no mundo enquanto a aplicacao de preferencias esta enfileirada.
 online=false;options.hudScale.action(value,options,nil,panels,nil);online=true;pending();assert(last==1.4)
 mobile=false;options.hudScale.action(value,options,nil,panels,nil);pending();assert(last==math.max(value/2+.5,1))
end
''')
print('OK: HUD 1 no login, 1.4 no jogo, atraso de preferencias e desktop preservado')
