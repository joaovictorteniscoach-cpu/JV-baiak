dofile('testes/teste_progressao.lua')
local T=JV_TEST_PROGRESSAO
ITEM_ATTRIBUTE_NAME,ITEM_ATTRIBUTE_ARTICLE=20,21
local falhaCriar=false;local falhaItem=0;local bolsaAtual
local criarNoMapa=Game.createItem
Game.createItem=function(id,quantidade,pos)
 if pos then return criarNoMapa(id,quantidade,pos) end
 if falhaCriar then return nil end
 assert(id==1988)
 local bolsa={items={},removida=false}
 function bolsa:addItem(id)
  if #self.items+1==falhaItem then return nil end
  local i=T.item(id);self.items[#self.items+1]=i;return i
 end
 function bolsa:remove()self.removida=true end
 bolsaAtual=bolsa;return bolsa
end
local acao
function Action() acao={aid=function()end,register=function()end};return acao end
dofile('data/scripts/custom/jv_desafios.lua')
local D=JV_DESAFIOS
T.globais.JVDesafiosBaus.onStartup()
for i=1,3 do local pos=Position(30000+(i-2)*6,30014,7);local bau=Tile(pos):getItemById(5675);assert(bau and bau:getActionId()==48300+i) end
local p=T.player();p.nivel=600;p.dados[T.P.storage]=2
function p:addItemEx(item,drop)assert(drop==false);self.entrega=item;return self.cheio and 1 or 0 end
T.comandos['!desafios'].onSay(p,'!desafios','')
assert(p.dialogo:find('Groove Perdido') and p.dialogo:find('Dominio da Fumaca') and p.dialogo:find('resgatar'))
local q=D.quests[1]
for i=1,q.meta do D.abate(p,q.monstro) end
assert(p:getStorageValue(q.progresso)==q.meta)
D.abate(p,q.monstro);assert(p:getStorageValue(q.progresso)==q.meta)
assert(not D.resgatar(p,9))
p.cheio=true;assert(not D.resgatar(p,1) and bolsaAtual.removida and p:getStorageValue(q.resgatado)~=1)
p.cheio=false;falhaItem=2;assert(not D.resgatar(p,1) and bolsaAtual.removida and p:getStorageValue(q.resgatado)~=1)
falhaItem=0;falhaCriar=true;assert(not D.resgatar(p,1) and p:getStorageValue(q.resgatado)~=1)
falhaCriar=false;assert(D.resgatar(p,1) and p:getStorageValue(q.resgatado)==1)
assert(#p.entrega.items==2 and p.entrega.items[1].attrs[ITEM_ATTRIBUTE_ARMOR]==26 and p.entrega.items[2].attrs[ITEM_ATTRIBUTE_DEFENSE]==48)
assert(p.entrega.items[1]:getCustomAttribute('jvLootRaro')==1)
assert(not D.resgatar(p,1),'resgate duplicado')
p.nivel=1000;p.dados[T.P.storage]=4
for indice=2,3 do
 local quest=D.quests[indice];p.dados[quest.progresso]=quest.meta
 assert(D.resgatar(p,indice) and p:getStorageValue(quest.resgatado)==1)
 assert(#p.entrega.items==2 and p.entrega.items[1].attrs[ITEM_ATTRIBUTE_ARMOR]==quest.armadura.valor and p.entrega.items[2].attrs[ITEM_ATTRIBUTE_DEFENSE]==quest.escudo.valor)
 assert(not D.resgatar(p,indice),'resgate duplicado da quest '..indice)
end
assert(acao.onUse(p,{getActionId=function()return 48301 end},{x=29994,y=30014,z=7})==true)
assert(acao.onUse(p,{getActionId=function()return 48301 end},{x=1,y=1,z=7})==false)
local outro=T.player();outro.nivel=599;outro.dados[T.P.storage]=2
D.abate(outro,q.monstro);assert(outro:getStorageValue(q.progresso)==-1)
outro.nivel=600;outro.dados[T.P.storage]=1;D.abate(outro,q.monstro);assert(outro:getStorageValue(q.progresso)==-1)
outro.dados[T.P.storage]=2;D.abate(outro,'outro');assert(outro:getStorageValue(q.progresso)==-1)
assert(D.quests[2].progresso~=q.progresso and D.quests[3].resgatado~=q.resgatado)
local a,b=T.player(),T.player();a.guid=51;b.guid=52;a.nivel=1000;b.nivel=1000
 a.dados[T.P.storage]=4;b.dados[T.P.storage]=4;b.localidade=a.localidade
 a.party={getMembers=function()return{a,b}end,getLeader=function()return a end}
local terceiro=D.quests[3];JV_ASCENSAO.monstros[terceiro.monstro]={tier=4,chance=0,arsenalIndice=5}
local criatura={getName=function()return terceiro.monstro end,getMaster=function()end,getPosition=function()return a.localidade end}
T.eventos.JVAscensaoMorte.onDeath(criatura,nil,a,a)
assert(a:getStorageValue(terceiro.progresso)==1 and b:getStorageValue(terceiro.progresso)==1,'abate em dupla nao creditou os dois')
print('OK: desafios independentes, creditos, itens, mochila cheia e resgate unico')
