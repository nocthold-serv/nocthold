-- Nocthold - diagnóstico de carga.
-- Canary Revscriptsys. Comando de solo lectura restringido al grupo GOD.
-- No crea monstruos, no teletransporta, no modifica storages ni la base de datos.

local noctholdStatus = TalkAction("/nocthold")

function noctholdStatus.onSay(player, words, param)
	local command = (param or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	if command == "" or command == "help" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nocthold " .. Nocthold.version .. " | /nocthold status | /nocthold spells | /nocthold help. Jugadores: !nocthold help")
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

	player:sendCancelMessage("Comando desconocido. Usa /nocthold help.")
	return true
end

noctholdStatus:separator(" ")
noctholdStatus:groupType("god")
noctholdStatus:register()
