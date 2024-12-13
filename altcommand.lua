addon.name = 'AltCommand';
addon.author = 'Redacted';
addon.version = '1.0';
addon.description = 'Send commands via highly customizable buttons.';

require('common')
local chat      = require('chat');
local imgui     = require('imgui');
local bit       = require('bit');
local settings  = require('settings');
local images    = require('images');
local ffi       = require('ffi');

local textureCache = {}
local timers = {}
local cachedSettings = {}
local editCommandName = {""}
local editCommandType = {"isDirect"}
local editCommandText = {""}
local editToggleCommand = {""}
local editToggleWords = {"on,off"}
local editSeriesCommands = {""}
local editSeriesCommandInputs = { {""} }
local editSeriesDelay = {1.0}
local editWindowToggleName = {""}
local editTexturePath = {""}
local currentTab = "Add Button"
local flags = { no_move = ImGuiWindowFlags_NoMove, no_title = ImGuiWindowFlags_NoTitleBar, no_resize = ImGuiWindowFlags_NoResize, no_scroll = ImGuiWindowFlags_NoScrollbar, no_scroll_mouse = ImGuiWindowFlags_NoScrollWithMouse,}
local isUIVisible = true
local current_menu = ''
local defines = {
    menus = {
        auction_menu = 'auc[%d]',
        map = 'map',
        region_map = 'cnqframe',
    }
}

local fallbackTexturePath = addon.path .. '/resources/misc/fallback.png'
local fallbackTexture = images.loadTextureFromFile(fallbackTexturePath)
if fallbackTexture then
    textureCache['misc/fallback.png'] = fallbackTexture
else
    print('Failed to load fallback texture from: ' .. fallbackTexturePath)
end

for i = 1, 4 do
    local previewPath = addon.path .. '/resources/misc/' .. i .. '.png'
    local texture = images.loadTextureFromFile(previewPath)
    if texture then
        textureCache['misc/' .. i .. '.png'] = texture
    else
        print('Failed to load preview texture ' .. i .. ' from: ' .. previewPath)
        -- Fall back to default texture if loading fails
        textureCache['misc/' .. i .. '.png'] = fallbackTexture
    end
end

local function fileExists(filePath)
    local f = io.open(filePath, "r")
    if f then
        io.close(f)
        return true
    else
        return false
    end
end

local pGameMenu = ashita.memory.find('FFXiMain.dll', 0, '8B480C85C974??8B510885D274??3B05', 16, 0)
local function get_game_menu_name()
    local menu_pointer = ashita.memory.read_uint32(pGameMenu)
    if menu_pointer == 0 then return '' end
    local menu_val = ashita.memory.read_uint32(menu_pointer)
    if menu_val == 0 then return '' end
    local menu_header = ashita.memory.read_uint32(menu_val + 4)
    if menu_header == 0 then return '' end
    local menu_name = ashita.memory.read_string(menu_header + 0x46, 16)
    return menu_name:gsub('\x00', ''):gsub('menu[%s]+', ''):trim()
end

local pInterfaceHidden = ashita.memory.find('FFXiMain.dll', 0, '8B4424046A016A0050B9????????E8????????F6D81BC040C3', 0, 0)
local function is_game_interface_hidden()
    if pInterfaceHidden == 0 then return false end
    local ptr = ashita.memory.read_uint32(pInterfaceHidden + 10)
    if ptr == 0 then return false end
    return ashita.memory.read_uint8(ptr + 0xB4) == 1
end

local pEventSystem = ashita.memory.find('FFXiMain.dll', 0, 'A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3', 0, 0)
local function is_event_system_active()
    if pEventSystem == 0 then return false end
    local ptr = ashita.memory.read_uint32(pEventSystem + 1)
    if ptr == 0 then return false end
    return ashita.memory.read_uint8(ptr) == 1
end

local pChatExpanded = ashita.memory.find('FFXiMain.dll', 0, '83EC??B9????????E8????????0FBF4C24??84C0', 0x04, 0)
local function is_chat_expanded()
    local ptr = ashita.memory.read_uint32(pChatExpanded)
    if ptr == 0 then return false end
    return ashita.memory.read_uint8(ptr + 0xF1) ~= 0
end

function string.trim(s)
    return s:match('^%s*(.-)%s*$')
end

local defaultWindow = {
    commands = T{
        T{ 
            text = "Click Me",
            commandType = "isDirect",
            command = "/altc help" 
        },
    },
    windowPos = T{ x = 100, y = 100 },
    isDraggable = true,
    isVisible = true,
    windowColor = { 0.016, 0.055, 0.051, 0.49 },
    buttonColor = { 0.2, 0.376, 0.8, 1.0 },
    textColor = { 1, 1, 1, 1 },            
    type = "normal",
    maxButtonsPerRow = { 1 },
    buttonSpacing = { 5 },
    buttonWidth = { 105 },
    buttonHeight = { 22 },
    imageButtonWidth = { 40 },
    imageButtonHeight = { 40 }
}

local default_settings = T{
    windows = T{}
};

local altCommand = T{
    settings = settings.load(default_settings),
};

local newWindowDialog = {
    windowName = {""},
    windowColor = {0.078, 0.890, 0.804, 0.49},
    buttonColor = {0.2, 0.4, 0.8, 1.0},
    textColor = {1.0, 1.0, 1.0, 1.0},
    windowType = {"normal"},
    previewWindow = {
        maxButtonsPerRow = {4},
        buttonSpacing = {10},
        buttonWidth = {105},
        buttonHeight = {22},
        imageButtonWidth = {40},
        imageButtonHeight = {40},
    }
}

local editWindowDialog = {
    isVisible = false,
    isOpen = { true },
    windowName = "",
    windowColor = { 0.078, 0.890, 0.804, 0.49 },
    buttonColor = { 0.2, 0.4, 0.8, 1.0 },
    textColor = {1.0, 1.0, 1.0, 1.0},
    maxButtonsPerRow = { 4 },
    buttonSpacing = { 10 },
    buttonWidth = { 105 },
    buttonHeight = { 22 },
    imageButtonWidth = { 40 },
    imageButtonHeight = { 40 },
    originalWindowName = "",
    originalSettings = {}
}

local addButtonDialog = {
    isVisible = false,
    isOpen = { true },
    selectedWindowIndex = { 1 },
    selectedWindow = { "" },    
    commandType = { "isDirect" }, 
    toggleCommand = { "" },
    toggleWords = { "" },      
    seriesDelay = { 1.0 },
    seriesCommands = { {""} },
    seriesCommandInputs = { {""} },
    windowToggleName = { "" },
    commandName = { "" },
    commandText = { "" },
    texturePath = { "" },
    previewTexture = nil,
    previewButtonColor = { 0.2, 0.4, 0.8, 1.0 },
    fallbackTexture = nil,
    inlineCommandDisplay = {
        commands = T{},
        windowColor = { 0.078, 0.890, 0.804, 0.49 },
        buttonColor = { 0.2, 0.4, 0.8, 1.0 },
        type = "normal",
        maxButtonsPerRow = { 4 },
        buttonSpacing = { 10 },
        buttonWidth = { 105 },
        buttonHeight = { 22 },
        imageButtonWidth = { 40 },
        imageButtonHeight = { 40 }
    }
}

local deleteConfirmDialog = {
    isVisible = false,
    isOpen = { true },
    windowToDelete = nil
}

local helpDialog = {
    isVisible = false,
    isOpen = { true }
}

addButtonDialog.selectedCommandIndex = nil

local function addTimer(name, delay, commands)
    local start_time = os.clock()
    timers[name] = {
        commands = commands,
        delay = delay,
        start_time = start_time,
        index = 2 -- Start with the second command, since the first is executed immediately
    }
end

local function getWindowNamesFromSettings(settings)
    local windowNames = {}
    local windowIndexMap = {}

    -- Handle both table types and ensure windows exists
    local windows = nil
    if type(settings) == "table" then
        if type(settings.windows) == "table" then
            windows = settings.windows
        elseif type(settings["windows"]) == "table" then 
            windows = settings["windows"]
        end
    end

    -- Process windows if found
    if windows then
        -- Handle both regular tables and T{} tables
        if type(windows.it) == "function" then
            -- It's a T{} table
            windows:each(function(data, name)
                if type(name) == "string" and name ~= "" then
                    table.insert(windowNames, name)
                    windowIndexMap[name] = #windowNames
                end
            end)
        else
            -- Regular Lua table
            for name, data in pairs(windows) do
                if type(name) == "string" and name ~= "" then
                    table.insert(windowNames, name)
                    windowIndexMap[name] = #windowNames
                end
            end
        end
    else
        print("Windows table not found in settings")
        print("Available keys:", table.concat(table.keys(settings or {}), ", "))
    end

    return windowNames, windowIndexMap
end

local function cacheWindowSettings(windowName, userSettings)
    local window = userSettings.windows[windowName]
    if window then
        -- Deep copy all values to avoid reference issues
        cachedSettings[windowName] = {
            windowColor = { unpack(window.windowColor or { 0.078, 0.890, 0.804, 0.49 }) },
            buttonColor = { unpack(window.buttonColor or { 0.2, 0.4, 0.8, 1.0 }) },
            textColor = { unpack(window.textColor or { 1.0, 1.0, 1.0, 1.0 }) },
            maxButtonsPerRow = { window.maxButtonsPerRow and window.maxButtonsPerRow[1] or 4 },
            buttonSpacing = { window.buttonSpacing and window.buttonSpacing[1] or 10 },
            buttonWidth = { window.buttonWidth and window.buttonWidth[1] or 105 },
            buttonHeight = { window.buttonHeight and window.buttonHeight[1] or 22 },
            imageButtonWidth = { window.imageButtonWidth and window.imageButtonWidth[1] or 40 },
            imageButtonHeight = { window.imageButtonHeight and window.imageButtonHeight[1] or 40 },
            windowType = window.type or "normal"
        }
    end
end

local function revertWindowSettings(windowName, userSettings)
    local cached = cachedSettings[windowName]
    if cached and userSettings.windows[windowName] then
        local window = userSettings.windows[windowName]
        -- Deep copy all values back from cache
        window.windowColor = { unpack(cached.windowColor) }
        window.buttonColor = { unpack(cached.buttonColor) }
        window.textColor = { unpack(cached.textColor) }
        window.maxButtonsPerRow = { cached.maxButtonsPerRow[1] }
        window.buttonSpacing = { cached.buttonSpacing[1] }
        window.buttonWidth = { cached.buttonWidth[1] }
        window.buttonHeight = { cached.buttonHeight[1] }
        window.imageButtonWidth = { cached.imageButtonWidth[1] }
        window.imageButtonHeight = { cached.imageButtonHeight[1] }
        window.type = cached.windowType
    end
end

local function initializeWindowDialog(dialogType, windowName)
    local userSettings = altCommand and altCommand.settings or settings
    local windowNames, _ = getWindowNamesFromSettings(userSettings)
    
    if #windowNames == 0 then
        print(chat.header(addon.name):append(chat.error('No windows found.')))
        return false
    end

    -- Use provided window name or default to first window
    windowName = windowName or windowNames[1]
    if not altCommand.settings.windows[windowName] then
        print(chat.header(addon.name):append(chat.error('Window "' .. windowName .. '" not found.')))
        return false
    end

    local window = altCommand.settings.windows[windowName]
    
    -- New Window
    if dialogType == "new" then
        -- Initialize new window dialog
        newWindowDialog.isVisible = true
        newWindowDialog.windowName = { "" }
        newWindowDialog.windowColor = { 0.078, 0.890, 0.804, 0.49 }
        newWindowDialog.buttonColor = { 0.2, 0.4, 0.8, 1.0 }
        newWindowDialog.windowType = { "normal" }
        newWindowDialog.previewWindow = {
            commands = T{},
            windowPos = T{ x = 100, y = 100 },
            isDraggable = false,
            maxButtonsPerRow = { 4 },
            buttonSpacing = { 5 },
            buttonWidth = { 105 },
            buttonHeight = { 22 },
            imageButtonWidth = { 40 },
            imageButtonHeight = { 40 }
        }

        -- Cache preview texture if not already cached
        local previewTexturePath = 'misc/preview.png'
        if not textureCache[previewTexturePath] then
            local fullTexturePath = addon.path .. '/resources/' .. previewTexturePath
            if fileExists(fullTexturePath) then
                local loadedTexture = images.loadTextureFromFile(fullTexturePath)
                if loadedTexture then
                    textureCache[previewTexturePath] = loadedTexture
                else
                    print(chat.header(addon.name):append(chat.error('Failed to load preview texture.')))
                end
            end
        end

        return true
    end
    
    -- Edit Window
    if dialogType == "edit" then
        -- Initialize edit dialog
        editWindowDialog.isVisible = true
        editWindowDialog.windowName = windowName
        editWindowDialog.originalWindowName = windowName
        editWindowDialog.windowColor = window.windowColor or { 0.078, 0.890, 0.804, 0.49 }
        editWindowDialog.buttonColor = window.buttonColor or { 0.2, 0.4, 0.8, 1.0 }
        editWindowDialog.maxButtonsPerRow = window.maxButtonsPerRow or { 4 }
        editWindowDialog.buttonSpacing = window.buttonSpacing or { 5 }
        editWindowDialog.buttonWidth = window.buttonWidth or { 105 }
        editWindowDialog.buttonHeight = window.buttonHeight or { 22 }
        editWindowDialog.imageButtonWidth = window.imageButtonWidth or { 40 }
        editWindowDialog.imageButtonHeight = window.imageButtonHeight or { 40 }
        editWindowDialog.windowType = { window.type or "normal" }
    
    -- Add Button
    elseif dialogType == "add" then
        -- Initialize add dialog
        addButtonDialog.isVisible = true
        addButtonDialog.selectedWindow = windowName
        addButtonDialog.selectedWindowIndex = { 1 }
        addButtonDialog.commandName = { "" }
        addButtonDialog.commandText = { "" }
        addButtonDialog.texturePath = { "" }
        addButtonDialog.previewTexture = nil
    end

    -- Cache window settings
    cacheWindowSettings(windowName, userSettings)
    return true
end

local function loadSelectedCommandFields(selectedWindow)
    local idx = addButtonDialog.selectedCommandIndex
    if not idx then return end

    local totalExisting = #selectedWindow.commands
    if idx <= totalExisting then
        local command = selectedWindow.commands[idx]
        -- Load command fields
        editCommandName = { command.text or "" }
        editCommandType = { command.commandType or "isDirect" }
        editCommandText = { command.command or "" }
        editToggleCommand = { command.toggleCommand or "" }
        editToggleWords = { command.toggleWords or "on,off" }
        editSeriesDelay = { command.seriesDelay or 1.0 }
        editWindowToggleName = { command.windowToggleName or "" }
        editTexturePath = { command.image or "" }
        
        -- Handle series commands
        editSeriesCommandInputs = { {""} }
        if command.seriesCommands then
            editSeriesCommandInputs = {}
            for cmd in command.seriesCommands:gmatch("[^,]+") do
                table.insert(editSeriesCommandInputs, {cmd:trim()})
            end
            -- Add empty input at end
            table.insert(editSeriesCommandInputs, {""})
        end
    end
end

local function saveSelectedCommandChanges(selectedWindow)
    local idx = addButtonDialog.selectedCommandIndex
    if not idx then return end

    local totalExisting = #selectedWindow.commands
    if idx <= totalExisting then
        local command = selectedWindow.commands[idx]
        -- Save command fields
        command.text = editCommandName[1]
        command.commandType = editCommandType[1]
        command.command = (editCommandType[1] == "isDirect") and editCommandText[1] or nil
        command.toggleCommand = (editCommandType[1] == "isToggle") and editToggleCommand[1] or nil
        command.toggleWords = (editCommandType[1] == "isToggle") and editToggleWords[1] or nil
        command.windowToggleName = (editCommandType[1] == "isWindow") and editWindowToggleName[1] or nil
        command.image = selectedWindow.type == "imgbutton" and editTexturePath[1] or nil

        -- Handle series commands
        if editCommandType[1] == "isSeries" then
            local nonEmptyCommands = {}
            for _, cmd in ipairs(editSeriesCommandInputs) do
                if cmd[1] ~= "" then
                    table.insert(nonEmptyCommands, cmd[1])
                end
            end
            command.seriesCommands = table.concat(nonEmptyCommands, ",")
            command.seriesDelay = editSeriesDelay[1]
        else 
            command.seriesCommands = nil
            command.seriesDelay = nil
        end
    end
    settings.save()
end

local function ensureNewWindowDefaults()
    newWindowDialog.windowName[1] = newWindowDialog.windowName[1] or ""
    newWindowDialog.windowColor = newWindowDialog.windowColor or {0.078, 0.890, 0.804, 0.49}
    newWindowDialog.buttonColor = newWindowDialog.buttonColor or {0.2, 0.4, 0.8, 1.0}
    newWindowDialog.windowType = newWindowDialog.windowType or {"normal"}
    if not newWindowDialog.previewWindow then
        newWindowDialog.previewWindow = {
            commands = T{},
            windowPos = T{ x = 100, y = 100 },
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
        newWindowDialog.previewWindow.imageButtonWidth = newWindowDialog.previewWindow.imageButtonWidth or {40}
        newWindowDialog.previewWindow.imageButtonHeight = newWindowDialog.previewWindow.imageButtonHeight or {40}
    end
end

local function ensureImageButtonDefaults()
    if newWindowDialog.windowType[1] == "imgbutton" then
        if not (newWindowDialog.previewWindow.imageButtonWidth and type(newWindowDialog.previewWindow.imageButtonWidth[1]) == "number") then
            newWindowDialog.previewWindow.imageButtonWidth = {40}
        end
        if not (newWindowDialog.previewWindow.imageButtonHeight and type(newWindowDialog.previewWindow.imageButtonHeight[1]) == "number") then
            newWindowDialog.previewWindow.imageButtonHeight = {40}
        end
    end
end

local function ensureNormalButtonDefaults()
    newWindowDialog.previewWindow.buttonWidth = newWindowDialog.previewWindow.buttonWidth or {105}
    newWindowDialog.previewWindow.buttonHeight = newWindowDialog.previewWindow.buttonHeight or {22}

    -- Ensure values are valid numbers
    newWindowDialog.previewWindow.buttonWidth[1] = math.max(1, tonumber(newWindowDialog.previewWindow.buttonWidth[1]) or 105)
    newWindowDialog.previewWindow.buttonHeight[1] = math.max(1, tonumber(newWindowDialog.previewWindow.buttonHeight[1]) or 22)
end

local function renderWindow(window, windowName, isPreview)
    -- Validate and wrap settings for ImGui compatibility
    window.maxButtonsPerRow = window.maxButtonsPerRow or T{ 4 }
    window.buttonSpacing = window.buttonSpacing or T{ 10 }
    window.buttonWidth = window.buttonWidth or T{ 40 }
    window.buttonHeight = window.buttonHeight or T{ 40 }
    window.imageButtonWidth = window.imageButtonWidth or T{ 40 }  -- New setting
    window.imageButtonHeight = window.imageButtonHeight or T{ 40 }  -- New setting

    -- Ensure values are valid numbers
    window.maxButtonsPerRow[1] = math.max(1, tonumber(window.maxButtonsPerRow[1]) or 4)
    window.buttonSpacing[1] = math.max(0, tonumber(window.buttonSpacing[1]) or 10)
    window.buttonWidth[1] = math.max(1, tonumber(window.buttonWidth[1]) or 40)
    window.buttonHeight[1] = math.max(1, tonumber(window.buttonHeight[1]) or 40)
    window.imageButtonWidth[1] = math.max(1, tonumber(window.imageButtonWidth[1]) or 40)
    window.imageButtonHeight[1] = math.max(1, tonumber(window.imageButtonHeight[1]) or 40)

    local commands = window.commands
    local windowPos = window.windowPos
    local windowColor = window.windowColor or { 0.078, 0.890, 0.804, 0.49 }
    local buttonColor = window.buttonColor or { 0.2, 0.4, 0.8, 1.0 }
    local textColor = window.textColor or {1.0, 1.0, 1.0, 1.0}
    local maxButtonsPerRow = window.maxButtonsPerRow[1]
    local buttonSpacing = window.buttonSpacing[1]
    local buttonWidth = window.type == "imgbutton" and window.imageButtonWidth[1] or window.buttonWidth[1]
    local buttonHeight = window.type == "imgbutton" and window.imageButtonHeight[1] or window.buttonHeight[1]

    -- Calculate window dimensions
    local totalRows = math.ceil(#commands / maxButtonsPerRow)

    -- Add padding compensation for image buttons
    local imagePaddingX = window.type == "imgbutton" and 8 or 0
    local imagePaddingY = window.type == "imgbutton" and 6 or 0

    local effectiveButtonWidth = buttonWidth + (window.type == "imgbutton" and imagePaddingX or 0)
    local effectiveButtonHeight = buttonHeight + (window.type == "imgbutton" and imagePaddingY or 0)

    local windowWidth = (effectiveButtonWidth * maxButtonsPerRow) + (buttonSpacing * (maxButtonsPerRow - 1)) + imgui.GetStyle().WindowPadding.x * 2
    local totalHeight = (effectiveButtonHeight * totalRows) + (totalRows - 1) * buttonSpacing + imgui.GetStyle().WindowPadding.y * 2

    -- Check if shift is held
    local io = imgui.GetIO()
    local shift_held = io.KeyShift

    -- Set window flags based on shift state
    local windowFlags = bit.bor(
        flags.no_title,
        flags.no_resize,
        flags.no_scroll,
        flags.no_scroll_mouse
    )
    
    -- Add no_move flag if shift is not held
    if not shift_held then
        windowFlags = bit.bor(windowFlags, flags.no_move)
    end

    imgui.SetNextWindowSize({ windowWidth, totalHeight }, ImGuiCond_Always)

    if window.isDraggable then
        imgui.SetNextWindowPos({ windowPos.x, windowPos.y }, ImGuiCond_FirstUseEver)
    else
        imgui.SetNextWindowPos({ windowPos.x, windowPos.y }, ImGuiCond_Always)
    end

    imgui.PushStyleColor(ImGuiCol_WindowBg, { windowColor[1], windowColor[2], windowColor[3], windowColor[4] })

    if imgui.Begin(windowName, true, windowFlags) then
        imgui.PushStyleColor(ImGuiCol_Button, buttonColor)
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, buttonColor)
        imgui.PushStyleColor(ImGuiCol_ButtonActive, buttonColor)

        for i = 1, #commands, maxButtonsPerRow do
            local buttonsInRow = math.min(maxButtonsPerRow, #commands - i + 1)
            local totalButtonWidth = (buttonsInRow * effectiveButtonWidth) + ((buttonsInRow - 1) * buttonSpacing)
            local paddingX = (windowWidth - totalButtonWidth) / 2
        
            imgui.SetCursorPosX(paddingX)

            for j = 0, buttonsInRow - 1 do
                local command = commands[i + j]

                -- Determine label for toggle commands
                local label = command.text or "No Label"
                if command.commandType == "isToggle" then
                    label = command.is_on and (command.text .. " Off") or command.text
                end

                local buttonClicked = false

                if command.image and window.type == "imgbutton" then
                    -- Attempt to get or load the texture
                    local texture = textureCache[command.image]
                    if not texture then
                        -- Try loading the texture now
                        local fullPath = addon.path .. '/resources/' .. command.image:gsub('\\', '/')
                        if fileExists(fullPath) then
                            local loadedTexture = images.loadTextureFromFile(fullPath)
                            if loadedTexture then
                                textureCache[command.image] = loadedTexture
                                texture = loadedTexture
                            else
                                print("Failed to load texture from: " .. fullPath .. " - Using fallback.")
                                command.image = 'misc/fallback.png'
                                textureCache['misc/fallback.png'] = fallbackTexture
                                texture = fallbackTexture
                            end
                        else
                            print("Texture file not found: " .. fullPath .. " - Using fallback.")
                            command.image = 'misc/fallback.png'
                            textureCache['misc/fallback.png'] = fallbackTexture
                            texture = fallbackTexture
                        end
                    end

                    if texture then
                        -- We have a valid texture or a fallback now
                        local textureID = tonumber(ffi.cast("uint32_t", texture))
                        buttonClicked = imgui.ImageButton(textureID, { buttonWidth, buttonHeight })

                        -- Add tooltip to show the label and state
                        if imgui.IsItemHovered() then
                            imgui.SetTooltip(label)
                        end
                    else
                        -- If we still don't have a texture for some reason, show a disabled button
                        imgui.PushStyleVar(ImGuiStyleVar_Alpha, 0.5)
                        imgui.Button(label, { buttonWidth, buttonHeight })
                        imgui.PopStyleVar()
                    end
                else
                    -- Text button
                    imgui.PushStyleColor(ImGuiCol_Text, textColor)
                    buttonClicked = imgui.Button(label, { buttonWidth, buttonHeight })
                    imgui.PopStyleColor()
                end

                if buttonClicked then
                    -- Handle different command types
                    if command.commandType == "isToggle" then
                        -- Toggle command
                        local toggle_command
                        if command.is_on then
                            -- Extract the "off" word from toggleWords (in case of custom toggles)
                            toggle_command = (command.toggleCommand or "") .. " " .. (command.toggleWords:match(",%s*(.+)") or "off")
                        else
                            -- Extract the "on" word from toggleWords (in case of custom toggles)
                            toggle_command = (command.toggleCommand or "") .. " " .. (command.toggleWords:match("([^,]+)") or "on")
                        end

                        -- Queue the toggle command
                        AshitaCore:GetChatManager():QueueCommand(-1, toggle_command)

                        -- Toggle the is_on state
                        command.is_on = not command.is_on

                    elseif command.commandType == "isSeries" then
                        -- Series command
                        local cmdList = {}
                        for cmd in (command.seriesCommands or ""):gmatch("[^,]+") do
                            table.insert(cmdList, cmd:trim())
                        end
                        if #cmdList > 0 then
                            AshitaCore:GetChatManager():QueueCommand(-1, cmdList[1])
                            if #cmdList > 1 then
                                addTimer("series_" .. command.text, command.seriesDelay or 1.0, cmdList)
                            end
                        end

                    elseif command.commandType == "isWindow" then
                        -- Window toggle command
                        local targetWindow = altCommand.settings.windows[command.windowToggleName or command.text]
                        if targetWindow then
                            targetWindow.isVisible = not targetWindow.isVisible
                        end

                    elseif command.commandType == "isDirect" or command.commandType == nil then
                        -- Direct command
                        if command.command and command.command ~= "" then
                            AshitaCore:GetChatManager():QueueCommand(-1, command.command)
                        end
                    end
                end

                -- Move to the next button in the row
                if j < buttonsInRow - 1 then
                    imgui.SameLine(0, buttonSpacing)
                end
            end
        end

        -- Save window position dynamically when dragged
        if window.isDraggable and imgui.IsWindowHovered() and imgui.IsMouseDragging(0) then
            windowPos.x, windowPos.y = imgui.GetWindowPos()
        end

        imgui.PopStyleColor(3)
        imgui.End()
    end

    imgui.PopStyleColor(1)
end

local function renderCommandsInline(window)
    window.maxButtonsPerRow = window.maxButtonsPerRow or T{ 4 }
    window.buttonSpacing = window.buttonSpacing or T{ 10 }
    window.buttonWidth = window.buttonWidth or T{ 40 }
    window.buttonHeight = window.buttonHeight or T{ 40 }
    window.imageButtonWidth = window.imageButtonWidth or T{ 40 }
    window.imageButtonHeight = window.imageButtonHeight or T{ 40 }

    window.maxButtonsPerRow[1] = math.max(1, tonumber(window.maxButtonsPerRow[1]) or 4)
    window.buttonSpacing[1] = math.max(0, tonumber(window.buttonSpacing[1]) or 10)
    window.buttonWidth[1] = math.max(1, tonumber(window.buttonWidth[1]) or 40)
    window.buttonHeight[1] = math.max(1, tonumber(window.buttonHeight[1]) or 40)
    window.imageButtonWidth[1] = math.max(1, tonumber(window.imageButtonWidth[1]) or 40)
    window.imageButtonHeight[1] = math.max(1, tonumber(window.imageButtonHeight[1]) or 40)

    local commands = window.commands
    local buttonColor = window.buttonColor or { 0.2, 0.4, 0.8, 1.0 }
    local maxButtonsPerRow = window.maxButtonsPerRow[1]
    local buttonSpacing = window.buttonSpacing[1]
    local buttonWidth = (window.type == "imgbutton") and window.imageButtonWidth[1] or window.buttonWidth[1]
    local buttonHeight = (window.type == "imgbutton") and window.imageButtonHeight[1] or window.buttonHeight[1]

    imgui.PushStyleColor(ImGuiCol_Button, buttonColor)
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, buttonColor)
    imgui.PushStyleColor(ImGuiCol_ButtonActive, buttonColor)

    local totalRows = math.ceil(#commands / maxButtonsPerRow)
    for i = 1, #commands, maxButtonsPerRow do
        local buttonsInRow = math.min(maxButtonsPerRow, #commands - i + 1)
        
        for j = 0, buttonsInRow - 1 do
            local command = commands[i + j]

            if command.text == "Follow" then
                local label = command.is_on and "Follow Off" or "Follow"
                if imgui.Button(label, { buttonWidth, buttonHeight }) then
                    local toggle_command = command.is_on and command.command_off or command.command_on
                    AshitaCore:GetChatManager():QueueCommand(-1, toggle_command)
                    command.is_on = not command.is_on
                end
            elseif command.text == "Attack" then
                if imgui.Button(command.text, { buttonWidth, buttonHeight }) then
                    local cmdList = { command.command, "/mss /follow [t]" }
                    AshitaCore:GetChatManager():QueueCommand(-1, cmdList[1])
                    if #cmdList > 1 then
                        addTimer("attack_sequence", 1, cmdList)
                    end
                end
            elseif command.image then
                -- Attempt to get or load the image texture
                local texture = textureCache[command.image]
                if not texture then
                    -- Try loading it now
                    local fullPath = addon.path .. '/resources/' .. command.image:gsub('\\', '/')
                    if fileExists(fullPath) then
                        local loadedTexture = images.loadTextureFromFile(fullPath)
                        if loadedTexture then
                            textureCache[command.image] = loadedTexture
                            texture = loadedTexture
                        else
                            texture = fallbackTexture
                        end
                    else
                        texture = fallbackTexture
                    end
                end

                if texture then
                    local textureID = tonumber(ffi.cast("uint32_t", texture))
                    if imgui.ImageButton(textureID, { buttonWidth, buttonHeight }) then
                        if altCommand.settings.windows[command.text] then
                            local w = altCommand.settings.windows[command.text]
                            w.isVisible = not w.isVisible
                        else
                            AshitaCore:GetChatManager():QueueCommand(-1, command.command)
                        end
                    end
                else
                    -- If we don't have a texture (and no fallback), just render a disabled button or text
                    imgui.PushStyleVar(ImGuiStyleVar_Alpha, 0.5)
                    imgui.Button(command.text or "No Image", { buttonWidth, buttonHeight })
                    imgui.PopStyleVar()
                end
            elseif altCommand.settings.windows[command.text] then
                if imgui.Button(command.text, { buttonWidth, buttonHeight }) then
                    local w = altCommand.settings.windows[command.text]
                    w.isVisible = not w.isVisible
                end
            else
                if imgui.Button(command.text, { buttonWidth, buttonHeight }) then
                    AshitaCore:GetChatManager():QueueCommand(-1, command.command)
                end
            end

            if j < buttonsInRow - 1 then
                imgui.SameLine(0, buttonSpacing)
            end
        end
    end

    imgui.PopStyleColor(3)
end

local function renderPreviewInline(windowConfig)
    local commands = windowConfig.commands
    local maxButtonsPerRow = (windowConfig.maxButtonsPerRow and windowConfig.maxButtonsPerRow[1]) or 4
    local buttonSpacing = (windowConfig.buttonSpacing and windowConfig.buttonSpacing[1]) or 10
    local textColor = windowConfig.textColor or {1.0, 1.0, 1.0, 1.0}
    local buttonWidth, buttonHeight
    
    if windowConfig.type == "imgbutton" then
        buttonWidth = windowConfig.imageButtonWidth[1] or 40
        buttonHeight = windowConfig.imageButtonHeight[1] or 40
    else
        buttonWidth = windowConfig.buttonWidth[1] or 105
        buttonHeight = windowConfig.buttonHeight[1] or 22
    end

    local imagePaddingX = (windowConfig.type == "imgbutton") and 8 or 0
    local imagePaddingY = (windowConfig.type == "imgbutton") and 6 or 0

    local effectiveButtonWidth = buttonWidth + ((windowConfig.type == "imgbutton") and imagePaddingX or 0)
    local effectiveButtonHeight = buttonHeight + ((windowConfig.type == "imgbutton") and imagePaddingY or 0)

    local totalRows = math.ceil(#commands / maxButtonsPerRow)
    local style = imgui.GetStyle()

    local windowWidth = (effectiveButtonWidth * maxButtonsPerRow)
        + (buttonSpacing * (maxButtonsPerRow - 1))
        + style.WindowPadding.x * 2
    local totalHeight = (effectiveButtonHeight * totalRows)
        + ((totalRows - 1) * buttonSpacing)
        + style.WindowPadding.y * 2

    local wc = windowConfig.windowColor or {0.078, 0.890, 0.804, 0.49}
    imgui.PushStyleColor(ImGuiCol_ChildBg, {wc[1], wc[2], wc[3], wc[4]})

    local windowFlags = bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoScrollWithMouse,
        ImGuiWindowFlags_AlwaysUseWindowPadding
    )
    imgui.BeginChild("ExistingWindowPreview", {windowWidth, totalHeight}, true, windowFlags)

    local buttonColor = windowConfig.buttonColor or {0.2, 0.4, 0.8, 1.0}
    imgui.PushStyleColor(ImGuiCol_Button, buttonColor)
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, buttonColor)
    imgui.PushStyleColor(ImGuiCol_ButtonActive, buttonColor)

    local cmdIndex = 0
    for i = 1, #commands, maxButtonsPerRow do
        local buttonsInRow = math.min(maxButtonsPerRow, #commands - i + 1)
        local totalButtonWidth = (effectiveButtonWidth * buttonsInRow) + ((buttonsInRow - 1) * buttonSpacing)
        local paddingX = (windowWidth - totalButtonWidth) / 2
        imgui.SetCursorPosX(paddingX)

        for j = 0, buttonsInRow - 1 do
            cmdIndex = cmdIndex + 1
            local command = commands[i + j]
            local label = command.text or "No Text"

            if command.image then
                -- Check if texture is cached
                local tex = textureCache[command.image]
                if not tex then
                    -- Attempt to load once
                    local fullPath = addon.path .. '/resources/' .. command.image:gsub('\\', '/')
                    if fileExists(fullPath) then
                        local loadedTexture = images.loadTextureFromFile(fullPath)
                        if loadedTexture then
                            textureCache[command.image] = loadedTexture
                            tex = loadedTexture
                        else
                            textureCache[command.image] = fallbackTexture
                            tex = fallbackTexture
                        end
                    else
                        textureCache[command.image] = fallbackTexture
                        tex = fallbackTexture
                    end
                end

                if tex and tex ~= fallbackTexture then
                    local textureID = tonumber(ffi.cast("uint32_t", tex))
                    if imgui.ImageButton(textureID, {buttonWidth, buttonHeight}) then
                        addButtonDialog.selectedCommandIndex = cmdIndex
                    end
                else
                    -- If even after loading we got fallbackTexture, just use text
                    label = label .. " [No Img]"
                    if imgui.Button(label, {buttonWidth, buttonHeight}) then
                        addButtonDialog.selectedCommandIndex = cmdIndex
                    end
                end
            else
                -- No image, just text
                imgui.PushStyleColor(ImGuiCol_Text, textColor)
                if imgui.Button(label, {buttonWidth, buttonHeight}) then
                    addButtonDialog.selectedCommandIndex = cmdIndex
                end
                imgui.PopStyleColor()
            end

            if j < buttonsInRow - 1 then
                imgui.SameLine(0, buttonSpacing)
            end
        end
    end

    imgui.PopStyleColor(3)
    imgui.EndChild()
    imgui.PopStyleColor()
end

local function renderAddButtonDialog()
    if not addButtonDialog.isVisible then
        return
    end

    local isOpen = addButtonDialog.isOpen

    ensureNewWindowDefaults()

    imgui.SetNextWindowSize({1400, 600}, ImGuiCond_Always)
    if imgui.Begin("Alt Command v0.1", isOpen, ImGuiWindowFlags_NoResize) then
        local userSettings = altCommand and altCommand.settings or settings
        local windowNames, windowIndexMap = getWindowNamesFromSettings(userSettings)

        if not addButtonDialog.selectedWindow and #windowNames > 0 then
            addButtonDialog.selectedWindow = windowNames[1]
            addButtonDialog.selectedWindowIndex = { 1 }
            cacheWindowSettings(windowNames[1], userSettings)
        end

        imgui.BeginChild("LeftSide", {380, -imgui.GetFrameHeightWithSpacing()}, true)
        if imgui.BeginTabBar("AddButton_NewWindow_Tabs") then
            -- New Window first
            if imgui.BeginTabItem("Create Window") then
                currentTab = "New Window"

                imgui.Text("Window Name:")
                imgui.InputText("##windowName", newWindowDialog.windowName, 64)

                imgui.Text("Window Color:")
                imgui.ColorEdit4("##windowColor", newWindowDialog.windowColor)

                imgui.Text("Button Color:")
                imgui.ColorEdit4("##buttonColor", newWindowDialog.buttonColor)

                imgui.Text("Text Color:")
                imgui.ColorEdit4("##windowTextColor", newWindowDialog.textColor)
                
                imgui.Text("Window Type:")
                if imgui.RadioButton("Normal", newWindowDialog.windowType[1] == "normal") then
                    newWindowDialog.windowType[1] = "normal"
                    newWindowDialog.previewWindow.type = "normal"
                    ensureNormalButtonDefaults()
                end
                imgui.SameLine()
                if imgui.RadioButton("Image Button", newWindowDialog.windowType[1] == "imgbutton") then
                    newWindowDialog.windowType[1] = "imgbutton"
                    newWindowDialog.previewWindow.type = "imgbutton"
                    ensureImageButtonDefaults()
                end

                ensureImageButtonDefaults()

                imgui.Text("Max Buttons Per Row:")
                imgui.InputInt("##maxButtonsPerRow", newWindowDialog.previewWindow.maxButtonsPerRow)
                if newWindowDialog.previewWindow.maxButtonsPerRow[1] < 1 then
                    newWindowDialog.previewWindow.maxButtonsPerRow[1] = 1
                end

                imgui.Text("Button Spacing:")
                imgui.InputInt("##buttonSpacing", newWindowDialog.previewWindow.buttonSpacing)

                if newWindowDialog.windowType[1] == "normal" then
                    imgui.Text("Button Width:")
                    imgui.InputInt("##buttonWidth", newWindowDialog.previewWindow.buttonWidth)
                    imgui.Text("Button Height:")
                    imgui.InputInt("##buttonHeight", newWindowDialog.previewWindow.buttonHeight)
                elseif newWindowDialog.windowType[1] == "imgbutton" then
                    ensureImageButtonDefaults()
                    imgui.Text("Image Button Width:")
                    imgui.InputInt("##imageButtonWidth", newWindowDialog.previewWindow.imageButtonWidth)
                    imgui.Text("Image Button Height:")
                    imgui.InputInt("##imageButtonHeight", newWindowDialog.previewWindow.imageButtonHeight)
                end

                if imgui.Button("Create Window") then
                    -- Require a name for new windows
                    if newWindowDialog.windowName[1] == "" then
                        print(chat.header(addon.name):append(chat.error("Please enter a name for the new window.")))
                    else
                        altCommand.settings.windows[newWindowDialog.windowName[1]] = {
                            commands = T{},
                            windowPos = T{ x = 100, y = 100 },
                            isDraggable = true,
                            isVisible = true,
                            windowColor = newWindowDialog.windowColor,
                            buttonColor = newWindowDialog.buttonColor,
                            textColor = newWindowDialog.textColor,
                            type = newWindowDialog.windowType[1],
                            maxButtonsPerRow = newWindowDialog.previewWindow.maxButtonsPerRow,
                            buttonSpacing = newWindowDialog.previewWindow.buttonSpacing,
                            buttonWidth = (newWindowDialog.windowType[1] == "normal") and newWindowDialog.previewWindow.buttonWidth or nil,
                            buttonHeight = (newWindowDialog.windowType[1] == "normal") and newWindowDialog.previewWindow.buttonHeight or nil,
                            imageButtonWidth = (newWindowDialog.windowType[1] == "imgbutton") and newWindowDialog.previewWindow.imageButtonWidth or nil,
                            imageButtonHeight = (newWindowDialog.windowType[1] == "imgbutton") and newWindowDialog.previewWindow.imageButtonHeight or nil
                        }
                        settings.save()
                        print(chat.header(addon.name):append(chat.message("New window '" .. newWindowDialog.windowName[1] .. "' created.")))
                    end
                end

                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Add/Edit Buttons") then
                currentTab = "Add Button"

                if #windowNames > 0 then
                    local currentSelection = addButtonDialog.selectedWindow
                    if type(currentSelection) == "table" then
                        currentSelection = currentSelection[1] or ""
                    end

                    if imgui.BeginCombo("##WindowSelect", currentSelection) then
                        for i, name in ipairs(windowNames) do
                            local isSelected = (currentSelection == name)
                            if imgui.Selectable(name, isSelected) then
                                if addButtonDialog.selectedWindow ~= name then
                                    revertWindowSettings(addButtonDialog.selectedWindow, userSettings)
                                    addButtonDialog.selectedWindow = name
                                    addButtonDialog.selectedWindowIndex = { i }
                                    cacheWindowSettings(name, userSettings)

                                    -- Reset selectedCommandIndex when a new window is selected
                                    addButtonDialog.selectedCommandIndex = nil
                                    addButtonDialog.lastSelectedCommandIndex = nil
                                end
                            end
                            if isSelected then imgui.SetItemDefaultFocus() end
                        end
                        imgui.EndCombo()
                    end

                    local selectedWindow = userSettings.windows[addButtonDialog.selectedWindow]
                    if selectedWindow then
                        
                        imgui.Text("Command Type:")
                        if imgui.RadioButton("Direct Command", addButtonDialog.commandType[1] == "isDirect") then
                            addButtonDialog.commandType[1] = "isDirect"
                        end
                        imgui.SameLine()
                        if imgui.RadioButton("Toggle On/Off", addButtonDialog.commandType[1] == "isToggle") then
                            addButtonDialog.commandType[1] = "isToggle"
                        end

                        if imgui.RadioButton("Command Series", addButtonDialog.commandType[1] == "isSeries") then
                            addButtonDialog.commandType[1] = "isSeries"
                        end
                        imgui.SameLine()
                        if imgui.RadioButton("Window Toggle", addButtonDialog.commandType[1] == "isWindow") then
                            addButtonDialog.commandType[1] = "isWindow"
                        end
                    
                        imgui.Text("Button Name:")
                        imgui.InputText("##commandName", addButtonDialog.commandName, 64)
                        
                        -- Show relevant fields based on type                        
                        if addButtonDialog.commandType[1] == "isDirect" then
                            imgui.Text("Command Text:")
                            imgui.InputText("##commandText", addButtonDialog.commandText, 256)
                        elseif addButtonDialog.commandType[1] == "isToggle" then
                            imgui.Text("Base Command:")
                            imgui.InputText("##toggleCommand", addButtonDialog.toggleCommand, 256)
                            imgui.Text("Toggle Words: (Ex: on, off)")
                            imgui.InputText("##toggleWords", addButtonDialog.toggleWords, 64)
                        elseif addButtonDialog.commandType[1] == "isSeries" then
                            imgui.Text("Delay between commands (seconds):")
                            imgui.InputFloat("##seriesDelay", addButtonDialog.seriesDelay, 0.1, 1.0)
                            imgui.Text("Command Series:")
                            
                            -- Track if we need a new input
                            local needNewInput = true
                            -- Track non-empty inputs for final string
                            local nonEmptyCommands = {}
                            
                            -- Render each command input
                            for i, cmd in ipairs(addButtonDialog.seriesCommandInputs) do
                                local label = string.format("Command %d##cmd%d", i, i)
                                if imgui.InputText(label, cmd, 256) then
                                    -- If this input is not empty and it's the last one, add a new empty input
                                    if cmd[1] ~= "" and i == #addButtonDialog.seriesCommandInputs then
                                        table.insert(addButtonDialog.seriesCommandInputs, {""})
                                    end
                                end
                                
                                -- Collect non-empty commands
                                if cmd[1] ~= "" then
                                    table.insert(nonEmptyCommands, cmd[1])
                                    needNewInput = false
                                end
                            end
                            
                            -- Remove empty inputs except last one
                            for i = #addButtonDialog.seriesCommandInputs - 1, 1, -1 do
                                if addButtonDialog.seriesCommandInputs[i][1] == "" then
                                    table.remove(addButtonDialog.seriesCommandInputs, i)
                                end
                            end
                            
                            -- Ensure at least one input exists
                            if #addButtonDialog.seriesCommandInputs == 0 then
                                addButtonDialog.seriesCommandInputs = { {""} }
                            end
                            
                            -- Update series commands string
                            addButtonDialog.seriesCommands[1] = table.concat(nonEmptyCommands, ",")
                        elseif addButtonDialog.commandType[1] == "isWindow" then
                            imgui.Text("Window Name:")
                            imgui.InputText("##windowToggleName", addButtonDialog.windowToggleName, 64)
                        end    
                        if selectedWindow.type == "imgbutton" then
                            imgui.Text("Texture Path:")
                            if imgui.InputText("##texturePath", addButtonDialog.texturePath, 256) then
                                local texturePath = addon.path .. '/resources/' .. addButtonDialog.texturePath[1]
                                if fileExists(texturePath) then
                                    local loadedTexture = images.loadTextureFromFile(texturePath)
                                    if loadedTexture then
                                        addButtonDialog.previewTexture = loadedTexture
                                    else
                                        addButtonDialog.previewTexture = fallbackTexture
                                    end
                                else
                                    addButtonDialog.previewTexture = fallbackTexture
                                end
                            end
                        end
                        if imgui.Button("Add Button##ConfirmAdd") then
                            -- Button click handling
                            if addButtonDialog.commandName[1] == "" then
                                print(chat.header(addon.name):append(chat.error("Please enter a name for the new button.")))
                            else
                                local imagePathToSave = nil
                                if selectedWindow.type == "imgbutton" then
                                    if addButtonDialog.previewTexture == fallbackTexture then
                                        print('Using fallback texture for the button.')
                                        imagePathToSave = 'misc/fallback.png'
                                    else
                                        imagePathToSave = addButtonDialog.texturePath[1]
                                    end
                                end
                
                                local newCommand = {
                                    text = addButtonDialog.commandName[1],
                                    commandType = addButtonDialog.commandType[1],
                                    command = addButtonDialog.commandText[1],
                                    toggleCommand = addButtonDialog.commandType[1] == "isToggle" and addButtonDialog.toggleCommand[1] or nil,
                                    toggleWords = addButtonDialog.commandType[1] == "isToggle" and addButtonDialog.toggleWords[1] or nil,
                                    seriesCommands = addButtonDialog.commandType[1] == "isSeries" and addButtonDialog.seriesCommands[1] or nil,
                                    seriesDelay = addButtonDialog.commandType[1] == "isSeries" and addButtonDialog.seriesDelay[1] or nil,
                                    windowToggleName = addButtonDialog.commandType[1] == "isWindow" and addButtonDialog.windowToggleName[1] or nil,
                                    is_on = false,
                                    image = imagePathToSave
                                }
                
                                table.insert(selectedWindow.commands, newCommand)
                                settings.save()
                                print(chat.header(addon.name):append(chat.message("New button added to window '" .. addButtonDialog.selectedWindow .. "'.")))
                            end
                        end
                        
                    end
                end

                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end
        imgui.EndChild()

        imgui.SameLine()

        imgui.BeginChild("RightSide", {0, -imgui.GetFrameHeightWithSpacing()}, true)
        
        local rightSideHeight = imgui.GetWindowHeight()
        local halfHeight = (rightSideHeight / 2)
        local spacing = imgui.GetStyle().ItemSpacing.y
        local previewHeight = halfHeight - (spacing / 2)

        imgui.BeginChild("WindowPreview", {0, previewHeight}, true)
        local selectedWindow = userSettings.windows[addButtonDialog.selectedWindow]
        if selectedWindow and currentTab == "Add Button" then
            imgui.Text("Preview:")
            imgui.Spacing()

            local inlineWindow = {
                commands = {},
                type = selectedWindow.type,
                windowColor = selectedWindow.windowColor,
                buttonColor = selectedWindow.buttonColor,
                textColor = selectedWindow.textColor,
                maxButtonsPerRow = selectedWindow.maxButtonsPerRow,
                buttonSpacing = selectedWindow.buttonSpacing,
                buttonWidth = selectedWindow.buttonWidth,
                buttonHeight = selectedWindow.buttonHeight,
                imageButtonWidth = selectedWindow.imageButtonWidth,
                imageButtonHeight = selectedWindow.imageButtonHeight
            }

            for _, cmd in ipairs(selectedWindow.commands) do
                table.insert(inlineWindow.commands, cmd)
            end

            if addButtonDialog.commandName[1] ~= "" then
                local previewCommand = {
                    text = addButtonDialog.commandName[1],
                    command = addButtonDialog.commandText[1],
                    image = (selectedWindow.type == "imgbutton" and addButtonDialog.texturePath[1] ~= "") and addButtonDialog.texturePath[1] or nil
                }
                table.insert(inlineWindow.commands, previewCommand)
            end

            renderPreviewInline(inlineWindow)

            imgui.Spacing()
            imgui.Text("Hint: Click a button above to select it. Then you can edit or delete it below.")
            imgui.Spacing()

            if addButtonDialog.selectedCommandIndex then
                if not addButtonDialog.lastSelectedCommandIndex or addButtonDialog.lastSelectedCommandIndex ~= addButtonDialog.selectedCommandIndex then
                    loadSelectedCommandFields(selectedWindow)
                    addButtonDialog.lastSelectedCommandIndex = addButtonDialog.selectedCommandIndex
                end
                if addButtonDialog.selectedCommandIndex then
                    -- Load command fields if selection changed
                    if not addButtonDialog.lastSelectedCommandIndex or addButtonDialog.lastSelectedCommandIndex ~= addButtonDialog.selectedCommandIndex then
                        loadSelectedCommandFields(selectedWindow)
                        addButtonDialog.lastSelectedCommandIndex = addButtonDialog.selectedCommandIndex
                    end
                
                    local selectedCommand = nil
                    local idx = addButtonDialog.selectedCommandIndex
                    if idx <= #selectedWindow.commands then
                        selectedCommand = selectedWindow.commands[idx]
                    end
                
                    if selectedCommand then
                        imgui.Text("Edit Selected Command:")
                        imgui.Text("Command Type:")
                        if imgui.RadioButton("Direct Command##editType", editCommandType[1] == "isDirect") then
                            editCommandType[1] = "isDirect"
                        end
                        imgui.SameLine()
                        if imgui.RadioButton("Toggle On/Off##editType", editCommandType[1] == "isToggle") then
                            editCommandType[1] = "isToggle"
                        end
                        if imgui.RadioButton("Command Series##editType", editCommandType[1] == "isSeries") then
                            editCommandType[1] = "isSeries"
                        end
                        imgui.SameLine()
                        if imgui.RadioButton("Window Toggle##editType", editCommandType[1] == "isWindow") then
                            editCommandType[1] = "isWindow"
                        end
                
                        imgui.Text("Button Name:")
                        imgui.InputText("##editCommandName", editCommandName, 64)
                
                        -- Show relevant fields based on command type
                        if editCommandType[1] == "isDirect" then
                            imgui.Text("Command Text:")
                            imgui.InputText("##editCommandText", editCommandText, 256)
                        elseif editCommandType[1] == "isToggle" then
                            imgui.Text("Base Command:")
                            imgui.InputText("##editToggleCommand", editToggleCommand, 256)
                            imgui.Text("Toggle Words:")
                            imgui.InputText("##editToggleWords", editToggleWords, 64)
                        elseif editCommandType[1] == "isSeries" then
                            imgui.Text("Delay between commands (seconds):")
                            imgui.InputFloat("##editSeriesDelay", editSeriesDelay, 0.1, 1.0)
                            imgui.Text("Command Series:")
                            
                            -- Track non-empty inputs for final string
                            local nonEmptyCommands = {}
                            
                            -- Render each command input
                            for i, cmd in ipairs(editSeriesCommandInputs) do
                                local label = string.format("Command %d##edit_cmd%d", i, i)
                                if imgui.InputText(label, cmd, 256) then
                                    -- If this input is not empty and it's the last one, add a new empty input
                                    if cmd[1] ~= "" and i == #editSeriesCommandInputs then
                                        table.insert(editSeriesCommandInputs, {""})
                                    end
                                end
                                
                                -- Collect non-empty commands
                                if cmd[1] ~= "" then
                                    table.insert(nonEmptyCommands, cmd[1])
                                end
                            end
                            
                            -- Remove empty inputs except last one
                            for i = #editSeriesCommandInputs - 1, 1, -1 do
                                if editSeriesCommandInputs[i][1] == "" then
                                    table.remove(editSeriesCommandInputs, i)
                                end
                            end
                            
                            -- Ensure at least one input exists
                            if #editSeriesCommandInputs == 0 then
                                editSeriesCommandInputs = { {""} }
                            end
                        elseif editCommandType[1] == "isWindow" then
                            imgui.Text("Window Name:")
                            imgui.InputText("##editWindowToggleName", editWindowToggleName, 64)
                        end
                
                        if selectedWindow.type == "imgbutton" then
                            imgui.Text("Texture Path:")
                            imgui.InputText("##editTexturePath", editTexturePath, 256)
                        end
                
                        if imgui.Button("Save Changes##EditCommand") then
                            saveSelectedCommandChanges(selectedWindow)
                            print(chat.header(addon.name):append(chat.message('Selected command updated.')))
                        end
                        imgui.SameLine()
                        if imgui.Button("Delete Selected Button##EditCommand") then
                            table.remove(selectedWindow.commands, idx)
                            settings.save()
                            addButtonDialog.selectedCommandIndex = nil
                            addButtonDialog.lastSelectedCommandIndex = nil
                            print(chat.header(addon.name):append(chat.message('Selected command deleted.')))
                        end
                    end
                end
            end

        elseif currentTab == "New Window" then
            imgui.Text("Preview:")
            imgui.Spacing()

            local previewWindow = {
                commands = T{},
                type = newWindowDialog.windowType[1],
                windowColor = newWindowDialog.windowColor,
                buttonColor = newWindowDialog.buttonColor,
                textColor = newWindowDialog.textColor,
                maxButtonsPerRow = newWindowDialog.previewWindow.maxButtonsPerRow,
                buttonSpacing = newWindowDialog.previewWindow.buttonSpacing,
                buttonWidth = newWindowDialog.previewWindow.buttonWidth,
                buttonHeight = newWindowDialog.previewWindow.buttonHeight,
                imageButtonWidth = newWindowDialog.previewWindow.imageButtonWidth,
                imageButtonHeight = newWindowDialog.previewWindow.imageButtonHeight
            }

            for i = 1, 4 do
                if newWindowDialog.windowType[1] == "imgbutton" then
                    table.insert(previewWindow.commands, { 
                        text = "Preview " .. i, 
                        image = string.format('misc/%d.png', i)
                    })
                else
                    table.insert(previewWindow.commands, { text = "Preview " .. i })
                end
            end

            renderPreviewInline(previewWindow)
            imgui.Spacing()
            imgui.Text("Hint: This is a sample preview of a potential new window layout.\n\nThe extra padding that shows up at the bottom of the above preview window when there is more than\none row will not show up on the actual windows created.\n\nI just haven't figured out what's causing it in this one preview window.")
        end
        imgui.EndChild()

        imgui.Spacing()

        imgui.BeginChild("WindowEdit", {0, 0}, true)
        local selectedWindow = userSettings.windows[addButtonDialog.selectedWindow]
        if selectedWindow and currentTab == "Add Button" then
            imgui.Text("Edit Window: " .. addButtonDialog.selectedWindow)
            
            imgui.Text("Window Color:")
            imgui.ColorEdit4("##editWindowColor", selectedWindow.windowColor)

            imgui.Text("Button Color:")
            imgui.ColorEdit4("##editButtonColor", selectedWindow.buttonColor)

            imgui.Text("Text Color:")
            imgui.ColorEdit4("##editTextColor", selectedWindow.textColor)
        
            imgui.Text("Max Buttons Per Row:")
            imgui.InputInt("##editMaxButtonsPerRow", selectedWindow.maxButtonsPerRow)
            if selectedWindow.maxButtonsPerRow[1] < 1 then
                selectedWindow.maxButtonsPerRow[1] = 1
            end

            imgui.Text("Button Spacing:")
            imgui.InputInt("##editButtonSpacing", selectedWindow.buttonSpacing)

            if selectedWindow.type == "normal" then
                imgui.Text("Button Width:")
                imgui.InputInt("##editButtonWidth", selectedWindow.buttonWidth)

                imgui.Text("Button Height:")
                imgui.InputInt("##editButtonHeight", selectedWindow.buttonHeight)
            elseif selectedWindow.type == "imgbutton" then
                if not (selectedWindow.imageButtonWidth and selectedWindow.imageButtonWidth[1]) then
                    selectedWindow.imageButtonWidth = {40}
                end
                if not (selectedWindow.imageButtonHeight and selectedWindow.imageButtonHeight[1]) then
                    selectedWindow.imageButtonHeight = {40}
                end

                imgui.Text("Image Button Width:")
                imgui.InputInt("##editImageButtonWidth", selectedWindow.imageButtonWidth)

                imgui.Text("Image Button Height:")
                imgui.InputInt("##editImageButtonHeight", selectedWindow.imageButtonHeight)
            end

            if imgui.Button("Save Changes##EditWindow") then
                settings.save()
                cacheWindowSettings(addButtonDialog.selectedWindow, userSettings)
                print(chat.header(addon.name):append(chat.message('Updated window "' .. addButtonDialog.selectedWindow .. '".')))
            end
            imgui.SameLine()
            if imgui.Button("Delete Window##EditWindow") then
                deleteConfirmDialog.isVisible = true
                deleteConfirmDialog.windowToDelete = addButtonDialog.selectedWindow
            end
            imgui.SameLine()
            if imgui.Button("Cancel##EditWindowCancel") then
                revertWindowSettings(addButtonDialog.selectedWindow, userSettings)
                print(chat.header(addon.name):append(chat.message('Reverted changes to window "' .. addButtonDialog.selectedWindow .. '".')))
            end
        else
            imgui.Text("No window selected or currently in 'New Window' tab.")
        end
        imgui.EndChild()

        imgui.EndChild() -- End RightSide
        
        imgui.Separator()
        local helpButtonWidth = 240
        local helpButtonHeight = 24
        local windowWidth = imgui.GetWindowWidth()
        local cursorPosX = (windowWidth - helpButtonWidth) / 2
        imgui.SetCursorPosX(cursorPosX)
        
        if imgui.Button("Click here for help", { helpButtonWidth, helpButtonHeight }) then
            helpDialog.isVisible = true 
        end
        
        imgui.End()
    else
        imgui.End()
    end

    if not isOpen[1] then
        addButtonDialog.isVisible = false
        addButtonDialog.isOpen[1] = true
    end
end

local function renderDeleteConfirmDialog()
    if not deleteConfirmDialog.isVisible then return end

    -- Center the confirmation dialog
    local viewportSize = { imgui.GetIO().DisplaySize.x, imgui.GetIO().DisplaySize.y }
    local windowSize = { 300, 100 }
    imgui.SetNextWindowPos({
        (viewportSize[1] - windowSize[1]) / 2,
        (viewportSize[2] - windowSize[2]) / 2
    }, ImGuiCond_Always)
    imgui.SetNextWindowSize(windowSize, ImGuiCond_Always)

    local isOpen = deleteConfirmDialog.isOpen
    if imgui.Begin("Confirm Delete", isOpen, bit.bor(ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove)) then
        imgui.Text(string.format('Are you sure you want to delete window "%s"?', deleteConfirmDialog.windowToDelete))

        -- Center the buttons
        local buttonWidth = 120
        local spacing = 10
        local totalWidth = (buttonWidth * 2) + spacing
        imgui.SetCursorPosX((windowSize[1] - totalWidth) / 2)

        if imgui.Button("Yes##DeleteConfirm", { buttonWidth, 0 }) then
            local userSettings = altCommand and altCommand.settings or settings
            userSettings.windows[deleteConfirmDialog.windowToDelete] = nil
            settings.save()
            print(chat.header(addon.name):append(chat.message('Deleted window "' .. deleteConfirmDialog.windowToDelete .. '".')))
            deleteConfirmDialog.isVisible = false
            editWindowDialog.isVisible = false
        end
        imgui.SameLine()
        if imgui.Button("No##DeleteCancel", { buttonWidth, 0 }) then
            deleteConfirmDialog.isVisible = false
        end
    end
    imgui.End()

    -- Check if the window was closed via the 'X' button
    if not isOpen[1] then
        deleteConfirmDialog.isVisible = false
        -- Reset isOpen for the next time the window is opened
        isOpen[1] = true
    end
end

local function renderHelpWindow()
    if not helpDialog.isVisible then
        return
    end

    local isOpen = helpDialog.isOpen

    -- Set the initial size of the help window
    imgui.SetNextWindowSize({ 1200, 600 }, ImGuiCond_Always)
    if imgui.Begin("AltCommand Help", isOpen, ImGuiWindowFlags_NoResize) then
        imgui.BeginChild("HelpContent", { 0, 0 }, false, ImGuiWindowFlags_HorizontalScrollbar)

        -- Render the Title Section
        imgui.PushStyleColor(ImGuiCol_Text, { 0.2, 0.8, 0.2, 1.0 })  -- Green color for title
        imgui.TextWrapped("AltCommand Addon Help\n")
        imgui.PopStyleColor()
        imgui.Spacing()
        imgui.Separator()

        -- Render the General Commands Section
        imgui.PushStyleColor(ImGuiCol_Text, { 0.9, 0.7, 0.0, 1.0 })  -- Yellow color for section headers
        imgui.TextWrapped("\nGeneral Commands:")
        imgui.PopStyleColor()
        imgui.TextWrapped("/altc or /altcommand - Opens main settings window")
        imgui.TextWrapped("/altc help or /altcommand help - Opens this help window\n")

        -- Render the Create Window Tab Section
        imgui.PushStyleColor(ImGuiCol_Text, { 0.9, 0.7, 0.0, 1.0 })
        imgui.TextWrapped("\nCreate Window Tab:")
        imgui.PopStyleColor()
        imgui.TextWrapped([[
Use the options on the left-hand side to set up the basic structure for a new window. You can choose:
- Button type (standard or image buttons)
- Background color
- Button color
- Text color
- Maximum buttons per row
- Space between buttons
- Button size
These settings can all be edited after window creation.

!! All new windows must have a unique name.
!! All windows can be repositioned by holding shift to drag them around.
!! Window positions save automatically after dragging.
]])

        -- Render the Add/Edit Buttons Tab Section
        imgui.PushStyleColor(ImGuiCol_Text, { 0.9, 0.7, 0.0, 1.0 })
        imgui.TextWrapped("\nAdd/Edit Buttons Tab:")
        imgui.PopStyleColor()
        imgui.TextWrapped([[
Use the left-hand pane to add new buttons. Start by selecting a window from the dropdown menu. Remember:
- Normal buttons cannot be placed on image button windows, and vice versa. All new buttons must have a unique name.

There are four types of buttons:

1. Direct Command:  
   Used for single-line commands.
   - Example:
     - /ma "Fire" <t>.

2. Toggle On/Off:  
   For commands that toggle with 2 words such as on / off. The default setting for toggle commands is off.
   - Example:
     - Command Name: Follow
     - Base Command: /ms followme 
     - Toggle Words: on, off (comma-separated)
     - Clicking the button will execute /ms followme on and change the button display to Follow Off.
     - Clicking again will execute /ms followme off and change the button display back to Follow.

3. Command Series:  
   Functions like a macro with configurable delays (minimum 0.1 seconds). Each command added generates a new line.
   - Example:  
     - Command 1: /equipset 1  
     - Command 2: /do something  
     - Command 3: /equipset 2  
     - Command 4: (Leave blank to finish)  

4. Window Toggle:  
   Toggles visibility for a window with the same name.
   - Example: 
     - Create a window called "CorShots" and load it with all of the Quick Draw elements (/ja "Light Shot" <t>, etc.) 
     - In another window, add a Window Toggle button called "CorShots". 
     - The "CorShots" button now toggles the "CorShots" window's visibility.
]])

        -- Render the Preview and Editing Sections
        imgui.PushStyleColor(ImGuiCol_Text, { 0.9, 0.7, 0.0, 1.0 })
        imgui.TextWrapped("\nPreview and Editing:")
        imgui.PopStyleColor()
        imgui.TextWrapped([[
Preview Pane:
- Displays how the button will appear before creation. You can click buttons in the preview to edit or delete them.
- Important: Click "Save Changes" for edits to take effect, deletions will take effect immediately after the confirmation dialog.

Edit Window Pane:
- Alter the current window's settings (e.g., background or button colors). Use "Delete Window" to remove the window entirely.
- Important: Click "Save Changes" for edits to take effect, "Cancel" to revert changes, and "Delete Window" to delete the window 
  and all of it's contents entirely.
]])

        imgui.Separator()
        local buttonWidth = 240
        local buttonHeight = 24
        local windowWidth = imgui.GetWindowWidth()
        local cursorPosX = (windowWidth - buttonWidth) / 2
        imgui.SetCursorPosX(cursorPosX)
        if imgui.Button("Click me to get started!", { buttonWidth, buttonHeight }) then
            helpDialog.isVisible = false -- Close help window
            if not initializeWindowDialog("add") then
                print(chat.header(addon.name):append(chat.error('Failed to initialize window dialog.')))
            end
            addButtonDialog.isVisible = true
        end
    end
    imgui.End()
    
    if not isOpen[1] then
        helpDialog.isVisible = false
        helpDialog.isOpen[1] = true
    end
end

ashita.events.register('d3d_present', 'timer_handler', function()
    local current_time = os.clock()

    for name, timer in pairs(timers) do
        local elapsed_time = current_time - timer.start_time
        if elapsed_time >= timer.delay then
            -- Execute the current command
            local command = timer.commands[timer.index]
            if command then
                AshitaCore:GetChatManager():QueueCommand(-1, command)
                timer.index = timer.index + 1
                timer.start_time = current_time  -- Reset timer for the next command
            else
                -- All commands executed, remove the timer
                timers[name] = nil
            end
        end
    end
end)

ashita.events.register('load', 'load_cb', function ()
    altCommand.settings.windows:each(function (window)
        window.commands:each(function (command)
            if (command.image) then
                local texturePath = addon.path .. '/resources/' .. command.image:gsub('\\', '/')
                local texture = images.loadTextureFromFile(texturePath)
                if texture then
                    textureCache[command.image] = texture
                else
                    print(chat.header(addon.name):append(chat.error('Failed to load texture from: ' .. texturePath)))
                end
            end
        end)
    end)
end)

local function renderCommandBox()
    local windowCount = 0
    for windowName, _ in pairs(altCommand.settings.windows) do
        windowCount = windowCount + 1
    end

    -- If no saved windows exist, show Default window
    if windowCount == 0 then
        renderWindow(defaultWindow, "Default", false)
        return
    end

    -- Otherwise show all visible saved windows
    for windowName, window in pairs(altCommand.settings.windows) do
        if window.isVisible then
            renderWindow(window, windowName, false)
        end
    end

    -- Render helper dialogs   
    renderDeleteConfirmDialog()

    -- Render the preview window if the dialog is visible
    if newWindowDialog.isVisible and newWindowDialog.previewWindow then
        local previewWindow = newWindowDialog.previewWindow
        local previewCommands = {}

        if newWindowDialog.windowType[1] == "imgbutton" then
            for i = 1, 8 do
                table.insert(previewCommands, { text = "Preview " .. i, image = 'misc/preview.png' })
            end
        else
            for i = 1, 8 do
                table.insert(previewCommands, { text = "Preview " .. i })
            end
        end

        previewWindow.commands = previewCommands

        renderWindow(previewWindow, "Preview", true)
    end
end

ashita.events.register('d3d_present', 'render_cb', function()
    -- Update the current menu name
    current_menu = get_game_menu_name()
    
    -- Determine if we should hide the UI
    local shouldHideUI = false
    
    -- Always hide if interface is hidden
    if is_game_interface_hidden() then
        shouldHideUI = true
    end

    -- Hide during events/cutscenes
    if is_event_system_active() then
        shouldHideUI = true
    end

    -- Hide if the map is open
    if current_menu:match(defines.menus.map) or current_menu:match(defines.menus.region_map) then
        shouldHideUI = true
    end

    -- Hide inside auction menu
    if current_menu:match(defines.menus.auction_menu) then
        shouldHideUI = true
    end

    -- Hide if chat is expanded
    if is_chat_expanded() then
        shouldHideUI = true
    end

    -- If we should hide the UI, return early
    if shouldHideUI then
        return
    end
    renderCommandBox()
    renderAddButtonDialog()
    renderHelpWindow()
end)

ashita.events.register('command', 'command_cb', function(e)
    -- Split command into args and convert to lowercase for easier comparison
    local args = e.command:args()
    local cmd = args[1]:lower()
    
    -- Check if command matches either /altc or /altcommand
    if cmd ~= '/altc' and cmd ~= '/altcommand' then 
        return 
    end

    -- Handle help command
    if args[2] and args[2]:lower() == 'help' then
        helpDialog.isVisible = true
        e.blocked = true
        return
    end

    -- Handle main window open (no args or just the base command)
    if not args[2] then
        if not initializeWindowDialog("add") then
            print(chat.header(addon.name):append(chat.error('Failed to initialize window dialog.')))
        end
        addButtonDialog.isVisible = true
        e.blocked = true
        return
    end
end)

ashita.events.register('unload', 'unload_cb', function ()
    -- Remove textures from settings before saving
    altCommand.settings.windows:each(function (window)
        window.commands:each(function (command)
            command.texture = nil
        end)
    end)
    settings.save()
end)