-- Nocthold: prueba automática dentro del servidor real (no con funciones simuladas).
-- Solo se activa con la variable NOCTHOLD_SELFTEST=1, que pone GitHub Actions. En el
-- servidor de pruebas y en producción este archivo no hace nada.
--
-- Qué comprueba, con el motor de Canary de verdad:
--   constantes usadas por los scripts, los 7 monstruos, los 30 hechizos (nombre y palabras),
--   que no queda ningún comando (!nocthold ni /nocthold), los mapas generados (tools/mapas)
--   casilla a casilla, la sala de La Forja Caída casilla a casilla, los 5 NPC, el portal del
--   templo, el altar, la barrera y el portal de salida, una piedra-llave de verdad,
--   y una expedición entera de llave 7 empezada desde el altar (6 fases, afijos, refuerzos de
--   jefe, muertes, la piedra sube a 8, portal final, salida y limpieza) con un jugador simulado.
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
	"CONST_ME_MAGIC_GREEN", "CONST_ME_SMALLPLANTS", "CONST_ME_TELEPORT", "CONST_PROP_BLOCKSOLID", "CONST_SLOT_FIRST", "CONST_SLOT_LAST",
	"FLAG_NOLIMIT", "ITEM_ATTRIBUTE_DESCRIPTION", "ITEM_ATTRIBUTE_NAME", "MESSAGE_EVENT_ADVANCE", "MESSAGE_FAREWELL",
	"MESSAGE_GREET", "MESSAGE_WALKAWAY", "TALKTYPE_MONSTER_SAY", "TALKTYPE_MONSTER_YELL",
	"TILESTATE_PROTECTIONZONE",
}

local U = NOCTHOLD_DUNGEON
local function arenaPos(dx, dy)
	return Position(U.origin.x + dx, U.origin.y + dy, U.origin.z)
end

-- Jugador simulado: solo lo usa el código Lua de la mazmorra, nunca entra en el mapa.
-- Lleva en la mochila (fake.key) una piedra-llave de verdad, creada en el suelo de la sala.
local fake = { guid = -4242, messages = {} }
local function newFake(position, guid)
	local f = { guid = guid or -4242, messages = {}, position = position }
	function f:getGuid() return self.guid end
	function f:getName() return "Probador CI" end
	function f:getPosition() return self.position end
	function f:getParty() return nil end
	function f:getGroup() return { getAccess = function() return false end } end
	function f:teleportTo(p) self.position = p return true end
	function f:addMoney(amount) self.money = (self.money or 0) + amount return true end
	function f:sendTextMessage(_, text) self.messages[#self.messages + 1] = text return true end
	function f:getSlotItem(slot) if slot == CONST_SLOT_FIRST then return self.key end return nil end
	return f
end
local function lastMessage() return fake.messages and fake.messages[#fake.messages] or "" end

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

	-- Comandos: ninguno. Todo va con objetos, NPC y portales.
	local talk = Game.getTalkActions()
	check(talk["!nocthold"] == nil, "el comando !nocthold debería haber desaparecido")
	check(talk["/nocthold"] == nil, "el comando /nocthold debería haber desaparecido")
	local wandType = ItemType(Nocthold.GOD_WAND)
	check(wandType:getId() == Nocthold.GOD_WAND and wandType:isPickupable(), "la vara de pruebas (" .. Nocthold.GOD_WAND .. ") no existe o no se puede coger")

	-- Objetos de la entrada: existen y son lo que creemos.
	local key = ItemType(U.ITEM_KEY)
	check(key and key:getId() == U.ITEM_KEY and key:isPickupable() and not key:isStackable(), "la piedra-llave (" .. U.ITEM_KEY .. ") debe poder cogerse y no apilarse")
	check(ItemType(U.ITEM_PORTAL):getId() == U.ITEM_PORTAL and not ItemType(U.ITEM_PORTAL):isMovable(), "el portal (" .. U.ITEM_PORTAL .. ") no existe o se puede mover")
	check(ItemType(U.ITEM_ALTAR):getId() == U.ITEM_ALTAR and not ItemType(U.ITEM_ALTAR):isMovable(), "el altar (" .. U.ITEM_ALTAR .. ") no existe o se puede mover")
end

local function checkGeneratedMaps()
	-- Mapas de data-nocthold/world/custom/ hechos con tools/mapas/generar_mapa.py. Canary los carga
	-- solo al arrancar; aquí se mira que cada casilla tiene lo que dice el plano, en el motor real.
	local mapas = Nocthold.mapas or {}
	local count = 0
	for name, mapa in pairs(mapas) do
		count = count + 1
		for point, p in pairs(mapa.puntos) do
			local wp = getWaypointPositionByName(name .. "." .. point)
			check(wp and wp.x == p[1] and wp.y == p[2] and wp.z == p[3], "mapa " .. name .. ": el punto '" .. point .. "' no está donde dice el plano")
		end
		local bad, floors, walls, first = 0, 0, 0, nil
		for _, c in ipairs(mapa.casillas) do
			local tile = Tile(Position(c[1], c[2], mapa.z))
			local ground = tile and tile:getGround()
			local problem
			if not ground then
				problem = "no hay casilla o no tiene suelo"
			elseif ground:getId() ~= c[3] then
				problem = "suelo " .. ground:getId() .. " en vez de " .. c[3]
			elseif c[4] ~= 0 and not tile:getItemById(c[4]) then
				problem = "falta el objeto " .. c[4]
			elseif (c[4] ~= 0) ~= tile:hasProperty(CONST_PROP_BLOCKSOLID) then
				problem = c[4] ~= 0 and "la pared no bloquea el paso" or "el suelo no se puede pisar"
			elseif c[5] ~= tile:hasFlag(TILESTATE_PROTECTIONZONE) then
				problem = c[5] and "debería ser zona protegida" or "no debería ser zona protegida"
			end
			if problem then
				bad = bad + 1
				first = first or (c[1] .. "," .. c[2] .. "," .. mapa.z .. ": " .. problem)
			elseif c[4] ~= 0 then
				walls = walls + 1
			else
				floors = floors + 1
			end
		end
		if check(bad == 0, "mapa " .. name .. ": " .. bad .. " casillas no coinciden con el plano (la primera, " .. tostring(first) .. ")") then
			check(floors == mapa.suelos and walls == mapa.paredes, "mapa " .. name .. ": cuenta de casillas distinta")
			logger.info("[NOCTHOLD-TEST] Mapa generado " .. name .. ": " .. floors .. " suelos y " .. walls .. " paredes, todo como en el plano")
		end
	end
	check(count > 0, "no hay mapas generados (falta data-nocthold/scripts/lib/nocthold_mapas.lua)")
end

local function hasAid(position, itemId, aid)
	local tile = Tile(position)
	local item = tile and tile:getItemById(itemId)
	return item ~= nil and item:getActionId() == aid
end

local function buildArena()
	-- dungeon_entrance.lua la prepara sola al arrancar con el suelo del templo.
	local town = Game.getTowns()[1]
	check(town ~= nil, "el mapa no tiene ciudades")
	local start = town:getTemplePosition()
	fake = newFake(start)
	local floorId = Tile(start):getGround():getId()
	check(U.mapReady and U.worldReady, "La Forja Caída no se preparó sola al arrancar")

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

	-- Portal del templo, altar, portal de salida y barrera.
	check(U.townPortal and hasAid(U.townPortal, U.ITEM_PORTAL, U.AID_TO_LOBBY), "no hay portal junto al templo")
	if U.townPortal then
		check(math.abs(U.townPortal.x - start.x) <= 4 and math.abs(U.townPortal.y - start.y) <= 4 and U.townPortal.z == start.z, "el portal está lejos del templo")
		check(not Tile(U.townPortal):hasProperty(CONST_PROP_BLOCKSOLID), "el portal del templo no se puede pisar")
	end
	check(hasAid(U.layoutPos("altar"), U.ITEM_ALTAR, U.AID_ALTAR), "no hay altar en la entrada")
	check(hasAid(U.layoutPos("exitPortal"), U.ITEM_PORTAL, U.AID_TO_TOWN), "no hay portal de salida en la entrada")
	check(not Tile(U.layoutPos("exitPortal")):hasProperty(CONST_PROP_BLOCKSOLID), "el portal de salida no se puede pisar")
	local b = U.layout.barrier
	for y = b[2], b[3] do
		local ground = Tile(arenaPos(b[1], y)):getGround()
		check(ground:getActionId() == U.AID_BARRIER, "la casilla " .. b[1] .. "," .. y .. " de la barrera no tiene su acción")
	end
	-- La barrera corta el paso: no hay otra fila de casillas entre la entrada y la mazmorra.
	check(Tile(arenaPos(b[1], b[2] - 1)) == nil or Tile(arenaPos(b[1], b[2] - 1)):getGround() == nil, "se puede rodear la barrera por arriba")
	check(Tile(arenaPos(b[1], b[3] + 1)) == nil or Tile(arenaPos(b[1], b[3] + 1)):getGround() == nil, "se puede rodear la barrera por abajo")

	local again = U.setupWorld()
	check(again == true, "preparar La Forja Caída una segunda vez no debería fallar")
	local portals = 0
	for _, item in ipairs(Tile(U.layoutPos("exitPortal")):getItems() or {}) do
		if item:getId() == U.ITEM_PORTAL then portals = portals + 1 end
	end
	check(portals == 1, "la segunda preparación duplicó objetos")

	-- Piedra-llave de verdad: nivel, nombre y acción.
	local key = Game.createItem(U.ITEM_KEY, 1, arenaPos(2, 20))
	if check(key ~= nil, "no se pudo crear la piedra-llave") then
		U.setKeyLevel(key, 7)
		check(U.keyLevel(key) == 7 and key:getActionId() == U.AID_KEY, "la piedra-llave no guarda su nivel")
		check(key:getName():find("piedra%-llave") ~= nil and key:getName():find("nivel 7") ~= nil, "nombre de la piedra-llave: " .. key:getName())
		fake.key = key
		check(#U.findKeys(fake) == 1, "no se encuentra la piedra-llave en el jugador")
	end

	-- Cada monstruo se puede crear en la sala (nombres con tilde incluidos), y el golpe de
	-- prueba (vara de pruebas del GOD) mata a los normales de un golpe y quita un 25 % a los 3 jefes.
	local tester = { isPlayer = function() return true end, getGuid = function() return fake.guid end }
	check(Nocthold.toggleTestDamage(fake, fake) == true, "la vara de pruebas no activa el golpe")
	local bosses = 0
	for _, name in ipairs(Nocthold.monsters) do
		local monster = Game.createMonster(Nocthold.latin1(name), arenaPos(70, 15), true, true)
		if check(monster ~= nil, "no se pudo crear " .. name .. " en la sala") then
			local maxHealth = monster:getMaxHealth()
			check(maxHealth > 0, name .. " tiene vida 0")
			local isBoss = monster:getType():isRewardBoss()
			if isBoss then bosses = bosses + 1 end
			local expected = isBoss and math.ceil(maxHealth * 0.25) or maxHealth
			check(Nocthold.testDamageFor(monster, tester) == expected, "golpe de prueba contra " .. name)
			monster:remove()
		end
	end
	check(Nocthold.toggleTestDamage(fake, fake) == false and not Nocthold.testDamage[fake.guid], "la vara de pruebas no quita el golpe")
	check(bosses == 3, "deberían ser 3 jefes, son " .. bosses)
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
	check(hasAid(U.layoutPos("finishPortal"), U.ITEM_PORTAL, U.AID_FINISH), "no apareció el portal de la última sala")
	-- El jugador simulado no está en Game.getPlayers(): se sube su piedra a mano, como haría upgradeKey.
	check(r.keyUpgradedTo == nil, "upgradeKey no debería encontrar a un jugador que no está conectado")
	if fake.key then
		U.setKeyLevel(U.findKeys(fake)[1], 8)
		check(U.keyLevel(fake.key) == 8, "la piedra-llave no sube de 7 a 8")
	end
	check(U.stepFinish(fake) == true and U.run == nil, "el portal final no liberó la sala")
	check(not hasAid(U.layoutPos("finishPortal"), U.ITEM_PORTAL, U.AID_FINISH), "el portal final no se quitó al vaciar la sala")
	local arrival = U.layoutPos("arrival")
	check(fake.position.x == arrival.x and fake.position.y == arrival.y, "el portal final no lleva a la entrada")

	-- Ningún monstruo de la expedición se queda en la sala.
	local leftovers = 0
	for _, creature in ipairs(Game.getSpectators(arenaPos(40, 15), false, false, 41, 41, 21, 21)) do
		if creature:isMonster() then leftovers = leftovers + 1 end
	end
	check(leftovers == 0, leftovers .. " monstruos se quedaron en la sala")

	-- Sin expedición nadie cruza la barrera; con una segunda en marcha, solo los suyos.
	local stranger = newFake(arenaPos(9, 15), -4343)
	check(not U.canPass(stranger) and not U.canPass(fake), "sin expedición la barrera debería cerrar el paso")
	check(U.useAltar(fake) == true, "el altar no empezó una segunda expedición: " .. lastMessage())
	check(U.run and U.run.keyLevel == 8, "la segunda expedición no usa la piedra de nivel 8")
	check(U.canPass(fake) and not U.canPass(stranger), "la barrera deja pasar a quien no debe")
	check(U.useAltar(stranger) == false, "el altar no debería dejar empezar otra expedición a la vez")
	U.reset(true)
	check(U.run == nil, "reset no liberó la sala")
	check(not U.canPass(fake), "tras reset la barrera debería volver a cerrar")
	if fake.key then fake.key:remove() end
	finish()
end

local function runDungeon()
	-- Desde el altar con la piedra de nivel 7 (activa los dos afijos alfa).
	local stranger = newFake(arenaPos(9, 15), -4343)
	check(U.useAltar(stranger) == false, "el altar no debería abrir sin piedra-llave")
	check(U.useAltar(fake) == true, "el altar no empezó la expedición: " .. lastMessage())
	local r = U.run
	if not check(r and r.stage == 1 and r.keyLevel == 7, "no empezó la fase 1 con llave 7") then return finish() end
	local s = U.layout.start[1]
	check(fake.position.x == arenaPos(s[1], s[2]).x, "el altar no llevó al líder dentro")
	check(r.remaining == 5, "fase 1 con llave 7 debería tener 5 enemigos (4 + afijo), tiene " .. tostring(r.remaining))
	addEvent(guarded("tick", tick), 1500)
end

local selftest = GlobalEvent("NoctholdSelftest")
function selftest.onStartup()
	logger.info("[NOCTHOLD-TEST] Empieza la prueba automática")
	addEvent(guarded("prueba", function()
		staticChecks()
		checkGeneratedMaps()
		buildArena()
		runDungeon()
	end), 3000)
	return true
end
selftest:register()
