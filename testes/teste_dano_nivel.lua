dofile('testes/teste_progressao.lua')
local T=JV_TEST_PROGRESSAO;local p=T.player();local E=JV_EVOLUCAO
local monstro={isPlayer=function()return false end,isMonster=function()return true end,getMaster=function()return nil end}
local alvo=T.eventos.JVEvolucaoDefesa
local function hit(n,atacante,valor)
 p.nivel=n;p.dados[T.P.storage]=0
 return alvo.onHealthChange(p,atacante,valor,1,0,2,0)
end
assert(hit(100,monstro,1000)==1000)
assert(hit(463,monstro,1000)==1182)
assert(hit(1000,monstro,1000)==1450)
assert(hit(2100,monstro,1000)==2000 and hit(9000,monstro,1000)==2000)
assert(hit(1000,nil,1000)==1000 and hit(1000,T.player(),1000)==1000)
local summon={isPlayer=function()return false end,isMonster=function()return true end,getMaster=function()return T.player()end}
assert(hit(1000,summon,1000)==1000,'alterou dano de summon de jogador')
assert(hit(1000,monstro,-1000)==-1450)
p.nivel=1000;p.dados[T.P.storage]=4
assert(alvo.onHealthChange(p,monstro,1000,1,0,2,0)==145)
assert(alvo.onHealthChange(p,monstro,1000,COMBAT_HEALING,0,2,0)==1000)
assert(T.eventos.JVEvolucaoMana.onManaChange(p,monstro,1000,1,0,2,0)==145)
print('OK: dano por nivel individual, limite, PvP, summon, cura, vida e mana')
