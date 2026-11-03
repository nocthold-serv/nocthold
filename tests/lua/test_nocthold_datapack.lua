-- Carga de data-nocthold con funciones de Canary simuladas (luajit tests/lua/test_nocthold_datapack.lua
-- desde la raíz del repo). Comprueba que todo se registra y que no se repiten palabras de hechizo.
-- No sustituye al arranque real (eso lo hace el job "Imagen Docker y arranque").
setmetatable(_G, { __index = function(_, key)
    if key == "CALLBACK_GREET" then return 101 end
    if key == "CALLBACK_MESSAGE_DEFAULT" then return 102 end
    if type(key) == "string" and (key:match("^CONST_") or key:match("^COMBAT_") or key:match("^CONDITION_") or key:match("^AREA_") or key:match("^TALKTYPE_") or key:match("^MESSAGE_") or key:match("^CALLBACK_") or key:match("^ORIGIN_")) then return 1 end
    return nil
end })

local registeredWords = {}
local castObjects, npcHandlers, monsterObjects = {}, {}, {}
local lastNpcSay
local registeredMonsters = {}
function MonsterType(name) return registeredMonsters[name] end
local spellCount, monsterCount, npcCount = 0, 0, 0
function Position(x, y, z) return { x = x, y = y, z = z } end
local state = setmetatable({}, { __mode = "k" })

local function genericObject()
    local obj = {}
    state[obj] = {}
    return setmetatable(obj, { __index = function(self, key)
        return function(_, ...)
            local args = {...}
            local s = state[self]
            if key == "words" then s.words = args[1] end
            if key == "name" then s.name = args[1] end
            if key == "onCastSpell" then s.cast = args[1]; castObjects[#castObjects + 1] = self end
            if key == "setCallback" then
                s.callbacks = s.callbacks or {}
                s.callbacks[args[1]] = args[2]
                if not s.listed then s.listed = true; npcHandlers[#npcHandlers + 1] = self end
            end
            if key == "say" then lastNpcSay = args[1] end
            if key == "groupType" then s.groupType = args[1] end
            if key == "register" and s.talkAction then
                -- Canary se niega a registrar un TalkAction sin groupType (solo lo dice en el log).
                assert(s.groupType, "TalkAction " .. s.talkAction .. " sin groupType")
            end
            if key == "register" then
                if s.words then
                    assert(not registeredWords[s.words], "duplicate spell words: " .. tostring(s.words))
                    registeredWords[s.words] = true
                    spellCount = spellCount + 1
                end
                return true
            end
            return true
        end
    end })
end

function Combat() return genericObject() end
function Spell(_) return genericObject() end
function Condition(_) return genericObject() end
function createCombatArea(_) return {} end
Game = {}
function Game.createMonsterType(name)
    monsterCount = monsterCount + 1
    registeredMonsters[name] = true
    local obj = genericObject()
    monsterObjects[name] = obj
    return obj
end
function Game.createNpcType(_) npcCount = npcCount + 1; return genericObject() end
function Game.getSpectators() return {} end
function CreatureEvent(_) return genericObject() end
function GlobalEvent(_) return genericObject() end
function TalkAction(words) local o = genericObject(); state[o].talkAction = words; return o end
NpcHandler = setmetatable({}, { __index = function() return function() return genericObject() end end })
KeywordHandler = setmetatable({}, { __index = function() return function() return genericObject() end end })
FocusModule = setmetatable({}, { __index = function() return function() return genericObject() end end })
function MsgContains(text, keyword) return string.find(text, keyword, 1, true) ~= nil end

local root = "data-nocthold"
dofile(root .. "/scripts/lib/nocthold.lua")
local spellFiles = {}
for line in io.popen("find " .. string.format("%q", root .. "/scripts/nocthold/spells") .. " -maxdepth 1 -type f -name '*.lua' | sort"):lines() do
    spellFiles[#spellFiles + 1] = line
end
for _, path in ipairs(spellFiles) do assert(loadfile(path))() end
assert(spellCount == 30, "Expected 30 registered spell definitions, got " .. spellCount)

local monsterFiles = {}
for line in io.popen("find " .. string.format("%q", root .. "/monster/nocthold") .. " -maxdepth 1 -type f -name '*.lua' | sort"):lines() do
    monsterFiles[#monsterFiles + 1] = line
end
for _, path in ipairs(monsterFiles) do assert(loadfile(path))() end
assert(#monsterFiles == 7 and monsterCount == 7, "Expected seven MonsterType scripts")

assert(loadfile(root .. "/npc/nocthold_npcs.lua"))()
assert(npcCount == 5, "Expected five NpcType registrations, got " .. npcCount)
assert(loadfile(root .. "/scripts/nocthold/runtime/encounter_runtime.lua"))()
assert(loadfile(root .. "/scripts/nocthold/runtime/adventure_commands.lua"))()
assert(loadfile(root .. "/scripts/nocthold/nocthold_admin.lua"))()
local monsters = Nocthold.countMonsters()
assert(monsters == 7, "Nocthold.countMonsters() = " .. monsters)
assert(#Nocthold.npcs == Nocthold.expectedNpcs and #Nocthold.spells == Nocthold.expectedSpells, Nocthold.statusText())

-- Cada hechizo se lanza una vez con un lanzador simulado: un fallo de Lua dentro del hechizo
-- (una función que no existe, una variable mal escrita) solo saldría al usarlo en el juego.
local function fakePosition()
    return { x = 100, y = 100, z = 7, sendMagicEffect = function() return true end }
end
local fakeCreature = {
    getPosition = function() return fakePosition() end,
    addCondition = function() return true end,
}
function Creature(_) return fakeCreature end
local fakeVariant = { getNumber = function() return 1 end, getPosition = function() return fakePosition() end }
assert(#castObjects == 30, "expected 30 onCastSpell callbacks, got " .. #castObjects)
for _, obj in ipairs(castObjects) do
    local s = state[obj]
    local ok, result = pcall(s.cast, fakeCreature, fakeVariant)
    assert(ok, "spell " .. tostring(s.name) .. " fails when cast: " .. tostring(result))
    assert(result ~= nil, "spell " .. tostring(s.name) .. " returns nothing")
end

-- Fases de los tres jefes (70 % y 35 % de vida): cada una pide sus refuerzos una sola vez.
local adds = {}
local realSpawnBossAdd = NOCTHOLD_DUNGEON.spawnBossAdd
NOCTHOLD_DUNGEON.spawnBossAdd = function(name, position)
    assert(type(name) == "string" and position and position.x, "bad boss add call")
    assert(MonsterType(Nocthold.latin1(name)), "boss add '" .. name .. "' is not a Nocthold monster")
    adds[#adds + 1] = name
    return {}
end
local bosses = 0
for name, obj in pairs(monsterObjects) do
    local think = rawget(obj, "onThink")
    if think then
        bosses = bosses + 1
        local hp = 1000
        local said = 0
        local fakeMonster = {
            getId = function() return 7000 + bosses end,
            getHealth = function() return hp end,
            getMaxHealth = function() return 1000 end,
            getPosition = function() return fakePosition() end,
            say = function() said = said + 1 end,
        }
        local before = #adds
        for _, value in ipairs({ 1000, 650, 650, 300, 300, 100 }) do
            hp = value
            assert(pcall(think, fakeMonster, 1000), "boss " .. name .. " onThink fails")
        end
        assert(#adds > before, "boss " .. name .. " never calls for reinforcements")
        assert(said == 2, "boss " .. name .. " should speak once per phase, spoke " .. said)
        local disappear = rawget(obj, "onDisappear")
        if disappear then assert(pcall(disappear, fakeMonster, fakeMonster), "boss " .. name .. " onDisappear fails") end
    end
end
assert(bosses == 3, "expected three bosses with phases, got " .. bosses)
NOCTHOLD_DUNGEON.spawnBossAdd = realSpawnBossAdd

-- NPC: saludo, cada palabra clave (también en plural) y la respuesta por defecto.
assert(#npcHandlers == 5, "expected five NPC handlers, got " .. #npcHandlers)
for _, handler in ipairs(npcHandlers) do
    local callbacks = state[handler].callbacks
    assert(callbacks[101] and callbacks[102], "NPC without greet or message callback")
    assert(callbacks[101]({}, {}) == true, "NPC greet fails")
    for _, message in ipairs({ "mazmorra", "llaves", "forja", "trabajo", "hola que tal" }) do
        lastNpcSay = nil
        assert(callbacks[102]({}, {}, 1, message) == true, "NPC reply fails for '" .. message .. "'")
        assert(type(lastNpcSay) == "string" and #lastNpcSay > 0, "NPC said nothing for '" .. message .. "'")
    end
end

-- La prueba dentro del servidor (selftest.lua) comprueba que Canary tiene todas las constantes
-- que usan nuestros archivos: su lista tiene que estar completa.
local selftestSource = io.open(root .. "/scripts/nocthold/selftest.lua"):read("*a")
local listed = {}
for name in selftestSource:match("local constants = (%b{})"):gmatch('"([%u%d_]+)"') do listed[name] = true end
for line in io.popen("find " .. string.format("%q", root) .. " -name '*.lua' ! -name selftest.lua | sort"):lines() do
    local source = io.open(line):read("*a")
    for name in source:gmatch("%f[%w_]([A-Z][A-Z]+_[A-Z0-9_]+)%f[^%w_]") do
        if name:match("^COMBAT_") or name:match("^CONDITION_") or name:match("^CONST_") or name:match("^AREA_")
            or name:match("^MESSAGE_") or name:match("^TALKTYPE_") or name:match("^FLAG_") or name:match("^CALLBACK_") then
            assert(listed[name], name .. " (used in " .. line .. ") is missing from the constants list in selftest.lua")
        end
    end
end
assert(loadfile(root .. "/scripts/nocthold/selftest.lua"))() -- sin NOCTHOLD_SELFTEST no hace nada

print(Nocthold.statusText())
print("Synthetic load smoke test OK: " .. spellCount .. " unique spell registrations (all cast once), " .. monsterCount .. " monster types (3 boss phase scripts), " .. npcCount .. " NPC types (all keywords answered), runtime and commands loaded.")
