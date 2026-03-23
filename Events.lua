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

-- ── CHAT_MSG_LOOT ──────────────────────────────────────────────────────────────

local function HandleLoot(msg)
    if not zLS:Get("showItems") then return end

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

    -- Determine quality and icon
    local r, g, b = 1, 1, 1
    local texture

    if linkType == "battlepet" then
        -- Battlepets: use a fixed teal color; no easy icon retrieval without cache
        r, g, b = 0.0, 1.0, 1.0
    else
        local _, _, quality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemLink)
        if quality then
            r, g, b = QualityColor(quality)
            texture = itemTexture
        else
            -- Cache miss: use GetItemInfoInstant for icon only
            local _, _, instantQuality, _, _, _, _, instantTexture = C_Item.GetItemInfoInstant(itemLink)
            texture = instantTexture
            if instantQuality then
                r, g, b = QualityColor(instantQuality)
            end
        end
    end

    if not zLS:Get("colorByQuality") then
        r, g, b = 1, 1, 1
    end

    -- Build message
    local prefix = ""
    if zLS:Get("showItemIcon") and texture then
        prefix = BuildIconPrefix(texture, zLS:Get("iconSize"))
    end

    local displayName = itemName or "Unknown"

    local ilvlPrefix = ""
    if zLS:Get("showItemLevel") and linkType ~= "battlepet" then
        local ilvl = C_Item.GetDetailedItemLevelInfo("|H" .. itemLink .. "|h[" .. displayName .. "]|h")
        if ilvl and ilvl > 0 then
            ilvlPrefix = ilvl .. "-"
        end
    end

    local nameStr = "|H" .. itemLink .. "|h|cff" ..
        string.format("%02x%02x%02x", math.floor(r*255), math.floor(g*255), math.floor(b*255)) ..
        "[" .. ilvlPrefix .. displayName .. "]|r|h"
    local countStr = (amount and amount > 1) and ("+|cffffffff" .. amount .. "|r") or nil

    local line
    if countStr then
        if zLS:Get("amountFirst") then
            line = prefix .. countStr .. " " .. nameStr
        else
            line = prefix .. nameStr .. " " .. countStr
        end
    else
        line = prefix .. nameStr
    end

    if zLS:Get("showItemTotals") and linkID and linkType ~= "battlepet" then
        local capturedLine = line
        local capturedR, capturedG, capturedB = r, g, b
        C_Timer.After(0.5, function()
            local total = C_Item.GetItemCount(itemLink, false, false, true) or 0
            local totalStr = total > 1 and ("  |cffaaaaaa(" .. total .. ")|r") or ""
            zLS:AddMessage(capturedLine .. totalStr, capturedR, capturedG, capturedB)
        end)
    else
        zLS:AddMessage(line, r, g, b)
    end
end

-- ── CHAT_MSG_CURRENCY ──────────────────────────────────────────────────────────

local function HandleCurrency(msg)
    if not zLS:Get("showCurrency") then return end

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

    local r, g, b = QualityColor(info.quality or 1)

    if not zLS:Get("colorByQuality") then
        r, g, b = 1, 1, 1
    end

    local prefix = ""
    if zLS:Get("showItemIcon") and info.iconFileID then
        prefix = BuildIconPrefix(info.iconFileID, zLS:Get("iconSize"))
    end

    local nameStr = "|cff" ..
        string.format("%02x%02x%02x", math.floor(r*255), math.floor(g*255), math.floor(b*255)) ..
        (info.name or "") .. "|r"
    local countStr = amount and ("+|cffffffff" .. amount .. "|r") or nil
    local totalStr = info.quantity and ("  |cffaaaaaa(" .. info.quantity .. ")|r") or ""

    local line
    if countStr then
        if zLS:Get("amountFirst") then
            line = prefix .. countStr .. " " .. nameStr
        else
            line = prefix .. nameStr .. " " .. countStr
        end
    else
        line = prefix .. nameStr
    end
    line = line .. totalStr

    zLS:AddMessage(line, r, g, b)
end

-- ── CHAT_MSG_MONEY ────────────────────────────────────────────────────────────

local function ParseMoneyAmount(msg, globalFmt)
    if not globalFmt then return 0 end
    local pat = globalFmt:gsub("%%d", "(%%d+)"):gsub("%%s", ".+")
    local n = msg:match(pat)
    return tonumber(n) or 0
end

local function HandleMoney(msg)
    if not zLS:Get("showMoney") then return end

    local gold   = ParseMoneyAmount(msg, GOLD_AMOUNT)
    local silver = ParseMoneyAmount(msg, SILVER_AMOUNT)
    local copper = ParseMoneyAmount(msg, COPPER_AMOUNT)
    local totalCopper = (gold * 10000) + (silver * 100) + copper

    if totalCopper <= 0 then return end

    local formatted = C_CurrencyInfo.GetCoinTextureString(totalCopper)
    local mc = zLS:Get("colorMoney")
    zLS:AddMessage("+" .. formatted, mc[1], mc[2], mc[3])
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
