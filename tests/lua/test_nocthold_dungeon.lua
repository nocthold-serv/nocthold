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
dofile("data-nocthold/scripts/lib/nocthold.lua")
local runtime = assert(loadfile("data-nocthold/scripts/nocthold/runtime/encounter_runtime.lua"))
runtime()
local U = NOCTHOLD_DUNGEON
U.mapReady = true
U.nextKey[123] = 7
assert(U.enter(fakePlayer) == true, "entry failed")
assert(U.start(fakePlayer) == true, "start failed")
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
assert(U.nextKey[123] == 8, "leader key was not upgraded after an in-time completion")
assert(U.leave(fakePlayer) == true, "leave after completion failed")
assert(U.run == nil, "completed run was not released after players left")

-- A fresh run can begin, and administrative reset removes its remaining tracked monsters.
assert(U.enter(fakePlayer) == true, "second entry failed")
assert(U.start(fakePlayer) == true, "second start failed")
local trackedBeforeReset = 0
for _ in pairs(U.tracked) do trackedBeforeReset = trackedBeforeReset + 1 end
assert(trackedBeforeReset > 0, "second run did not spawn monsters")
U.reset(true)
assert(U.run == nil, "admin reset did not release run")
local removedTracked = 0
for _, c in ipairs(fakeCreatures) do if c.removed then removedTracked = removedTracked + 1 end end
assert(removedTracked >= trackedBeforeReset, "reset did not remove tracked monsters")
print("Encounter logic OK: six stages, key 7 modifiers, boss-add tracking, completion, payout, leave, rerun and cleanup.")
