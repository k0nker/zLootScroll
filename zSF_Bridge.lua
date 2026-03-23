-- zSF_Bridge.lua
-- Wires zLootScroll to the zSettingsFrame framework.
-- Registers the adapter and builds the panel on PLAYER_LOGIN.

local zSF = LibStub("zSettingsFrame-1.0")

---@type zSF_Adapter
local adapter = {
    addonName  = "zLootScroll",
    schema     = ZSL_ZSF_SCHEMA,

    themeColors = {
        primary = { RAID_CLASS_COLORS["MAGE"] },
        secondary = { RAID_CLASS_COLORS["DEATHKNIGHT"] },
    },

    get = function(key)
        return zLS:Get(key)
    end,

    set = function(key, val)
        zLS:Set(key, val)
    end,

    getDefault = function(key)
        return zLS:GetDefault(key)
    end,

    reset = function(keys)
        zLS:Reset(keys)
    end,

    onPanelShow = function()
        zLS.store:Sync()
    end,

    subscribe = function(callback)
        return zLS.store:SubscribeAll(function()
            callback()
        end)
    end,
}

zLS.zSFCtx = zSF.Register(adapter)
