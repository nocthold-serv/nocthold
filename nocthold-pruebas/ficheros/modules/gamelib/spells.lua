SpelllistSettings = {
    ['Default'] = {
        iconFile = '/images/game/spells/spell-icons-32x32',
        iconsForGameCooldown = '/images/game/spells/spell-icons-20x20',
        iconSize = {
            width = 32,
            height = 32
        },
        iconSizeCooldown = {
            width = 20,
            height = 22
        },
        spellListWidth = 210,
        spellWindowWidth = 550,
    } --[[,
['Custom'] =  {
  iconFile = '/images/game/spells/custom',
  iconSize = {width = 32, height = 32},
  spellOrder = {
    'Chain Lighting'
    ,'Chain Healing'
    ,'Divine Chain'
    ,'Berserk Chain'
    ,'Cheat death'
    ,'Brutal Charge'
    ,'Empower Summons'
    ,'Summon Doppelganger'
  }
}]]
}

-- check "/docs/generate_spell_data.py"
-- spells from canary
-- Nocthold: solo nuestros hechizos (generado por client/configurar.py a partir de
-- data-nocthold/scripts/nocthold/spells). Los de Tibia no se usan en Nocthold.
SpellInfo = {
    Default = {
        ["Shield Bash"] = {id = 1001, name = "Shield Bash", words = "vorn skel", type = 'Instant', level = 1, mana = 8, soul = 0, maglevel = 0, icon = '', clientId = 0, group = {[1] = 1000}, needTarget = true, parameter = false, range = 1, exhaustion = 5000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Golpeas con el escudo a un enemigo pegado a ti. Daño físico. El hechizo básico del Guardián."},
        ["Sundering Strike"] = {id = 1002, name = "Sundering Strike", words = "vorn drak", type = 'Instant', level = 5, mana = 18, soul = 0, maglevel = 0, icon = '', clientId = 1, group = {[1] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 9000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Un tajo fuerte a un enemigo cercano (hasta 5 casillas). Daño físico alto."},
        ["Iron Sweep"] = {id = 1003, name = "Iron Sweep", words = "vorn kar", type = 'Instant', level = 10, mana = 28, soul = 0, maglevel = 0, icon = '', clientId = 2, group = {[1] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 12000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Barres a todos los enemigos alrededor del objetivo con un golpe circular. Daño físico en área."},
        ["Taunting Roar"] = {id = 1004, name = "Taunting Roar", words = "hrum voth", type = 'Instant', level = 8, mana = 24, soul = 0, maglevel = 0, icon = '', clientId = 3, group = {[1] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 16000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Ruges y sacudes el suelo: poco daño físico al objetivo y a todos los que lo rodean."},
        ["Groundbreaker"] = {id = 1005, name = "Groundbreaker", words = "vorn tagh", type = 'Instant', level = 14, mana = 35, soul = 0, maglevel = 0, icon = '', clientId = 4, group = {[1] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 18000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Partes el suelo bajo el objetivo y dañas a todos los que están cerca. Daño físico en área."},
        ["Fortress Stance"] = {id = 1006, name = "Fortress Stance", words = "stal mur", type = 'Instant', level = 4, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 5, group = {[3] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 18000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Te plantas como una muralla: tu defensa con escudo sube un 25 % durante 6 segundos."},
        ["Intercept"] = {id = 1007, name = "Intercept", words = "stal vel", type = 'Instant', level = 6, mana = 18, soul = 0, maglevel = 0, icon = '', clientId = 6, group = {[3] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 20000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Te lanzas a cubrir huecos en la línea: tu velocidad sube mucho durante 6 segundos."},
        ["Bulwark"] = {id = 1008, name = "Bulwark", words = "stal gard", type = 'Instant', level = 12, mana = 30, soul = 0, maglevel = 0, icon = '', clientId = 7, group = {[3] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 25000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Levantas el escudo con todo tu peso: tu defensa con escudo sube un 30 % durante 7 segundos."},
        ["Last Stand"] = {id = 1009, name = "Last Stand", words = "stal ultor", type = 'Instant', level = 8, mana = 35, soul = 0, maglevel = 0, icon = '', clientId = 8, group = {[3] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 90000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Aguantas hasta el final: tu vida máxima sube un 15 % durante 8 segundos."},
        ["Guardian's Oath"] = {id = 1010, name = "Guardian's Oath", words = "stal oth", type = 'Instant', level = 20, mana = 55, soul = 0, maglevel = 0, icon = '', clientId = 9, group = {[3] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 90000, premium = false, vocations = {4, 8}, special = false, source = 0, description = "Juras proteger al grupo: tu vida máxima sube un 10 % durante 8 segundos."},
        ["Verdant Touch"] = {id = 1011, name = "Verdant Touch", words = "sylva mei", type = 'Instant', level = 1, mana = 20, soul = 0, maglevel = 0, icon = '', clientId = 10, group = {[2] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 4000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "Cura a un aliado o a ti mismo con savia viva. Curación rápida y barata."},
        ["Renewing Roots"] = {id = 1012, name = "Renewing Roots", words = "sylva rhun", type = 'Instant', level = 4, mana = 28, soul = 0, maglevel = 0, icon = '', clientId = 11, group = {[2] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 10000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "Unas raíces curan un poco al objetivo y siguen curándolo durante 8 segundos."},
        ["Purify"] = {id = 1013, name = "Purify", words = "sylva lis", type = 'Instant', level = 6, mana = 25, soul = 0, maglevel = 0, icon = '', clientId = 12, group = {[2] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 16000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "Limpia la parálisis del objetivo y lo cura un poco."},
        ["Blooming Wave"] = {id = 1014, name = "Blooming Wave", words = "sylva brae", type = 'Instant', level = 8, mana = 32, soul = 0, maglevel = 0, icon = '', clientId = 13, group = {[2] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 12000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "Una ola de flores cura al objetivo y a todos los que están a su alrededor."},
        ["Lifebloom"] = {id = 1015, name = "Lifebloom", words = "sylva vira", type = 'Instant', level = 10, mana = 36, soul = 0, maglevel = 0, icon = '', clientId = 14, group = {[2] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 18000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "Una flor se abre sobre el objetivo y lo va curando cada 2 segundos durante 10 segundos."},
        ["Spirit Bloom"] = {id = 1016, name = "Spirit Bloom", words = "sylva anim", type = 'Instant', level = 16, mana = 45, soul = 0, maglevel = 0, icon = '', clientId = 15, group = {[2] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 25000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "Los espíritus del bosque curan mucho al objetivo y a los que están a su alrededor."},
        ["Rebirth"] = {id = 1017, name = "Rebirth", words = "sylva nov", type = 'Instant', level = 22, mana = 65, soul = 0, maglevel = 0, icon = '', clientId = 16, group = {[2] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 60000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "La curación más fuerte del Custodio, para salvar a un aliado en apuros. Tarda en volver a estar lista."},
        ["Thorn Lash"] = {id = 1018, name = "Thorn Lash", words = "ronce vas", type = 'Instant', level = 6, mana = 26, soul = 0, maglevel = 0, icon = '', clientId = 17, group = {[1] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 7000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "Un látigo de espinas golpea al objetivo. Daño de tierra."},
        ["Nature's Grasp"] = {id = 1019, name = "Nature's Grasp", words = "ronce tenn", type = 'Instant', level = 12, mana = 38, soul = 0, maglevel = 0, icon = '', clientId = 18, group = {[1] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 18000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "Las enredaderas atrapan al objetivo: poco daño y lo frenan durante 3 segundos."},
        ["Barkskin"] = {id = 1020, name = "Barkskin", words = "ronce crot", type = 'Instant', level = 5, mana = 24, soul = 0, maglevel = 0, icon = '', clientId = 19, group = {[3] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 22000, premium = false, vocations = {2, 6}, special = false, source = 0, description = "Tu piel se vuelve corteza: tu defensa con escudo sube un 30 % durante 7 segundos."},
        ["Arcane Bolt"] = {id = 1021, name = "Arcane Bolt", words = "aeth ir", type = 'Instant', level = 1, mana = 18, soul = 0, maglevel = 0, icon = '', clientId = 20, group = {[1] = 1000}, needTarget = true, parameter = false, range = 6, exhaustion = 2500, premium = false, vocations = {1, 5}, special = false, source = 0, description = "Un rayo de energía pura contra un enemigo a distancia. El hechizo básico del Arcanista."},
        ["Shatter"] = {id = 1022, name = "Shatter", words = "aeth krys", type = 'Instant', level = 6, mana = 24, soul = 0, maglevel = 0, icon = '', clientId = 21, group = {[1] = 1000}, needTarget = true, parameter = false, range = 6, exhaustion = 8500, premium = false, vocations = {1, 5}, special = false, source = 0, description = "Una esquirla de hielo golpea con fuerza a un enemigo. Daño de hielo."},
        ["Frost Lattice"] = {id = 1023, name = "Frost Lattice", words = "aeth glas", type = 'Instant', level = 4, mana = 32, soul = 0, maglevel = 0, icon = '', clientId = 22, group = {[1] = 1000}, needTarget = true, parameter = false, range = 6, exhaustion = 14000, premium = false, vocations = {1, 5}, special = false, source = 0, description = "Una red de escarcha daña al objetivo y lo frena durante 2,5 segundos."},
        ["Prismatic Burst"] = {id = 1024, name = "Prismatic Burst", words = "aeth prisma", type = 'Instant', level = 6, mana = 35, soul = 0, maglevel = 0, icon = '', clientId = 23, group = {[1] = 1000}, needTarget = true, parameter = false, range = 5, exhaustion = 12000, premium = false, vocations = {1, 5}, special = false, source = 0, description = "Un estallido de luz de colores daña al objetivo y a los que están a su alrededor."},
        ["Arcane Nova"] = {id = 1025, name = "Arcane Nova", words = "aeth nova", type = 'Instant', level = 8, mana = 34, soul = 0, maglevel = 0, icon = '', clientId = 24, group = {[1] = 1000}, needTarget = true, parameter = false, range = 6, exhaustion = 14000, premium = false, vocations = {1, 5}, special = false, source = 0, description = "Una explosión de energía alrededor del objetivo. Daño en área."},
        ["Meteor"] = {id = 1026, name = "Meteor", words = "aeth ignar", type = 'Instant', level = 16, mana = 58, soul = 0, maglevel = 0, icon = '', clientId = 25, group = {[1] = 1000}, needTarget = true, parameter = false, range = 6, exhaustion = 22000, premium = false, vocations = {1, 5}, special = false, source = 0, description = "Una roca ardiente cae del cielo sobre el objetivo y quema a todos los que están cerca."},
        ["Chain Lightning"] = {id = 1027, name = "Chain Lightning", words = "aeth fulgor", type = 'Instant', level = 20, mana = 68, soul = 0, maglevel = 0, icon = '', clientId = 26, group = {[1] = 1000}, needTarget = true, parameter = false, range = 6, exhaustion = 18000, premium = false, vocations = {1, 5}, special = false, source = 0, description = "Un relámpago salta entre el objetivo y los enemigos de su alrededor."},
        ["Frost Armor"] = {id = 1028, name = "Frost Armor", words = "aeth glacis", type = 'Instant', level = 5, mana = 28, soul = 0, maglevel = 0, icon = '', clientId = 27, group = {[3] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 25000, premium = false, vocations = {1, 5}, special = false, source = 0, description = "Te cubres de hielo: tu vida máxima sube un 10 % durante 8 segundos."},
        ["Mana Ward"] = {id = 1029, name = "Mana Ward", words = "aeth custos", type = 'Instant', level = 10, mana = 40, soul = 0, maglevel = 0, icon = '', clientId = 28, group = {[3] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 30000, premium = false, vocations = {1, 5}, special = false, source = 0, description = "Un escudo de energía te rodea: tu defensa con escudo sube un 30 % durante 7 segundos."},
        ["Arcane Surge"] = {id = 1030, name = "Arcane Surge", words = "aeth celer", type = 'Instant', level = 12, mana = 42, soul = 0, maglevel = 0, icon = '', clientId = 29, group = {[3] = 1000}, needTarget = false, parameter = false, range = -1, exhaustion = 30000, premium = false, vocations = {1, 5}, special = false, source = 0, description = "La energía te empuja: tu velocidad sube mucho durante 6 segundos."},
    }
}

VocationNames = {
    [0] = 'None',
    [1] = 'Sorcerer',
    [2] = 'Druid',
    [3] = 'Paladin',
    [4] = 'Knight',
    [5] = 'Master Sorcerer',
    [6] = 'Elder Druid',
    [7] = 'Royal Paladin',
    [8] = 'Elite Knight',
    [9] = 'Monk',
    [10] = 'Exalted Monk'
}

SpellGroups = {
    [1] = 'Attack',
    [2] = 'Healing',
    [3] = 'Support',
    [4] = 'Special',
    [5] = 'Conjure',
    [6] = 'Crippling',
    [7] = 'Focus',
    [8] = 'UltimateStrikes',
    [9] = 'GreatBeams',
    [10] = 'BurstsOfNature',
    [11] = 'Virtue'
}

SpellRunesData = {
    [3148] = {id = 30, group = 3, name = 'destroy field rune', exhaustion = 2000},
    [3149] = {id = 55, group = 1, name = 'energybomb rune', exhaustion = 2000},
    [3152] = {id = 4, group = 2, name = 'intense healing rune', exhaustion = 1000},
    [3153] = {id = 31, group = 2, name = 'antidote rune', exhaustion = 1000},
    [3155] = {id = 21, group = 1, name = 'sudden death rune', exhaustion = 2000},
    [3156] = {id = 94, group = 1, name = 'Wild Growth Rune', exhaustion = 2000},
    [3158] = {id = 114, group = 1, name = 'icicle rune', exhaustion = 2000},
    [3160] = {id = 5, group = 2, name = 'ultimate healing rune', exhaustion = 1000},
    [3161] = {id = 115, group = 1, name = 'avalanche rune', exhaustion = 2000},
    [3164] = {id = 27, group = 1, name = 'energy field rune', exhaustion = 2000},
    [3165] = {id = 54, group = 3, name = 'paralyze rune', exhaustion = 6000},
    [3166] = {id = 33, group = 1, name = 'energy wall rune', exhaustion = 2000},
    [3172] = {id = 26, group = 1, name = 'poison field rune', exhaustion = 2000},
    [3173] = {id = 91, group = 1, name = 'poison bomb rune', exhaustion = 2000},
    [3174] = {id = 7, group = 1, name = 'light magic missile rune', exhaustion = 2000},
    [3175] = {id = 116, group = 1, name = 'stone shower rune', exhaustion = 2000},
    [3176] = {id = 32, group = 1, name = 'poison wall rune', exhaustion = 2000},
    [3177] = {id = 12, group = 3, name = 'convince creature rune', exhaustion = 2000},
    [3178] = {id = 14, group = 3, name = 'chameleon rune', exhaustion = 2000},
    [3179] = {id = 77, group = 1, name = 'stalagmite rune', exhaustion = 2000},
    [3180] = {id = 86, group = 1, name = 'Magic Wall Rune', exhaustion = 2000},
    [3182] = {id = 130, group = 1, name = 'holy missile rune', exhaustion = 2000},
    [3188] = {id = 25, group = 1, name = 'fire field rune', exhaustion = 2000},
    [3189] = {id = 15, group = 1, name = 'fireball rune', exhaustion = 2000},
    [3190] = {id = 28, group = 1, name = 'fire wall rune', exhaustion = 2000},
    [3191] = {id = 16, group = 1, name = 'great fireball rune', exhaustion = 2000},
    [3192] = {id = 17, group = 1, name = 'firebomb rune', exhaustion = 2000},
    [3195] = {id = 50, group = 1, name = 'soulfire rune', exhaustion = 2000},
    [3197] = {id = 78, group = 3, name = 'desintegrate rune', exhaustion = 2000},
    [3198] = {id = 8, group = 1, name = 'heavy magic missile rune', exhaustion = 2000},
    [3200] = {id = 18, group = 1, name = 'explosion rune', exhaustion = 2000},
    [3202] = {id = 117, group = 1, name = 'thunderstorm rune', exhaustion = 2000},
    [3203] = {id = 83, group = 3, name = 'animate dead rune', exhaustion = 2000},
    [17512] = {id = 7, group = 1, name = 'lightest magic missile rune', exhaustion = 2000},
    [21351] = {id = 116, group = 1, name = 'light stone shower rune', exhaustion = 2000},
    [21352] = {id = 7, group = 1, name = 'lightest missile rune', exhaustion = 2000}
}

Spells = {}

function Spells.getSpellList()
    local spells = {}
    for k, spell in pairs(SpellInfo["Default"]) do
        table.insert(spells, spell)
    end
    return spells
end

function Spells.getSpellByName(name)
    return SpellInfo[Spells.getSpellProfileByName(name)][name]
end

function Spells.getSpellByWords(words)
    local words = words:lower():trim()
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return spell, profile, k
            end
        end
    end
    return nil
end

function Spells.getSpellByIcon(iconId)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.id == iconId then
                return spell, profile, k
            end
        end
    end
    return nil
end

function Spells.getSpellByClientId(clientId)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.clientId == clientId then
                return spell, profile, k
            end
        end
    end
    return nil
end

function Spells.getSpellIconIds()
    local ids = {}
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            table.insert(ids, spell.id)
        end
    end
    return ids
end

function Spells.getSpellProfileById(id)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.id == id then
                return profile
            end
        end
    end
    return nil
end

function Spells.getSpellProfileByWords(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return profile
            end
        end
    end
    return nil
end

function Spells.getSpellDataByWords(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return spell
            end
        end
    end
    return nil
end

function Spells.getSpellDataByParamWords(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            local inputWords = words:lower()
            local spellWords = spell.words:lower()
            local quoteStartIndex = inputWords:find('%"')

            if not spell.parameter then
                if inputWords == spellWords then
                    return spell, nil
                end
            else
                if quoteStartIndex then
                    local spellPart = inputWords:sub(1, quoteStartIndex - 1):match("^%s*(.-)%s*$")
                    local parameter = inputWords:sub(quoteStartIndex + 1)
                    if spellPart == spellWords then
                        return spell, parameter
                    end
                else
                    if inputWords == spellWords then
                        return spell, nil
                    end
                end
            end
        end
    end
    return nil, nil
end

function Spells.getSpellFormatedName(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            local inputWords = words:lower()
            local spellWords = spell.words:lower()

            if not spell.parameter then
                if inputWords == spellWords then
                    return spellWords
                end
            else
                if string.sub(inputWords, 1, string.len(spellWords)) == spellWords then
                    local extraText = string.sub(inputWords, string.len(spellWords) + 1)
                    if extraText ~= "" then
                        if string.sub(extraText, 1, 1) == " " then
                            local firstChar = string.sub(extraText, 2, 2)
                            if firstChar == '"' then
                                local fomated = extraText:gsub('"', '')
                                fomated = "\"" .. string.sub(fomated, 2) .. "\""
                                return spellWords .. " " .. fomated
                            else
                                return spellWords .. extraText
                            end
                        end
                    else
                        return spellWords
                    end
                end
            end
        end
    end
    return words
end

function Spells.getSpellNameByWords(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return k
            end
        end
    end
    return nil
end

function Spells.getSpellDataById(spellId)
    for _, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.id == spellId then
                return spell
            end
        end
    end
    return nil
end

function Spells.getRuneSpellByItem(itemId)
    local data = SpellRunesData[itemId]
    if data then
        return data
    end
    return nil
end

function Spells.isRuneSpell(spellId)
    for _, data in pairs(SpellRunesData) do
        if data.id == spellId then
            return true
        end
    end
    return false
end

function Spells.getSpellProfileByName(spellName)
    for profile, data in pairs(SpellInfo) do
        if table.findbykey(data, spellName:trim(), true) then
            return profile
        end
    end
    return nil
end

function Spells.getSpellsByVocationId(vocId)
    local spells = {}
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if table.contains(spell.vocations, vocId) then
                table.insert(spells, spell)
            end
        end
    end
    return spells
end

function Spells.filterSpellsByGroups(spells, groups)
    local filtered = {}
    for v, spell in pairs(spells) do
        local spellGroups = Spells.getGroupIds(spell)
        if table.equals(spellGroups, groups) then
            table.insert(filtered, spell)
        end
    end
    return filtered
end

function Spells.getCooldownByGroup(spellData, groupId)
    local keys = {}
    for k in pairs(spellData.group) do
        table.insert(keys, k)
    end
    table.sort(keys)
    local index = 1
    for _, k in ipairs(keys) do
        if index == 1 and k == groupId then
            return spellData.group[k]
        end
        index = index + 1
    end
    return nil
end

function Spells.getCooldownBySecondaryGroup(spellData, groupId)
    local keys = {}
    for k in pairs(spellData.group) do
        table.insert(keys, k)
    end
    table.sort(keys)
    local index = 1
    for _, k in ipairs(keys) do
        if index == 2 and k == groupId then
            return spellData.group[k]
        end
        index = index + 1
    end
    return nil
end

function Spells.getGroupIds(spell)
    local groups = {}
    for k, _ in pairs(spell.group) do
        table.insert(groups, k)
    end
    return groups
end

function Spells.getPrimaryGroup(spell)
    local indexes = {}
    for k in pairs(spell.group) do
        table.insert(indexes, k)
    end
    table.sort(indexes)
    return indexes[1] or -1
end

function Spells.getIconFileByProfile(profile)
    return SpelllistSettings[profile]['iconFile']
end

function Spells.getImageClip(indexClip, profile)
    if profile == nil then
        profile = "Default"
    end
    return indexClip * SpelllistSettings[profile].iconSize.width .. " 0 " .. SpelllistSettings[profile].iconSize.width .. " " .. SpelllistSettings[profile].iconSize.height
end

function Spells.getImageClipCooldown(indexClip, profile)
    if profile == nil then
        profile = "Default"
    end
    return indexClip * SpelllistSettings[profile].iconSizeCooldown.width .. " 0 " .. SpelllistSettings[profile].iconSizeCooldown.width .. " " .. SpelllistSettings[profile].iconSizeCooldown.height
end
