-- Nocthold: entrada a La Forja Caída sin comandos.
--
--   Portal junto al templo   -> lleva a la sala de entrada (la de los 5 NPC).
--   Cronista de Llaves       -> da la piedra-llave del nivel que pidas (npc/nocthold_npcs.lua).
--   Altar de la entrada      -> el líder lo usa con la piedra-llave encima: entra el grupo y empieza.
--   Barrera del pasillo      -> solo pasan los de la expedición (para volver tras morir).
--   Portal de la entrada     -> vuelve al templo.
--   Portal de la última sala -> aparece al terminar y te saca de la expedición.
--
-- Todo se crea al arrancar el servidor, encima de la sala de encounter_runtime.lua. Los objetos
-- puestos así no se guardan en el mapa: se vuelven a crear en cada arranque.

NOCTHOLD_DUNGEON = NOCTHOLD_DUNGEON or {}
local U = NOCTHOLD_DUNGEON

U.ITEM_PORTAL = 1949 -- magic forcefield
U.ITEM_ALTAR = 3515 -- altar
U.ITEM_KEY = 3235 -- ancient rune: la piedra-llave (no se apila, se puede coger)
U.AID_TO_LOBBY = 45101
U.AID_TO_TOWN = 45102
U.AID_BARRIER = 45103
U.AID_ALTAR = 45104
U.AID_FINISH = 45105
U.AID_KEY = 45106
U.KEY_ATTRIBUTE = "nocthold_llave"

local function tell(player, message)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.latin1("[Nocthold] " .. message))
end

-- Piedra-llave -----------------------------------------------------------------------------

local function isKey(item)
	return item and item:getId() == U.ITEM_KEY and item:getActionId() == U.AID_KEY
end

-- Todas las piedras-llave que lleva el jugador (equipo y mochilas, a cualquier profundidad).
function U.findKeys(player)
	local keys = {}
	for slot = CONST_SLOT_FIRST, CONST_SLOT_LAST do
		local item = player:getSlotItem(slot)
		if item then
			if isKey(item) then
				keys[#keys + 1] = item
			end
			if item:isContainer() then
				for _, inner in ipairs(item:getItems(true)) do
					if isKey(inner) then
						keys[#keys + 1] = inner
					end
				end
			end
		end
	end
	return keys
end

function U.keyLevel(item)
	return tonumber(item:getCustomAttribute(U.KEY_ATTRIBUTE)) or 0
end

function U.setKeyLevel(item, level)
	item:setActionId(U.AID_KEY)
	item:setCustomAttribute(U.KEY_ATTRIBUTE, level)
	item:setAttribute(ITEM_ATTRIBUTE_NAME, Nocthold.latin1("piedra-llave de la Forja Caída (nivel " .. level .. ")"))
	item:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, Nocthold.latin1("Úsala en el altar de la entrada de La Forja Caída. Sube de nivel si terminas a tiempo."))
	return true
end

-- Cambia la piedra que lleve el jugador por una nueva de ese nivel (solo una por jugador).
function U.giveKey(player, level)
	for _, old in ipairs(U.findKeys(player)) do
		old:remove()
	end
	local item = player:addItem(U.ITEM_KEY, 1)
	if not item then
		return nil
	end
	U.setKeyLevel(item, level)
	return item
end

-- Al terminar a tiempo, encounter_runtime.lua sube la piedra del líder.
function U.upgradeKey(guid, level)
	for _, player in ipairs(Game.getPlayers()) do
		if player:getGuid() == guid then
			local key = U.findKeys(player)[1]
			if key then
				return U.setKeyLevel(key, level)
			end
			return false
		end
	end
	return false
end

-- Altar --------------------------------------------------------------------------------------

function U.useAltar(player)
	local r = U.run
	if r then
		if U.godReset and U.godReset(player) then
			return false
		end
		if r.players[player:getGuid()] then
			tell(player, "Tu expedición ya está en marcha. Cruza la barrera del pasillo para volver.")
		else
			tell(player, "La Forja Caída está ocupada por otra expedición. Espera a que termine.")
		end
		return false
	end
	local key = U.findKeys(player)[1]
	if not key then
		tell(player, "El altar no reacciona. Necesitas una piedra-llave: pídesela al Cronista de Llaves.")
		return false
	end
	if not U.enter(player, U.keyLevel(key)) then
		return false
	end
	return U.start(player)
end

-- Colocar los objetos -------------------------------------------------------------------------

local function placeItem(itemId, position, actionId)
	local item = Game.createItem(itemId, 1, position)
	if not item then
		return nil
	end
	item:setActionId(actionId)
	return item
end

-- Primera casilla libre cerca del templo (sin paredes, objetos ni el propio templo).
local function freeTileNear(center)
	for distance = 2, 4 do
		for dy = -distance, distance do
			for dx = -distance, distance do
				if math.max(math.abs(dx), math.abs(dy)) == distance then
					local p = Position(center.x + dx, center.y + dy, center.z)
					local tile = Tile(p)
					if tile and tile:getGround() and tile:getItemCount() == 0 and not tile:hasProperty(CONST_PROP_BLOCKSOLID) and not tile:getTopCreature() then
						return p
					end
				end
			end
		end
	end
	return nil
end

function U.openFinishPortal()
	U.closeFinishPortal()
	U.finishPortal = placeItem(U.ITEM_PORTAL, U.layoutPos("finishPortal"), U.AID_FINISH)
	return U.finishPortal ~= nil
end

function U.closeFinishPortal()
	local tile = Tile(U.layoutPos("finishPortal"))
	local item = tile and tile:getItemById(U.ITEM_PORTAL)
	if item then
		item:remove()
	end
	U.finishPortal = nil
end

-- Sala, NPC, altar, barrera y portales. Devuelve true o false y un texto para el log.
function U.setupWorld()
	local town = Game.getTowns()[1]
	if not town then
		return false, "el mapa no tiene ciudades: no sé dónde poner el portal."
	end
	local temple = town:getTemplePosition()
	local templeTile = Tile(temple)
	if not templeTile or not templeTile:getGround() then
		return false, "no hay suelo en el templo " .. temple.x .. "," .. temple.y .. "," .. temple.z
	end
	local ok, message = U.buildMap(templeTile:getGround():getId())
	if not ok then
		return false, message
	end
	if U.worldReady then
		return true, message
	end

	if not placeItem(U.ITEM_ALTAR, U.layoutPos("altar"), U.AID_ALTAR) then
		return false, "no se pudo poner el altar."
	end
	if not placeItem(U.ITEM_PORTAL, U.layoutPos("exitPortal"), U.AID_TO_TOWN) then
		return false, "no se pudo poner el portal de salida de la entrada."
	end
	local b = U.layout.barrier
	for y = b[2], b[3] do
		local ground = Tile(U.pos(b[1], y)):getGround()
		ground:setActionId(U.AID_BARRIER)
	end
	local portalPos = freeTileNear(temple)
	if not portalPos then
		return false, "no hay ninguna casilla libre cerca del templo para el portal."
	end
	if not placeItem(U.ITEM_PORTAL, portalPos, U.AID_TO_LOBBY) then
		return false, "no se pudo poner el portal del templo."
	end
	U.townPortal = portalPos
	U.worldReady = true
	return true, message .. " Portal del templo en " .. portalPos.x .. "," .. portalPos.y .. "," .. portalPos.z .. "."
end

local startup = GlobalEvent("NoctholdDungeonSetup")
function startup.onStartup()
	local ok, message = U.setupWorld()
	if ok then
		logger.info("[NOCTHOLD] " .. message)
	else
		logger.error("[NOCTHOLD] La Forja Caída no se ha podido preparar: " .. message)
	end
	return true
end
startup:register()

-- Pisar y usar ---------------------------------------------------------------------------------

local function teleport(player, position)
	local from = player:getPosition()
	player:teleportTo(position)
	from:sendMagicEffect(CONST_ME_TELEPORT)
	position:sendMagicEffect(CONST_ME_TELEPORT)
end

-- Cada casilla con su acción. Devuelven lo que espera Canary de un onStepIn.
function U.stepToLobby(player)
	if not U.mapReady then
		tell(player, "El portal está apagado. Avisa a un administrador.")
		return false
	end
	teleport(player, U.layoutPos("arrival"))
	tell(player, "Bienvenido a la entrada de La Forja Caída. El Cronista de Llaves te dará una piedra-llave.")
	return true
end

function U.stepToTown(player)
	local town = player:getTown()
	teleport(player, town and town:getTemplePosition() or U.townPortal)
	return true
end

function U.stepBarrier(player, fromPosition)
	-- Hacia la entrada siempre se puede; hacia dentro solo los de la expedición.
	if fromPosition.x > player:getPosition().x or U.canPass(player) then
		return true
	end
	player:teleportTo(fromPosition, true)
	if U.run then
		tell(player, "Una fuerza te impide pasar: la mazmorra está ocupada por otra expedición.")
	else
		tell(player, "Una fuerza te impide pasar. Usa tu piedra-llave en el altar para empezar.")
	end
	return true
end

function U.stepFinish(player)
	if U.run and U.run.players[player:getGuid()] then
		return U.leave(player)
	end
	teleport(player, U.layoutPos("arrival"))
	return true
end

local function stepEvent(actionId, handler)
	local event = MoveEvent()
	event:type("stepin")
	function event.onStepIn(creature, item, position, fromPosition)
		if not creature:isPlayer() then
			return true
		end
		handler(creature, fromPosition)
		return true
	end
	event:aid(actionId)
	event:register()
end

stepEvent(U.AID_TO_LOBBY, U.stepToLobby)
stepEvent(U.AID_TO_TOWN, U.stepToTown)
stepEvent(U.AID_BARRIER, U.stepBarrier)
stepEvent(U.AID_FINISH, U.stepFinish)

local altar = Action()
function altar.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	U.useAltar(player)
	return true
end
altar:aid(U.AID_ALTAR)
altar:register()

-- Usar la piedra-llave (doble clic) también vale si estás junto al altar.
local key = Action()
function key.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local altarPos = U.layoutPos("altar")
	local p = player:getPosition()
	if p.z == altarPos.z and math.abs(p.x - altarPos.x) <= 1 and math.abs(p.y - altarPos.y) <= 1 then
		U.useAltar(player)
	else
		tell(player, "Piedra-llave de nivel " .. U.keyLevel(item) .. ". Úsala junto al altar de la entrada de La Forja Caída.")
	end
	return true
end
key:aid(U.AID_KEY)
key:register()
