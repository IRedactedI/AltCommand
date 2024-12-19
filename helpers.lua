local images = require("images")
local variables = require("variables")
local imgui = require("imgui")

local helpers = {}

helpers.settings = {}

helpers.settings.load = function(default_table, filename)
    assert(filename ~= nil, "No filename provided to settings.load()")

    local f = loadfile(filename)
    if f ~= nil then
        local result = f()
        if type(result) == "table" then
            return setmetatable(result, {__index = default_table})
        else
            return default_table
        end
    end
    return default_table
end

local function serializeTable(t, indent)
    indent = indent or ""
    local nextIndent = indent .. "    "
    local lines = {"{\n"}
    for k, v in pairs(t) do
        local keyStr = (type(k) == "string" and string.format("[%q]", k)) or ("["..k.."]")
        if type(v) == "table" then
            table.insert(lines, nextIndent .. keyStr .. " = " .. serializeTable(v, nextIndent) .. ",\n")
        elseif type(v) == "string" then
            table.insert(lines, nextIndent .. keyStr .. " = " .. string.format("%q", v) .. ",\n")
        else
            table.insert(lines, nextIndent .. keyStr .. " = " .. tostring(v) .. ",\n")
        end
    end
    table.insert(lines, indent .. "}")
    return table.concat(lines)
end

helpers.settings.save = function(data, filename)
    assert(filename ~= nil, "No filename provided to settings.save()")

    local f = io.open(filename, "w+")
    if f ~= nil then
        f:write("return " .. serializeTable(data))
        f:close()
    else
        print(chat.header(addon.name):append(chat.error("Failed to open file for saving: " .. filename)))
    end
end

helpers.initializeFallbackTexture = function()
    if variables.fallbackTexture then
        variables.textureCache["misc/fallback.png"] = variables.fallbackTexture
    else
        print(chat.header(addon.name):append(chat.error("Failed to load fallback texture from: " .. variables.fallbackTexturePath)))
    end
end

helpers.loadPreviewTextures = function()
    for i = 1, 4 do
        local previewPath = addon.path .. "resources/misc/" .. i .. ".png"
        local texture = images.loadTextureFromFile(previewPath)
        variables.textureCache["misc/" .. i .. ".png"] = texture
    end
end

helpers.fileExists = function (filePath)
    local f = io.open(filePath, "r")
    if f then
        io.close(f)
        return true
    else
        return false
    end
end

helpers.windowExists = function(windowName, settings)
    if not settings or not settings.windows then return false end
    return settings.windows[windowName] ~= nil
end

helpers.get_game_menu_name = function ()
    local menu_pointer = ashita.memory.read_uint32(variables.pGameMenu)
    if menu_pointer == 0 then
        return ""
    end
    local menu_val = ashita.memory.read_uint32(menu_pointer)
    if menu_val == 0 then
        return ""
    end
    local menu_header = ashita.memory.read_uint32(menu_val + 4)
    if menu_header == 0 then
        return ""
    end
    local menu_name = ashita.memory.read_string(menu_header + 0x46, 16)
    return menu_name:gsub("\x00", ""):gsub("menu[%s]+", ""):trim()
end


helpers.is_game_interface_hidden = function()
    if variables.pInterfaceHidden == 0 then
        return false
    end
    local ptr = ashita.memory.read_uint32(variables.pInterfaceHidden + 10)
    if ptr == 0 then
        return false
    end
    return ashita.memory.read_uint8(ptr + 0xB4) == 1
end

helpers.is_event_system_active = function ()
    if variables.pEventSystem == 0 then
        return false
    end
    local ptr = ashita.memory.read_uint32(variables.pEventSystem + 1)
    if ptr == 0 then
        return false
    end
    return ashita.memory.read_uint8(ptr) == 1
end

helpers.is_chat_expanded = function()
    local ptr = ashita.memory.read_uint32(variables.pChatExpanded)
    if ptr == 0 then
        return false
    end
    return ashita.memory.read_uint8(ptr + 0xF1) ~= 0
end

helpers.addTimer = function(name, delay, commands)
    local start_time = os.clock()
    variables.timers[name] = {
        commands = commands,
        delay = delay,
        start_time = start_time,
        index = 2
    }
end

helpers.withStyleVars = function(vars, func)
    for _, var in ipairs(vars) do
        imgui.PushStyleVar(var.id, var.value)
    end
    func()
    imgui.PopStyleVar(#vars)
end

-- Todo: Wrap Colors
--local function withStyleColors(colors, func)
--    for _, color in ipairs(colors) do
--        imgui.PushStyleColor(color.id, color.value)
--    end
--    func()
--    imgui.PopStyleColor(#colors)
--end

helpers.getWindowNamesFromSettings = function(settings)
    local windowNames = {}
    local windowIndexMap = {}

    local windows = nil
    if type(settings) == "table" then
        if type(settings.windows) == "table" then
            windows = settings.windows
        elseif type(settings["windows"]) == "table" then
            windows = settings["windows"]
        end
    end

    if windows then
        if type(windows.it) == "function" then
            windows:each(
                function(data, name)
                    if type(name) == "string" and name ~= "" then
                        table.insert(windowNames, name)
                    end
                end
            )
        else
            for name, data in pairs(windows) do
                if type(name) == "string" and name ~= "" then
                    table.insert(windowNames, name)
                end
            end
        end

        table.sort(windowNames)

        for i, name in ipairs(windowNames) do
            windowIndexMap[name] = i
        end
    else
        print(chat.header(addon.name):append(chat.error("Windows table not found in settings")))
        print(chat.header(addon.name):append(chat.error("Available keys: " .. table.concat(table.keys(settings or {}), ", "))))
    end

    return windowNames, windowIndexMap
end

helpers.cacheWindowSettings = function(windowName, userSettings)
    local window = userSettings.windows[windowName]
    if window then
        window.windowPos = window.windowPos or {x = 100, y = 100}

        variables.cachedSettings[windowName] = {
            windowColor = {unpack(window.windowColor or {0.078, 0.890, 0.804, 0.49})},
            buttonColor = {unpack(window.buttonColor or {0.2, 0.4, 0.8, 1.0})},
            textColor = {unpack(window.textColor or {1.0, 1.0, 1.0, 1.0})},
            maxButtonsPerRow = {window.maxButtonsPerRow and window.maxButtonsPerRow[1] or 4},
            buttonSpacing = {window.buttonSpacing and window.buttonSpacing[1] or 10},
            buttonWidth = {window.buttonWidth and window.buttonWidth[1] or 105},
            buttonHeight = {window.buttonHeight and window.buttonHeight[1] or 22},
            imageButtonWidth = {window.imageButtonWidth and window.imageButtonWidth[1] or 40},
            imageButtonHeight = {window.imageButtonHeight and window.imageButtonHeight[1] or 40},
            windowType = window.type or "normal",
            windowPos = {x = window.windowPos.x, y = window.windowPos.y}
        }
    end
end

helpers.revertWindowSettings = function(windowName, userSettings)
    local cached = variables.cachedSettings[windowName]
    if cached and userSettings.windows[windowName] then
        local window = userSettings.windows[windowName]
        window.windowColor = {unpack(cached.windowColor)}
        window.buttonColor = {unpack(cached.buttonColor)}
        window.textColor = {unpack(cached.textColor)}
        window.maxButtonsPerRow = {cached.maxButtonsPerRow[1]}
        window.buttonSpacing = {cached.buttonSpacing[1]}
        window.buttonWidth = {cached.buttonWidth[1]}
        window.buttonHeight = {cached.buttonHeight[1]}
        window.imageButtonWidth = {cached.imageButtonWidth[1]}
        window.imageButtonHeight = {cached.imageButtonHeight[1]}
        window.type = cached.windowType
    end
end

helpers.initializeWindowDialog = function(dialogType, windowName)
    local userSettings = variables.altCommand and variables.altCommand.settings or settings
    local windowNames, _ = helpers.getWindowNamesFromSettings(userSettings)

    if #windowNames == 0 then
        return false
    end

    windowName = windowName or windowNames[1]
    if not variables.altCommand.settings.windows[windowName] then
        print(chat.header(addon.name):append(chat.error('Window "' .. windowName .. '" not found.')))
        return false
    end

    local window = variables.altCommand.settings.windows[windowName]

    if dialogType == "new" then
        variables.newWindowDialog.isVisible = true
        variables.newWindowDialog.windowName = {""}
        variables.newWindowDialog.windowColor = {0.078, 0.890, 0.804, 0.49}
        variables.newWindowDialog.buttonColor = {0.2, 0.4, 0.8, 1.0}
        variables.newWindowDialog.windowType = {"normal"}
        variables.newWindowDialog.previewWindow = {
            commands = T {},
            windowPos = T {x = 100, y = 100},
            isDraggable = false,
            maxButtonsPerRow = {4},
            buttonSpacing = {5},
            buttonWidth = {105},
            buttonHeight = {22},
            imageButtonWidth = {40},
            imageButtonHeight = {40}
        }

        local previewTexturePath = "misc/preview.png"
        if not variables.textureCache[previewTexturePath] then
            local fullTexturePath = addon.path .. "/resources/" .. previewTexturePath
            if helpers.fileExists(fullTexturePath) then
                local loadedTexture = images.loadTextureFromFile(fullTexturePath)
                if loadedTexture then
                    variables.textureCache[previewTexturePath] = loadedTexture
                else
                    print(chat.header(addon.name):append(chat.error("Failed to load preview texture.")))
                end
            end
        end

        return true
    end

    if dialogType == "add" then
        variables.addButtonDialog.isVisible = true
        variables.addButtonDialog.selectedWindow = windowName
        variables.addButtonDialog.selectedWindowIndex = {1}
        variables.addButtonDialog.commandName = {""}
        variables.addButtonDialog.commandText = {""}
        variables.addButtonDialog.texturePath = {""}
        variables.addButtonDialog.previewTexture = nil
    end

    helpers.cacheWindowSettings(windowName, userSettings)
    return true
end

helpers.loadSelectedCommandFields = function(selectedWindow)
    local idx = variables.addButtonDialog.selectedCommandIndex
    if not idx then
        return
    end

    local totalExisting = #selectedWindow.commands
    if idx <= totalExisting then
        local command = selectedWindow.commands[idx]
        variables.editCommandName = {command.text or ""}
        variables.editCommandType = {command.commandType or "isDirect"}
        variables.editCommandText = {command.command or ""}
        variables.editToggleCommand = {command.toggleCommand or ""}
        variables.editToggleWords = {command.toggleWords or "on,off"}
        variables.editSeriesDelay = {command.seriesDelay or 1.0}
        variables.editWindowToggleName = {command.windowToggleName or ""}
        variables.editTexturePath = {command.image or ""}

        variables.editSeriesCommandInputs = {{""}}
        if command.seriesCommands then
            variables.editSeriesCommandInputs = {}
            for cmd in command.seriesCommands:gmatch("[^,]+") do
                table.insert(variables.editSeriesCommandInputs, {cmd:trim()})
            end
            table.insert(variables.editSeriesCommandInputs, {""})
        end
    end
end

helpers.saveSelectedCommandChanges = function(selectedWindow)
    local idx = variables.addButtonDialog.selectedCommandIndex
    if not idx then
        return
    end

    local totalExisting = #selectedWindow.commands
    if idx <= totalExisting then
        local command = selectedWindow.commands[idx]
        command.text = variables.editCommandName[1]
        command.commandType = variables.editCommandType[1]
        command.command = (variables.editCommandType[1] == "isDirect") and variables.editCommandText[1] or nil
        command.toggleCommand = (variables.editCommandType[1] == "isToggle") and variables.editToggleCommand[1] or nil
        command.toggleWords = (variables.editCommandType[1] == "isToggle") and variables.editToggleWords[1] or nil
        command.windowToggleName = (variables.editCommandType[1] == "isWindow") and variables.editWindowToggleName[1] or nil
        command.image = selectedWindow.type == "imgbutton" and variables.editTexturePath[1] or nil

        if variables.editCommandType[1] == "isSeries" then
            local nonEmptyCommands = {}
            for _, cmd in ipairs(variables.editSeriesCommandInputs) do
                if cmd[1] ~= "" then
                    table.insert(nonEmptyCommands, cmd[1])
                end
            end
            command.seriesCommands = table.concat(nonEmptyCommands, ",")
            command.seriesDelay = variables.editSeriesDelay[1]
        else
            command.seriesCommands = nil
            command.seriesDelay = nil
        end
    end
    helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
end

helpers.ensureNewWindowDefaults = function()
    variables.newWindowDialog.windowName[1] = variables.newWindowDialog.windowName[1] or ""
    variables.newWindowDialog.windowColor = variables.newWindowDialog.windowColor or {0.078, 0.890, 0.804, 0.49}
    variables.newWindowDialog.buttonColor = variables.newWindowDialog.buttonColor or {0.2, 0.4, 0.8, 1.0}
    variables.newWindowDialog.windowType = variables.newWindowDialog.windowType or {"normal"}
    if not variables.newWindowDialog.previewWindow then
        variables.newWindowDialog.previewWindow = {
            commands = T {},
            windowPos = T {x = 100, y = 100},
            isDraggable = false,
            isVisible = true,
            windowColor = {0.078, 0.890, 0.804, 0.49},
            buttonColor = {0.2, 0.4, 0.8, 1.0},
            textColor = {1.0, 1.0, 1.0, 1.0},
            maxButtonsPerRow = {4},
            buttonSpacing = {5},
            buttonWidth = {105},
            buttonHeight = {22},
            imageButtonWidth = {40},
            imageButtonHeight = {40},
            type = "normal"
        }
    else
        variables.newWindowDialog.previewWindow.imageButtonWidth = variables.newWindowDialog.previewWindow.imageButtonWidth or {40}
        variables.newWindowDialog.previewWindow.imageButtonHeight = variables.newWindowDialog.previewWindow.imageButtonHeight or {40}
    end
end

helpers.ensureImageButtonDefaults = function()
    if variables.newWindowDialog.windowType[1] == "imgbutton" then
        if not (variables.newWindowDialog.previewWindow.imageButtonWidth and
        type(variables.newWindowDialog.previewWindow.imageButtonWidth[1]) == "number") then
            variables.newWindowDialog.previewWindow.imageButtonWidth = {40}
        end
        if not (variables.newWindowDialog.previewWindow.imageButtonHeight and
        type(variables.newWindowDialog.previewWindow.imageButtonHeight[1]) == "number") then
            variables.newWindowDialog.previewWindow.imageButtonHeight = {40}
        end
    end
end

helpers.ensureNormalButtonDefaults = function()
    variables.newWindowDialog.previewWindow.buttonWidth = variables.newWindowDialog.previewWindow.buttonWidth or {105}
    variables.newWindowDialog.previewWindow.buttonHeight = variables.newWindowDialog.previewWindow.buttonHeight or {22}
    variables.newWindowDialog.previewWindow.buttonWidth[1] = math.max(1, tonumber(variables.newWindowDialog.previewWindow.buttonWidth[1]) or 105)
    variables.newWindowDialog.previewWindow.buttonHeight[1] = math.max(1, tonumber(variables.newWindowDialog.previewWindow.buttonHeight[1]) or 22)
end

helpers.clearAddButtonDialog = function()
    variables.addButtonDialog.commandName = {""}
    variables.addButtonDialog.commandType = {"isDirect"}
    variables.addButtonDialog.commandText = {""}
    variables.addButtonDialog.toggleCommand = {""}
    variables.addButtonDialog.toggleWords = {""}
    variables.addButtonDialog.seriesCommands = {""}
    variables.addButtonDialog.seriesCommandInputs = {{""}}
    variables.addButtonDialog.seriesDelay = {1.0}
    variables.addButtonDialog.windowToggleName = {""}
    variables.addButtonDialog.texturePath = {""}
end

return helpers