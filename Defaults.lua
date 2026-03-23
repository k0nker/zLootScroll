-- Defaults.lua
zLS = zLS or {}

zLS.defaults = {
    -- ── Frame visibility ──────────────────────────────────────────────────
    enabled           = true,           -- whether the feed frame is shown at all

    -- ── Frame dimensions ─────────────────────────────────────────────────
    frameWidth        = 320,            -- pixels
    frameHeight       = 180,            -- pixels

    -- ── Message display ──────────────────────────────────────────────────
    maxMessages       = 20,             -- max lines kept in the frame buffer
    messageDuration   = 8,              -- seconds before a line fades out (0 = never fade)
    lineSpacing       = 2,              -- pixels between lines
    fontSize          = 12,             -- point size for message text
    insertMode        = "BOTTOM",       -- "TOP" or "BOTTOM" — new messages go to bottom by default

    -- ── Category toggles ─────────────────────────────────────────────────
    showItems         = true,           -- show looted/crafted/received items
    showCurrency      = true,           -- show currency token gains
    showMoney         = true,           -- show gold/silver/copper gains

    -- ── Item display options ──────────────────────────────────────────────
    showItemIcon      = true,           -- prepend item icon texture to the message
    iconSize          = 14,             -- icon texture size in pixels
    showItemLevel     = true,           -- prepend item level inside brackets, e.g. [620-Name]
    showItemTotals    = false,          -- append bag count total after item name
    amountFirst       = false,          -- when true: +N [Name]; when false: [Name] +N

    -- ── Frame chrome ─────────────────────────────────────────────────────
    showBackground    = true,           -- semi-transparent backdrop behind messages
    bgAlpha           = 0.4,            -- backdrop alpha (0.0–1.0)
    showBorder        = false,          -- thin border around frame
    lockFrame         = false,          -- when true, disables mouse drag

    -- ── Font ─────────────────────────────────────────────────────────────
    fontFace          = "Friz Quadrata TT",  -- LSM font name
    fontOutline       = "OUTLINE",           -- font flag string
    fontJustify       = "LEFT",              -- LEFT / CENTER / RIGHT

    -- ── Font shadow ───────────────────────────────────────────────────────
    fontShadow        = false,               -- draw shadow behind text
    fontShadowColor   = { 0, 0, 0, 1 },     -- RGBA
    fontShadowOffsetX = 1,                   -- pixels
    fontShadowOffsetY = -1,                  -- pixels

    -- ── Message colors ────────────────────────────────────────────────────
    colorByQuality    = true,                -- tint items/currency by quality; false = white
    colorMoney        = { 1, 1, 0 },        -- RGB for money gain messages

    -- ── Default frame position (per-character fallback) ───────────────────
    defaultPoint      = "BOTTOMRIGHT",
    defaultRelPoint   = "BOTTOMRIGHT",
    defaultX          = -20,
    defaultY          = 300,
}
