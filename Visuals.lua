-- EyesOnMe: Visual elements - nameplate badges, vignette, threat counter
local ADDON_NAME, EyesOnMe = ...

--------------------------------------------------------------
-- Nameplate badge pool
--------------------------------------------------------------

local BADGE_SIZE = 16
local GLOW_SIZE = 4
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
        GameTooltip:AddLine("Drag to move", 0.5, 0.5, 0.5)
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

    counterFrame:Hide() -- Hidden when count = 0
end

local function UpdateCounter(count)
    if not EyesOnMeDB.showCounter or not counterFrame then return end

    if count > 0 then
        counterFrame.text:SetText(count)
        counterFrame:Show()
    else
        counterFrame:Hide()
    end
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
end

--------------------------------------------------------------
-- Core callbacks (override stubs in Core.lua)
--------------------------------------------------------------

function EyesOnMe:OnTargeterAdded(unit, info)
    ShowBadge(unit)
end

function EyesOnMe:OnTargeterRemoved(unit, info)
    HideBadge(unit)
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
    end
end

function EyesOnMe:OnFriendlyAdded(unit, info)
    ShowFriendlyBadge(unit)
end

function EyesOnMe:OnFriendlyRemoved(unit, info)
    HideFriendlyBadge(unit)
end

function EyesOnMe:OnFriendlyEnabledChanged(enabled)
    if not enabled then
        HideAllFriendlyBadges()
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
end
