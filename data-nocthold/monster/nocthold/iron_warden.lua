-- Nocthold prototype creature: El Guardián de Hierro
-- Uses Canary MonsterType registration style. Placeholder outfit lookType=1144.
-- Boss phase mechanics are specified in JSON and will be wired after the event API is tested in DEV.

local mType = Game.createMonsterType(Nocthold.latin1("El Guardián de Hierro"))
local monster = {}

monster.description = Nocthold.latin1("Guardián de Hierro")
monster.experience = 0
monster.outfit = {
    lookType = 1144,
    lookHead = 0,
    lookBody = 0,
    lookLegs = 0,
    lookFeet = 0,
    lookAddons = 0,
    lookMount = 0,
}
monster.health = 80000
monster.maxHealth = 80000
monster.race = "blood"
monster.speed = 160
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
    { name = "melee", type = COMBAT_PHYSICALDAMAGE, interval = 2000, minDamage = -350, maxDamage = -650 },
    { name = "combat", type = COMBAT_PHYSICALDAMAGE, interval = 8000, chance = 20, radius = 2, minDamage = -250, maxDamage = -450, target = false },
}
monster.defenses = { defense = 120, armor = 110 }
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
    if ratio <= 0.70 and phase < 1 then
        phases[id] = 1
        monster:say(Nocthold.latin1("¡La forja exige mas hierro!"), TALKTYPE_MONSTER_SAY)
        p:sendMagicEffect(CONST_ME_BLOCKHIT)
        NOCTHOLD_DUNGEON.spawnBossAdd("Acólito de la Forja", Position(p.x - 2, p.y, p.z))
        NOCTHOLD_DUNGEON.spawnBossAdd("Acólito de la Forja", Position(p.x + 2, p.y, p.z))
    elseif ratio <= 0.35 and phase < 2 then
        phases[id] = 2
        monster:say(Nocthold.latin1("¡Que arda vuestra esperanza!"), TALKTYPE_MONSTER_SAY)
        p:sendMagicEffect(CONST_ME_EXPLOSIONHIT)
        NOCTHOLD_DUNGEON.spawnBossAdd("Coloso de Brasa", Position(p.x, p.y + 3, p.z))
    end
    return true
end
mType.onDisappear = function(monster, creature)
    if monster:getId() == creature:getId() then phases[monster:getId()] = nil end
end

mType:register(monster)
