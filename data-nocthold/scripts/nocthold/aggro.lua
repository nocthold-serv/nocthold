-- Nocthold: eventos de las zonas de aggro (la lógica está en scripts/lib/nocthold_aggro.lua).

local A = Nocthold.aggro

-- Un jugador entra en la zona invisible de un grupo dormido: se despierta el grupo entero.
local alEntrar = EventCallback("NoctholdAggroZona", true)
function alEntrar.zoneAfterCreatureEnter(zone, creature)
	local id = A.porZona[zone:getName()]
	if id and A.esProvocador(creature) then
		A.despertar(id, creature)
	end
	return true
end
alEntrar:register()

-- Cualquier daño a un monstruo dormido despierta a su grupo (si se lo hace un jugador o su
-- invocación, todos van a por él). Las curas no cuentan.
local alRecibirDano = CreatureEvent("NoctholdAggroDano")
function alRecibirDano.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if primaryType ~= COMBAT_HEALING and creature then
		local id = A.grupoDe(creature)
		local g = id and A.grupos[id]
		if g and not g.despierto then
			A.despertar(id, A.esProvocador(attacker) and attacker or nil)
		end
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end
alRecibirDano:register()

-- Al morir, el monstruo deja de contar en su grupo.
local alMorir = CreatureEvent("NoctholdAggroMuerte")
function alMorir.onDeath(creature)
	A.porMonstruo[creature:getId()] = nil
	return true
end
alMorir:register()
