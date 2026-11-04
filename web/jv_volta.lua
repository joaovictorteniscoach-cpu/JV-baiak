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

local function marcarCaixasPadrao()
    if g_settings.getBoolean('jvLoginPadraoFeito') then return end
    local janela = rootWidget:recursiveGetChildById('enterGame')
    if not janela then return end
    for _, id in ipairs({'rememberEmailBox', 'autoLoginBox'}) do
        local caixa = janela:getChildById(id)
        if caixa then pcall(function() caixa:setChecked(true) end) end
    end
    g_settings.set('jvLoginPadraoFeito', true)
end

local function entrarNoPersonagem()
    if not deveVoltar() or g_game.isOnline() then return end
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
    if not deveVoltar() or g_game.isOnline() then return end
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
            g_game[f] = function(...) esquecer(); return original(...) end
        end
    end
    connect(g_game, { onGameStart = function()
        marcarOnline()
        if V.evento then removeEvent(V.evento) end
        V.evento = cycleEvent(marcarOnline, 10000)
    end, onGameEnd = function()
        if V.evento then removeEvent(V.evento) end
        V.evento = nil
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
    scheduleEvent(entrarNaConta, 2500)
end
