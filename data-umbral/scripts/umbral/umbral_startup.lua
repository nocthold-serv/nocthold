-- UMBRAL: al arrancar, deja en el log qué se ha cargado.
-- La comprobación automática (GitHub Actions) busca la línea "[UMBRAL] OK".

local umbralStartup = GlobalEvent("UmbralStartup")

function umbralStartup.onStartup()
	local monsters, missing = Umbral.countMonsters()
	local ok = monsters == #Umbral.monsters and #Umbral.npcs == Umbral.expectedNpcs
	if ok then
		logger.info("[UMBRAL] OK " .. Umbral.statusText())
	else
		logger.error("[UMBRAL] INCOMPLETO " .. Umbral.statusText())
		if #missing > 0 then
			logger.error("[UMBRAL] Monstruos que faltan: " .. table.concat(missing, ", "))
		end
	end
	return true
end

umbralStartup:register()
