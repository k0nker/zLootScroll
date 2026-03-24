-- LootBrowser.lua
-- Self-contained loot history browser. Opened via /zls browse.

-- ── Layout constants ──────────────────────────────────────────────────────────

local W           = 900   -- window width
local H           = 620   -- window height
local TITLEBAR_H  = 36    -- title bar
local FILTERBAR_H = 138   -- filter controls area: 44px row1 + 8 + 30px date row + 8 + 40px row2 + margins
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
    ---@type table<number,boolean>  per-tier ON/OFF; all ON by default
    quality   = { [0]=true, [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true },
    money     = "include", -- "include" | "exclude" | "only"
    currency  = "include", -- "include" | "exclude" | "only"
    ---@type number|nil  Unix timestamp (local-time epoch); nil = unbounded
    dateStart = nil,
    ---@type number|nil  Unix timestamp (local-time epoch); nil = unbounded
    dateEnd   = nil,
    search    = "",        -- substring match against item/currency name
}

---@type Frame|nil
local browser

-- ── Quality tier metadata ─────────────────────────────────────────────────────

---@type table<number,table>  { r, g, b } per WoW item quality index
local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 }, -- Poor (grey)
    [1] = { 1.00, 1.00, 1.00 }, -- Common (white)
    [2] = { 0.12, 1.00, 0.00 }, -- Uncommon (green)
    [3] = { 0.00, 0.44, 0.87 }, -- Rare (blue)
    [4] = { 0.64, 0.21, 0.93 }, -- Epic (purple)
    [5] = { 1.00, 0.50, 0.00 }, -- Legendary (orange)
    [6] = { 0.90, 0.80, 0.50 }, -- Artifact (pale gold)
}

---@type table<number,string>
local QUALITY_LABELS = {
    [0] = "Poor", [1] = "Common",   [2] = "Uncommon",
    [3] = "Rare",  [4] = "Epic",     [5] = "Legendary", [6] = "Artifact",
}

-- ── Filter bar (Phase 2) ──────────────────────────────────────────────────────

--- Stub: called whenever any filter changes. Phase 3 replaces with real table refresh.
local function RefreshTable() end

---Build the two-row filter controls bar.
---@param parent Frame
---@return Frame
local function BuildFilterBar(parent)
    local L = zLS.L

    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -(TITLEBAR_H + 1))
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(TITLEBAR_H + 1))
    bar:SetHeight(FILTERBAR_H)
    bar:SetFrameLevel(parent:GetFrameLevel() + 1)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.25)

    -- ── Row 1: drop-down filters + reset button (44px tall) ──────────────────

    local row1 = CreateFrame("Frame", nil, bar)
    row1:SetHeight(44)
    row1:SetPoint("TOPLEFT",  bar, "TOPLEFT",  SIDE_PAD, -4)
    row1:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -SIDE_PAD, -4)
    row1:SetFrameLevel(bar:GetFrameLevel() + 1)

    -- Each cell is anchored LEFT in row1 with y=0 so the dropdown vertically
    -- centres itself inside the 44-pixel row (LEFT anchor aligns midpoints).
    local xOff = 0
    local function MakeDDCell(w)
        local cell = CreateFrame("Frame", nil, row1)
        cell:SetSize(w, 20)
        cell:SetPoint("LEFT", row1, "LEFT", xOff, 0)
        xOff = xOff + w + 8
        return cell
    end

    local srvCell  = MakeDDCell(130)
    local chrCell  = MakeDDCell(130)
    local znCell   = MakeDDCell(130)
    local mnCell   = MakeDDCell(110)
    local crCell   = MakeDDCell(110)

    local serverDD   = zAF_BuildDropdown(srvCell, L.BROWSER_ALL,              C_PRIM)
    local charDD     = zAF_BuildDropdown(chrCell, L.BROWSER_ALL,              C_PRIM)
    local zoneDD     = zAF_BuildDropdown(znCell,  L.BROWSER_ALL,              C_PRIM)
    local moneyDD    = zAF_BuildDropdown(mnCell,  L.BROWSER_MONEY_INCLUDE,    C_PRIM)
    local currencyDD = zAF_BuildDropdown(crCell,  L.BROWSER_CURRENCY_INCLUDE, C_PRIM)

    local resetBtn = zAF_BuildActionButton(row1, L.BROWSER_RESET_FILTERS, nil, 80)
    resetBtn:SetPoint("RIGHT", row1, "RIGHT", 0, 0)

    -- ── Date row: range picker on its own line (30px tall) ────────────────────

    local dateRow = CreateFrame("Frame", nil, bar)
    dateRow:SetHeight(30)
    dateRow:SetPoint("TOPLEFT",  bar, "TOPLEFT",  SIDE_PAD, -(4 + 44 + 8))
    dateRow:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -SIDE_PAD, -(4 + 44 + 8))
    dateRow:SetFrameLevel(bar:GetFrameLevel() + 1)

    local drCell = CreateFrame("Frame", nil, dateRow)
    drCell:SetSize(280, 20)
    drCell:SetPoint("LEFT", dateRow, "LEFT", 0, 0)
    local datePicker = zAF_BuildDateRangePicker(drCell, C_PRIM)

    -- ── Row 2: quality pill toggles + search box (40px tall) ─────────────────

    local row2 = CreateFrame("Frame", nil, bar)
    row2:SetHeight(40)
    row2:SetPoint("TOPLEFT",  bar, "TOPLEFT",  SIDE_PAD, -(4 + 44 + 8 + 30 + 8))
    row2:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -SIDE_PAD, -(4 + 44 + 8 + 30 + 8))
    row2:SetFrameLevel(bar:GetFrameLevel() + 1)

    local qLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qLabel:SetWidth(38)
    qLabel:SetJustifyH("LEFT")
    qLabel:SetTextColor(0.55, 0.55, 0.55, 1)
    qLabel:SetText(L.BROWSER_QUALITY_LABEL)
    qLabel:SetPoint("LEFT", row2, "LEFT", 0, 0)

    local pillX = 42  -- 38px label + 4px gap
    ---@type table<number,CheckButton>
    local qualPills = {}
    for i = 0, 6 do
        local col  = QUALITY_COLORS[i]
        local pill = zAF_MakePillToggle(row2, col)
        pill:SetChecked(true)
        pill:SetPoint("LEFT", row2, "LEFT", pillX, 0)
        pillX = pillX + 36 + 4

        local tier = i  -- capture for closures
        local innerClick = pill.DoClick
        pill:SetScript("OnClick", function(self)
            innerClick(self)
            filters.quality[tier] = self.checked
            RefreshTable()
        end)
        pill:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(QUALITY_LABELS[tier])
            GameTooltip:Show()
        end)
        pill:SetScript("OnLeave", function() GameTooltip:Hide() end)
        qualPills[i] = pill
    end

    -- Search box fills the rest of row 2 (pillX already includes a 4px gap
    -- after the last pill, so the search sits 4px clear of it).
    local searchBg = CreateFrame("Frame", nil, row2)
    searchBg:SetHeight(20)
    searchBg:SetPoint("LEFT",  row2, "LEFT", pillX, 0)
    searchBg:SetPoint("RIGHT", row2, "RIGHT", 0, 0)
    searchBg:SetFrameLevel(row2:GetFrameLevel() + 1)

    local searchTexBg = searchBg:CreateTexture(nil, "BACKGROUND")
    searchTexBg:SetAllPoints()
    searchTexBg:SetColorTexture(0.07, 0.07, 0.10, 0.90)
    zAF_DrawBorder(searchBg, ZAF.COLOR_BORDER[1], ZAF.COLOR_BORDER[2], ZAF.COLOR_BORDER[3], 0.45)

    local searchHint = searchBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchHint:SetPoint("LEFT", searchBg, "LEFT", 6, 0)
    searchHint:SetTextColor(0.30, 0.30, 0.30, 1)
    searchHint:SetText(L.BROWSER_SEARCH_HINT)

    local search = CreateFrame("EditBox", nil, searchBg)
    search:SetPoint("TOPLEFT",     searchBg, "TOPLEFT",     4, -2)
    search:SetPoint("BOTTOMRIGHT", searchBg, "BOTTOMRIGHT", -4,  2)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    search:SetFont(GameFontHighlightSmall:GetFont())
    search:SetTextColor(0.9, 0.9, 0.9, 1)

    -- ── Bottom separator ──────────────────────────────────────────────────────

    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(ZAF.COLOR_BORDER[1], ZAF.COLOR_BORDER[2], ZAF.COLOR_BORDER[3], 0.5)
    sep:SetPoint("TOPLEFT",  bar, "BOTTOMLEFT",  0, 0)
    sep:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    PixelUtil.SetHeight(sep, 1, 1)
    zAF_DisablePixelSnap(sep)

    -- ── Drop-down menu accessors ──────────────────────────────────────────────

    serverDD.SetMenuAccessors(
        function() return filters.server end,
        function()
            local opts, order = { [false] = L.BROWSER_ALL }, { false }
            local g = zLS.db and zLS.db.global
            if g and g.chars then
                local realms = {}
                for realm in pairs(g.chars) do realms[#realms+1] = realm end
                table.sort(realms)
                for _, realm in ipairs(realms) do
                    opts[realm] = realm; order[#order+1] = realm
                end
            end
            return opts, order
        end,
        function(key, display)
            filters.server    = key or nil
            serverDD.text:SetText(display)
            filters.character = nil
            charDD.text:SetText(L.BROWSER_ALL)
            RefreshTable()
        end
    )

    charDD.SetMenuAccessors(
        function() return filters.character end,
        function()
            local opts, order = { [false] = L.BROWSER_ALL }, { false }
            local g = zLS.db and zLS.db.global
            if g and g.chars then
                local seen = {}
                if filters.server then
                    local chars = g.chars[filters.server]
                    if chars then
                        for name in pairs(chars) do seen[name] = true end
                    end
                else
                    for _, chars in pairs(g.chars) do
                        for name in pairs(chars) do seen[name] = true end
                    end
                end
                local names = {}
                for name in pairs(seen) do names[#names+1] = name end
                table.sort(names)
                for _, name in ipairs(names) do opts[name] = name; order[#order+1] = name end
            end
            return opts, order
        end,
        function(key, display)
            filters.character = key or nil
            charDD.text:SetText(display)
            RefreshTable()
        end
    )

    zoneDD.SetMenuAccessors(
        function() return filters.zone end,
        function()
            local opts, order = { [false] = L.BROWSER_ALL }, { false }
            local g = zLS.db and zLS.db.global
            if g and g.chars then
                local seen = {}
                for _, chars in pairs(g.chars) do
                    for _, data in pairs(chars) do
                        if data.lootLog then
                            for _, e in ipairs(data.lootLog) do
                                if e.zoneName and e.zoneName ~= "" then
                                    seen[e.zoneName] = true
                                end
                            end
                        end
                    end
                end
                local zones = {}
                for z in pairs(seen) do zones[#zones+1] = z end
                table.sort(zones)
                for _, z in ipairs(zones) do opts[z] = z; order[#order+1] = z end
            end
            return opts, order
        end,
        function(key, display)
            filters.zone = key or nil
            zoneDD.text:SetText(display)
            RefreshTable()
        end
    )

    datePicker.SetOnChanged(function(sTs, eTs)
        filters.dateStart = sTs
        filters.dateEnd   = eTs
        RefreshTable()
    end)


    local MONEY_KEYS   = { "include", "exclude", "only" }
    local MONEY_LABELS = {
        include = L.BROWSER_MONEY_INCLUDE,
        exclude = L.BROWSER_MONEY_EXCLUDE,
        only    = L.BROWSER_MONEY_ONLY,
    }
    moneyDD.SetMenuAccessors(
        function() return filters.money end,
        function()
            local opts, order = {}, {}
            for _, k in ipairs(MONEY_KEYS) do opts[k] = MONEY_LABELS[k]; order[#order+1] = k end
            return opts, order
        end,
        function(key, display)
            filters.money = key
            moneyDD.text:SetText(display)
            RefreshTable()
        end
    )

    local CURR_KEYS   = { "include", "exclude", "only" }
    local CURR_LABELS = {
        include = L.BROWSER_CURRENCY_INCLUDE,
        exclude = L.BROWSER_CURRENCY_EXCLUDE,
        only    = L.BROWSER_CURRENCY_ONLY,
    }
    currencyDD.SetMenuAccessors(
        function() return filters.currency end,
        function()
            local opts, order = {}, {}
            for _, k in ipairs(CURR_KEYS) do opts[k] = CURR_LABELS[k]; order[#order+1] = k end
            return opts, order
        end,
        function(key, display)
            filters.currency = key
            currencyDD.text:SetText(display)
            RefreshTable()
        end
    )

    -- ── Search wiring ─────────────────────────────────────────────────────────

    search:SetScript("OnTextChanged", function(self)
        local t = self:GetText()
        if t == "" then searchHint:Show() else searchHint:Hide() end
        filters.search = strtrim(t):lower()
        RefreshTable()
    end)
    search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    search:SetScript("OnEditFocusLost",   function()
        if search:GetText() == "" then searchHint:Show() end
    end)

    -- ── Reset button ──────────────────────────────────────────────────────────

    resetBtn:SetScript("OnClick", function()
        filters.server    = nil;  serverDD.text:SetText(L.BROWSER_ALL)
        filters.character = nil;  charDD.text:SetText(L.BROWSER_ALL)
        filters.zone      = nil;  zoneDD.text:SetText(L.BROWSER_ALL)
        filters.dateStart = nil; filters.dateEnd = nil; datePicker.ClearRange()
        filters.money     = "include"; moneyDD.text:SetText(L.BROWSER_MONEY_INCLUDE)
        filters.currency  = "include"; currencyDD.text:SetText(L.BROWSER_CURRENCY_INCLUDE)
        for i = 0, 6 do
            filters.quality[i] = true
            qualPills[i]:SetChecked(true)
        end
        search:SetText("")
        searchHint:Show()
        RefreshTable()
    end)

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

    zLS.zafCtx:Push()

    local f = CreateFrame("Frame", "zLootScrollBrowser", UIParent)
    table.insert(UISpecialFrames, "zLootScrollBrowser")
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)

    zAF_FillBG(f, C_BG[1], C_BG[2], C_BG[3], C_BG[4])

    -- Border lives in a high-level overlay frame so it renders above all child content.
    local borderFrame = CreateFrame("Frame", nil, f)
    borderFrame:SetAllPoints()
    borderFrame:SetFrameLevel(f:GetFrameLevel() + 200)
    zAF_DrawGradientBorder(borderFrame, C_PRIM, C_SEC, C_SEC, C_PRIM)

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
    zAF_DisablePixelSnap(sep)

    -- ── Close button ──────────────────────────────────────────────────────────

    local closeBtn = zAF_BuildCloseButton(titleBar, C_PRIM)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -SIDE_PAD, 0)
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

    zLS.zafCtx:Pop()
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
