-- Nocthold - diagnóstico de carga.
-- Canary Revscriptsys. Comando de solo lectura restringido al grupo GOD.
-- No crea monstruos, no teletransporta, no modifica storages ni la base de datos.

local noctholdStatus = TalkAction("/nocthold")

function noctholdStatus.onSay(player, words, param)
	local command = (param or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	if command == "" or command == "help" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Nocthold " .. Nocthold.version .. " | Comandos: /nocthold status | /nocthold help")
		return true
	end

	if command == "status" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.statusText() .. " Estado: bootstrap de desarrollo.")
		return true
	end

	player:sendCancelMessage("Comando desconocido. Usa /nocthold help.")
	return true
end

noctholdStatus:separator(" ")
noctholdStatus:groupType("god")
noctholdStatus:register()
