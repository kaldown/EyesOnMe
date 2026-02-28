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
local targetingMe = {}   -- [unitToken] = { name, fullName, class, guid }
local threatCount = 0
local POLL_INTERVAL = 0.5
local pollElapsed = 0
local friendlyEnabled = true
local friendlyTargetingMe = {}  -- [guid] = { name, fullName, class, guid, nameplateUnit, groupUnit }
local friendlyCount = 0
local playersOnly = true

--------------------------------------------------------------
-- Defaults
--------------------------------------------------------------

local defaults = {
    enabled = true,
    playersOnly = true,
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
    autoShowNameList = true,
    autoShowFriendlyNameList = true,
    nameListSize = 5,
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
    if playersOnly then
        return UnitIsPlayer(unit) and UnitIsEnemy("player", unit)
    else
        return UnitIsEnemy("player", unit)
    end
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
    if targetingMe[unit] then return end

    local name, realm = UnitName(unit)
    local _, class = UnitClass(unit)
    local guid = UnitGUID(unit)
    local fullName = realm and realm ~= "" and (name .. "-" .. realm) or name

    targetingMe[unit] = {
        name = name or "Unknown",
        fullName = fullName or "Unknown",
        class = class or "UNKNOWN",
        guid = guid or "",
        isPlayer = UnitIsPlayer(unit),
    }

    local oldCount = threatCount
    threatCount = threatCount + 1

    EyesOnMe:DebugLogDetection(unit, targetingMe[unit], "enemy")
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
        friendlyTargetingMe[guid].nameplateUnit = nameplateUnit
        if IsGroupUnit(unit) then
            friendlyTargetingMe[guid].groupUnit = unit
        end
        return
    end

    local name, realm = UnitName(unit)
    local _, class = UnitClass(unit)
    local fullName = realm and realm ~= "" and (name .. "-" .. realm) or name

    friendlyTargetingMe[guid] = {
        name = name or "Unknown",
        fullName = fullName or "Unknown",
        class = class or "UNKNOWN",
        guid = guid,
        nameplateUnit = nameplateUnit,
        groupUnit = IsGroupUnit(unit) and unit or nil,
    }

    local oldCount = friendlyCount
    friendlyCount = friendlyCount + 1

    EyesOnMe:DebugLogDetection(unit, friendlyTargetingMe[guid], "friendly")
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
                    if guid then
                        if not friendlySeenGuids[guid] then
                            friendlySeenGuids[guid] = true
                            AddFriendly(guid, unit, nil)
                        elseif friendlyTargetingMe[guid] then
                            -- Update group unit for players already seen via nameplate
                            friendlyTargetingMe[guid].groupUnit = unit
                        end
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

function EyesOnMe:IsPlayersOnly()
    return playersOnly
end

function EyesOnMe:SetPlayersOnly(enabled)
    playersOnly = enabled
    EyesOnMeDB.playersOnly = enabled
    ResetAll()
    if isEnabled then
        FullScan()
    end
end

--------------------------------------------------------------
-- Debug diagnostic system (temporary, for targeting investigation)
-- Collects data passively during gameplay. Review with /eom debug
--------------------------------------------------------------

local debugMode = false

local function GetContext()
    local ctx = "open_world"
    if UnitInBattleground("player") then
        ctx = "battleground"
    elseif IsActiveBattlefieldArena and IsActiveBattlefieldArena() then
        ctx = "arena"
    elseif IsInRaid() then
        ctx = "raid"
    elseif IsInGroup() then
        ctx = "party"
    end
    return ctx
end

local function DebugLog(category, data)
    if not debugMode then return end
    EyesOnMeDB.debugLog = EyesOnMeDB.debugLog or {}
    local log = EyesOnMeDB.debugLog
    log[#log + 1] = {
        t = time(),
        cat = category,
        ctx = GetContext(),
        combat = InCombatLockdown() and true or false,
        d = data,
    }
    -- Cap at 500 entries to avoid SavedVariables bloat
    if #log > 500 then
        table.remove(log, 1)
    end
end

function EyesOnMe:IsDebugMode()
    return debugMode
end

function EyesOnMe:SetDebugMode(on)
    debugMode = on
    if on then
        EyesOnMeDB.debugLog = {}
        print(ADDON_PREFIX .. "Debug mode |cFF00FF00ON|r - data collection started")
        -- Snapshot current context
        DebugLog("context", { context = GetContext() })
        -- Check arena unit IDs
        if IsActiveBattlefieldArena and IsActiveBattlefieldArena() then
            for i = 1, 5 do
                local exists = UnitExists("arena" .. i)
                if exists then
                    local n, r = UnitName("arena" .. i)
                    DebugLog("arena_unit", { unit = "arena" .. i, name = n, realm = r })
                end
            end
        end
    else
        print(ADDON_PREFIX .. "Debug mode |cFFFF0000OFF|r")
    end
end

function EyesOnMe:DebugLogDetection(unit, info, side)
    if not debugMode then return end
    local name, realm = UnitName(unit)
    local isPlayer = UnitIsPlayer(unit)
    DebugLog("detect_" .. side, {
        unit = unit,
        name = name,
        realm = realm or "",
        fullName = info.fullName,
        isPlayer = isPlayer,
        guid = info.guid,
    })
end

function EyesOnMe:DebugLogClick(data)
    if not debugMode then return end

    -- Check what actually got targeted after the secure click
    local gotName, gotRealm = UnitName("target")
    local gotGuid = UnitGUID("target")
    local gotFull = GetUnitName("target", true) or ""
    data.gotTarget = gotName or ""
    data.gotRealm = gotRealm or ""
    data.gotGuid = gotGuid or ""
    data.gotFullName = gotFull

    -- Determine if click was successful
    local exp = data.expectedName or ""
    local matched = false
    if exp ~= "" then
        matched = (gotName == exp)
            or (gotFull == exp)
            -- Name-Realm expected, got just Name (WoW strips realm from UnitName)
            or (exp:find("-") and gotName == exp:match("^(.+)-"))
    end
    data.matched = matched

    -- Diagnose failure reason
    if not matched then
        local macro = data.attrMacro or ""
        local aUnit = data.attrUnit or ""
        if macro == "/targetexact nil" and aUnit == "" then
            data.failReason = "default_attrs_never_set"
        elseif data.attrType == "target" and not data.unitExists then
            data.failReason = "unit_gone"
        elseif data.attrType == "target" and data.unitExists and not data.unitIsPlayer then
            data.failReason = "unit_is_npc"
        elseif data.attrType == "target" and data.unitExists and data.unitIsPlayer
            and data.unitName and data.unitName ~= exp:match("^([^-]+)") then
            data.failReason = "unit_recycled"
        elseif exp == "" then
            data.failReason = "empty_row"
        else
            data.failReason = "unknown"
        end
    end

    DebugLog("click", data)
end

function EyesOnMe:DebugReport()
    local log = EyesOnMeDB.debugLog
    if not log or #log == 0 then
        print(ADDON_PREFIX .. "No debug data. Run: /eom debug on")
        return
    end

    print(ADDON_PREFIX .. "=== Debug Report (" .. #log .. " entries) ===")

    -- Tally by category and context
    local contexts = {}
    local enemies = { total = 0, withRealm = 0, player = 0, npc = 0 }
    local friendlies = { total = 0, withRealm = 0 }
    local arenaUnits = {}

    -- Click stats broken down
    local cs = {
        ene_ooc = { ok = 0, miss = 0 },
        ene_combat = { ok = 0, miss = 0 },
        fri_ooc = { ok = 0, miss = 0 },
        fri_combat = { ok = 0, miss = 0 },
    }
    local failReasons = {}
    local clickEntries = {}

    for _, entry in ipairs(log) do
        contexts[entry.ctx] = true

        if entry.cat == "detect_enemy" then
            enemies.total = enemies.total + 1
            if entry.d.realm and entry.d.realm ~= "" then
                enemies.withRealm = enemies.withRealm + 1
            end
            if entry.d.isPlayer then
                enemies.player = enemies.player + 1
            else
                enemies.npc = enemies.npc + 1
            end

        elseif entry.cat == "detect_friendly" then
            friendlies.total = friendlies.total + 1
            if entry.d.realm and entry.d.realm ~= "" then
                friendlies.withRealm = friendlies.withRealm + 1
            end

        elseif entry.cat == "click" then
            clickEntries[#clickEntries + 1] = entry
            local d = entry.d
            local key = (d.side or "ene") .. "_" .. (entry.combat and "combat" or "ooc")
            -- Normalize key
            if key:find("^fri") then
                key = entry.combat and "fri_combat" or "fri_ooc"
            else
                key = entry.combat and "ene_combat" or "ene_ooc"
            end
            if cs[key] then
                if d.matched then
                    cs[key].ok = cs[key].ok + 1
                else
                    cs[key].miss = cs[key].miss + 1
                end
            end
            if not d.matched and d.failReason then
                failReasons[d.failReason] = (failReasons[d.failReason] or 0) + 1
            end

        elseif entry.cat == "arena_unit" then
            arenaUnits[#arenaUnits + 1] = entry.d.unit .. "=" .. (entry.d.name or "?")
        end
    end

    -- Print context and detection summary
    local ctxList = {}
    for c in pairs(contexts) do ctxList[#ctxList + 1] = c end
    print("  Contexts: " .. table.concat(ctxList, ", "))

    if enemies.total > 0 then
        print("  Enemies detected: " .. enemies.total ..
            " (players: " .. enemies.player .. ", NPCs: " .. enemies.npc .. ")")
        print("    With realm: " .. enemies.withRealm ..
            ", Without: " .. (enemies.total - enemies.withRealm))
    end
    if friendlies.total > 0 then
        print("  Friendlies detected: " .. friendlies.total ..
            " (with realm: " .. friendlies.withRealm .. ")")
    end

    -- Click summary table
    if #clickEntries > 0 then
        print("  --- Click Summary ---")
        local function fmtCS(label, s)
            local total = s.ok + s.miss
            if total == 0 then return end
            print("    " .. label .. ": " .. s.ok .. "/" .. total ..
                (s.miss > 0 and (" |cFFFF0000(" .. s.miss .. " miss)|r") or " |cFF00FF00(all OK)|r"))
        end
        fmtCS("Enemy OOC     ", cs.ene_ooc)
        fmtCS("Enemy COMBAT  ", cs.ene_combat)
        fmtCS("Friend OOC    ", cs.fri_ooc)
        fmtCS("Friend COMBAT ", cs.fri_combat)

        -- Failure reasons
        local hasReasons = false
        for _ in pairs(failReasons) do hasReasons = true; break end
        if hasReasons then
            print("  --- Failure Reasons ---")
            for reason, count in pairs(failReasons) do
                print("    " .. reason .. ": " .. count)
            end
        end
    end

    if #arenaUnits > 0 then
        print("  Arena units: " .. table.concat(arenaUnits, ", "))
    end

    -- Last 10 click details
    if #clickEntries > 0 then
        print("  --- Last " .. math.min(10, #clickEntries) .. " Clicks ---")
        local start = math.max(1, #clickEntries - 9)
        for i = start, #clickEntries do
            local e = clickEntries[i]
            local d = e.d
            local status = d.matched and "|cFF00FF00OK|r" or "|cFFFF0000MISS|r"
            local combat = e.combat and "[C]" or "[O]"
            local side = (d.side or "?"):sub(1, 3)
            print(string.format("  %d. %s %s %s %s",
                i, status, combat, side, d.expectedName or "?"))
            if not d.matched then
                print(string.format("     WHY: %s | attr=%s unit=%s macro=%s",
                    d.failReason or "?", d.attrType or "?",
                    d.attrUnit or "", d.attrMacro or ""))
                print(string.format("     unitExists=%s isPlayer=%s got=%s",
                    tostring(d.unitExists), tostring(d.unitIsPlayer),
                    d.gotTarget or "nil"))
            end
        end
    end
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
function EyesOnMe:OnCombatStart() end
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
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitializeDB()
        isEnabled = EyesOnMeDB.enabled
        friendlyEnabled = EyesOnMeDB.friendlyEnabled
        playersOnly = EyesOnMeDB.playersOnly
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

    elseif event == "PLAYER_REGEN_DISABLED" then
        EyesOnMe:OnCombatStart()

    elseif event == "PLAYER_REGEN_ENABLED" then
        EyesOnMe:OnCombatEnd()

    elseif event == "PLAYER_ENTERING_WORLD" then
        ResetAll()
        if isEnabled then
            C_Timer.After(1, FullScan)
        end
        -- Debug: log context and check arena units on zone change
        if debugMode then
            DebugLog("context", { context = GetContext() })
            if IsActiveBattlefieldArena and IsActiveBattlefieldArena() then
                for i = 1, 5 do
                    if UnitExists("arena" .. i) then
                        local n, r = UnitName("arena" .. i)
                        DebugLog("arena_unit", { unit = "arena" .. i, name = n, realm = r })
                    end
                end
            end
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
