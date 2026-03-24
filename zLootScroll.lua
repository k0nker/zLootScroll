-- zLootScroll.lua
-- Author: k0nker
zLS = zLS or {}

-- ── Settings accessors ────────────────────────────────────────────────────────
-- These delegate to the zSignalReact Store once it is created in Init().
-- Before Init() fires (i.e. during file load), direct fallback to defaults.

function zLS:Get(key)
    if self.store then return self.store:Get(key) end
    return self.defaults.profile[key]
end

function zLS:Set(key, value)
    if self.store then
        self.store:Set(key, value)
    end
end

function zLS:GetDefault(key)
    return self.defaults.profile[key]
end

function zLS:Reset(keys)
    if self.store then
        self.store:ApplyDefaults(keys)
    end
end

-- ── Loot log ─────────────────────────────────────────────────────────────────

---Append an entry to the loot log.
---When keepForever is off the log is trimmed to historyLength (account-wide setting).
---When keepForever is on it grows unbounded (used by history features).
---@param entry table raw entry data (type, t, wallTime, plus type-specific fields)
function zLS:LogEntry(entry)
    local log = self.lootLog
    if not log then return end
    log[#log + 1] = entry
    local g = zLS.db and zLS.db.global
    if g and not g.keepForever then
        local cap = g.historyLength or 100
        while #log > cap do
            table.remove(log, 1)
        end
    end
end

---Wipe the in-memory and persisted loot log, then clear the feed frame.
function zLS:ClearLog()
    if self.lootLog then
        wipe(self.lootLog)
    end
    if self.frame then
        self.frame:Clear()
    end
end

-- ── Initialization ────────────────────────────────────────────────────────────

function zLS:Init()
    -- Build the profile proxy so zSignalReact always reads/writes the active
    -- AceDB profile, even across profile switches.
    local profileProxy = setmetatable({}, {
        __index = function(_, key)
            return zLS.db and zLS.db.profile and zLS.db.profile[key]
        end,
        __newindex = function(_, key, value)
            if zLS.db and zLS.db.profile then
                zLS.db.profile[key] = value
            end
        end,
    })

    local zSR = LibStub("zSignalReact-1.0")
    self.store = zSR:NewStore(self.defaults.profile, profileProxy)

    -- Rebuild the feed whenever the active profile changes.
    local function onProfileSwitch()
        self.store:Sync()
        self:ApplyFrameSettings()
        self:RedrawFeed()
    end
    self.db.RegisterCallback(self, "OnProfileChanged", onProfileSwitch)
    self.db.RegisterCallback(self, "OnProfileReset",   onProfileSwitch)
    self.db.RegisterCallback(self, "OnProfileCopied",  onProfileSwitch)

    self:BuildFrame()
    self:RegisterEvents()
    self:RedrawFeed()  -- restore any persisted entries still within their fade window
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
        zLS:ClearLog()
        print("|cff00ccff" .. zLS.L.CMD_CLEAR .. "|r")

    elseif cmd == "browse" then
        zLS:OpenBrowser()
        print("|cff00ccff" .. zLS.L.CMD_BROWSE .. "|r")

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
        -- Initialize AceDB. All settings live under db.profile (per-profile),
        -- frame position under db.char (per-character), loot log under db.global
        -- (account-wide, keyed per realm and character name).
        zLS.db = LibStub("AceDB-3.0"):New("zLootScrollDB", zLS.defaults, true)

        -- One-time migration: keepForever moved from per-profile to account-wide global.
        -- Promote any profile that had it set to true, then strip it from all raw profiles
        -- so it stops appearing in the per-profile saved data.
        local rawProfiles = zLootScrollDB and zLootScrollDB.profiles
        if rawProfiles then
            for _, profileData in pairs(rawProfiles) do
                if profileData.keepForever == true and not zLS.db.global.keepForever then
                    zLS.db.global.keepForever = true
                end
                profileData.keepForever = nil
            end
        end
        zLS.db.profile.keepForever = nil  -- clean whatever AceDB loaded into the live profile

        -- Per-character data (frame position).
        zLS._charDB = zLS.db.char

        -- Rolling loot log: account-wide, keyed by realm → character.
        local realm    = GetRealmName()
        local charName = UnitName("player")
        local g        = zLS.db.global
        g.chars                   = g.chars or {}
        g.chars[realm]            = g.chars[realm] or {}
        g.chars[realm][charName]  = g.chars[realm][charName] or {}
        g.chars[realm][charName].lootLog = g.chars[realm][charName].lootLog or {}
        zLS.lootLog = g.chars[realm][charName].lootLog

        zLS:Init()
    end
end)
