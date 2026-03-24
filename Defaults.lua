-- Defaults.lua
zLS = zLS or {}

zLS.defaults = {
    -- ── Per-profile settings ───────────────────────────────────────────────
    profile = {
        -- ── Frame visibility ──────────────────────────────────────────────
        enabled           = true,           -- whether the feed frame is shown at all

        -- ── Frame dimensions ─────────────────────────────────────────────
        frameWidth        = 320,            -- pixels
        frameHeight       = 180,            -- pixels

        -- ── Message display ──────────────────────────────────────────────
        maxMessages       = 20,             -- max lines kept in the frame buffer
        messageDuration   = 8,              -- seconds a message stays visible (0 = never fade)
        lineSpacing       = 2,              -- pixels between lines
        fontSize          = 12,             -- point size for message text
        insertMode        = "BOTTOM",       -- "TOP" or "BOTTOM" — new messages go to bottom by default

        -- ── Category toggles ─────────────────────────────────────────────
        showItems         = true,           -- show looted/crafted/received items
        showCurrency      = true,           -- show currency token gains
        showMoney         = true,           -- show gold/silver/copper gains

        -- ── Quality display filters ───────────────────────────────────────
        showPoor          = true,           -- show Poor (grey) quality items
        showCommon        = true,           -- show Common (white) quality items
        showUncommon      = true,           -- show Uncommon (green) quality items
        showRare          = true,           -- show Rare (blue) quality items
        showEpic          = true,           -- show Epic (purple) quality items
        showLegendary     = true,           -- show Legendary/Artifact (orange/gold) quality items

        -- ── Item display options ──────────────────────────────────────────
        showItemIcon      = true,           -- prepend item icon texture to the message
        iconSize          = 14,             -- icon texture size in pixels
        showItemLevel     = true,           -- prepend item level inside brackets, e.g. [620-Name]
        showItemTotals    = false,          -- append bag count total after item name
        amountFirst       = false,          -- when true: +N [Name]; when false: [Name] +N

        -- ── Frame chrome ─────────────────────────────────────────────────
        showBackground    = true,           -- semi-transparent backdrop behind messages
        bgAlpha           = 0.4,            -- backdrop alpha (0.0–1.0)
        showBorder        = false,          -- thin border around frame
        lockFrame         = true,           -- when true, disables mouse drag

        -- ── Font ─────────────────────────────────────────────────────────
        fontFace          = "Friz Quadrata TT",  -- LSM font name
        fontOutline       = "OUTLINE",           -- font flag string
        fontJustify       = "LEFT",              -- LEFT / CENTER / RIGHT

        -- ── Font shadow ───────────────────────────────────────────────────
        fontShadow        = false,               -- draw shadow behind text
        fontShadowColor   = { 0, 0, 0, 1 },     -- RGBA
        fontShadowOffsetX = 1,                   -- pixels
        fontShadowOffsetY = -1,                  -- pixels

        -- ── Message colors ────────────────────────────────────────────────
        colorByQuality    = true,                -- tint items/currency by quality; false = white
        colorMoney        = { 1, 1, 0 },        -- RGB for money gain messages
        showTimestamp     = false,               -- when true, prepend [HH:MM:SS] to each message
        timestamp24hr     = true,               -- true = 24-hr clock; false = 12-hr (no AM/PM letters)
        colorTimestamp    = { 0.01, 0.46, 0.58 },   -- color for the [HH:MM:SS] timestamp
        colorCount        = { 0.68, 0.37, 0.37 },   -- color for the (N) bag and currency totals
        colorIncrement    = { .81, .80, .38 },       -- color for the +N increment on looted stacks

        -- ── Frame position ───────────────────────────────────────────────
        frame = {
            point    = "CENTER",
            relPoint = "CENTER",
            x        = 0,
            y        = 100,
        },
    },

    -- ── Per-character data ─────────────────────────────────────────────────
    -- Minimap button position is per-character (each alt can park it differently).
    char = {
        minimap = {
            hide        = false,  -- when true, LibDBIcon hides the button
            minimapPos  = 220,    -- degrees around the minimap (0 = top, clockwise)
        },
    },

    -- ── Account-wide data ─────────────────────────────────────────────────
    -- Loot log entries are initialised programmatically under
    -- global.chars[realm][charName].lootLog — no static defaults needed here.
    global = {
        keepForever   = false,  -- when true, log grows unbounded; false = capped at historyLength
        historyLength = 100,    -- max entries kept per character when keepForever is off

        -- Per-quality storage gates: when false, entries of that tier are pruned at login.
        storePoor      = true,
        storeCommon    = true,
        storeUncommon  = true,
        storeRare      = true,
        storeEpic      = true,
        storeLegendary = true,
        storeArtifact  = true,

        -- Per-type storage gates.
        storeMoney     = true,
        storeCurrency  = true,
    },
}

