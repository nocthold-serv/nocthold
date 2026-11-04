-- Nocthold 1.0.0-alpha.1: La Forja Caida runtime encounter controller.
-- Canary 3.6.1 / Revscriptsys. One shared test arena; NOT isolated multi-party instances.
-- La sala se genera sola al arrancar y el jugador no usa comandos: portal junto al templo,
-- piedra-llave del Cronista, altar, barrera y portales de salida (ver dungeon_entrance.lua).

NOCTHOLD_DUNGEON = NOCTHOLD_DUNGEON or {}
local U = NOCTHOLD_DUNGEON
U.version = "1.0.0-alpha.1"
U.origin = Position(64000, 64000, 7)
U.mapReady = U.mapReady or false
U.run = U.run or nil
U.tracked = U.tracked or {}
U.token = U.token or 0

local function pos(dx, dy)
    return Position(U.origin.x + dx, U.origin.y + dy, U.origin.z)
end
U.pos = pos

-- Puntos de la sala (relativos a U.origin). La entrada (x 0-10) es la sala de los NPC.
U.layout = {
    arrival = {5, 16},            -- donde aparece quien llega por el portal del templo
    exitPortal = {0, 15},         -- portal de la entrada que lleva de vuelta al templo
    altar = {5, 10},              -- altar donde el lider usa su piedra-llave
    barrier = {12, 14, 16},       -- x, y desde, y hasta: solo pasan los de la expedicion
    start = { {14,15}, {15,15}, {16,15}, {14,14}, {14,16} }, -- donde empieza el grupo
    finishPortal = {79, 15},      -- portal que aparece en la ultima sala al terminar
}

function U.layoutPos(name)
    local p = U.layout[name]
    return pos(p[1], p[2])
end

-- Esta dentro de la sala generada (entrada incluida) o solo de la parte con monstruos.
function U.isInsideArena(position, dungeonOnly)
    if not position or position.z ~= U.origin.z then return false end
    local dx, dy = position.x - U.origin.x, position.y - U.origin.y
    return dx >= (dungeonOnly and U.layout.barrier[1] or 0) and dx <= 80 and dy >= 0 and dy <= 30
end

local function tell(player, message)
    if player then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.latin1("[Nocthold] " .. message))
    end
end

-- Player(guid) is not portable across Canary/TFS bindings (the constructor
-- usually resolves a runtime creature id). Resolve online players by database GUID.
local function onlinePlayerByGuid(guid, onlinePlayers)
    local players = onlinePlayers or Game.getPlayers()
    for _, candidate in ipairs(players) do
        if candidate:getGuid() == guid then return candidate end
    end
    return nil
end

function U.tellGroup(message)
    if not U.run then return end
    local onlinePlayers = Game.getPlayers()
    for guid in pairs(U.run.players) do
        tell(onlinePlayerByGuid(guid, onlinePlayers), message)
    end
end

local function rects()
    -- Entrance, three chambers and connecting corridors. Unfilled tiles are void.
    return {
        {0, 9, 10, 21},
        {10, 14, 20, 16},
        {20, 8, 32, 22},
        {32, 14, 42, 16},
        {42, 8, 54, 22},
        {54, 14, 64, 16},
        {64, 5, 80, 25},
    }
end

U.rects = rects -- funcion: la prueba automatica (selftest.lua) recorre las mismas casillas

-- Pone el suelo de la sala y los 5 NPC. Lo llama dungeon_entrance.lua al arrancar el
-- servidor con el suelo del templo. Devuelve true o false y un texto para el log.
function U.buildMap(floorId)
    if U.mapReady then
        return true, "La sala ya estaba construida."
    end
    if not floorId then
        return false, "No hay suelo que copiar."
    end
    local created, failed = 0, 0
    for _, r in ipairs(rects()) do
        for x = r[1], r[3] do
            for y = r[2], r[4] do
                local p = pos(x, y)
                local tile = Game.createTile(p, true)
                if not tile then
                    tile = Tile(p)
                end
                if tile then
                    if not tile:getGround() then
                        -- Canary rechaza cualquier objeto en una casilla sin suelo; FLAG_NOLIMIT salta esa comprobacion
                        tile:addItem(floorId, 1, FLAG_NOLIMIT)
                    end
                    if tile:getGround() then created = created + 1 else failed = failed + 1 end
                else
                    failed = failed + 1
                end
            end
        end
    end
    if failed > 0 then
        return false, "Sala incompleta: " .. created .. " casillas preparadas y " .. failed .. " fallos."
    end
    local npcSpawns = {
        {"Capitana Elira", 3, 12},
        {"Intendente Renn", 3, 15},
        {"Archivista Nima", 3, 18},
        {"Forjador Borun", 7, 12},
        {"Cronista de Llaves", 7, 18},
    }
    for _, data in ipairs(npcSpawns) do
        local npc = Game.createNpc(data[1], pos(data[2], data[3]), true, true)
        if not npc then
            return false, "No se pudo crear el NPC " .. data[1] .. ". Comprueba que su NpcType carga."
        end
    end
    U.mapReady = true
    return true, "La Forja Caida se ha generado: " .. created .. " casillas y cinco NPC (X=64000, Y=64000, Z=7)."
end

local function collectParty(player)
    local list = { player }
    local party = player:getParty()
    if not party then return list end
    local leader = party:getLeader()
    if leader and leader:getGuid() ~= player:getGuid() then
        tell(player, "Solo el lider del grupo puede reservar la mazmorra.")
        return nil
    end
    for _, member in ipairs(party:getMembers()) do
        if member and member:getGuid() ~= player:getGuid() then
            list[#list + 1] = member
        end
    end
    return list
end

-- Reserva la sala para el grupo del lider con una llave de ese nivel. Lo usa el altar
-- (dungeon_entrance.lua), justo antes de U.start. Entran ya los del grupo que estan en la
-- sala de entrada; los demas pueden venir despues por el portal del templo y la barrera.
function U.enter(player, level)
    if not U.mapReady then
        tell(player, "La Forja Caida aun no esta preparada. Avisa a un administrador.")
        return false
    end
    if U.run then
        tell(player, "La Forja Caida esta ocupada por otra expedicion. Espera a que termine.")
        return false
    end
    local members = collectParty(player)
    if not members then return false end
    if #members > 5 then
        tell(player, "La expedicion admite un maximo de cinco jugadores.")
        return false
    end
    level = math.max(0, math.min(10, math.floor(tonumber(level) or 0)))
    U.token = U.token + 1
    U.run = {
        token = U.token,
        ownerGuid = player:getGuid(),
        keyLevel = level,
        players = {},
        stage = 0,
        stageName = "Preparacion",
        remaining = 0,
        startedAt = nil,
        timeLimit = math.max(600, 1500 - level * 30),
        warned = {},
        failed = false,
        completed = false,
        emptySince = nil,
        completedAt = nil,
    }
    local slot = 0
    for _, member in ipairs(members) do
        U.run.players[member:getGuid()] = true
        local here = member:getGuid() == player:getGuid() or U.isInsideArena(member:getPosition())
        if here then
            slot = slot + 1
            local p = U.layout.start[slot]
            member:teleportTo(pos(p[1], p[2]))
            tell(member, "Has entrado en La Forja Caida. Lider: " .. player:getName() .. ". Llave de nivel " .. level .. ".")
        else
            tell(member, "Tu grupo ha entrado en La Forja Caida. Cruza el portal junto al templo para unirte.")
        end
    end
    return true
end

-- Cualquiera de la expedicion (o un GOD) cruza la barrera de la entrada; los demas no.
function U.canPass(player)
    if player:getGroup():getAccess() then return true end
    local r = U.run
    return r ~= nil and r.startedAt ~= nil and r.players[player:getGuid()] == true
end

function U.leave(player)
    if not U.run then
        tell(player, "No estas en una expedicion.")
        return false
    end
    local guid = player:getGuid()
    if not U.run.players[guid] then
        tell(player, "No formas parte de esta expedicion.")
        return false
    end
    player:teleportTo(U.layoutPos("arrival"))
    U.run.players[guid] = nil
    tell(player, "Has salido de La Forja Caida.")
    local count = 0
    for _ in pairs(U.run.players) do count = count + 1 end
    if count == 0 then
        U.reset(false)
    end
    return true
end

local function spawnTracked(name, dx, dy)
    local r = U.run
    if not r then return false end
    -- Los nombres con tilde se registran en Latin-1 (ver scripts/lib/nocthold.lua).
    local monster = Game.createMonster(Nocthold.latin1(name), pos(dx, dy), true, true)
    if not monster then
        U.tellGroup("ERROR: no se pudo invocar " .. name .. ". Comprueba el nombre y la carga de MonsterType.")
        return false
    end
    U.tracked[monster:getId()] = r.token
    r.remaining = r.remaining + 1
    return true
end

function U.spawnBossAdd(name, position)
    if not U.run or U.run.completed then return nil end
    local monster = Game.createMonster(Nocthold.latin1(name), position, true, true)
    if monster then
        U.tracked[monster:getId()] = U.run.token
        U.run.remaining = U.run.remaining + 1
        U.tellGroup("Refuerzos: " .. name .. ".")
    end
    return monster
end

local stages = {
    { name = "Calzada de Escoria", type = "trash", spawns = {
        {"Acólito de la Forja", 23, 12}, {"Acólito de la Forja", 23, 18},
        {"Carroñero de Escoria", 28, 12}, {"Carroñero de Escoria", 28, 18},
    }},
    { name = "El Guardian de Hierro", type = "boss", spawns = {{"El Guardián de Hierro", 26, 15}} },
    { name = "Galeria de Brasas", type = "trash", spawns = {
        {"Sabueso de Ceniza", 45, 11}, {"Sabueso de Ceniza", 45, 19},
        {"Coloso de Brasa", 50, 15}, {"Acólito de la Forja", 48, 10},
    }},
    { name = "La Maestra Carmesi", type = "boss", spawns = {{"La Maestra de Fundición Carmesí", 48, 15}} },
    { name = "Camara del Corazon", type = "trash", spawns = {
        {"Carroñero de Escoria", 68, 11}, {"Carroñero de Escoria", 68, 19},
        {"Acólito de la Forja", 72, 10}, {"Acólito de la Forja", 72, 20},
        {"Sabueso de Ceniza", 75, 15},
    }},
    { name = "El Corazon de la Forja", type = "boss", spawns = {{"El Corazón de la Forja", 72, 15}} },
}

local function startStage(index)
    local r = U.run
    if not r then return end
    if index > #stages then
        r.completed = true
        r.completedAt = os.time()
        local elapsed = os.time() - r.startedAt
        local reward = 5000 + (r.keyLevel * 1500)
        if r.failed then reward = math.floor(reward * 0.5) end
        U.tellGroup("La Forja Caida ha sido conquistada. Tiempo: " .. elapsed .. " s. Recompensa: " .. reward .. " oro por jugador.")
        for guid in pairs(r.players) do
            local p = onlinePlayerByGuid(guid)
            if p then
                pcall(function() p:addMoney(reward) end)
            end
        end
        U.run.stageName = "Completada"
        if not r.failed then
            local newLevel = math.min(10, r.keyLevel + 1)
            if U.upgradeKey and U.upgradeKey(r.ownerGuid, newLevel) then
                r.keyUpgradedTo = newLevel
                U.tellGroup("La piedra-llave del lider sube a nivel " .. newLevel .. ".")
            else
                U.tellGroup("El lider no lleva su piedra-llave encima: esta vez no sube de nivel.")
            end
        else
            U.tellGroup("La piedra-llave no sube porque se agoto el tiempo.")
        end
        if U.openFinishPortal then U.openFinishPortal() end
        U.tellGroup("Cruzad el portal de la ultima sala para volver a la entrada. Si seguis dentro, volvereis solos en 90 segundos.")
        return
    end
    r.stage = index
    r.stageName = stages[index].name
    r.remaining = 0
    U.tracked = {}
    local left = r.startedAt and math.max(0, r.timeLimit - (os.time() - r.startedAt)) or r.timeLimit
    U.tellGroup("Encuentro " .. index .. "/" .. #stages .. ": " .. r.stageName .. ". Quedan " .. math.floor(left / 60) .. ":" .. string.format("%02d", left % 60) .. ".")
    local spawns = {}
    for _, spawn in ipairs(stages[index].spawns) do
        spawns[#spawns + 1] = spawn
    end
    -- Alpha affix: one additional hound per trash pack from key 4.
    if r.keyLevel >= 4 and stages[index].type == "trash" then
        local extraX = (index == 1 and 30) or (index == 3 and 52) or 77
        spawns[#spawns + 1] = {"Sabueso de Ceniza", extraX, 15}
    end
    -- Alpha affix: the final boss encounter gets an extra colossus from key 7.
    if r.keyLevel >= 7 and index == 6 then
        spawns[#spawns + 1] = {"Coloso de Brasa", 77, 21}
    end
    for _, spawn in ipairs(spawns) do
        if not spawnTracked(spawn[1], spawn[2], spawn[3]) then
            r.failed = true
            U.tellGroup("La fase no pudo generarse completa. Contacta con un administrador.")
            return
        end
    end
end

function U.start(player)
    local r = U.run
    if not r then tell(player, "No hay ninguna expedicion reservada.") return false end
    if r.ownerGuid ~= player:getGuid() then tell(player, "Solo el lider que reservo la expedicion puede iniciarla.") return false end
    if r.startedAt then tell(player, "La expedicion ya esta en marcha.") return false end
    r.startedAt = os.time()
    U.tellGroup("La llave " .. r.keyLevel .. " ha comenzado. Tiempo: " .. r.timeLimit .. " segundos.")
    if r.keyLevel >= 4 then U.tellGroup("Afijo alfa: Brasas Errantes. Aparece un Sabueso adicional en cada grupo de enemigos.") end
    if r.keyLevel >= 7 then U.tellGroup("Afijo alfa: Corazon Furioso. La camara final recibe un Coloso adicional.") end
    startStage(1)
    return true
end

function U.onMonsterDeath(creature)
    local r = U.run
    if not r or not r.startedAt then return true end
    local id = creature:getId()
    if U.tracked[id] ~= r.token then return true end
    U.tracked[id] = nil
    r.remaining = math.max(0, r.remaining - 1)
    if r.remaining == 0 then
        local token = r.token
        local nextStage = r.stage + 1
        addEvent(function()
            if U.run and U.run.token == token and U.run.remaining == 0 and not U.run.completed then
                startStage(nextStage)
            end
        end, 1200)
    end
    return true
end

function U.statusText()
    local r = U.run
    if not r then return "Ahora mismo no hay ninguna expedicion en La Forja Caida." end
    local elapsed = r.startedAt and (os.time() - r.startedAt) or 0
    return "La Forja Caida | Llave " .. r.keyLevel .. " | Fase: " .. r.stageName .. " | Enemigos pendientes: " .. r.remaining .. " | Tiempo: " .. elapsed .. "/" .. r.timeLimit .. " s" .. (r.failed and " | TIEMPO AGOTADO" or "")
end

function U.status(player)
    tell(player, U.statusText())
    return true
end

local function removeTrackedCreatures()
    -- Search only the generated dungeon bounds and remove only creatures owned by this run.
    local spectators = Game.getSpectators(pos(40, 15), false, false, 41, 41, 21, 21)
    for _, creature in ipairs(spectators) do
        local id = creature:getId()
        if U.tracked[id] then
            pcall(function() creature:remove() end)
        end
    end
end

function U.reset(teleportPlayers)
    local r = U.run
    if not r then return end
    if teleportPlayers then
        -- Solo a los que siguen dentro de la mazmorra; quien esta en la ciudad se queda alli.
        for guid in pairs(r.players) do
            local p = onlinePlayerByGuid(guid)
            if p and U.isInsideArena(p:getPosition(), true) then
                p:teleportTo(U.layoutPos("arrival"))
            end
        end
    end
    if U.closeFinishPortal then U.closeFinishPortal() end
    removeTrackedCreatures()
    U.run = nil
    U.tracked = {}
end

local deathEvent = CreatureEvent("NoctholdDungeonDeath")
function deathEvent.onDeath(creature, corpse, lastHitKiller, mostDamageKiller, lastHitUnjustified, mostDamageUnjustified)
    return U.onMonsterDeath(creature)
end
deathEvent:register()

local clock = GlobalEvent("NoctholdDungeonClock")
clock:interval(1000)
function clock.onThink(interval)
    local r = U.run
    if not r then return true end

    local now = os.time()
    if r.completed and r.completedAt and now - r.completedAt >= 90 then
        U.tellGroup("La expedicion ha terminado. Regresareis a la entrada.")
        U.reset(true)
        return true
    end

    -- Si nadie de la expedicion esta conectado y dentro (entrada incluida) en 3 minutos,
    -- la sala se libera para otro grupo.
    local inside = 0
    for _, onlinePlayer in ipairs(Game.getPlayers()) do
        if r.players[onlinePlayer:getGuid()] and U.isInsideArena(onlinePlayer:getPosition()) then
            inside = inside + 1
        end
    end
    if inside == 0 then
        r.emptySince = r.emptySince or now
        if now - r.emptySince >= 180 then
            print("[NOCTHOLD] Reset automatico: nadie de la expedicion sigue en La Forja Caida.")
            U.reset(false)
            return true
        end
    else
        r.emptySince = nil
    end

    if r.startedAt and not r.completed and not r.failed then
        local elapsed = now - r.startedAt
        local left = r.timeLimit - elapsed
        if left <= r.timeLimit / 2 and not r.warned.half then
            r.warned.half = true
            U.tellGroup("Ha pasado la mitad del tiempo. Quedan " .. math.ceil(left / 60) .. " minutos.")
        end
        if left <= 60 and not r.warned.last then
            r.warned.last = true
            U.tellGroup("Queda un minuto.")
        end
        if elapsed >= r.timeLimit then
            r.failed = true
            U.tellGroup("Se ha agotado el tiempo. Podeis terminar la mazmorra, pero la recompensa se reducira.")
        end
    end
    return true
end
clock:register()
