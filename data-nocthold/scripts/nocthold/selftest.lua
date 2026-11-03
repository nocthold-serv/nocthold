-- Nocthold: prueba automática dentro del servidor real (no con funciones simuladas).
-- Solo se activa con la variable NOCTHOLD_SELFTEST=1, que pone GitHub Actions. En el
-- servidor de pruebas y en producción este archivo no hace nada.
--
-- Qué comprueba, con el motor de Canary de verdad:
--   constantes usadas por los scripts, los 7 monstruos, los 30 hechizos (nombre y palabras),
--   los comandos /nocthold y !nocthold, la sala de buildmap casilla a casilla, los 5 NPC,
--   y una expedición entera de llave 7 (6 fases, afijos, refuerzos de jefe, muertes,
--   mejora de llave, salida y limpieza) con un jugador simulado.
-- Lo que NO puede probar sin un cliente conectado: lanzar los hechizos, hablar con los NPC
-- y las fases de los jefes por vida (Canary no "piensa" por monstruos sin jugadores cerca).
-- Eso lo cubren los tests de tests/lua y la prueba en el juego.

if os.getenv("NOCTHOLD_SELFTEST") ~= "1" then
	return
end

local fails, oks = 0, 0
local function check(ok, what)
	if ok then
		oks = oks + 1
	else
		fails = fails + 1
		logger.error("[NOCTHOLD-TEST] FALLO " .. what)
	end
	return ok
end

local function finish()
	if fails == 0 then
		logger.info("[NOCTHOLD-TEST] TODO OK (" .. oks .. " comprobaciones)")
	else
		logger.error("[NOCTHOLD-TEST] FALLIDO: " .. fails .. " fallos de " .. (oks + fails) .. " comprobaciones")
	end
end

local function guarded(name, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			check(false, name .. ": error de Lua: " .. tostring(err))
			finish()
		end
	end
end

-- Mantener al día: tests/lua/test_nocthold_datapack.lua comprueba que esta lista recoge
-- todas las constantes que usan los archivos de data-nocthold.
local constants = {
	"AREA_CIRCLE2X2", "CALLBACK_GREET", "CALLBACK_MESSAGE_DEFAULT", "COMBAT_EARTHDAMAGE", "COMBAT_ENERGYDAMAGE",
	"COMBAT_FIREDAMAGE", "COMBAT_FORMULA_LEVELMAGIC", "COMBAT_HEALING", "COMBAT_ICEDAMAGE",
	"COMBAT_PARAM_AGGRESSIVE", "COMBAT_PARAM_BLOCKARMOR", "COMBAT_PARAM_BLOCKSHIELD", "COMBAT_PARAM_DISPEL",
	"COMBAT_PARAM_EFFECT", "COMBAT_PARAM_TYPE", "COMBAT_PHYSICALDAMAGE", "CONDITION_ATTRIBUTES",
	"CONDITION_HASTE", "CONDITION_PARALYZE", "CONDITION_PARAM_HEALTHGAIN", "CONDITION_PARAM_HEALTHTICKS",
	"CONDITION_PARAM_SKILL_SHIELDPERCENT", "CONDITION_PARAM_SPEED", "CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT",
	"CONDITION_PARAM_TICKS", "CONDITION_REGENERATION", "CONST_ME_BLOCKHIT", "CONST_ME_ENERGYHIT",
	"CONST_ME_EXPLOSIONHIT", "CONST_ME_FIREAREA", "CONST_ME_GREEN_RINGS", "CONST_ME_GROUNDSHAKER",
	"CONST_ME_HITAREA", "CONST_ME_HOLYDAMAGE", "CONST_ME_ICEATTACK", "CONST_ME_MAGIC_BLUE",
	"CONST_ME_MAGIC_GREEN", "CONST_ME_SMALLPLANTS", "FLAG_NOLIMIT", "MESSAGE_EVENT_ADVANCE", "MESSAGE_FAREWELL",
	"MESSAGE_GREET", "MESSAGE_WALKAWAY", "TALKTYPE_MONSTER_SAY", "TALKTYPE_MONSTER_YELL",
}

local U = NOCTHOLD_DUNGEON
local function arenaPos(dx, dy)
	return Position(U.origin.x + dx, U.origin.y + dy, U.origin.z)
end

-- Jugador simulado: solo lo usa el código Lua de la mazmorra, nunca entra en el mapa.
local fake = { guid = -4242, messages = {} }
local function newFake(position)
	fake.position = position
	function fake:getGuid() return self.guid end
	function fake:getName() return "Probador CI" end
	function fake:getPosition() return self.position end
	function fake:getParty() return nil end
	function fake:teleportTo(p) return true end
	function fake:addMoney(amount) self.money = (self.money or 0) + amount return true end
	function fake:sendTextMessage(_, text) self.messages[#self.messages + 1] = text return true end
	return fake
end
local function lastMessage() return fake.messages[#fake.messages] or "" end

local function staticChecks()
	-- Constantes que los scripts usan y que deben existir en este Canary.
	for _, name in ipairs(constants) do
		check(rawget(_G, name) ~= nil, "la constante " .. name .. " no existe en Canary")
	end

	-- Registro del datapack (lo mismo que el aviso [NOCTHOLD] OK).
	local monsters, missing = Nocthold.countMonsters()
	check(monsters == #Nocthold.monsters, "monstruos cargados " .. monsters .. "/" .. #Nocthold.monsters .. " (faltan: " .. table.concat(missing, ", ") .. ")")
	check(#Nocthold.npcs == Nocthold.expectedNpcs, "NPC registrados " .. #Nocthold.npcs .. "/" .. Nocthold.expectedNpcs)
	check(#Nocthold.spells == Nocthold.expectedSpells, "hechizos registrados " .. #Nocthold.spells .. "/" .. Nocthold.expectedSpells)

	-- Hechizos: Canary los tiene de verdad, con palabras "nocthold ..." únicas que llevan al mismo hechizo.
	local seenWords = {}
	for _, name in ipairs(Nocthold.spells) do
		local spell = Spell(name)
		if check(spell ~= nil, "Canary no conoce el hechizo " .. name) then
			local words = spell:words()
			check(type(words) == "string" and words:sub(1, 9) == "nocthold ", "palabras del hechizo " .. name .. ": " .. tostring(words))
			check(not seenWords[words or ""], "palabras repetidas: " .. tostring(words))
			seenWords[words or ""] = true
			local byWords = words and Spell(words)
			check(byWords ~= nil and byWords:name() == name, "las palabras '" .. tostring(words) .. "' no llevan a " .. name)
		end
	end

	-- Comandos.
	local talk = Game.getTalkActions()
	check(talk["!nocthold"] ~= nil, "el comando !nocthold no está registrado")
	check(talk["/nocthold"] ~= nil, "el comando /nocthold no está registrado")
end

local function buildArena()
	local town = Game.getTowns()[1]
	check(town ~= nil, "el mapa no tiene ciudades")
	local start = town:getTemplePosition()
	newFake(start)
	check(Tile(start) and Tile(start):getGround(), "no hay suelo en el templo " .. start.x .. "," .. start.y .. "," .. start.z)
	local floorId = Tile(start):getGround():getId()

	check(U.buildMap(fake) == true, "buildmap falló: " .. lastMessage())
	local total, withFloor = 0, 0
	for _, r in ipairs(U.rects()) do
		for x = r[1], r[3] do
			for y = r[2], r[4] do
				total = total + 1
				local tile = Tile(arenaPos(x, y))
				if tile and tile:getGround() and tile:getGround():getId() == floorId then
					withFloor = withFloor + 1
				end
			end
		end
	end
	check(total > 0 and withFloor == total, "casillas con suelo " .. withFloor .. "/" .. total)

	local npcs = {}
	for _, creature in ipairs(Game.getSpectators(arenaPos(5, 15), false, false, 8, 8, 8, 8)) do
		if creature:isNpc() then npcs[creature:getName()] = true end
	end
	for _, name in ipairs(Nocthold.npcs) do
		check(npcs[Nocthold.latin1(name)] or npcs[name], "el NPC " .. name .. " no aparece en la entrada")
	end

	check(U.buildMap(fake) == true and U.mapReady, "un segundo buildmap no debería fallar")

	-- Cada monstruo se puede crear en la sala (nombres con tilde incluidos).
	for _, name in ipairs(Nocthold.monsters) do
		local monster = Game.createMonster(Nocthold.latin1(name), arenaPos(70, 15), true, true)
		if check(monster ~= nil, "no se pudo crear " .. name .. " en la sala") then
			check(monster:getMaxHealth() > 0, name .. " tiene vida 0")
			monster:remove()
		end
	end
end

local function killTracked()
	local killed = 0
	for id in pairs(U.tracked) do
		local creature = Creature(id)
		if creature then
			creature:addHealth(-creature:getHealth(), COMBAT_PHYSICALDAMAGE)
			killed = killed + 1
		end
	end
	return killed
end

local runChecks
local ticks = 0
local seenStages = {}
local bossAddsTested = {}
local function tick()
	ticks = ticks + 1
	local r = U.run
	if not check(r ~= nil, "la expedición desapareció a medias (fase " .. tostring(next(seenStages)) .. ")") then
		return finish()
	end
	if r.completed then
		return runChecks()
	end
	if ticks > 60 then
		check(false, "la expedición no terminó en 90 s; última fase " .. tostring(r.stage) .. " con " .. tostring(r.remaining) .. " enemigos")
		return finish()
	end
	seenStages[r.stage] = true
	-- En cada jefe, una invocación de refuerzo como las de sus fases (se suma a los pendientes).
	if r.remaining > 0 and not bossAddsTested[r.stage] and (r.stage == 2 or r.stage == 4 or r.stage == 6) then
		bossAddsTested[r.stage] = true
		local before = r.remaining
		local add = U.spawnBossAdd("Acólito de la Forja", arenaPos(60 + r.stage, 15))
		check(add ~= nil and r.remaining == before + 1, "el refuerzo del jefe de la fase " .. r.stage .. " no cuenta como pendiente")
	end
	if r.remaining > 0 then
		killTracked()
	end
	addEvent(guarded("tick", tick), 1500)
end

runChecks = function()
	local r = U.run
	for stage = 1, 6 do
		check(seenStages[stage], "la fase " .. stage .. " no llegó a empezar")
	end
	check(bossAddsTested[2] and bossAddsTested[4] and bossAddsTested[6], "no se probaron los refuerzos de los tres jefes")
	check(r.stageName == "Completada", "estado final: " .. tostring(r.stageName))
	check(not r.failed, "la expedición se marcó como fallida")
	check(U.nextKey[fake.guid] == 8, "la llave no subió de 7 a 8: " .. tostring(U.nextKey[fake.guid]))
	check(U.leave(fake) == true and U.run == nil, "salir al terminar no liberó la sala")

	-- Ningún monstruo de la expedición se queda en la sala.
	local leftovers = 0
	for _, creature in ipairs(Game.getSpectators(arenaPos(40, 15), false, false, 41, 41, 21, 21)) do
		if creature:isMonster() then leftovers = leftovers + 1 end
	end
	check(leftovers == 0, leftovers .. " monstruos se quedaron en la sala")

	-- Una segunda expedición arranca y reset la limpia.
	check(U.enter(fake) == true and U.start(fake) == true, "no se pudo empezar una segunda expedición: " .. lastMessage())
	U.reset(true)
	check(U.run == nil, "reset no liberó la sala")
	finish()
end

local function runDungeon()
	U.nextKey[fake.guid] = 7 -- llave 7: activa los dos afijos alfa
	check(U.enter(fake) == true, "!nocthold enter falló: " .. lastMessage())
	check(U.start(fake) == true, "!nocthold start falló: " .. lastMessage())
	local r = U.run
	if not check(r and r.stage == 1, "no empezó la fase 1") then return finish() end
	check(r.remaining == 5, "fase 1 con llave 7 debería tener 5 enemigos (4 + afijo), tiene " .. tostring(r.remaining))
	addEvent(guarded("tick", tick), 1500)
end

local selftest = GlobalEvent("NoctholdSelftest")
function selftest.onStartup()
	logger.info("[NOCTHOLD-TEST] Empieza la prueba automática")
	addEvent(guarded("prueba", function()
		staticChecks()
		buildArena()
		runDungeon()
	end), 3000)
	return true
end
selftest:register()
