-- EyesOnMe: Visual elements - nameplate badges, vignette, threat counter
local ADDON_NAME, EyesOnMe = ...

--------------------------------------------------------------
-- Nameplate badge pool
--------------------------------------------------------------

local BADGE_SIZE = 16
local GLOW_SIZE = 4
local DROPDOWN_ROW_HEIGHT = 20
local DROPDOWN_PADDING = 4
local DROPDOWN_MAX_ROWS = 10
local CLICK_THRESHOLD = 5 -- pixels to differentiate click vs drag
local badges = {} -- [nameplate frame] = badge frame

local function CreateBadge(nameplate)
    local badge = CreateFrame("Frame", nil, nameplate)
    badge:SetSize(BADGE_SIZE + GLOW_SIZE * 2, BADGE_SIZE + GLOW_SIZE * 2)
    badge:SetPoint("BOTTOM", nameplate, "TOP", 0, 2)
    badge:SetFrameLevel(nameplate:GetFrameLevel() + 5)

    -- Circular glow background
    local glow = badge:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(BADGE_SIZE * 2.2, BADGE_SIZE * 2.2)
    glow:SetPoint("CENTER")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.8, 0.1, 0.1, 0.7)
    badge.glow = glow

    -- Eye icon
    local icon = badge:CreateTexture(nil, "ARTWORK")
    icon:SetSize(BADGE_SIZE, BADGE_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_EyeOfKilrogg")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    badge.icon = icon

    badge:Hide()
    return badge
end

local function GetOrCreateBadge(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return nil end

    if not badges[nameplate] then
        badges[nameplate] = CreateBadge(nameplate)
    end
    return badges[nameplate]
end

local function ShowBadge(unit)
    if not EyesOnMeDB.showBadges then return end
    local badge = GetOrCreateBadge(unit)
    if badge then
        badge:Show()
    end
end

local function HideBadge(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate and badges[nameplate] then
        badges[nameplate]:Hide()
    end
end

local function HideAllBadges()
    for _, badge in pairs(badges) do
        badge:Hide()
    end
end

--------------------------------------------------------------
-- Friendly nameplate badge pool
--------------------------------------------------------------

local friendlyBadges = {} -- [nameplate frame] = badge frame

local function CreateFriendlyBadge(nameplate)
    local badge = CreateFrame("Frame", nil, nameplate)
    badge:SetSize(BADGE_SIZE + GLOW_SIZE * 2, BADGE_SIZE + GLOW_SIZE * 2)
    badge:SetPoint("BOTTOM", nameplate, "TOP", 0, 2)
    badge:SetFrameLevel(nameplate:GetFrameLevel() + 5)

    -- Circular glow background (teal)
    local glow = badge:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(BADGE_SIZE * 2.2, BADGE_SIZE * 2.2)
    glow:SetPoint("CENTER")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.1, 0.6, 0.7, 0.7)
    badge.glow = glow

    -- Friendly icon
    local icon = badge:CreateTexture(nil, "ARTWORK")
    icon:SetSize(BADGE_SIZE, BADGE_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Spell_Holy_FlashHeal")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    badge.icon = icon

    badge:Hide()
    return badge
end

local function GetOrCreateFriendlyBadge(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return nil end

    if not friendlyBadges[nameplate] then
        friendlyBadges[nameplate] = CreateFriendlyBadge(nameplate)
    end
    return friendlyBadges[nameplate]
end

local function ShowFriendlyBadge(unit)
    if not unit or not EyesOnMeDB.showFriendlyBadges then return end
    local badge = GetOrCreateFriendlyBadge(unit)
    if badge then
        badge:Show()
    end
end

local function HideFriendlyBadge(unit)
    if not unit then return end
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate and friendlyBadges[nameplate] then
        friendlyBadges[nameplate]:Hide()
    end
end

local function HideAllFriendlyBadges()
    for _, badge in pairs(friendlyBadges) do
        badge:Hide()
    end
end

--------------------------------------------------------------
-- Red vignette overlay
--------------------------------------------------------------

local vignetteFrame
local vignetteTarget = 0
local vignetteCurrent = 0
local VIGNETTE_FADE_SPEED = 3.0 -- alpha units per second

local function CreateVignette()
    vignetteFrame = CreateFrame("Frame", "EyesOnMeVignette", UIParent)
    vignetteFrame:SetAllPoints(UIParent)
    vignetteFrame:SetFrameStrata("BACKGROUND")
    vignetteFrame:SetFrameLevel(0)
    vignetteFrame:EnableMouse(false)

    -- Four edge textures (top, bottom, left, right) with gradient
    local edgeSize = 128

    -- Top edge
    local top = vignetteFrame:CreateTexture(nil, "BACKGROUND")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(edgeSize)
    top:SetColorTexture(0.4, 0.0, 0.0, 1.0)
    top:SetGradient("VERTICAL", CreateColor(0.4, 0.0, 0.0, 0.0), CreateColor(0.4, 0.0, 0.0, 1.0))
    vignetteFrame.top = top

    -- Bottom edge
    local bottom = vignetteFrame:CreateTexture(nil, "BACKGROUND")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(edgeSize)
    bottom:SetColorTexture(0.4, 0.0, 0.0, 1.0)
    bottom:SetGradient("VERTICAL", CreateColor(0.4, 0.0, 0.0, 1.0), CreateColor(0.4, 0.0, 0.0, 0.0))
    vignetteFrame.bottom = bottom

    -- Left edge
    local left = vignetteFrame:CreateTexture(nil, "BACKGROUND")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(edgeSize)
    left:SetColorTexture(0.4, 0.0, 0.0, 1.0)
    left:SetGradient("HORIZONTAL", CreateColor(0.4, 0.0, 0.0, 1.0), CreateColor(0.4, 0.0, 0.0, 0.0))
    vignetteFrame.left = left

    -- Right edge
    local right = vignetteFrame:CreateTexture(nil, "BACKGROUND")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(edgeSize)
    right:SetColorTexture(0.4, 0.0, 0.0, 1.0)
    right:SetGradient("HORIZONTAL", CreateColor(0.4, 0.0, 0.0, 0.0), CreateColor(0.4, 0.0, 0.0, 1.0))
    vignetteFrame.right = right

    vignetteFrame:SetAlpha(0)
    vignetteFrame:Hide()

    -- Smooth fade OnUpdate
    vignetteFrame:SetScript("OnUpdate", function(self, elapsed)
        if math.abs(vignetteCurrent - vignetteTarget) < 0.01 then
            vignetteCurrent = vignetteTarget
            if vignetteCurrent <= 0 then
                self:Hide()
            end
        else
            local speed = VIGNETTE_FADE_SPEED * elapsed
            if vignetteCurrent < vignetteTarget then
                vignetteCurrent = math.min(vignetteCurrent + speed, vignetteTarget)
            else
                vignetteCurrent = math.max(vignetteCurrent - speed, vignetteTarget)
            end
        end
        self:SetAlpha(vignetteCurrent)
    end)
end

local function UpdateVignette(count)
    if not EyesOnMeDB.showVignette or not vignetteFrame then return end

    local intensity = EyesOnMeDB.vignetteIntensity or 1.0
    if count <= 0 then
        vignetteTarget = 0
    elseif count == 1 then
        vignetteTarget = 0.15 * intensity
    elseif count <= 3 then
        vignetteTarget = 0.3 * intensity
    else
        vignetteTarget = 0.5 * intensity
    end

    if vignetteTarget > 0 then
        vignetteFrame:Show()
    end
end

--------------------------------------------------------------
-- Clickable dropdown panel (shared factory)
--------------------------------------------------------------

local function CreateDropdownRow(parent, index)
    local row = CreateFrame("Button", parent:GetName() .. "Row" .. index,
        parent, "SecureActionButtonTemplate")
    row:SetHeight(DROPDOWN_ROW_HEIGHT)
    row:RegisterForClicks("AnyDown", "AnyUp")
    row:SetAttribute("type1", "macro")
    row:SetAttribute("macrotext", "/targetexact nil")

    -- Name text
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    row.text = text

    -- Hover highlight
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    row:Hide()
    return row
end

local function CreateDropdownPanel(parent, panelName, bgR, bgG, bgB, borderR, borderG, borderB)
    -- Parent to UIParent (not counter) to avoid secure taint propagation.
    -- SecureActionButtonTemplate children would make the counter frame protected,
    -- blocking Show/Hide during combat. Anchor still references the counter.
    local dropdown = CreateFrame("Frame", panelName, UIParent, "BackdropTemplate")
    dropdown:SetPoint("TOP", parent, "BOTTOM", 0, -2)
    dropdown:SetFrameStrata("DIALOG")
    dropdown:SetClampedToScreen(true)

    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dropdown:SetBackdropColor(bgR, bgG, bgB, 0.92)
    dropdown:SetBackdropBorderColor(borderR, borderG, borderB, 1)

    -- Pre-allocate button pool
    dropdown.rows = {}
    for i = 1, DROPDOWN_MAX_ROWS do
        local row = CreateDropdownRow(dropdown, i)
        row:SetPoint("TOPLEFT", DROPDOWN_PADDING, -(DROPDOWN_PADDING + (i - 1) * DROPDOWN_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", -DROPDOWN_PADDING, -(DROPDOWN_PADDING + (i - 1) * DROPDOWN_ROW_HEIGHT))
        dropdown.rows[i] = row
    end

    dropdown.anchorParent = parent -- store counter frame ref for width calc
    dropdown.activeCount = 0
    dropdown:Hide()

    return dropdown
end

--------------------------------------------------------------
-- Threat counter (floating, draggable)
--------------------------------------------------------------

local counterFrame

local function CreateCounter()
    counterFrame = CreateFrame("Frame", "EyesOnMeCounter", UIParent, "BackdropTemplate")
    counterFrame:SetSize(64, 32)
    counterFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    counterFrame:SetFrameStrata("HIGH")
    counterFrame:SetClampedToScreen(true)
    counterFrame:EnableMouse(true)
    counterFrame:SetMovable(true)

    counterFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    counterFrame:SetBackdropColor(0.15, 0.0, 0.0, 0.85)
    counterFrame:SetBackdropBorderColor(0.6, 0.0, 0.0, 1)

    -- Eye icon
    local icon = counterFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_EyeOfKilrogg")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    counterFrame.icon = icon

    -- Count text
    local text = counterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetTextColor(1, 0.2, 0.2)
    text:SetText("0")
    counterFrame.text = text

    -- Drag handling
    counterFrame:RegisterForDrag("LeftButton")
    counterFrame:SetScript("OnDragStart", function(self)
        if not EyesOnMeDB.lockCounter then
            self:StartMoving()
        end
    end)
    counterFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        EyesOnMeDB.counterPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    -- Click detection (differentiate from drag)
    local mouseDownX, mouseDownY
    counterFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            mouseDownX, mouseDownY = GetCursorPosition()
        end
    end)
    counterFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and mouseDownX then
            local x, y = GetCursorPosition()
            local dx = math.abs(x - mouseDownX)
            local dy = math.abs(y - mouseDownY)
            if dx < CLICK_THRESHOLD and dy < CLICK_THRESHOLD then
                -- It's a click, not a drag (dropdown toggle only out of combat)
                if self.dropdown and not InCombatLockdown() then
                    if self.dropdown:IsShown() then
                        self.dropdown:Hide()
                    else
                        EyesOnMe:RefreshEnemyDropdown()
                        self.dropdown:Show()
                    end
                end
            end
            mouseDownX, mouseDownY = nil, nil
        end
    end)

    -- Tooltip
    counterFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("EyesOnMe", 0.8, 0.2, 0.2)
        GameTooltip:AddLine(" ")
        local count = EyesOnMe:GetThreatCount()
        if count > 0 then
            GameTooltip:AddLine(count .. " enemy player(s) targeting you", 1, 0.3, 0.3)
            for _, info in pairs(EyesOnMe:GetTargeters()) do
                local color = RAID_CLASS_COLORS[info.class]
                if color then
                    GameTooltip:AddLine("  " .. info.name, color.r, color.g, color.b)
                else
                    GameTooltip:AddLine("  " .. info.name, 0.7, 0.7, 0.7)
                end
            end
        else
            GameTooltip:AddLine("No enemies targeting you", 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click for targets, drag to move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    counterFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Restore position
    if EyesOnMeDB.counterPos then
        local pos = EyesOnMeDB.counterPos
        counterFrame:ClearAllPoints()
        counterFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end

    -- Dropdown panel
    counterFrame.dropdown = CreateDropdownPanel(
        counterFrame, "EyesOnMeEnemyDropdown",
        0.15, 0.0, 0.0,   -- bg: dark red
        0.6, 0.0, 0.0     -- border: red
    )
    tinsert(UISpecialFrames, "EyesOnMeEnemyDropdown")

    -- PostClick: close dropdown after targeting (only out of combat to avoid taint)
    local enemyDropdown = counterFrame.dropdown
    for _, row in ipairs(enemyDropdown.rows) do
        row:HookScript("PostClick", function()
            if not InCombatLockdown() and enemyDropdown:IsShown() then
                enemyDropdown:Hide()
            end
        end)
    end

    -- Use SetAlpha instead of Show/Hide to avoid combat lockdown taint.
    -- The dropdown (containing SecureActionButtonTemplate rows) anchors to
    -- this counter, making Show()/Hide() protected during combat.
    counterFrame:Show()
    counterFrame:SetAlpha(0)
    counterFrame:EnableMouse(false)
end

local function UpdateCounter(count)
    if not counterFrame then return end
    if not EyesOnMeDB.showCounter or count <= 0 then
        if counterFrame.dropdown and not InCombatLockdown() then
            counterFrame.dropdown:Hide()
        end
        counterFrame:SetAlpha(0)
        if not InCombatLockdown() then
            counterFrame:EnableMouse(false)
        end
        return
    end
    counterFrame.text:SetText(count)
    counterFrame:SetAlpha(1)
    if not InCombatLockdown() then
        counterFrame:EnableMouse(true)
    end
end

--------------------------------------------------------------
-- Friendly counter (floating, draggable)
--------------------------------------------------------------

local friendlyCounterFrame

local function CreateFriendlyCounter()
    friendlyCounterFrame = CreateFrame("Frame", "EyesOnMeFriendlyCounter", UIParent, "BackdropTemplate")
    friendlyCounterFrame:SetSize(64, 32)
    friendlyCounterFrame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    friendlyCounterFrame:SetFrameStrata("HIGH")
    friendlyCounterFrame:SetClampedToScreen(true)
    friendlyCounterFrame:EnableMouse(true)
    friendlyCounterFrame:SetMovable(true)

    friendlyCounterFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    friendlyCounterFrame:SetBackdropColor(0.0, 0.1, 0.15, 0.85)
    friendlyCounterFrame:SetBackdropBorderColor(0.0, 0.4, 0.5, 1)

    -- Friendly icon
    local icon = friendlyCounterFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_FlashHeal")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    friendlyCounterFrame.icon = icon

    -- Count text
    local text = friendlyCounterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetTextColor(0.2, 0.8, 0.9)
    text:SetText("0")
    friendlyCounterFrame.text = text

    -- Drag handling
    friendlyCounterFrame:RegisterForDrag("LeftButton")
    friendlyCounterFrame:SetScript("OnDragStart", function(self)
        if not EyesOnMeDB.lockFriendlyCounter then
            self:StartMoving()
        end
    end)
    friendlyCounterFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        EyesOnMeDB.friendlyCounterPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    -- Click detection (differentiate from drag)
    local mouseDownX, mouseDownY
    friendlyCounterFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            mouseDownX, mouseDownY = GetCursorPosition()
        end
    end)
    friendlyCounterFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and mouseDownX then
            local x, y = GetCursorPosition()
            local dx = math.abs(x - mouseDownX)
            local dy = math.abs(y - mouseDownY)
            if dx < CLICK_THRESHOLD and dy < CLICK_THRESHOLD then
                if self.dropdown and not InCombatLockdown() then
                    if self.dropdown:IsShown() then
                        self.dropdown:Hide()
                    else
                        EyesOnMe:RefreshFriendlyDropdown()
                        self.dropdown:Show()
                    end
                end
            end
            mouseDownX, mouseDownY = nil, nil
        end
    end)

    -- Tooltip
    friendlyCounterFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("EyesOnMe - Friendly", 0.2, 0.8, 0.9)
        GameTooltip:AddLine(" ")
        local count = EyesOnMe:GetFriendlyCount()
        if count > 0 then
            GameTooltip:AddLine(count .. " friendly player(s) targeting you", 0.3, 0.9, 1.0)
            for _, info in pairs(EyesOnMe:GetFriendlyTargeters()) do
                local color = RAID_CLASS_COLORS[info.class]
                if color then
                    GameTooltip:AddLine("  " .. info.name, color.r, color.g, color.b)
                else
                    GameTooltip:AddLine("  " .. info.name, 0.7, 0.7, 0.7)
                end
            end
        else
            GameTooltip:AddLine("No friendlies targeting you", 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click for targets, drag to move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    friendlyCounterFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Restore position
    if EyesOnMeDB.friendlyCounterPos then
        local pos = EyesOnMeDB.friendlyCounterPos
        friendlyCounterFrame:ClearAllPoints()
        friendlyCounterFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end

    -- Dropdown panel
    friendlyCounterFrame.dropdown = CreateDropdownPanel(
        friendlyCounterFrame, "EyesOnMeFriendlyDropdown",
        0.0, 0.1, 0.15,   -- bg: dark teal
        0.0, 0.4, 0.5     -- border: teal
    )
    tinsert(UISpecialFrames, "EyesOnMeFriendlyDropdown")

    -- PostClick: close dropdown after targeting (only out of combat to avoid taint)
    local friendlyDropdown = friendlyCounterFrame.dropdown
    for _, row in ipairs(friendlyDropdown.rows) do
        row:HookScript("PostClick", function()
            if not InCombatLockdown() and friendlyDropdown:IsShown() then
                friendlyDropdown:Hide()
            end
        end)
    end

    friendlyCounterFrame:Show()
    friendlyCounterFrame:SetAlpha(0)
    friendlyCounterFrame:EnableMouse(false)
end

local function UpdateFriendlyCounter(count)
    if not friendlyCounterFrame then return end
    if not EyesOnMeDB.showFriendlyCounter or count <= 0 then
        if friendlyCounterFrame.dropdown and not InCombatLockdown() then
            friendlyCounterFrame.dropdown:Hide()
        end
        friendlyCounterFrame:SetAlpha(0)
        if not InCombatLockdown() then
            friendlyCounterFrame:EnableMouse(false)
        end
        return
    end
    friendlyCounterFrame.text:SetText(count)
    friendlyCounterFrame:SetAlpha(1)
    if not InCombatLockdown() then
        friendlyCounterFrame:EnableMouse(true)
    end
end

--------------------------------------------------------------
-- Dropdown entry refresh
--------------------------------------------------------------

local function PopulateDropdown(dropdown, entries)
    if InCombatLockdown() then return end
    -- entries = array of { name, class, unit }
    local count = math.min(#entries, DROPDOWN_MAX_ROWS)
    local maxWidth = 80 -- min width

    for i = 1, DROPDOWN_MAX_ROWS do
        local row = dropdown.rows[i]
        if i <= count then
            local entry = entries[i]
            local color = RAID_CLASS_COLORS[entry.class]
            if color then
                row.text:SetTextColor(color.r, color.g, color.b)
            else
                row.text:SetTextColor(0.7, 0.7, 0.7)
            end
            row.text:SetText(entry.name)

            -- Update secure macro (only out of combat)
            if not InCombatLockdown() then
                row:SetAttribute("macrotext", "/targetexact " .. entry.name)
            end

            row:Show()

            -- Track max width
            local textWidth = row.text:GetStringWidth() + 16
            if textWidth > maxWidth then
                maxWidth = textWidth
            end
        else
            row:Hide()
            if not InCombatLockdown() then
                row:SetAttribute("macrotext", "/targetexact nil")
            end
        end
    end

    dropdown.activeCount = count

    -- Resize dropdown to fit
    local totalHeight = DROPDOWN_PADDING * 2 + count * DROPDOWN_ROW_HEIGHT
    local totalWidth = maxWidth + DROPDOWN_PADDING * 2
    if count > 0 then
        local minWidth = dropdown.anchorParent and dropdown.anchorParent:GetWidth() or 80
        dropdown:SetSize(math.max(totalWidth, minWidth), totalHeight)
    end
end

function EyesOnMe:RefreshEnemyDropdown()
    if not counterFrame or not counterFrame.dropdown then return end
    local entries = {}
    for unit, info in pairs(self:GetTargeters()) do
        entries[#entries + 1] = {
            name = info.name,
            class = info.class,
            unit = unit, -- nameplate unit token
        }
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    PopulateDropdown(counterFrame.dropdown, entries)
end

function EyesOnMe:RefreshFriendlyDropdown()
    if not friendlyCounterFrame or not friendlyCounterFrame.dropdown then return end
    local entries = {}
    for _, info in pairs(self:GetFriendlyTargeters()) do
        local unit = info.nameplateUnit or info.groupUnit
        entries[#entries + 1] = {
            name = info.name,
            class = info.class,
            unit = unit,
        }
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    PopulateDropdown(friendlyCounterFrame.dropdown, entries)
end

--------------------------------------------------------------
-- Sound alerts
--------------------------------------------------------------

local ALERT_SOUND = SOUNDKIT.RAID_WARNING or 8959

local function PlayAlertSound()
    if EyesOnMeDB.soundAlerts then
        PlaySound(ALERT_SOUND, "Master")
    end
end

--------------------------------------------------------------
-- Init visuals (called from Core.lua ADDON_LOADED)
--------------------------------------------------------------

function EyesOnMe:InitVisuals()
    CreateVignette()
    CreateCounter()
    CreateFriendlyCounter()

    -- Tooltip hook: show "Target: YOU" on unit tooltips
    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
        local _, unitId = tooltip:GetUnit()
        if unitId and UnitExists(unitId) and UnitIsUnit(unitId .. "target", "player")
            and not UnitIsUnit(unitId, "player") then
            if UnitIsEnemy("player", unitId) then
                tooltip:AddLine("Target: YOU", 1, 0.2, 0.2)
            elseif UnitIsFriend("player", unitId) then
                tooltip:AddLine("Target: YOU", 0.2, 0.8, 0.9)
            end
            tooltip:Show()
        end
    end)
end

--------------------------------------------------------------
-- Core callbacks (override stubs in Core.lua)
--------------------------------------------------------------

function EyesOnMe:OnTargeterAdded(unit, info)
    ShowBadge(unit)
    if not InCombatLockdown()
        and counterFrame and counterFrame.dropdown and counterFrame.dropdown:IsShown() then
        self:RefreshEnemyDropdown()
    end
end

function EyesOnMe:OnTargeterRemoved(unit, info)
    HideBadge(unit)
    if not InCombatLockdown()
        and counterFrame and counterFrame.dropdown and counterFrame.dropdown:IsShown() then
        self:RefreshEnemyDropdown()
    end
end

function EyesOnMe:OnThreatCountChanged(oldCount, newCount)
    UpdateCounter(newCount)
    UpdateVignette(newCount)

    -- Sound alert: transition from 0 to 1+
    if oldCount == 0 and newCount > 0 then
        PlayAlertSound()
    end
end

function EyesOnMe:OnEnabledChanged(enabled)
    if not enabled then
        HideAllBadges()
        UpdateCounter(0)
        UpdateVignette(0)
        HideAllFriendlyBadges()
        UpdateFriendlyCounter(0)
    end
end

function EyesOnMe:OnFriendlyAdded(unit, info)
    ShowFriendlyBadge(unit)
    if not InCombatLockdown()
        and friendlyCounterFrame and friendlyCounterFrame.dropdown
        and friendlyCounterFrame.dropdown:IsShown() then
        self:RefreshFriendlyDropdown()
    end
end

function EyesOnMe:OnFriendlyRemoved(unit, info)
    HideFriendlyBadge(unit)
    if not InCombatLockdown()
        and friendlyCounterFrame and friendlyCounterFrame.dropdown
        and friendlyCounterFrame.dropdown:IsShown() then
        self:RefreshFriendlyDropdown()
    end
end

function EyesOnMe:OnFriendlyEnabledChanged(enabled)
    if not enabled then
        HideAllFriendlyBadges()
        UpdateFriendlyCounter(0)
    end
end

function EyesOnMe:OnFriendlyCountChanged(oldCount, newCount)
    UpdateFriendlyCounter(newCount)
end

function EyesOnMe:OnCombatEnd()
    -- Sync mouse state deferred from combat (EnableMouse is protected on tainted frames)
    if counterFrame then
        counterFrame:EnableMouse(counterFrame:GetAlpha() > 0)
    end
    if friendlyCounterFrame then
        friendlyCounterFrame:EnableMouse(friendlyCounterFrame:GetAlpha() > 0)
    end
    -- Refresh dropdown attributes that couldn't be updated during combat
    if not InCombatLockdown() then
        self:RefreshEnemyDropdown()
        self:RefreshFriendlyDropdown()
    end
end

function EyesOnMe:OnTargetersRefreshed()
    if InCombatLockdown() then return end
    if counterFrame and counterFrame.dropdown and counterFrame.dropdown:IsShown() then
        self:RefreshEnemyDropdown()
    end
    if friendlyCounterFrame and friendlyCounterFrame.dropdown
        and friendlyCounterFrame.dropdown:IsShown() then
        self:RefreshFriendlyDropdown()
    end
end

--------------------------------------------------------------
-- Refresh all visuals (for settings changes)
--------------------------------------------------------------

function EyesOnMe:RefreshVisuals()
    local count = self:GetThreatCount()
    UpdateCounter(count)
    UpdateVignette(count)

    -- Refresh enemy badges
    if EyesOnMeDB.showBadges then
        for unit in pairs(self:GetTargeters()) do
            ShowBadge(unit)
        end
    else
        HideAllBadges()
    end

    -- Refresh friendly badges
    if EyesOnMeDB.showFriendlyBadges then
        for _, info in pairs(self:GetFriendlyTargeters()) do
            if info.nameplateUnit then
                ShowFriendlyBadge(info.nameplateUnit)
            end
        end
    else
        HideAllFriendlyBadges()
    end

    -- Refresh friendly counter
    UpdateFriendlyCounter(self:GetFriendlyCount())
end
