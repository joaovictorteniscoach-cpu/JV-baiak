-- Gestos reais no modulo Lua com objetos do cliente simulados.
local agora,ataques,aberturas,usos,falas,originais,pausas,caminhadas=1000,0,0,0,0,0,0,0
MouseLeftButton,MouseRightButton,MouseTouch,MouseTouch2,MouseTouch3=1,2,3,4,5
KeyboardNoModifier=0
local p={getId=function()return 99 end,getPosition=function()return{x=10,y=10,z=7}end,
 autoWalk=function(_,destino)caminhadas=caminhadas+1;return true end}
g_clock={millis=function()return agora end};g_platform={isMobile=function()return true end}
g_keyboard={getModifiers=function()return 0 end};g_logger={info=function()end}
g_map={getSpectators=function()return{}end}
g_game={getLocalPlayer=function()return p end,getAttackingCreature=function()end,
 attack=function()ataques=ataques+1 end,open=function()aberturas=aberturas+1 end,
 use=function()usos=usos+1 end,talk=function()falas=falas+1 end,follow=function()end}
modules={game_interface={processMouseAction=function()originais=originais+1;return true end}}
JVAutoAtaque={andarManual=function()pausas=pausas+1 end}
function connect()end
function cycleEvent()return 1 end
function removeEvent()end
function doNothing()end
local monstro={getId=function()return 10 end,getName=function()return 'Demon' end,
 isNpc=function()return false end,isMonster=function()return true end,isPlayer=function()return false end}
local npc={getId=function()return 11 end,getName=function()return 'Guia' end,isNpc=function()return true end,
 getPosition=function()return{x=10,y=11,z=7}end}
local corpo={getId=function()return 99 end,getPosition=function()return{x=12,y=10,z=7}end,
 isContainer=function()return true end,isLyingCorpse=function()return true end,isUsable=function()return true end}
local alavanca={getId=function()return 1945 end,getPosition=function()return{x=13,y=10,z=7}end,
 isContainer=function()return false end,isUsable=function()return true end}
dofile('web/jv_npc.lua');JVNpc.iniciar();local tocar=modules.game_interface.processMouseAction
assert(tocar({},1,nil,nil,nil,monstro,nil));assert(ataques==0,'primeiro toque atacou')
agora=1300;assert(tocar({},1,nil,nil,nil,monstro,nil));assert(ataques==1,'segundo toque nao atacou')
agora=2000;assert(tocar({},1,nil,nil,nil,npc,nil));assert(falas==0,'primeiro toque falou')
agora=2300;assert(tocar({},1,nil,nil,nil,npc,nil));assert(falas==1,'segundo toque nao falou')
agora=3000;assert(tocar({},1,nil,nil,corpo,nil,nil));assert(aberturas==0,'primeiro toque abriu')
agora=3300;assert(tocar({},1,nil,nil,corpo,nil,nil));assert(aberturas==1,'segundo toque nao abriu')
agora=4000;assert(tocar({},1,nil,nil,alavanca,nil,nil));assert(usos==0)
agora=4300;assert(tocar({},1,nil,nil,alavanca,nil,nil));assert(usos==1,'segundo toque nao usou')
agora=5000;tocar({},1,{x=15,y=10,z=7},nil,nil,nil,nil);assert(pausas==1 and caminhadas==1 and originais==0,'andar foi bloqueado')
agora=5500;tocar({},1,{x=12,y=10,z=7},nil,corpo,nil,nil);assert(caminhadas==2 and aberturas==1,'primeiro toque no corpo nao caminhou')
agora=5700;tocar({},1,{x=12,y=10,z=7},nil,corpo,nil,nil);assert(aberturas==2 and caminhadas==2,'segundo toque nao abriu corpo')
local caminhosCampo=0
modules.jv_caminho={caminhar=function(_,destino)caminhosCampo=caminhosCampo+1;return true end}
agora=5800;tocar({},1,{x=16,y=10,z=7},nil,nil,nil,nil)
assert(caminhosCampo==1 and caminhadas==2,'toque ignorou o caminho que atravessa fogo e veneno')
modules.jv_caminho.caminhar=function()return false end
agora=5900;tocar({},1,{x=17,y=10,z=7},nil,nil,nil,nil)
assert(caminhadas==3,'caminho padrao nao retomou quando nao ha rota especial')
-- Ataque manual com autoataque desligado: o caminho nao deve disputar a perseguicao.
local modo=1;local mudancas=0
g_game.isAttacking=function()return true end
g_game.getChaseMode=function()return modo end
g_game.setChaseMode=function(v)modo=v;mudancas=mudancas+1 end
JVAutoAtaque={ligado=false,andarManual=function()end}
agora=5950;tocar({},1,{x=18,y=10,z=7},nil,nil,nil,nil)
assert(modo==0 and mudancas==1,'caminhada manual deixou perseguicao ligada')
agora=5970;tocar({},1,{x=19,y=10,z=7},nil,nil,nil,nil)
assert(mudancas==1,'reenviou modo de perseguicao sem necessidade')
g_platform.isMobile=function()return false end
agora=6000;tocar({},1,nil,nil,nil,monstro,nil);assert(originais==1 and ataques==1,'mudou clique PC')
print('OK: dois toques para atacar, falar, abrir e usar; caminhada e PC preservados')
