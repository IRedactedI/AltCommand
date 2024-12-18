local images = require("images")
local settings = require("settings")

local variables = {}

variables.textureCache = {}
variables.timers = {}
variables.cachedSettings = {}
variables.forcePositionUpdate = {}
variables.editCommandName = {""}
variables.editCommandType = {"isDirect"}
variables.editCommandText = {""}
variables.editToggleCommand = {""}
variables.editToggleWords = {"on,off"}
variables.editSeriesCommands = {""}
variables.editSeriesCommandInputs = {{""}}
variables.editSeriesDelay = {1.0}
variables.editWindowToggleName = {""}
variables.editTexturePath = {""}
variables.currentTab = "Add Button"
variables.current_menu = ""
variables.fallbackTexturePath = addon.path .. "/resources/misc/fallback.png"
variables.fallbackTexture = images.loadTextureFromFile(variables.fallbackTexturePath)
variables.pGameMenu = ashita.memory.find("FFXiMain.dll", 0, "8B480C85C974??8B510885D274??3B05", 16, 0)
variables.pInterfaceHidden = ashita.memory.find("FFXiMain.dll", 0, "8B4424046A016A0050B9????????E8????????F6D81BC040C3", 0, 0)
variables.pEventSystem = ashita.memory.find("FFXiMain.dll", 0, "A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3", 0, 0)
variables.pChatExpanded = ashita.memory.find("FFXiMain.dll", 0, "83EC??B9????????E8????????0FBF4C24??84C0", 0x04, 0)

variables.flags = {
    no_move = ImGuiWindowFlags_NoMove,
    no_title = ImGuiWindowFlags_NoTitleBar,
    no_resize = ImGuiWindowFlags_NoResize,
    no_scroll = ImGuiWindowFlags_NoScrollbar,
    no_scroll_mouse = ImGuiWindowFlags_NoScrollWithMouse
}


variables.defines = {
    menus = {
        auction_menu = "auc[%d]",
        map = "map",
        region_map = "cnqframe"
    }
}

variables.defaultWindow = {
    commands = T {
        T {
            text = "Click Me",
            commandType = "isDirect",
            command = "/altc help"
        }
    },
    windowPos = {x = 100, y = 100},
    isDraggable = false,
    isVisible = true,
    windowColor = {0.016, 0.055, 0.051, 0.49},
    buttonColor = {0.2, 0.376, 0.8, 1.0},
    textColor = {1, 1, 1, 1},
    type = "normal",
    maxButtonsPerRow = {1},
    buttonSpacing = {5},
    buttonWidth = {105},
    buttonHeight = {22},
    imageButtonWidth = {40},
    imageButtonHeight = {40}
}

variables.default_settings =
    T {
    windows = T {}
}

variables.altCommand =
    T {
    settings = settings.load(variables.default_settings)
}

variables.newWindowDialog = {
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
        imageButtonHeight = {40}
    }
}

variables.addButtonDialog = {
    isVisible = false,
    isOpen = {true},
    selectedWindowIndex = {1},
    selectedWindow = "",
    selectedCommandIndex = nil,
    commandType = {"isDirect"},
    commandName = {""},
    commandText = {""},
    toggleCommand = {""},
    toggleWords = {""},
    seriesDelay = {1.0},
    seriesCommands = {{""}},
    seriesCommandInputs = {{""}},
    windowToggleName = {""},
    texturePath = {""},
    previewTexture = nil,
    previewButtonColor = {0.2, 0.4, 0.8, 1.0},
    inlineCommandDisplay = {
        commands = T {},
        windowColor = {0.078, 0.890, 0.804, 0.49},
        buttonColor = {0.2, 0.4, 0.8, 1.0},
        type = "normal",
        maxButtonsPerRow = {4},
        buttonSpacing = {10},
        buttonWidth = {105},
        buttonHeight = {22},
        imageButtonWidth = {40},
        imageButtonHeight = {40}
    }
}

variables.deleteConfirmDialog = {
    isVisible = false,
    isOpen = {true},
    windowToDelete = nil,
    buttonToDelete = nil,
    deleteType = nil,
    parentWindow = nil
}

variables.helpDialog = {
    isVisible = false,
    isOpen = {true}
}

return variables