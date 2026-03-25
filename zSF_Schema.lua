-- zSF_Schema.lua
-- Declarative schema for every zLootScroll setting, consumed by
-- zSF_Bridge.lua and passed to the zSettingsFrame constructor.

local L   = zLS.L
local LSM = LibStub("LibSharedMedia-3.0")
local zSF = LibStub("zSettingsFrame-1.0")

local function LSM_Values(mediaType)
    local t = {}
    for _, key in ipairs(LSM:List(mediaType)) do t[key] = key end
    return t
end

local function LSM_Fetch(mediaType)
    return function(key) return LSM:Fetch(mediaType, key) end
end

local FONT_OUTLINE_VALUES = {
    [""]                        = "None",
    OUTLINE                     = "Outline",
    THICKOUTLINE                = "Thick Outline",
    MONOCHROME                  = "Monochrome",
    ["OUTLINE|MONOCHROME"]      = "Outline + Mono",
    ["THICKOUTLINE|MONOCHROME"] = "Thick + Mono",
}

---@type table[]
ZSL_ZSF_SCHEMA = {
    -- ── General ───────────────────────────────────────────────────────────────
    -- Behavior: what the feed shows and how it operates.
    {
        widgetType = "nav",
        name       = L.OPT_GENERAL,
        children   = {
            { widgetType = "header" },

            {
                widgetType = "toggle",
                key        = "enabled",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_ENABLED,
                desc       = L.OPT_ENABLED_DESC
            },

            {
                widgetType = "toggle",
                key        = "lockFrame",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_LOCK_FRAME,
                desc       = L.OPT_LOCK_FRAME_DESC
            },

            {
                widgetType = "toggle",
                key        = "enableScrolling",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_ENABLE_SCROLLING,
                desc       = L.OPT_ENABLE_SCROLLING_DESC,
                confirmOn  = L.OPT_ENABLE_SCROLLING_WARN
            },

            { widgetType = "header", name = "Categories" },

            {
                widgetType = "toggle",
                key        = "showItems",
                widthBlizzard = "full",
                name       = L.OPT_SHOW_ITEMS,
                desc       = L.OPT_SHOW_ITEMS_DESC
            },

            {
                widgetType = "toggle",
                key        = "showCurrency",
                widthBlizzard = "full",
                name       = L.OPT_SHOW_CURRENCY,
                desc       = L.OPT_SHOW_CURRENCY_DESC
            },

            {
                widgetType = "toggle",
                key        = "showMoney",
                widthBlizzard = "full",
                name       = L.OPT_SHOW_MONEY,
                desc       = L.OPT_SHOW_MONEY_DESC
            },

            { widgetType = "header", name = L.OPT_SHOW_QUALITY_HDR },

            { widgetType = "toggle", key = "showPoor",      width = "half", name = L.OPT_SHOW_POOR,      desc = L.OPT_SHOW_POOR_DESC },
            { widgetType = "toggle", key = "showCommon",    width = "half", name = L.OPT_SHOW_COMMON,    desc = L.OPT_SHOW_COMMON_DESC },
            { widgetType = "toggle", key = "showUncommon",  width = "half", name = L.OPT_SHOW_UNCOMMON,  desc = L.OPT_SHOW_UNCOMMON_DESC },
            { widgetType = "toggle", key = "showRare",      width = "half", name = L.OPT_SHOW_RARE,      desc = L.OPT_SHOW_RARE_DESC },
            { widgetType = "toggle", key = "showEpic",      width = "half", name = L.OPT_SHOW_EPIC,      desc = L.OPT_SHOW_EPIC_DESC },
            { widgetType = "toggle", key = "showLegendary", width = "half", name = L.OPT_SHOW_LEGENDARY, desc = L.OPT_SHOW_LEGENDARY_DESC },

            { widgetType = "header", name = "Feed" },

            {
                widgetType = "select",
                key        = "insertMode",
                widthBlizzard = "full",
                name       = L.OPT_INSERT_MODE,
                desc       = L.OPT_INSERT_MODE_DESC,
                values     = { BOTTOM = "Bottom", TOP = "Top" }
            },

            {
                widgetType = "range",
                key = "maxMessages",
                widthBlizzard = "full",
                name = L.OPT_MAX_MESSAGES,
                desc = L.OPT_MAX_MESSAGES_DESC,
                min = 5,
                max = 500,
                step = 1
            },

            {
                widgetType = "range",
                key = "messageDuration",
                widthBlizzard = "full",
                name = L.OPT_MSG_DURATION,
                desc = L.OPT_MSG_DURATION_DESC,
                min = 0,
                max = 300,
                step = 0.5,
            },

            { widgetType = "header" },

            {
                widgetType = "button",
                name       = L.OPT_RESET_BEHAVIOR,
                width      = "third",
                resetKeys  = { "enabled", "lockFrame" },
            },

            {
                widgetType = "button",
                name       = L.OPT_RESET_CATEGORIES,
                width      = "third",
                resetKeys  = { "showItems", "showCurrency", "showMoney",
                               "showPoor", "showCommon", "showUncommon",
                               "showRare", "showEpic", "showLegendary" },
            },

            {
                widgetType = "button",
                name       = L.OPT_RESET_FEED,
                width      = "third",
                resetKeys  = { "insertMode", "maxMessages", "messageDuration" },
            },
        },
    },

    -- ── Display ───────────────────────────────────────────────────────────────
    -- How items are presented and how the frame is sized.
    {
        widgetType = "nav",
        name       = L.OPT_DISPLAY,
        children   = {
            { widgetType = "header", name = "Items" },

            {
                widgetType = "toggle",
                key        = "showItemIcon",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_SHOW_ICON,
                desc       = L.OPT_SHOW_ICON_DESC
            },

            {
                widgetType = "range",
                key = "iconSize",
                width = "half",
                widthBlizzard = "full",
                name = L.OPT_ICON_SIZE,
                min = 10,
                max = 24,
                step = 1
            },

            {
                widgetType = "toggle",
                key        = "showItemLevel",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_SHOW_ILVL,
                desc       = L.OPT_SHOW_ILVL_DESC
            },

            {
                widgetType = "toggle",
                key        = "showItemTotals",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_SHOW_TOTALS,
                desc       = L.OPT_SHOW_TOTALS_DESC
            },

            {
                widgetType = "toggle",
                key        = "showTimestamp",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_SHOW_TIMESTAMP,
                desc       = L.OPT_SHOW_TIMESTAMP_DESC
            },

            {
                widgetType  = "toggle",
                key         = "timestamp24hr",
                width       = "half",
                widthBlizzard = "full",
                name        = L.OPT_TIMESTAMP_24HR,
                desc        = L.OPT_TIMESTAMP_24HR_DESC,
                disableWhen = function() return not zLS:Get("showTimestamp") end
            },

            {
                widgetType = "toggle",
                key        = "amountFirst",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_AMOUNT_FIRST,
                desc       = L.OPT_AMOUNT_FIRST_DESC
            },

            { widgetType = "header", name = "Frame" },

            {
                widgetType = "range",
                key = "frameWidth",
                width = "half",
                widthBlizzard = "full",
                name = L.OPT_FRAME_WIDTH,
                min = 100,
                max = 800,
                step = 10
            },

            {
                widgetType = "range",
                key = "frameHeight",
                width = "half",
                widthBlizzard = "full",
                name = L.OPT_FRAME_HEIGHT,
                min = 60,
                max = 600,
                step = 10
            },

            {
                widgetType = "range",
                key = "lineSpacing",
                width = "half",
                widthBlizzard = "full",
                name = L.OPT_LINE_SPACING,
                min = 0,
                max = 10,
                step = 1
            },

            { widgetType = "header", name = "Background" },

            {
                widgetType = "toggle",
                key        = "showBackground",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_SHOW_BG,
                desc       = L.OPT_SHOW_BG_DESC
            },

            {
                widgetType = "range",
                key = "bgAlpha",
                width = "half",
                widthBlizzard = "full",
                name = L.OPT_BG_ALPHA,
                min = 0.0,
                max = 1.0,
                step = 0.05
            },

            { widgetType = "header" },

            {
                widgetType = "button",
                name       = L.OPT_RESET_ITEMS,
                width      = "third",
                resetKeys  = { "showItemIcon", "iconSize", "showItemLevel", "showItemTotals", "showTimestamp", "timestamp24hr", "amountFirst" },
            },

            {
                widgetType = "button",
                name       = L.OPT_RESET_FRAME,
                width      = "third",
                resetKeys  = { "frameWidth", "frameHeight", "lineSpacing" },
            },

            {
                widgetType = "button",
                name       = L.OPT_RESET_BACKGROUND,
                width      = "third",
                resetKeys  = { "showBackground", "bgAlpha" },
            },
        },
    },

    -- ── Style ─────────────────────────────────────────────────────────────────
    -- All visual aesthetics: font and colors.
    {
        widgetType = "nav",
        name       = L.OPT_STYLE,
        children   = {
            { widgetType = "header", name = "Font" },

            {
                widgetType   = "fontSelect",
                key          = "fontFace",
                width        = "half",
                widthBlizzard = "full",
                name         = L.OPT_FONT_FACE,
                desc         = L.OPT_FONT_FACE_DESC,
                values       = function() return LSM_Values("font") end,
                previewFetch = LSM_Fetch("font")
            },

            {
                widgetType = "select",
                key        = "fontOutline",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_FONT_OUTLINE,
                desc       = L.OPT_FONT_OUTLINE_DESC,
                values     = FONT_OUTLINE_VALUES
            },

            {
                widgetType = "range",
                key = "fontSize",
                width = "half",
                widthBlizzard = "full",
                name = L.OPT_FONT_SIZE,
                min = 8,
                max = 24,
                step = 1
            },

            {
                widgetType = "select",
                key        = "fontJustify",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_FONT_JUSTIFY,
                desc       = L.OPT_FONT_JUSTIFY_DESC,
                values     = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
            },

            { widgetType = "header", name = "Font Shadow" },

            {
                widgetType = "toggle",
                key        = "fontShadow",
                widthBlizzard = "full",
                name       = L.OPT_FONT_SHADOW,
                desc       = L.OPT_FONT_SHADOW_DESC
            },

            {
                widgetType  = "colorAlpha",
                key         = "fontShadowColor",
                width       = "half",
                widthBlizzard = "full",
                name        = L.OPT_FONT_SHADOW_COLOR,
                disableWhen = function() return not zLS:Get("fontShadow") end
            },

            {
                widgetType = "range",
                key = "fontShadowOffsetX",
                width = "quarter",
                widthBlizzard = "full",
                name = L.OPT_FONT_SHADOW_OFFSET_X,
                min = -5,
                max = 5,
                step = 1,
                disableWhen = function() return not zLS:Get("fontShadow") end
            },

            {
                widgetType = "range",
                key = "fontShadowOffsetY",
                width = "quarter",
                widthBlizzard = "full",
                name = L.OPT_FONT_SHADOW_OFFSET_Y,
                min = -5,
                max = 5,
                step = 1,
                disableWhen = function() return not zLS:Get("fontShadow") end
            },

            { widgetType = "header", name = "Colors" },

            {
                widgetType = "toggle",
                key        = "colorByQuality",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_COLOR_BY_QUALITY,
                desc       = L.OPT_COLOR_BY_QUALITY_DESC
            },

            {
                widgetType = "color",
                key        = "colorMoney",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_COLOR_MONEY,
                desc       = L.OPT_COLOR_MONEY_DESC
            },

            {
                widgetType  = "color",
                key         = "colorTimestamp",
                width       = "half",
                widthBlizzard = "full",
                name        = L.OPT_COLOR_TIMESTAMP,
                desc        = L.OPT_COLOR_TIMESTAMP_DESC,
                disableWhen = function() return not zLS:Get("showTimestamp") end
            },

            {
                widgetType = "color",
                key        = "colorCount",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_COLOR_COUNT,
                desc       = L.OPT_COLOR_COUNT_DESC
            },

            {
                widgetType = "color",
                key        = "colorIncrement",
                width      = "half",
                widthBlizzard = "full",
                name       = L.OPT_COLOR_INCREMENT,
                desc       = L.OPT_COLOR_INCREMENT_DESC
            },

            { widgetType = "header" },

            {
                widgetType = "button",
                name       = L.OPT_RESET_FONT,
                width      = "third",
                resetKeys  = { "fontFace", "fontOutline", "fontSize", "fontJustify" },
            },

            {
                widgetType = "button",
                name       = L.OPT_RESET_FONT_SHADOW,
                width      = "third",
                resetKeys  = { "fontShadow", "fontShadowColor", "fontShadowOffsetX", "fontShadowOffsetY" },
            },

            {
                widgetType = "button",
                name       = L.OPT_RESET_COLORS,
                width      = "third",
                resetKeys  = { "colorByQuality", "colorMoney", "colorTimestamp", "colorCount", "colorIncrement" },
            },
        },
    },

    -- ── Log Storage ─────────────────────────────────────────────────────────────
    -- Per-type storage filters applied by PruneAllLogs() at login/reload.
    -- All keys are global-scoped: must use explicit get/set, not key=.
    {
        widgetType = "nav",
        name       = L.OPT_NAV_STORAGE,
        children   = {
            {
                widgetType = "text",
                name       = L.OPT_HISTORY_NOTICE,
                widthBlizzard = "full",
            },

            { widgetType = "header" },

            {
                widgetType    = "toggle",
                widthBlizzard = "full",
                name          = L.OPT_KEEP_FOREVER,
                desc          = L.OPT_KEEP_FOREVER_DESC,
                confirmOn     = L.OPT_KEEP_FOREVER_WARN_E,
                confirmOff    = L.OPT_KEEP_FOREVER_WARN_D,
                get           = function() return zLS.db.global.keepForever end,
                set           = function(v) zLS.db.global.keepForever = v end,
            },

            {
                widgetType    = "range",
                widthBlizzard = "full",
                name          = L.OPT_HISTORY_LENGTH,
                desc          = L.OPT_HISTORY_LENGTH_DESC,
                min           = 50,
                max           = 25000,
                step          = 50,
                get           = function() return zLS.db.global.historyLength end,
                set           = function(v) zLS.db.global.historyLength = v end,
                disableWhen   = function() return zLS.db.global.keepForever end,
            },
            { widgetType = "header", name = L.OPT_STORAGE_QUALITY_HDR },

            {
                widgetType = "toggle",
                name       = L.OPT_STORE_POOR,
                desc       = L.OPT_STORE_POOR_DESC,
                get        = function() return zLS.db.global.storePoor end,
                set        = function(v) zLS.db.global.storePoor = v end,
            },
            {
                widgetType = "toggle",
                name       = L.OPT_STORE_COMMON,
                desc       = L.OPT_STORE_COMMON_DESC,
                get        = function() return zLS.db.global.storeCommon end,
                set        = function(v) zLS.db.global.storeCommon = v end,
            },
            {
                widgetType = "toggle",
                name       = L.OPT_STORE_UNCOMMON,
                desc       = L.OPT_STORE_UNCOMMON_DESC,
                confirmOff = L.STORAGE_WARN_TURN_OFF,
                get        = function() return zLS.db.global.storeUncommon end,
                set        = function(v) zLS.db.global.storeUncommon = v end,
            },
            {
                widgetType = "toggle",
                name       = L.OPT_STORE_RARE,
                desc       = L.OPT_STORE_RARE_DESC,
                confirmOff = L.STORAGE_WARN_TURN_OFF,
                get        = function() return zLS.db.global.storeRare end,
                set        = function(v) zLS.db.global.storeRare = v end,
            },
            {
                widgetType = "toggle",
                name       = L.OPT_STORE_EPIC,
                desc       = L.OPT_STORE_EPIC_DESC,
                confirmOff = L.STORAGE_WARN_TURN_OFF,
                get        = function() return zLS.db.global.storeEpic end,
                set        = function(v) zLS.db.global.storeEpic = v end,
            },
            {
                widgetType = "toggle",
                name       = L.OPT_STORE_LEGENDARY,
                desc       = L.OPT_STORE_LEGENDARY_DESC,
                confirmOff = L.STORAGE_WARN_TURN_OFF,
                get        = function() return zLS.db.global.storeLegendary end,
                set        = function(v) zLS.db.global.storeLegendary = v end,
            },
            {
                widgetType = "toggle",
                name       = L.OPT_STORE_ARTIFACT,
                desc       = L.OPT_STORE_ARTIFACT_DESC,
                confirmOff = L.STORAGE_WARN_TURN_OFF,
                get        = function() return zLS.db.global.storeArtifact end,
                set        = function(v) zLS.db.global.storeArtifact = v end,
            },

            { widgetType = "header", name = L.OPT_STORAGE_TYPES_HDR },

            {
                widgetType = "toggle",
                name       = L.OPT_STORE_MONEY,
                desc       = L.OPT_STORE_MONEY_DESC,
                get        = function() return zLS.db.global.storeMoney end,
                set        = function(v) zLS.db.global.storeMoney = v end,
            },
            {
                widgetType = "toggle",
                name       = L.OPT_STORE_CURRENCY,
                desc       = L.OPT_STORE_CURRENCY_DESC,
                confirmOff = L.STORAGE_WARN_TURN_OFF,
                get        = function() return zLS.db.global.storeCurrency end,
                set        = function(v) zLS.db.global.storeCurrency = v end,
            },
        },
    },

    -- ── Profiles ─────────────────────────────────────────────────────────────
    -- Create, copy, delete, and reset settings profiles.
    {
        widgetType = "nav",
        name       = L.OPT_PROFILES,
        children   = {
            { widgetType = "header", name = L.OPT_PROFILE_ACTIVE },

            {
                widgetType = "select",
                widthBlizzard = "full",
                name       = L.OPT_PROFILE_CURRENT,
                desc       = L.OPT_PROFILE_CURRENT_DESC,
                values     = function()
                    local profiles = {}
                    for _, name in pairs(zLS.db:GetProfiles()) do
                        profiles[name] = name
                    end
                    return profiles
                end,
                get = function() return zLS.db:GetCurrentProfile() end,
                set = function(v)
                    zLS.db:SetProfile(v)
                    zSF.RefreshAll(true)
                end,
            },

            {
                widgetType    = "input",
                widthBlizzard = "full",
                name          = L.OPT_PROFILE_NEW,
                desc          = L.OPT_PROFILE_NEW_DESC,
                get           = function() return "" end,
                set           = function(v)
                    if v and v ~= "" then
                        zLS.db:SetProfile(v)
                    end
                    zSF.RefreshAll(true)
                end,
            },

            { widgetType = "header", name = L.OPT_PROFILE_COPY_HEADER },

            {
                widgetType    = "select",
                width         = "half",
                widthBlizzard = "full",
                divider       = false,
                name          = L.OPT_PROFILE_COPY_SOURCE,
                desc          = L.OPT_PROFILE_COPY_SOURCE_DESC,
                values        = function()
                    local profiles = {}
                    local cur = zLS.db:GetCurrentProfile()
                    for _, name in pairs(zLS.db:GetProfiles()) do
                        if name ~= cur then profiles[name] = name end
                    end
                    return profiles
                end,
                get = function() return zLS._profileCopySource end,
                set = function(v) zLS._profileCopySource = v end,
            },

            { widgetType = "filler", width = "quarter", divider = false },

            {
                widgetType    = "button",
                width         = "quarter",
                name          = L.OPT_PROFILE_COPY,
                desc          = L.OPT_PROFILE_COPY_DESC,
                iconAtlas     = "orderhalltalents-choice-arrow-large",
                confirm       = L.OPT_PROFILE_COPY_CONFIRM,
                disableWhen   = function() return not zLS._profileCopySource end,
                func          = function()
                    zLS.db:CopyProfile(zLS._profileCopySource)
                    print("|cff00ccff" .. zLS.L.MSG_PROFILE_COPIED .. zLS._profileCopySource .. "|r")
                    zLS._profileCopySource = nil
                    zSF.RefreshAll(true)
                end,
            },

            { widgetType = "header", name = L.OPT_PROFILE_DELETE_HEADER },

            {
                widgetType    = "select",
                width         = "half",
                widthBlizzard = "full",
                divider       = false,
                name          = L.OPT_PROFILE_DELETE_TARGET,
                desc          = L.OPT_PROFILE_DELETE_TARGET_DESC,
                values        = function()
                    local profiles = {}
                    local cur = zLS.db:GetCurrentProfile()
                    for _, name in pairs(zLS.db:GetProfiles()) do
                        if name ~= cur then profiles[name] = name end
                    end
                    return profiles
                end,
                get = function() return zLS._profileDeleteTarget end,
                set = function(v) zLS._profileDeleteTarget = v end,
            },

            { widgetType = "filler", width = "quarter", divider = false },

            {
                widgetType    = "button",
                width         = "quarter",
                name          = L.OPT_PROFILE_DELETE,
                desc          = L.OPT_PROFILE_DELETE_DESC,
                iconAtlas     = "common-icon-delete",
                confirm       = L.OPT_PROFILE_DELETE_CONFIRM,
                disableWhen   = function() return not zLS._profileDeleteTarget end,
                func          = function()
                    local name = zLS._profileDeleteTarget
                    zLS.db:DeleteProfile(name, true)
                    print("|cff00ccff" .. zLS.L.MSG_PROFILE_DELETED .. name .. "|r")
                    zLS._profileDeleteTarget = nil
                    zSF.RefreshAll(true)
                end,
            },

            { widgetType = "header", name = L.OPT_PROFILE_RESET_HEADER },

            {
                widgetType    = "button",
                width         = "third",
                divider       = false,
                name          = L.OPT_PROFILE_RESET,
                desc          = L.OPT_PROFILE_RESET_DESC,
                showResetIcon = true,
                confirm       = L.OPT_PROFILE_RESET_CONFIRM,
                func          = function()
                    zLS.db:ResetProfile()
                    zSF.RefreshAll(true)
                end,
            },
        },
    },
}
