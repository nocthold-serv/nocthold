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

-- Al morir, el monstruo deja de contar en su grupo. Si era el último del grupo y el plano pone un
-- cofre para ese grupo (el jefe final), aparece el cofre (scripts/nocthold/mapas_cofres.lua).
local alMorir = CreatureEvent("NoctholdAggroMuerte")
function alMorir.onDeath(creature)
	local id = A.grupoDe(creature)
	A.porMonstruo[creature:getId()] = nil
	if id and A.grupos[id] then
		local quedan = 0
		for _, m in ipairs(A.monstruosVivos(id)) do
			if m:getId() ~= creature:getId() then
				quedan = quedan + 1
			end
		end
		if quedan == 0 and Nocthold.cofres then
			Nocthold.cofres.alVaciarGrupo(id)
		end
	end
	return true
end
alMorir:register()

-- Al arrancar el servidor, cada mapa del generador (tools/mapas) que traiga grupos en su
-- plano los coloca solo, dormidos y con su zona. No hace falta ningún comando.
local alArrancar = GlobalEvent("NoctholdAggroArranque")
function alArrancar.onStartup()
	local nombres = {}
	for nombre, mapa in pairs(Nocthold.mapas or {}) do
		if mapa.grupos and next(mapa.grupos) then
			nombres[#nombres + 1] = nombre
		end
	end
	table.sort(nombres)
	for _, nombre in ipairs(nombres) do
		local p = Nocthold.mapas[nombre].puntos.entrada
		if p and Tile(Position(p[1], p[2], p[3])) then
			A.prepararMapa(nombre)
		end
	end
	return true
end
alArrancar:register()
