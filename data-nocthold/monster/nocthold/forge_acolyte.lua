-- Nocthold prototype creature: Acólito de la Forja
-- Uses Canary MonsterType registration style. Placeholder outfit lookType=130.
-- Boss phase mechanics are specified in JSON and will be wired after the event API is tested in DEV.

local mType = Game.createMonsterType(Nocthold.latin1("Acólito de la Forja"))
local monster = {}

monster.description = Nocthold.latin1("Acólito de la Forja")
monster.experience = 0
monster.outfit = {
    lookType = 130,
    lookHead = 0,
    lookBody = 0,
    lookLegs = 0,
    lookFeet = 0,
    lookAddons = 0,
    lookMount = 0,
}
monster.health = 2100
monster.maxHealth = 2100
monster.race = "venom"
monster.speed = 190
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
    { name = "melee", type = COMBAT_PHYSICALDAMAGE, interval = 2000, minDamage = -25, maxDamage = -40 },
    { name = "combat", type = COMBAT_FIREDAMAGE, interval = 4000, chance = 25, radius = 2, minDamage = -45, maxDamage = -70, target = false },
}
monster.defenses = { defense = 8, armor = 5 }
monster.immunities = {}

mType:registerEvent("NoctholdDungeonDeath")
mType:register(monster)
