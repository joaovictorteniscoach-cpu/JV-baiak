-- Configuracao compartilhada: NPC, combate, hunts e testes usam os mesmos valores.
return {
    storage = 79500, storageAbates = 79600,
    multiplicadores = {2, 4, 7, 10},
    levels = {200, 400, 600, 800}, precos = {100000, 300000, 700000, 1500000},
    -- Intervalo dos ataques basicos em ms; as magias conservam seus cooldowns.
    intervalo = {320, 285, 250, 220}, movimento = {20, 40, 60, 80},
    addons = {0, 1, 2, 3}, cores = {76, 86, 94, 79},
    classes = {
        [1] = {outfits = {139, 131}, nomes = {'Cavaleiro Desperto', 'Guardiao de Ferro', 'Cavaleiro Abissal', 'Tita da Guerra'}},
        [2] = {outfits = {137, 129}, nomes = {'Atirador Desperto', 'Sentinela Real', 'Rastreador Astral', 'Executor Divino'}},
        [3] = {outfits = {138, 130}, nomes = {'Canalizador', 'Piromante', 'Arcanista', 'Arquimago'}},
        [4] = {outfits = {148, 144}, nomes = {'Naturalista', 'Guardiao das Raizes', 'Xama Ancestral', 'Avatar da Natureza'}},
    },
    -- Um rank a cada 50 abates nas hunts novas; no maximo +20% de dano PvE.
    abatesPorMaestria = 50, maxMaestria = 10, bonusMaestria = 0.02,
    reforco = {1.10, 1.20, 1.35, 1.50},
    itens = {
        2400, 2390, 2421, 8925, -- espadas, club e axe
        8851, 8854, 8922, 2183, -- distancia, wand e rod
        2472, 2471, 2495, 2522, 2646, -- armadura e raros classicos
    },
    -- Areas NOVAS, fora do mapa existente. Nunca substituir tiles ocupados.
    hub = {x=30000, y=30000, z=7},
    -- Entradas de hunts existentes auditadas no mapa fixado que tinham 0 ou 1
    -- criatura a ate 7 quadrados. Portais de retorno, cidades e bosses ficam de fora.
    entradasReforcadas = {
        {origem={462,1250,7}, destino={1124,1784,7}, monstro='Grim Reaper Evoluido'},
        {origem={462,1258,7}, destino={1930,1552,7}, monstro='Demon Evoluido'},
        {origem={471,1228,6}, destino={526,1242,8}, monstro='Bog Raider Evoluido'},
        {origem={471,1263,6}, destino={102,1572,7}, monstro='Demon Evoluido'},
        {origem={1403,1316,8}, destino={1268,1744,7}, monstro='Wyrm Evoluido'},
        {origem={1409,1322,8}, destino={1517,1329,8}, monstro='Destroyer Evoluido'},
        {origem={1413,1316,8}, destino={27,1835,7}, monstro='Frost Dragon Evoluido'},
        {origem={1421,1332,9}, destino={1039,1598,7}, monstro='Frost Dragon Evoluido'},
        {origem={1425,1286,7}, destino={816,1869,7}, monstro='Mutated Human Evoluido'},
        {origem={1427,1316,8}, destino={1001,781,7}, monstro='Warlock Evoluido'},
    },
    hunts = {
        {nome='Caverna Infernal', monstro='Demonio Ascendido', level=400, evo=1, tier=1, x=30100, y=30000, z=7, raio=12, quantidade=18, respawn=35, chance=0.005},
        {nome='Forja Abissal', monstro='Colosso Abissal', level=600, evo=2, tier=2, x=30200, y=30000, z=7, raio=13, quantidade=21, respawn=40, chance=0.008},
        {nome='Cripta Ancestral', monstro='Guardiao Ancestral', level=650, evo=2, tier=2, x=30300, y=30000, z=7, raio=15, quantidade=24, respawn=45, chance=0.01, dupla=true},
        {nome='Covil dos Titas', monstro='Tita Profanado', level=800, evo=3, tier=3, x=30400, y=30000, z=7, raio=16, quantidade=27, respawn=50, chance=0.012, dupla=true},
        {nome='Trono Infernal', monstro='Soberano Infernal', level=1000, evo=4, tier=4, x=30500, y=30000, z=7, raio=13, quantidade=1, respawn=300, chance=0.15, boss=true},
    },
}
