-- Nocthold: portales de los mapas generados con tools/mapas, sin ningún comando.
--
--   Junto al templo  -> un portal por cada mapa generado (en orden alfabético) que lleva a su entrada.
--   Dentro del mapa  -> los portales del plano con "destino X: templo" llevan al templo del jugador.
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

function M.nombres()
	local nombres = {}
	for nombre in pairs(Nocthold.mapas or {}) do
		nombres[#nombres + 1] = nombre
	end
	table.sort(nombres)
	return nombres
end

function M.casillaLibreCerca(centro)
	for distancia = 2, 6 do
		for dy = -distancia, distancia do
			for dx = -distancia, distancia do
				if math.max(math.abs(dx), math.abs(dy)) == distancia then
					local p = Position(centro.x + dx, centro.y + dy, centro.z)
					local tile = Tile(p)
					if tile and tile:getGround() and tile:getItemCount() == 0 and not tile:hasProperty(CONST_PROP_BLOCKSOLID)
						and not tile:getTopCreature() then
						return p
					end
				end
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
	for i, nombre in ipairs(M.nombres()) do
		local aid = M.AID_PRIMERO + i - 1
		local e = Nocthold.mapas[nombre].puntos.entrada
		local destino = Position(e[1], e[2], e[3])
		if not Tile(destino) then
			logger.warn("[NOCTHOLD] El mapa " .. nombre .. " no está cargado (falta su .otbm en world/custom): sin portal.")
		else
			local desde = M.casillaLibreCerca(templo)
			local item = desde and Game.createItem(M.ITEM_PORTAL, 1, desde)
			if not item then
				return false, "no hay sitio junto al templo para el portal de " .. nombre
			end
			item:setActionId(aid)
			M.portales[aid] = { nombre = nombre, desde = desde, destino = destino }
			hechos[#hechos + 1] = nombre .. " (" .. desde.x .. "," .. desde.y .. "," .. desde.z .. ")"
		end
	end
	return true, "Portales a los mapas generados junto al templo: " .. (#hechos > 0 and table.concat(hechos, ", ") or "ninguno")
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
		destino = player:getTown():getTemplePosition()
		texto = "Vuelves al templo."
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
