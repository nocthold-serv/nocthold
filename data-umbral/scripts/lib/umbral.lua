-- UMBRAL: datos comunes del datapack (se carga antes que scripts, monstruos y NPC).
-- Sirve para que el aviso de arranque y /umbral status digan qué se ha cargado de verdad.

Umbral = Umbral or {}
Umbral.version = "0.2.0"

-- Los siete monstruos de monster/umbral/ (nombre exacto de Game.createMonsterType).
Umbral.monsters = {
	"Carroñero de Escoria",
	"Sabueso de Ceniza",
	"Acólito de la Forja",
	"Coloso de Brasa",
	"El Guardián de Hierro",
	"La Maestra de Fundición Carmesí",
	"El Corazón de la Forja",
}

-- Los cinco NPC de npc/umbral_npcs.lua. Cada uno se apunta al registrarse.
Umbral.expectedNpcs = 5
Umbral.npcs = {}

function Umbral.registerNpc(name)
	table.insert(Umbral.npcs, name)
end

function Umbral.countMonsters()
	local loaded = 0
	local missing = {}
	for _, name in ipairs(Umbral.monsters) do
		if MonsterType(name) then
			loaded = loaded + 1
		else
			table.insert(missing, name)
		end
	end
	return loaded, missing
end

function Umbral.statusText()
	local monsters = Umbral.countMonsters()
	return string.format(
		"UMBRAL %s cargado: %d/%d monstruos, %d/%d NPC.",
		Umbral.version,
		monsters,
		#Umbral.monsters,
		#Umbral.npcs,
		Umbral.expectedNpcs
	)
end
