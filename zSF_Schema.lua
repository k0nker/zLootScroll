-- zSF_Schema.lua
-- Declarative schema for every zLootScroll setting, consumed by
-- zSF_Bridge.lua and passed to the zSettingsFrame constructor.

local L   = zLS.L
local LSM = LibStub("LibSharedMedia-3.0")

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
                name       = L.OPT_ENABLED,
                desc       = L.OPT_ENABLED_DESC
            },

            {
                widgetType = "toggle",
                key        = "lockFrame",
                width      = "half",
                name       = L.OPT_LOCK_FRAME,
                desc       = L.OPT_LOCK_FRAME_DESC
            },

            { widgetType = "header", name = "Categories" },

            {
                widgetType = "toggle",
                key        = "showItems",
                name       = L.OPT_SHOW_ITEMS,
                desc       = L.OPT_SHOW_ITEMS_DESC
            },

            {
                widgetType = "toggle",
                key        = "showCurrency",
                name       = L.OPT_SHOW_CURRENCY,
                desc       = L.OPT_SHOW_CURRENCY_DESC
            },

            {
                widgetType = "toggle",
                key        = "showMoney",
                name       = L.OPT_SHOW_MONEY,
                desc       = L.OPT_SHOW_MONEY_DESC
            },

            { widgetType = "header", name = "Feed" },

            {
                widgetType = "select",
                key        = "insertMode",
                name       = L.OPT_INSERT_MODE,
                desc       = L.OPT_INSERT_MODE_DESC,
                values     = { BOTTOM = "Bottom", TOP = "Top" }
            },

            {
                widgetType = "range",
                key = "maxMessages",
                name = L.OPT_MAX_MESSAGES,
                desc = L.OPT_MAX_MESSAGES_DESC,
                min = 5,
                max = 100,
                step = 1
            },

            {
                widgetType = "range",
                key = "messageDuration",
                name = L.OPT_MSG_DURATION,
                desc = L.OPT_MSG_DURATION_DESC,
                min = 0.5,
                max = 60,
                step = 0.5
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
                name       = L.OPT_SHOW_ICON,
                desc       = L.OPT_SHOW_ICON_DESC
            },

            {
                widgetType = "range",
                key = "iconSize",
                width = "half",
                name = L.OPT_ICON_SIZE,
                min = 10,
                max = 24,
                step = 1
            },

            {
                widgetType = "toggle",
                key        = "showItemLevel",
                width      = "half",
                name       = L.OPT_SHOW_ILVL,
                desc       = L.OPT_SHOW_ILVL_DESC
            },

            {
                widgetType = "toggle",
                key        = "showItemTotals",
                width      = "half",
                name       = L.OPT_SHOW_TOTALS,
                desc       = L.OPT_SHOW_TOTALS_DESC
            },

            {
                widgetType = "toggle",
                key        = "amountFirst",
                width      = "half",
                name       = L.OPT_AMOUNT_FIRST,
                desc       = L.OPT_AMOUNT_FIRST_DESC
            },

            { widgetType = "header", name = "Frame" },

            {
                widgetType = "range",
                key = "frameWidth",
                width = "half",
                name = L.OPT_FRAME_WIDTH,
                min = 100,
                max = 800,
                step = 10
            },

            {
                widgetType = "range",
                key = "frameHeight",
                width = "half",
                name = L.OPT_FRAME_HEIGHT,
                min = 60,
                max = 600,
                step = 10
            },

            {
                widgetType = "range",
                key = "lineSpacing",
                width = "half",
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
                name       = L.OPT_SHOW_BG,
                desc       = L.OPT_SHOW_BG_DESC
            },

            {
                widgetType = "range",
                key = "bgAlpha",
                width = "half",
                name = L.OPT_BG_ALPHA,
                min = 0.0,
                max = 1.0,
                step = 0.05
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
                name         = L.OPT_FONT_FACE,
                desc         = L.OPT_FONT_FACE_DESC,
                values       = function() return LSM_Values("font") end,
                previewFetch = LSM_Fetch("font")
            },

            {
                widgetType = "select",
                key        = "fontOutline",
                width      = "half",
                name       = L.OPT_FONT_OUTLINE,
                desc       = L.OPT_FONT_OUTLINE_DESC,
                values     = FONT_OUTLINE_VALUES
            },

            {
                widgetType = "range",
                key = "fontSize",
                width = "half",
                name = L.OPT_FONT_SIZE,
                min = 8,
                max = 24,
                step = 1
            },

            {
                widgetType = "select",
                key        = "fontJustify",
                width      = "half",
                name       = L.OPT_FONT_JUSTIFY,
                desc       = L.OPT_FONT_JUSTIFY_DESC,
                values     = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
            },

            { widgetType = "header", name = "Font Shadow" },

            {
                widgetType = "toggle",
                key        = "fontShadow",
                name       = L.OPT_FONT_SHADOW,
                desc       = L.OPT_FONT_SHADOW_DESC
            },

            {
                widgetType  = "colorAlpha",
                key         = "fontShadowColor",
                width       = "half",
                name        = L.OPT_FONT_SHADOW_COLOR,
                disableWhen = function() return not zLS:Get("fontShadow") end
            },

            {
                widgetType = "range",
                key = "fontShadowOffsetX",
                width = "quarter",
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
                name       = L.OPT_COLOR_BY_QUALITY,
                desc       = L.OPT_COLOR_BY_QUALITY_DESC
            },

            {
                widgetType = "color",
                key        = "colorMoney",
                width      = "half",
                name       = L.OPT_COLOR_MONEY,
                desc       = L.OPT_COLOR_MONEY_DESC
            },
        },
    },
}
