-- Nocthold 1.0.0-alpha.1: La Forja Caida runtime encounter controller.
-- Canary 3.6.1 / Revscriptsys. One shared test arena; NOT isolated multi-party instances.
-- Build the dynamic floor as GOD with: !nocthold buildmap

NOCTHOLD_DUNGEON = NOCTHOLD_DUNGEON or {}
local U = NOCTHOLD_DUNGEON
U.version = "1.0.0-alpha.1"
U.origin = Position(64000, 64000, 7)
U.mapReady = U.mapReady or false
U.nextKey = U.nextKey or {}
U.run = U.run or nil
U.tracked = U.tracked or {}
U.token = U.token or 0

local function pos(dx, dy)
    return Position(U.origin.x + dx, U.origin.y + dy, U.origin.z)
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

function U.buildMap(player)
    if U.mapReady then
        tell(player, "El mapa dinamico ya esta construido en esta sesion.")
        return true
    end
    local sourceTile = Tile(player:getPosition())
    local ground = sourceTile and sourceTile:getGround() or nil
    if not ground then
        tell(player, "No se pudo leer el suelo bajo tus pies. Pisa una casilla normal y repite.")
        return false
    end
    local floorId = ground:getId()
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
        tell(player, "Mapa incompleto: " .. created .. " casillas preparadas y " .. failed .. " fallos. Revisa el log antes de entrar.")
        return false
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
            print("[NOCTHOLD] No se pudo crear NPC: " .. data[1] .. ". Comprueba que su NpcType carga.")
        end
    end
    U.mapReady = true
    tell(player, "La Forja Caida se ha generado: " .. created .. " casillas y cinco puntos de NPC. Zona: X=64000, Y=64000, Z=7.")
    tell(player, "Usa !nocthold enter para formar una expedicion.")
    return true
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

local function saveReturn(player)
    local p = player:getPosition()
    return { x = p.x, y = p.y, z = p.z }
end

function U.enter(player)
    if not U.mapReady then
        tell(player, "El mapa aun no esta construido. Un GOD debe ejecutar !nocthold buildmap.")
        return false
    end
    if U.run then
        tell(player, "La Forja Caida esta reservada por otra expedicion. Solo se permite una run simultanea en esta arena alfa.")
        return false
    end
    local members = collectParty(player)
    if not members then return false end
    if #members > 5 then
        tell(player, "La expedicion admite un maximo de cinco jugadores.")
        return false
    end
    U.token = U.token + 1
    local level = U.nextKey[player:getGuid()] or 0
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
        failed = false,
        completed = false,
        emptySince = nil,
        completedAt = nil,
    }
    local leaderPos = player:getPosition()
    for _, member in ipairs(members) do
        local mp = member:getPosition()
        if mp.z ~= leaderPos.z or math.abs(mp.x - leaderPos.x) > 12 or math.abs(mp.y - leaderPos.y) > 12 then
            U.run = nil
            tell(player, "Todos los miembros deben estar conectados y a menos de 12 casillas del lider para entrar.")
            return false
        end
    end
    for i, member in ipairs(members) do
        local returnPos = saveReturn(member)
        U.run.players[member:getGuid()] = returnPos
        local offsets = { {5,15}, {4,15}, {6,15}, {5,14}, {5,16} }
        member:teleportTo(pos(offsets[i][1], offsets[i][2]))
        tell(member, "Has entrado en La Forja Caida. Lider: " .. player:getName() .. ". Dificultad: " .. level .. ".")
    end
    tell(player, "Expedicion reservada para " .. #members .. " jugador(es). Habla con el Cronista o usa !nocthold start.")
    return true
end

function U.rejoin(player)
    if not U.run then
        tell(player, "No hay ninguna expedicion activa.")
        return false
    end
    local guid = player:getGuid()
    if not U.run.players[guid] then
        tell(player, "No figuras entre los miembros de esta expedicion.")
        return false
    end
    player:teleportTo(pos(5, 15))
    tell(player, "Te has reincorporado a La Forja Caida.")
    return true
end

function U.leave(player)
    if not U.run then
        tell(player, "No estas en una expedicion.")
        return false
    end
    local guid = player:getGuid()
    local entry = U.run.players[guid]
    if not entry then
        tell(player, "No formas parte de esta expedicion.")
        return false
    end
    player:teleportTo(Position(entry.x, entry.y, entry.z))
    U.run.players[guid] = nil
    tell(player, "Has abandonado La Forja Caida.")
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
            U.nextKey[r.ownerGuid] = math.min(10, r.keyLevel + 1)
            U.tellGroup("La llave del lider mejora a nivel " .. U.nextKey[r.ownerGuid] .. ".")
        else
            U.tellGroup("La llave no mejora porque se agoto el tiempo.")
        end
        U.tellGroup("Podeis salir con !nocthold leave. Si seguis dentro, volvereis a la entrada en 90 segundos.")
        return
    end
    r.stage = index
    r.stageName = stages[index].name
    r.remaining = 0
    U.tracked = {}
    U.tellGroup("Encuentro " .. index .. "/" .. #stages .. ": " .. r.stageName .. ".")
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
    if not r then tell(player, "Primero usa !nocthold enter.") return false end
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

function U.status(player)
    if not U.run then tell(player, "No hay ninguna expedicion activa.") return true end
    local r = U.run
    local elapsed = r.startedAt and (os.time() - r.startedAt) or 0
    tell(player, "La Forja Caida | Llave " .. r.keyLevel .. " | Fase: " .. r.stageName .. " | Enemigos pendientes: " .. r.remaining .. " | Tiempo: " .. elapsed .. "/" .. r.timeLimit .. " s" .. (r.failed and " | TIEMPO AGOTADO" or ""))
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
        for guid, entry in pairs(r.players) do
            local p = onlinePlayerByGuid(guid)
            if p then
                p:teleportTo(Position(entry.x, entry.y, entry.z))
            end
        end
    end
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

    local onlineGuids = {}
    for _, onlinePlayer in ipairs(Game.getPlayers()) do
        onlineGuids[onlinePlayer:getGuid()] = true
    end
    local onlineCount = 0
    for guid in pairs(r.players) do
        if onlineGuids[guid] then onlineCount = onlineCount + 1 end
    end
    if onlineCount == 0 then
        r.emptySince = r.emptySince or now
        if now - r.emptySince >= 120 then
            print("[NOCTHOLD] Reset automatico: no quedan miembros conectados.")
            U.reset(false)
            return true
        end
    else
        r.emptySince = nil
    end

    if r.startedAt and not r.completed and not r.failed then
        local elapsed = now - r.startedAt
        if elapsed >= r.timeLimit then
            r.failed = true
            U.tellGroup("Se ha agotado el tiempo. Podeis terminar la mazmorra, pero la recompensa se reducira.")
        end
    end
    return true
end
clock:register()
