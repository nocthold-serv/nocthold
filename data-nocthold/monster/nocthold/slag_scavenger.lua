-- Nocthold prototype creature: Carroñero de Escoria
-- Uses Canary MonsterType registration style. Placeholder outfit lookType=128.
-- Boss phase mechanics are specified in JSON and will be wired after the event API is tested in DEV.

local mType = Game.createMonsterType(Nocthold.latin1("Carroñero de Escoria"))
local monster = {}

monster.description = Nocthold.latin1("Carroñero de Escoria")
monster.experience = 0
monster.outfit = {
    lookType = 128,
    lookHead = 0,
    lookBody = 0,
    lookLegs = 0,
    lookFeet = 0,
    lookAddons = 0,
    lookMount = 0,
}
monster.health = 1800
monster.maxHealth = 1800
monster.race = "blood"
monster.speed = 175
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
    { name = "melee", type = COMBAT_PHYSICALDAMAGE, interval = 2000, minDamage = -35, maxDamage = -55 },
}
monster.defenses = { defense = 12, armor = 8 }
monster.immunities = {}

mType:registerEvent("NoctholdDungeonDeath")
mType:register(monster)
