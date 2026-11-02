-- Nocthold 1.0.0-alpha.1 public commands.
-- Admin map creation is guarded by group access. All commands are server-authoritative.
local talk = TalkAction("!nocthold")

local function reply(player, text)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, Nocthold.latin1("[Nocthold] " .. text))
end

function talk.onSay(player, words, param)
    local args = {}
    for token in string.gmatch((param or ""):lower(), "%S+") do args[#args + 1] = token end
    local command = args[1] or "help"
    local U = NOCTHOLD_DUNGEON
    if not U then reply(player, "El runtime de mazmorra no ha cargado.") return false end

    if command == "help" then
        reply(player, "Comandos: !nocthold key 0-10 | enter | rejoin | start | status | leave. GOD: !nocthold buildmap | reset")
        return true
    elseif command == "buildmap" then
        if not player:getGroup():getAccess() then
            reply(player, "Solo administradores pueden generar el mapa.")
            return true
        end
        U.buildMap(player)
        return true
    elseif command == "key" then
        local level = tonumber(args[2])
        if not level or level < 0 or level > 10 or level % 1 ~= 0 then
            reply(player, "Uso: !nocthold key 0-10.")
            return true
        end
        if U.run then reply(player, "No puedes cambiar la llave durante una expedicion.") return true end
        U.nextKey[player:getGuid()] = level
        reply(player, "Siguiente llave configurada: " .. level .. ".")
        return true
    elseif command == "enter" then
        U.enter(player)
        return true
    elseif command == "rejoin" then
        U.rejoin(player)
        return true
    elseif command == "start" then
        U.start(player)
        return true
    elseif command == "status" then
        U.status(player)
        return true
    elseif command == "leave" then
        U.leave(player)
        return true
    elseif command == "reset" then
        if not player:getGroup():getAccess() then reply(player, "Solo administradores.") return true end
        U.reset(true)
        reply(player, "Expedicion reiniciada.")
        return true
    end
    reply(player, "Comando desconocido. Usa !nocthold help.")
    return true
end

talk:separator(" ")
talk:groupType("normal") -- Canary no registra un TalkAction sin groupType
talk:register()
