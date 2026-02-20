# Auto-Visible Name List Design

## Summary

Replace the click-to-open dropdown with a persistent, auto-visible name list panel that shows class-colored player names instantly when someone targets you, including during combat. Pre-allocated secure button rows enable click-to-target.

## Problem

Current behavior requires clicking the counter to open a dropdown to see who is targeting you. In PvP, you need this information immediately without an extra click - especially mid-combat.

## Design

### Architecture

Two name list panels (enemy + friendly), each anchored below its counter. Each panel pre-allocates 10 `SecureActionButtonTemplate` rows at init. The `nameListSize` setting (default 5, configurable 1-10 in settings menu) controls how many rows can be active. Changes take effect immediately, no reload required.

The existing click-to-open dropdown is removed entirely. Counter frames become display-only (icon + number + drag + tooltip).

### Panel Structure

```
+----------------+
|  [eye] 3       |  <-- counter (existing, unchanged)
+----------------+
| Roguemaster    |  <-- row 1 (SecureActionButton, class-colored)
| Backstabber    |  <-- row 2
| Shadowdancer   |  <-- row 3
|                |  <-- rows 4-10 (alpha 0, pre-allocated but invisible)
+----------------+
   panel backdrop auto-sizes to fit 3 active rows
```

**Panel frame** (non-secure, `BackdropTemplate`):
- Parented to `UIParent`, anchored `TOP` to counter `BOTTOM`
- `Show()` once at init, never `Hide()` - visibility via `SetAlpha(0/1)`
- Auto-sizes height to `padding*2 + activeCount * rowHeight`
- Auto-sizes width to widest name + padding (min = counter width)
- `SetSize` and `SetAlpha` are combat-safe on non-secure frames

**Row buttons** (secure, `SecureActionButtonTemplate`):
- Parented to the panel, fixed anchor offsets
- `Show()` once at init, never `Hide()` - visibility via `SetAlpha(0/1)`
- Each row: `FontString` (class-colored name) + highlight texture on hover
- Fixed position: `row[i]` at `TOPLEFT panel, PADDING, -(PADDING + (i-1) * ROW_HEIGHT)`

### Combat-Safe Operations

All display updates work during combat:

| Operation | Combat-safe? | Used for |
|---|---|---|
| `FontString:SetText()` | Yes | Name display |
| `FontString:SetTextColor()` | Yes | Class coloring |
| `frame:SetAlpha()` | Yes | Row/panel visibility |
| `frame:SetSize()` (non-secure) | Yes | Panel backdrop resize |
| `button:SetAttribute()` | No | Targeting sync (deferred) |

### Targeting Strategy

Attributes synced out of combat only (every 0.5s FullScan + `PLAYER_REGEN_ENABLED`):

| Source | Attribute setup | Works in combat? |
|---|---|---|
| Friendly with group token | `type="target"`, `unit="party2"` | Yes (stable token) |
| Enemy (nameplate) | `type="macro"`, `macrotext="/targetexact Name"` | Frozen at pre-combat state |
| Enemy (cross-realm BG) | `type="macro"`, `macrotext="/targetexact Name-Server"` | Frozen at pre-combat state |

**Cross-realm fix:** Capture realm from `UnitName()`:
```lua
local name, realm = UnitName(unit)
local fullName = realm and realm ~= "" and (name .. "-" .. realm) or name
```
Display short `name` in row text, use `fullName` in macrotext.

Unused rows keep `macrotext="/targetexact nil"` so clicking does nothing.

### Data Flow

```
Core.lua detects change (OnTargeterAdded/Removed, FullScan)
    |
    v
Visuals.lua callback fires
    |
    v
Build sorted entry array from GetTargeters() / GetFriendlyTargeters()
    |
    v
RefreshNameList(panel, entries):
    cap = min(#entries, nameListSize)
    For i = 1..10:
        if i <= cap:
            row.text:SetText(name)           -- combat-safe
            row.text:SetTextColor(classColor) -- combat-safe
            row:SetAlpha(1)                   -- combat-safe
            if not InCombatLockdown():
                SetAttribute(targeting)       -- targeting sync
        else:
            row.text:SetText("")
            row:SetAlpha(0)
            if not InCombatLockdown():
                SetAttribute("macrotext", "/targetexact nil")
    Resize panel backdrop to fit cap rows
    panel:SetAlpha(cap > 0 and 1 or 0)
```

### Auto-Show / Auto-Hide

- Panel becomes visible (alpha 1) when first targeter is detected
- Panel becomes invisible (alpha 0) when count drops to 0
- Controlled by `autoShowNameList` / `autoShowFriendlyNameList` DB toggles
- When toggle is off, panel stays hidden (alpha 0) regardless of count

### Settings Additions

New DB defaults:

| Key | Default | Description |
|---|---|---|
| `autoShowNameList` | `true` | Auto-show enemy name list |
| `autoShowFriendlyNameList` | `true` | Auto-show friendly name list |
| `nameListSize` | `5` | Max visible rows per panel (1-10) |

Settings panel additions:
- Enemy section: "Auto-show target list" checkbox
- Friendly section: "Auto-show friendly list" checkbox
- Shared section at bottom: "Name list size" slider (1-10)

Pre-allocate 10 rows (the max) at init. The slider controls how many can be active. Changing the slider takes effect immediately.

### What Gets Removed

- `CreateDropdownPanel()` and `PopulateDropdown()` functions
- `RefreshEnemyDropdown()` and `RefreshFriendlyDropdown()`
- Counter frame click-detection scripts (OnMouseDown/OnMouseUp)
- `UISpecialFrames` registration for dropdowns
- `PostClick` hide-dropdown handlers
- `CLICK_THRESHOLD` constant

Counter frames simplify to: icon + number + drag + tooltip.

### What Stays Unchanged

- Counter frames (icon + number display)
- Nameplate badges (enemy + friendly)
- Red vignette overlay
- Sound alerts
- Minimap button
- All Core.lua detection logic
- Settings panel structure (just adding new checkboxes + slider)

### Cross-Realm BG Fix

Both enemy and friendly tracking updated to store full names:

**Core.lua `AddTargeter`:**
```lua
local name, realm = UnitName(unit)
local fullName = realm and realm ~= "" and (name .. "-" .. realm) or name
targetingMe[unit] = {
    name = name or "Unknown",
    fullName = fullName or "Unknown",
    class = class or "UNKNOWN",
    guid = guid or "",
}
```

**Core.lua `AddFriendly`:** Same pattern for `friendlyTargetingMe`.
