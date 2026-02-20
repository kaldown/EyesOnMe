-- EyesOnMe: Settings panel, minimap button, slash command
local ADDON_NAME, EyesOnMe = ...

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

--------------------------------------------------------------
-- Minimap button (LibDataBroker + LibDBIcon)
--------------------------------------------------------------

local dataObject = LDB:NewDataObject("EyesOnMe", {
    type = "launcher",
    icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
    OnClick = function(self, button)
        if button == "LeftButton" then
            EyesOnMe:Toggle()
            local status = EyesOnMe:IsAddonEnabled()
                and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
            print("|cFFCC3333[EyesOnMe]|r " .. status)
            -- Re-trigger LibDBIcon's OnEnter to refresh tooltip with new state
            local onEnter = self:GetScript("OnEnter")
            if onEnter then
                onEnter(self)
            end
        elseif button == "RightButton" then
            EyesOnMe:ToggleSettings()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("EyesOnMe", 0.8, 0.2, 0.2)
        tooltip:AddLine(" ")
        local status = EyesOnMe:IsAddonEnabled()
            and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
        tooltip:AddLine("Status: " .. status, 1, 1, 1)
        local count = EyesOnMe:GetThreatCount()
        if count > 0 then
            tooltip:AddLine("Threats: |cFFFF3333" .. count .. "|r", 1, 1, 1)
        end
        local friendlyCount = EyesOnMe:GetFriendlyCount()
        if friendlyCount > 0 then
            tooltip:AddLine("Friendlies: |cFF33CCDD" .. friendlyCount .. "|r", 1, 1, 1)
        end
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFFFFFFFFLeft-click:|r Toggle ON/OFF", 0.7, 0.7, 0.7)
        tooltip:AddLine("|cFFFFFFFFRight-click:|r Settings", 0.7, 0.7, 0.7)
    end,
})

--------------------------------------------------------------
-- Settings panel
--------------------------------------------------------------

local settingsFrame

local function CreateCheckbox(parent, label, dbKey, x, y, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.text:SetText(label)
    cb:SetChecked(EyesOnMeDB[dbKey])
    cb:SetScript("OnClick", function(self)
        EyesOnMeDB[dbKey] = self:GetChecked()
        if onChange then onChange(self:GetChecked()) end
        EyesOnMe:RefreshVisuals()
    end)
    return cb
end

local function CreateSlider(parent, label, dbKey, x, y, minVal, maxVal, step, formatFn)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(180)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(EyesOnMeDB[dbKey] or minVal)

    if not formatFn then
        formatFn = function(v) return math.floor(v * 100) .. "%" end
    end

    slider.Low:SetText(formatFn(minVal))
    slider.High:SetText(formatFn(maxVal))
    slider.Text:SetText(label .. ": " .. formatFn(EyesOnMeDB[dbKey] or minVal))
    slider:SetScript("OnValueChanged", function(self, value)
        EyesOnMeDB[dbKey] = value
        self.Text:SetText(label .. ": " .. formatFn(value))
        EyesOnMe:RefreshVisuals()
    end)
    return slider
end

local function CreateSettingsPanel()
    settingsFrame = CreateFrame("Frame", "EyesOnMeSettings", UIParent, "BackdropTemplate")
    settingsFrame:SetSize(280, 540)
    settingsFrame:SetPoint("CENTER")
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:SetMovable(true)
    settingsFrame:SetClampedToScreen(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:RegisterForDrag("LeftButton")
    settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
    settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
    settingsFrame:Hide()

    settingsFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    settingsFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    settingsFrame:SetBackdropBorderColor(0.6, 0.0, 0.0, 1)

    -- Title
    local title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("EyesOnMe Settings")
    title:SetTextColor(0.8, 0.2, 0.2)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- === Enemy Tracking Section ===
    local enemyHeader = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enemyHeader:SetPoint("TOPLEFT", 16, -38)
    enemyHeader:SetText("Enemy Tracking")
    enemyHeader:SetTextColor(1, 0.3, 0.3)

    local y = -55
    CreateCheckbox(settingsFrame, "Enable addon", "enabled", 16, y, function(checked)
        EyesOnMe:SetEnabled(checked)
    end)
    y = y - 30
    CreateCheckbox(settingsFrame, "Show nameplate badges", "showBadges", 16, y)
    y = y - 30
    CreateCheckbox(settingsFrame, "Show threat counter", "showCounter", 16, y)
    y = y - 30
    CreateCheckbox(settingsFrame, "Show red vignette", "showVignette", 16, y)
    y = y - 30
    CreateCheckbox(settingsFrame, "Sound alerts", "soundAlerts", 16, y)
    y = y - 30
    CreateCheckbox(settingsFrame, "Lock counter position", "lockCounter", 16, y)
    y = y - 30
    CreateCheckbox(settingsFrame, "Auto-show target list", "autoShowNameList", 16, y)
    y = y - 40

    -- Vignette intensity slider
    CreateSlider(settingsFrame, "Vignette intensity", "vignetteIntensity", 50, y, 0.1, 1.0, 0.05)
    y = y - 50

    -- === Friendly Tracking Section ===
    local friendlyHeader = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    friendlyHeader:SetPoint("TOPLEFT", 16, y)
    friendlyHeader:SetText("Friendly Tracking")
    friendlyHeader:SetTextColor(0.2, 0.8, 0.9)

    y = y - 17
    CreateCheckbox(settingsFrame, "Track friendly targeting", "friendlyEnabled", 16, y, function(checked)
        EyesOnMe:SetFriendlyEnabled(checked)
    end)
    y = y - 30
    CreateCheckbox(settingsFrame, "Show friendly badges", "showFriendlyBadges", 16, y)
    y = y - 30
    CreateCheckbox(settingsFrame, "Show friendly counter", "showFriendlyCounter", 16, y)
    y = y - 30
    CreateCheckbox(settingsFrame, "Lock friendly counter", "lockFriendlyCounter", 16, y)
    y = y - 30
    CreateCheckbox(settingsFrame, "Auto-show friendly list", "autoShowFriendlyNameList", 16, y)

    -- === Name List Section ===
    y = y - 20
    local listHeader = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", 16, y)
    listHeader:SetText("Name List")
    listHeader:SetTextColor(0.8, 0.8, 0.8)

    y = y - 27
    CreateSlider(settingsFrame, "Max names shown", "nameListSize", 50, y, 1, 10, 1,
        function(v) return tostring(math.floor(v)) end)

    tinsert(UISpecialFrames, "EyesOnMeSettings")
end

function EyesOnMe:ToggleSettings()
    if not settingsFrame then
        CreateSettingsPanel()
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end

--------------------------------------------------------------
-- Slash command
--------------------------------------------------------------

SLASH_EYESONME1 = "/eom"

SlashCmdList["EYESONME"] = function(msg)
    EyesOnMe:Toggle()
    local status = EyesOnMe:IsAddonEnabled()
        and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
    print("|cFFCC3333[EyesOnMe]|r " .. status)
end

--------------------------------------------------------------
-- Init (called from Core.lua ADDON_LOADED)
--------------------------------------------------------------

function EyesOnMe:InitSettings()
    LDBIcon:Register("EyesOnMe", dataObject, EyesOnMeDB.minimap)
end
