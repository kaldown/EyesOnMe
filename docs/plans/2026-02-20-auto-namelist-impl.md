# Auto-Visible Name List Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the click-to-open dropdown with a persistent, auto-visible name list that shows class-colored player names instantly (including during combat) with click-to-target.

**Architecture:** Two name list panels (enemy + friendly) anchored below their counters. Each pre-allocates 10 SecureActionButtonTemplate rows. Visibility controlled via SetAlpha (combat-safe). Targeting attributes sync out of combat; display updates (text, color, alpha) are instant.

**Tech Stack:** WoW Classic Lua, SecureActionButtonTemplate, BackdropTemplate

**Design doc:** `docs/plans/2026-02-20-auto-namelist-design.md`

**Domain skill:** `wow-addon-development` - invoke before touching any Lua file.

---

### Task 1: Add fullName tracking and new defaults to Core.lua

**Files:**
- Modify: `Core.lua:28-43` (defaults)
- Modify: `Core.lua:75-94` (AddTargeter)
- Modify: `Core.lua:118-145` (AddFriendly)

**Step 1: Add new defaults**

In `Core.lua`, add three new keys to the `defaults` table (after `friendlyCounterPos`):

```lua
    friendlyCounterPos = nil,
    autoShowNameList = true,
    autoShowFriendlyNameList = true,
    nameListSize = 5,
    minimap = { hide = false },
```

**Step 2: Add fullName to AddTargeter**

Replace the `AddTargeter` function body. Capture realm from `UnitName()`:

```lua
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
    }

    local oldCount = threatCount
    threatCount = threatCount + 1

    EyesOnMe:OnTargeterAdded(unit, targetingMe[unit])
    EyesOnMe:OnThreatCountChanged(oldCount, threatCount)
end
```

**Step 3: Add fullName to AddFriendly**

Replace the body of `AddFriendly`. After the early-return for existing GUIDs:

```lua
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

    EyesOnMe:OnFriendlyAdded(nameplateUnit or unit, friendlyTargetingMe[guid])
    EyesOnMe:OnFriendlyCountChanged(oldCount, friendlyCount)
end
```

**Step 4: Commit**

```
git add Core.lua
git commit -m "feat(core): add fullName tracking and name list defaults"
```

---

### Task 2: Remove old dropdown code from Visuals.lua

**Files:**
- Modify: `Visuals.lua`

Remove the following code blocks:

**Step 1: Remove dropdown constants and factory**

Delete `CLICK_THRESHOLD` from line 13.

Delete `CreateDropdownRow` function (lines 239-262).

Delete `CreateDropdownPanel` function (lines 264-296).

**Step 2: Remove dropdown from CreateCounter**

In `CreateCounter()`, remove:
- Click detection variables and scripts: `mouseDownX/mouseDownY`, `OnMouseDown`, `OnMouseUp` handlers (lines 351-375)
- Dropdown panel creation and wiring (lines 411-427): the `CreateDropdownPanel` call, `tinsert(UISpecialFrames, ...)`, and the PostClick loop

**Step 3: Remove dropdown from CreateFriendlyCounter**

In `CreateFriendlyCounter()`, remove the same patterns:
- Click detection variables and scripts (lines 508-532)
- Dropdown panel creation and wiring (lines 568-584)

**Step 4: Remove dropdown refresh functions**

Delete `PopulateDropdown` function (lines 614-671).

Delete `RefreshEnemyDropdown` function (lines 673-685).

Delete `RefreshFriendlyDropdown` function (lines 687-700).

**Step 5: Remove dropdown references from callbacks**

In `OnTargeterAdded` (line 742): remove the `if not InCombatLockdown() ... RefreshEnemyDropdown` block.

In `OnTargeterRemoved` (line 750): remove the same block.

In `OnFriendlyAdded` (line 778): remove the `RefreshFriendlyDropdown` block.

In `OnFriendlyRemoved` (line 786): remove the same block.

In `OnCombatEnd` (line 807): remove `self:RefreshEnemyDropdown()` and `self:RefreshFriendlyDropdown()` lines.

In `OnTargetersRefreshed` (line 822): remove the entire function body (dropdown refresh logic).

**Step 6: Remove dropdown from UpdateCounter/UpdateFriendlyCounter**

In `UpdateCounter` (line 437): remove `if counterFrame.dropdown ...` Hide block.

In `UpdateFriendlyCounter` (line 591): remove `if friendlyCounterFrame.dropdown ...` Hide block.

**Step 7: Verify /reload in-game**

Expected: counters still show, badges still work, no Lua errors. Clicking the counter does nothing (no dropdown). This is a temporary regression.

**Step 8: Commit**

```
git add Visuals.lua
git commit -m "refactor(ui): remove click-to-open dropdown"
```

---

### Task 3: Add name list panel to Visuals.lua

**Files:**
- Modify: `Visuals.lua`

**Step 1: Add name list constants**

Replace the removed `CLICK_THRESHOLD` with new constants. Near the top of Visuals.lua, after the existing constants:

```lua
local NAMELIST_ROW_HEIGHT = 20
local NAMELIST_PADDING = 4
local NAMELIST_MAX_ROWS = 10
```

Keep existing `DROPDOWN_ROW_HEIGHT` and `DROPDOWN_PADDING` removed. The new constants replace them.

**Step 2: Add CreateNameListPanel factory**

Add this function where `CreateDropdownPanel` used to be (after the friendly badge section):

```lua
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
```

**Step 3: Add RefreshNameList function**

Add the shared refresh function after `CreateNameListPanel`:

```lua
local function RefreshNameList(panel, entries, autoShowKey)
    if not panel or not EyesOnMeDB[autoShowKey] then
        if panel then panel:SetAlpha(0) end
        return
    end

    local maxVisible = EyesOnMeDB.nameListSize or 5
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

            if not InCombatLockdown() then
                row:SetAttribute("type1", "macro")
                row:SetAttribute("unit", "")
                row:SetAttribute("macrotext", "/targetexact nil")
            end
        end
    end

    panel.activeCount = count

    if count > 0 then
        local totalHeight = NAMELIST_PADDING * 2 + count * NAMELIST_ROW_HEIGHT
        local totalWidth = maxWidth + NAMELIST_PADDING * 2
        local minWidth = panel.anchorParent and panel.anchorParent:GetWidth() or 80
        panel:SetSize(math.max(totalWidth, minWidth), totalHeight)
        panel:SetAlpha(1)
    else
        panel:SetAlpha(0)
    end
end
```

**Step 4: Add enemy/friendly refresh wrappers**

Add after `RefreshNameList`:

```lua
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
```

**Step 5: Commit**

```
git add Visuals.lua
git commit -m "feat(ui): add name list panel factory and refresh logic"
```

---

### Task 4: Wire name list panels into counters

**Files:**
- Modify: `Visuals.lua`

**Step 1: Create enemy name list in CreateCounter**

At the end of `CreateCounter()`, where the dropdown creation used to be, add:

```lua
    -- Name list panel
    counterFrame.nameList = CreateNameListPanel(
        counterFrame, "EyesOnMeEnemyNameList",
        0.15, 0.0, 0.0,   -- bg: dark red
        0.6, 0.0, 0.0     -- border: red
    )
```

**Step 2: Create friendly name list in CreateFriendlyCounter**

At the end of `CreateFriendlyCounter()`, where the dropdown creation used to be, add:

```lua
    -- Name list panel
    friendlyCounterFrame.nameList = CreateNameListPanel(
        friendlyCounterFrame, "EyesOnMeFriendlyNameList",
        0.0, 0.1, 0.15,   -- bg: dark teal
        0.0, 0.4, 0.5     -- border: teal
    )
```

**Step 3: Update OnTargeterAdded callback**

Replace the body:

```lua
function EyesOnMe:OnTargeterAdded(unit, info)
    ShowBadge(unit)
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
    end
end
```

**Step 4: Update OnTargeterRemoved callback**

```lua
function EyesOnMe:OnTargeterRemoved(unit, info)
    HideBadge(unit)
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
    end
end
```

**Step 5: Update OnFriendlyAdded callback**

```lua
function EyesOnMe:OnFriendlyAdded(unit, info)
    ShowFriendlyBadge(unit)
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
    end
end
```

**Step 6: Update OnFriendlyRemoved callback**

```lua
function EyesOnMe:OnFriendlyRemoved(unit, info)
    HideFriendlyBadge(unit)
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
    end
end
```

**Step 7: Update OnCombatEnd callback**

Full attribute sync when leaving combat:

```lua
function EyesOnMe:OnCombatEnd()
    if counterFrame then
        counterFrame:EnableMouse(counterFrame:GetAlpha() > 0)
    end
    if friendlyCounterFrame then
        friendlyCounterFrame:EnableMouse(friendlyCounterFrame:GetAlpha() > 0)
    end
    -- Full attribute sync now that combat lockdown is lifted
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
    end
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
    end
end
```

**Step 8: Update OnTargetersRefreshed callback**

Refresh name lists on every FullScan (syncs attributes out of combat):

```lua
function EyesOnMe:OnTargetersRefreshed()
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
    end
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
    end
end
```

**Step 9: Update OnEnabledChanged callback**

Add name list hide when addon is disabled:

```lua
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
```

**Step 10: Update OnFriendlyEnabledChanged callback**

```lua
function EyesOnMe:OnFriendlyEnabledChanged(enabled)
    if not enabled then
        HideAllFriendlyBadges()
        UpdateFriendlyCounter(0)
        if friendlyCounterFrame and friendlyCounterFrame.nameList then
            friendlyCounterFrame.nameList:SetAlpha(0)
        end
    end
end
```

**Step 11: Update RefreshVisuals**

Add name list refresh to the existing `RefreshVisuals` function, at the end:

```lua
    -- Refresh name lists
    if counterFrame and counterFrame.nameList then
        RefreshNameList(counterFrame.nameList, BuildEnemyEntries(), "autoShowNameList")
    end
    if friendlyCounterFrame and friendlyCounterFrame.nameList then
        RefreshNameList(friendlyCounterFrame.nameList, BuildFriendlyEntries(), "autoShowFriendlyNameList")
    end
```

**Step 12: Verify /reload in-game**

Expected: enemy and friendly name lists auto-show below counters when players target you. Class-colored names visible. Clicking a name targets that player (out of combat). Names appear/disappear during combat. No Lua errors.

**Step 13: Commit**

```
git add Visuals.lua
git commit -m "feat(ui): wire auto-visible name list panels to counters"
```

---

### Task 5: Add name list settings to Settings.lua

**Files:**
- Modify: `Settings.lua:89-165` (CreateSettingsPanel)

**Step 1: Add enemy name list checkbox**

In `CreateSettingsPanel()`, in the Enemy Tracking section, after the "Lock counter position" checkbox (around the `y = y - 40` line before the slider), add:

```lua
    CreateCheckbox(settingsFrame, "Auto-show target list", "autoShowNameList", 16, y)
    y = y - 30
```

**Step 2: Add friendly name list checkbox**

In the Friendly Tracking section, after the "Lock friendly counter" checkbox, add:

```lua
    CreateCheckbox(settingsFrame, "Auto-show friendly list", "autoShowFriendlyNameList", 16, y)
    y = y - 30
```

**Step 3: Add name list size slider**

After the friendly section, add a new shared section:

```lua
    -- === Name List Section ===
    y = y - 20
    local listHeader = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", 16, y)
    listHeader:SetText("Name List")
    listHeader:SetTextColor(0.8, 0.8, 0.8)

    y = y - 27
    CreateSlider(settingsFrame, "Max names shown", "nameListSize", 50, y, 1, 10, 1)
```

**Step 4: Adjust settings frame height**

The settings frame needs more height for the new controls. Update the frame size:

```lua
    settingsFrame:SetSize(280, 540)
```

(Was 450, now 540 to fit the new checkboxes + slider + section header.)

**Step 5: Fix slider display for integer values**

The existing `CreateSlider` formats as percentage (`math.floor(value * 100) .. "%"`). The name list size slider needs integer display. Add an optional `formatter` parameter to `CreateSlider`, or create the slider inline.

Simplest approach: modify `CreateSlider` to accept an optional format function:

```lua
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
```

Update the existing vignette intensity call to pass the percent formatter explicitly (or leave nil for default):

```lua
    CreateSlider(settingsFrame, "Vignette intensity", "vignetteIntensity", 50, y, 0.1, 1.0, 0.05)
```

And the new name list size slider:

```lua
    CreateSlider(settingsFrame, "Max names shown", "nameListSize", 50, y, 1, 10, 1,
        function(v) return tostring(math.floor(v)) end)
```

**Step 6: Verify /reload in-game**

Expected: settings panel shows the new checkboxes and slider. Toggling "Auto-show target list" hides/shows the name list. Changing the slider adjusts how many names are visible. No Lua errors.

**Step 7: Commit**

```
git add Settings.lua
git commit -m "feat(settings): add name list toggle and size controls"
```

---

### Task 6: Final verification and counter tooltip update

**Files:**
- Modify: `Visuals.lua` (counter tooltip text)

**Step 1: Update enemy counter tooltip**

In the `counterFrame` OnEnter handler, remove the line:
```lua
        GameTooltip:AddLine("Click for targets, drag to move", 0.5, 0.5, 0.5)
```
Replace with:
```lua
        GameTooltip:AddLine("Drag to move", 0.5, 0.5, 0.5)
```

**Step 2: Update friendly counter tooltip**

Same change in the `friendlyCounterFrame` OnEnter handler.

**Step 3: Full in-game verification**

Test matrix:

1. **Enemy detection:** Walk near enemy players. Names appear below enemy counter. Class colors correct.
2. **Friendly detection:** Group with a friend. Their name appears below friendly counter when they target you.
3. **Click-to-target (out of combat):** Click a name in the list. Should target that player.
4. **Combat behavior:** Enter combat. New names should appear instantly. Existing names should disappear when they stop targeting.
5. **Settings toggles:** Uncheck "Auto-show target list" - name list hides. Re-check - it shows again.
6. **Name list size slider:** Set to 3. Only 3 names show even if 5 are targeting. Set to 10. All names show.
7. **Counter still works:** Number updates, drag to move, tooltip shows.
8. **Disable addon:** `/eom` - everything hides. `/eom` again - everything shows.
9. **Party/raid targeting:** In a party, friendly name list shows group members targeting you. Click targets via group token.

**Step 4: Commit**

```
git add Visuals.lua
git commit -m "fix(ui): update counter tooltips for name list"
```
