-- Events.lua

-- Convert WoW's global currency format strings into Lua match patterns.
-- CURRENCY_GAINED / CURRENCY_GAINED_MULTIPLE are locale-specific, so we
-- build the patterns at load time rather than hard-coding English strings.
local currencyPatternSingle   = CURRENCY_GAINED:gsub("%%s", "(.+)")
local currencyPatternMultiple = CURRENCY_GAINED_MULTIPLE
    :gsub("%%s",  "(.+)")
    :gsub("%%d",  "(%%d+)")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function BuildIconPrefix(texture, size)
    if not texture then return "" end
    return "|T" .. texture .. ":" .. size .. ":" .. size .. "|t "
end

local function QualityColor(quality)
    local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qc then
        return qc.r, qc.g, qc.b
    end
    return 1, 1, 1
end

---@param c number[] RGB table {r, g, b} in [0,1]
---@return string hex six-character lowercase hex
local function RGBToHex(c)
    return string.format("%02x%02x%02x", math.floor(c[1]*255), math.floor(c[2]*255), math.floor(c[3]*255))
end

---@return string formatted [HH:MM:SS] time derived from a unix timestamp
---@param t number unix timestamp
local function FormatEntryTimestamp(t)
    if not zLS:Get("showTimestamp") or not t then return "" end
    local h = tonumber(date("%H", t))
    local m = date("%M", t)
    local s = date("%S", t)
    if not zLS:Get("timestamp24hr") then
        h = h % 12
        if h == 0 then h = 12 end
    end
    return "|cff" .. RGBToHex(zLS:Get("colorTimestamp")) .. "[" .. string.format("%02d", h) .. ":" .. m .. ":" .. s .. "]|r "
end

-- ── Entry renderers ────────────────────────────────────────────────────────────
-- These are called both for live display and for RedrawFeed() replays.

---@param entry table logged item entry
---@return string|nil text, number r, number g, number b
local function RenderItemEntry(entry)
    if not zLS:Get("showItems") then return nil end

    -- Per-quality-tier display filter. Nil quality (e.g. battlepets) always passes.
    local q = entry.quality
    if q == 0 and not zLS:Get("showPoor")     then return nil end
    if q == 1 and not zLS:Get("showCommon")   then return nil end
    if q == 2 and not zLS:Get("showUncommon") then return nil end
    if q == 3 and not zLS:Get("showRare")     then return nil end
    if q == 4 and not zLS:Get("showEpic")     then return nil end
    if (q == 5 or q == 6) and not zLS:Get("showLegendary") then return nil end

    local r, g, b
    if entry.linkType == "battlepet" then
        r, g, b = 0, 1, 1
    elseif q then
        r, g, b = QualityColor(q)
    else
        r, g, b = 1, 1, 1
    end
    if not zLS:Get("colorByQuality") then r, g, b = 1, 1, 1 end

    local prefix = ""
    if zLS:Get("showItemIcon") and entry.texture then
        prefix = BuildIconPrefix(entry.texture, zLS:Get("iconSize"))
    end

    local displayName = entry.itemName or "Unknown"
    local ilvlPrefix  = ""
    if zLS:Get("showItemLevel") and entry.linkType ~= "battlepet" and entry.ilvl and entry.ilvl > 0 then
        ilvlPrefix = entry.ilvl .. "-"
    end

    local nameStr = "|H" .. entry.itemLink .. "|h|cff" ..
        string.format("%02x%02x%02x", math.floor(r*255), math.floor(g*255), math.floor(b*255)) ..
        "[" .. ilvlPrefix .. displayName .. "]|r|h"

    local countStr = (entry.amount and entry.amount > 1)
        and ("+|cff" .. RGBToHex(zLS:Get("colorIncrement")) .. entry.amount .. "|r")
        or nil

    local timePart = FormatEntryTimestamp(entry.t)

    local line
    if countStr then
        if zLS:Get("amountFirst") then
            line = timePart .. prefix .. countStr .. " " .. nameStr
        else
            line = timePart .. prefix .. nameStr .. " " .. countStr
        end
    else
        line = timePart .. prefix .. nameStr
    end

    if zLS:Get("showItemTotals") and entry.total and entry.total > 1 then
        line = line .. "  |cff" .. RGBToHex(zLS:Get("colorCount")) .. "(" .. entry.total .. ")|r"
    end

    return line, r, g, b
end

---@param entry table logged currency entry
---@return string|nil text, number r, number g, number b
local function RenderCurrencyEntry(entry)
    if not zLS:Get("showCurrency") then return nil end

    local r, g, b = QualityColor(entry.quality or 1)
    if not zLS:Get("colorByQuality") then r, g, b = 1, 1, 1 end

    local timePart = FormatEntryTimestamp(entry.t)

    local prefix = ""
    if zLS:Get("showItemIcon") and entry.iconFileID then
        prefix = BuildIconPrefix(entry.iconFileID, zLS:Get("iconSize"))
    end

    local hexColor = string.format("%02x%02x%02x", math.floor(r*255), math.floor(g*255), math.floor(b*255))
    local nameStr
    if entry.currencyID then
        nameStr = "|Hcurrency:" .. entry.currencyID .. "|h|cff" .. hexColor .. (entry.name or "") .. "|r|h"
    else
        nameStr = "|cff" .. hexColor .. (entry.name or "") .. "|r"
    end

    local countStr = entry.amount and ("+|cff" .. RGBToHex(zLS:Get("colorIncrement")) .. entry.amount .. "|r") or nil
    local totalStr = (entry.quantity and entry.quantity > 0)
        and ("  |cff" .. RGBToHex(zLS:Get("colorCount")) .. "(" .. entry.quantity .. ")|r")
        or ""

    local line
    if countStr then
        if zLS:Get("amountFirst") then
            line = timePart .. prefix .. countStr .. " " .. nameStr
        else
            line = timePart .. prefix .. nameStr .. " " .. countStr
        end
    else
        line = timePart .. prefix .. nameStr
    end
    line = line .. totalStr

    return line, r, g, b
end

---@param entry table logged money entry
---@return string|nil text, number r, number g, number b
local function RenderMoneyEntry(entry)
    if not zLS:Get("showMoney") then return nil end
    local mc       = zLS:Get("colorMoney")
    local timePart = FormatEntryTimestamp(entry.t)
    local formatted = C_CurrencyInfo.GetCoinTextureString(entry.totalCopper)
    return timePart .. "+" .. formatted, mc[1], mc[2], mc[3]
end

---Dispatch to the correct renderer. Called by RedrawFeed in LootFrame.lua.
---@param entry table
---@return string|nil text, number r, number g, number b
function zLS:RenderEntry(entry)
    if entry.type == "item" then
        return RenderItemEntry(entry)
    elseif entry.type == "currency" then
        return RenderCurrencyEntry(entry)
    elseif entry.type == "money" then
        return RenderMoneyEntry(entry)
    end
end

-- ── CHAT_MSG_LOOT ──────────────────────────────────────────────────────────────

local function HandleLoot(msg)
    -- Extract item link from the message (|Hitem:...|h[Name]|h)
    local itemLink = msg:match("|H(item:[^|]+)|h%[([^%]]+)%]|h")
    local itemName = msg:match("|H[^|]+|h%[([^%]]+)%]|h")
    if not itemLink then
        -- Battlepet link
        itemLink = msg:match("|H(battlepet:[^|]+)|h%[([^%]]+)%]|h")
        itemName = msg:match("|H[^|]+|h%[([^%]]+)%]|h")
    end
    if not itemLink then return end

    -- Amount (looting a stack)
    local amount = msg:match("x(%d+)%s*$") or msg:match("%((%d+)%)")
    amount = tonumber(amount)

    -- Parse link type and ID
    local linkType, linkID = strsplit(":", itemLink)
    linkID = tonumber(linkID)

    local texture, ilvl, quality

    if linkType == "battlepet" then
        -- Battlepets: quality nil (teal color applied at render time via linkType check)
    else
        local _, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemLink)
        if itemQuality then
            quality = itemQuality
            texture = itemTexture
        else
            -- Cache miss: use GetItemInfoInstant for icon only
            local _, _, instantQuality, _, _, _, _, instantTexture = C_Item.GetItemInfoInstant(itemLink)
            texture = instantTexture
            quality = instantQuality
        end
        -- Always attempt to resolve ilvl so it can be used on redraw even if
        -- showItemLevel was off at the time of loot.
        local displayName = itemName or "Unknown"
        local lvl = C_Item.GetDetailedItemLevelInfo("|H" .. itemLink .. "|h[" .. displayName .. "]|h")
        if lvl and lvl > 0 then ilvl = lvl end
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local entry = {
        t        = time(),
        type     = "item",
        itemLink = itemLink,
        itemName = itemName,
        amount   = amount,
        ilvl     = ilvl,
        texture  = texture,
        total    = 0,
        linkType = linkType,
        quality  = quality,
        mapID    = mapID or 0,
        zoneName = GetRealZoneText() or "",
    }
    zLS:LogEntry(entry)

    if linkID and linkType ~= "battlepet" then
        -- Always fetch and store the total so it's available for redraws, regardless of the setting.
        C_Timer.After(0.5, function()
            entry.total = C_Item.GetItemCount(itemLink, false, false, true) or 0
            if zLS:Get("showItemTotals") then
                -- Re-render the live message once the total is ready.
                local text, er, eg, eb = RenderItemEntry(entry)
                if text then zLS:AddMessage(text, er, eg, eb) end
            end
        end)
        -- If totals are off, show immediately without waiting for the timer.
        if not zLS:Get("showItemTotals") then
            local text, er, eg, eb = RenderItemEntry(entry)
            if text then zLS:AddMessage(text, er, eg, eb) end
        end
    else
        local text, er, eg, eb = RenderItemEntry(entry)
        if text then zLS:AddMessage(text, er, eg, eb) end
    end
end

-- ── CHAT_MSG_CURRENCY ──────────────────────────────────────────────────────────

local function HandleCurrency(msg)
    local currencyLink, amount

    -- Try multiple-amount pattern first
    local a, b2 = msg:match(currencyPatternMultiple)
    if a and b2 then
        -- Determine which capture is numeric
        if tonumber(a) then
            amount = tonumber(a)
            currencyLink = b2
        else
            currencyLink = a
            amount = tonumber(b2)
        end
    else
        currencyLink = msg:match(currencyPatternSingle)
        amount = nil
    end

    if not currencyLink then return end

    local info = C_CurrencyInfo.GetCurrencyInfoFromLink(currencyLink)
    if not info then return end

    local currencyID = currencyLink and tonumber(currencyLink:match("currency:(%d+)"))
    local mapID      = C_Map.GetBestMapForUnit("player")
    local entry = {
        t          = time(),
        type       = "currency",
        name       = info.name,
        amount     = amount,
        quantity   = info.quantity,
        iconFileID = info.iconFileID,
        quality    = info.quality or 1,
        currencyID = currencyID,
        mapID      = mapID or 0,
        zoneName   = GetRealZoneText() or "",
    }
    zLS:LogEntry(entry)

    local text, er, eg, eb = RenderCurrencyEntry(entry)
    if text then zLS:AddMessage(text, er, eg, eb) end
end

-- ── CHAT_MSG_MONEY ────────────────────────────────────────────────────────────

local function ParseMoneyAmount(msg, globalFmt)
    if not globalFmt then return 0 end
    local pat = globalFmt:gsub("%%d", "(%%d+)"):gsub("%%s", ".+")
    local n = msg:match(pat)
    return tonumber(n) or 0
end

local function HandleMoney(msg)
    local gold   = ParseMoneyAmount(msg, GOLD_AMOUNT)
    local silver = ParseMoneyAmount(msg, SILVER_AMOUNT)
    local copper = ParseMoneyAmount(msg, COPPER_AMOUNT)
    local totalCopper = (gold * 10000) + (silver * 100) + copper
    if totalCopper <= 0 then return end

    local mapID = C_Map.GetBestMapForUnit("player")
    local entry = {
        t           = time(),
        type        = "money",
        totalCopper = totalCopper,
        mapID       = mapID or 0,
        zoneName    = GetRealZoneText() or "",
    }
    zLS:LogEntry(entry)

    local text, er, eg, eb = RenderMoneyEntry(entry)
    if text then zLS:AddMessage(text, er, eg, eb) end
end

-- ── Event registration ────────────────────────────────────────────────────────

function zLS:RegisterEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_LOOT")
    eventFrame:RegisterEvent("CHAT_MSG_MONEY")
    eventFrame:RegisterEvent("CHAT_MSG_CURRENCY")
    eventFrame:SetScript("OnEvent", function(_, event, msg)
        if event == "CHAT_MSG_LOOT" then
            HandleLoot(msg)
        elseif event == "CHAT_MSG_MONEY" then
            HandleMoney(msg)
        elseif event == "CHAT_MSG_CURRENCY" then
            HandleCurrency(msg)
        end
    end)
    self._eventFrame = eventFrame
end
