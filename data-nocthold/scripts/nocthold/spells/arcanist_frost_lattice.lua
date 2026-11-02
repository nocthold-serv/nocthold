-- Nocthold
-- Deals ice damage and applies a short 60-point movement slow to susceptible targets.
-- Boss-specific slow reduction/immunity rules will be added in the encounter layer.

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_ICEDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_ICEATTACK)
combat:setFormula(COMBAT_FORMULA_LEVELMAGIC, -0.55, -8, -0.75, -14)

local slow = Condition(CONDITION_PARALYZE)
slow:setParameter(CONDITION_PARAM_TICKS, 2500)
slow:setParameter(CONDITION_PARAM_SPEED, -60)
combat:addCondition(slow)

local spell = Spell("instant")
spell:name("Frost Lattice")
spell:words("nocthold frost")
spell:group("attack")
spell:cooldown(14000)
spell:groupCooldown(1000)
spell:level(4)
spell:mana(32)
spell:needTarget(true)
spell:range(6)
spell:blockWalls(true)
spell:isAggressive(true)
spell:needLearn(false)
spell:vocation("sorcerer;true", "master sorcerer;true")
spell:onCastSpell(function(creature, variant)
    return combat:execute(creature, variant)
end)
spell:register()
Nocthold.registerSpell("Frost Lattice")
