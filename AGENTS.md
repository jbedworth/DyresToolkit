# Agent Guidelines

## Project purpose and scope

Dyre's Toolkit is a WoW: Forever library AddOn: the code Dyre's AddOns share
(author-approved, 2026-10-19). It does nothing on its own. It holds one layout
mode for every Dyre's AddOn, the grid and snap to grid, snapping across
AddOns, a minimap button with a menu, and the "Dyre's AddOns" settings home.
Since 2.4.0 it also holds the code trackers share: aura slots, unit and cast
lookups, focusWorks, and the health-bar block and DIES badge (Dyre's Debuff
Tracker phase 1, coordinator-approved 2026-10-30).
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
- Snap to grid (author-approved after play testing; on by default since
  2.2.1, author: "It should probably be on by default"): per axis, a box whose
  center is within reach (24) of the red center line centers on it; else an
  edge within reach goes onto it; else an edge within a quarter of the grid
  size (GRID_EDGE_REACH; 8 at 32) of a grey line goes onto it; else the box
  stays where it was dropped. A neighbor in reach (magnetic snapping) comes
  before the grid. A Shift-dragged group snaps to the grid by its outer box.
- Ctrl held at the drop skips all snapping, neighbors and grid (author:
  "for people trying to do pixel-perfect aligns"). A drop that waited out
  combat snaps as usual.
- While locked, a drag started with Ctrl held moves that one frame
  (author-approved 2026-10-21, family-wide, as Questie's tracker): no Shift
  group, and the drop is free (no neighbors, no grid), also after a combat
  wait. It can only start on a part that takes the mouse while locked (a
  button or drag handle, a box's header); the rest of a locked widget stays
  click-through. Never in combat.
- `AddSettingsLink(category, layout, opts)` (2.3.0; author-approved
  2026-10-22: a feature that moved to another Dyre's AddOn is linked, not
  mirrored): a button row that opens that AddOn's page through its
  `openSettings` from `RegisterAddOn`. `opts.addon` (folder), `opts.name`,
  optional `opts.button`, `opts.tooltip`, `opts.missing`. Greyed (a modify
  predicate, checked each time the page draws) while the AddOn has not
  joined; a click then says `missing` in chat. Never opens in combat.
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
- Methods: `SetContentSize(w, h, anchor)` (a size from content; anchor
  `"LEFT"`/`"RIGHT"`/`"TOP"`/`"BOTTOM"` or a corner keeps that edge, for
  bars growing left to right or right to left and boxes collapsing to their top; default the center; 2.1.0, for DBR's grow direction),
  A widget that has grown from an edge saves that edge and its size with
  its place (`anchor`, `width`, `height` in the position table, 2.2.0), and
  is restored at that size and resized keeping the edge: its content is not
  in yet at login, so a center alone made it drift on every reload (found in
  client, 2026-10-21).
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
  `AddDefaultTick(initializer, {min, max, default})` (2.2.0) puts the same
  gold default mark on an AddOn's own slider.
- Never call GetCenter (or GetRect, GetLeft...) on a frame the toolkit has
  placed: read the center from its anchor (Layout.lua Center). Those calls
  make the client lay out pending frames inside our call, and a Blizzard frame
  resized then (the objective tracker) runs its update tainted by the toolkit
  (found in client, 2026-10-21). A frame just dragged has the client's own
  anchor, so it falls back to GetCenter.
- Rules: saved numbers are repaired on creation; sizes apply from the
  center (`ResizeFromCenter`); a protected widget resizes, re-places, and
  changes its mouse only out of combat, waiting for `PLAYER_REGEN_ENABLED`;
  opacity (`SetAlpha`) applies at once. Engine-owned objects inside a widget
  (AuraContainer slots) stay the AddOn's: set up only in `initializeFrame`,
  rebuilt from `onLayout`/`onOpacity` (family rule, found in WTF).

### Shared tracker code (2.4.0; coordinator-approved 2026-10-30)

Dyre's Debuff Tracker (`src/DyresDebuffTracker`, a local folder) is built on
these; they were copied in WTF, MTF, DSU, and DBR before. Additions: CONTRACT
stays 2, so a dependent checks that the functions it uses exist.

- Auras.lua: WTF 1.4.0's AuraEngine.lua, only its namespace changed.
  `AuraEngineKind()` ("engine" on Forever, "lua" on Era, else nil),
  `AURA_ENGINE_MISSING`, `CreateAuraContainer(parent)`: the engine's
  AuraContainer, else a plain-Lua one with the same slot methods. One
  dispatcher and one ticker for every AddOn; the ticker runs only while a
  timed aura shows.
- Units.lua: `IsSecret`, `Describe`, `ReadGUID`, `ReadName`, `IsDead` (nil or
  false for a secret). The plate memory (`LearnPlate`, `LearnPlates`,
  `ForgetPlate`, `PlateGUID`, `KnownPlate`): one table; the toolkit registers
  no plate events, each AddOn calls these from its own handlers.
  `FindUnit(guid, order)` (tokens, "plates", "memory"; default focus,
  target, plates, memory). `LockCast(targetName, opts)` returns guid, unit,
  look: the mob a cast goes to as it starts, with `units`, `memory`,
  `secretHostile`, `allowDead`, `stopAtName`, `stopAt`, so WTF's tracker,
  WTF's Control bar, and MTF's chain each keep their own rules.
- focusWorks: whether this client has a focus target. One flag for the
  whole family in `DyresToolkitDB.focusWorks` (coordinator: a fact about the
  client, and each client install has its own SavedVariables). Nil until
  PLAYER_FOCUS_CHANGED comes with a readable `UnitExists("focus")` true, then
  true for good; only true counts. A reset from any AddOn
  (`ResetFocusWorks`) resets it for all; `FOCUS_RESET_TEXT` says so.
  `FocusWorks()`, `OnFocusWorks(callback(works))` (called on every learn
  and every reset, as often as they happen; it may come in combat, so a
  listener defers macros and secure attributes itself), `LearnFocusWorks()`,
  and `NoteFocusWorks()` (an AddOn's own older flag was true: carry it over
  once). Core's SanitizeDB keeps the key; Core.lua is not changed for it.
- HealthBars.lua: WTF 1.4.0's Predict.lua frame adapters and drawing.
  `FindPlateBar(unit)`, `FindUnitBar(unit)` return bar and
  `{name, place, strata, busy}` (adapter names as WTF's debug output:
  "Threat Plates", "Plater", "EllesmereUI", "Platynator", "Shadowed Unit
  Frames", "BetterBlizzFrames", "Blizzard"); FindPlateBar gets the plate
  from `C_NamePlate.GetNamePlateForUnit`, skips a forbidden one, and reads
  its children for Platynator. `RegisterBarAdapter(kind, adapter, before)`.
  `UseBar(shown, unit, bar, info)` keeps which bar shows each unit in the
  caller's table and hides the block on a bar the unit left.
  `PrepareBar(bar, kind)` makes a block now, out of combat (the target
  frame's, at login). `DrawPrediction(bar, kind, damage, health, style,
  info)` (kind "target", "plate", "row"; style from the caller: fill, color
  {r, g, b}, opacity, outline, dies, side) returns whether DIES shows and
  its side. `HidePrediction`, `MoveDies(bar, place)` for tracker rows
  (`{point, region, relativePoint, x}`, or nil for the bar's end). Nothing
  draws with a secret or no health, or on a vertical bar. The caller
  redraws on its events, and once more on the next frame after
  NAME_PLATE_UNIT_ADDED. Textures/Stripes.tga is a byte copy of WTF
  1.4.0's (John's art, its scripts/make_stripes.py). The look keeps WTF
  1.4.0's numbers (lighten within 0.15, outline 40% lighter and +30%
  alpha, levels +1/+0, badge +12, sizes 14/11/10, UI scale); its tests are
  ported.
- DIES side (John's screenshot, 2026-10-30, "DIESJuk'taz ]": Threat Plates'
  target-of-target text "[ name ]", 30 px right of the bar, on in his Era
  profile). A side is taken when the adapter says so (`busy`, from each
  AddOn's Era source): Threat Plates, right while its target-of-target text,
  crowd-control icons (widgets.Auras.CrowdControl), or threat widget show,
  left while the threat widget shows (in groups); Plater, the side of its
  cast target name from the profile (castbar_target_show and
  castbar_target_anchor sides 1-3 left, 5-7 right; John's: 6) and the raid
  marker's side while its icon shows. Also when a shown text of the bar or
  its parent is anchored just outside that edge (GetPoint only, never
  GetLeft or GetCenter; a secret anchor is never compared). Then the other
  side, then inside the bar's right end. A caller's `style.side` wins.
  Platynator keeps its 22 px place (its layout is per design; checked in
  client by John).
- Public HealthBars API (John, 2026-10-31: in 2.4.0; docs/HEALTHBARS_API.md):
  `DyresToolkit.HealthBars`, `API_VERSION` 1, no new global. For outside
  AddOns: `RegisterAdapter{name, plate, unit, side, anchor, strata, level,
  avoid, suppress}` (before the built-in adapters; nil falls through; one
  per name, a second replaces), `UnregisterAdapter`, `SetSuppressed(bar,
  on)` (weak keys), `Refresh(unit)` (coalesced to the next frame, calls the
  active source's `refresh`), `GetPredictedDamage`, `WillDie` (nil for a
  secret health), `RegisterCallback`/`UnregisterCallback`
  ("PREDICTION_CHANGED"). For the family only (TOC `## Group:
  DyresToolkit`): `RegisterSource{addon, priority, damage, willDie,
  refresh}`, `SetSourceEnabled`, `IsActiveSource` (draw only when true;
  Debuff Tracker 20 above WTF 10, so a mob is drawn once),
  `NotifyChanged(addon, unit, guid)`. Every outside function runs in pcall;
  a failing one is off until reload. Its chat line shows only in debug mode
  (`/dyre debug`, session-only, lists the failures so far; John,
  2026-10-31: players cannot fix it). Badge place order: the caller's
  `style.side`, then the adapter's anchor, its side, then the toolkit's own.
- No byte-for-byte copy tests of toolkit files, here or in a dependent
  (John, 2026-10-30): a dependent's suite loads ../DyresToolkit when it is
  there and its vendored copy only in CI. Additions are still preferred over
  edits to Core.lua, Layout.lua, Widgets.lua, Settings.lua, and Minimap.lua.

Switch-over (not in 2.4.0; each owner session, in its own release):
- DSU, DBR (low risk): drop AuraEngine.lua for `CreateAuraContainer`, need
  2.4 (a message with an older toolkit), copy tests/toolkit again.
- MTF (medium): the same, plus ReadGUID, `LockCast` with its chain,
  `FindUnit`, focusWorks with `NoteFocusWorks`, and `/mtf reset_focus`
  calling `ResetFocusWorks`. Its Polymorph bar later moves to Dyre's Debuff
  Tracker.
- WTF (John, 2026-10-30: switches in 1.4.1, by the WTF session): drops
  AuraEngine.lua, Core's plate memory and focusWorks, its ReadGUID and cast
  lock copies, and Predict's adapters and drawing; keeps contract 1 for its
  movables and `## OptionalDeps`, with the features that need 2.4 off
  without it. Its Layout.lua fallback stays.
- Required before any switch-over on Forever: an in-client check that an
  AuraContainer made by toolkit code shows auras in combat with no taint
  blamed on DyresToolkit (as in 2.2.1).

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
  Layout.lua, Widgets.lua, Settings.lua, Minimap.lua, Auras.lua, Units.lua,
  HealthBars.lua, loaded in that order; Textures/Stripes.tga.
- tests/run.lua: the Lua 5.1 mock suite. tests/test_*.py: the release helpers.
- Package only the TOC, Libs/ files listed in scripts/build_release.py, the
  eight runtime files, Textures/Stripes.tga, and LICENSE, under `DyresToolkit/`, named
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
