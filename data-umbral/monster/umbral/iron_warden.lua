-- UMBRAL prototype creature: El Guardián de Hierro
-- Uses Canary MonsterType registration style. Placeholder outfit lookType=1144.
-- Boss phase mechanics are specified in JSON and will be wired after the event API is tested in DEV.

local mType = Game.createMonsterType("El Guardián de Hierro")
local monster = {}

monster.description = "Guardián de Hierro"
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
monster.loot = {}
monster.attacks = {
    { name = "melee", type = COMBAT_PHYSICALDAMAGE, interval = 2000, minDamage = -350, maxDamage = -650 },
    { name = "combat", type = COMBAT_PHYSICALDAMAGE, interval = 8000, chance = 20, radius = 2, minDamage = -250, maxDamage = -450, target = false },
}
monster.defenses = { defense = 120, armor = 110 }
monster.immunities = {}

mType:register(monster)
