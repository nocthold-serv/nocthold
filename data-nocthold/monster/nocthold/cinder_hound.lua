-- Nocthold prototype creature: Sabueso de Ceniza
-- Uses Canary MonsterType registration style. Placeholder outfit lookType=35.
-- Boss phase mechanics are specified in JSON and will be wired after the event API is tested in DEV.

local mType = Game.createMonsterType(Nocthold.latin1("Sabueso de Ceniza"))
local monster = {}

monster.description = Nocthold.latin1("Sabueso de Ceniza")
monster.experience = 0
monster.outfit = {
    lookType = 35,
    lookHead = 0,
    lookBody = 0,
    lookLegs = 0,
    lookFeet = 0,
    lookAddons = 0,
    lookMount = 0,
}
monster.health = 2400
monster.maxHealth = 2400
monster.race = "blood"
monster.speed = 230
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
monster.loot = {
    { name = "gold coin", chance = 70000, maxCount = 25 },
}
monster.attacks = {
    { name = "melee", type = COMBAT_PHYSICALDAMAGE, interval = 2000, minDamage = -40, maxDamage = -65 },
    { name = "combat", type = COMBAT_FIREDAMAGE, interval = 5000, chance = 20, radius = 2, minDamage = -25, maxDamage = -40, target = false },
}
monster.defenses = { defense = 10, armor = 10 }
monster.immunities = {}

mType:registerEvent("NoctholdDungeonDeath")
mType:register(monster)
