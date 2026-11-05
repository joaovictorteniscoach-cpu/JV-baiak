-- JV Baiak: VOLTAR DE OUTRO APP SEM FICAR PRESO (jogo no navegador, iPhone)
-- Quando voce sai para o WhatsApp, o iPhone congela a pagina e a conexao cai. A pagina
-- (shell.html) recarrega ao voltar; aqui o jogo entra de novo sozinho no mesmo
-- personagem, que continuou no jogo (o servidor segura o personagem enquanto voce
-- esta fora). So entra sozinho se voce nao tiver saido pelo botao Sair (logout).
-- No celular, "Lembrar conta" e "Entrar automaticamente" vem marcados na primeira vez.
JVVolta = JVVolta or {}
local V = JVVolta
local JANELA = 60 * 60 -- entra sozinho se esteve no jogo na ultima hora

local function modulo(nome)
    local m = modules.client_entergame
    return (m and m[nome]) or _G[nome]
end

local function marcarOnline()
    if not g_game.isOnline() then return end
    pcall(function() g_settings.set('jvVoltaNome', g_game.getCharacterName()) end)
    g_settings.set('jvVoltaAte', tostring(os.time()))
    pcall(g_settings.save)
end

local function esquecer()
    g_settings.set('jvVoltaAte', '0')
    pcall(g_settings.save)
end

local function deveVoltar()
    local ate = tonumber(g_settings.get('jvVoltaAte')) or 0
    return ate > 0 and os.time() - ate <= JANELA
end

-- No celular "Lembrar conta" e "Entrar automaticamente" ficam SEMPRE marcados: sem a senha
-- guardada, ao voltar de outro app o jogo nao consegue entrar sozinho (parecia que tinha saido).
local function marcarCaixasPadrao()
    local janela = rootWidget:recursiveGetChildById('enterGame')
    if not janela then return end
    for _, id in ipairs({'rememberEmailBox', 'autoLoginBox'}) do
        local caixa = janela:getChildById(id)
        if caixa and not caixa:isChecked() then pcall(function() caixa:setChecked(true) end) end
    end
    g_settings.set('jvLoginPadraoFeito', true)
end

local function entrarNoPersonagem()
    -- uma tentativa por carregamento da pagina: nunca fica entrando e saindo sozinho
    if V.tentouPersonagem or V.travado or not deveVoltar() or g_game.isOnline() then return end
    V.tentouPersonagem = true
    local nome = g_settings.get('jvVoltaNome')
    local lista = rootWidget:recursiveGetChildById('characters')
    if not lista or not nome or nome == '' then return end
    for _, item in ipairs(lista:getChildren()) do
        if item.characterName == nome then
            pcall(function() lista:focusChild(item, KeyboardFocusReason) end)
            local CL = modulo('CharacterList')
            if CL and CL.doLogin then CL.doLogin() end
            return
        end
    end
end

local function entrarNaConta()
    if V.tentouConta or V.travado or not deveVoltar() or g_game.isOnline() then return end
    V.tentouConta = true
    if g_settings.getBoolean('autologin') then return end -- o proprio jogo ja vai entrar
    local janela = rootWidget:recursiveGetChildById('enterGame')
    if not janela or not janela:isVisible() then return end
    local conta = janela:getChildById('accountNameTextEdit')
    local senha = janela:getChildById('accountPasswordTextEdit')
    local EG = modulo('EnterGame')
    if conta and senha and conta:getText() ~= '' and senha:getText() ~= '' and EG and EG.doLogin then
        EG.doLogin()
    end
end

function V.iniciar()
    if V.ligado or not (g_platform and g_platform.isMobile and g_platform.isMobile()) then return end
    V.ligado = true
    -- saiu pelo botao: nao volta sozinho
    for _, f in ipairs({'safeLogout', 'forceLogout', 'logout'}) do
        local original = g_game[f]
        if type(original) == 'function' then
            g_game[f] = function(...) esquecer(); V.saindo = true; return original(...) end
        end
    end
    connect(g_game, { onGameStart = function()
        marcarOnline()
        if V.evento then removeEvent(V.evento) end
        V.evento = cycleEvent(marcarOnline, 30000)
        -- 5 minutos no jogo sem cair: volta a reconectar sozinho normalmente
        if V.estavel then removeEvent(V.estavel) end
        V.estavel = scheduleEvent(function()
            V.quedas = {}
            if V.travado then
                V.travado = false
                g_settings.set('autoReconnect', true)
                pcall(g_settings.save)
            end
        end, 5 * 60 * 1000)
    end, onGameEnd = function()
        if V.evento then removeEvent(V.evento) end
        V.evento = nil
        if V.estavel then removeEvent(V.estavel) end
        V.estavel = nil
        g_logger.info('JV_GAME_END')
        if V.saindo then V.saindo = false; return end
        -- caiu sem apertar Sair: conta as quedas. 3 em 3 minutos = algo derrubando em
        -- seguida (o jogo aberto em outra aba/aparelho). Para de reconectar sozinho.
        local agora = os.time()
        local recentes = {}
        for _, t in ipairs(V.quedas or {}) do if agora - t <= 180 then recentes[#recentes + 1] = t end end
        recentes[#recentes + 1] = agora
        V.quedas = recentes
        if #recentes >= 3 and not V.travado then
            V.travado = true
            g_settings.set('autoReconnect', false)
            pcall(g_settings.save)
            g_logger.info('JV_RECONEXAO_PAUSADA')
            scheduleEvent(function()
                pcall(displayInfoBox, 'JV Baiak', 'O personagem caiu varias vezes seguidas.\n' ..
                    'Se o jogo estiver aberto em outra aba ou outro aparelho, feche la.\n' ..
                    'Depois toque no personagem e em Entrar.')
            end, 800)
        end
    end })
    local CL = modulo('CharacterList')
    if CL and CL.create then
        local criar = CL.create
        CL.create = function(...)
            local r = criar(...)
            scheduleEvent(entrarNoPersonagem, 300)
            return r
        end
    end
    scheduleEvent(marcarCaixasPadrao, 1500)
    -- a tela de entrar volta depois de sair ou cair: marca as caixas de novo
    connect(g_game, { onGameEnd = function() scheduleEvent(marcarCaixasPadrao, 1500) end })
    scheduleEvent(entrarNaConta, 2500)
end
