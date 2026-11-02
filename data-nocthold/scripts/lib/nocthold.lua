-- Nocthold: datos comunes del datapack (se carga antes que scripts, monstruos y NPC).
-- Sirve para que el aviso de arranque y /nocthold status digan qué se ha cargado de verdad.

Nocthold = Nocthold or {}
Nocthold.version = "1.0.0-alpha.1"

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

-- El cliente (OTClient y el oficial) lee los textos en Latin-1, no en UTF-8: sin esto
-- "Caída" sale como "CaÃ­da". Los .lua se escriben en UTF-8 normal y todo texto con
-- acentos o ñ que vaya al jugador (nombres, diálogos) pasa por Nocthold.latin1().
function Nocthold.latin1(text)
	return (text:gsub("[\xC2\xC3][\x80-\xBF]", function(pair)
		local first, second = pair:byte(1, 2)
		return string.char((first - 0xC0) * 64 + (second - 0x80))
	end):gsub("[\xC4-\xF4][\x80-\xBF]+", "?"))
end

-- Los cinco NPC de npc/nocthold_npcs.lua. Cada uno se apunta al registrarse.
Nocthold.expectedNpcs = 5
Nocthold.npcs = {}

function Nocthold.registerNpc(name)
	table.insert(Nocthold.npcs, name)
end

-- Los 30 hechizos de scripts/nocthold/spells/. Cada uno se apunta al registrarse.
Nocthold.expectedSpells = 30
Nocthold.spells = {}

function Nocthold.registerSpell(name)
	table.insert(Nocthold.spells, name)
end

function Nocthold.countMonsters()
	local loaded = 0
	local missing = {}
	for _, name in ipairs(Nocthold.monsters) do
		if MonsterType(Nocthold.latin1(name)) then
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
		"Contenido propio %s cargado: %d/%d monstruos, %d/%d NPC, %d/%d hechizos.",
		Nocthold.version,
		monsters,
		#Nocthold.monsters,
		#Nocthold.npcs,
		Nocthold.expectedNpcs,
		#Nocthold.spells,
		Nocthold.expectedSpells
	)
end
