local config = {
	oldPosition = {
		[1] = Position(945, 1410, 8),
		[2] = Position(944, 1410, 8),
		[3] = Position(943, 1410, 8),
		[4] = Position(942, 1410, 8),
		[5] = Position(941, 1410, 8),
	},
	newPosition = {
		[1] = Position(943, 1429, 8),
		[2] = Position(942, 1429, 8),
		[3] = Position(941, 1429, 8),
		[4] = Position(940, 1429, 8),
		[5] = Position(939, 1429, 8),
	},
	monsterSpawn = {
		[1] = Position(940, 1426, 8),
		[2] = Position(942, 1426, 8),
		[3] = Position(944, 1426, 8),
		[4] = Position(939, 1432, 8),
		[5] = Position(941, 1432, 8),
		[6] = Position(943, 1432, 8),
		[7] = Position(944, 1429, 8),
		[8] = Position(945, 1429, 8),
	},
	monsterName = "Serpent Spawn",
	tempoCooldown = 4, -- Em horas
	storageTempo = 86475,
}

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
	
	if Game.getStorageValue(config.storageTempo) == -1 or not Game.getStorageValue(config.storageTempo) then
		Game.setStorageValue(config.storageTempo, 0)
	end

	if Game.getStorageValue(config.storageTempo) >= os.time() then
		player:sendCancelMessage("O seu time precisa esperar ".. string.diff((Game.getStorageValue(config.storageTempo) - os.time()), true) .. " para fazer essa quest.")
		player:getPosition():sendMagicEffect(CONST_ME_POFF)
		return true
	end

	if item.itemid == 1945 then
        -- Um jogador ja pode entrar sozinho; ate cinco podem usar as casas juntas.
        local players = {}
        for i, origem in ipairs(config.oldPosition) do
            local tile = Tile(origem)
            local participante = tile and tile:getTopCreature()
            if participante and participante:isPlayer() then
                local destino = config.newPosition[i]
                local alvo = Tile(destino)
                if not alvo or alvo:queryAdd(participante) ~= RETURNVALUE_NOERROR then
                    player:sendCancelMessage("A sala da quest esta ocupada. Tente novamente.")
                    return true
                end
                players[#players + 1] = {jogador=participante, origem=origem, destino=destino}
            end
        end
        if #players == 0 then
            player:sendCancelMessage("Pise em uma das casas de entrada para iniciar a quest.")
            return true
        end
        for _, entrada in ipairs(players) do
            entrada.origem:sendMagicEffect(CONST_ME_POFF)
            if not entrada.jogador:teleportTo(entrada.destino, false) then
                player:sendCancelMessage("Nao foi possivel entrar na sala. Tente novamente.")
                return true
            end
            entrada.jogador:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
        end

		for v, c in ipairs(config.monsterSpawn) do
			Game.createMonster(config.monsterName, c, false, true)
			Position(config.monsterSpawn[v]):sendMagicEffect(CONST_ME_TELEPORT)
		end

		Game.setStorageValue(config.storageTempo, os.time() + config.tempoCooldown * 60 * 60)
		item:transform(1946)
		addEvent(function()
			local spectator = Game.getSpectators(Position(942, 1429, 8), false, false, 0, 4, 0, 4)
			if #spectator > 0 then
				for a, b in ipairs(spectator) do
					local creature = Creature(b)
					if creature:isMonster() then
						creature:remove()
					end
				end
			end
			item:transform(1945)
		end, config.tempoCooldown * 60 * 60 * 1000)

	elseif item.itemid == 1946 then
		player:sendCancelMessage(RETURNVALUE_NOTPOSSIBLE)
		player:getPosition():sendMagicEffect(CONST_ME_POFF)
	end
	return true
end
