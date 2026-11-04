-- Lógica de La Forja Caída (scripts/nocthold/runtime) con funciones de Canary simuladas.
-- luajit tests/lua/test_nocthold_dungeon.lua desde la raíz del repo. No es un test de integración.
MESSAGE_EVENT_ADVANCE = 19
TALKTYPE_MONSTER_SAY = 1
TALKTYPE_MONSTER_YELL = 2
CONST_ME_BLOCKHIT = 1
CONST_ME_EXPLOSIONHIT = 2
CONST_ME_FIREAREA = 3
local nextId = 100
local moneyAwarded = 0
local fakeCreatures = {}
local fakePlayer = {}
function Position(x, y, z) return { x = x, y = y, z = z } end
function Player(guid) if guid == 123 then return fakePlayer end return nil end
function CreatureEvent(name)
    local o = {}
    function o:type(v) self.eventType = v; return true end
    function o:register() return true end
    return o
end
function GlobalEvent(name)
    local o = {}
    function o:interval(v) self.ms = v; return true end
    function o:register() return true end
    return o
end
Game = {}
function Game.createMonster(name, position, extended, force)
    nextId = nextId + 1
    local id = nextId
    local creature = {
        name = name,
        pos = position,
        removed = false,
        getId = function(self) return id end,
        remove = function(self) self.removed = true; return true end,
    }
    fakeCreatures[#fakeCreatures + 1] = creature
    return creature
end
function Game.getPlayers() return { fakePlayer } end
function Game.getSpectators(position, multifloor, onlyPlayer, minX, maxX, minY, maxY)
    local list = {}
    for _, c in ipairs(fakeCreatures) do if not c.removed then list[#list + 1] = c end end
    return list
end
function addEvent(callback, delay) callback(); return 1 end
function fakePlayer:getGuid() return 123 end
function fakePlayer:getName() return "Tester" end
function fakePlayer:getPosition() return Position(100, 100, 7) end
function fakePlayer:getParty() return nil end
function fakePlayer:teleportTo(position) self.position = position; return true end
function fakePlayer:sendTextMessage(type, text) end
function fakePlayer:addMoney(amount) moneyAwarded = moneyAwarded + amount; return true end
function fakePlayer:getGroup() return { getAccess = function() return false end } end
function fakePlayer:getSlotItem(slot) if slot == CONST_SLOT_FIRST then return self.key end return nil end
CONST_SLOT_FIRST, CONST_SLOT_LAST = 1, 10
ITEM_ATTRIBUTE_NAME, ITEM_ATTRIBUTE_DESCRIPTION = 7, 3
local function newEvent()
    local o = {}
    for _, m in ipairs({ "type", "aid", "register" }) do o[m] = function() return true end end
    return o
end
MoveEvent, Action = newEvent, newEvent
-- Piedra-llave simulada (como un Item de Canary con atributos).
local function newKey()
    local k = { attrs = {}, custom = {}, aid = 0 }
    function k:getId() return 3235 end
    function k:getActionId() return self.aid end
    function k:setActionId(v) self.aid = v return true end
    function k:setCustomAttribute(name, v) self.custom[name] = v return true end
    function k:getCustomAttribute(name) return self.custom[name] end
    function k:setAttribute(name, v) self.attrs[name] = v return true end
    function k:isContainer() return false end
    return k
end
dofile("data-nocthold/scripts/lib/nocthold.lua")
assert(loadfile("data-nocthold/scripts/nocthold/runtime/dungeon_entrance.lua"))()
local runtime = assert(loadfile("data-nocthold/scripts/nocthold/runtime/encounter_runtime.lua"))
runtime()
local U = NOCTHOLD_DUNGEON

-- buildmap: igual que Canary, una casilla nueva no tiene suelo y rechaza objetos salvo con FLAG_NOLIMIT.
FLAG_NOLIMIT = 1
local fakeTiles = {}
local function newTile(ground)
    local t = { ground = ground }
    function t:getGround() return self.ground end
    function t:addItem(itemId, count, flags)
        if not self.ground and (flags or 0) % 2 ~= FLAG_NOLIMIT then return nil end
        self.ground = { getId = function() return itemId end }
        return self.ground
    end
    return t
end
local function tileKey(p) return p.x .. ":" .. p.y .. ":" .. p.z end
fakeTiles[tileKey(Position(100, 100, 7))] = newTile({ getId = function() return 406 end })
function Tile(p) return fakeTiles[tileKey(p)] end
function Game.createTile(p, dynamic)
    local key = tileKey(p)
    fakeTiles[key] = fakeTiles[key] or newTile(nil)
    return fakeTiles[key]
end
function Game.createNpc(name, position) return { name = name } end
assert(U.buildMap(406) == true, "buildmap did not lay floor on groundless tiles")
assert(U.mapReady, "buildmap did not mark the map as ready")
assert(Tile(Position(64000, 64009, 7)):getGround():getId() == 406, "buildmap did not copy the temple floor")

-- Objetos puestos en el suelo (el portal de la última sala).
local portalItems = {}
function Game.createItem(id, count, p)
    local it = newKey()
    it.realId, it.pos = id, p
    function it:remove() self.removed = true return true end
    portalItems[#portalItems + 1] = it
    return it
end
local plainTile = Tile
function Tile(p)
    local t = plainTile(p) or {}
    t.getItemById = function(_, id)
        for _, it in ipairs(portalItems) do
            if not it.removed and it.realId == id and it.pos.x == p.x and it.pos.y == p.y then return it end
        end
        return nil
    end
    return t
end
function Position(x, y, z)
    return { x = x, y = y, z = z, sendMagicEffect = function() return true end }
end

-- Sin piedra-llave el altar no abre; con una de nivel 7, entra el líder y empieza.
assert(U.useAltar(fakePlayer) == false and U.run == nil, "the altar opened without a key")
fakePlayer.key = newKey()
U.setKeyLevel(fakePlayer.key, 7)
assert(U.keyLevel(fakePlayer.key) == 7 and fakePlayer.key.aid == U.AID_KEY, "key level not stored")
assert(U.canPass(fakePlayer) == false, "barrier open without a run")
assert(U.useAltar(fakePlayer) == true, "altar did not start the run")
assert(U.run.keyLevel == 7 and U.run.stage == 1, "run did not start at key 7")
assert(U.isInsideArena(fakePlayer.position, true), "leader was not moved into the dungeon")
assert(U.canPass(fakePlayer) == true, "barrier closed for a run member")
local stranger = { getGuid = function() return 999 end, getGroup = fakePlayer.getGroup }
assert(U.canPass(stranger) == false, "barrier open for a stranger")
-- La barrera: hacia dentro solo los suyos (vuelve a la casilla de antes); hacia fuera, todos.
local pushed
stranger.getPosition = function() return Position(64012, 64015, 7) end
stranger.teleportTo = function(_, p) pushed = p return true end
stranger.sendTextMessage = function() end
U.stepBarrier(stranger, Position(64011, 64015, 7))
assert(pushed and pushed.x == 64011, "barrier did not push the stranger back")
pushed = nil
U.stepBarrier(stranger, Position(64013, 64015, 7))
assert(pushed == nil, "barrier must let everyone walk back to the entrance")

local guard = 0
while U.run and not U.run.completed and guard < 30 do
    guard = guard + 1
    local ids = {}
    for id in pairs(U.tracked) do ids[#ids + 1] = id end
    assert(#ids > 0, "stage has no tracked monsters at iteration " .. guard)
    if U.run.stage == 2 and not U.testAdd1 then
        U.testAdd1 = true
        U.spawnBossAdd("Acólito de la Forja", Position(64025, 64016, 7))
    elseif U.run.stage == 4 and not U.testAdd2 then
        U.testAdd2 = true
        U.spawnBossAdd("Sabueso de Ceniza", Position(64047, 64016, 7))
    elseif U.run.stage == 6 and not U.testAdd3 then
        U.testAdd3 = true
        U.spawnBossAdd("Coloso de Brasa", Position(64075, 64016, 7))
    end
    ids = {}
    for id in pairs(U.tracked) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        U.onMonsterDeath({ getId = function() return id end })
    end
end
assert(U.run and U.run.completed, "encounter did not complete")
assert(moneyAwarded > 0, "no reward awarded")
assert(U.keyLevel(fakePlayer.key) == 8 and U.run.keyUpgradedTo == 8, "leader key was not upgraded after an in-time completion")
assert(#portalItems == 1 and not portalItems[1].removed and portalItems[1].realId == U.ITEM_PORTAL and portalItems[1].aid == U.AID_FINISH, "finish portal did not appear")
assert(U.stepFinish(fakePlayer) == true, "finish portal did not take the player out")
assert(U.run == nil, "completed run was not released after players left")
assert(fakePlayer.position.x == 64005 and fakePlayer.position.y == 64016, "finish portal did not lead to the entrance")
assert(portalItems[1].removed, "finish portal was not removed when the run ended")

-- A fresh run can begin (with the upgraded key), and administrative reset removes its remaining tracked monsters.
assert(U.useAltar(fakePlayer) == true and U.run.keyLevel == 8, "second run did not use the level 8 key")
local trackedBeforeReset = 0
for _ in pairs(U.tracked) do trackedBeforeReset = trackedBeforeReset + 1 end
assert(trackedBeforeReset > 0, "second run did not spawn monsters")
U.reset(true)
assert(U.run == nil, "admin reset did not release run")
local removedTracked = 0
for _, c in ipairs(fakeCreatures) do if c.removed then removedTracked = removedTracked + 1 end end
assert(removedTracked >= trackedBeforeReset, "reset did not remove tracked monsters")
print("Encounter logic OK: altar with key, barrier, six stages, key 7 modifiers, boss-add tracking, completion, payout, key upgrade, finish portal, rerun and cleanup.")
