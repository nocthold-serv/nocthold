-- Carga de data-nocthold con funciones de Canary simuladas (luajit tests/lua/test_nocthold_datapack.lua
-- desde la raíz del repo). Comprueba que todo se registra y que no se repiten palabras de hechizo.
-- No sustituye al arranque real (eso lo hace el job "Imagen Docker y arranque").
setmetatable(_G, { __index = function(_, key)
    if type(key) == "string" and (key:match("^CONST_") or key:match("^COMBAT_") or key:match("^CONDITION_") or key:match("^AREA_") or key:match("^TALKTYPE_") or key:match("^MESSAGE_") or key:match("^CALLBACK_") or key:match("^ORIGIN_")) then return 1 end
    return nil
end })

local registeredWords = {}
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
function Game.createMonsterType(name) monsterCount = monsterCount + 1; registeredMonsters[name] = true; return genericObject() end
function Game.createNpcType(_) npcCount = npcCount + 1; return genericObject() end
function Game.getSpectators() return {} end
function CreatureEvent(_) return genericObject() end
function GlobalEvent(_) return genericObject() end
function TalkAction(_) return genericObject() end
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
print(Nocthold.statusText())
print("Synthetic load smoke test OK: " .. spellCount .. " unique spell registrations, " .. monsterCount .. " monster types, " .. npcCount .. " NPC types, runtime and commands loaded.")
