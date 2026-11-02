-- Nocthold prototype creature: Coloso de Brasa
-- Uses Canary MonsterType registration style. Placeholder outfit lookType=131.
-- Boss phase mechanics are specified in JSON and will be wired after the event API is tested in DEV.

local mType = Game.createMonsterType("Coloso de Brasa")
local monster = {}

monster.description = "Coloso de Brasa"
monster.experience = 0
monster.outfit = {
    lookType = 131,
    lookHead = 0,
    lookBody = 0,
    lookLegs = 0,
    lookFeet = 0,
    lookAddons = 0,
    lookMount = 0,
}
monster.health = 5200
monster.maxHealth = 5200
monster.race = "blood"
monster.speed = 140
monster.manaCost = 0
monster.changeTarget = { interval = 4000, chance = 10 }
monster.flags = {
    summonable = false,
    attackable = true,
    hostile = true,
    convinceable = false,
    pushable = false,
    rewardBoss = false,
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
    { name = "melee", type = COMBAT_PHYSICALDAMAGE, interval = 2000, minDamage = -75, maxDamage = -110 },
    { name = "combat", type = COMBAT_FIREDAMAGE, interval = 6000, chance = 25, radius = 2, minDamage = -65, maxDamage = -95, target = false },
}
monster.defenses = { defense = 25, armor = 25 }
monster.immunities = {}

mType:register(monster)
