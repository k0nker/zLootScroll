-- LootBrowser.lua
-- Self-contained loot history browser. Opened via /zls browse.

-- ── Layout constants ──────────────────────────────────────────────────────────

local W           = 900   -- window width
local H           = 620   -- window height
local TITLEBAR_H  = 36    -- title bar
local FILTERBAR_H = 52    -- filter controls row
local COLHEADER_H = 26    -- column header row (Phase 3)
local ROW_H       = 22    -- per-row height (Phase 3)
local SIDE_PAD    = 10    -- horizontal inner padding
local MAX_ROWS    = 500   -- cap on rendered data rows (Phase 3)

-- Mage blue (primary) / DK red (secondary) — matches the addon's theme.
local C_PRIM     = { 0.25, 0.78, 0.92 }
local C_SEC      = { 0.77, 0.12, 0.23 }
local C_BG       = { 0.04, 0.04, 0.06, 0.97 }
local C_TITLEBAR = { 0, 0, 0, 0.55 }

-- ── Filter state ─────────────────────────────────────────────────────────────
-- Declared here so all phases share the same table. Persists across open/close.

---@class zLS_BrowserFilters
local filters = {
    server    = nil,       -- nil = All; string = realm name
    character = nil,       -- nil = All; string = character name
    zone      = nil,       -- nil = All; string = zone name
    quality   = nil,       -- nil = All; 0–7 = specific quality tier
    money     = "include", -- "include" | "exclude" | "only"
    dateRange = "all",     -- "all" | "today" | "7d" | "30d" | "90d"
    search    = "",        -- substring match against item/currency name
}

---@type Frame|nil
local browser

-- ── Filter bar (Phase 2) ──────────────────────────────────────────────────────

---Build the filter controls bar. Phase 2 replaces the placeholder content.
---Returns the bar frame so the table section can anchor below it.
---@param parent Frame
---@return Frame
local function BuildFilterBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -(TITLEBAR_H + 1))
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(TITLEBAR_H + 1))
    bar:SetHeight(FILTERBAR_H)
    bar:SetFrameLevel(parent:GetFrameLevel() + 1)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.25)

    local ph = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ph:SetPoint("CENTER")
    ph:SetTextColor(0.38, 0.38, 0.38, 1)
    ph:SetText("— Filters coming in Phase 2 —")

    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(ZSF.COLOR_BORDER[1], ZSF.COLOR_BORDER[2], ZSF.COLOR_BORDER[3], 0.5)
    sep:SetPoint("TOPLEFT",  bar, "BOTTOMLEFT",  0, 0)
    sep:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    PixelUtil.SetHeight(sep, 1, 1)
    zSF_DisablePixelSnap(sep)

    return bar
end

-- ── Table (Phase 3) ───────────────────────────────────────────────────────────

---Build the scrollable data table. Phase 3 replaces the placeholder content.
---@param parent Frame
---@param filterBar Frame
local function BuildTable(parent, filterBar) -- luacheck: ignore filterBar
    local ph = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ph:SetPoint("CENTER", parent, "CENTER", 0, -((TITLEBAR_H + 1 + FILTERBAR_H) / 2))
    ph:SetTextColor(0.32, 0.32, 0.32, 1)
    ph:SetText("— Loot data table coming in Phase 3 —")
end

-- ── Browser frame construction ────────────────────────────────────────────────

local function BuildBrowser()
    if browser then return end

    local f = CreateFrame("Frame", "zLootScrollBrowser", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)

    zSF_FillBG(f, C_BG[1], C_BG[2], C_BG[3], C_BG[4])
    zSF_DrawGradientBorder(f, C_PRIM, C_PRIM, C_SEC, C_SEC)

    -- ── Title bar ─────────────────────────────────────────────────────────────

    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT",  f, "TOPLEFT")
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT")
    titleBar:SetHeight(TITLEBAR_H)
    titleBar:SetFrameLevel(f:GetFrameLevel() + 2)

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(C_TITLEBAR[1], C_TITLEBAR[2], C_TITLEBAR[3], C_TITLEBAR[4])

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", SIDE_PAD + 4, 0)
    titleText:SetTextColor(C_PRIM[1], C_PRIM[2], C_PRIM[3], 1)
    titleText:SetText(zLS.L.BROWSER_TITLE)

    -- Thin accent line under the title bar
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(C_PRIM[1], C_PRIM[2], C_PRIM[3], 0.5)
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -TITLEBAR_H)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -TITLEBAR_H)
    PixelUtil.SetHeight(sep, 1, 1)
    zSF_DisablePixelSnap(sep)

    -- ── Close button ──────────────────────────────────────────────────────────

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -SIDE_PAD, 0)
    closeBtn:SetFrameLevel(titleBar:GetFrameLevel() + 1)
    closeBtn:EnableMouse(true)

    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeX:SetAllPoints()
    closeX:SetText("×")
    closeX:SetTextColor(0.60, 0.60, 0.60, 1)

    closeBtn:SetScript("OnEnter", function() closeX:SetTextColor(1, 0.3, 0.3, 1) end)
    closeBtn:SetScript("OnLeave", function() closeX:SetTextColor(0.60, 0.60, 0.60, 1) end)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ── Drag (title bar only) ─────────────────────────────────────────────────

    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

    -- ── Content sections ──────────────────────────────────────────────────────

    local filterBar = BuildFilterBar(f)
    BuildTable(f, filterBar)

    f:Hide()
    browser = f
end

-- ── Public API ────────────────────────────────────────────────────────────────

---Toggle the loot history browser open or closed.
function zLS:OpenBrowser()
    BuildBrowser()
    if browser:IsShown() then
        browser:Hide()
    else
        browser:Show()
    end
end
