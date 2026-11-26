-- Mantem personagens presentes quando a conexao foi suspensa pelo celular.
-- Sair manualmente, morte e reinicio do servidor continuam funcionando normalmente.
local manter=GlobalEvent('JVSemKickInatividade')
function manter.onThink()
    for _,player in ipairs(Game.getPlayers()) do
        if player.resetIdleTime then player:resetIdleTime() end
    end
    return true
end
manter:interval(30000)
manter:register()
