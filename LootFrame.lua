-- LootFrame.lua

local LSM = LibStub("LibSharedMedia-3.0")

-- Keys that affect the visual appearance of the frame. When any of these
-- change via the store, ApplyFrameSettings is called automatically.
local FRAME_SETTINGS_KEYS = {
    frameWidth        = true,
    frameHeight       = true,
    maxMessages       = true,
    messageDuration   = true,
    lineSpacing       = true,
    fontSize          = true,
    insertMode        = true,
    showBackground    = true,
    bgAlpha           = true,
    fontFace          = true,
    fontOutline       = true,
    fontJustify       = true,
    fontShadow        = true,
    fontShadowColor   = true,
    fontShadowOffsetX = true,
    fontShadowOffsetY = true,
}

-- Keys that require a full message redraw when changed.
-- ApplyFrameSettings runs first (registered earlier) so frame state is current.
local REDRAW_KEYS = {
    maxMessages     = true,
    messageDuration = true,
    showTimestamp  = true,
    timestamp24hr  = true,
    colorTimestamp = true,
    colorCount     = true,
    colorIncrement = true,
    colorMoney     = true,
    colorByQuality = true,
    showItemIcon   = true,
    iconSize       = true,
    showItemLevel  = true,
    showItemTotals = true,
    amountFirst    = true,
    insertMode     = true,
    showItems      = true,
    showCurrency   = true,
    showMoney      = true,
    showPoor       = true,
    showCommon     = true,
    showUncommon   = true,
    showRare       = true,
    showEpic       = true,
    showLegendary  = true,
}

-- ── Frame construction ────────────────────────────────────────────────────────

function zLS:BuildFrame()
    local f = CreateFrame("ScrollingMessageFrame", "zLootScrollFrame", UIParent)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(false)
    f:SetInsertMode(self:Get("insertMode") == "TOP"
        and SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP
        or  SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM)

    local duration = self:Get("messageDuration")
    f:SetFading(duration > 0)
    f:SetFadeDuration(1.5)
    f:SetTimeVisible(duration)
    f:SetMaxLines(self:Get("maxMessages"))
    f:SetSpacing(self:Get("lineSpacing"))
    -- Font, shadow, and justify are applied by ApplyFrameSettings below.

    -- Semi-transparent background texture
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, self:Get("bgAlpha"))
    if not self:Get("showBackground") then bg:Hide() end
    f.bg = bg

    -- Drag overlay; mouse disabled by default, shown in move mode
    local drag = CreateFrame("Frame", nil, f)
    drag:SetAllPoints()
    drag:EnableMouse(false)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        zLS:SavePosition()
    end)

    -- Visible bounds indicator shown only while unlocked so users can see
    -- the frame area even when the background is disabled.
    local moveOverlay = drag:CreateTexture(nil, "BACKGROUND")
    moveOverlay:SetAllPoints()
    moveOverlay:SetColorTexture(0.2, 0.6, 1, 0.15)
    moveOverlay:Hide()
    drag.moveOverlay = moveOverlay

    f.drag = drag

    -- Hyperlink tooltips when the frame is locked (mouse handled by drag overlay otherwise)
    f:SetHyperlinksEnabled(true)
    f:SetScript("OnHyperlinkEnter", function(_, link)
        local currencyID = link:match("^currency:(%d+)$")
        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
        if currencyID then
            GameTooltip:SetCurrencyByID(tonumber(currencyID))
        else
            GameTooltip:SetHyperlink(link)
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnHyperlinkLeave", function()
        GameTooltip:Hide()
    end)

    -- Mouse-wheel scrolling
    f:EnableMouseWheel(false)
    drag:EnableMouseWheel(false)

    self.frame = f
    self:RestorePosition()
    self:ApplyFrameSettings()

    if not self:Get("enabled") then f:Hide() end

    -- ── Reactive subscriptions via zSignalReact ───────────────────────────────

    -- Re-apply all visual frame settings whenever any relevant key changes.
    self.store:RegisterEffectMap(FRAME_SETTINGS_KEYS, function()
        self:ApplyFrameSettings()
    end)

    -- Redraw all logged messages whenever any display-affecting key changes.
    -- Registered after FRAME_SETTINGS_KEYS so frame state is fresh before redraw.
    self.store:RegisterEffectMap(REDRAW_KEYS, function()
        self:RedrawFeed()
    end)

    -- Toggle frame visibility when "enabled" changes.
    self.store:Subscribe("enabled", function(value)
        if self.frame then
            if value then self.frame:Show() else self.frame:Hide() end
        end
    end)

    -- Toggle draggability when "lockFrame" changes.
    self.store:Subscribe("lockFrame", function(value)
        self:SetMovable(not value)
    end)
end

-- ── Apply all settings to existing frame ─────────────────────────────────────

function zLS:ApplyFrameSettings()
    local f = self.frame
    if not f then return end

    f:SetWidth(self:Get("frameWidth"))
    f:SetHeight(self:Get("frameHeight"))
    f:SetMaxLines(self:Get("maxMessages"))
    f:SetSpacing(self:Get("lineSpacing"))

    local fontPath = LSM:Fetch("font", self:Get("fontFace")) or "Fonts\\FRIZQT__.TTF"
    f:SetFont(fontPath, self:Get("fontSize"), self:Get("fontOutline"))
    f:SetJustifyH(self:Get("fontJustify"))

    local shadow = self:Get("fontShadow")
    if shadow then
        local sc = self:Get("fontShadowColor")
        f:SetShadowColor(sc[1], sc[2], sc[3], sc[4])
        f:SetShadowOffset(self:Get("fontShadowOffsetX"), self:Get("fontShadowOffsetY"))
    else
        f:SetShadowColor(0, 0, 0, 0)
        f:SetShadowOffset(0, 0)
    end

    local duration = self:Get("messageDuration")
    f:SetFading(duration > 0)
    f:SetTimeVisible(duration)
    f:SetInsertMode(self:Get("insertMode") == "TOP"
        and SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP
        or  SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM)

    f.bg:SetColorTexture(0, 0, 0, self:Get("bgAlpha"))
    if self:Get("showBackground") then f.bg:Show() else f.bg:Hide() end
end

-- ── Position persistence ──────────────────────────────────────────────────────

function zLS:SavePosition()
    local point, _, relPoint, x, y = self.frame:GetPoint()
    self._charDB.frame.point    = point
    self._charDB.frame.relPoint = relPoint
    self._charDB.frame.x        = x
    self._charDB.frame.y        = y
end

function zLS:RestorePosition()
    local pos = self._charDB.frame
    self.frame:ClearAllPoints()
    self.frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

-- ── Movable toggle ────────────────────────────────────────────────────────────

function zLS:SetMovable(enable)
    if not self.frame then return end
    if enable then
        -- Move mode: drag overlay owns the mouse; disable on the frame itself so
        -- the overlay receives all input (tooltips won't fire, which is acceptable).
        self.frame:EnableMouse(false)
        self.frame.drag:EnableMouse(true)
        self.frame.drag:EnableMouseWheel(true)
        self.frame:EnableMouseWheel(true)
        self.frame:SetScript("OnMouseWheel", function(_, delta)
            if delta > 0 then self.frame:ScrollUp() else self.frame:ScrollDown() end
        end)
        self.frame.drag.moveOverlay:Show()
    else
        -- Locked: enable motion only so hyperlink hover fires, but clicks fall through.
        self.frame:SetMouseMotionEnabled(true)
        self.frame:SetMouseClickEnabled(false)
        self.frame.drag:EnableMouse(false)
        self.frame.drag:EnableMouseWheel(false)
        self.frame:EnableMouseWheel(false)
        self.frame:SetScript("OnMouseWheel", nil)
        self.frame.drag.moveOverlay:Hide()
    end
end

-- ── Redraw feed from log ──────────────────────────────────────────────────────

---Clear the frame and re-render every log entry that is still within its fade
---window (or all entries when keepForever is on) using current settings.
function zLS:RedrawFeed()
    local f = self.frame
    if not f then return end
    f:Clear()

    local log = self.lootLog
    if not log or #log == 0 then return end

    local now         = time()
    local duration    = self:Get("messageDuration")

    for _, entry in ipairs(log) do
        -- duration == 0 means no fading; show everything in the log.
        -- Otherwise only show entries still within the fade window.
        local visible = duration == 0 or (now - entry.t) < duration
        if visible then
            -- RenderEntry is defined in Events.lua; safe to call at runtime.
            local text, r, g, b = self:RenderEntry(entry)
            if text then
                f:AddMessage(text, r or 1, g or 1, b or 1)
            end
        end
    end
end

-- ── AddMessage ────────────────────────────────────────────────────────────────

function zLS:AddMessage(text, r, g, b)
    if not self:Get("enabled") then return end
    if not self.frame then return end
    self.frame:AddMessage(text, r or 1, g or 1, b or 1)
end
