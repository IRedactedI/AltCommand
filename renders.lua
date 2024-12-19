require("common")
local ffi = require("ffi")
local bit = require("bit")
local chat = require("chat")
local imgui = require("imgui")
local images = require("images")
local helpers = require("helpers")
local variables = require("variables")

local renders = {}

renders.renderWindow = function(window, windowName, isPreview)
    local function getToggleText(buttonName, toggleWords, isActive)
        local word1, word2 = string.match(toggleWords or "on off", "(%w+)[%s,]+(%w+)")
        word1 = word1 or "on"
        word2 = word2 or "off"
        
        if word1 == "on" and word2 == "off" then
            return buttonName .. (isActive and " Off" or "")
        end
        return buttonName .. " " .. (isActive and word2 or word1)
    end
    local styleVars = {
        {id = ImGuiStyleVar_FrameBorderSize, value = 0},
        {id = ImGuiStyleVar_WindowBorderSize, value = 0},
        {id = ImGuiStyleVar_FrameRounding, value = 5},
        {id = ImGuiStyleVar_WindowRounding, value = 5}
    }
    helpers.withStyleVars(styleVars,function()
            window.maxButtonsPerRow = window.maxButtonsPerRow or T {4}
            window.buttonSpacing = window.buttonSpacing or T {10}
            window.buttonWidth = window.buttonWidth or T {40}
            window.buttonHeight = window.buttonHeight or T {40}
            window.imageButtonWidth = window.imageButtonWidth or T {40}
            window.imageButtonHeight = window.imageButtonHeight or T {40}

            window.maxButtonsPerRow[1] = math.max(1, tonumber(window.maxButtonsPerRow[1]) or 4)
            window.buttonSpacing[1] = math.max(0, tonumber(window.buttonSpacing[1]) or 10)
            window.buttonWidth[1] = math.max(1, tonumber(window.buttonWidth[1]) or 40)
            window.buttonHeight[1] = math.max(1, tonumber(window.buttonHeight[1]) or 40)
            window.imageButtonWidth[1] = math.max(1, tonumber(window.imageButtonWidth[1]) or 40)
            window.imageButtonHeight[1] = math.max(1, tonumber(window.imageButtonHeight[1]) or 40)

            local commands = window.commands
            local windowPos = window.windowPos or {x = 0, y = 0}
            local windowColor = window.windowColor or {0.078, 0.890, 0.804, 0.49}
            local buttonColor = window.buttonColor or {0.2, 0.4, 0.8, 1.0}
            local textColor = window.textColor or {1.0, 1.0, 1.0, 1.0}
            local maxButtonsPerRow = window.maxButtonsPerRow[1]
            local buttonSpacing = window.buttonSpacing[1]
            local buttonWidth = window.type == "imgbutton" and window.imageButtonWidth[1] or window.buttonWidth[1]
            local buttonHeight = window.type == "imgbutton" and window.imageButtonHeight[1] or window.buttonHeight[1]

            local totalRows = math.ceil(#commands / maxButtonsPerRow)

            local imagePaddingX = window.type == "imgbutton" and 8 or 0
            local imagePaddingY = window.type == "imgbutton" and 6 or 0

            local effectiveButtonWidth = buttonWidth + (window.type == "imgbutton" and imagePaddingX or 0)
            local effectiveButtonHeight = buttonHeight + (window.type == "imgbutton" and imagePaddingY or 0)

            local windowWidth = (effectiveButtonWidth * maxButtonsPerRow) + (buttonSpacing * (maxButtonsPerRow - 1)) + imgui.GetStyle().WindowPadding.x * 2
            local totalHeight = (effectiveButtonHeight * totalRows) + (totalRows - 1) * buttonSpacing + imgui.GetStyle().WindowPadding.y * 2

            local io = imgui.GetIO()
            local shift_held = io.KeyShift
            local windowFlags = bit.bor(variables.flags.no_title, variables.flags.no_resize, variables.flags.no_scroll, variables.flags.no_scroll_mouse)

            if not shift_held then
                windowFlags = bit.bor(windowFlags, variables.flags.no_move)
            else
                window.isDraggable = true
            end

            local cond
            if variables.forcePositionUpdate[windowName] then
                cond = ImGuiCond_Always
                variables.forcePositionUpdate[windowName] = false
            else
                if window.isDraggable and shift_held then
                    cond = nil
                else
                    cond = ImGuiCond_Always
                end
            end

            imgui.SetNextWindowSize({windowWidth, totalHeight}, ImGuiCond_Always)

            if cond ~= nil then
                imgui.SetNextWindowPos({windowPos.x, windowPos.y}, cond)
            end


            imgui.PushStyleColor(ImGuiCol_WindowBg, {windowColor[1], windowColor[2], windowColor[3], windowColor[4]})

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

                        imgui.PushID(i.."_"..j)

                        local label = command.text or "No Label"
                        if command.commandType == "isToggle" then
                            label = getToggleText(command.text, command.toggleWords, command.is_on)
                        end

                        local buttonClicked = false

                        if command.image and window.type == "imgbutton" then
                            local texture = variables.textureCache[command.image]
                            if not texture then
                                local fullPath = addon.path .. "/resources/" .. command.image:gsub("\\", "/")
                                if helpers.fileExists(fullPath) then
                                    local loadedTexture = images.loadTextureFromFile(fullPath)
                                    if loadedTexture then
                                        variables.textureCache[command.image] = loadedTexture
                                        texture = loadedTexture
                                    else
                                        print(chat.header(addon.name):append(chat.error("Failed to load texture from: " .. fullPath .. " - Using fallback.")))
                                        command.image = "misc/fallback.png"
                                        variables.textureCache["misc/fallback.png"] = variables.fallbackTexture
                                        texture = variables.fallbackTexture
                                    end
                                else
                                    print(chat.header(addon.name):append(chat.error("Texture file not found: " .. fullPath .. " - Using fallback.")))
                                    command.image = "misc/fallback.png"
                                    variables.textureCache["misc/fallback.png"] = variables.fallbackTexture
                                    texture = variables.fallbackTexture
                                end
                            end

                            if texture then
                                local textureID = tonumber(ffi.cast("uint32_t", texture))
                                buttonClicked = imgui.ImageButton(textureID, {buttonWidth, buttonHeight})

                                if imgui.IsItemHovered() then
                                    imgui.SetTooltip(label)
                                end
                            else
                                imgui.PushStyleVar(ImGuiStyleVar_Alpha, 0.5)
                                imgui.Button(label, {buttonWidth, buttonHeight})
                                imgui.PopStyleVar()
                            end
                        else
                            imgui.PushStyleColor(ImGuiCol_Text, textColor)
                            buttonClicked = imgui.Button(label, {buttonWidth, buttonHeight})
                            imgui.PopStyleColor()
                        end

                        imgui.PopID()

                        if buttonClicked then
                            if command.commandType == "isToggle" then
                                local toggle_command
                                if command.is_on then
                                    toggle_command =
                                        (command.toggleCommand or "") ..
                                        " " .. (command.toggleWords:match(",%s*(.+)") or "off")
                                else
                                    toggle_command =
                                        (command.toggleCommand or "") ..
                                        " " .. (command.toggleWords:match("([^,]+)") or "on")
                                end

                                AshitaCore:GetChatManager():QueueCommand(-1, toggle_command)

                                command.is_on = not command.is_on
                            elseif command.commandType == "isSeries" then
                                local cmdList = {}
                                for cmd in (command.seriesCommands or ""):gmatch("[^,]+") do
                                    table.insert(cmdList, cmd:trim())
                                end
                                if #cmdList > 0 then
                                    AshitaCore:GetChatManager():QueueCommand(-1, cmdList[1])
                                    if #cmdList > 1 then
                                        helpers.addTimer("series_" .. command.text, command.seriesDelay or 1.0, cmdList)
                                    end
                                end
                            elseif command.commandType == "isWindow" then
                                local targetWindow = variables.altCommand.settings.windows[command.windowToggleName or command.text]
                                if targetWindow then
                                    targetWindow.isVisible = not targetWindow.isVisible
                                end
                            elseif command.commandType == "isDirect" or command.commandType == nil then
                                if command.command and command.command ~= "" then
                                    AshitaCore:GetChatManager():QueueCommand(-1, command.command)
                                end
                            end
                        end

                        if j < buttonsInRow - 1 then
                            imgui.SameLine(0, buttonSpacing)
                        end
                    end
                end

                if window.isDraggable and imgui.IsWindowHovered() and imgui.IsMouseDragging(0) then
                    local newX, newY = imgui.GetWindowPos()
                    windowPos.x = newX
                    windowPos.y = newY
                    helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                end

                imgui.PopStyleColor(3)
                imgui.End()
            end
            imgui.PopStyleColor(1)
        end
    )
end

renders.renderPreviewInline = function(windowConfig)
    local function getPreviewToggleText(buttonName, rawToggleWords)
        local word1, word2 = string.match(rawToggleWords or "on off", "(%w+)[%s,]+(%w+)")
        word1 = word1 or "on"
        word2 = word2 or "off"
        if word1 == "on" and word2 == "off" then
            return buttonName
        end
        return buttonName .. " " .. word1
    end
    local styleVars = {
        {id = ImGuiStyleVar_FrameBorderSize, value = 0},
        {id = ImGuiStyleVar_WindowBorderSize, value = 0},
        {id = ImGuiStyleVar_FrameRounding, value = 5},
        {id = ImGuiStyleVar_WindowRounding, value = 5},
        {id = ImGuiStyleVar_ChildRounding, value = 5}
    }
    helpers.withStyleVars(styleVars,function()
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

            local windowWidth =
                (effectiveButtonWidth * maxButtonsPerRow) + (buttonSpacing * (maxButtonsPerRow - 1)) +
                style.WindowPadding.x * 2
            local totalHeight =
                (effectiveButtonHeight * totalRows) + ((totalRows - 1) * buttonSpacing) + style.WindowPadding.y * 2

            local wc = windowConfig.windowColor or {0.078, 0.890, 0.804, 0.49}
            imgui.PushStyleColor(ImGuiCol_ChildBg, {wc[1], wc[2], wc[3], wc[4]})

            local windowFlags =
                bit.bor(
                ImGuiWindowFlags_NoTitleBar,
                ImGuiWindowFlags_NoResize,
                ImGuiWindowFlags_NoScrollbar,
                ImGuiWindowFlags_NoScrollWithMouse,
                ImGuiWindowFlags_AlwaysUseWindowPadding
            )
            local parentWidth = imgui.GetWindowWidth()
            local parentHeight = imgui.GetWindowHeight()

            local childX = (parentWidth - windowWidth) * 0.5
            local childY = (parentHeight - totalHeight) * 0.1

            imgui.SetCursorPos({childX, childY})
            imgui.BeginChild("ExistingWindowPreview", {windowWidth, totalHeight}, false, windowFlags)

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
                    if command.commandType == "isToggle" then
                        label = getPreviewToggleText(command.text, variables.addButtonDialog.toggleWords[1])
                    end
    
                    imgui.PushID("preview_"..i.."_"..j)
    
                    if windowConfig.type == "imgbutton" then
                        if command.image and command.image ~= "" then
                            local tex = variables.textureCache[command.image]
                            if variables.addButtonDialog.selectedCommandIndex == cmdIndex and 
                               variables.editTexturePath and 
                               variables.editTexturePath[1] ~= "" then
                                local fullPath = addon.path .. "/resources/" .. variables.editTexturePath[1]:gsub("\\", "/")
                                tex = images.loadTextureFromFile(fullPath)
                                if not tex then
                                    tex = variables.fallbackTexture
                                end
                            else
                                if not tex then
                                    local fullPath = addon.path .. "/resources/" .. command.image:gsub("\\", "/")
                                    tex = images.loadTextureFromFile(fullPath)
                                    variables.textureCache[command.image] = tex
                                end
                            end
                            
                            local textureID = tonumber(ffi.cast("uint32_t", tex or variables.fallbackTexture))
                            if imgui.ImageButton(textureID, {buttonWidth, buttonHeight}) then
                                if not command.isPreview then
                                    variables.addButtonDialog.selectedCommandIndex = cmdIndex
                                end
                            end
                        else
                            local textureID = tonumber(ffi.cast("uint32_t", variables.fallbackTexture))
                            if imgui.ImageButton(textureID, {buttonWidth, buttonHeight}) then
                                if not command.isPreview then
                                    variables.addButtonDialog.selectedCommandIndex = cmdIndex
                                end
                            end
                        end
                    else
                        imgui.PushStyleColor(ImGuiCol_Text, textColor)
                        if command.isPreview then
                            imgui.Button(label, {buttonWidth, buttonHeight})
                        else
                            if imgui.Button(label, {buttonWidth, buttonHeight}) then
                                variables.addButtonDialog.selectedCommandIndex = cmdIndex
                            end
                        end
                        imgui.PopStyleColor()
                    end
    
                    imgui.PopID()
    
                    if j < buttonsInRow - 1 then
                        imgui.SameLine(0, buttonSpacing)
                    end
                end
            end
    
            imgui.PopStyleColor(3)
            imgui.EndChild()
            imgui.PopStyleColor()
        end)
end

renders.renderAddButtonDialog = function()
    local styleVars = {
        {id = ImGuiStyleVar_FrameBorderSize, value = 0},
        {id = ImGuiStyleVar_WindowBorderSize, value = 0},
        {id = ImGuiStyleVar_FrameRounding, value = 5},
        {id = ImGuiStyleVar_WindowRounding, value = 5}
    }
    helpers.withStyleVars(styleVars,function()
            if not variables.addButtonDialog.isVisible then
                return
            end

            local isOpen = variables.addButtonDialog.isOpen

            helpers.ensureNewWindowDefaults()

            imgui.SetNextWindowSize({1250, 600}, ImGuiCond_Always)
            if imgui.Begin("Alt Command v1.0", isOpen, ImGuiWindowFlags_NoResize) then
                local userSettings = variables.altCommand and variables.altCommand.settings or settings
                local windowNames, windowIndexMap = helpers.getWindowNamesFromSettings(userSettings)

                local oldTab = variables.currentTab

                if not variables.addButtonDialog.selectedWindow and #windowNames > 0 then
                    variables.addButtonDialog.selectedWindow = windowNames[1]
                    variables.addButtonDialog.selectedWindowIndex = {1}
                    helpers.cacheWindowSettings(windowNames[1], userSettings)
                end

                imgui.BeginChild("LeftSide", {380, -imgui.GetFrameHeightWithSpacing()}, true)
                if imgui.BeginTabBar("AddButton_NewWindow_Tabs") then
                    if imgui.BeginTabItem("Create Window") then
                        variables.currentTab = "New Window"

                        imgui.Text("Window Name:")
                        imgui.InputText("##windowName", variables.newWindowDialog.windowName, 64)

                        imgui.Text("Window Color:")
                        imgui.ColorEdit4("##windowColor", variables.newWindowDialog.windowColor)

                        imgui.Text("Button Color:")
                        imgui.ColorEdit4("##buttonColor", variables.newWindowDialog.buttonColor)

                        imgui.Text("Text Color:")
                        imgui.ColorEdit4("##windowTextColor", variables.newWindowDialog.textColor)

                        imgui.Text("Window Type:")
                        if imgui.RadioButton("Normal", variables.newWindowDialog.windowType[1] == "normal") then
                            variables.newWindowDialog.windowType[1] = "normal"
                            variables.newWindowDialog.previewWindow.type = "normal"
                            helpers.ensureNormalButtonDefaults()
                        end
                        imgui.SameLine()
                        if imgui.RadioButton("Image Button", variables.newWindowDialog.windowType[1] == "imgbutton") then
                            variables.newWindowDialog.windowType[1] = "imgbutton"
                            variables.newWindowDialog.previewWindow.type = "imgbutton"
                            helpers.ensureImageButtonDefaults()
                        end

                        imgui.Text("Max Buttons Per Row:")
                        imgui.InputInt("##maxButtonsPerRow", variables.newWindowDialog.previewWindow.maxButtonsPerRow)
                        if variables.newWindowDialog.previewWindow.maxButtonsPerRow[1] < 1 then
                            variables.newWindowDialog.previewWindow.maxButtonsPerRow[1] = 1
                        end

                        imgui.Text("Button Spacing:")
                        imgui.InputInt("##buttonSpacing", variables.newWindowDialog.previewWindow.buttonSpacing)

                        if variables.newWindowDialog.windowType[1] == "normal" then
                            imgui.Text("Button Width:")
                            imgui.InputInt("##buttonWidth", variables.newWindowDialog.previewWindow.buttonWidth)
                            imgui.Text("Button Height:")
                            imgui.InputInt("##buttonHeight", variables.newWindowDialog.previewWindow.buttonHeight)
                        elseif variables.newWindowDialog.windowType[1] == "imgbutton" then
                            helpers.ensureImageButtonDefaults()
                            imgui.Text("Image Button Width:")
                            imgui.InputInt("##imageButtonWidth", variables.newWindowDialog.previewWindow.imageButtonWidth)
                            imgui.Text("Image Button Height:")
                            imgui.InputInt("##imageButtonHeight", variables.newWindowDialog.previewWindow.imageButtonHeight)
                        end

                        if imgui.Button("Create Window") then
                            if variables.newWindowDialog.windowName[1] == "" then
                                print(chat.header(addon.name):append(chat.error("Please enter a name for the new window.")))
                            elseif helpers.windowExists(variables.newWindowDialog.windowName[1], variables.altCommand.settings) then
                                print(chat.header(addon.name):append(chat.error('A window named "' .. variables.newWindowDialog.windowName[1] .. '" already exists.')))
                            else
                                variables.altCommand.settings.windows[variables.newWindowDialog.windowName[1]] = {
                                    commands = T {},
                                    windowPos = T {x = 100, y = 100},
                                    isDraggable = true,
                                    isVisible = true,
                                    windowColor = variables.newWindowDialog.windowColor,
                                    buttonColor = variables.newWindowDialog.buttonColor,
                                    textColor = variables.newWindowDialog.textColor,
                                    type = variables.newWindowDialog.windowType[1],
                                    maxButtonsPerRow = variables.newWindowDialog.previewWindow.maxButtonsPerRow,
                                    buttonSpacing = variables.newWindowDialog.previewWindow.buttonSpacing,
                                    buttonWidth = (variables.newWindowDialog.windowType[1] == "normal") and variables.newWindowDialog.previewWindow.buttonWidth or nil,
                                    buttonHeight = (variables.newWindowDialog.windowType[1] == "normal") and variables.newWindowDialog.previewWindow.buttonHeight or nil,
                                    imageButtonWidth = (variables.newWindowDialog.windowType[1] == "imgbutton") and variables.newWindowDialog.previewWindow.imageButtonWidth or nil,
                                    imageButtonHeight = (variables.newWindowDialog.windowType[1] == "imgbutton") and variables.newWindowDialog.previewWindow.imageButtonHeight or nil
                                }
                                helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                                print(
                                    chat.header(addon.name):append(chat.message("New window '" .. variables.newWindowDialog.windowName[1] .. "' created.")))
                            end
                        end
                        imgui.EndTabItem()
                    end

                    if imgui.BeginTabItem("Add/Edit Buttons") then
                        variables.currentTab = "Add Button"

                        local left_pane_width = 400

                        imgui.BeginChild("LeftPane", {left_pane_width, 0}, false)

                        if #windowNames > 0 then
                            local currentSelection = variables.addButtonDialog.selectedWindow or ""

                            if imgui.BeginCombo("##WindowSelect", currentSelection) then
                                for i, name in ipairs(windowNames) do
                                    local isSelected = (currentSelection == name)
                                    if imgui.Selectable(name, isSelected) then
                                        if variables.addButtonDialog.selectedWindow ~= name then
                                            helpers.revertWindowSettings(variables.addButtonDialog.selectedWindow, userSettings)
                                            variables.addButtonDialog.selectedWindow = name
                                            variables.addButtonDialog.selectedWindowIndex = {i}
                                            helpers.cacheWindowSettings(name, userSettings)
                                            variables.addButtonDialog.selectedCommandIndex = nil
                                            variables.addButtonDialog.lastSelectedCommandIndex = nil
                                            variables.forcePositionUpdate[name] = true
                                        end
                                    end
                                    if isSelected then
                                        imgui.SetItemDefaultFocus()
                                    end
                                end
                                imgui.EndCombo()
                            end

                            local selectedWindow = userSettings.windows[variables.addButtonDialog.selectedWindow]
                            if selectedWindow then
                                imgui.Text("Command Type:")
                                if imgui.RadioButton("Direct Command", variables.addButtonDialog.commandType[1] == "isDirect") then
                                    variables.addButtonDialog.commandType[1] = "isDirect"
                                end
                                imgui.SameLine()
                                if imgui.RadioButton("Toggle On/Off", variables.addButtonDialog.commandType[1] == "isToggle") then
                                    variables.addButtonDialog.commandType[1] = "isToggle"
                                end
                                if imgui.RadioButton("Command Series", variables.addButtonDialog.commandType[1] == "isSeries") then
                                    variables.addButtonDialog.commandType[1] = "isSeries"
                                end
                                imgui.SameLine()
                                if imgui.RadioButton("Window Toggle", variables.addButtonDialog.commandType[1] == "isWindow") then
                                    variables.addButtonDialog.commandType[1] = "isWindow"
                                end

                                imgui.Text("Button Name:")
                                imgui.InputText("##commandName", variables.addButtonDialog.commandName, 64)

                                if variables.addButtonDialog.commandType[1] == "isDirect" then
                                    imgui.Text("Command Text:")
                                    imgui.InputText("##commandText", variables.addButtonDialog.commandText, 256)
                                elseif variables.addButtonDialog.commandType[1] == "isToggle" then
                                    imgui.Text("Base Command:")
                                    imgui.InputText("##toggleCommand", variables.addButtonDialog.toggleCommand, 256)
                                    imgui.Text("Toggle Words: (Ex: on, off)")
                                    imgui.InputText("##toggleWords", variables.addButtonDialog.toggleWords, 64)
                                elseif variables.addButtonDialog.commandType[1] == "isSeries" then
                                    imgui.Text("Delay between commands (seconds):")
                                    imgui.InputFloat("##seriesDelay", variables.addButtonDialog.seriesDelay, 0.1, 1.0)
                                    imgui.Text("Command Series:")

                                    local needNewInput = true
                                    local nonEmptyCommands = {}

                                    for i, cmd in ipairs(variables.addButtonDialog.seriesCommandInputs) do
                                        local label = string.format("Command %d##cmd%d", i, i)
                                        if imgui.InputText(label, cmd, 256) then
                                            if cmd[1] ~= "" and i == #variables.addButtonDialog.seriesCommandInputs then
                                                table.insert(variables.addButtonDialog.seriesCommandInputs, {""})
                                            end
                                        end
                                        if cmd[1] ~= "" then
                                            table.insert(nonEmptyCommands, cmd[1])
                                            needNewInput = false
                                        end
                                    end

                                    for i = #variables.addButtonDialog.seriesCommandInputs - 1, 1, -1 do
                                        if variables.addButtonDialog.seriesCommandInputs[i][1] == "" then
                                            table.remove(variables.addButtonDialog.seriesCommandInputs, i)
                                        end
                                    end

                                    if #variables.addButtonDialog.seriesCommandInputs == 0 then
                                        variables.addButtonDialog.seriesCommandInputs = {{""}}
                                    end

                                    variables.addButtonDialog.seriesCommands[1] = table.concat(nonEmptyCommands, ",")
                                elseif variables.addButtonDialog.commandType[1] == "isWindow" then
                                    imgui.Text("Window Name:")
                                    imgui.InputText("##windowToggleName", variables.addButtonDialog.windowToggleName, 64)
                                end

                                if selectedWindow.type == "imgbutton" then
                                    imgui.Text("Texture Path:")
                                    if imgui.InputText("##texturePath", variables.addButtonDialog.texturePath, 256) then
                                        local texturePath = addon.path .. "/resources/" .. variables.addButtonDialog.texturePath[1]
                                        if helpers.fileExists(texturePath) then
                                            local loadedTexture = images.loadTextureFromFile(texturePath)
                                            if loadedTexture then
                                                variables.addButtonDialog.previewTexture = loadedTexture
                                            else
                                                variables.addButtonDialog.previewTexture = variables.fallbackTexture
                                            end
                                        else
                                            variables.addButtonDialog.previewTexture = variables.fallbackTexture
                                        end
                                    end
                                end

                                if imgui.Button("Add Button##ConfirmAdd") then
                                    if variables.addButtonDialog.commandName[1] == "" then
                                        print(chat.header(addon.name):append(chat.error("Please enter a name for the new button.")))
                                    else
                                        local imagePathToSave = nil
                                        if selectedWindow.type == "imgbutton" then
                                            if variables.addButtonDialog.previewTexture == variables.fallbackTexture then
                                                    print(chat.header(addon.name):append(chat.message("Using fallback texture for the button.")))
                                                imagePathToSave = "misc/fallback.png"
                                            else
                                                imagePathToSave = variables.addButtonDialog.texturePath[1]
                                            end
                                        end

                                        local newCommand = {
                                            text = variables.addButtonDialog.commandName[1],
                                            commandType = variables.addButtonDialog.commandType[1],
                                            command = variables.addButtonDialog.commandText[1],
                                            toggleCommand = variables.addButtonDialog.commandType[1] == "isToggle" and variables.addButtonDialog.toggleCommand[1] or nil,
                                            toggleWords = variables.addButtonDialog.commandType[1] == "isToggle" and variables.addButtonDialog.toggleWords[1] or nil,
                                            seriesCommands = variables.addButtonDialog.commandType[1] == "isSeries" and variables.addButtonDialog.seriesCommands[1] or nil,
                                            seriesDelay = variables.addButtonDialog.commandType[1] == "isSeries" and variables.addButtonDialog.seriesDelay[1] or nil,
                                            windowToggleName = variables.addButtonDialog.commandType[1] == "isWindow" and variables.addButtonDialog.windowToggleName[1] or nil,
                                            is_on = false,
                                            image = imagePathToSave
                                        }

                                        table.insert(selectedWindow.commands, newCommand)
                                        helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                                        helpers.clearAddButtonDialog()
                                        print(chat.header(addon.name):append(chat.message("New button added to window '" .. variables.addButtonDialog.selectedWindow .. "'.")))
                                    end
                                end

                                imgui.Spacing()
                                imgui.Separator()
                                imgui.Spacing()

                                imgui.PushStyleColor(ImGuiCol_Text, {0.9, 0.7, 0.0, 1.0})
                                imgui.Text("Window Settings For:")
                                imgui.PopStyleColor()
                                imgui.SameLine()
                                imgui.Text(variables.addButtonDialog.selectedWindow)
                                imgui.Spacing()

                                local selectedWindowName = variables.addButtonDialog.selectedWindow
                                local selectedWindow = userSettings.windows[selectedWindowName]

                                imgui.Text("Window Position:")
                                selectedWindow.windowPos = selectedWindow.windowPos or {x = 100, y = 100}
                                local pos = {
                                    userSettings.windows[selectedWindowName].windowPos.x,
                                    userSettings.windows[selectedWindowName].windowPos.y
                                }
                                if imgui.DragInt2("##windowPos", pos) then
                                    userSettings.windows[selectedWindowName].windowPos.x = pos[1]
                                    userSettings.windows[selectedWindowName].windowPos.y = pos[2]
                                    variables.forcePositionUpdate[selectedWindowName] = true
                                    helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                                end

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
                                    selectedWindow.imageButtonWidth = selectedWindow.imageButtonWidth or {40}
                                    selectedWindow.imageButtonHeight = selectedWindow.imageButtonHeight or {40}

                                    imgui.Text("Image Button Width:")
                                    imgui.InputInt("##editImageButtonWidth", selectedWindow.imageButtonWidth)
                                    imgui.Text("Image Button Height:")
                                    imgui.InputInt("##editImageButtonHeight", selectedWindow.imageButtonHeight)
                                end

                                imgui.Spacing()

                                if imgui.Button("Save Changes##EditWindow") then
                                    helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                                    helpers.cacheWindowSettings(variables.addButtonDialog.selectedWindow, userSettings)
                                    print(chat.header(addon.name):append(chat.message('Updated window "' .. variables.addButtonDialog.selectedWindow .. '".')))
                                end
                                imgui.SameLine()
                                if imgui.Button("Delete Window##EditWindow") then
                                    variables.deleteConfirmDialog.isVisible = true
                                    variables.deleteConfirmDialog.deleteType = "window"
                                    variables.deleteConfirmDialog.windowToDelete = variables.addButtonDialog.selectedWindow
                                end
                                imgui.SameLine()
                                if imgui.Button("Cancel##EditWindow") then
                                    helpers.revertWindowSettings(variables.addButtonDialog.selectedWindow, userSettings)
                                    print(chat.header(addon.name):append(chat.message('Reverted changes to window "' .. variables.addButtonDialog.selectedWindow .. '".')))
                                end
                            end
                        else
                            imgui.Text("No windows available. Please create a window first.")
                        end

                        imgui.EndChild()

                        imgui.SameLine()
                        imgui.BeginChild("RightPane", {0, 0}, false)

                        local selectedWindow = userSettings.windows[variables.addButtonDialog.selectedWindow]
                        if selectedWindow then
                            local inlineWindow = {
                                commands = T {},
                                windowColor = selectedWindow.windowColor,
                                buttonColor = selectedWindow.buttonColor,
                                textColor = selectedWindow.textColor,
                                type = selectedWindow.type,
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

                            if variables.addButtonDialog.selectedCommandIndex then
                                if not variables.addButtonDialog.lastSelectedCommandIndex or 
                                variables.addButtonDialog.lastSelectedCommandIndex ~= variables.addButtonDialog.selectedCommandIndex then
                                helpers.loadSelectedCommandFields(selectedWindow)
                                variables.addButtonDialog.lastSelectedCommandIndex = variables.addButtonDialog.selectedCommandIndex
                            end

                                local selectedCommand = selectedWindow.commands[variables.addButtonDialog.selectedCommandIndex]
                                if selectedCommand then
                                    imgui.Spacing()
                                    imgui.Separator()
                                    imgui.Spacing()

                                    local idx = variables.addButtonDialog.selectedCommandIndex
                                    local canMoveLeft = idx > 1
                                    local canMoveRight = idx < #selectedWindow.commands

                                    if canMoveLeft then
                                        if imgui.Button("Move Left") then
                                            selectedWindow.commands[idx], selectedWindow.commands[idx - 1] =
                                                selectedWindow.commands[idx - 1],
                                                selectedWindow.commands[idx]
                                            variables.addButtonDialog.selectedCommandIndex = idx - 1
                                            helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                                            print(chat.header(addon.name):append(chat.message('Moved button "' .. selectedCommand.text .. '" left.')))
                                        end
                                    else
                                        imgui.TextDisabled("Move Left")
                                    end

                                    imgui.SameLine()
                                    if canMoveRight then
                                        if imgui.Button("Move Right") then
                                            selectedWindow.commands[idx], selectedWindow.commands[idx + 1] =
                                                selectedWindow.commands[idx + 1],
                                                selectedWindow.commands[idx]
                                            variables.addButtonDialog.selectedCommandIndex = idx + 1
                                            helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                                            print(chat.header(addon.name):append(chat.message('Moved button "' .. selectedCommand.text .. '" right.')))
                                        end
                                    else
                                        imgui.TextDisabled("Move Right")
                                    end

                                    imgui.Spacing()
                                    imgui.Separator()
                                    imgui.Spacing()
                                end
                            end
                        else
                            imgui.Text("No window selected.")
                        end

                        imgui.EndChild()

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
                local selectedWindow = userSettings.windows[variables.addButtonDialog.selectedWindow]
                if selectedWindow and variables.currentTab == "Add Button" then
                    imgui.PushStyleColor(ImGuiCol_Text, {0.9, 0.7, 0.0, 1.0})
                    imgui.Text("Preview:")
                    imgui.PopStyleColor()
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

                    if variables.addButtonDialog.commandName[1] ~= "" then
                        local previewCommand = {
                            text = variables.addButtonDialog.commandName[1],
                            command = variables.addButtonDialog.commandText[1],
                            commandType = variables.addButtonDialog.commandType[1],
                            toggleWords = variables.addButtonDialog.toggleWords[1],
                            image = (selectedWindow.type == "imgbutton" and variables.addButtonDialog.texturePath[1] ~= "") and variables.addButtonDialog.texturePath[1] or nil,
                            isPreview = true
                        }
                        table.insert(inlineWindow.commands, previewCommand)
                    end

                    renders.renderPreviewInline(inlineWindow)

                    if tex == variables.fallbackTexture then
                        imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 0.0, 0.0, 1.0 })
                        imgui.TextWrapped("Image not found - using fallback texture")
                        imgui.PopStyleColor()
                    end

                    imgui.Spacing()
                    imgui.Text("Click a button above to select it. Then you can edit or delete it below.")
                    imgui.PushStyleColor(ImGuiCol_Text, { 0.9, 0.2, 0.2, 1.0 })
                    imgui.TextWrapped("If you see angry Cinnamon Toast Crunch, the texture path is blank or invalid.")
                    imgui.TextWrapped("All buttons saved with an improper path will default to misc/fallback.png.")
                    imgui.PopStyleColor()

                    if variables.addButtonDialog.selectedCommandIndex then
                        if not variables.addButtonDialog.lastSelectedCommandIndex or 
                        variables.addButtonDialog.lastSelectedCommandIndex ~= variables.addButtonDialog.selectedCommandIndex then
                        helpers.loadSelectedCommandFields(selectedWindow)
                        variables.addButtonDialog.lastSelectedCommandIndex = variables.addButtonDialog.selectedCommandIndex
                    end


                    local selectedCommand = nil
                    local idx = variables.addButtonDialog.selectedCommandIndex
                    if idx <= #selectedWindow.commands then
                        selectedCommand = selectedWindow.commands[idx]
                    end

                    if selectedCommand then
                        imgui.Spacing()
                        imgui.Separator()
                        imgui.Spacing()

                        local canMoveLeft = idx > 1
                        local canMoveRight = idx < #selectedWindow.commands

                        if canMoveLeft or canMoveRight then
                            imgui.Text("Rearrange Button Order:")

                                if canMoveLeft then
                                    if imgui.Button("Move Left") then
                                        selectedWindow.commands[idx], selectedWindow.commands[idx - 1] =
                                            selectedWindow.commands[idx - 1],
                                            selectedWindow.commands[idx]
                                        variables.addButtonDialog.selectedCommandIndex = idx - 1
                                        helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                                        print(chat.header(addon.name):append(chat.message('Moved button "' .. selectedCommand.text .. '" left.')))
                                    end
                                else
                                    imgui.TextDisabled("Move Left")
                                end

                                imgui.SameLine()

                                if canMoveRight then
                                    if imgui.Button("Move Right") then
                                        selectedWindow.commands[idx], selectedWindow.commands[idx + 1] =
                                            selectedWindow.commands[idx + 1],
                                            selectedWindow.commands[idx]
                                        variables.addButtonDialog.selectedCommandIndex = idx + 1
                                        helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                                        print(chat.header(addon.name):append(chat.message('Moved button "' .. selectedCommand.text .. '" right.')))
                                    end
                                else
                                    imgui.TextDisabled("Move Right")
                                end
                            end
                        end
                    end
                elseif variables.currentTab == "New Window" then
                    imgui.PushStyleColor(ImGuiCol_Text, {0.9, 0.7, 0.0, 1.0})
                    imgui.Text("Preview:")
                    imgui.PopStyleColor()
                    imgui.Spacing()

                    local previewWindow = {
                        commands = T {},
                        type = variables.newWindowDialog.windowType[1],
                        windowColor = variables.newWindowDialog.windowColor,
                        buttonColor = variables.newWindowDialog.buttonColor,
                        textColor = variables.newWindowDialog.textColor,
                        maxButtonsPerRow = variables.newWindowDialog.previewWindow.maxButtonsPerRow,
                        buttonSpacing = variables.newWindowDialog.previewWindow.buttonSpacing,
                        buttonWidth = variables.newWindowDialog.previewWindow.buttonWidth,
                        buttonHeight = variables.newWindowDialog.previewWindow.buttonHeight,
                        imageButtonWidth = variables.newWindowDialog.previewWindow.imageButtonWidth,
                        imageButtonHeight = variables.newWindowDialog.previewWindow.imageButtonHeight
                    }

                    for i = 1, 4 do
                        if variables.newWindowDialog.windowType[1] == "imgbutton" then
                            table.insert(
                                previewWindow.commands,
                                {
                                    text = "Preview " .. i,
                                    image = string.format("misc/%d.png", i)
                                }
                            )
                        else
                            table.insert(previewWindow.commands, {text = "Preview " .. i})
                        end
                    end

                    renders.renderPreviewInline(previewWindow)
                    imgui.Spacing()
                    imgui.Text("This is a sample preview of a potential new window layout.\n\nWindows resize automatically with button size and spacing.\n\nIf you have extra padding below your buttons, decrease your button spacing.")
                end
                imgui.EndChild()

                imgui.Spacing()

                imgui.BeginChild("WindowEdit", {0, 0}, true)
                local selectedWindow = userSettings.windows[variables.addButtonDialog.selectedWindow]
                if selectedWindow and variables.currentTab == "Add Button" then
                    if variables.addButtonDialog.selectedCommandIndex then
                        if not variables.addButtonDialog.lastSelectedCommandIndex or variables.addButtonDialog.lastSelectedCommandIndex ~= variables.addButtonDialog.selectedCommandIndex then
                            helpers.loadSelectedCommandFields(selectedWindow)
                            variables.addButtonDialog.lastSelectedCommandIndex = variables.addButtonDialog.selectedCommandIndex
                        end

                        local selectedCommand = selectedWindow.commands[variables.addButtonDialog.selectedCommandIndex]
                        if selectedCommand then
                            imgui.PushStyleColor(ImGuiCol_Text, {0.9, 0.7, 0.0, 1.0})
                            imgui.Text(string.format('Currently Editing: "%s"', selectedCommand.text))
                            imgui.PopStyleColor()
                            imgui.Separator()
                            imgui.Spacing()

                            imgui.Text("Command Type:")
                            if imgui.RadioButton("Direct Command##editType", variables.editCommandType[1] == "isDirect") then
                                variables.editCommandType[1] = "isDirect"
                            end

                            imgui.SameLine()

                            if imgui.RadioButton("Toggle On/Off##editType", variables.editCommandType[1] == "isToggle") then
                                variables.editCommandType[1] = "isToggle"
                            end

                            if imgui.RadioButton("Command Series##editType", variables.editCommandType[1] == "isSeries") then
                                variables.editCommandType[1] = "isSeries"
                            end

                            imgui.SameLine()

                            if imgui.RadioButton("Window Toggle##editType", variables.editCommandType[1] == "isWindow") then
                                variables.editCommandType[1] = "isWindow"
                            end

                            imgui.Text("Button Name:")
                            imgui.InputText("##editCommandName", variables.editCommandName, 64)

                            if variables.editCommandType[1] == "isDirect" then
                                imgui.Text("Command Text:")
                                imgui.InputText("##editCommandText", variables.editCommandText, 256)
                            elseif variables.editCommandType[1] == "isToggle" then
                                imgui.Text("Toggle Command:")
                                imgui.InputText("##editToggleCommand", variables.editToggleCommand, 256)
                                imgui.Text("Toggle Words: (Ex: on, off)")
                                imgui.InputText("##editToggleWords", variables.editToggleWords, 64)
                            elseif variables.editCommandType[1] == "isSeries" then
                                imgui.Text("Delay between commands (seconds):")
                                imgui.InputFloat("##editSeriesDelay", variables.editSeriesDelay, 0.1, 1.0)
                                imgui.Text("Command Series:")

                                for i, cmd in ipairs(variables.editSeriesCommandInputs) do
                                    local label = string.format("Command %d##editCmd%d", i, i)
                                    if imgui.InputText(label, cmd, 256) then
                                        if cmd[1] ~= "" and i == #variables.editSeriesCommandInputs then
                                            table.insert(variables.editSeriesCommandInputs, {""})
                                        end
                                    end
                                end

                                for i = #variables.editSeriesCommandInputs - 1, 1, -1 do
                                    if variables.editSeriesCommandInputs[i][1] == "" then
                                        table.remove(variables.editSeriesCommandInputs, i)
                                    end
                                end

                                if #variables.editSeriesCommandInputs == 0 then
                                    variables.editSeriesCommandInputs = {{""}}
                                end
                            elseif variables.editCommandType[1] == "isWindow" then
                                imgui.Text("Window Name:")
                                imgui.InputText("##editWindowToggleName", variables.editWindowToggleName, 64)
                            end

                            if selectedWindow.type == "imgbutton" then
                                imgui.Text("Texture Path:")
                                imgui.InputText("##editTexturePath", variables.editTexturePath, 256)
                            end

                            if imgui.Button("Save Changes##EditCommand") then
                                helpers.saveSelectedCommandChanges(selectedWindow)
                                print(chat.header(addon.name):append(chat.message('Updated button "' .. variables.editCommandName[1] .. '".')))
                            end
                            imgui.SameLine()
                            if imgui.Button("Delete Button##DeleteCommand") then
                                variables.deleteConfirmDialog.isVisible = true
                                variables.deleteConfirmDialog.deleteType = "button"
                                variables.deleteConfirmDialog.buttonToDelete = selectedCommand
                                variables.deleteConfirmDialog.parentWindow = selectedWindow
                            end
                        end
                    else
                        imgui.Text("No button selected for editing.")
                    end
                else
                    imgui.Text("No window selected or currently in 'New Window' tab.")
                end
                imgui.EndChild()

                imgui.EndChild()

                imgui.Separator()
                local helpButtonWidth = 240
                local helpButtonHeight = 24
                local windowWidth = imgui.GetWindowWidth()
                local cursorPosX = (windowWidth - helpButtonWidth) / 2
                imgui.SetCursorPosX(cursorPosX)

                if imgui.Button("Click here for help", {helpButtonWidth, helpButtonHeight}) then
                    variables.helpDialog.isVisible = true
                end

                imgui.End()
            else
                imgui.End()
            end

            if not isOpen[1] then
                variables.addButtonDialog.isVisible = false
                variables.addButtonDialog.isOpen[1] = true
            end

            if oldTab ~= variables.currentTab then
                local userSettings = variables.altCommand and variables.altCommand.settings or settings

                if oldTab == "Add Button" and variables.currentTab == "New Window" then
                    if variables.addButtonDialog.selectedWindow and userSettings.windows[variables.addButtonDialog.selectedWindow] then
                        helpers.revertWindowSettings(variables.addButtonDialog.selectedWindow, userSettings)
                    end

                    helpers.clearAddButtonDialog()

                elseif oldTab == "New Window" and variables.currentTab == "Add Button" then
                    variables.newWindowDialog.windowName[1] = ""
                    variables.newWindowDialog.windowColor = {0.078, 0.890, 0.804, 0.49}
                    variables.newWindowDialog.buttonColor = {0.2, 0.4, 0.8, 1.0}
                    variables.newWindowDialog.textColor = {1.0, 1.0, 1.0, 1.0}
                    variables.newWindowDialog.windowType = {"normal"}
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
                end
            end
        end
    )
end

renders.renderDeleteConfirmDialog = function()
    local styleVars = {
        {id = ImGuiStyleVar_FrameBorderSize, value = 0},
        {id = ImGuiStyleVar_WindowBorderSize, value = 0},
        {id = ImGuiStyleVar_FrameRounding, value = 5},
        {id = ImGuiStyleVar_WindowRounding, value = 5}
    }
    helpers.withStyleVars(styleVars,function()
            if not variables.deleteConfirmDialog.isVisible then
                return
            end

            local viewportSize = {imgui.GetIO().DisplaySize.x, imgui.GetIO().DisplaySize.y}
            local windowSize = {300, 100}
            imgui.SetNextWindowPos({(viewportSize[1] - windowSize[1]) / 2, (viewportSize[2] - windowSize[2]) / 2}, ImGuiCond_Always)
            imgui.SetNextWindowSize(windowSize, ImGuiCond_Always)

            local isOpen = variables.deleteConfirmDialog.isOpen
            if imgui.Begin("Confirm Delete", isOpen, bit.bor(ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove)) then
                if variables.deleteConfirmDialog.deleteType == "window" then
                    imgui.Text(string.format('Delete window: "%s"?', variables.deleteConfirmDialog.windowToDelete))
                else
                    imgui.Text(string.format('Delete button: "%s"?', variables.deleteConfirmDialog.buttonToDelete.text))
                end

                local buttonWidth = 120
                local spacing = 10
                local totalWidth = (buttonWidth * 2) + spacing
                imgui.SetCursorPosX((windowSize[1] - totalWidth) / 2)

                if imgui.Button("Yes##DeleteConfirm", {buttonWidth, 0}) then
                    local userSettings = variables.altCommand and variables.altCommand.settings or settings
                    if variables.deleteConfirmDialog.deleteType == "button" then
                        local cmdList = variables.deleteConfirmDialog.parentWindow.commands
                        local buttonToDelete = variables.deleteConfirmDialog.buttonToDelete
                        local indexToDelete = nil
                
                        for idx, c in ipairs(cmdList) do
                            if c == buttonToDelete then
                                indexToDelete = idx
                                break
                            end
                        end
                
                        if indexToDelete then
                            table.remove(cmdList, indexToDelete)
                            helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                            print(chat.header(addon.name):append(chat.message('Deleted button "' .. buttonToDelete.text .. '".')))
                        else
                            print(chat.header(addon.name):append(chat.error('Failed to find the button to delete.')))
                        end
                
                        variables.addButtonDialog.selectedCommandIndex = nil
                        variables.deleteConfirmDialog.isVisible = false
                    elseif variables.deleteConfirmDialog.deleteType == "window" then
                        local windowToDelete = variables.deleteConfirmDialog.windowToDelete
                        if userSettings.windows[windowToDelete] then
                            userSettings.windows[windowToDelete] = nil
                            helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                            print(chat.header(addon.name):append(chat.message('Deleted window "' .. windowToDelete .. '".')))
                        else
                            print(chat.header(addon.name):append(chat.error('Window "' .. windowToDelete .. '" not found.')))
                        end
                        variables.deleteConfirmDialog.isVisible = false
                    end
                end
                imgui.SameLine()
                if imgui.Button("No##DeleteCancel", {buttonWidth, 0}) then
                    variables.deleteConfirmDialog.isVisible = false
                end
            end
            imgui.End()

            if not isOpen[1] then
                variables.deleteConfirmDialog.isVisible = false
                variables.deleteConfirmDialog.isOpen[1] = true
            end
        end
    )
end

renders.renderHelpWindow = function()
    local styleVars = {
        {id = ImGuiStyleVar_FrameBorderSize, value = 0},
        {id = ImGuiStyleVar_WindowBorderSize, value = 0},
        {id = ImGuiStyleVar_FrameRounding, value = 5},
        {id = ImGuiStyleVar_WindowRounding, value = 5}
    }
    helpers.withStyleVars(styleVars,function()
            if not variables.helpDialog.isVisible then
                return
            end

            local isOpen = variables.helpDialog.isOpen

            imgui.SetNextWindowSize({1200, 600}, ImGuiCond_Always)
            if imgui.Begin("AltCommand Help", isOpen, ImGuiWindowFlags_NoResize) then
                imgui.BeginChild("HelpContent", {0, 0}, false, ImGuiWindowFlags_HorizontalScrollbar)

                imgui.PushStyleColor(ImGuiCol_Text, {0.2, 0.8, 0.2, 1.0})
                imgui.TextWrapped("AltCommand Addon Help\n")
                imgui.PopStyleColor()
                imgui.Spacing()
                imgui.Separator()

                imgui.PushStyleColor(ImGuiCol_Text, {0.9, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\nGeneral Commands:")
                imgui.PopStyleColor()
                imgui.TextWrapped("/altc or /altcommand - Opens main settings window")
                imgui.TextWrapped("/altc help or /altcommand help - Opens this help window\n")

                imgui.PushStyleColor(ImGuiCol_Text, {0.9, 0.7, 0.0, 1.0})
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

Windows can be moved by Shift + Click and Drag to the desired position.

You can also move the window via the Window Settings for: menu by either 
clicking and dragging the X and Y position numbers, or double-clicking 
to manually enter coordinates.

Positions are automatically saved.]])
                imgui.PushStyleColor(ImGuiCol_Text, {0.9, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\nAdd/Edit Buttons Tab:")
                imgui.PopStyleColor()
                imgui.TextWrapped([[
 Use the left-hand pane to add new buttons. Start by selecting a window from the dropdown menu.
 - Normal buttons cannot be placed on image button windows, and vice versa.]])
                imgui.PushStyleColor(ImGuiCol_Text, {0.9, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\nThere are four types of buttons:")
                imgui.PopStyleColor()

                imgui.PushStyleColor(ImGuiCol_Text, {0.5, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\n1. Direct Command:")
                imgui.PopStyleColor()
                imgui.TextWrapped([[
   Used for single-line commands.
   - Example:
     - /ma "Fire" <t>.]])
                imgui.PushStyleColor(ImGuiCol_Text, {0.5, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\n2. Toggle On/Off:")
                imgui.PopStyleColor()
                imgui.TextWrapped([[
   For commands that toggle with 2 words such as on / off. The default setting for toggle commands is off.
   - Example:
     - Command Name: Follow
     - Base Command: /ms followme 
     - Toggle Words: on, off (comma-separated)
     - Clicking the button will execute /ms followme on and change the button display to Follow Off.
     - Clicking again will execute /ms followme off and change the button display back to Follow.]])
                imgui.PushStyleColor(ImGuiCol_Text, {0.5, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\n3. Command Series:")
                imgui.PopStyleColor()
                imgui.TextWrapped([[
   Functions like a macro with configurable delays (minimum 0.1 seconds). Each command added generates a new line.
   - Example:  
     - Command 1: /equipset 1  
     - Command 2: /do something  
     - Command 3: /equipset 2  
     - Command 4: (Leave blank to finish)]])
                imgui.PushStyleColor(ImGuiCol_Text, {0.5, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\n4. Window Toggle:")
                imgui.PopStyleColor()
                imgui.TextWrapped([[
   Toggles visibility for a window with the same name.
   - Example: 
     - Create a window called "CorShots" and load it with all of the Quick Draw elements (/ja "Light Shot" <t>, etc.) 
     - In another window, add a Window Toggle button called "CorShots". 
     - The "CorShots" button now toggles the "CorShots" window's visibility.]])

                imgui.PushStyleColor(ImGuiCol_Text, {0.9, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\nPreview and Editing:")
                imgui.PopStyleColor()
                imgui.PushStyleColor(ImGuiCol_Text, {0.5, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\nPreview:")
                imgui.PopStyleColor()
                imgui.TextWrapped([[
 - Displays how the button will appear before creation. You can click buttons in the preview to edit or delete them.
 - Important: Click "Save Changes" for edits to take effect, deletions will take effect immediately after the confirmation dialog.]])
                imgui.PushStyleColor(ImGuiCol_Text, {0.5, 0.7, 0.0, 1.0})
                imgui.TextWrapped("\nWindow Settings:")
                imgui.PopStyleColor()
                imgui.TextWrapped([[
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
                if imgui.Button("Click me to get started!", {buttonWidth, buttonHeight}) then
                    variables.helpDialog.isVisible = false
                    variables.addButtonDialog.isVisible = true
                end
            end
            imgui.End()

            if not isOpen[1] then
                variables.helpDialog.isVisible = false
                variables.helpDialog.isOpen[1] = true
            end
        end
    )
end

renders.renderCommandBox = function()
    local windowCount = 0
    for windowName, _ in pairs(variables.altCommand.settings.windows) do
        windowCount = windowCount + 1
    end

    if windowCount == 0 then
        renders.renderWindow(variables.defaultWindow, "Default", false)
        return
    end

    for windowName, window in pairs(variables.altCommand.settings.windows) do
        if window.isVisible then
            renders.renderWindow(window, windowName, false)
        end
    end

    renders.renderDeleteConfirmDialog()

    if variables.newWindowDialog.isVisible and variables.newWindowDialog.previewWindow then
        local previewWindow = variables.newWindowDialog.previewWindow
        local previewCommands = {}

        if variables.newWindowDialog.windowType[1] == "imgbutton" then
            for i = 1, 8 do
                table.insert(previewCommands, {text = "Preview " .. i, image = "misc/preview.png"})
            end
        else
            for i = 1, 8 do
                table.insert(previewCommands, {text = "Preview " .. i})
            end
        end

        previewWindow.commands = previewCommands

        renders.renderWindow(previewWindow, "Preview", true)
    end
end

return renders