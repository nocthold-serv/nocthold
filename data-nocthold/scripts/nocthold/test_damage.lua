-- Nocthold - "golpe de prueba" para probar la mazmorra rápido.
-- Un GOD lo activa a un jugador usando sobre él su vara de pruebas (god_tools.lua). Mientras está activo, cualquier
-- golpe o hechizo de ese jugador mata de un golpe a los monstruos normales de Nocthold y a
-- los jefes les quita un 25 % (4 golpes, así se ven sus dos fases). Solo afecta a nuestros
-- 7 monstruos, no toca ningún objeto y se borra al reiniciar el servidor.

Nocthold.testDamage = Nocthold.testDamage or {}
Nocthold.testDamageBossShare = 0.25

-- Daño que hace un jugador con el golpe de prueba activo, o nil si no lo tiene.
function Nocthold.testDamageFor(monster, attacker)
	if not attacker or not attacker:isPlayer() or not Nocthold.testDamage[attacker:getGuid()] then
		return nil
	end
	local maxHealth = monster:getMaxHealth()
	local monsterType = monster:getType()
	if monsterType and monsterType:isRewardBoss() then
		return math.ceil(maxHealth * Nocthold.testDamageBossShare)
	end
	return maxHealth
end

local testDamage = CreatureEvent("NoctholdTestDamage")
function testDamage.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	-- Solo daño (no curas) y solo si el atacante tiene el golpe de prueba.
	if creature and primaryType ~= COMBAT_HEALING then
		local damage = Nocthold.testDamageFor(creature, attacker)
		if damage then
			return damage, primaryType, 0, secondaryType
		end
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
testDamage:register()
