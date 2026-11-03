-- Nocthold - diagnóstico de carga y herramientas de prueba.
-- Canary Revscriptsys. Comando restringido al grupo GOD.
-- No crea monstruos, no modifica storages ni la base de datos. Solo teletransporta al propio
-- GOD con "/nocthold mapa <nombre>" (a la entrada de un mapa generado con tools/mapas).
-- "golpe" solo cambia una tabla en memoria (ver scripts/nocthold/test_damage.lua).

local noctholdStatus = TalkAction("/nocthold")

function noctholdStatus.onSay(player, words, param)
	local trimmed = (param or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local command, argument = trimmed:match("^(%S*)%s*(.-)$")
	command = command:lower()

	if command == "" or command == "help" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nocthold " .. Nocthold.version .. " | /nocthold status | /nocthold spells | /nocthold golpe [jugador] | /nocthold mapa [nombre] | /nocthold help. Jugadores: !nocthold help")
		return true
	end

	if command == "status" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.statusText() .. " Estado: bootstrap de desarrollo.")
		return true
	end

	if command == "spells" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Guardian (knight): bash, fortress, last stand, roar, sunder, sweep, bulwark, intercept, groundbreaker, oath.")
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Warden (druid): mend, roots, purify, bloom, barkskin, thorn, grasp, spirit bloom, lifebloom, rebirth.")
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Arcanist (sorcerer): bolt, frost, prism, nova, meteor, frost armor, surge, ward, shatter, chain.")
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Se lanzan con 'nocthold <palabra>', por ejemplo: nocthold bash.")
		return true
	end

	if command == "golpe" then
		local target = argument ~= "" and Player(argument) or player
		if not target then
			player:sendCancelMessage("No hay ningún jugador conectado con ese nombre.")
			return true
		end
		local guid = target:getGuid()
		local active = not Nocthold.testDamage[guid]
		Nocthold.testDamage[guid] = active or nil
		local state = active and "ACTIVADO: mata de un golpe a los monstruos de Nocthold y a los jefes les quita un 25 %." or "DESACTIVADO."
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.latin1("Golpe de prueba para " .. target:getName() .. " " .. state))
		if target:getGuid() ~= player:getGuid() then
			target:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.latin1("Golpe de prueba " .. state))
		end
		return true
	end

	if command == "mapa" then
		local mapas = Nocthold.mapas or {}
		local names = {}
		for name in pairs(mapas) do
			names[#names + 1] = name
		end
		table.sort(names)
		local mapa = mapas[argument:lower()]
		if not mapa then
			local list = #names > 0 and table.concat(names, ", ") or "ninguno"
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Mapas generados: " .. list .. ". Usa /nocthold mapa <nombre> para ir a su entrada.")
			return true
		end
		local p = mapa.puntos.entrada
		local destination = Position(p[1], p[2], p[3])
		if not Tile(destination) then
			player:sendCancelMessage(Nocthold.latin1("Ese mapa no está cargado en este servidor (¿arranca con DATA_PACK=data-nocthold?)."))
			return true
		end
		player:teleportTo(destination)
		destination:sendMagicEffect(CONST_ME_TELEPORT)
		local points = {}
		for point, q in pairs(mapa.puntos) do
			points[#points + 1] = point .. " (" .. q[1] .. "," .. q[2] .. "," .. q[3] .. ")"
		end
		table.sort(points)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Mapa " .. argument:lower() .. ". Puntos: " .. table.concat(points, ", "))
		return true
	end

	player:sendCancelMessage("Comando desconocido. Usa /nocthold help.")
	return true
end

noctholdStatus:separator(" ")
noctholdStatus:groupType("god")
noctholdStatus:register()
