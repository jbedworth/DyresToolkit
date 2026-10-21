# Agent Guidelines

## Project purpose and scope

Dyre's Toolkit is a WoW: Forever library AddOn: the code Dyre's AddOns share
(author-approved, 2026-10-19). It does nothing on its own. It holds one layout
mode for every Dyre's AddOn, the grid and snap to grid, snapping across
AddOns, a minimap button with a menu, and the "Dyre's AddOns" settings home.
Sounds stay in Dyre's Sounds, apart for licensing (author). The coordinating
session owns this repository as shared infrastructure. Keep this feature set;
do not add speculative features without agreement.

Naming (author-approved): title "Dyre's Toolkit"; folder, TOC, repository,
global, and saved variables `DyresToolkit`/`DyresToolkitDB`; commands `/dyre`
and `/dyretoolkit`; chat prefix `Dyre:`. ("DTF" was dropped: crude slang.)

### The family (author-approved)

- Smaller single-purpose AddOns, not one pack. The toolkit gives them one
  layout mode, one minimap button, and one settings home.
- Every Dyre's AddOn with frames or settings lists the toolkit as a CurseForge
  required dependency and as `## OptionalDeps: DyresToolkit` in its TOC (never
  `## Dependencies`, which stops it loading when the toolkit is missing).
  Without the toolkit it keeps its own layout code and top-level settings
  page, and says once in chat to install Dyre's Toolkit, naming only
  CurseForge.
- The in-game AddOn list: this AddOn has `## Category: Dyre's AddOns`; every
  other Dyre's AddOn has `## Group: DyresToolkit`, so it nests here
  (Blizzard_AddOnList AddonList.lua: Group must equal the parent's folder
  name; without the parent, a child shows at the top level).

### The interface (contract 1)

- The global `DyresToolkit`, reached with `DyresToolkit.RequireContract(1)`,
  which returns nil for a newer contract. Raise `CONTRACT` only for a change a
  dependent must know about; additions keep contract 1.
- `RegisterAddOn(info)`: `info.addon` (folder name), `info.title`, optional
  `info.setLocked(locked)` (show or hide its samples and outlines, quietly:
  the toolkit says one line for all) and `info.openSettings()`.
- `AddOns()`, `IsLocked()`, `SetLocked(locked)`, `Lock()`, `Unlock()`,
  `ToggleLock()`.
- `RegisterMovable(frame, save)`, `BeginDrag(frame)`, `EndDrag(frame)`,
  `ScaleKeepingCenter(frame, scale)`: the same rules as the Layout.lua MTF,
  WTF, and DBR copied (GAP 20, reach 24, Shift-drag groups, a drop in combat
  waits), across every AddOn's frames, plus snap to grid. Each AddOn saves
  its own positions through `save`.
- `ResizeFromCenter(frame, scale, width, height)` (added in 1.1.0; contract 1,
  so dependents check that it exists and keep their own copy as a fallback):
  changes scale and/or size without moving the frame's center on screen.
  A bare `SetScale` moves a frame anchored CENTER to UIParent's corner,
  because the offsets are in the frame's own scaled units (found by MTF,
  2026-10-20). It reads the center in UIParent units first, re-anchors there,
  saves through the registered `save` (an unregistered frame is only
  re-anchored), and does nothing when nothing changes. `ScaleKeepingCenter`
  now calls it.
- Snap to grid (author-approved after play testing): per axis, a box whose
  center is within reach (24) of the red center line centers on it; else an
  edge within reach goes onto it; else an edge within a quarter of the grid
  size (GRID_EDGE_REACH; 8 at 32) of a grey line goes onto it; else the box
  stays where it was dropped. A neighbor in reach (magnetic snapping) comes
  before the grid. A Shift-dragged group snaps to the grid by its outer box.
- Ctrl held at the drop skips all snapping, neighbors and grid (author:
  "for people trying to do pixel-perfect aligns"). A drop that waited out
  combat snaps as usual.
- `RegisterSettingsCategory(name)` returns a page (category, layout) under
  "Dyre's AddOns", or nil without the settings API; the AddOn then makes its
  own top-level page. The home is made on first use, whoever asks first.
  `SettingsCategory()`, `OpenSettings(category)` (never in combat).
- Under "Dyre's AddOns", "Dyre's " is said once (author-approved): a page or
  menu entry for "Dyre's Buff Reminders" shows as "Buff Reminders"
  (ns.ShortName); other names stay. The in-game AddOn list keeps the full
  TOC titles (author: "for the addon list, this is fine").

### Widgets (contract 2, 2.0.0; author-approved 2026-10-20)

- Author: "all the widget layout, snapping, modifier key move rules, etc.,
  centralized in Dyre's Tools, so the individual packs do not have to worry
  about it." Every Dyre's AddOn moves its frames to widgets, one at a time
  (MTF first, then smallest first), and drops its own Layout.lua, movers,
  drag scripts, scale code, and lock lines. The toolkit becomes a required
  dependency (`## Dependencies: DyresToolkit`) in each AddOn as it moves.
- `CreateWidget(spec)` (Widgets.lua): `spec.addon`, `spec.key`, `spec.title`,
  `spec.store` (the AddOn's saved table: the place as
  `{point, relativePoint, x, y}` and the numbers), `spec.width`/`height` (the
  size at 100%), `spec.point` (default place from UIParent), optional
  `spec.frame` (the AddOn's own frame, such as a named secure button),
  `spec.keys` (renamed save keys, for old saves), `spec.sizes` (`scale` and
  `opacity` = true or a range; `width`/`height` = ranges; any AddOn setting =
  a range with `label` and optional `percent`), `spec.sizeOrder`,
  `spec.measure(widget) -> width, height` (the frame size from the
  settings, as MTF's Polymorph bar: name line by text size, plus bar height,
  plus padding), `spec.resetSizes` (what "Reset size" restores; default
  every size but opacity), `spec.hint` (the outline text), `spec.mouse`
  (`"unlocked"` default: clicks only while unlocked, the click-through rule;
  `"always"`: a bar of buttons; `"client"`: the AddOn decides), callbacks
  `onLayout(widget, width, height, scale)`, `onOpacity(widget, alpha)`,
  `onUnlock(widget, unlocked)`.
- Methods: `SetContentSize(w, h)` (a size from content, from the center),
  `SetSetting(name, value)` (clamped, saved, applied), `GetSetting(name)`,
  `ResetSize()` (spec.resetSizes, else every size but opacity),
  `ResetPosition()`, `AddDragHandle(child)` (a button the widget drags by;
  clicks still reach it).
  `ResetWidgets(addon)` and `Widgets(addon)`. All toolkit state lives in
  `widget.dyre`, so it never clashes with the AddOn's own fields.
- `AddWidgetSettings(category, layout, widget, opts)`: a slider per size
  (variables `DYRE_<ADDON>_<KEY>_<NAME>`), each with a gold default mark
  (`ns.AddDefaultTick`, as MTF's and WTF's), and "Reset size"; `opts.labels`,
  `opts.tooltips`, `opts.resetLabel`, `opts.resetTooltip`.
- Rules: saved numbers are repaired on creation; sizes apply from the
  center (`ResizeFromCenter`); a protected widget resizes, re-places, and
  changes its mouse only out of combat, waiting for `PLAYER_REGEN_ENABLED`;
  opacity (`SetAlpha`) applies at once. Engine-owned objects inside a widget
  (AuraContainer slots) stay the AddOn's: set up only in `initializeFrame`,
  rebuilt from `onLayout`/`onOpacity` (family rule, found in WTF).

### Rules

- Frames always start locked at login. Frames move only out of combat.
- The minimap button uses LibDataBroker-1.1 and LibDBIcon-1.0, embedded
  (author: "the standard way"); Forever has no AddOn compartment
  (Blizzard_Minimap.toc loads it for mainline only). LibDBIcon keeps its place
  in `DyresToolkitDB.minimap`.
- The menu uses MenuUtil.CreateContextMenu (Blizzard_Menu loads for every
  game type).

## Project structure

- Runtime: DyresToolkit.toc, Libs/ (LibStub, CallbackHandler-1.0,
  LibDataBroker-1.1, LibDBIcon-1.0, and Ace3-LICENSE.txt), Core.lua,
  Layout.lua, Widgets.lua, Settings.lua, Minimap.lua, loaded in that order.
- tests/run.lua: the Lua 5.1 mock suite. tests/test_*.py: the release helpers.
- Package only the TOC, Libs/ files listed in scripts/build_release.py, the
  five runtime files, and LICENSE, under `DyresToolkit/`, named
  `DyresToolkit-<version>-forever.zip`, with `release.json` for WowUp.

## Client and API verification

- Target: Forever beta 1.60.1, build 70450 (tested in client, 2026-10-19; Interface still 16001), Lua 5.1. Pin
  source review to Gethe/wow-ui-source commit
  `943764493e6b16d63ded3ab304150d1f05e58b57`.
- Gate only on required APIs; never on client version. Never compare, print,
  or index a value that may be secret.

## Testing and releases

- Run tests/run.lua with Lua 5.1, `luac5.1 -p` on every Lua file (the
  libraries too), and the Python tests; actionlint on workflow changes.
  Report actual results.
- Read docs/RELEASE_PLAN.md before release steps. Do not create commits, tags,
  uploads, or releases unless asked. Every release needs a CHANGELOG section.
- Commit messages: imperative, capitalized subject, at most about 50
  characters, no ending punctuation.
