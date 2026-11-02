-- Nocthold: datos comunes del datapack (se carga antes que scripts, monstruos y NPC).
-- Sirve para que el aviso de arranque y /nocthold status digan qué se ha cargado de verdad.

Nocthold = Nocthold or {}
Nocthold.version = "0.2.0"

-- Los siete monstruos de monster/nocthold/ (nombre exacto de Game.createMonsterType).
Nocthold.monsters = {
	"Carroñero de Escoria",
	"Sabueso de Ceniza",
	"Acólito de la Forja",
	"Coloso de Brasa",
	"El Guardián de Hierro",
	"La Maestra de Fundición Carmesí",
	"El Corazón de la Forja",
}

-- Los cinco NPC de npc/nocthold_npcs.lua. Cada uno se apunta al registrarse.
Nocthold.expectedNpcs = 5
Nocthold.npcs = {}

function Nocthold.registerNpc(name)
	table.insert(Nocthold.npcs, name)
end

function Nocthold.countMonsters()
	local loaded = 0
	local missing = {}
	for _, name in ipairs(Nocthold.monsters) do
		if MonsterType(name) then
			loaded = loaded + 1
		else
			table.insert(missing, name)
		end
	end
	return loaded, missing
end

function Nocthold.statusText()
	local monsters = Nocthold.countMonsters()
	return string.format(
		"Contenido propio %s cargado: %d/%d monstruos, %d/%d NPC.",
		Nocthold.version,
		monsters,
		#Nocthold.monsters,
		#Nocthold.npcs,
		Nocthold.expectedNpcs
	)
end
