-- LootBrowser.lua
-- Self-contained loot history browser. Opened via /zls browse.

-- ── Layout constants ──────────────────────────────────────────────────────────

local W           = 900   -- window width
local H           = 620   -- window height
local TITLEBAR_H  = 36    -- title bar
local FILTERBAR_H = 138   -- 4 + 14 labels + 2 + 22 DDs + 6 + 30 date + 6 + 22 quality + 6 + 22 pages + 4
local COLHEADER_H = 26    -- column header row
local ROW_H       = 22    -- per-row height
local SIDE_PAD    = 10    -- horizontal inner padding
local PAGE_SIZE   = 250   -- entries per page

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

-- ── Shared quality-colour helper ─────────────────────────────────────────────

---@param quality number|nil  WoW item quality index (0-6), or nil
---@return number r, number g, number b  in [0,1]; falls back to white
local function QualityColor(quality)
    local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qc then return qc.r, qc.g, qc.b end
    return 1, 1, 1
end

-- ── Column definitions ────────────────────────────────────────────────────────

---@class zLS_ColDef
---@field key   string  Locale key for the header label
---@field w     number  Pixel width
---@field j     string  FontString justification ("LEFT" | "CENTER" | "RIGHT")

---@type zLS_ColDef[]
local COLS = {
    { key = "BROWSER_COL_DATETIME",  w = 110, j = "LEFT"   },
    { key = "BROWSER_COL_SERVER",    w = 90,  j = "LEFT"   },
    { key = "BROWSER_COL_CHARACTER", w = 90,  j = "LEFT"   },
    { key = "BROWSER_COL_ITEM",      w = 205, j = "LEFT"   },
    { key = "BROWSER_COL_ILVL",      w = 45,  j = "CENTER" },
    { key = "BROWSER_COL_AMOUNT",    w = 65,  j = "RIGHT"  },
    { key = "BROWSER_COL_TOTAL",     w = 65,  j = "RIGHT"  },
    { key = "BROWSER_COL_MAP",       w = 95,  j = "LEFT"   },
    { key = "BROWSER_COL_ZONE",      w = 115, j = "LEFT"   },
}

-- ── Sort helpers ──────────────────────────────────────────────────────────────

---@type table<number, fun(r: table): any>
local sortGetters = {
    [1] = function(r) return r.entry.t          or 0  end,
    [2] = function(r) return r.realm            or "" end,
    [3] = function(r) return r.char             or "" end,
    [4] = function(r) return r.entry.itemName   or r.entry.name or "" end,
    [5] = function(r) return r.entry.ilvl       or 0  end,
    [6] = function(r) return r.entry.amount     or r.entry.totalCopper or 0 end,
    [7] = function(r) return r.entry.total      or r.entry.quantity    or 0 end,
    [8] = function(r) return r.entry.mapName    or "" end,
    [9] = function(r) return r.entry.zoneName   or "" end,
}

---@param col  number  1-indexed column
---@param dir  number  -1 = descending, 1 = ascending
---@return fun(a: table, b: table): boolean
local function MakeSortComparator(col, dir)
    local getter = sortGetters[col] or sortGetters[1]
    return function(a, b)
        local va, vb = getter(a), getter(b)
        if va == vb then
            return (a.entry.t or 0) > (b.entry.t or 0)
        end
        if dir == -1 then return va > vb else return va < vb end
    end
end

-- ── Filter helpers ────────────────────────────────────────────────────────────

---@param e         table
---@param dateStart number|nil  unix timestamp lower bound (inclusive)
---@param dateEnd   number|nil  unix timestamp upper bound (inclusive)
local function PassesDateFilter(e, dateStart, dateEnd)
    if not dateStart and not dateEnd then return true end
    if not e.t then return true end
    if dateStart and e.t < dateStart then return false end
    if dateEnd   and e.t > dateEnd   then return false end
    return true
end

---@param e       table
---@param quality table<number,boolean>|nil  per-tier booleans; nil = show all
local function PassesQualityFilter(e, quality)
    if e.type ~= "item" then return true end
    if not quality then return true end
    if e.quality == nil then return true end
    return quality[e.quality] ~= false
end

---@param e    table
---@param mode string  "include" | "exclude" | "only"
local function PassesMoneyFilter(e, mode)
    if mode == "only"    then return e.type == "money" end
    if mode == "exclude" then return e.type ~= "money" end
    return true
end

---@param e    table
---@param mode string  "include" | "exclude" | "only"
local function PassesCurrencyFilter(e, mode)
    if mode == "only"    then return e.type == "currency" end
    if mode == "exclude" then return e.type ~= "currency" end
    return true
end

---@param e        table
---@param realm    string
---@param charName string
---@param search   string|nil  lowercase substring; empty or nil skips check
local function PassesSearch(e, realm, charName, search)
    if not search or search == "" then return true end
    local function has(s) return s and s:lower():find(search, 1, true) end
    return has(e.itemName) or has(e.name) or has(realm) or has(charName)
        or has(e.zoneName)
end

-- ── Filter bar (Phase 2) ──────────────────────────────────────────────────────

--- Forward declaration; BuildTable assigns the real implementation.
---@type fun()
local RefreshTable = function() end

---@type number
local currentPage = 1

---@type table
local filteredCache = {}

---@type number  total entries in the loot log before any filter is applied
local rawTotal = 0

--- Forward declaration; BuildTable assigns the real implementation.
---@type fun(page: number)
local RenderPage = function() end

--- Forward declaration; BuildFilterBar assigns the real implementation.
---@type fun(page: number, totalPages: number, rangeStart: number, rangeEnd: number, total: number, grandTotal: number)
local UpdatePageControls = function() end

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

    -- ── Label row: tiny grey captions above each dropdown (14px tall) ─────────

    local labelRow = CreateFrame("Frame", nil, bar)
    labelRow:SetHeight(14)
    labelRow:SetPoint("TOPLEFT",  bar, "TOPLEFT",  SIDE_PAD, -4)
    labelRow:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -SIDE_PAD, -4)
    labelRow:SetFrameLevel(bar:GetFrameLevel() + 1)

    -- ── DD row: drop-down filters + reset button (22px tall) ─────────────────
    -- Y: 4 top-pad + 14 labels + 2 gap = 20

    local ddRow = CreateFrame("Frame", nil, bar)
    ddRow:SetHeight(22)
    ddRow:SetPoint("TOPLEFT",  bar, "TOPLEFT",  SIDE_PAD, -20)
    ddRow:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -SIDE_PAD, -20)
    ddRow:SetFrameLevel(bar:GetFrameLevel() + 1)

    -- Each cell is anchored LEFT in ddRow (midpoint alignment).
    -- A matching label is placed above each cell in labelRow at the same x.
    local xOff = 0
    ---@param w         number  pixel width of the cell and its label
    ---@param labelText string  caption rendered in labelRow
    ---@return Frame
    local function MakeDDCell(w, labelText)
        local lbl = labelRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetWidth(w)
        lbl:SetJustifyH("LEFT")
        lbl:SetTextColor(0.55, 0.55, 0.55, 1)
        lbl:SetPoint("LEFT", labelRow, "LEFT", xOff, 0)
        lbl:SetText(labelText)

        local cell = CreateFrame("Frame", nil, ddRow)
        cell:SetSize(w, 20)
        cell:SetPoint("LEFT", ddRow, "LEFT", xOff, 0)
        xOff = xOff + w + 8
        return cell
    end

    local srvCell  = MakeDDCell(130, L.BROWSER_COL_SERVER)
    local chrCell  = MakeDDCell(130, L.BROWSER_COL_CHARACTER)
    local znCell   = MakeDDCell(130, L.BROWSER_COL_ZONE)
    local mnCell   = MakeDDCell(110, L.BROWSER_LABEL_MONEY)
    local crCell   = MakeDDCell(110, L.BROWSER_LABEL_CURRENCY)

    local serverDD   = zAF_BuildDropdown(srvCell, L.BROWSER_ALL,              C_PRIM, parent)
    local charDD     = zAF_BuildDropdown(chrCell, L.BROWSER_ALL,              C_PRIM, parent)
    local zoneDD     = zAF_BuildDropdown(znCell,  L.BROWSER_ALL,              C_PRIM, parent)
    local moneyDD    = zAF_BuildDropdown(mnCell,  L.BROWSER_MONEY_INCLUDE,    C_PRIM, parent)
    local currencyDD = zAF_BuildDropdown(crCell,  L.BROWSER_CURRENCY_INCLUDE, C_PRIM, parent)

    local resetBtn = zAF_BuildActionButton(ddRow, L.BROWSER_RESET_FILTERS, nil, 80)
    resetBtn:SetPoint("RIGHT", ddRow, "RIGHT", 0, 0)

    local refreshBtn = zAF_BuildActionButton(ddRow, L.BROWSER_REFRESH, nil, 70)
    refreshBtn:SetPoint("RIGHT", resetBtn, "LEFT", -4, 0)
    refreshBtn:SetScript("OnClick", function() RefreshTable() end)

    -- ── Date row: range picker on its own line (30px tall) ────────────────────

    local dateRow = CreateFrame("Frame", nil, bar)
    dateRow:SetHeight(30)
    -- Y: 4 + 14 + 2 + 22 + 6 = 48
    dateRow:SetPoint("TOPLEFT",  bar, "TOPLEFT",  SIDE_PAD, -48)
    dateRow:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -SIDE_PAD, -48)
    dateRow:SetFrameLevel(bar:GetFrameLevel() + 1)

    local drCell = CreateFrame("Frame", nil, dateRow)
    drCell:SetSize(280, 20)
    drCell:SetPoint("LEFT", dateRow, "LEFT", 0, 0)
    local datePicker = zAF_BuildDateRangePicker(drCell, C_PRIM)

    -- ── Row 2: quality pill toggles + search box (22px tall) ─────────────────
    -- Y: 4 + 14 + 2 + 22 + 6 + 30 + 6 = 84

    local row2 = CreateFrame("Frame", nil, bar)
    row2:SetHeight(22)
    row2:SetPoint("TOPLEFT",  bar, "TOPLEFT",  SIDE_PAD, -84)
    row2:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -SIDE_PAD, -84)
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
            filters.zone      = nil
            zoneDD.text:SetText(L.BROWSER_ALL)
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
            filters.zone      = nil
            zoneDD.text:SetText(L.BROWSER_ALL)
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
                for realm, chars in pairs(g.chars) do
                    if not filters.server or realm == filters.server then
                        for charName, data in pairs(chars) do
                            if not filters.character or charName == filters.character then
                                if data.lootLog then
                                    for _, e in ipairs(data.lootLog) do
                                        if e.zoneName and e.zoneName ~= "" then
                                            seen[e.zoneName] = true
                                        end
                                    end
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
    search:SetScript("OnEscapePressed",   function() search:ClearFocus() end)

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

    -- ── Pagination row: << < [Page X / Y] > >> (22px tall) ───────────────────
    -- Y: 4 + 14 + 2 + 22 + 6 + 30 + 6 + 22 + 6 = 112

    local pageRow = CreateFrame("Frame", nil, bar)
    pageRow:SetHeight(22)
    pageRow:SetPoint("TOPLEFT",  bar, "TOPLEFT",  SIDE_PAD, -112)
    pageRow:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -SIDE_PAD, -112)
    pageRow:SetFrameLevel(bar:GetFrameLevel() + 1)

    ---@param btn     Button
    ---@param enabled boolean
    local function SetNavBtnEnabled(btn, enabled)
        if enabled then
            btn:EnableMouse(true)
            btn.label:SetTextColor(0.80, 0.80, 0.80, 1)
        else
            btn:EnableMouse(false)
            btn.label:SetTextColor(0.30, 0.30, 0.30, 1)
        end
    end

    -- Build right-to-left so each button anchors to its right neighbour.
    local lastPageBtn  = zAF_BuildActionButton(pageRow, ">>", nil, 28)
    lastPageBtn:SetPoint("RIGHT", pageRow, "RIGHT", 0, 0)

    local nextPageBtn  = zAF_BuildActionButton(pageRow, ">",  nil, 28)
    nextPageBtn:SetPoint("RIGHT", lastPageBtn, "LEFT", -4, 0)

    local pageText = pageRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageText:SetWidth(100)
    pageText:SetJustifyH("CENTER")
    pageText:SetTextColor(0.75, 0.75, 0.75, 1)
    pageText:SetPoint("RIGHT", nextPageBtn, "LEFT", -4, 0)
    pageText:SetText("")

    local prevPageBtn  = zAF_BuildActionButton(pageRow, "<",  nil, 28)
    prevPageBtn:SetPoint("RIGHT", pageText, "LEFT", -4, 0)

    local firstPageBtn = zAF_BuildActionButton(pageRow, "<<", nil, 28)
    firstPageBtn:SetPoint("RIGHT", prevPageBtn, "LEFT", -4, 0)

    local showingText = pageRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    showingText:SetWidth(160)
    showingText:SetJustifyH("LEFT")
    showingText:SetTextColor(0.45, 0.45, 0.45, 1)
    showingText:SetPoint("LEFT", pageRow, "LEFT", 0, 0)
    showingText:SetText("")

    local statSep = pageRow:CreateTexture(nil, "ARTWORK")
    statSep:SetWidth(1)
    statSep:SetPoint("TOP",    pageRow, "TOPLEFT",    164, -3)
    statSep:SetPoint("BOTTOM", pageRow, "BOTTOMLEFT", 164,  3)
    statSep:SetColorTexture(0.30, 0.30, 0.30, 1)

    local totalText = pageRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalText:SetJustifyH("LEFT")
    totalText:SetTextColor(0.45, 0.45, 0.45, 1)
    totalText:SetPoint("LEFT", pageRow, "LEFT", 170, 0)
    totalText:SetText("")

    firstPageBtn:SetScript("OnClick", function()
        if currentPage > 1 then RenderPage(1) end
    end)
    prevPageBtn:SetScript("OnClick", function()
        if currentPage > 1 then RenderPage(currentPage - 1) end
    end)
    nextPageBtn:SetScript("OnClick", function()
        local tp = math.max(1, math.ceil(#filteredCache / PAGE_SIZE))
        if currentPage < tp then RenderPage(currentPage + 1) end
    end)
    lastPageBtn:SetScript("OnClick", function()
        local tp = math.max(1, math.ceil(#filteredCache / PAGE_SIZE))
        if currentPage < tp then RenderPage(tp) end
    end)

    UpdatePageControls = function(page, totalPages, rangeStart, rangeEnd, total, grandTotal)
        pageText:SetText(string.format(L.BROWSER_PAGE_OF, page, totalPages))
        showingText:SetText(total > 0 and string.format(L.BROWSER_SHOWING, rangeStart, rangeEnd, total) or "")
        totalText:SetText(string.format(L.BROWSER_TOTAL_ENTRIES, grandTotal))
        SetNavBtnEnabled(firstPageBtn, page > 1)
        SetNavBtnEnabled(prevPageBtn,  page > 1)
        SetNavBtnEnabled(nextPageBtn,  page < totalPages)
        SetNavBtnEnabled(lastPageBtn,  page < totalPages)
    end

    return bar
end

-- ── Table (Phase 3) ───────────────────────────────────────────────────────────

---Build the scrollable data table with sortable column headers and pre-allocated rows.
---@param parent    Frame
---@param filterBar Frame
local function BuildTable(parent, filterBar) -- luacheck: ignore filterBar
    local L = zLS.L

    -- Sort state — locals so OnClick closures and RefreshTable share them.
    local sortCol = 1
    local sortDir = -1  -- -1 = descending (newest first), 1 = ascending

    local tableTop = TITLEBAR_H + 1 + FILTERBAR_H

    -- ── Container area ────────────────────────────────────────────────────────

    local tableArea = CreateFrame("Frame", nil, parent)
    tableArea:SetPoint("TOPLEFT",     parent, "TOPLEFT",  0, -tableTop)
    tableArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    tableArea:SetFrameLevel(parent:GetFrameLevel() + 1)

    -- ── Column header row ─────────────────────────────────────────────────────

    local headerRow = CreateFrame("Frame", nil, tableArea)
    headerRow:SetHeight(COLHEADER_H)
    headerRow:SetPoint("TOPLEFT",  tableArea, "TOPLEFT",  SIDE_PAD, 0)
    headerRow:SetPoint("TOPRIGHT", tableArea, "TOPRIGHT", -SIDE_PAD, 0)
    headerRow:SetFrameLevel(tableArea:GetFrameLevel() + 2)

    local headerBg = headerRow:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0, 0, 0, 0.40)

    ---@type Frame[]  sort arrow Frames, one per column
    local sortArrows = {}
    local xPos = 0
    for i, col in ipairs(COLS) do
        local btn = CreateFrame("Button", nil, headerRow)
        btn:SetSize(col.w, COLHEADER_H)
        btn:SetPoint("LEFT", headerRow, "LEFT", xPos, 0)
        btn:SetFrameLevel(headerRow:GetFrameLevel() + 1)

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT",  btn, "LEFT",  4,   0)
        lbl:SetPoint("RIGHT", btn, "RIGHT", -18, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetTextColor(0.75, 0.75, 0.75, 1)
        lbl:SetText(L[col.key] or col.key)

        -- Sort arrow, hidden by default; direction updated in RefreshTable.
        local arrow = zAF_MakeVerticalArrow(btn, true, C_PRIM, C_SEC)
        arrow:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
        arrow:Hide()
        sortArrows[i] = arrow

        -- Thin column divider on the right edge of each header cell.
        local div = headerRow:CreateTexture(nil, "BACKGROUND")
        div:SetWidth(1)
        div:SetPoint("TOP",    btn, "TOPRIGHT",    0, 0)
        div:SetPoint("BOTTOM", btn, "BOTTOMRIGHT", 0, 0)
        div:SetColorTexture(unpack(ZAF.COLOR_COL_DIVIDER))

        local colIdx = i
        btn:SetScript("OnClick", function()
            if sortCol == colIdx then
                sortDir = -sortDir
            else
                sortCol = colIdx
                sortDir = -1
            end
            RefreshTable()
        end)

        xPos = xPos + col.w
    end

    -- Accent line under the header row.
    local hdSep = tableArea:CreateTexture(nil, "ARTWORK")
    hdSep:SetColorTexture(C_PRIM[1], C_PRIM[2], C_PRIM[3], 0.3)
    hdSep:SetPoint("TOPLEFT",  headerRow, "BOTTOMLEFT",  0, 0)
    hdSep:SetPoint("TOPRIGHT", headerRow, "BOTTOMRIGHT", 0, 0)
    PixelUtil.SetHeight(hdSep, 1, 1)
    zAF_DisablePixelSnap(hdSep)

    -- ── Scroll frame ──────────────────────────────────────────────────────────
    -- sf must be anchored and sized before content is created; anchoring to a
    -- zero-size frame produces a degenerate layout.

    local tableW = W - 2 * SIDE_PAD  -- pixel width of the scrollable data area

    local sf = CreateFrame("ScrollFrame", nil, tableArea)
    sf:SetPoint("TOPLEFT",     tableArea, "TOPLEFT",  SIDE_PAD, -COLHEADER_H)
    sf:SetPoint("BOTTOMRIGHT", tableArea, "BOTTOMRIGHT", -SIDE_PAD, 0)
    sf:SetFrameLevel(tableArea:GetFrameLevel() + 1)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local current   = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local new       = math.max(0, math.min(current - (delta * 30), maxScroll))
        self:SetVerticalScroll(new)
    end)

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(tableW)
    content:SetHeight(1)
    content:SetPoint("TOPLEFT")
    sf:SetScrollChild(content)
    content:SetFrameLevel(sf:GetFrameLevel() + 1)

    -- ── Pre-allocate row frames ────────────────────────────────────────────────
    -- Each row has: stripe BG, hover highlight, 9 cell FontStrings, icon texture
    -- for col 4, invisible button overlay for col 4, divider textures.

    ---@type Frame[]
    local rowFrames = {}

    for i = 1, PAGE_SIZE do
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW_H)
        row:SetFrameLevel(content:GetFrameLevel() + 1)

        local sc = (i % 2 == 0) and ZAF.COLOR_ROW_STRIPE_EVEN or ZAF.COLOR_ROW_STRIPE_ODD
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints()
        stripe:SetColorTexture(sc[1], sc[2], sc[3], sc[4])

        local hov = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        hov:SetAllPoints()
        hov:SetColorTexture(unpack(ZAF.COLOR_ROW_HOVER))
        hov:Hide()
        row._hover = hov

        row._cells = {}
        local cx = 0
        for ci, col in ipairs(COLS) do
            if ci == 4 then
                -- Icon (20×20 left of name text).
                local icon = row:CreateTexture(nil, "ARTWORK")
                icon:SetSize(20, 20)
                icon:SetPoint("LEFT", row, "LEFT", cx + 2, 0)
                row._icon = icon

                local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                nameFs:SetPoint("LEFT",  row, "LEFT", cx + 26, 0)
                nameFs:SetPoint("RIGHT", row, "LEFT", cx + col.w - 2, 0)
                nameFs:SetJustifyH("LEFT")
                row._name    = nameFs
                row._cells[ci] = nameFs

                -- Full-cell button for tooltip events.
                local cellBtn = CreateFrame("Button", nil, row)
                cellBtn:SetPoint("LEFT",  row, "LEFT", cx,        0)
                cellBtn:SetPoint("RIGHT", row, "LEFT", cx + col.w, 0)
                cellBtn:SetHeight(ROW_H)
                cellBtn:SetFrameLevel(row:GetFrameLevel() + 2)
                row._cellBtn = cellBtn
            else
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetPoint("LEFT",  row, "LEFT", cx + 4,        0)
                fs:SetPoint("RIGHT", row, "LEFT", cx + col.w - 4, 0)
                fs:SetJustifyH(col.j)
                row._cells[ci] = fs
            end

            local div = row:CreateTexture(nil, "BACKGROUND")
            div:SetWidth(1)
            div:SetPoint("TOP",    row, "TOPLEFT",    cx + col.w, 0)
            div:SetPoint("BOTTOM", row, "BOTTOMLEFT", cx + col.w, 0)
            div:SetColorTexture(unpack(ZAF.COLOR_COL_DIVIDER))

            cx = cx + col.w
        end

        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self) self._hover:Show() end)
        row:SetScript("OnLeave", function(self) self._hover:Hide() end)

        row:Hide()
        rowFrames[i] = row
    end

    -- ── Status notice (shown when no results or cap reached) ──────────────────

    local notice = tableArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    notice:SetPoint("TOP", tableArea, "TOP", 0, -(COLHEADER_H + 24))
    notice:SetTextColor(0.32, 0.32, 0.32, 1)
    notice:Hide()

    local function UpdateNotice(total)
        if total == 0 then
            notice:SetText(L.BROWSER_NO_RESULTS)
            notice:Show()
        else
            notice:Hide()
        end
    end

    -- ── PopulateRow ───────────────────────────────────────────────────────────

    local function PopulateRow(rowFrame, row)
        local e = row.entry

        -- Col 1: Date / Time
        rowFrame._cells[1]:SetText(e.t and date("%Y-%m-%d %H:%M:%S", e.t) or "")

        -- Col 2: Server
        rowFrame._cells[2]:SetText(row.realm or "")

        -- Col 3: Character
        rowFrame._cells[3]:SetText(row.char or "")

        -- Col 4: Icon + name, coloured by quality
        if e.texture then
            rowFrame._icon:SetTexture(e.texture)
            rowFrame._icon:Show()
        elseif e.iconFileID then
            rowFrame._icon:SetTexture(e.iconFileID)
            rowFrame._icon:Show()
        else
            rowFrame._icon:SetTexture(nil)
            rowFrame._icon:Hide()
        end

        if e.type == "item" then
            local r, g, b = QualityColor(e.quality)
            rowFrame._name:SetTextColor(r, g, b, 1)
            rowFrame._name:SetText(e.itemName or "")
        elseif e.type == "currency" then
            local r, g, b = QualityColor(e.quality or 1)
            rowFrame._name:SetTextColor(r, g, b, 1)
            rowFrame._name:SetText(e.name or "")
        elseif e.type == "money" then
            rowFrame._name:SetTextColor(0.85, 0.75, 0.30, 1)
            rowFrame._name:SetText(
                e.totalCopper and C_CurrencyInfo.GetCoinTextureString(e.totalCopper) or "")
        else
            rowFrame._name:SetTextColor(0.75, 0.75, 0.75, 1)
            rowFrame._name:SetText("")
        end

        -- Tooltip on the item-cell button.
        rowFrame._cellBtn:SetScript("OnEnter", function()
            if e.type == "item" and e.itemLink then
                GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
                GameTooltip:SetHyperlink("|H" .. e.itemLink .. "|h[" .. (e.itemName or "") .. "]|h")
                GameTooltip:Show()
            elseif e.type == "currency" and e.currencyID then
                GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
                GameTooltip:SetCurrencyByID(e.currencyID)
                GameTooltip:Show()
            end
        end)
        rowFrame._cellBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Col 5: iLvl
        rowFrame._cells[5]:SetText(e.ilvl and e.ilvl > 0 and tostring(e.ilvl) or "")

        -- Col 6: Amount — nil means 1 (single item/currency looted); money has no amount field
        rowFrame._cells[6]:SetText(
            e.type ~= "money" and zLS:FormatNumber(e.amount or 1) or "")

        -- Col 7: Total — items treat 0 as 1 (bag count 0 means the timer didn't fire in time,
        -- but we know they have at least 1); currency uses live wallet quantity; money has none
        local totalVal
        if e.type == "item" then
            totalVal = math.max(e.total or 0, 1)
        elseif e.type == "currency" then
            totalVal = (e.quantity and e.quantity > 0) and e.quantity or nil
        end
        rowFrame._cells[7]:SetText(totalVal and zLS:FormatNumber(totalVal) or "")

        -- Col 8: Map (field removed in Phase 0k; always empty for new entries)
        rowFrame._cells[8]:SetText(e.mapName or "")

        -- Col 9: Zone
        rowFrame._cells[9]:SetText(e.zoneName or "")
    end

    -- ── Real RefreshTable ─────────────────────────────────────────────────────
    -- Replaces the forward-declared stub captured by BuildFilterBar closures.

    RefreshTable = function()
        -- 1. Collect all entries tagged with realm + character name.
        local rows = {}
        local g = zLS.db and zLS.db.global
        if g and g.chars then
            for realm, chars in pairs(g.chars) do
                for charName, data in pairs(chars) do
                    if data.lootLog then
                        for _, e in ipairs(data.lootLog) do
                            rows[#rows+1] = { entry = e, realm = realm, char = charName }
                        end
                    end
                end
            end
        end
        rawTotal = #rows

        -- 2. Filter (cheap guards first).
        filteredCache = {}
        for _, row in ipairs(rows) do
            local e = row.entry
            if PassesDateFilter(e, filters.dateStart, filters.dateEnd)
            and (not filters.server    or row.realm == filters.server)
            and (not filters.character or row.char  == filters.character)
            and (not filters.zone      or e.zoneName == filters.zone)
            and PassesQualityFilter(e, filters.quality)
            and PassesMoneyFilter(e, filters.money)
            and PassesCurrencyFilter(e, filters.currency)
            and PassesSearch(e, row.realm, row.char, filters.search)
            then
                filteredCache[#filteredCache+1] = row
            end
        end

        -- 3. Sort.
        table.sort(filteredCache, MakeSortComparator(sortCol, sortDir))

        -- 4. Update sort-arrow visibility and direction.
        for i = 1, #COLS do
            if i == sortCol then
                -- Rotate arrow to reflect current direction.
                sortArrows[i].normalTex:SetRotation(
                    sortDir == -1 and (math.pi / 2) or (-math.pi / 2))
                sortArrows[i]:Show()
            else
                sortArrows[i]:Hide()
            end
        end

        -- 5. Reset to page 1 and render.
        currentPage = 1
        RenderPage(1)
    end

    RenderPage = function(page)
        local total      = #filteredCache
        local totalPages = math.max(1, math.ceil(total / PAGE_SIZE))
        currentPage      = math.max(1, math.min(page, totalPages))
        local startIdx   = (currentPage - 1) * PAGE_SIZE + 1

        -- Render the page slice; hide unused row frames.
        for i = 1, PAGE_SIZE do
            local rowFrame = rowFrames[i]
            local row = filteredCache[startIdx + i - 1]
            if row then
                PopulateRow(rowFrame, row)
                rowFrame:Show()
            else
                rowFrame:Hide()
            end
        end

        -- Resize content to the visible rows and reset scroll.
        local visCount = math.min(total - startIdx + 1, PAGE_SIZE)
        content:SetHeight(math.max(visCount * ROW_H, 1))
        sf:SetVerticalScroll(0)

        UpdateNotice(total)
        UpdatePageControls(currentPage, totalPages, startIdx, startIdx + visCount - 1, total, rawTotal)
    end
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
