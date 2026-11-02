-- UMBRAL prototype creature: La Maestra de Fundición Carmesí
-- Uses Canary MonsterType registration style. Placeholder outfit lookType=1224.
-- Boss phase mechanics are specified in JSON and will be wired after the event API is tested in DEV.

local mType = Game.createMonsterType("La Maestra de Fundición Carmesí")
local monster = {}

monster.description = "Maestra de Fundición Carmesí"
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
monster.loot = {}
monster.attacks = {
    { name = "melee", type = COMBAT_PHYSICALDAMAGE, interval = 2000, minDamage = -300, maxDamage = -550 },
    { name = "combat", type = COMBAT_FIREDAMAGE, interval = 5000, chance = 25, radius = 2, minDamage = -250, maxDamage = -500, target = false },
}
monster.defenses = { defense = 100, armor = 90 }
monster.immunities = {}

mType:register(monster)
