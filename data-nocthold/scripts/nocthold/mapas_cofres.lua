-- Nocthold: el cofre del jefe final en los mapas del generador (tools/mapas: "cofre C: j").
--
--   * Mientras vive el jefe no hay cofre. Cuando muere el último monstruo de su grupo (aggro),
--     aparece un cofre del tesoro en la casilla 'C' del plano, con un aviso a los que estén dentro.
--   * Lo abre cualquier jugador (usar, sin comandos). Se abre UNA vez: reparte "premios" objetos
--     al azar del botín del plano, cada uno a un jugador al azar del grupo (el que lo abre y los de su
--     party que estén dentro de la mazmorra), y desaparece.
--   * Vuelve a salir solo si se vuelve a matar al jefe, es decir, cuando se rehace la mazmorra
--     (Nocthold.aggro.prepararMapa quita el cofre que quedara y vuelve a poner los monstruos).
--
-- Action id 45300. Los portales de los mapas usan 45200+, La Forja 45101-45106.

Nocthold = Nocthold or {}
Nocthold.cofres = Nocthold.cofres or { activos = {} }

local C = Nocthold.cofres
C.ITEM = 4073 -- treasure chest: no se mueve, no se puede pisar y da luz
C.AID = 45300

local function clave(pos)
	return pos.x .. "," .. pos.y .. "," .. pos.z
end

local function decir(jugador, texto)
	jugador:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.latin1("[Nocthold] " .. texto))
end

-- Jugadores dentro de la mazmorra (la caja que ocupa, en sus pisos).
function C.dentro(nombre)
	local mapa = Nocthold.mapas and Nocthold.mapas[nombre]
	local lista = {}
	if not mapa then
		return lista
	end
	local o = mapa.ocupa or mapa.caja
	local pisos = {}
	for _, z in ipairs(mapa.pisos or { mapa.z }) do
		pisos[z] = true
	end
	for _, jugador in ipairs(Game.getPlayers()) do
		local p = jugador:getPosition()
		if pisos[p.z] and p.x >= o[1] and p.x <= o[3] and p.y >= o[2] and p.y <= o[4] then
			lista[#lista + 1] = jugador
		end
	end
	return lista
end

-- Quien abre el cofre y los de su party que estén dentro de la mazmorra.
function C.participantes(abre, nombre)
	local lista = { abre }
	local party = abre:getParty()
	local lider = party and party:getLeader()
	if not lider then
		return lista
	end
	for _, jugador in ipairs(C.dentro(nombre)) do
		local suya = jugador:getParty()
		local suLider = suya and suya:getLeader()
		if suLider and suLider:getId() == lider:getId() and jugador:getId() ~= abre:getId() then
			lista[#lista + 1] = jugador
		end
	end
	return lista
end

-- Pone el cofre de "datos" (una entrada de mapa.cofres) en su casilla. Devuelve el objeto o nil.
function C.aparecer(nombre, datos)
	local pos = Position(datos[1], datos[2], datos[3])
	local tile = Tile(pos)
	if not tile then
		logger.error("[NOCTHOLD] Cofre de " .. nombre .. ": no existe la casilla " .. clave(pos))
		return nil
	end
	local cofre = tile:getItemById(C.ITEM) or Game.createItem(C.ITEM, 1, pos)
	if not cofre then
		logger.error("[NOCTHOLD] Cofre de " .. nombre .. ": no se pudo crear en " .. clave(pos))
		return nil
	end
	cofre:setActionId(C.AID)
	C.activos[clave(pos)] = { mapa = nombre, datos = datos }
	pos:sendMagicEffect(CONST_ME_TELEPORT)
	for _, jugador in ipairs(C.dentro(nombre)) do
		decir(jugador, "El jefe ha caído. Ha aparecido su cofre: solo se puede abrir una vez.")
	end
	logger.info("[NOCTHOLD] Cofre de " .. nombre .. " en " .. clave(pos))
	return cofre
end

-- Lo llama la zona de aggro cuando muere el último monstruo de un grupo ("mapa.letra").
function C.alVaciarGrupo(id)
	local nombre, letra = tostring(id):match("^(.+)%.(%l)$")
	local mapa = nombre and Nocthold.mapas and Nocthold.mapas[nombre]
	for _, datos in ipairs(mapa and mapa.cofres or {}) do
		if datos.grupo == letra then
			C.aparecer(nombre, datos)
		end
	end
end

-- Quita los cofres que queden de un mapa (al rehacer la mazmorra).
function C.quitarDe(nombre)
	for k, activo in pairs(C.activos) do
		if activo.mapa == nombre then
			C.activos[k] = nil
		end
	end
	local mapa = Nocthold.mapas and Nocthold.mapas[nombre]
	for _, datos in ipairs(mapa and mapa.cofres or {}) do
		local tile = Tile(Position(datos[1], datos[2], datos[3]))
		local cofre = tile and tile:getItemById(C.ITEM)
		if cofre then
			cofre:remove()
		end
	end
end

-- Reparte los premios. Devuelve la lista { {jugador, id, cantidad}, ... }.
function C.repartir(datos, jugadores, pos)
	local dados = {}
	for _ = 1, datos.premios or 1 do
		local premio = datos.botin[math.random(#datos.botin)]
		local jugador = jugadores[math.random(#jugadores)]
		local id, cantidad = premio[1], premio[2] or 1
		-- Si no le cabe (peso o mochila llena), se queda en el suelo junto al cofre.
		if not jugador:addItem(id, cantidad) then
			Game.createItem(id, cantidad, pos)
		end
		dados[#dados + 1] = { jugador, id, cantidad }
	end
	for _, quien in ipairs(jugadores) do
		for _, d in ipairs(dados) do
			local nombreObjeto = ItemType(d[2]):getName()
			decir(quien, d[1]:getName() .. " recibe " .. (d[3] > 1 and (d[3] .. " x ") or "") .. nombreObjeto .. " del cofre.")
		end
	end
	return dados
end

-- Abre el cofre: devuelve true y lo repartido, o false si ese cofre ya se abrió.
function C.abrir(jugador, cofre)
	local pos = cofre:getPosition()
	local activo = C.activos[clave(pos)]
	if not activo then
		return false
	end
	C.activos[clave(pos)] = nil
	cofre:remove()
	pos:sendMagicEffect(CONST_ME_MAGIC_BLUE)
	return true, C.repartir(activo.datos, C.participantes(jugador, activo.mapa), pos)
end

local usar = Action()
function usar.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not C.abrir(player, item) then
		decir(player, "Este cofre ya está vacío.")
	end
	return true
end
usar:aid(C.AID)
usar:register()
