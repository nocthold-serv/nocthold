-- Nocthold prototype creature: La Maestra de Fundición Carmesí
-- Uses Canary MonsterType registration style. Placeholder outfit lookType=1224.
-- Boss phase mechanics are specified in JSON and will be wired after the event API is tested in DEV.

local mType = Game.createMonsterType(Nocthold.latin1("La Maestra de Fundición Carmesí"))
local monster = {}

monster.description = Nocthold.latin1("Maestra de Fundición Carmesí")
monster.experience = 0
monster.outfit = {
    lookType = 1224,
    lookHead = 0,
    lookBody = 0,
    lookLegs = 0,
    lookFeet = 0,
    lookAddons = 0,
    lookMount = 0,
}
monster.health = 95000
monster.maxHealth = 95000
monster.race = "blood"
monster.speed = 190
monster.manaCost = 0
monster.changeTarget = { interval = 4000, chance = 10 }
monster.flags = {
    summonable = false,
    attackable = true,
    hostile = true,
    convinceable = false,
    pushable = false,
    rewardBoss = true,
    illusionable = false,
    canPushItems = true,
    canPushCreatures = true,
    staticAttackChance = 90,
    targetDistance = 1,
    runHealth = 0,
    healthHidden = false,
    isBlockable = false,
    canWalkOnEnergy = true,
    canWalkOnFire = true,
    canWalkOnPoison = true,
}
monster.voices = { interval = 7000, chance = 10 }
monster.loot = {
    { name = "gold coin", chance = 70000, maxCount = 25 },
}
monster.attacks = {
    { name = "melee", type = COMBAT_PHYSICALDAMAGE, interval = 2000, minDamage = -300, maxDamage = -550 },
    { name = "combat", type = COMBAT_FIREDAMAGE, interval = 5000, chance = 25, radius = 2, minDamage = -250, maxDamage = -500, target = false },
}
monster.defenses = { defense = 100, armor = 90 }
monster.immunities = {}

mType:registerEvent("NoctholdDungeonDeath")

local phases = {}
mType.onThink = function(monster, interval)
    local id = monster:getId()
    local hp, maxHp = monster:getHealth(), monster:getMaxHealth()
    if not maxHp or maxHp <= 0 then return true end
    local ratio = hp / maxHp
    local phase = phases[id] or 0
    local p = monster:getPosition()
    if ratio <= 0.66 and phase < 1 then
        phases[id] = 1
        monster:say(Nocthold.latin1("¡Sabuesos, defended la fundicion!"), TALKTYPE_MONSTER_SAY)
        p:sendMagicEffect(CONST_ME_FIREAREA)
        NOCTHOLD_DUNGEON.spawnBossAdd("Sabueso de Ceniza", Position(p.x - 3, p.y - 2, p.z))
        NOCTHOLD_DUNGEON.spawnBossAdd("Sabueso de Ceniza", Position(p.x + 3, p.y + 2, p.z))
    elseif ratio <= 0.33 and phase < 2 then
        phases[id] = 2
        monster:say(Nocthold.latin1("¡La camara se sobrecarga!"), TALKTYPE_MONSTER_SAY)
        p:sendMagicEffect(CONST_ME_FIREAREA)
        NOCTHOLD_DUNGEON.spawnBossAdd("Coloso de Brasa", Position(p.x, p.y + 3, p.z))
    end
    return true
end
mType.onDisappear = function(monster, creature)
    if monster:getId() == creature:getId() then phases[monster:getId()] = nil end
end

mType:register(monster)
