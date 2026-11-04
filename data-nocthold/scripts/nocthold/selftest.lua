-- Nocthold: prueba automática dentro del servidor real (no con funciones simuladas).
-- Solo se activa con la variable NOCTHOLD_SELFTEST=1, que pone GitHub Actions. En el
-- servidor de pruebas y en producción este archivo no hace nada.
--
-- Qué comprueba, con el motor de Canary de verdad:
--   constantes usadas por los scripts, los 7 monstruos, los 30 hechizos (nombre y palabras),
--   los comandos /nocthold y !nocthold, los mapas generados (tools/mapas) casilla a casilla y sus portales,
--   la sala de buildmap casilla a casilla, los 5 NPC, las zonas de aggro (grupos dormidos que
--   se despiertan enteros al entrar alguien en su zona o al recibir daño),
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
	"COMBAT_FIREDAMAGE", "COMBAT_FORMULA_LEVELMAGIC", "COMBAT_HEALING", "COMBAT_HOLYDAMAGE", "COMBAT_ICEDAMAGE",
	"COMBAT_PARAM_AGGRESSIVE", "COMBAT_PARAM_BLOCKARMOR", "COMBAT_PARAM_BLOCKSHIELD", "COMBAT_PARAM_DISPEL",
	"COMBAT_PARAM_EFFECT", "COMBAT_PARAM_TYPE", "COMBAT_PHYSICALDAMAGE", "CONDITION_ATTRIBUTES",
	"CONDITION_HASTE", "CONDITION_PARALYZE", "CONDITION_PARAM_HEALTHGAIN", "CONDITION_PARAM_HEALTHTICKS",
	"CONDITION_PARAM_SKILL_SHIELDPERCENT", "CONDITION_PARAM_SPEED", "CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT",
	"CONDITION_PARAM_TICKS", "CONDITION_REGENERATION", "CONST_ME_BLOCKHIT", "CONST_ME_ENERGYHIT",
	"CONST_ME_EXPLOSIONHIT", "CONST_ME_FIREAREA", "CONST_ME_GREEN_RINGS", "CONST_ME_GROUNDSHAKER",
	"CONST_ME_HITAREA", "CONST_ME_HOLYDAMAGE", "CONST_ME_ICEATTACK", "CONST_ME_MAGIC_BLUE",
	"CONST_ME_MAGIC_GREEN", "CONST_ME_SMALLPLANTS", "CONST_ME_TELEPORT", "CONST_PROP_BLOCKSOLID", "FLAG_NOLIMIT", "MESSAGE_EVENT_ADVANCE", "MESSAGE_FAREWELL",
	"MESSAGE_GREET", "MESSAGE_WALKAWAY", "TALKTYPE_MONSTER_SAY", "TALKTYPE_MONSTER_YELL",
	"TILESTATE_PROTECTIONZONE",
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

	-- Hechizos: Canary los tiene de verdad, con palabras únicas que llevan al mismo hechizo y un id
	-- propio (1001-1030) único: el enfriamiento va por id y el cliente busca el icono por ese id.
	local seenWords, seenIds = {}, {}
	for _, name in ipairs(Nocthold.spells) do
		local spell = Spell(name)
		if check(spell ~= nil, "Canary no conoce el hechizo " .. name) then
			local words = spell:words()
			check(type(words) == "string" and words ~= "" and not words:find("nocthold", 1, true), "palabras del hechizo " .. name .. ": " .. tostring(words))
			check(not seenWords[words or ""], "palabras repetidas: " .. tostring(words))
			seenWords[words or ""] = true
			local id = spell:id()
			check(type(id) == "number" and id >= 1001 and id <= 1030, "id del hechizo " .. name .. ": " .. tostring(id))
			check(not seenIds[id or 0], "id repetido: " .. tostring(id))
			seenIds[id or 0] = true
			local byWords = words and Spell(words)
			check(byWords ~= nil and byWords:name() == name, "las palabras '" .. tostring(words) .. "' no llevan a " .. name)
		end
	end

	-- Comandos.
	local talk = Game.getTalkActions()
	check(talk["!nocthold"] ~= nil, "el comando !nocthold no está registrado")
	check(talk["/nocthold"] ~= nil, "el comando /nocthold no está registrado")
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
		-- Portales del plano: campo mágico con su destino, o con el action id que lleva al templo.
		for _, p in ipairs(mapa.portales or {}) do
			local where = "mapa " .. name .. ": portal " .. p[1] .. "," .. p[2] .. "," .. p[3]
			local tile = Tile(Position(p[1], p[2], p[3]))
			local portal = tile and tile:getItemById(NOCTHOLD_MAPAS.ITEM_PORTAL)
			if check(portal ~= nil, where .. " no está") then
				if p.destino == "templo" then
					check(portal:getActionId() == NOCTHOLD_MAPAS.AID_TEMPLO, where .. ": no lleva el action id del templo")
				else
					-- Canary da a los teletransportes la clase Teleport, que tiene getDestination().
					local d = portal.getDestination and portal:getDestination()
					check(d and d.x == p.destino[1] and d.y == p.destino[2] and d.z == p.destino[3], where .. ": destino distinto del plano")
				end
			end
		end
		-- Portal del templo hacia la entrada del mapa (mapas_portales.lua).
		local fromTown
		for aid, portal in pairs(NOCTHOLD_MAPAS.portales) do
			if portal.nombre == name then
				local item = Tile(portal.desde) and Tile(portal.desde):getItemById(NOCTHOLD_MAPAS.ITEM_PORTAL)
				fromTown = item and item:getActionId() == aid
			end
		end
		check(fromTown, "mapa " .. name .. ": no hay portal junto al templo")
		if check(bad == 0, "mapa " .. name .. ": " .. bad .. " casillas no coinciden con el plano (la primera, " .. tostring(first) .. ")") then
			check(floors == mapa.suelos and walls == mapa.paredes, "mapa " .. name .. ": cuenta de casillas distinta")
			logger.info("[NOCTHOLD-TEST] Mapa generado " .. name .. ": " .. floors .. " suelos y " .. walls .. " paredes, todo como en el plano")
		end
	end
	check(count > 0, "no hay mapas generados (falta data-nocthold/scripts/lib/nocthold_mapas.lua)")
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

	-- Cada monstruo se puede crear en la sala (nombres con tilde incluidos), y el golpe de
	-- prueba (/nocthold golpe) mata a los normales de un golpe y quita un 25 % a los 3 jefes.
	local tester = { isPlayer = function() return true end, getGuid = function() return fake.guid end }
	Nocthold.testDamage[fake.guid] = true
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
	Nocthold.testDamage[fake.guid] = nil
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

-- Zonas de aggro (scripts/lib/nocthold_aggro.lua) con el motor de verdad: dos grupos dormidos
-- en la tercera sala de la arena (vacía hasta la fase 3 de la expedición). Un monstruo marcado
-- como "provocador" hace de jugador: se queda fuera, luego entra en la zona del grupo A, y al
-- grupo B se le hace daño desde fuera. Cada grupo debe despertarse entero y solo cuando toca.
local function checkAggro(siguiente)
	local A = Nocthold.aggro
	local function crear(nombre, dxs, dy)
		local lista = {}
		for _, dx in ipairs(dxs) do
			local m = Game.createMonster(Nocthold.latin1(nombre), arenaPos(dx, dy), false, true)
			if check(m ~= nil, "aggro: no se pudo crear " .. nombre .. " en " .. dx .. "," .. dy) then
				m:setDormant(true)
				lista[#lista + 1] = m
			end
		end
		return lista
	end
	local grupoA = crear("Sabueso de Ceniza", { 46, 47, 48 }, 10)
	local grupoB = crear("Carroñero de Escoria", { 46, 48 }, 20)
	check(A.crearGrupo("ci.a", grupoA, 2) ~= nil, "aggro: no se pudo crear el grupo A")
	check(A.crearGrupo("ci.b", grupoB, 2) ~= nil, "aggro: no se pudo crear el grupo B")
	local gA, gB = A.grupos["ci.a"], A.grupos["ci.b"]
	if not check(gA and gB, "aggro: faltan los grupos") then
		return siguiente()
	end
	-- Caja de los 3 Sabuesos (x 46-48, y 10) más 2 casillas: 7 x 5 = 35 casillas.
	check(#gA.zona:getPositions() == 35, "aggro: la zona del grupo A tiene " .. #gA.zona:getPositions() .. " casillas, deberían ser 35")

	local provocador = Game.createMonster(Nocthold.latin1("Carroñero de Escoria"), arenaPos(48, 15), false, true)
	if not check(provocador ~= nil, "aggro: no se pudo crear el provocador") then
		return siguiente()
	end
	A.provocadores[provocador:getId()] = true
	for _, m in ipairs(grupoA) do
		check(m:isDormant() == true, "aggro: un Sabueso del grupo A no está dormido")
		check(m:isTarget(provocador) == false, "aggro: un monstruo dormido puede elegir objetivo")
	end
	for _, m in ipairs(grupoB) do
		check(m:isDormant() == true, "aggro: un monstruo del grupo B no está dormido")
	end
	check(provocador:isTarget(grupoA[1]) == true, "aggro: control fallido, un monstruo despierto debería poder elegir objetivo")

	local function limpiar()
		A.provocadores[provocador:getId()] = nil
		provocador:remove()
		check(A.quitarGrupo("ci.a") and A.quitarGrupo("ci.b"), "aggro: no se pudieron quitar los grupos")
		check(next(A.porZona) == nil and next(A.grupos) == nil, "aggro: quedan grupos o zonas apuntados")
		local quedan = 0
		for _, c in ipairs(Game.getSpectators(arenaPos(48, 15), false, false, 8, 8, 8, 8)) do
			if c:isMonster() then
				quedan = quedan + 1
			end
		end
		check(quedan == 0, "aggro: " .. quedan .. " monstruos se quedaron en la tercera sala")
	end

	addEvent(guarded("aggro fuera", function()
		check(not gA.despierto and not gB.despierto, "aggro: un grupo se despertó sin que nadie entrara en su zona")
		provocador:teleportTo(arenaPos(47, 12)) -- borde de la zona A
		addEvent(guarded("aggro dentro", function()
			check(gA.despierto, "aggro: entrar en la zona no despertó al grupo A")
			local despiertos = 0
			for _, m in ipairs(grupoA) do
				if not m:isDormant() and m:isTarget(provocador) then
					despiertos = despiertos + 1
				end
			end
			check(despiertos == #grupoA, "aggro: solo " .. despiertos .. "/" .. #grupoA .. " del grupo A se despertaron")
			check(not gB.despierto, "aggro: entrar en la zona A despertó también al grupo B")

			doTargetCombatHealth(0, grupoB[1], COMBAT_HOLYDAMAGE, -50, -50, CONST_ME_HOLYDAMAGE)
			addEvent(guarded("aggro daño", function()
				check(gB.despierto, "aggro: hacer daño a uno del grupo B no despertó al grupo")
				for _, m in ipairs(grupoB) do
					check(not m:isDormant(), "aggro: un monstruo del grupo B sigue dormido tras el daño")
				end
				limpiar()
				logger.info("[NOCTHOLD-TEST] Zonas de aggro: grupo A despierto al entrar, grupo B al recibir daño, cada uno por separado")
				siguiente()
			end), 500)
		end), 1000)
	end), 1500)
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
		checkGeneratedMaps()
		buildArena()
		checkAggro(guarded("expedición", runDungeon))
	end), 3000)
	return true
end
selftest:register()
