-- Nocthold: herramientas de prueba del GOD sin comandos.
--
--   Vara de pruebas (palanca, en la mochila de todo GOD al entrar al juego):
--     usarla sobre un jugador  -> activa o quita su golpe de prueba (ver test_damage.lua)
--     usarla sin más           -> lo activa o lo quita para el propio GOD
--   Altar de La Forja Caída con una expedición en marcha -> el GOD la vacía (reset).
--   Piedra-llave de cualquier nivel -> Cronista de Llaves, como cualquier jugador.
--   Ir a la mazmorra -> portal junto al templo; el GOD cruza la barrera siempre.

NOCTHOLD_DUNGEON = NOCTHOLD_DUNGEON or {}
local U = NOCTHOLD_DUNGEON

Nocthold.GOD_WAND = 3304 -- crowbar: se puede usar "con" un jugador
Nocthold.AID_GOD_WAND = 45107

local function tell(player, message)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.latin1(message))
end

local function hasWand(player)
	for slot = CONST_SLOT_FIRST, CONST_SLOT_LAST do
		local item = player:getSlotItem(slot)
		if item then
			if item:getId() == Nocthold.GOD_WAND and item:getActionId() == Nocthold.AID_GOD_WAND then
				return true
			end
			if item:isContainer() then
				for _, inner in ipairs(item:getItems(true)) do
					if inner:getId() == Nocthold.GOD_WAND and inner:getActionId() == Nocthold.AID_GOD_WAND then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Da la vara a un GOD que no la tenga. Devuelve true si se la ha dado.
function Nocthold.giveGodWand(player)
	if not player:getGroup():getAccess() or hasWand(player) then
		return false
	end
	local item = player:addItem(Nocthold.GOD_WAND, 1)
	if not item then
		return false
	end
	item:setActionId(Nocthold.AID_GOD_WAND)
	item:setAttribute(ITEM_ATTRIBUTE_NAME, "vara de pruebas")
	item:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, Nocthold.latin1("Solo GOD. Úsala sobre un jugador para darle o quitarle el golpe de prueba; úsala sin más para ti."))
	return true
end

-- Activa o quita el golpe de prueba de target. Devuelve el estado nuevo.
function Nocthold.toggleTestDamage(god, target)
	local guid = target:getGuid()
	local active = not Nocthold.testDamage[guid]
	Nocthold.testDamage[guid] = active or nil
	local state = active and "ACTIVADO: mata de un golpe a los monstruos de Nocthold y a los jefes les quita un 25 %." or "DESACTIVADO."
	tell(god, "Golpe de prueba para " .. target:getName() .. " " .. state)
	if target:getGuid() ~= god:getGuid() then
		tell(target, "Golpe de prueba " .. state)
	end
	return active
end

local login = CreatureEvent("NoctholdGodTools")
function login.onLogin(player)
	if Nocthold.giveGodWand(player) then
		tell(player, "Tienes la vara de pruebas en la mochila.")
	end
	return true
end
login:register()

local wand = Action()
function wand.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not player:getGroup():getAccess() then
		item:remove()
		return true
	end
	local who = player
	if target and type(target) == "userdata" and target.isPlayer and target:isPlayer() then
		who = target
	end
	Nocthold.toggleTestDamage(player, who)
	return true
end
wand:aid(Nocthold.AID_GOD_WAND)
wand:register()

-- Lo usa el altar (dungeon_entrance.lua): un GOD con una expedición en marcha la vacía.
function U.godReset(player)
	if not U.run or not player:getGroup():getAccess() then
		return false
	end
	U.reset(true)
	tell(player, "La Forja Caída queda libre: monstruos quitados y jugadores a la entrada.")
	return true
end
