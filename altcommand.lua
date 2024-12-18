-- This is my first addon, so it's a bit of a mess. I'm still learning Lua and Ashita, so I'm sure there are better ways to do things.
-- Thank you to atom0s for help with texture loading and caching. 
-- Full credit to onimitch for the UI hiding sections here that I shamelessly copied from his minimapcontrol addon (I hope this is ok?).
-- All other code is my own, and custom icons are mostly my own creations using the FFXI icon set as a base.

-- Todo: Clear Add/Edit dialog fields after adding a window.
-- Todo: Investigate intermittent transfer of dropdown selected window's settings to New window tab and vice versa.
-- Todo: Investigate duplicate image causing subsequent commands to ignore clicks.
-- Todo: Alphebetize window dropdown list.

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
local settings = require("settings")
local variables = require("variables")

-- Pre-load Necessary Textures
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
                timer.start_time = current_time -- Reset timer for the next command
            else
                -- All commands executed, remove the timer
                variables.timers[name] = nil
            end
        end
    end
end)

ashita.events.register("load", "load_cb", function()
    variables.altCommand.settings.windows:each(function(window)
        window.commands:each(function(command)
            if (command.image) then
                local texturePath = addon.path .. "/resources/" .. command.image:gsub("\\", "/")
                local texture = images.loadTextureFromFile(texturePath)
                if texture then
                    variables.textureCache[command.image] = texture
                else
                    print(chat.header(addon.name):append(chat.error("Failed to load texture from: " .. texturePath)))
                end
            end
        end)
    end)
end)

ashita.events.register( "d3d_present", "render_cb", function()
    -- Update the current menu name
    variables.current_menu = helpers.get_game_menu_name()

    -- Determine if we should hide the UI
    local shouldHideUI = false

    -- Always hide if interface is hidden
    if helpers.is_game_interface_hidden() then
        shouldHideUI = true
    end

    -- Hide during events/cutscenes
    if helpers.is_event_system_active() then
        shouldHideUI = true
    end

    -- Hide if the map is open
    if variables.current_menu:match(variables.defines.menus.map) or variables.current_menu:match(variables.defines.menus.region_map) then
        shouldHideUI = true
    end

    -- Hide inside auction menu
    if variables.current_menu:match(variables.defines.menus.auction_menu) then
        shouldHideUI = true
    end

    -- Hide if chat is expanded
    if helpers.is_chat_expanded() then
        shouldHideUI = true
    end

    -- If we should hide the UI, return early
    if shouldHideUI then
        return
    end
    renders.renderCommandBox()
    renders.renderAddButtonDialog()
    renders.renderHelpWindow()
end)

ashita.events.register( "command", "command_cb", function(e)
    -- Split command into args and convert to lowercase for easier comparison
    local args = e.command:args()
    local cmd = args[1]:lower()

    -- Check if command matches either /altc or /altcommand
    if cmd ~= "/altc" and cmd ~= "/altcommand" then
        return
    end

    -- Handle help command
    if args[2] and args[2]:lower() == "help" then
        variables.helpDialog.isVisible = true
        e.blocked = true
        return
    end

    -- Handle main window open (no args or just the base command)
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
    -- Remove textures from settings before saving
    variables.altCommand.settings.windows:each(function(window)
        window.commands:each(function(command)
            command.texture = nil
        end)
    end)
    settings.save()
end)