-- Familia por classe, atributos, requisitos, fragmentos, resgate e integracao real dos modulos.
dofile('testes/teste_progressao.lua')
local T=JV_TEST_PROGRESSAO
ITEM_ATTRIBUTE_NAME,ITEM_ATTRIBUTE_ARTICLE=20,21
ORIGIN_MELEE,ORIGIN_RANGED,ORIGIN_WAND,ORIGIN_SPELL=1,2,3,4
dofile('data/scripts/custom/jv_arsenal.lua')
local A=JV_ARSENAL
local C=dofile('data/lib/jv_arsenal.lua')
assert(C.evoStorage==T.P.storage)
local nomes,ids={},{}
for _,f in ipairs(C.familias)do
 local anterior=0
 for n=1,4 do
  local i=assert(A.criar(f.chave,n))
  assert(i:getId()==f.item and i.attrs[ITEM_ATTRIBUTE_NAME]==f.nomes[n])
  assert(not nomes[f.nomes[n]] and not ids[i:getCustomAttribute('jvarmaid')],'identidade duplicada')
  nomes[f.nomes[n]],ids[i:getCustomAttribute('jvarmaid')]=true,true
  assert(i.attrs[ITEM_ATTRIBUTE_ATTACK]>anterior);anterior=i.attrs[ITEM_ATTRIBUTE_ATTACK]
  if f.defesa then assert(i.attrs[ITEM_ATTRIBUTE_DEFENSE]==f.defesa[n])end
  local p=T.player(f.classe);p.dados[C.evoStorage]=n;p.nivel=C.levels[n]
  assert(A.podeUsar(p,i))
  p.nivel=C.levels[n]-1;assert(not A.podeUsar(p,i));p.nivel=C.levels[n]
  p.dados[C.evoStorage]=n-1;assert(not A.podeUsar(p,i));p.dados[C.evoStorage]=n
  p.classe=f.classe%4+1;assert(not A.podeUsar(p,i))
 end
end
local total=0;for _ in pairs(ids)do total=total+1 end;assert(total==28)
assert(ItemType(2400):getAttack()==48,'alterou item base')
assert(not A.criar('inexistente',1) and not A.criar('espada',4.5) and not A.criar('espada','x'))
print('OK: 28 identidades e nomes unicos, progressao crescente e requisitos das 4 classes')

local p=T.player(3);p.dados[C.evoStorage]=4;p.inventario[5]=A.criar('cetro',4)
assert(JV_EVOLUCAO.ataque(p,ORIGIN_WAND)==10,'duplicou bonus do ataque basico da wand')
assert(math.abs(JV_EVOLUCAO.ataque(p,ORIGIN_SPELL)-16.5)<0.0001)
p.inventario[6]=A.criar('cetro',2)
assert(math.abs(JV_EVOLUCAO.ataque(p,ORIGIN_SPELL)-16.5)<0.0001,'somou duas armas')
p.nivel=999;assert(JV_EVOLUCAO.ataque(p,ORIGIN_SPELL)==0,'level perdido continuou com bonus')
local monstro={isMonster=function()return true end}
assert(T.eventos.JVEvolucaoDano.onHealthChange(monstro,p,1000,1,0,2,ORIGIN_SPELL)==0)
local alvo=T.player(4)
assert(T.eventos.JVEvolucaoDefesa.onHealthChange(alvo,p,1000,1,0,2,ORIGIN_SPELL)==0)
assert(T.eventos.JVEvolucaoMana.onManaChange(alvo,p,1000,1,0,2,ORIGIN_SPELL)==0,'arma sem requisitos drenou mana pelo escudo')
assert(T.eventos.JVEvolucaoDefesa.onHealthChange(alvo,p,1000,COMBAT_HEALING,0,2,ORIGIN_SPELL)==1000,'bloqueou cura')
p.nivel=1000;p.inventario[6]=nil;p.classe=2;p.inventario[5]=A.criar('arco',4)
assert(math.abs(JV_EVOLUCAO.ataque(p,ORIGIN_RANGED)-16.5)<0.0001)
p.classe=1;p.inventario[5]=A.criar('espada',4)
assert(JV_EVOLUCAO.ataque(p,ORIGIN_MELEE)==10,'duplicou ataque nativo do knight')
print('OK: bonus por origem, perda de level, classe e nenhum bonus duplicado')

local function mochila()
 return{itens={},ret=RETURNVALUE_NOERROR,isContainer=function()return true end,
  addItemEx=function(s,i)if s.ret==0 then s.itens[#s.itens+1]=i end;s.ultimo=i;return s.ret end,
  getSize=function(s)return #s.itens end,getItem=function(s,i)return s.itens[i+1]end}
end
-- Loja: dinheiro misto, item correto, falhas e devolucao sem cobranca.
do
 local q=T.player(1);q.money=100000;q.banco=500000;q.inventario[10]=mochila()
 local ok=A.comprar(q,'espada',1)
 assert(ok and q.money==0 and q.banco==100000 and #q.inventario[10].itens==1)
 assert(q.inventario[10].itens[1]:getCustomAttribute('jvarmaid')=='espada:1')
 local saldo=q.banco;assert(not A.comprar(q,'espada',2) and q.banco==saldo)
 q.banco=1000000;q.inventario[10].ret=1
 assert(not A.comprar(q,'espada',1) and q.banco==1000000 and q.inventario[10].ultimo.removido)
 q.inventario[10].ret=0;q.money=100000;q.removeMoney=function()return false end
 assert(not A.comprar(q,'espada',1) and q.banco==1000000 and q.inventario[10].ultimo.removido)
 assert(not A.comprar(q,'inexistente',1) and not A.comprar(q,'espada',9))
end
print('OK: loja, pagamento misto, arma correta e falhas sem cobranca')
p=T.player(3);p.dados[C.evoStorage]=4;p.inventario[10]=mochila()
local k=C.fragmentosStorage+3;p.dados[k]=C.custos[4]
assert(not A.resgatar(p,'espada',4) and p.dados[k]==C.custos[4],'resgatou de outra classe')
p.nivel=999;assert(not A.resgatar(p,'cetro',4));p.nivel=1000
p.inventario[10].ret=1
assert(not A.resgatar(p,'cetro',4) and p.dados[k]==C.custos[4] and p.inventario[10].ultimo.removido)
p.inventario[10].ret=0
assert(A.resgatar(p,'cetro',4) and p.dados[k]==0 and #p.inventario[10].itens==1)
assert(not A.resgatar(p,'cetro',4) and #p.inventario[10].itens==1,'resgate duplicado')
p.dados[k]=C.custos[4];p.inventario[10]=nil
assert(not A.resgatar(p,'cetro',4) and p.dados[k]==C.custos[4])
p.inventario[10]=mochila()
local criar=Game.createItem;Game.createItem=function()end
assert(not A.resgatar(p,'cetro',4) and p.dados[k]==C.custos[4]);Game.createItem=criar
assert(not A.resgatar(p,'cetro',{}) and not A.resgatar(p,'cetro',-1))
A.catalogo(p);assert(p.dialogo:find('Cetro do Arquimago') and not p.dialogo:find('Espada do Tita'))
print('OK: resgate exato, sem duplicacao, mochila cheia, falha de criacao e catalogo por classe')

local hunt=T.P.hunts[5];local antes=p.dados[k]
A.creditar(p,hunt);assert(p.dados[k]==antes+1)
A.creditar(p,T.P.hunts[1]);assert(p.dados[C.fragmentosStorage]==1 and p.dados[k]==antes+1,'fragmento baixo virou IV')
p.nivel=299;A.creditar(p,T.P.hunts[1]);assert(p.dados[C.fragmentosStorage]==1);p.nivel=1000
local q=T.player(4);q.guid=2;q.dados[C.evoStorage]=4;q.localidade=p.localidade
p.party={getMembers=function()return{p,q}end,getLeader=function()return p end}
local morto={getName=function()return hunt.monstro end,getMaster=function()end,getPosition=function()return p.localidade end}
local random=math.random;math.random=function(a,b)return b or a end
local saldo=p.dados[k]
T.eventos.JVAscensaoMorte.onDeath(morto,nil,p,p)
assert(p.dados[k]==saldo+1 and q.dados[k]==1,'dupla nao recebeu ou lider duplicou')
q.localidade=Position(p.localidade.x+30,p.localidade.y,7)
T.eventos.JVAscensaoMorte.onDeath(morto,nil,p,p);assert(q.dados[k]==1,'personagem distante ganhou fragmento')
morto.getMaster=function()return p end
saldo=p.dados[k];T.eventos.JVAscensaoMorte.onDeath(morto,nil,p,p);assert(p.dados[k]==saldo,'farmou invocacao')
local drops=0;local corpse={addItem=function(s,id) drops=drops+1;return T.item(id)end}
assert(not A.sortear(corpse,hunt,5) and drops==0)
math.random=function(a,b)return 1 end
local item=A.sortear(corpse,hunt,5)
assert(drops==1 and item:getCustomAttribute('jvarmaid')=='espada:4')
local antigo=Game.createItem
Game.createItem=function()error('drop sem espaco criou item virtual fora do corpo')end
assert(not A.criar('cetro',4,{addItem=function()end}))
Game.createItem=antigo
math.random=random
print('OK: fragmentos por patamar, dupla, distancia, invocacoes e drop independente do rate global')

JV_PRECOS={[2183]=3000}
p=T.player(4);p.dados[C.evoStorage]=4;p.dados[79100]=2183;p.inventario[10]=mochila()
local raro=A.criar('bastao',4);local normal=T.item(2183)
p.inventario[10].itens={raro,normal}
T.comandos['!venderloot'].onSay(p,'!venderloot','')
assert(not raro.removido and normal.removido,'venda em lote vendeu nova arma')
print('OK: novas armas protegidas da venda em lote; loot normal preservado')

-- Demon e Juggernaut deixam as armas no corpo antes da coleta automatica.
local sorte=math.random;local quantidade=0;local ultimo
local corpo={addItem=function(_,id)quantidade=quantidade+1;ultimo=T.item(id);return ultimo end}
local atacante=T.player(1)
local criatura={getName=function()return 'Demon' end,getMaster=function()end}
math.random=function(a,b)return 1 end
T.eventos.JVArsenalClassico.onDeath(criatura,corpo,atacante,atacante)
assert(quantidade==1 and ultimo:getCustomAttribute('jvarmaid')=='espada:1')
criatura.getName=function()return 'Juggernaut' end
T.eventos.JVArsenalClassico.onDeath(criatura,corpo,atacante,atacante)
assert(quantidade==2 and ultimo:getCustomAttribute('jvarmaid')=='espada:2')
criatura.getMaster=function()return atacante end
T.eventos.JVArsenalClassico.onDeath(criatura,corpo,atacante,atacante)
criatura.getMaster=function()end;math.random=function(a,b)return b or a end
T.eventos.JVArsenalClassico.onDeath(criatura,corpo,atacante,atacante)
assert(quantidade==2,'invocacao ou sorteio perdido gerou drop')
math.random=sorte
print('OK: Demon e Juggernaut derrubam patamares corretos, sem farm de invocacao')

-- Mesmo com azar consecutivo, cada personagem recebe uma arma no limite.
local azar=math.random;math.random=function(a,b)return b or a end
local paciente=T.player(1);local n=0
local espaco={addItem=function(_,id)n=n+1;return T.item(id)end}
local piso={tier=1,andar=1,boss=false}
for i=1,19 do assert(not A.sortear(espaco,piso,1,paciente)) end
assert(n==0 and paciente:getStorageValue(79921)==19)
assert(A.sortear(espaco,piso,1,paciente) and n==1 and paciente:getStorageValue(79921)==0,'garantia de hunt falhou')
paciente:setStorageValue(79921,19)
assert(not A.sortear({addItem=function()end},piso,1,paciente) and paciente:getStorageValue(79921)==20,'garantia perdida por corpo cheio')
assert(A.sortear(espaco,piso,1,paciente) and paciente:getStorageValue(79921)==0,'garantia nao tentou novamente')
local guarda={tier=3,andar=4,boss=false,garantiaIndice=6}
paciente:setStorageValue(79926,19);paciente:setStorageValue(79925,3)
assert(A.sortear(espaco,guarda,4,paciente) and paciente:getStorageValue(79926)==0 and paciente:getStorageValue(79925)==3,'guardas interferiram na garantia do chefe')
local dem=T.player(1);criatura.getName=function()return 'Demon' end;criatura.getMaster=function()end
local antes=quantidade
for i=1,20 do T.eventos.JVArsenalClassico.onDeath(criatura,corpo,dem,dem) end
assert(quantidade==antes+1 and dem:getStorageValue(79931)==0,'garantia do Demon falhou')
math.random=azar
print('OK: garantia por personagem, azar, corpo cheio e Demon')

-- Dialogo da loja usa sessoes individuais, confirmacao e expira ao sair.
do
 local callbacks,respostas,compras={},{},{}
 local handler={}
 function handler:onCreatureAppear()end
 function handler:onCreatureDisappear()end
 function handler:onCreatureSay()end
 function handler:onThink()end
 function handler:isFocused()return true end
 function handler:say(t,cid)respostas[cid]=t end
 function handler:setMessage()end
 function handler:setCallback(k,v)callbacks[k]=v end
 function handler:addModule()end
 NpcHandler={new=function()return handler end};KeywordHandler={new=function()return{}end}
 FocusModule={new=function()return{}end};NpcSystem={parseParameters=function()end}
 MESSAGE_GREET,MESSAGE_FAREWELL,MESSAGE_WALKAWAY=1,2,3
 CALLBACK_MESSAGE_DEFAULT,CALLBACK_ONRELEASEFOCUS=4,5
 local jogadores={[101]=T.player(1),[102]=T.player(2)}
 local anterior=Player;Player=function(cid)return jogadores[cid]end
 local comprar=A.comprar;A.comprar=function(p,f,n)compras[#compras+1]={p,f,n};return true,'Entregue.' end
 assert(loadfile('servidor-imagem/extras/data/npc/scripts/jv_loja_arsenal.lua'))()
 local fala=callbacks[CALLBACK_MESSAGE_DEFAULT];local sair=callbacks[CALLBACK_ONRELEASEFOCUS]
 fala(101,1,'armas');assert(respostas[101]:find('{espada}',1,true))
 fala(101,1,'espada');fala(101,1,'patamar 2');assert(respostas[101]:find('2000000',1,true))
 fala(102,1,'sim');assert(#compras==0,'outro jogador confirmou compra')
 fala(101,1,'sim');assert(#compras==1 and compras[1][2]=='espada' and compras[1][3]==2)
 fala(101,1,'sim');assert(#compras==1,'compra repetida sem nova escolha')
 fala(102,1,'arco');fala(102,1,'patamar 1');sair(102);fala(102,1,'sim');assert(#compras==1,'compra apos sair')
 fala(102,1,'arco');fala(102,1,'patamar 1');fala(102,1,'nao');fala(102,1,'sim');assert(#compras==1,'compra apos cancelamento')
 A.comprar=comprar;Player=anterior
end
print('OK: dialogo da loja por jogador, confirmacao e cancelamento')
