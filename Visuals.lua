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
