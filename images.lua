------------------------------------------------------------
--Full Credit to atom0s for providing texture loading code-- 
--and helping me correct my issues with it, thanks atom0s!--
------------------------------------------------------------

require "common"
local chat = require("chat")
local ffi = require("ffi")
local d3d = require("d3d8")
local C = ffi.C
local d3d8dev = d3d.get_device()

ffi.cdef [[
    // Exported from Addons.dll
    HRESULT __stdcall D3DXCreateTextureFromFileA(IDirect3DDevice8* pDevice, const char* pSrcFile, IDirect3DTexture8** ppTexture);
]]

local images = {}
local fallbackTexture = nil

images.loadTextureFromFile = function(filePath)
    local fallbackTexturePath = addon.path .. "resources/misc/fallback.png"
    local texture_ptr = ffi.new("IDirect3DTexture8*[1]")
    local res = C.D3DXCreateTextureFromFileA(d3d8dev, filePath, texture_ptr)
    if (res ~= C.S_OK) then
        --Too verbose, but useful for debugging
        --print(chat.header(addon.name) .. chat.message(("(%s) not found: using misc/fallback.png"):format(filePath)))
        if not fallbackTexture then
            local fallback_texture_ptr = ffi.new("IDirect3DTexture8*[1]")
            local fallback_res = C.D3DXCreateTextureFromFileA(d3d8dev, fallbackTexturePath, fallback_texture_ptr)
            if (fallback_res ~= C.S_OK) then
                print(chat.header(addon.name) .. chat.message("Fallback image not found at misc/fallback.png"))
            end
            fallbackTexture = ffi.new("IDirect3DTexture8*", fallback_texture_ptr[0])
            d3d.gc_safe_release(fallbackTexture)
        end
        return fallbackTexture
    end
    local texture = ffi.new("IDirect3DTexture8*", texture_ptr[0])
    d3d.gc_safe_release(texture)

    return texture
end

return images;