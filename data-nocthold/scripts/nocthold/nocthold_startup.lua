-- Nocthold: al arrancar, deja en el log qué se ha cargado.
-- La comprobación automática (GitHub Actions) busca la línea "[NOCTHOLD] OK".

local noctholdStartup = GlobalEvent("NoctholdStartup")

function noctholdStartup.onStartup()
	local monsters, missing = Nocthold.countMonsters()
	local ok = monsters == #Nocthold.monsters and #Nocthold.npcs == Nocthold.expectedNpcs
	if ok then
		logger.info("[NOCTHOLD] OK " .. Nocthold.statusText())
	else
		logger.error("[NOCTHOLD] INCOMPLETO " .. Nocthold.statusText())
		if #missing > 0 then
			logger.error("[NOCTHOLD] Monstruos que faltan: " .. table.concat(missing, ", "))
		end
	end
	return true
end

noctholdStartup:register()
