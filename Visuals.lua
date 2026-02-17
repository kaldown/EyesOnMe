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

    -- Red glow background
    local glow = badge:CreateTexture(nil, "BACKGROUND")
    glow:SetAllPoints()
    glow:SetColorTexture(0.8, 0.1, 0.1, 0.6)
    badge.glow = glow

    -- Eye icon
    local icon = badge:CreateTexture(nil, "ARTWORK")
    icon:SetSize(BADGE_SIZE, BADGE_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_EyeOfKilrogg")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    badge.icon = icon

    -- Border
    local border = badge:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.6, 0.0, 0.0, 0.8)
    badge.border = border

    -- Ensure icon draws on top of border
    icon:SetDrawLayer("ARTWORK", 1)
    border:SetDrawLayer("ARTWORK", 0)

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
