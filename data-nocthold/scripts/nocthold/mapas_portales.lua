-- Nocthold: portales de los mapas generados con tools/mapas, sin ningún comando.
--
--   Entrada          -> un portal por cada mapa generado (en orden alfabético) que lleva a su entrada.
--                       Va en el punto con nombre del mapa principal que diga el plano ("entrada_mundo:
--                       DUNGEON_TIDAL_VAULT", los huecos de mazmorra del mapa del mundo) o, si no lo
--                       tiene o ese punto no existe en el mapa cargado, junto al templo de la ciudad 1.
--   Dentro del mapa  -> los portales del plano con "destino X: templo" sacan de la mazmorra: al lado
--                       de su portal de entrada si está en el mundo, o al templo del jugador.
--                       Los de "destino X: <punto>" o "X Y Z" ya llevan el destino en el .otbm:
--                       los mueve Canary solo, sin pasar por aquí.
--
-- Action ids: 45200 (al templo) y 45201 en adelante (templo -> mapa). La Forja usa 45101-45106.
-- Los portales del templo se crean en cada arranque: no se guardan en el mapa.

NOCTHOLD_MAPAS = NOCTHOLD_MAPAS or {}
local M = NOCTHOLD_MAPAS

M.ITEM_PORTAL = 1949 -- magic forcefield
M.AID_TEMPLO = 45200 -- el mismo que pone tools/mapas/generar_mapa.py (AID_TEMPLO)
M.AID_PRIMERO = 45201
M.portales = {} -- action id -> { nombre, desde, destino }
M.salidas = {} -- mapa -> dónde se sale (al lado de su portal en el mundo), si no es el templo

function M.nombres()
	local nombres = {}
	for nombre in pairs(Nocthold.mapas or {}) do
		nombres[#nombres + 1] = nombre
	end
	table.sort(nombres)
	return nombres
end

local function libre(p)
	local tile = Tile(p)
	return tile and tile:getGround() and tile:getItemCount() == 0 and not tile:hasProperty(CONST_PROP_BLOCKSOLID)
		and not tile:getTopCreature()
end

function M.casillaLibreCerca(centro)
	for distancia = 2, 6 do
		for dy = -distancia, distancia do
			for dx = -distancia, distancia do
				if math.max(math.abs(dx), math.abs(dy)) == distancia then
					local p = Position(centro.x + dx, centro.y + dy, centro.z)
					if libre(p) then
						return p
					end
				end
			end
		end
	end
	return nil
end

-- Dónde va el portal de entrada de un mapa: en su punto del mundo (o al lado) o junto al templo.
function M.sitioDelPortal(mapa, templo)
	local punto = mapa.entrada_mundo and getWaypointPositionByName(mapa.entrada_mundo)
	if punto then
		return libre(punto) and punto or M.casillaLibreCerca(punto), mapa.entrada_mundo
	end
	if mapa.entrada_mundo then
		logger.warn("[NOCTHOLD] El mapa principal no tiene el punto " .. mapa.entrada_mundo .. ": portal junto al templo.")
	end
	return M.casillaLibreCerca(templo), "templo"
end

-- El mapa generado en el que está una posición (su caja ocupa y sus pisos), o nil.
function M.mapaEn(p)
	for nombre, mapa in pairs(Nocthold.mapas or {}) do
		local o = mapa.ocupa or mapa.caja
		for _, z in ipairs(mapa.pisos or { mapa.z }) do
			if p.z == z and p.x >= o[1] and p.x <= o[3] and p.y >= o[2] and p.y <= o[4] then
				return nombre
			end
		end
	end
	return nil
end

function M.preparar()
	local town = Game.getTowns()[1]
	if not town then
		return false, "el mapa no tiene ciudades"
	end
	local templo = town:getTemplePosition()
	local hechos = {}
	M.salidas = {}
	for i, nombre in ipairs(M.nombres()) do
		local aid = M.AID_PRIMERO + i - 1
		local mapa = Nocthold.mapas[nombre]
		local e = mapa.puntos.entrada
		local destino = Position(e[1], e[2], e[3])
		if not Tile(destino) then
			logger.warn("[NOCTHOLD] El mapa " .. nombre .. " no está cargado (falta su .otbm en world/custom): sin portal.")
		else
			local desde, donde = M.sitioDelPortal(mapa, templo)
			local item = desde and Game.createItem(M.ITEM_PORTAL, 1, desde)
			if not item then
				return false, "no hay sitio para el portal de " .. nombre .. " (" .. donde .. ")"
			end
			item:setActionId(aid)
			M.portales[aid] = { nombre = nombre, desde = desde, destino = destino }
			if donde ~= "templo" then
				-- Al salir de la mazmorra se aparece al lado de su portal, no encima (volvería a entrar).
				M.salidas[nombre] = M.casillaLibreCerca(desde)
			end
			hechos[#hechos + 1] = nombre .. " en " .. donde .. " (" .. desde.x .. "," .. desde.y .. "," .. desde.z .. ")"
		end
	end
	return true, "Portales a los mapas generados: " .. (#hechos > 0 and table.concat(hechos, ", ") or "ninguno")
end

local inicio = GlobalEvent("NoctholdMapasPortales")
function inicio.onStartup()
	local ok, mensaje = M.preparar()
	if ok then
		logger.info("[NOCTHOLD] " .. mensaje)
	else
		logger.error("[NOCTHOLD] " .. mensaje)
	end
	return true
end
inicio:register()

function M.pisar(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then
		return true
	end
	local aid = item:getActionId()
	local destino, texto
	if aid == M.AID_TEMPLO then
		local mapa = M.mapaEn(position)
		destino = mapa and M.salidas and M.salidas[mapa]
		if destino then
			texto = "Sales de " .. mapa:gsub("_", " ") .. "."
		else
			destino = player:getTown():getTemplePosition()
			texto = "Vuelves al templo."
		end
	else
		local portal = M.portales[aid]
		if not portal then
			player:teleportTo(fromPosition, true)
			return true
		end
		destino = portal.destino
		texto = "Entras en " .. portal.nombre:gsub("_", " ") .. "."
	end
	position:sendMagicEffect(CONST_ME_TELEPORT)
	player:teleportTo(destino)
	destino:sendMagicEffect(CONST_ME_TELEPORT)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.latin1("[Nocthold] " .. texto))
	return true
end

-- Un MoveEvent por action id: el del templo y uno por cada mapa que haya (se sabe ya al cargar,
-- porque scripts/lib/nocthold_mapas*.lua se carga antes que los scripts).
local aids = { M.AID_TEMPLO }
for i = 1, #M.nombres() do
	aids[#aids + 1] = M.AID_PRIMERO + i - 1
end
for _, aid in ipairs(aids) do
	local evento = MoveEvent()
	evento:type("stepin")
	function evento.onStepIn(creature, item, position, fromPosition)
		return M.pisar(creature, item, position, fromPosition)
	end
	evento:aid(aid)
	evento:register()
end
