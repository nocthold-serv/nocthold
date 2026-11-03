-- Nocthold - diagnóstico de carga y herramientas de prueba.
-- Canary Revscriptsys. Comando restringido al grupo GOD.
-- No crea monstruos, no teletransporta, no modifica storages ni la base de datos.
-- "golpe" solo cambia una tabla en memoria (ver scripts/nocthold/test_damage.lua).

local noctholdStatus = TalkAction("/nocthold")

function noctholdStatus.onSay(player, words, param)
	local trimmed = (param or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local command, argument = trimmed:match("^(%S*)%s*(.-)$")
	command = command:lower()

	if command == "" or command == "help" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nocthold " .. Nocthold.version .. " | /nocthold status | /nocthold spells | /nocthold golpe [jugador] | /nocthold help. Jugadores: !nocthold help")
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

	player:sendCancelMessage("Comando desconocido. Usa /nocthold help.")
	return true
end

noctholdStatus:separator(" ")
noctholdStatus:groupType("god")
noctholdStatus:register()
