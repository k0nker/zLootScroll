-- zLootScroll.lua
-- Author: k0nker
zLS = zLS or {}

-- ── Settings accessors ────────────────────────────────────────────────────────
-- These delegate to the zSignalReact Store once it is created in Init().
-- Before Init() (i.e. during file load), direct table access is used as a
-- safe fallback so Defaults.lua / Locales can reference zLS without crashing.

function zLS:Get(key)
    if self.store then return self.store:Get(key) end
    local v = zLSSaved and zLSSaved.settings and zLSSaved.settings[key]
    if v == nil then return self.defaults[key] end
    return v
end

function zLS:Set(key, value)
    if self.store then
        self.store:Set(key, value)
    else
        zLSSaved.settings[key] = value
    end
end

function zLS:GetDefault(key)
    return self.defaults[key]
end

function zLS:Reset(keys)
    if self.store then
        self.store:ApplyDefaults(keys)
    else
        for _, k in ipairs(keys) do
            zLSSaved.settings[k] = nil
        end
    end
end

-- ── Initialization ────────────────────────────────────────────────────────────

function zLS:Init()
    -- Create the reactive store backed by the live SavedVariables settings table.
    -- All Get/Set/Reset calls now go through it and signal subscribers automatically.
    local zSR = LibStub("zSignalReact-1.0")
    self.store = zSR:NewStore(self.defaults, zLSSaved.settings)

    self:BuildFrame()
    self:RegisterEvents()
    print("|cff00ccff" .. self.L.ADDON_LOADED .. "|r")
end

-- ── Slash commands ────────────────────────────────────────────────────────────

local function HandleSlash(input)
    local cmd = strtrim(input):lower()

    if cmd == "" then
        if zLS.zSFCtx then zLS.zSFCtx:Open() end

    elseif cmd == "toggle" then
        if zLS.frame then
            if zLS.frame:IsShown() then
                zLS.frame:Hide()
            else
                zLS.frame:Show()
            end
        end
        print("|cff00ccff" .. zLS.L.CMD_TOGGLE .. "|r")

    elseif cmd == "move" then
        local locked = zLS:Get("lockFrame")
        zLS:Set("lockFrame", not locked)
        -- store subscription in LootFrame.lua calls SetMovable reactively
        if locked then
            print("|cff00ccff" .. zLS.L.CMD_MOVE_ON .. "|r")
        else
            print("|cff00ccff" .. zLS.L.CMD_MOVE_OFF .. "|r")
        end

    elseif cmd == "clear" then
        if zLS.frame then
            zLS.frame:Clear()
        end
        print("|cff00ccff" .. zLS.L.CMD_CLEAR .. "|r")

    elseif cmd == "help" then
        print("|cff00ccff" .. zLS.L.SLASH_HELP .. "|r")

    else
        print("|cffff4444" .. zLS.L.CMD_UNKNOWN .. "|r")
    end
end

SLASH_ZLOOTSCROLL1 = "/zls"
SLASH_ZLOOTSCROLL2 = "/zlootscroll"
SlashCmdList["ZLOOTSCROLL"] = HandleSlash

-- ── Bootstrap frame (PLAYER_LOGIN) ───────────────────────────────────────────

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("PLAYER_LOGIN")
bootFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        zLSSaved = zLSSaved or {}
        zLSSaved.settings = zLSSaved.settings or {}
        zLSSaved.chars = zLSSaved.chars or {}

        local charKey = GetRealmName() .. "/" .. UnitName("player")
        zLSSaved.chars[charKey] = zLSSaved.chars[charKey] or {}
        zLS._charDB = zLSSaved.chars[charKey]

        if not zLS._charDB.frame then
            zLS._charDB.frame = {
                point    = zLS.defaults.defaultPoint,
                relPoint = zLS.defaults.defaultRelPoint,
                x        = zLS.defaults.defaultX,
                y        = zLS.defaults.defaultY,
            }
        end

        zLS:Init()
    end
end)
