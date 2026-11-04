-- Nocthold
-- Temporary mitigation prototype: increases the existing shielding skill by 25% for 6 seconds.
-- This is a bridge to the dedicated damage-reduction layer planned for a later release.

local spell = Spell("instant")
spell:name("Fortress Stance")
spell:words("stal mur")
spell:id(1006)
spell:group("support")
spell:cooldown(18000)
spell:groupCooldown(1000)
spell:level(4)
spell:mana(20)
spell:needTarget(false)
spell:isSelfTarget(true)
spell:allowOnSelf(true)
spell:isAggressive(false)
spell:needLearn(false)
spell:vocation("knight;true", "elite knight;true")
spell:onCastSpell(function(creature, variant)
    local condition = Condition(CONDITION_ATTRIBUTES)
    condition:setParameter(CONDITION_PARAM_TICKS, 6000)
    condition:setParameter(CONDITION_PARAM_SKILL_SHIELDPERCENT, 125)
    creature:addCondition(condition)
    creature:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
    return true
end)
spell:register()
Nocthold.registerSpell("Fortress Stance")
