-- EyesOnMe: Visual elements - nameplate badges, vignette, threat counter
local ADDON_NAME, EyesOnMe = ...

--------------------------------------------------------------
-- Nameplate badge pool
--------------------------------------------------------------

local BADGE_SIZE = 16
local GLOW_SIZE = 4
local NAMELIST_ROW_HEIGHT = 20
local NAMELIST_PADDING = 4
local NAMELIST_MAX_ROWS = 10
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
-- Name list panel (auto-visible, pre-allocated secure rows)
--------------------------------------------------------------

local function CreateNameListRow(parent, index)
    local row = CreateFrame("Button", parent:GetName() .. "Row" .. index,
        parent, "SecureActionButtonTemplate")
    row:SetHeight(NAMELIST_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", NAMELIST_PADDING, -(NAMELIST_PADDING + (index - 1) * NAMELIST_ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", -NAMELIST_PADDING, -(NAMELIST_PADDING + (index - 1) * NAMELIST_ROW_HEIGHT))
    row:RegisterForClicks("AnyDown", "AnyUp")
    row:SetAttribute("type1", "macro")
    row:SetAttribute("macrotext", "/targetexact nil")

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    row.text = text

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    -- PreClick syncs macrotext from Lua property before the secure action fires.
    -- This allows targeting even for names detected during combat, since
    -- SetAttribute from a hardware-click PreClick is allowed in Classic.
    row:SetScript("PreClick", function(self)
        local name = self.targetFullName
        if name and name ~= "" then
            self:SetAttribute("type1", "macro")
            self:SetAttribute("macrotext", "/targetexact " .. name)
        end
    end)

    row:Show()
    row:SetAlpha(0)
    return row
end

local function CreateNameListPanel(anchorParent, panelName, bgR, bgG, bgB, borderR, borderG, borderB)
    local panel = CreateFrame("Frame", panelName, UIParent, "BackdropTemplate")
    panel:SetPoint("TOP", anchorParent, "BOTTOM", 0, -2)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)

    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(bgR, bgG, bgB, 0.92)
    panel:SetBackdropBorderColor(borderR, borderG, borderB, 1)

    panel.rows = {}
    for i = 1, NAMELIST_MAX_ROWS do
        panel.rows[i] = CreateNameListRow(panel, i)
    end

    panel.anchorParent = anchorParent
    panel.activeCount = 0
    panel:Show()
    panel:SetAlpha(0)

    return panel
end

local function RefreshNameList(panel, entries, autoShowKey)
    if not panel or not EyesOnMeDB[autoShowKey] then
        if panel then panel:SetAlpha(0) end
        return
    end

    local maxVisible = math.floor((EyesOnMeDB.nameListSize or 5) + 0.5)
    local count = math.min(#entries, maxVisible, NAMELIST_MAX_ROWS)
    local maxWidth = 80

    for i = 1, NAMELIST_MAX_ROWS do
        local row = panel.rows[i]
        if i <= count then
            local entry = entries[i]
            local color = RAID_CLASS_COLORS[entry.class]
            if color then
                row.text:SetTextColor(color.r, color.g, color.b)
            else
                row.text:SetTextColor(0.7, 0.7, 0.7)
            end
            row.text:SetText(entry.name)
            row:SetAlpha(1)

            -- Always update Lua properties (combat-safe, just table fields)
            row.targetFullName = entry.fullName or entry.name

            if not InCombatLockdown() then
                local u = entry.unit
                if u and (u:find("^raid") or u:find("^party")) then
                    row:SetAttribute("type1", "target")
                    row:SetAttribute("unit", u)
                    row:SetAttribute("macrotext", "")
                else
                    row:SetAttribute("type1", "macro")
                    row:SetAttribute("unit", "")
                    row:SetAttribute("macrotext", "/targetexact " .. (entry.fullName or entry.name))
                end
            end

            local textWidth = row.text:GetStringWidth() + 16
            if textWidth > maxWidth then
                maxWidth = textWidth
            end
        else
            row.text:SetText("")
            row:SetAlpha(0)
            row.targetFullName = nil

            if not InCombatLockdown() then
                row:SetAttribute("type1", "macro")
                row:SetAttribute("unit", "")
                row:SetAttribute("macrotext", "/targetexact nil")
            end
        end
    end

    panel.activeCount = count

    if count > 0 then
        if not InCombatLockdown() then
            local totalHeight = NAMELIST_PADDING * 2 + count * NAMELIST_ROW_HEIGHT
            local totalWidth = maxWidth + NAMELIST_PADDING * 2
            local minWidth = panel.anchorParent and panel.anchorParent:GetWidth() or 80
            panel:SetSize(math.max(totalWidth, minWidth), totalHeight)
        end
        panel:SetAlpha(1)
    else
        panel:SetAlpha(0)
    end
end

local function BuildEnemyEntries()
    local entries = {}
    for unit, info in pairs(EyesOnMe:GetTargeters()) do
        entries[#entries + 1] = {
            name = info.name,
            fullName = info.fullName or info.name,
            class = info.class,
            unit = unit,
        }
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    return entries
end

local function BuildFriendlyEntries()
    local entries = {}
    for _, info in pairs(EyesOnMe:GetFriendlyTargeters()) do
        local unit = info.groupUnit or info.nameplateUnit
        entries[#entries + 1] = {
            name = info.name,
            fullName = info.fullName or info.name,
            class = info.class,
            unit = unit,
        }
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    return entries
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

    counterFrame:Show()
    counterFrame:SetAlpha(0)
    counterFrame:EnableMouse(false)

    -- Name list panel
    counterFrame.nameList = CreateNameListPanel(
        counterFrame, "EyesOnMeEnemyNameList",
        0.15, 0.0, 0.0,   -- bg: dark red
        0.6, 0.0, 0.0     -- border: red
    )
end

local function UpdateCounter(count)
    if not counterFrame then return end
    if not EyesOnMeDB.showCounter or count <= 0 then
        counterFrame:SetAlpha(0)
        if not InCombatLockdown() then
            counterFrame:EnableMouse(false)
        end
        if counterFrame.nameList then
            counterFrame.nameList:SetAlpha(0)
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
        GameTooltip:AddLine("Drag to move", 0.5, 0.5, 0.5)
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

    friendlyCounterFrame:Show()
    friendlyCounterFrame:SetAlpha(0)
    friendlyCounterFrame:EnableMouse(false)

    -- Name list panel
    friendlyCounterFrame.nameList = CreateNameListPanel(
        friendlyCounterFrame, "EyesOnMeFriendlyNameList",
        0.0, 0.1, 0.15,   -- bg: dark teal
        0.0, 0.4, 0.5     -- border: teal
    )
end

local function UpdateFriendlyCounter(count)
    if not friendlyCounterFrame then return end
    if not EyesOnMeDB.showFriendlyCounter or count <= 0 then
        friendlyCounterFrame:SetAlpha(0)
        if not InCombatLockdown() then
            friendlyCounterFrame:EnableMouse(false)
        end
        if friendlyCounterFrame.nameList then
            friendlyCounterFrame.nameList:SetAlpha(0)
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
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
    end
end

function EyesOnMe:OnTargeterRemoved(unit, info)
    HideBadge(unit)
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
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
        if counterFrame and counterFrame.nameList then
            counterFrame.nameList:SetAlpha(0)
        end
        if friendlyCounterFrame and friendlyCounterFrame.nameList then
            friendlyCounterFrame.nameList:SetAlpha(0)
        end
    end
end

function EyesOnMe:OnFriendlyAdded(unit, info)
    ShowFriendlyBadge(unit)
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
    end
end

function EyesOnMe:OnFriendlyRemoved(unit, info)
    HideFriendlyBadge(unit)
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
    end
end

function EyesOnMe:OnFriendlyEnabledChanged(enabled)
    if not enabled then
        HideAllFriendlyBadges()
        UpdateFriendlyCounter(0)
        if friendlyCounterFrame and friendlyCounterFrame.nameList then
            friendlyCounterFrame.nameList:SetAlpha(0)
        end
    end
end

function EyesOnMe:OnFriendlyCountChanged(oldCount, newCount)
    UpdateFriendlyCounter(newCount)
end

function EyesOnMe:OnCombatEnd()
    if counterFrame then
        counterFrame:EnableMouse(counterFrame:GetAlpha() > 0)
    end
    if friendlyCounterFrame then
        friendlyCounterFrame:EnableMouse(friendlyCounterFrame:GetAlpha() > 0)
    end
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
    end
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
    end
end

function EyesOnMe:OnTargetersRefreshed()
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
    end
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
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

    -- Refresh name lists
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
    end
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
    end
end
