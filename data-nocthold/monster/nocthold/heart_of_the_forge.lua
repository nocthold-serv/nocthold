-- Nocthold prototype creature: El Corazón de la Forja
-- Uses Canary MonsterType registration style. Placeholder outfit lookType=1144.
-- Boss phase mechanics are specified in JSON and will be wired after the event API is tested in DEV.

local mType = Game.createMonsterType(Nocthold.latin1("El Corazón de la Forja"))
local monster = {}

monster.description = Nocthold.latin1("Corazón de la Forja")
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
monster.health = 140000
monster.maxHealth = 140000
monster.race = "energy"
monster.speed = 120
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
    { name = "melee", type = COMBAT_PHYSICALDAMAGE, interval = 2000, minDamage = -450, maxDamage = -800 },
    { name = "combat", type = COMBAT_FIREDAMAGE, interval = 6000, chance = 30, radius = 2, minDamage = -350, maxDamage = -650, target = false },
}
monster.defenses = { defense = 160, armor = 140 }
monster.immunities = {}

mType:register(monster)
