-- Fluxo da venda real com mochilas/depot e itens protegidos simulados.
dofile('testes/teste_progressao.lua')
local T=JV_TEST_PROGRESSAO;local p=T.player(1);local cmd=T.comandos['!venderloot']
local function container(itens)
 return {itens=itens,getId=function()return 1988 end,getCustomAttribute=function()end,isContainer=function()return true end,getSize=function(s)return #s.itens end,
  getItem=function(s,i)return s.itens[i+1]end}
end
local comum=T.item(2183);local fora=T.item(2400);local raro=T.item(2183)
raro:setCustomAttribute('jvLootRaro',1)
local mochila=container({comum,fora,raro});p.inventario[10]=mochila
local noDepot=T.item(2183);local depot=container({container({noDepot})})
p.getTown=function()return{getId=function()return 1 end}end
p.getDepotChest=function(_,id,criar)assert(id==1 and criar==false);return depot end
JV_PRECOS={[2183]=3000,[2400]=10000}
cmd.onSay(p,'!venderloot','mochila')
assert(not comum.removido and not fora.removido and p.msg:find('Lista vazia'),'venda sem lista')
p.dados[79100]=2183
cmd.onSay(p,'!venderloot','mochila')
assert(comum.removido and not fora.removido and not raro.removido and p.banco==3000,'mochila/lista/raros')
p.dados[79005]=0
cmd.onSay(p,'!venderloot','depot')
assert(noDepot.removido and p.banco==6000 and not fora.removido,'depot ou bolsa aninhada')
p.dados[79005]=0
local mochila2=container({raro});p.inventario[10]=mochila2
cmd.onSay(p,'!venderloot','mochila raros')
assert(raro.removido and p.banco==9000,'escolha explicita de raro')
p.dados[79005]=0
local falha=T.item(2183);falha.remove=function()return false end;p.inventario[10]=container({falha})
cmd.onSay(p,'!venderloot','mochila')
assert(p.banco==9000 and not falha.removido,'creditou item que nao foi removido')
p.dados[79005]=0
local item1=T.item(2183);local item2=T.item(2400);local semPreco=T.item(9999);local protegido=T.item(2183)
protegido:setCustomAttribute('jvLootRaro',1)
p.inventario[10]=container({item1,container({item2,semPreco,protegido})})
cmd.onSay(p,'!venderloot','tudo mochila')
assert(item1.removido and item2.removido and not semPreco.removido and not protegido.removido and p.banco==22000,'venda geral, preco, raridade ou bolsas aninhadas')
p.dados[79005]=0
local depositoItem=T.item(2400);depot=container({container({depositoItem})})
cmd.onSay(p,'!venderloot','tudo depot')
assert(depositoItem.removido and p.banco==32000,'venda geral do depot')
p.dados[79005]=0
p.inventario[10]=container({protegido});p.dados[79100]=2183
cmd.onSay(p,'!venderloot','mochila raros')
assert(protegido.removido and p.banco==35000,'venda explicita de raro selecionado')
print('OK: venda geral e por lista, mochila/depot, raro opcional e sem credito em falha')
