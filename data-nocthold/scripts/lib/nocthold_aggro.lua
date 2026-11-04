-- Nocthold: zonas de aggro (como los "pulls" de una mazmorra de WoW).
--
-- Cada grupo de monstruos tiene una zona invisible (una caja alrededor de sus monstruos más
-- "radio" casillas). Mientras nadie entra en ella, el grupo está DORMIDO: ve a los jugadores
-- pero no los ataca ni se mueve (monster:setDormant, cambio nuestro en el motor de Canary).
-- El grupo entero se despierta a la vez cuando:
--   * un jugador (o su invocación) entra en la zona, o
--   * cualquiera de sus monstruos recibe daño (por ejemplo, un ataque a distancia desde fuera).
-- Una vez despierto se comporta como un monstruo normal de Tibia.
--
-- Los eventos (entrar en la zona, recibir daño) se registran en scripts/nocthold/aggro.lua.
-- Los mapas del generador (tools/mapas) traen los grupos en Nocthold.mapas[m].grupos;
-- Nocthold.aggro.prepararMapa(nombre) crea sus monstruos dormidos con su zona.

Nocthold = Nocthold or {}
Nocthold.aggro = Nocthold.aggro or {
	grupos = {}, -- id -> { zona, nombreZona, monstruos = {ids}, despierto, desde, hasta, radio }
	porMonstruo = {}, -- id del monstruo -> id del grupo
	porZona = {}, -- nombre de la zona -> id del grupo
	creadas = 0, -- cada grupo nuevo usa una zona con nombre nuevo (ver crearGrupo)
	provocadores = {}, -- solo para la prueba automática: ids de criaturas que cuentan como jugador
}

local A = Nocthold.aggro
A.radioPorDefecto = 3
A.prefijoZona = "nocthold.aggro."

local function log(texto)
	logger.info("[NOCTHOLD-AGGRO] " .. texto)
end

-- ¿Esta criatura despierta a un grupo al entrar en su zona o al pegarle?
-- Jugadores normales (no GM/GOD) y sus invocaciones.
function A.esProvocador(criatura)
	if not criatura then
		return false
	end
	if A.provocadores[criatura:getId()] then
		return true
	end
	local master = criatura:getMaster()
	if master and master:isPlayer() then
		criatura = master
	end
	if not criatura:isPlayer() then
		return false
	end
	local grupo = criatura:getGroup()
	return not (grupo and grupo:getAccess())
end

function A.grupoDe(monstruo)
	return monstruo and A.porMonstruo[monstruo:getId()] or nil
end

function A.monstruosVivos(id)
	local g = A.grupos[id]
	local vivos = {}
	if g then
		for _, mid in ipairs(g.monstruos) do
			local m = Monster(mid)
			if m and not m:isRemoved() and m:getHealth() > 0 then
				vivos[#vivos + 1] = m
			end
		end
	end
	return vivos
end

-- Despierta al grupo entero. "culpable" (opcional) es quien lo ha provocado: todos van a por él.
function A.despertar(id, culpable)
	local g = A.grupos[id]
	if not g or g.despierto then
		return false
	end
	g.despierto = true
	for _, m in ipairs(A.monstruosVivos(id)) do
		m:setDormant(false)
		local elegido = false
		if culpable and not culpable:isRemoved() then
			m:addTarget(culpable, true)
			elegido = m:selectTarget(culpable)
		end
		if not elegido then
			m:searchTarget()
		end
	end
	log("grupo " .. id .. " despierto" .. (culpable and (" por " .. culpable:getName()) or ""))
	return true
end

-- Crea (o rehace) un grupo con monstruos ya creados. Todos deben estar en el mismo piso.
-- Devuelve el grupo, o nil y el motivo.
function A.crearGrupo(id, monstruos, radio)
	if #monstruos == 0 then
		return nil, "el grupo " .. id .. " no tiene monstruos"
	end
	radio = radio or A.radioPorDefecto
	local p0 = monstruos[1]:getPosition()
	local x1, y1, x2, y2, z = p0.x, p0.y, p0.x, p0.y, p0.z
	for _, m in ipairs(monstruos) do
		local p = m:getPosition()
		if p.z ~= z then
			return nil, "el grupo " .. id .. " tiene monstruos en pisos distintos"
		end
		x1, y1 = math.min(x1, p.x), math.min(y1, p.y)
		x2, y2 = math.max(x2, p.x), math.max(y2, p.y)
	end

	A.quitarGrupo(id, false)
	local desde = Position(x1 - radio, y1 - radio, z)
	local hasta = Position(x2 + radio, y2 + radio, z)
	-- Nombre de zona nuevo cada vez: Canary guarda en cada casilla las zonas que la tocan y
	-- no lo limpia al quitar un área, así que una zona vieja nunca se reutiliza (y como ya
	-- no está en porZona, el evento de entrar la ignora).
	A.creadas = A.creadas + 1
	local nombreZona = A.prefijoZona .. id .. "#" .. A.creadas
	local zona = Zone(nombreZona)
	zona:addArea(desde, hasta)

	local g = { zona = zona, nombreZona = nombreZona, monstruos = {}, despierto = false, desde = desde, hasta = hasta, radio = radio }
	A.grupos[id] = g
	A.porZona[nombreZona] = id
	for _, m in ipairs(monstruos) do
		m:setDormant(true)
		m:registerEvent("NoctholdAggroDano")
		m:registerEvent("NoctholdAggroMuerte")
		g.monstruos[#g.monstruos + 1] = m:getId()
		A.porMonstruo[m:getId()] = id
	end

	-- Si ya hay alguien dentro (p. ej. se creó el grupo encima de un jugador), se despierta ya.
	for _, criatura in ipairs(zona:getCreatures()) do
		if A.esProvocador(criatura) then
			A.despertar(id, criatura)
			break
		end
	end
	return g
end

-- Borra la zona del grupo y, si quitarMonstruos no es false, también sus monstruos vivos.
function A.quitarGrupo(id, quitarMonstruos)
	local g = A.grupos[id]
	if not g then
		return false
	end
	for _, m in ipairs(A.monstruosVivos(id)) do
		if quitarMonstruos ~= false then
			m:remove()
		end
	end
	for _, mid in ipairs(g.monstruos) do
		A.porMonstruo[mid] = nil
	end
	g.zona:subtractArea(g.desde, g.hasta)
	A.porZona[g.nombreZona] = nil
	A.grupos[id] = nil
	return true
end

-- Crea los grupos de un mapa del generador (Nocthold.mapas[nombre].grupos), dormidos.
-- Si ya estaban, los quita y los vuelve a crear. Devuelve grupos creados, monstruos creados
-- y una lista de avisos (texto) para enseñar a quien lo pidió.
function A.prepararMapa(nombre)
	local mapa = Nocthold.mapas and Nocthold.mapas[nombre]
	local avisos = {}
	if not mapa then
		return 0, 0, { "no existe el mapa " .. tostring(nombre) }
	end
	local claves = {}
	for clave in pairs(mapa.grupos or {}) do
		claves[#claves + 1] = clave
	end
	table.sort(claves, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)

	-- Mazmorra rehecha: el cofre del jefe de la vez anterior (si nadie lo abrió) se va.
	if Nocthold.cofres then
		Nocthold.cofres.quitarDe(nombre)
	end
	local grupos, total = 0, 0
	for _, clave in ipairs(claves) do
		local datos = mapa.grupos[clave]
		local id = nombre .. "." .. clave
		A.quitarGrupo(id)
		local creados = {}
		for _, p in ipairs(datos.monstruos or {}) do
			if not p[4] then
				avisos[#avisos + 1] = "pull " .. clave .. ": una letra sin 'grupo X: monstruo' en el plano"
			else
				local m = Game.createMonster(Nocthold.latin1(p[4]), Position(p[1], p[2], p[3]), true, true)
				if m then
					m:setDormant(true)
					creados[#creados + 1] = m
				else
					avisos[#avisos + 1] = "no se pudo crear " .. p[4] .. " en " .. p[1] .. "," .. p[2] .. "," .. p[3]
				end
			end
		end
		if #creados > 0 then
			local g, motivo = A.crearGrupo(id, creados, datos.radio)
			if g then
				grupos = grupos + 1
				total = total + #creados
			elseif motivo then
				avisos[#avisos + 1] = motivo
			end
		end
	end
	for _, aviso in ipairs(avisos) do
		logger.warn("[NOCTHOLD-AGGRO] " .. nombre .. ": " .. aviso)
	end
	log(nombre .. ": " .. grupos .. " grupos y " .. total .. " monstruos dormidos")
	return grupos, total, avisos
end

-- Enseña el borde de la zona del grupo con un efecto (para probar con /nocthold aggro).
function A.ensenarZona(id)
	local g = A.grupos[id]
	if not g then
		return false
	end
	local d, h = g.desde, g.hasta
	for x = d.x, h.x do
		for y = d.y, h.y do
			if x == d.x or x == h.x or y == d.y or y == h.y then
				Position(x, y, d.z):sendMagicEffect(CONST_ME_MAGIC_GREEN)
			end
		end
	end
	return true
end
