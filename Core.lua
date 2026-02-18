-- EyesOnMe: PvP awareness - detect enemy players targeting you
local ADDON_NAME, EyesOnMe = ...

local ADDON_PREFIX = "|cFFCC3333[EyesOnMe]|r "
local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = GetMetadata and GetMetadata(ADDON_NAME, "Version") or "dev"
if VERSION:find("^@") then VERSION = "dev" end

--------------------------------------------------------------
-- State
--------------------------------------------------------------

EyesOnMeDB = EyesOnMeDB or {}

local isEnabled = true
local targetingMe = {}   -- [unitToken] = { name, class, guid }
local threatCount = 0
local POLL_INTERVAL = 0.5
local pollElapsed = 0
local friendlyEnabled = true
local friendlyTargetingMe = {}  -- [guid] = { name, class, guid, nameplateUnit, groupUnit }
local friendlyCount = 0

--------------------------------------------------------------
-- Defaults
--------------------------------------------------------------

local defaults = {
    enabled = true,
    showBadges = true,
    showCounter = true,
    showVignette = true,
    soundAlerts = true,
    vignetteIntensity = 1.0,
    lockCounter = false,
    counterPos = nil,
    friendlyEnabled = true,
    showFriendlyBadges = true,
    showFriendlyCounter = true,
    lockFriendlyCounter = false,
    friendlyCounterPos = nil,
    minimap = { hide = false },
}

local function InitializeDB()
    for k, v in pairs(defaults) do
        if EyesOnMeDB[k] == nil then
            EyesOnMeDB[k] = v
        end
    end
end

--------------------------------------------------------------
-- Detection helpers
--------------------------------------------------------------

local function IsEnemyPlayer(unit)
    return UnitIsPlayer(unit) and UnitIsEnemy("player", unit)
end

local function IsTargetingMe(unit)
    return UnitIsUnit(unit .. "target", "player")
end

local function IsFriendlyPlayer(unit)
    return UnitIsPlayer(unit)
        and UnitIsFriend("player", unit)
        and not UnitIsUnit(unit, "player")
end

--------------------------------------------------------------
-- Core tracking
--------------------------------------------------------------

local function AddTargeter(unit)
    if targetingMe[unit] then return end -- already tracked

    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    local guid = UnitGUID(unit)

    targetingMe[unit] = {
        name = name or "Unknown",
        class = class or "UNKNOWN",
        guid = guid or "",
    }

    local oldCount = threatCount
    threatCount = threatCount + 1

    -- Notify visuals
    EyesOnMe:OnTargeterAdded(unit, targetingMe[unit])
    EyesOnMe:OnThreatCountChanged(oldCount, threatCount)
end

local function RemoveTargeter(unit)
    if not targetingMe[unit] then return end

    local info = targetingMe[unit]
    targetingMe[unit] = nil

    local oldCount = threatCount
    threatCount = threatCount - 1

    -- Notify visuals
    EyesOnMe:OnTargeterRemoved(unit, info)
    EyesOnMe:OnThreatCountChanged(oldCount, threatCount)
end

--------------------------------------------------------------
-- Friendly tracking (GUID-keyed to avoid duplicates)
--------------------------------------------------------------

local function IsGroupUnit(unit)
    return unit and (unit:find("^party") or unit:find("^raid")) and true or false
end

local function AddFriendly(guid, unit, nameplateUnit)
    if friendlyTargetingMe[guid] then
        -- Update nameplate unit if we now have one
        if nameplateUnit then
            friendlyTargetingMe[guid].nameplateUnit = nameplateUnit
        end
        -- Update group unit if this is a party/raid token
        if IsGroupUnit(unit) then
            friendlyTargetingMe[guid].groupUnit = unit
        end
        return
    end

    local name = UnitName(unit)
    local _, class = UnitClass(unit)

    friendlyTargetingMe[guid] = {
        name = name or "Unknown",
        class = class or "UNKNOWN",
        guid = guid,
        nameplateUnit = nameplateUnit,
        groupUnit = IsGroupUnit(unit) and unit or nil,
    }

    local oldCount = friendlyCount
    friendlyCount = friendlyCount + 1

    EyesOnMe:OnFriendlyAdded(nameplateUnit or unit, friendlyTargetingMe[guid])
    EyesOnMe:OnFriendlyCountChanged(oldCount, friendlyCount)
end

local function RemoveFriendly(guid)
    if not friendlyTargetingMe[guid] then return end

    local info = friendlyTargetingMe[guid]
    friendlyTargetingMe[guid] = nil

    local oldCount = friendlyCount
    friendlyCount = friendlyCount - 1

    EyesOnMe:OnFriendlyRemoved(info.nameplateUnit, info)
    EyesOnMe:OnFriendlyCountChanged(oldCount, friendlyCount)
end

local function CheckUnit(unit)
    if not isEnabled then return end
    if not UnitExists(unit) then
        RemoveTargeter(unit)
        return
    end
    if IsEnemyPlayer(unit) and IsTargetingMe(unit) then
        AddTargeter(unit)
    else
        RemoveTargeter(unit)
    end
end

local function FullScan()
    if not isEnabled then return end
    local nameplates = C_NamePlate.GetNamePlates()
    if not nameplates then return end

    -- Track which units we see this scan
    local seen = {}
    local friendlySeenGuids = {}

    for _, nameplate in ipairs(nameplates) do
        local unit = nameplate.namePlateUnitToken
        if unit then
            -- Enemy check (existing)
            seen[unit] = true
            CheckUnit(unit)

            -- Friendly check (new)
            if friendlyEnabled and IsFriendlyPlayer(unit)
                and IsTargetingMe(unit) then
                local guid = UnitGUID(unit)
                if guid then
                    friendlySeenGuids[guid] = true
                    AddFriendly(guid, unit, unit)
                end
            end
        end
    end

    -- Group unit scan (catches members beyond nameplate range)
    if friendlyEnabled then
        local prefix, count
        if IsInRaid() then
            prefix, count = "raid", GetNumGroupMembers()
        elseif IsInGroup() then
            prefix, count = "party", GetNumSubgroupMembers()
        end
        if prefix then
            for i = 1, count do
                local unit = prefix .. i
                if UnitExists(unit) and not UnitIsUnit(unit, "player")
                    and UnitIsUnit(unit .. "target", "player") then
                    local guid = UnitGUID(unit)
                    if guid and not friendlySeenGuids[guid] then
                        friendlySeenGuids[guid] = true
                        AddFriendly(guid, unit, nil)
                    end
                end
            end
        end
    end

    -- Remove stale enemy entries
    for unit in pairs(targetingMe) do
        if not seen[unit] then
            RemoveTargeter(unit)
        end
    end

    -- Remove stale friendly entries
    for guid in pairs(friendlyTargetingMe) do
        if not friendlySeenGuids[guid] then
            RemoveFriendly(guid)
        end
    end

    EyesOnMe:OnTargetersRefreshed()
end

local function ResetAll()
    for unit in pairs(targetingMe) do
        RemoveTargeter(unit)
    end
    wipe(targetingMe)
    local oldCount = threatCount
    threatCount = 0
    if oldCount ~= 0 then
        EyesOnMe:OnThreatCountChanged(oldCount, 0)
    end

    for guid in pairs(friendlyTargetingMe) do
        RemoveFriendly(guid)
    end
    wipe(friendlyTargetingMe)
    local oldFriendly = friendlyCount
    friendlyCount = 0
    if oldFriendly ~= 0 then
        EyesOnMe:OnFriendlyCountChanged(oldFriendly, 0)
    end
end

--------------------------------------------------------------
-- Public API (for Visuals/Settings)
--------------------------------------------------------------

function EyesOnMe:GetThreatCount()
    return threatCount
end

function EyesOnMe:GetTargeters()
    return targetingMe
end

function EyesOnMe:IsAddonEnabled()
    return isEnabled
end

function EyesOnMe:SetEnabled(enabled)
    isEnabled = enabled
    EyesOnMeDB.enabled = enabled
    if enabled then
        FullScan()
    else
        ResetAll()
    end
    EyesOnMe:OnEnabledChanged(enabled)
end

function EyesOnMe:Toggle()
    self:SetEnabled(not isEnabled)
end

function EyesOnMe:GetFriendlyCount()
    return friendlyCount
end

function EyesOnMe:GetFriendlyTargeters()
    return friendlyTargetingMe
end

function EyesOnMe:IsFriendlyTrackingEnabled()
    return friendlyEnabled
end

function EyesOnMe:SetFriendlyEnabled(enabled)
    friendlyEnabled = enabled
    EyesOnMeDB.friendlyEnabled = enabled
    if not enabled then
        for guid in pairs(friendlyTargetingMe) do
            RemoveFriendly(guid)
        end
        wipe(friendlyTargetingMe)
        local oldCount = friendlyCount
        friendlyCount = 0
        if oldCount ~= 0 then
            EyesOnMe:OnFriendlyCountChanged(oldCount, 0)
        end
    end
    EyesOnMe:OnFriendlyEnabledChanged(enabled)
end

--------------------------------------------------------------
-- Event visual stubs (overridden by Visuals.lua)
--------------------------------------------------------------

function EyesOnMe:OnTargeterAdded(unit, info) end
function EyesOnMe:OnTargeterRemoved(unit, info) end
function EyesOnMe:OnThreatCountChanged(oldCount, newCount) end
function EyesOnMe:OnEnabledChanged(enabled) end
function EyesOnMe:OnFriendlyAdded(unit, info) end
function EyesOnMe:OnFriendlyRemoved(unit, info) end
function EyesOnMe:OnFriendlyCountChanged(oldCount, newCount) end
function EyesOnMe:OnFriendlyEnabledChanged(enabled) end
function EyesOnMe:OnCombatEnd() end
function EyesOnMe:OnTargetersRefreshed() end

--------------------------------------------------------------
-- Event frame
--------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("UNIT_TARGET")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitializeDB()
        isEnabled = EyesOnMeDB.enabled
        friendlyEnabled = EyesOnMeDB.friendlyEnabled
        EyesOnMe:InitVisuals()
        EyesOnMe:InitSettings()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        local status = isEnabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
        print(ADDON_PREFIX .. "v" .. VERSION .. " loaded (" .. status .. ")")
        if isEnabled then
            FullScan()
        end
        self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if isEnabled and arg1 then
            CheckUnit(arg1)
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if arg1 then
            RemoveTargeter(arg1)
        end

    elseif event == "UNIT_TARGET" then
        if isEnabled and arg1 and arg1:find("^nameplate") then
            CheckUnit(arg1)
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if isEnabled then
            FullScan()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        EyesOnMe:OnCombatEnd()

    elseif event == "PLAYER_ENTERING_WORLD" then
        ResetAll()
        if isEnabled then
            C_Timer.After(1, FullScan)
        end
    end
end)

-- Polling fallback
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    if not isEnabled then return end
    pollElapsed = pollElapsed + elapsed
    if pollElapsed >= POLL_INTERVAL then
        pollElapsed = 0
        FullScan()
    end
end)
