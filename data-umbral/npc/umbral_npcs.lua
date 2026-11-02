-- UMBRAL NPC prototypes for Canary Revscripts/NpcType API.
-- All five are registered as NPC types. A map NPC placement file is still required to spawn them.
-- Nocthold: cada NPC se apunta en Umbral.npcs (scripts/lib/umbral.lua) para el aviso de arranque.

local function registerUmbralNpc(def)
    local npcType = Game.createNpcType(def.name)
    local npcConfig = {
        name = def.name,
        description = def.name,
        health = 100,
        maxHealth = 100,
        walkInterval = 2000,
        walkRadius = 2,
        outfit = {
            lookType = 128, -- placeholder outfit; replace after client asset review
            lookHead = 0,
            lookBody = 0,
            lookLegs = 0,
            lookFeet = 0,
            lookAddons = 0,
            lookMount = 0,
        },
        flags = { floorchange = false },
        voices = { interval = 15000, chance = 10, { text = def.voice } },
    }

    local keywordHandler = KeywordHandler:new()
    local npcHandler = NpcHandler:new(keywordHandler)

    npcType.onThink = function(npc, interval) npcHandler:onThink(npc, interval) end
    npcType.onAppear = function(npc, creature) npcHandler:onAppear(npc, creature) end
    npcType.onDisappear = function(npc, creature) npcHandler:onDisappear(npc, creature) end
    npcType.onMove = function(npc, creature, fromPosition, toPosition)
        npcHandler:onMove(npc, creature, fromPosition, toPosition)
    end
    npcType.onSay = function(npc, creature, messageType, message)
        npcHandler:onSay(npc, creature, messageType, message)
    end
    npcType.onCloseChannel = function(npc, player) npcHandler:onCloseChannel(npc, player) end

    local function greetCallback(npc, player)
        npcHandler:setMessage(MESSAGE_GREET, "Saludos, |PLAYERNAME|. " .. def.greeting)
        return true
    end

    local function creatureSayCallback(npc, player, messageType, message)
        if not npcHandler:checkInteraction(npc, player) then
            return false
        end
        local lowerMessage = message:lower()
        for keyword, reply in pairs(def.replies) do
            if MsgContains(lowerMessage, keyword) then
                npcHandler:say(reply, npc, player)
                return true
            end
        end
        npcHandler:say(def.fallback, npc, player)
        return true
    end

    npcHandler:setCallback(CALLBACK_GREET, greetCallback)
    npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
    npcHandler:setMessage(MESSAGE_FAREWELL, "Que la luz te guíe.")
    npcHandler:setMessage(MESSAGE_WALKAWAY, "Vuelve cuando estés preparado.")
    npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)
    npcType:register(npcConfig)
    if Umbral then
        Umbral.registerNpc(def.name)
    end
end

registerUmbralNpc({
    name = "Capitana Elira",
    voice = "¡Bastión del Alba necesita aventureros!",
    greeting = "Puedo hablarte de los contratos, la Forja Caída o las temporadas.",
    replies = {
        contrato = "Los Marjales de Ceniza están infestados. Empieza por los Carroñeros de Escoria y los Sabuesos.",
        forja = "La Forja Caída tiene tres guardianes. Reúne cinco aventureros antes de entrar.",
        temporada = "Las temporadas rotarán afijos y recompensas. El Cronista conserva los registros.",
    },
    fallback = "Pregúntame por contrato, forja o temporada.",
})

registerUmbralNpc({
    name = "Intendente Renn",
    voice = "Equipo revisado, correas tensadas. Siguiente.",
    greeting = "Gestiono suministros y equipo básico.",
    replies = {
        equipo = "El equipo se organizará por ranuras, rareza y nivel de objeto. La tienda de alfa aún no vende objetos finales.",
        marcas = "Las Marcas de Forja se obtienen en la mazmorra y sirven para comprar equipo de recuperación.",
        reparar = "El servicio de reparación se activará cuando el sistema de durabilidad esté implementado.",
    },
    fallback = "Puedo explicarte equipo, marcas o reparación.",
})

registerUmbralNpc({
    name = "Archivista Nima",
    voice = "Cada run deja una historia. Algunas, una cicatriz.",
    greeting = "Custodio los registros de Eryndor.",
    replies = {
        historia = "La Forja Caída era el corazón industrial de Eryndor. Algo despertó bajo sus cámaras.",
        temporada = "El marcador de temporada guardará puntuación, nivel de llave, tiempo, muertes y grupo.",
        sintonia = "La sintonización de mazmorra desbloqueará dificultades y rutas conforme avances.",
    },
    fallback = "Pregúntame por historia, temporada o sintonía.",
})

registerUmbralNpc({
    name = "Forjador Borun",
    voice = "El metal recuerda cada golpe.",
    greeting = "Puedo explicarte cómo se desarrollará la forja de equipo.",
    replies = {
        mejorar = "Las mejoras consumirán materiales y moneda, con límites semanales para evitar inflación.",
        desguazar = "El desguace convertirá objetos no deseados en materiales. Nunca destruyas equipo equipado por accidente.",
        legendario = "Los efectos legendarios alterarán habilidades, no serán solo grandes aumentos de atributos.",
    },
    fallback = "Pregúntame por mejorar, desguazar o legendario.",
})

registerUmbralNpc({
    name = "Cronista de Llaves",
    voice = "Cinco nombres. Una llave. Una historia.",
    greeting = "Registro las expediciones de cinco aventureros.",
    replies = {
        llave = "El sistema de llaves permitirá escoger mazmorra, nivel y afijos. Aún no está habilitado para iniciar runs.",
        grupo = "La composición recomendada es un tanque, un sanador y tres DPS.",
        ranking = "El ranking se calculará en servidor y guardará las mejores ejecuciones válidas.",
    },
    fallback = "Pregúntame por llave, grupo o ranking.",
})
