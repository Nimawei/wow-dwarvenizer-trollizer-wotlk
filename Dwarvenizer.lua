-- Dwarvenizer/Trollizer (Wrath 3.3.5a compatible)
-- Now with EnsureInit() so slash commands and savedvars are present even if XML OnLoad didn't run.

Dwarvenizer = {
    version = "1.3-wotlk",
    settingsID = UnitName("player") .. "@" .. GetRealmName(),
    languages = {} -- will be filled from lang*.lua tables if present
}

-----------------------------------------------------------------------------

-- Core transform
Dwarvenizer.dwarvenize = function(messageIn)
    local messageOut = ""

    -- safety: if settings missing, return original
    if (not DwarvenizerSettings) or (not DwarvenizerSettings[Dwarvenizer.settingsID]) then
        return messageIn
    end

    local langKey = DwarvenizerSettings[Dwarvenizer.settingsID].language or "dwarf"
    local language = Dwarvenizer.languages[langKey] or {}
    local cnt = 1
    local replacements = {}

    -- Store and replace item links with placeholders to avoid mangling them
    for itemLink in string.gmatch(messageIn, "(|c%x+|Hitem:.-|h%[.-%]|h|r)") do
        messageIn = string.gsub(messageIn, "(|c%x+|Hitem:.-|h%[.-%]|h|r)", "__"..cnt.."__", 1)
        table.insert(replacements, itemLink)
        cnt = cnt + 1
    end

    -- Replace phrases (dict1 = multi-word / phrase rules)
    if language.dict1 then
        for _, srSet in ipairs(language.dict1) do
            local stringSearch, stringReplace
            for setKey, setValue in pairs(srSet) do
                stringSearch, stringReplace = setKey, setValue
                break
            end

            stringReplace = Dwarvenizer.adjustReplaceString(stringReplace)
            if stringReplace ~= nil then
                stringReplace = string.gsub(stringReplace, "[§@]+%s*$", "")
                messageIn = Dwarvenizer.translate(messageIn, "%s+" .. stringSearch .. "%s+", " " .. stringReplace .. " ")
            end
        end
    end

    local lastSegment = ""

    -- Split into segments (words + trailing punctuation kept separate)
    for segment in string.gmatch(messageIn, "[%p%a%d_ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿĀāĂăĄąĆćĈĉĊċČčĎďĐđĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħĨĩĪīĬĭĮįİıĲĳĴĵĶķĸĹĺĻļĽľĿŀŁłŃńŅņŇňŉŊŋŌōŎŏŐőŒœŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŦŧŨũŪūŬŭŮ]+") do
        local punctuation = ""
        for p in string.gmatch(segment, "(%p+)$") do punctuation = p; break end
        if punctuation == nil then punctuation = "" end

        segment = string.gsub(segment, "%p*$", "")

        -- Replace single-word segments (dict2)
        if language.dict2 then
            for _, srSet in ipairs(language.dict2) do
                local stringSearch, stringReplace
                for setKey, setValue in pairs(srSet) do
                    stringSearch, stringReplace = setKey, setValue
                    break
                end

                if not (string.find(stringSearch or "", "^%^") and string.find(lastSegment or "", "'$")) then
                    stringReplace = Dwarvenizer.adjustReplaceString(stringReplace)
                    if stringReplace ~= nil then
                        stringReplace = string.gsub(stringReplace, "[§@]+%s*$", "")
                        segment = Dwarvenizer.translate(segment, stringSearch, stringReplace)
                    end
                end
            end
        end

        -- Minor cleanup
        segment = string.gsub(segment, "''", "'")

        lastSegment = segment
        messageOut = messageOut .. segment .. punctuation .. " "
    end

    -- Restore item links
    for k, v in ipairs(replacements) do
        messageOut = string.gsub(messageOut, "__"..k.."__", v, 1)
    end

    return messageOut
end

-----------------------------------------------------------------------------

Dwarvenizer.adjustReplaceString = function(stringReplace)
    local _ = math.random(100)
    local chance = math.random(100)

    if type(stringReplace) == "table" then
        local possibilities = {}
        for _, v in pairs(stringReplace) do
            table.insert(possibilities, v)
        end
        if #possibilities > 0 then
            stringReplace = possibilities[ math.random(#possibilities) ]
        else
            stringReplace = nil
        end
    end

    if DwarvenizerSettings and DwarvenizerSettings[Dwarvenizer.settingsID] and DwarvenizerSettings[Dwarvenizer.settingsID].chance and DwarvenizerSettings[Dwarvenizer.settingsID].chance < 10 then
        if (stringReplace and string.sub(stringReplace, -2) == "§") and (chance > (DwarvenizerSettings[Dwarvenizer.settingsID].chance * 10)) then
            return nil
        end
        if (stringReplace and string.sub(stringReplace, -2) == "@") and (chance > (DwarvenizerSettings[Dwarvenizer.settingsID].chance * 5)) then
            return nil
        end
    end

    return stringReplace
end

-----------------------------------------------------------------------------

Dwarvenizer.translate = function(segment, stringSearch, stringReplace)
    if not string.find(segment or "", "^[%u]+$") and stringSearch and stringReplace then
        segment = string.gsub(segment, stringSearch, stringReplace)

        if stringSearch ~= "^he" then
            local stringSearch1  = string.gsub(stringSearch,  "%l", string.upper, 1)
            local stringReplace1 = string.gsub(stringReplace, "%l", string.upper, 1)
            segment = string.gsub(segment, stringSearch1, stringReplace1)
        end
    end
    return segment
end

-----------------------------------------------------------------------------

Dwarvenizer.print = function(message)
    if not string.find(message, "\n$") then message = message .. "\n" end
    for line in string.gmatch(message, "(.-)\n") do
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(line)
        end
    end
end

-----------------------------------------------------------------------------

-- Slash command handlers (they call _main after ensuring settings exist)
Dwarvenizer.onSlashCommand = {}

Dwarvenizer.onSlashCommand.Dwarf = function(slashCommand)
    if not DwarvenizerSettings or not DwarvenizerSettings[Dwarvenizer.settingsID] then
        Dwarvenizer_EnsureInit()
    end
    DwarvenizerSettings[Dwarvenizer.settingsID].language = "dwarf"
    Dwarvenizer.onSlashCommand._main(slashCommand)
end

Dwarvenizer.onSlashCommand.Troll = function(slashCommand)
    if not DwarvenizerSettings or not DwarvenizerSettings[Dwarvenizer.settingsID] then
        Dwarvenizer_EnsureInit()
    end
    DwarvenizerSettings[Dwarvenizer.settingsID].language = "troll"
    Dwarvenizer.onSlashCommand._main(slashCommand)
end

Dwarvenizer.onSlashCommand._main = function(slashCommand)
    local currentSettings = DwarvenizerSettings and DwarvenizerSettings[Dwarvenizer.settingsID]
    local languageEntry = nil
    if currentSettings and Dwarvenizer.languages then
        languageEntry = Dwarvenizer.languages[currentSettings.language]
    end

    local language = languageEntry or { name = "Dwarvenizer", slashCommand = "dwarvenizer", welcomeMsg = "No language tables found." }
    local color

    slashCommand = string.lower(slashCommand or "")

    if (language.name == "|cFFFFD700Dwarvenizer|r") then
        color = "|cFFFFD700"
    else
        color = "|cFF008000"
    end

    local ending            = "|r"
    local defaultMessage    = color .. language.name .. "|r:" .. (language.welcomeMsg or "")
    local command1Message   = color .. (language.slashCommand or "dwarvenizer") .. "|r chance <num>, 0-10 (|cFF8000800 for off|r)"
    local command2Message   = color .. (language.slashCommand or "dwarvenizer") .. "|r toggle <channel>\n" .. color .. (language.slashCommand or "dwarvenizer") .. "|r toggle list,  all channel status"
    local command3Message
    if (language.name == "|cFFFFD700Dwarvenizer|r") then
        command3Message = "|cFF008000Trollizer|r to enable Troll Accent."
    else
        command3Message = "|cFFFFD700Dwarvenizer|r to enable Dwarven Accent."
    end
    local command4Message   = "Current Chance: |cFFFFD700" .. tostring(currentSettings and currentSettings.chance or "nil") .. "|r"
    local command5Message   = "|cff00C78CBrought back to life by Haptik of Eternal Vigilance on Deviate Delight. We will see you there!|r"

    local _, _, newChance = string.find(slashCommand, "%s*chance (%d+)")
    local _, _, toggle    = string.find(slashCommand, "%s*toggle%s*(%a*)")

    if newChance then
        newChance = newChance * 1
        if newChance >= 0 and newChance <= 10 then
            if not DwarvenizerSettings then DwarvenizerSettings = {} end
            if not DwarvenizerSettings[Dwarvenizer.settingsID] then DwarvenizerSettings[Dwarvenizer.settingsID] = {} end
            DwarvenizerSettings[Dwarvenizer.settingsID].chance = newChance
            Dwarvenizer.print(language.name .. ": Probability set to " .. newChance .. "\n")
            if newChance == 0 then
                Dwarvenizer.print("    (It's turned off now.)\n")
            end
        else
            Dwarvenizer.print(language.name .. ": Probability must be a number between 0-10!\n")
        end

    elseif (toggle ~= "list" and toggle ~= "" and toggle ~= nil) then
        for channel, bool in pairs((currentSettings and currentSettings.system) or {}) do
            if channel == string.lower(toggle) then
                currentSettings.system[channel] = not currentSettings.system[channel]
                local state = currentSettings.system[channel] and "enabled" or "disabled"
                local chName = channel
                if chName == "channel" then chName = "general chat" end
                Dwarvenizer.print(language.name .. ": " .. chName .. " channel processing " .. state)
            end
        end

    elseif (toggle == "list" or toggle == "") then
        local togglesList = (language.name or "Dwarvenizer") .. " settings:\n"
        for channel, bool in pairs((currentSettings and currentSettings.system) or {}) do
            local state = bool and "on" or "off"
            local chName = channel
            if chName == "channel" then chName = "channel (i.e. general chat channels 1-4)" end
            togglesList = togglesList .. chName .. ": " .. state .. "\n"
        end
        togglesList = string.gsub(togglesList, ", $", ". ")

        Dwarvenizer.print(togglesList ..
            "To enable/disable ".. color .. (language.name or "Dwarvenizer") .. ending ..
            " for a particular channel type, enter '/" .. color .. (language.slashCommand or "dwarvenizer") .. ending ..
            " toggle <channel type>', for example '/" .. color .. (language.slashCommand or "dwarvenizer") .. ending .. " toggle raid'. " ..
            "If you want to know which channels are enabled/disabled, type '/" .. color .. (language.slashCommand or "dwarvenizer") .. ending .. " toggle list'.")
    else
        Dwarvenizer.print(defaultMessage)
        Dwarvenizer.print(command1Message)
        Dwarvenizer.print(command2Message)
        Dwarvenizer.print(command3Message)
        Dwarvenizer.print(command4Message)
        Dwarvenizer.print(command5Message)
    end
end

-----------------------------------------------------------------------------

-- Dwarvenizer_onLoad: legacy XML-driven entrypoint; still used by XML if present.
function Dwarvenizer_onLoad()
    -- Try to ensure init (this will register slash commands, ensure savedvars, and hook)
    Dwarvenizer_EnsureInit()

    -- Print (EnsureInit already printed loaded message; no need to duplicate)
end

-----------------------------------------------------------------------------

-- EnsureInit: safe initialiser that can run at file load or on PLAYER_LOGIN
function Dwarvenizer_EnsureInit()
    if Dwarvenizer._inited then return end

    -- seed randomness once
    pcall(function() math.randomseed(time()) end)

    -- Ensure savedvars structure exists
    if DwarvenizerSettings == nil then DwarvenizerSettings = {} end
    if DwarvenizerSettings[Dwarvenizer.settingsID] == nil then
        DwarvenizerSettings[Dwarvenizer.settingsID] = { chance = 8, version = Dwarvenizer.version, language = "dwarf" }
    end
    if DwarvenizerSettings[Dwarvenizer.settingsID].system == nil then
        DwarvenizerSettings[Dwarvenizer.settingsID].system = { say = true, whisper = true, channel = true, party = false, guild = false, yell = true, raid = false }
    end
    if DwarvenizerSettings[Dwarvenizer.settingsID].language == nil then
        DwarvenizerSettings[Dwarvenizer.settingsID].language = "dwarf"
    end

    -- Load language tables from global lang files if present
    if DwarvenizerLangDwarven then Dwarvenizer.languages.dwarf = DwarvenizerLangDwarven end
    if DwarvenizerLangTrollish then Dwarvenizer.languages.troll = DwarvenizerLangTrollish end

    -- Register slash commands (safe to do now)
    SLASH_Dwarvenizer_Dwarf1 = "/dwarvenizer"
    SlashCmdList["Dwarvenizer_Dwarf"] = Dwarvenizer.onSlashCommand.Dwarf

    SLASH_Dwarvenizer_Troll1 = "/trollizer"
    SlashCmdList["Dwarvenizer_Troll"] = Dwarvenizer.onSlashCommand.Troll

    -- Print a friendly loaded message once
    local name = (Dwarvenizer.languages[DwarvenizerSettings[Dwarvenizer.settingsID].language] and Dwarvenizer.languages[DwarvenizerSettings[Dwarvenizer.settingsID].language].name) or "Dwarvenizer"
    local chance = DwarvenizerSettings[Dwarvenizer.settingsID].chance
    Dwarvenizer.print("|cffff8000" .. name .. "|r: Loaded. Probability set to |cFFFF0000" .. tostring(chance) .. "|r (out of 10). Have fun!\n")

    -- Hook SendChatMessage now that defaults exist
    if (type(SendChatMessage) == "function") and (SendChatMessage ~= Dwarvenizer_SendChatMessage) then
        Dwarvenizer_Saved_SendChatMessage = SendChatMessage
        SendChatMessage = Dwarvenizer_SendChatMessage
    end

    Dwarvenizer._inited = true
end

-----------------------------------------------------------------------------

-- Safe SendChatMessage wrapper (calls saved original)
Dwarvenizer_Saved_SendChatMessage = nil

function Dwarvenizer_SendChatMessage(msg, system, language, channel)
    -- If the saved/original SendChatMessage isn't present yet, try best-effort passthrough
    if (Dwarvenizer_Saved_SendChatMessage == nil) then
        if type(SendChatMessage) == "function" and SendChatMessage ~= Dwarvenizer_SendChatMessage then
            return SendChatMessage(msg, system, language, channel)
        else
            if msg and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(tostring(msg)) end
            return
        end
    end

    local systemSetToSay = false

    if msg == nil then
        msg = ""
    end

    if system == nil then
        system = "SAY"
        systemSetToSay = true
    end

    -- If settings aren't ready, just pass through to original function
    if (not DwarvenizerSettings) or (not DwarvenizerSettings[Dwarvenizer.settingsID]) then
        Dwarvenizer_Saved_SendChatMessage(msg, system, language, channel)
        return
    end

    -- Only process when enabled and allowed for the channel
    if (DwarvenizerSettings[Dwarvenizer.settingsID].chance > 0)
        and ((system == "CHANNEL" and channel and channel > 0 and channel < 5) or system ~= "CHANNEL")
        and (not string.find(msg, "^%(%("))
        and DwarvenizerSettings[Dwarvenizer.settingsID].system[string.lower(system)] == true
        and system ~= "EMOTE"
    then
        msg = Dwarvenizer.dwarvenize(msg)
    end

    if systemSetToSay == true then
        system = nil
    end

    Dwarvenizer_Saved_SendChatMessage(msg, system, language, channel)
end

-- Run EnsureInit now (this makes slash commands available even if XML OnLoad didn't fire)
pcall(function() Dwarvenizer_EnsureInit() end)

-- end of Dwarvenizer.lua
