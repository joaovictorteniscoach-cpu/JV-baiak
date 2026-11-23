-- Mesmo subId usado no motor: nao interfere nas outras magias de atributos.
local vampirismo = Condition(CONDITION_ATTRIBUTES)
vampirismo:setParameter(CONDITION_PARAM_SUBID, 8420)
vampirismo:setParameter(CONDITION_PARAM_TICKS, 20000)
vampirismo:setParameter(CONDITION_PARAM_BUFF_SPELL, true)

function onCastSpell(creature, variant)
    creature:addCondition(vampirismo)
    creature:getPosition():sendMagicEffect(CONST_ME_MAGIC_RED)
    return true
end
