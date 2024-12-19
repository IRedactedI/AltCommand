-- This is my first addon, so it's a bit of a mess. I'm still learning Lua and Ashita, so I'm sure there are better ways to do things.
-- Thank you to atom0s for help with texture loading and caching!
-- Full credit to onimitch for the UI hiding sections, thanks Mitch!
-- Included icons are pulled straight from game files, or my own creations using FFXI icons as a base (more to be added).

addon.name = "AltCommand"
addon.author = "Redacted"
addon.version = "1.0"
addon.description = "Send commands via highly customizable buttons."

require("common")
local bit = require("bit")
local chat = require("chat")
local images = require("images")
local renders = require("renders")
local helpers = require("helpers")
local variables = require("variables")


helpers.initializeFallbackTexture()
helpers.loadPreviewTextures()

ashita.events.register("d3d_present", "timer_handler", function()
    local current_time = os.clock()

    for name, timer in pairs(variables.timers) do
        local elapsed_time = current_time - timer.start_time
        if elapsed_time >= timer.delay then
            local command = timer.commands[timer.index]
            if command then
                AshitaCore:GetChatManager():QueueCommand(-1, command)
                timer.index = timer.index + 1
                timer.start_time = current_time
            else
                variables.timers[name] = nil
            end
        end
    end
end)

ashita.events.register('packet_in', 'jobchange_handler', function(e)
    if (e.id == 0x1B) then
        local job = struct.unpack('B', e.data, 0x08 + 1)
        
        if (job ~= variables.currentJob) then
            helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
        
            variables.currentJob = job
            local partyMgr = AshitaCore:GetMemoryManager():GetParty()
            local charName = partyMgr:GetMemberName(0)
            local serverId = partyMgr:GetMemberServerId(0)
            local charId = serverId
            local basePath = string.format("%sconfig\\addons\\altcommand\\%s_%s\\", AshitaCore:GetInstallPath(), charName, charId)
            variables.jobSettingsPath = basePath .. variables.jobMapping[job] .. ".lua"
        
            variables.textureCache = {}
            
            os.execute('mkdir "' .. basePath:gsub("/", "\\") .. '"')
            
            local f = io.open(variables.jobSettingsPath, "r")
            if f then
                f:close()
                variables.altCommand.settings = helpers.settings.load(variables.default_settings, variables.jobSettingsPath)
                print(chat.header(addon.name):append(chat.message("Loaded window profile: "):append(chat.success(variables.jobMapping[job] .. ".lua"))))
            else
                variables.altCommand.settings = helpers.settings.load(variables.default_settings, variables.jobSettingsPath)
                variables.altCommand.settings.windows = T{}
                helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
                print(chat.header(addon.name):append(chat.message("No window profile found for: "):append(chat.error(variables.jobMapping[job] .. ".lua")):append(chat.message(". Created new profile."))))
            end

            if type(variables.altCommand.settings.windows) == 'table' then
                if not variables.altCommand.settings.windows.it then
                    variables.altCommand.settings.windows = T(variables.altCommand.settings.windows)
                end
                
                for _, window in pairs(variables.altCommand.settings.windows) do
                    if type(window.commands) == 'table' and not window.commands.it then
                        window.commands = T(window.commands)
                    end
                end
            else
                variables.altCommand.settings.windows = T{}
            end

            if variables.altCommand.settings.windows then
                variables.altCommand.settings.windows:each(function(window)
                    if window.commands then
                        window.commands:each(function(command)
                            if command.image then
                                local texturePath = addon.path .. "/resources/" .. command.image:gsub("\\", "/")
                                local texture = images.loadTextureFromFile(texturePath)
                                if texture then
                                    variables.textureCache[command.image] = texture
                                end
                            end
                        end)
                    end
                end)
            end
        end
    end
end)

ashita.events.register("load", "load_cb", function()
    local partyMgr = AshitaCore:GetMemoryManager():GetParty()
    local charName = partyMgr:GetMemberName(0)
    local serverId = partyMgr:GetMemberServerId(0)
    local charId = serverId

    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local mainJobId = player:GetMainJob()
    variables.currentJob = variables.jobMapping[mainJobId]
    if variables.currentJob == nil then
        variables.currentJob = "UNKNOWN"
    end

    local basePath = string.format("%sconfig\\addons\\altcommand\\%s_%s\\", AshitaCore:GetInstallPath(), charName, charId)
    os.execute('mkdir "' .. basePath:gsub("/", "\\") .. '"')
    variables.jobSettingsPath = basePath .. variables.currentJob .. ".lua"

    local f = io.open(variables.jobSettingsPath, "r")
    if f then
        f:close()
        variables.altCommand.settings = helpers.settings.load(variables.default_settings, variables.jobSettingsPath)
        print(chat.header(addon.name):append(chat.message("Loaded window profile: "):append(chat.success(variables.currentJob .. ".lua"))))
    else
        variables.altCommand.settings = helpers.settings.load(variables.default_settings, variables.jobSettingsPath)
        variables.altCommand.settings.windows = T{}
        helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
        print(chat.header(addon.name):append(chat.message("No profile found for: "):append(chat.error(variables.currentJob .. ".lua")):append(chat.message(". Created new profile."))))
    end

    if type(variables.altCommand.settings.windows) == 'table' then
        if not variables.altCommand.settings.windows.it then
            variables.altCommand.settings.windows = T(variables.altCommand.settings.windows)
        end
        
        for _, window in pairs(variables.altCommand.settings.windows) do
            if type(window.commands) == 'table' and not window.commands.it then
                window.commands = T(window.commands)
            end
        end
    else
        variables.altCommand.settings.windows = T{}
    end

    if variables.altCommand.settings.windows then
        variables.altCommand.settings.windows:each(function(window)
            if window.commands then
                window.commands:each(function(command)
                    if command.image then
                        local texturePath = addon.path .. "/resources/" .. command.image:gsub("\\", "/")
                        local texture = images.loadTextureFromFile(texturePath)
                        if texture then
                            variables.textureCache[command.image] = texture
                        else
                            print(chat.header(addon.name):append(chat.error("Failed to load texture from: " .. texturePath)))
                        end
                    end
                end)
            end
        end)
    end
end)

ashita.events.register( "d3d_present", "render_cb", function()
    variables.current_menu = helpers.get_game_menu_name()

    local shouldHideUI = false

    if helpers.is_game_interface_hidden() then
        shouldHideUI = true
    end

    if helpers.is_event_system_active() then
        shouldHideUI = true
    end

    if variables.current_menu:match(variables.defines.menus.map) or variables.current_menu:match(variables.defines.menus.region_map) then
        shouldHideUI = true
    end

    if variables.current_menu:match(variables.defines.menus.auction_menu) then
        shouldHideUI = true
    end

    if helpers.is_chat_expanded() then
        shouldHideUI = true
    end

    if shouldHideUI then
        return
    end
    renders.renderCommandBox()
    renders.renderAddButtonDialog()
    renders.renderHelpWindow()
end)

ashita.events.register( "command", "command_cb", function(e)
    local args = e.command:args()
    local cmd = args[1]:lower()

    if cmd ~= "/altc" and cmd ~= "/altcommand" then
        return
    end

    if args[2] and args[2]:lower() == "help" then
        variables.helpDialog.isVisible = true
        e.blocked = true
        return
    end

    if not args[2] then
        if not helpers.initializeWindowDialog("add") then
            print(chat.header(addon.name):append(chat.error("Failed to initialize window dialog.")))
        end
        variables.addButtonDialog.isVisible = true
        e.blocked = true
        return
    end
end)

ashita.events.register( "unload", "unload_cb", function()
    variables.altCommand.settings.windows:each(function(window)
        window.commands:each(function(command)
            command.texture = nil
        end)
    end)
    helpers.settings.save(variables.altCommand.settings, variables.jobSettingsPath)
end)