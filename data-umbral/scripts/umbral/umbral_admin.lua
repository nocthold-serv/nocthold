-- UMBRAL - diagnóstico de carga.
-- Canary Revscriptsys. Comando de solo lectura restringido al grupo GOD.
-- No crea monstruos, no teletransporta, no modifica storages ni la base de datos.

local umbralStatus = TalkAction("/umbral")

function umbralStatus.onSay(player, words, param)
	local command = (param or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	if command == "" or command == "help" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "UMBRAL " .. Umbral.version .. " | Comandos: /umbral status | /umbral help")
		return true
	end

	if command == "status" then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, Umbral.statusText() .. " Estado: bootstrap de desarrollo.")
		return true
	end

	player:sendCancelMessage("Comando UMBRAL desconocido. Usa /umbral help.")
	return true
end

umbralStatus:separator(" ")
umbralStatus:groupType("god")
umbralStatus:register()
