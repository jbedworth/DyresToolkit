# Agent Guidelines

## Project purpose and scope

Dyre's Toolkit is a WoW: Forever library AddOn: the code Dyre's AddOns share
(author-approved, 2026-10-19). From 2.9.0 to 2.15.1 it also had threat,
tank, and swing features of its own; 2.16.0 moved them to Dyre's Threat and
Combat Tools (John, 2026-11-26), so on its own it again shows nothing in
combat and plays no sounds. It
holds one layout mode for every Dyre's AddOn, the grid and snap to grid, snapping across
AddOns, a minimap button with a menu, and the "Dyre's AddOns" settings home.
Since 2.4.0 it also holds the code trackers share: aura slots, unit and cast
lookups, focusWorks, and the health-bar block and DIES badge (Dyre's Debuff
Tracker phase 1, coordinator-approved 2026-10-30).
Sounds stay in Dyre's Sounds, apart for licensing (author): never copy its
files here; use its library (the global `DyresSounds`) when it is loaded
(John, 2026-11-11). The coordinating
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

### Master switches (2.17.0; John, 2026-11-27)

- Proc cues: "Add the Procs master switch". The proc store has `enabled`
  (SanitizeProcs: false only when turned off). Every arc and sound goes
  through `Switch`, which gives false while it is off; each proc's own
  switches keep their values; claims stay. `handle.Enabled()`.
  `AddProcMasterSetting(category, layout, handle, {label, tooltip,
  variable})`: the checkbox, variable `DYRE_<ADDON>_PROCS_ENABLED` (mapped
  on a host page); AddProcSettings' rows (and the arc size rows) are greyed
  while it is off and watch its variable.
- Control bars: "if the polymorph bar/macro master switch is off, disable
  all the functionality, not just the bar". `store.enabled == false` stops
  the announcements (AnnounceCast) and deletes our macros (ApplyMacros, as
  `store.macros == false`); turned on, they are written again (a player
  puts them on the action bars again). The control, macros, and announce
  claims stay. Before 2.17.0 a player with the bar off kept the macros and
  the announcements; updating removes those macros at the next Refresh.

- Proc rows listed, greyed until known (John, 2026-11-27: "I expect to see
  every setting available for warlocks, but only enabled if I have it. Not
  a generic banner"): AddProcSettings lists every proc of the player's
  class, its header, the master, and the arc size rows, always shown; a
  proc's rows are greyed while its talent is not known, and their tooltip
  ends " Greyed out: you have not learned <proc> yet."; the size rows are
  greyed while no proc is known. Before 2.17.0 these rows were hidden until
  known (and the size rows added only when a talent was known at build).

- Greyed button labels (John, 2026-11-27: "the inconsistent label
  enable/disable"): on Forever a greyed button row keeps a gold label
  (Classic Era's EvaluateState calls DisplayEnabled, 758-764; Forever's does
  not, seen in client). `GreyButtonLabel(initializer)` greys the label with
  the button: hooksecurefunc on the initializer's InitFrame and, once per
  pooled frame, on EvaluateState; weak tables; a frame we greyed goes back to
  NORMAL_FONT_COLOR when it draws another row. Used on Reset size, settings
  links, and the profile Copy row; every Dyre's AddOn calls it on its own
  greyed button rows.

### Settings sections (2.17.0; John, 2026-11-26)

John: class AddOns that bundle other Dyre's AddOns "should surface every
setting in the wrapped addon's settings, and just pass-through the setting
to the wrapped addon"; the setting stays on the wrapped AddOn's own page
too. This replaces AddSettingsLink pages in MTF and WTF (the 2026-10-22
"linked, not mirrored" rule), with the link kept as the fallback.
Settings.lua; CONTRACT stays 2 (`SETTINGS_SECTIONS_VERSION`, a feature
test: 1 the sections, 2 also `opts.variable` on AddWidgetSettings and
AddProcSettings, and AddProcSettings `opts.keys`, a list of proc keys to
keep; DBR's request, 2026-11-27: those helpers name their own variables, so
on a host page they must take ctx.variable too). 3 (John, 2026-11-27, fit and finish): ctx.part
"all" (default), "master" (only the section's top switch: hosts put every
section's switch on their top page; "the top-level disable for each section
should be on the top-level MTF panel"), "rest" (everything else, on the
host's sub-page); `part = "master"` with the owner missing adds nothing (the
sub-page has the link and primer). AddWidgetSettings and AddProcSettings
take `opts.modify`: their rows are greyed while it gives false. The owner's
rule (John: "when the top-level is off, the settings that are controlling a
disabled feature should be disabled too"; his screenshot: DBR greyed only
the rows right under Enable): a row is greyed while ANY switch above it is
off, the section's top switch included, also on a page where that switch
is not shown. Live: Blizzard checks a row's greying again only when its
DIRECT parent's setting changes (Blizzard_SettingControls.lua 297-302;
found by DBR). `WatchSettings(initializer, variables)` calls the
initializer's own `AddEvaluateStateCVar` for each variable, which registers
`Settings.SetOnValueChangedCallback` for any setting variable (313-316;
Blizzard_Settings.lua 645), so a grandchild or a slider checks again when
the top switch changes on the same page. AddWidgetSettings and
AddProcSettings take `opts.watch` for it.

- `RegisterSettingsSection{addon, key, title, build}`: a Dyre's AddOn only
  (`ns.InFamily`), key `[%w_]+`; `build(category, layout, ctx) -> true`
  when it added a row. Register no later than ADDON_LOADED; read settings
  only in get, set, and predicates (a host's PLAYER_LOGIN may come first).
  A second registration replaces the first. `SettingsSections(addon)`.
- `AddSettingsSection(category, layout, {addon, key, host, filter, link})`
  on the host's page: the owner's rows ("rows"), else `AddSettingsLink`
  with `link` ("link"): owner not loaded, older owner, build returned
  false, or build failed (pcall; said only in debug mode;
  `SettingsSectionFailures()`).
- ctx: host, owner, key, class (player class file), filter (the host's, as
  given), own, `variable(name)`. Blizzard refuses a variable registered
  twice (Blizzard_SettingsPanel.lua 708-712), so on a host page every
  variable is `DYRE_<HOST>__<name>`; `OwnSettingsContext(addon, key,
  filter)` gives the owner's own page with names unchanged, so one builder
  serves both pages. Both pages' rows use the owner's get and set on its
  live tables; only one page shows at a time, and a page reads its values as
  it draws.
- Primer box (John, 2026-11-27: when a bundled AddOn is missing, "there
  should be a message box on those panels telling people" what they get if
  they install it): `AddSettingsSection`'s `primer` text shows in a box above
  the link only while the owner is missing (no section registered, not
  joined, and `C_AddOns.IsAddOnLoaded` false; an older owner that is loaded
  gets the link alone). `AddSettingsPrimer(category, layout, text)` for any
  page. The row is SettingsTemplates.xml's
  `DyresToolkitSettingsPrimerTemplate` (mixin
  `DyresToolkitSettingsPrimerMixin`, a global in Settings.lua), made with
  `Settings.CreateElementInitializer`, which Blizzard runs securely
  (Blizzard_SettingsInbound.lua 224-228); the height is the template's (86),
  so no function of ours goes on the initializer, and text over
  `SETTINGS_PRIMER_MAX` (400) is cut. The hosts write the text: what the
  missing AddOn adds to that page, and where to get it.

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
  `secretHostile`, `allowDead`, `stopAtName`, `stopAt`, `plateKey`, so WTF's
  tracker, WTF's Control bar, and MTF's chain each keep their own rules.
- Plate keys (2.6.0; John, 2026-11-09, on two WTF player reports; not yet
  checked in client): creature GUIDs are secret in instances, so
  `MobKey(unit)` gives the GUID, else the plate memory's, else
  `plate:nameplateN` (`PlateToken`, `PlateKey`, `KeyPlate`). `FindUnit` takes
  such a key. A holder must drop it at NAME_PLATE_UNIT_REMOVED, because the
  token then may show another mob, and must never keep it past that (the DoT
  tracker's `dead` table holds only real GUIDs). The default locks of the DoT
  tracker and the Control bar set `plateKey`, and so do MTF's own locks (MTF
  1.3.2; its focus lock also takes a secret "can attack"). Without a plate, a mob with a secret GUID gets no row.
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
  marker's side while its icon shows. A player's own place wins (2.6.0;
  John, 2026-11-09, "DIES centered in the middle of the target frame"):
  style `side` "left", "right", "inside", "center", "above", or "below",
  plus `x` and `y` offsets (whole, at most 200), the owner's store keys
  `diesPlace`/`diesX`/`diesY` (target and focus) and `plateDiesPlace`/
  `plateDiesX`/`plateDiesY`; "auto" is the toolkit's choice. Rows keep theirs.
  Also when a shown text of the bar or
  its parent is anchored just outside that edge (GetPoint only, never
  GetLeft or GetCenter; a secret anchor is never compared). Then the other
  side, then inside the bar's right end. A caller's `style.side` wins.
  Platynator keeps its 22 px place (its layout is per design; checked in
  client by John).
- Clipping frames (2.6.0; John's screenshot, 2026-11-09: EllesmereUI's
  target frame showed the block and no DIES): when a frame above the bar
  clips its children (EllesmereUI 9.8.3's bar clip, the whole unit frame),
  the badge and the gate go on a holder made on that frame's parent, at its
  level + 25, shown and hidden with the block (the overlay's OnShow and
  OnHide). The badge is still placed from the bar. Checked in client by John
  on Forever, 2026-11-09: DIES left of EllesmereUI's target frame, in a fight.
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
  WTF 10 above the Debuff Tracker's 5, so a mob is drawn once: a class Tools
  AddOn wins for its class; lead, 2026-11-01),
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

### Profiles (unreleased, 2.10.0; John, 2026-11-15)

A player: "some kind of profile options so I don't have to set it up
separately for each character." John's model (docs/PROFILES.md quotes it
whole): each character has one profile, its own, with today's settings kept;
no switching and no shared profile; copy another character's settings or
the Defaults; export and import as text. An AddOn cannot write files, so
text only. Then John: "what I want is profiles to be entirely owned by the
Toolkit. Settings for every Dyre addon, positions of every widget and visual,
sound selections, everything." So one "Dyre's Toolkit Profile" per
character, with a part per AddOn; each AddOn keeps its live settings in its
own SavedVariables (John chose this); account-wide settings are not in it
(John: "user-centric, not per character"); applied live (John: "Live apply
would be cooler"). The family rule "the engine never owns SavedVariables"
has this exception: the profile copies live in DyresToolkitDB.profiles.

- Profiles.lua: `RegisterProfilePart{addon, title, current, sanitize,
  characterKeys, refresh}` (CONTRACT stays 2; a dependent checks that it
  exists, and without it keeps its own table as today; no account
  SavedVariables line is needed). Register after the SavedVariables load and
  before the frames are built: a part waiting for this AddOn is written then,
  with no refresh. `ProfileParts()`. The profile (`ns.profile`): `Key`,
  `Others`, `Label`, `CopyFrom(key or PROFILE_DEFAULTS)`, `Export`,
  `Import(text)`, `Snapshot`, `Apply`.
- The key (`ns.CharacterKey`): "Name - Realm" from GetRealmName(), else
  UnitFullName's realm, else GetNormalizedRealmName(); with no realm, the
  name alone (2.16.0; vanquishu, CurseForge, 2026-11-27: GetRealmName() gave
  "" on Forever, so the key was nil and import always said "not ready").
  Nil only while the name is not readable.
- Storage: `DyresToolkitDB.profiles["Name - Realm"] = {class, seen, parts =
  {[addon] = settings}, pending = {[addon] = settings}}`, written at each
  registration, after a copy or import, and at PLAYER_LOGOUT. A part of an
  AddOn not loaded now stays; a copied or imported part for it waits in
  `pending`. An entry from a 2.10.0 test build (`settings`) becomes the
  toolkit's part.
- Apply (copy or import): never in combat; all or nothing (every loaded
  part's `sanitize` runs first, in pcall; one failure changes nothing). Each
  part is written into its live table IN PLACE (`WriteInPlace`: cleared and
  filled, nested tables kept), so `spec.store` of widgets, trackers' stores,
  and settings closures see the new values; `characterKeys` are not touched.
  Then each part's `refresh` runs in pcall; a part with none, or whose
  refresh fails, is named in a "Reload to finish" popup (`DYRE_PROFILE_RELOAD`).
  Then every Dyre's settings page (`ns.settingsLayouts`, Settings.lua) has
  each setting's `NotifyUpdate` called (Blizzard_Setting.lua: for "a source
  other than the setting object"). Defaults: every loaded part from `{}`
  through its sanitize; not-loaded parts wait as `{}`.
- `ReapplyWidgets(addon)` (Widgets.lua): repairs a widget's numbers and runs
  Setup again (place, scale, size, opacity), waiting out combat for a
  protected widget. The toolkit's own refresh (`DTT.ApplyProfile`) calls it,
  then RefreshThreat, RefreshBar, ApplyMarkerOrder, ApplyPullDisplay, and
  CheckPetTaunt.
- `ns.AddProfileSettings(category, layout)`, the toolkit's page only: a
  header "Profile: Name - Realm (Class)" (John: not seeing this character
  "is disconcerting"), "Copy settings from" (this character first, marked
  "(this character)" and chosen at first, then Defaults, then the others,
  with class; Copy grey while this character is chosen, John, 2026-11-15)
  with a Copy button at the dropdown's right (John, 2026-11-15; the
  client has no such row, so `AttachRowButton` wraps the row initializer's
  InitFrame and Resetter: the list pools row frames, so the button shows
  only while the frame draws that row; without those methods, a Copy row),
  then "Export profile" and "Import profile". StaticPopups
  `DYRE_PROFILE_COPY`, `_EXPORT`, `_IMPORT`, `_RELOAD` (hasEditBox,
  maxLetters, editBoxWidth: GameDialog.lua on both clients). No popup in
  combat. No per-AddOn Profile section.
- Text: `DYRE2:profile:<data>:<Adler-32>`, the data a table of AddOn folder
  to part; printable, no `|`, no `:` in the data, whitespace ignored on
  import. Parsed by the engine (depth 20, 20000 items, 60000 characters);
  never `loadstring`. A `DYRE1` line (test builds) is refused.
- The toolkit's own part: DyresToolkitCharDB, no `characterKeys`, live
  apply. Each other AddOn adds its part in its own release, at least 24 h
  after the Toolkit, with a `refresh` for live apply (or none, and the
  player is asked to reload).

### Proc cues (unreleased, 2.11.0; John, 2026-11-18)

John: "It would be nice if there was a shared engine that multiple classes
can use for their procs, but the class-specific stuff stayed closer to its
own class-specific addon ... the visual on-screen representation of procs
that make certain abilities hit better is a general need; what those are
vary class to class." He approved: the engine here, the Mage data in Mage
Tools Forever. Procs.lua is ported from Dyre's Shields Up's prototype (its
Procs.lua, uncommitted on 2026-11-18, and its AGENTS.md "Proc cues"): the
design and every rule, not its namespace. A class AddOn passes its procs as
data; the toolkit draws two mirrored arcs (one widget, one arc each side of
the caster) while a proc's buff is up and plays a sound when it appears,
both in combat. Additions only: CONTRACT stays 2, so a dependent checks
that the functions exist.

The client (John, 2026-11-18, after a review of SpellActivationOverlay,
SAO: "DSU is the right home for our 'spell activation overlays'; we already
do this for the shields, which is an activation overlay, across various
classes"; "build the catalog one set of classes at a time, starting with a
simple set of mage, warlock, paladin, and warrior overlays, in DSU"): Dyre's
Shields Up holds every class's proc data and art and is the one caller of
`RegisterProcs`; Mage Tools Forever and Warlock Tools Forever hold none
(their unreleased proc entries moved there). The engine stays here, so
another AddOn can still use it. DSU steps aside when SAO is loaded (John:
"We'll plan to coexist"); that is DSU's rule, not the engine's.

The home moves to Dyre's Buff Reminders (2.12.0; John, 2026-11-20: "I do
not want users to have to go to DBR to change the chime sounds for Overpower
and Revenge, when the visual arc toggle lives in DSU"; DBR is "a better fit
for all buffs/procs (procs are really short-term triggered buffs) chimes and
visuals ... This lets DSU focus on managing just absorption shield
rendering"). DBR 1.13.0 registers the catalog (DSU's and its own Proc
Chimes); DSU 1.5.0 keeps the shields only. The engine's additions
(`PROC_ENGINE_VERSION` 2, a feature test):
- `spec.priority`: the claim's priority (`PROC_OWNER_PRIORITY_HOME` 20 for
  DBR; DSU 1.4 claims at 10).
- The owner gate: a handle draws arcs and plays sounds for a proc only while
  its AddOn owns `proc:<key>` (no Owners, or no owner: yes). It follows
  `OnOwnerChanged`, out of combat (in combat, at PLAYER_REGEN_ENABLED). A
  player with DSU 1.4 and DBR 1.13 sees each proc once, DBR's. Rows of a
  proc another AddOn owns stay, greyed (`AddModifyPredicate`), and their
  tooltip (a function) names it. `handle.Owns(key)` gives owns, owner; the
  debug line says "shown by <addon>, not here".
- `arcOn = false` on a proc: its arc switch starts off (a sound-only proc by
  default); `ProcArcDefault(proc)`.
- `spec.usableSounds = true`: usable procs get a sound (any Dyre's Sounds
  key, `SanitizeUsableProcSound`; soundOn default), played by the engine as
  the spell turns usable on SPELL_UPDATE_USABLE (in combat too), never on
  the first read, at most once per 3 s (rage flicker); a voice says the
  client's spell name. They then claim their kind. Their rows: arc, sound,
  and the sound (no aura filter). Opt-in, because DSU 1.4 has Overpower and
  Revenge while DBR 1.12 plays its own reactive chime: a sound here by
  default would be a second one.

- A proc: `key` (letters, digits, `_`), `label`, `buff` (the client's buff
  name), `class` (class file), `talents` (spell IDs), `ids` (candidate buff
  IDs), `color` {r, g, b}, `sound` (a Dyre's Sounds key), optional
  `tooltip` (extra text for its rows, such as a macro), `stacks` (a
  stacking proc's most stacks; see Stacks below), and `art` (see Art
  below).
- `SanitizeProcs(saved, procs)` -> `{arc = {[key] = bool}, sound = {[key] =
  bool}, sounds = {[key] = soundKey}, position, scale}`; both switches on by
  default; a sound kept only when Dyre's Sounds can make it an aura sound
  (`SanitizeProcSound(key, default)`; without the library the key is kept);
  a broken place dropped. The AddOn calls it from its own SanitizeDB, so the
  table stays in its SavedVariables and its profile part (the family rule:
  the toolkit never owns an AddOn's SavedVariables).
- `SanitizeProcIDs(saved, procs)` -> `{[key] = learned buff ID}` (whole,
  positive, never a talent ID); the AddOn keeps it as a profile
  `characterKeys` entry (data the character found, not a setting).
- `RegisterProcs(spec)` -> handle, or nil when no proc in `spec.procs`
  matches the player's class (then no frame, no events, no rows). spec:
  `addon` (folder), `procs`, `store()` and `learned()` (functions that
  return the AddOn's live tables, so a profile copy written in place is
  seen), optional `title` (default "Proc arcs"), `point` (default CENTER
  0, -20), and `art` (the default for its procs). Once per AddOn (a second call gives the same handle). Call it at
  PLAYER_LOGIN after the AddOn's settings load. One widget per AddOn: key
  `procarcs`, store `store()` (its `position` and `scale`), sizes scale
  only, mouse "unlocked"; while unlocked both sample arcs show, full, in the
  first known proc's color.
- Handle: `Apply()` (after any setting or profile change: arcs rebuilt when
  the IDs changed, sounds registered again, refresh, learn), `Known(key)`,
  `List()`, `Widget()`, `ResetPosition()` (true when there is a widget),
  `Preview(key)` (plays the chosen sound, never in combat), `Report(report)`
  (one line per proc: "<label>: talent known|not known, buff IDs <id>
  (named|confirmed), ..., arcs ready|none, sound registered|off"); also
  `Addon()`, `Store()`, and, for tests and debug, `Frame()` and
  `Container(key, side)` ("left" or "right").
- `AddProcSettings(category, layout, handle, opts)` -> rows by proc key, or
  nil (no settings API, no handle): on the AddOn's own page, a section
  header (`opts.header`, default "Procs") shown only while some proc's
  talent is known; per proc "<label> arc" and "<label> sound" switches and a
  "Sound" dropdown (Dyre's Sounds' aura sounds, its nested menu through
  `SetupMenu(initializer, "aura")`) under the sound switch, each shown only
  while its talent is known, tooltips ending with `proc.tooltip`; variables
  `DYRE_<ADDON>_PROC_<KEY>_ARC`, `_SOUND`, `_SOUND_CHOICE` (uppercase).
  The sound switch's default is `ProcSoundDefault(proc)`: on, unless the
  proc has `soundOn = false` (DSU's Clearcasting, John, 2026-11-20, as DBR's
  "off, the game already plays a sound for it"); `SanitizeProcs` uses it for
  an unset or non-boolean switch, and the setting's default matches.
  Then `AddWidgetSettings` for the arcs ("Proc arc size", Reset size) only
  when a talent is known as the page is built (those rows take no shown
  predicate; a talent learned later shows them after a /reload). Choosing a
  sound plays it once.
- The AddOn's profile `refresh` calls `ReapplyWidgets(addon)` (place, size)
  and then `handle.Apply()`.
- One cue per proc for the family (John, 2026-11-18: Nightfall moves to WTF
  on this engine, while Dyre's Buff Reminders' Proc Chimes has its own
  Nightfall sound): `RegisterProcs` claims the Owners kind
  `PROC_KIND_PREFIX .. key` ("proc:nightfall") for the AddOn at
  `PROC_OWNER_PRIORITY` (10, a class Tools AddOn's) for each proc of the
  player's class. An AddOn with its own copy (DBR) checks `KindOwner` and
  steps aside for a kind another AddOn owns; so the proc keys match DBR's
  `PROC_SOUNDS` keys ("nightfall", "mageclearcasting"). A switch turned off
  keeps the claim (off means off).
- Rules (the prototype's):
  - Auras are never read in combat. A candidate counts only when
    `C_Spell.GetSpellName` names it the buff (a secret name never counts).
    The buff's name is in the client's language (2.11.1, a French player
    report; `BuffName`, exported as `ProcBuffName`): a proc's `buff` is
    English, and a non-English client names the IDs in its own language,
    so nothing matched. A listed ID named `buff` keeps `buff` (English);
    else the first listed ID's name; with no listed IDs (Decimation), the
    talent's name; else `buff`. Never compare a name from the client with
    English text.
    Out of combat (UNIT_AURA for the player, PLAYER_REGEN_ENABLED, each
    Apply), for a known proc with its arc or sound on,
    `GetAuraDataBySpellName("player", BuffName(proc), "HELPFUL").spellId` is saved in
    `learned()` and used from then on. A secret answer is never tested or
    indexed.
  - A talent ID is never a buff ID: the talent's passive aura carries the
    buff's name, so it is never learned, kept, in the arcs' filter, or given
    a sound (in the filter the arcs would show all the time).
  - Talents: `IsPlayerSpell`, else `C_SpellBook.IsSpellKnown`, else
    `IsSpellKnown`, any of the proc's talent IDs; checked again on
    SPELLS_CHANGED (a talent learned later gets its cue, a respec loses it).
    Then by name: a learned spellbook entry (not FutureSpell) named as one
    of those IDs (2.16.0; vanquishu, CurseForge, 2026-11-27: Revenge, usable
    6572, lost its cue after a higher rank was trained, because Forever
    reports only the trained rank's ID as known). So no rank list is needed
    for a usable proc or a ranked talent.
  - Two containers per proc, one per side, from `CreateAuraContainer`
    (the engine on Forever, plain Lua on Era), each slot filter "HELPFUL"
    with `includeSpellIDs` a SET (`{[id] = true}`; a list matched nothing in
    client, DSU's Shield.lua), each side its own table. The engine shows the
    slot while the buff is up, drains a StatusBar with the time left
    (`SetDurationBar`, RemainingTime), and hides it when the buff goes.
  - Containers are made, shown, and hidden only out of combat: the engine's
    slot frames are forbidden to AddOn code in combat (MageProcs, seen in
    client: "calling 'SetScale' on bad self"). A change in combat waits for
    PLAYER_REGEN_ENABLED; the widget frame (ours) shows or hides at once. A
    new ID gets new containers; the old ones are hidden.
  - Sound: `C_UnitAuras.AddAuraSound(Added, {spellID, unitToken "player",
    outputChannel "master", throttleSeconds 1, soundFileName/soundFileID})`
    from Dyre's Sounds' `AuraSound` (the choice, else the proc's default,
    else `DEFAULT_PROC_SOUND` "magical"), once per buff ID; every Apply
    removes the old ones first. During an Encounter restriction
    (`C_RestrictedActions.IsAddOnRestrictionActive(Encounter)`) nothing
    changes; it waits for ADDON_RESTRICTION_STATE_CHANGED (registered only
    with aura sounds, where the event is valid) or PLAYER_REGEN_ENABLED.
    Sounds stay in Dyre's Sounds (global `DyresSounds`, RequireContract(1),
    with Resolve, AuraSound, Play, Choices, SetupMenu); none ship here.
  - Classic Era: no `AddAuraSound`, so no sound and no error; the plain-Lua
    containers still draw the arcs.
  - Events only: no OnUpdate, no timers, no polling (tests/run.lua checks
    the file).
- Art (John, 2026-11-18: "I would prefer if each client of the 'toolkit
  platform' APIs could provide their own artwork instead of having all art
  across all addins baked into the toolkit"; he took the three
  recommendations: a plain fallback here, art per proc with a spec default,
  and the lightning moved to Mage Tools Forever). A proc's `art`, else the
  spec's `art`, is `{right = path, left = path, tint = bool}`:
  - Both paths must be in the registering AddOn's own folder
    (`Interface\AddOns\<addon>\`, matched without regard to case, with
    something after it and no `..`); else the art is ignored. The left file
    is the right one mirrored: a StatusBar sets its fill's texture
    coordinates itself, so the toolkit cannot flip one file.
  - `tint` (default true): the art is white and the proc's color tints it
    (track, bar, and the unlocked samples); false: drawn white-on, in its
    own colors.
  - The game gives AddOn code no way to know whether a texture file exists
    (a missing one draws nothing or green), so each AddOn's own tests check
    its files.
  - Geometry, a contract for every proc art: square (256x256 32-bit TGA
    suggested), the ring center CENTER_X 8/128 in from the flat side, the
    crescent OUTER_SPAN 118/128 of the height, the art within radii 89 to
    118 of 128; ARC_SCALE 1.1 of the 160 ring size (DSU's), so it sits
    outside DSU's shield ring.
  - Resolved once at RegisterProcs; the AddOn's tables are not changed.
- The fallback arcs: Textures/ProcArc.tga (right) and ProcArcLeft.tga
  (left), a plain white crescent (a bright core, a soft glow, thinner and
  fading at the tips), made by scripts/make_proc_arcs.py (pure Python,
  4x4 samples). They take the proc's color. Before, these files were
  lightning (moved to Mage Tools Forever, then to Dyre's Shields Up with
  the proc data), and before that copies of Dyre's Shields
  Up's ShieldArc.tga, whose ratios every proc art keeps.
- Stacks (John, 2026-11-18, from players of other proc AddOns: "Fingers of
  frost procs should drop one side when 1 stack is consumed"): a proc with
  `stacks` N (whole, 2 to 10) shows the left arc from one stack and the
  right arc only at N. AddOn code cannot read the count in combat, so the
  game decides: the right slot's arc and track sit inside a StatusBar (the
  gate, no texture) handed to `button:SetApplicationBar(gate,
  {minApplications = N, maxApplications = N})`; the engine's
  ApplyApplicationBar calls `SetShown(applications >= minApplications)`
  (Blizzard_CustomAuraButton.lua 68-75 and 419-430; options in
  AuraContainerUtilDocumentation.lua; Gethe 943764493e6b). Found through
  MageProcs' GameAura.lua comments (facts only). A client without
  SetApplicationBar, or a call that fails, shows both arcs as before.
  Auras.lua's plain-Lua container has the same gate for Era. The sound also
  registers `Enum.UnitAuraSoundTrigger.ApplicationsIncreased` (1,
  UnitAuraConstantsDocumentation.lua) when the client has it, so a stack
  added plays; a stack used has no trigger: the right arc going is its cue.
  Not checked in client (no Frost Mage to test with; Frost checks never
  hold a release).
- Usable procs (unreleased; Dyre's Shields Up's request, John, 2026-11-19:
  "yes, send it to the coordinator; skip Paladin for now"): Warrior
  Overpower (7384) and Revenge (6572) are not buffs; the game makes the
  ability usable for a few seconds. A proc with `usable` = the rank 1 spell
  ID (whole, positive) needs no `buff`, `ids`, or `talents` (talents
  optional; with none, "known" is the spell itself through the same
  talent check). Read by name (`C_Spell.GetSpellName`, so every rank
  counts) with `C_Spell.IsSpellUsable`, else the global `IsUsableSpell`, at
  every Apply and on SPELL_UPDATE_USABLE (registered only when the AddOn has
  a usable proc of the player's class), also in combat. Usable: "full";
  not usable but short of power (the second return): "dim"
  (`USABLE_DIM_ALPHA` 0.4), so rage does not make it flicker; else "off". A
  secret answer is never compared and changes nothing. Its arcs are two
  textures on the widget's own plain frame (no aura slot), full art in the
  proc's color (its `art`, the spec's, else the plain crescent), shown,
  hidden, and dimmed at once in combat. No aura sound, no learned ID
  (`SanitizeProcIDs` keeps none), and no Owners claim: Dyre's Buff
  Reminders' reactive sounds (Overpower, Revenge) never step aside (DBR
  AGENTS.md "Proc sounds"); a later step may move the sound here with DBR
  stepping aside. Settings: the arc switch only (no sound switch or
  dropdown). `handle.Usable(key)` returns the look and the two textures
  (tests and debug); `Report` says "<label>: spell known|not known, usable
  full|dim|off|not read yet, arcs on|off, sound none (usable proc)".
  DBR's probe (its TESTING.md) found IsSpellUsable readable in combat for
  Revenge; the second return in combat is an open question (TESTING.md).
- Not checked in client yet (TESTING.md "Proc cues"). No dependent uses it
  yet: Dyre's Shields Up adds the catalog in its own release, at least 24 h
  after the Toolkit.

### Tracking engine, stage A (2.5.0; lead plan, 2026-11-01)

The DoT and crowd-control tracking moves here from WTF and MTF in stages
(Dyre's Debuff Tracker's docs/ENGINE_SPLIT.md: A spells, macros, announce,
class data; B `CreateControlTracker`; C the DoT tracker and prediction; D
WTF and MTF switch; E the Debuff Tracker's wrapper). Rules for every
engine: it never owns SavedVariables (the owner passes a `store` table and
keeps its sanitizers and migrations; the one exception, in stage C, is the
learned ticks in `DyresToolkitDB.ticks`); frame names are passed in; class
rules are data; CONTRACT stays 2; WTF 1.4.1 and MTF 1.2.3 keep working.

- Spells.lua: `SpellName(id)` (nil for secret or missing),
  `SpellbookIDsByName()` (byName, learned; FutureSpell is not learned),
  `SpellSet(ids, names, book)` (set, names, known), `IndexSpells(defs)`
  (byID, sets by key, known by key), `KnowsAny(list or set)`,
  `PetKnows(spellID)` (the bank enum, else the legacy call, else the pet
  spellbook by name, as Era needs).
- Macros.lua: `CharacterMacroLimit()`, `MacrosAvailable()` (ok, missing),
  `OutOfCombat(key, fn)` (now, else once at PLAYER_REGEN_ENABLED, the latest
  per key), `CreateMacroKeeper{owned, warn, icon}` (`owned`: the caller's saved
  name -> true table, so "adopted" comes once, not at every login) with `:Available()`, `:Has`,
  `:Write(name, body, oldNames)` ("created", "adopted", "renamed",
  "edited", "unchanged", else nil and "combat", "unavailable", or "full";
  two character slots stay free, warned once), `:Delete(name)`.
  `MarkLine(unit, marker)` and `FocusCastMacro{spell, marker, condition,
  chain, shift, untargeted}`: WTF 1.4.1's Fear, Banish, and Seduction text
  exactly, and MTF 1.2.3's Polymorph text once focus works. Its chained /tm
  is WTF's `[@focus...][@mouseover...][harm,nodead] !5`, not MTF's
  `; `-separated form: the same mob, other text.
  The focus lines (2.9.0; John, 2026-11-12, from MTF player brainsenhh:
  "Once in battle, the polymorph macro doesn't work and the timer doesn't
  show"; the old `/focus [@mouseover,harm,nodead][nocombat,harm,nodead]`
  kept a dead first focus in combat, so `/use [@focus,exists,harm,nodead]`
  failed). The game's /focus (Gethe/wow-ui-source SlashCommands.lua, live
  580, classic_era 576) does `if not target or target == "focus" then
  target = action end; FocusUnit(target)`: a `@focus` clause runs
  FocusUnit(""), which focuses your target, so no clause can keep the
  focus (John's test of `[@focus,harm,nodead]`: "it ignores the fact that
  @focus is set ... and changes focus"). So the line matches only when the
  focus must change: `/focus [@mouseover,harm,nodead][@focus,noharm]
  [@focus,dead]` (John tested in client: "No focus, something targeted or
  mouseover sets focus. Once focus is set, it's locked on, which is what we
  want."). A missing focus matches `noharm` (DQT saw noharm true with no
  unit). The trade-off: with no focus, a friendly or dead target becomes the
  focus (the `/use` line then casts nothing). Before it, only while focus
  works, `/clearfocus [mod:shift][btn:2]` (John: "someone can shift-click,
  clear and retarget something"; 2026-11-13: "make it so the user can use
  shift or right-click to get the switching focus behavior"; `btn:2` is an
  action button's right-click; a key binding is always button 1, so a key
  clears only with Shift; no dead test: "Focus is auto-lost if the mob
  dies"). No `exists` in the focus macros (John, 2026-11-12: "exists is a
  no-op, drop it"; `harm` is false with no unit): `/tm [@focus,harm,
  nodead] !N`, `/use [@focus,harm,nodead] Spell`; MarkLine gives
  `/tm [@unit,harm,nodead] !N`. Kept on purpose: Control.lua's recast
  (`FocusRecastMacro`), DotTracker's focus macros, and the state drivers
  still have `exists` (John, 2026-11-12: "Leave it until we have a reason
  to change it ... don't churn code for no reason"). Do not remove it. Banish and Seduction get both lines; Fear's Shift
  form changes only its `/use`. Lengths: "Polymorph: Turtle" with marker 8
  is 193 with focus, 236 with the Era chain (no /clearfocus there; with it,
  267, over the 255 limit); tests/run.lua checks every control macro fits.
  Other languages (2.11.1, a localization audit, 2026-11-20; John: "Yes,
  fix all three"): a body is bytes, and a Cyrillic or Chinese name takes 2
  or 3 a letter (Shackle Undead in Russian made 268). `FocusCastMacro`
  checks `#body` against `MACRO_MAX_BYTES` (255) and gives up, in order:
  the name after `#showtooltip`, the marker line's fallback, the marker
  line, the Shift and right-click clear. The cast line stays whole; if
  nothing fits, the shortest is written. English macros do not change.
  Seduction (`petFamily` in ClassData): `PetFamilyCondition()` adds
  ",pet:<UnitCreatureFamily("pet")>" as the client names it, since
  `[pet:x]` tests the pet's name or family in the client's language and
  the English "pet:Succubus/Incubus" matched nothing elsewhere. The macro
  is written only while the pet knows the spell (and on UNIT_PET), so the
  pet is out then; a missing, secret, or odd family ([ ] , ; / :) gives
  no pet test. Never put English game names in macro conditions.
- Announce.lua: `RAID_MARKERS` (chat codes `{rt1}`..`{rt8}` since 2.11.1:
  every client knows them; `{moon}` and the other words need the reader's
  client to know the English word), `ValidMarker`, `MarkerCode`,
  `GroupChannel(say)`, `SendChat`, `FormatAnnouncement(text, values)` (MTF's
  values table; false or "" drops the token and the space before it;
  secrets give ""), `CreateAnnouncer{repeatSeconds = 3, say, enabled}` with
  `:SendGroup(key, message)`, throttled per key.
- ClassData.lua: `ClassData` and `ClassSpells(classFile)`: WARLOCK (dots,
  ranks, families, familyOrder, control, macros) and MAGE (control, macros),
  every ID from WTF 1.4.1 and MTF 1.2.3. Agony's ramp is `weights`
  (`TickWeight(family, tick)`), Fear's plate timer `plateTimer`, Seduction's
  pet check `pet`. Polymorph has `single` (one up at a time: a new cast
  replaces the row).
- Every class (the DDT class gate; lead, 2026-11-14, John: "go with your
  recommendations"; the audit is the shared notes'
  ddt-class-spells-audit.md): DRUID, HUNTER, PRIEST, ROGUE, SHAMAN,
  WARRIOR, PALADIN, and Mage's Fireball, Pyroblast, and Frostfire Bolt. Each
  ID is copied from a local file (LibClassicDurations, Good-to-Go Camelot,
  TalentsForeverBook, WhatsTraining, Does It Die Advanced; the file's head
  names each), none guessed, and NONE IS CHECKED IN CLIENT yet (lead
  decision 7): each class's `checks` lists what John checks, and DDT's
  TESTING.md lists them all. Durations are Era's; Forever's are assumed the
  same. The over-time ranks have no base damage (false; option a); a nil
  duration (Lacerate, Frostfire Bolt) counts only from the tooltip; a nil
  level is not in the sources. New family fields: `finisher`,
  `pointDuration`, `late`, `mask`, `ground` (DotPredict below). Left out:
  Wrack (a channel), Gouge and Scatter Shot (short), TBC-only spells.
  Entangling Roots is both a DoT slot and a control bar spell. Warrior's Hamstring (John, 2026-11-17: "add Warrior Hamstring to CC
  abilities that can be on more than one mob, as well as Druid roots"):
  a control bar spell, not `single`, so one row per mob, like Entangling
  Roots; 1715, 7372, 7373, 15 s (LCD; G2G-F and WT have the same ranks).

### Tracking engine, stage B (2.5.0; lead plan, 2026-11-01)

- Owners.lua (lead decision 7a): one owner per kind, as the HealthBars
  sources. Kinds are "control:<CLASS>", "macros:<CLASS>",
  "announce:<CLASS>". `ClaimOwner(kind, addon, priority)` (a second claim
  changes the priority), `SetOwnerEnabled(kind, addon, on)`,
  `KindOwner(kind)`, `IsOwner(kind, addon)`, `OnOwnerChanged(kind,
  callback(owner, kind))`. The highest enabled claim owns; a tie goes to
  the first. A class Tools AddOn claims at 10 and wins for its class; Dyre's
  Debuff Tracker at 5. A listener that fails is off until reload, said only
  in debug mode.
- Control.lua: `FocusRecastMacro(spell)` and `CreateControlTracker(spec)`,
  WTF 1.4.1's Control.lua and MTF 1.2.3's Polymorph.lua merged; their rules
  are its spec (the file's head). The tracker owns the spell sets, the cast
  pipeline (lock at UNIT_SPELLCAST_SENT, land at SUCCEEDED, give back on
  FAILED/INTERRUPTED), rows and their timeouts, binding, focus loss, death
  by GUID, the secure click slots, the Focus box, the nameplate timers, the
  announcements, and the macros; its own event frame. The owner keeps its
  saved table (`store`, read live: enabled, plateTimers, macros, markers, or
  `markerFor`), the anchor's place and moving (`parent`; without one, as
  MTF's widget, the owner places the slot), and its settings pages.
  - Names are passed in: `names.row`, `names.click` (a prefix + index, or a
    table of exact names), `names.focus`. WTF's
    WarlockToolsForeverControlRow<n>/Click<n>/Focus and MTF's
    MageToolsForeverPolymorphBar/MageToolsForeverPolymorph come out exact.
  - Orders are spec fields (lead decision 2a): `find` (FindUnit; default
    the Toolkit's), `lock` (default WTF Control's: focus, mouseover, target,
    plates, with memory, secretHostile, and plateKey), `focusLock` (default
    focus with secretHostile and plateKey). MTF passes `find = {focus,
    target, plates}`, `lock = {focus, mouseover, target; stopAt mouseover;
    plateKey}`, `focusLock = {focus; plateKey, secretHostile}`.
  - A `click` spell cast while focus works is focus-only (its row binds to
    "focus", goes with it, and clicks `FocusRecastMacro`); otherwise rows
    start from the cast and take no click. `single` spells reuse their row.
  - `countdown` (MTF): without focus, a row no unit shows has its name
    count the time down from the last aura read (C_UnitAuras, readable on
    those clients), a 1 s C_Timer only while one shows. `clickThrough`
    (MTF): the slot stays while the bar does, with the mouse only for a click
    or while unlocked.
  - `fixedClick = key` (2.9.3; John, 2026-11-15, MTF player report:
    a Polymorph first cast in combat had no click; "we always use the
    focus target"): the slot's macro does not depend on the mob, so it is
    set once, out of combat, from when you know the spell, not per cast.
    It casts the def's first ID's name (the learned spell). The slot's visibility is a state driver,
    `[@focus,exists,harm,nodead] show; hide` (show while unlocked; hide
    with the bar off or no focus support), so it follows your focus in
    combat. While it can show and no sheep is up, the row shows dimmed
    with your focus's name (FixedSlotShown mirrors the driver; a secret
    "can attack" counts as shown), so no click area is unseen. Cost: with
    a live hostile focus and no sheep, a click on the bar sheeps your
    focus. Overrides `clickThrough` for the slot.
  - Every row click casts the learned spell, `ClickSpell(def)` = the def's
    first ID's name, never the variant you cast (John, 2026-11-15: the
    variants, Pig, Turtle, Cow, the watermelon, come from deciphered
    scrolls in limited supply, and a variant's recast has a strong chance
    of not working). The bar still tracks a variant's sheep.
  - Owners: the tracker claims control, macros, and (with `announce`)
    announce for its class at `priority`. Not the owner: no rows, no
    timers, no announcements, and no macro writes or deletes (the owner
    keeps them). `store.enabled == false` steps aside for control.
  - Macros: a `CreateMacroKeeper{owned}` (the owner's saved table) writes
    each ClassData macro you know (`pet` through PetKnows), out of combat;
    `store.macros == false` deletes ours; `onAdopt(name)` once for another
    AddOn's macro of that name.
  - Methods: `Refresh()`, `SetScale(scale)` (rows, with the slots, out of
    combat), `Rebuild()` (a new look: regions at once, engine slots out of
    combat), `KnowsAny()`, `MacroBody(def)`, `ApplyMacros()`, `IsOwner(what)`,
    `Owner(what)`, `DebugLines()`; fields `rows`, `focusBox`, `plateTimers`.
  - Not the engine's: the anchor and its mover, WTF's own tooltips (pass
    `tooltip`), drag (`onDragStart`/`onDragStop`), and MTF's size widget,
    which calls `SetScale` and `Rebuild` from its onLayout/onOpacity.
- Owner claims are for Dyre's AddOns only (`## Group: DyresToolkit`, the
  HealthBars source gate, `ns.InFamily` in HealthBars.lua): an outside
  AddOn's ClaimOwner and SetOwnerEnabled give false and why.

### Tracking engine, stage C (2.5.0; lead plan, 2026-11-01)

WTF 1.4.1's Tracker.lua, Dots.lua, and Predict.lua, moved with their rules
(each file's head); WTF's tests' cases are ported.

- DotTracker.lua: `HexColor(hex)` and `CreateDotTracker(spec)`. spec:
  `addon`, `priority` (owner kind "dots:<CLASS>"), `class` or `slots`
  (ClassData `dots`), `store` (the owner's db.tracker, read live: enabled,
  theme, sizes.compact/bars, order, health, healthText, panelOpacity,
  position, sections, and each slot's `lastUsed` key, which the tracker
  writes), `names` {target, focus, list} (WTF's WarlockToolsForeverTracker,
  ...TrackerFocus, ...TrackerList), `point`, `slotColor(key)`,
  `panelColor(key)`, `movable` {register(frame, save), beginDrag, endDrag}
  (the owner's layout; `save` writes `store.sections[key]`), `locked()`,
  `ctrlMove`, `predictor`, `find` (default plates, memory, target, focus),
  `lock` (default target, focus, mouseover, plates with stopAtName and
  allowDead), `onSpellsChanged()`. Methods: `Refresh`, `Rebuild` (theme,
  sizes, order, colors, health: out of combat), `ApplyPanelColors`,
  `ApplyPanelOpacity`, `ResetPosition` (after the owner cleared its
  places), `RefreshPrediction(guid)`, `CandidateFilters(key)`,
  `KnowsSlot(key)`, `SlotIcon(key)`, `OrderedSlots()`, `SlotColor(key)`,
  `IsOwner()`, `DebugLines()`; fields `rows`, `pinned`, `sections`, `shown`.
  Every secure change (pinned recasts, state drivers, rebuilds) goes
  through `OutOfCombat`. Not the owner: the sections hide and nothing is
  tracked.
- Smart curse (2.7.0; John, 2026-11-10, from a WTF player comment): the
  Curse slot's ClassData `smart` = {weakness, tongues, elements,
  recklessness} (first ranks; cast by name). A secure click cannot read the
  mob in combat (no macro condition tests mana or class; attributes lock),
  so: Alt Recklessness, Shift Weakness, Ctrl Tongues (else Weakness), no
  modifier the smart pick (`SmartCursePick`: Tongues on a mob with mana
  (`UnitHasMana`: power type 0 with a max above 0; nil for secret), else
  Elements, else Weakness), set out of combat on target, focus, and power
  changes, only when a pick changed. `SmartCurseMacro(names, pick, unit)`.
  `store.curseMode` "smart" makes the pinned Curse slot cast it ("last", the
  default, keeps the last-used recast); the marker (T, E, W on the icon's
  corner) reads the mob at any time, in smart mode, unless
  `store.curseMarker == false`. `names.smartCurse` makes a hidden secure
  button for a CLICK keybind; `onSmartCurse(body)` gives the owner the
  "! Curse" macro body (nil without Weakness: no macro, no click). Methods
  `ApplySmartCurse()`, `SmartCurseBody()`. Not checked in client yet.
- Outline width (2.8.0; John, 2026-11-11, from a WTF player asking to hide
  the border): `store.outlineWidth`, whole pixels 0-20 (`TRACKER_OUTLINE`,
  default 3, the old constant), sets the pinned rows' solid outline; 0 makes
  none. The stacked rows' step is the width + 4, so the default does not move
  anything and 0 closes them up. Read at each pinned row's build: a change
  needs `Rebuild` (out of combat). The rows' tooltip-style edge is not this.
- Hide empty slots (unreleased; treadpool, a DDT player, 2026-11-17:
  "Would be cleaner if it only showed the DoTs that are actively ticking";
  John: "Yes, build it"): `store.hideEmpty` true (`TRACKER_HIDE_EMPTY`, a
  flag owners check before they offer it) draws no placeholders (the dim
  icon, the Bars line and label; `row.placeholders`), so a slot shows only
  while the aura slot shows itself (engine or Auras.lua, also in combat).
  The slots keep their places and do not close up: on Forever the tracker
  cannot read which DoTs are up in combat (the engine draws them), and the
  pinned rows' secure slots move only out of combat. Pinned rows then make
  no secure slots, so no recast clicks and no smart-curse marker: an empty
  slot would be an unseen click area (family rule: a secure button never
  takes clicks unseen). The row (name, health, backdrop) still shows while
  its unit is a live hostile; `panelOpacity` can make the backdrop clear.
  A change needs `Rebuild`. Not checked in client.
- Panel switches (unreleased; a player, 2026-11-19: "Is there a way to
  disable the target dot window or hide it? I like having the focus/ other
  targets but I already have this info on the target window."; John: "a 3
  panels toggle show/off, default to show. A checkbox is fine for now."):
  `store.show[key]` for target, focus, and list (`TRACKER_PANELS`, a flag
  owners check before they offer it); only false hides that panel, also
  while unlocked. The list still leaves out your target and focus, and a
  hidden pinned panel takes no room above the list. A change needs
  `Refresh` (the pinned sections change out of combat). Owners: DDT and WTF
  add three checkboxes, default on, in their own releases (24 h after the
  Toolkit, or gated on the flag).
- Per-panel settings (unreleased; John, 2026-11-21: "The panel settings
  need to be organized by the panel they control, and each needs it's own
  config (size, border width, etc.)"; "The show mob health checkbox, and text
  config ... are missing from the Target/Focus/Others boxes"):
  `store.panels[key]` (key "target", "focus", "list") may hold `health`,
  `healthText`, `frame`, `outlineWidth`, and `sizes` ({compact, bars}, each
  merged field by field over the tracker-wide sizes); nil uses the
  tracker-wide store key (`PanelOption`). Every size helper (`Sizes`,
  `TextScale`, `RowWidth`, `RowHeight`, `RowStep`, `BarIcon`, `NameLine`,
  `SlotSize`, `SlotsWidth`, `PinnedSpacing`, `OutlineWidth`, `ScaleFont`,
  `HealthTextWidth`) takes the panel key; rows use `row.panelKey`. The stack
  follows each pinned panel's own height and outline (`StackOffset`: focus
  below the target's row and outline, the list below the focus's); a list
  growing up sits above the target's outline. `TRACKER_PANEL_OPTIONS` (the
  list of names) is the flag owners check. Combat rules unchanged: frame
  with `ApplyPanelColors` (at once, also in combat), the rest with
  `Rebuild`. Owners: DDT (Panels section, one sub-section per panel); WTF
  no longer has a tracker. Not checked in client.
- Panel frame switch (unreleased; a DDT player, 2026-11-20, GitHub issue
  DDT#1: "I'd like to hide all of that and only show the debuff bars.";
  John: "Build parts 1 and 2"): `store.frame` false draws every tracker row
  (pinned and list) with a clear background and border (`ColorPanel` sets
  the backdrop alphas to 0); anything else draws them. The name, the bars,
  the health fill, and the pinned outline (`outlineWidth`) stay. A change
  needs `ApplyPanelColors` (backdrop colors only, so at once, also in
  combat); a rebuilt row reads it again. `TRACKER_FRAME` is the flag owners
  check before they offer it. Owners: DDT adds a "Show panel frame"
  checkbox, default on; WTF may add one too. Not checked in client.
- Bar orientation (HealthBars.lua `Vertical`; WTF player report,
  2026-11-19: "attempt to compare a secret" from `DrawPrediction` on the
  target bar in combat): a secret `GetOrientation` is never compared; the
  bar's last readable answer is used (a weak-keyed table), else horizontal.
  The same for `GetReverseFill` in `Anchor` (the overlay's last answer
  stands) and the fill's `GetAtlas`/`GetTexture` in `BarArt` (a secret gives
  no bar art, so the caller's look draws). Note: the test mock's SECRET
  errors only when compared with another table (Lua 5.1 calls `__eq` only
  for two tables), so these tests prove the IsSecret paths run, not that
  no string compare is left.
- Grow direction (2.9.2; John, 2026-11-14: "for each frame (Target,
  Focus, Other) we need to be able to set whether the DoTs should grow up
  or down from the origin"; "Keep the name above/below setting we already
  have where it is. The user can chose."): `store.grow[key]` for target,
  focus, and list, "down" (default; anything else) or "up"
  (`TRACKER_GROW`). Up, Bars look: the same block of lines in reverse
  order (PlaceSlot), so the first DoT is the lowest; the name stays where
  `namePosition` puts it. Up, the list (both looks): rows stack upward from
  the list frame's bottom; a list not yet dragged sits above the stack
  (BOTTOMLEFT on the stack's TOPLEFT, PinnedSpacing up), so it never covers
  the pinned rows, and does not follow them. A change needs `Rebuild`. The
  sections keep the toolkit's CENTER saves, so a size change (a new DoT
  learned) still grows a panel both ways from its center.
- The aura confirm (2.10.1; John, 2026-11-16, after the DoT probe below:
  "Yes, build it"; DotTracker.lua, above LockMob). Bug 2 (John, DDT 1.0.1
  on Forever, 2026-11-14: a mouseover Serpent Sting at a mob he was not
  targeting did not show): UNIT_SPELLCAST_SENT gives only a name, and the
  lock stops at the first unit with it, your target first. At SENT the
  tracker also lists the candidates: each live mob you can attack with the
  cast's name on your target, focus, or mouseover (those of the lock's
  units; never other plates: a cast cannot go to a plate you neither target
  nor point at, and a same-named pack on plates must not make every cast
  wait, found by WTF's tests) (by GUID, else plate key; once each, by
  key or plate token), plus the lock's own mob (it may be a corpse). One
  candidate: tracked at success, as before (`bound=single`). Two or more:
  UNIT_AURA is registered on its own frame and one `C_Timer.After`
  (`AURA_CONFIRM_SECONDS` 1.5, DotPredict's PROJECTILE_TRAVEL) starts. The
  first UNIT_AURA on a candidate (MobKey of the event unit, or its plate
  token, matched against those read at SENT, never against what the mouse
  shows now) that adds an aura is the mob (`bound=aura`). Added means
  `addedAuras` secret (Forever: presence only), or a readable entry that is
  secret or is one of your DoT IDs with sourceUnit "player" (Era). No aura
  added in time: a candidate with a row that had any aura event is a
  refresh (`bound=refresh`, nothing new); else the fallback tracks the
  locked mob and the mouseover Twin (`bound=fallback`; the held Twin fix of
  2026-11-14, now only this). A new confirm closes the open one by its
  fallback; PLAYER_REGEN_ENABLED cancels it (`bound=cancelled`); a plate
  that goes drops its candidate. `/ddt debug`'s lastCast line shows
  `candidates=N bound=...`. Evidence (John's `/dtt debug_dots`, Forever,
  open world, solo, 32 casts, 4 with a same-name mouseover): UNIT_AURA came
  0.3-0.9 s after success for the hit mob's plate and/or "target", for no
  other mob, also after the mouse moved on; `addedAuras` secret even out of
  combat. Limits: in a group another player's aura on a candidate in the
  window wins; a mob with no plate that is not your target gives no event
  (the fallback runs). Not checked in client yet: the build itself,
  dungeons (secret GUIDs, plate keys), groups.
- PlateDots.lua: `CreatePlateDots{tracker, store, slots, color}` (store:
  enabled, plateDots, plateDotsOffset, plateDotsOpacity, onPlates);
  `Refresh`, `ApplyColors`, `ApplyOpacity`; fields `byUnit`, `known`. Only
  while its tracker owns the class's DoTs.
- DotPredict.lua: `CombatLogUsable()`, `LearnedTicks()`, and
  `CreateDotPredictor(spec)`: `addon`, `priority` (its HealthBars source),
  `class` or `ranks`/`families`/`familyOrder`, `store` (enabled, plates,
  dies, fill, opacity, outline), `color()`, `legacyTicks`. Where the combat
  log is restricted (Forever), the hidden-ticks path (2.6.0; John,
  2026-11-08; docs/FOREVER_PREDICT.md and the file's head): casts, tooltips,
  UNIT_COMBAT timing and school, the damage meter after combat, and
  `predictor.hidden` true; it never registers the combat log there (the
  client's popup). Nil and "the combat log" only without C_Timer, or why
  RegisterSource refused. `DrawPrediction` takes a secret health (the DIES
  gate: a clip window and a 10000 px StatusBar, Does It Die's method) and
  returns nil for DIES then; a row then puts DIES just left of its health texts (its `secretPlace`; the numbers stay), else at the bar's end. Methods: `Available`, `PredictedDamage(guid)`, `DrawRow(bar,
  guid, health, place)`, `Refresh`, `SetTracker` (DotTracker calls it),
  `DebugLines`. The tick weights are ClassData's (`TickWeight`).
- Every class in DotPredict (the DDT class gate; lead-approved engine items
  3 and 5, plus what option a and the new data need; the file's head):
  a rank with no base gives no first guess (source "waiting") and a saved
  tick is used as saved (no spell power rescale); finishers read combo
  points at UNIT_SPELLCAST_SENT (registered on Era too when a family is a
  finisher; GetComboPoints, else UnitPower; secret: 1 point, nothing
  saved), `pointDuration` sets the length, the tooltip's "N points: X
  damage over Y sec" line the damage, saved ticks per point
  (`ticks[rank].points[n]`, repaired once a session), and the damage meter
  never teaches a finisher; `late` DoTs on the hidden path start at their
  own hit when `direct`, else each slot may come PROJECTILE_TRAVEL (1.5 s,
  Does It Die) late until the first tick, the outcome window grows by the
  same, and a slot timer waits again when the rhythm moved; `mask`
  overrides the school mask; `ground` never starts from a cast on the
  hidden path. The tooltip reader also takes damage with no school word
  ("bleed for 15 damage over 9 sec") and refuses a length under one tick.
  The meter teaches a family with no guess when its tick is above 0. Not
  built: attack power scaling (item 4; seen ticks correct it), Does It
  Die's own combo point count. On Forever, melee swings are physical too,
  so a bleed's slot can take a swing in its window (Does It Die's tight
  windows limit it).
- The learned ticks (lead decision 1, the one engine store):
  `DyresToolkitDB.ticks[rank] = {tick, power}`, repaired once a session
  (tick > 0, power >= 0, a rank some ClassData table lists), shared by every
  Dyre's AddOn. `legacyTicks` (WTF's WarlockToolsForeverAccountDB.ticks) is
  copied once per owner (`DyresToolkitDB.ticksImported[addon]`), only for
  ranks not saved yet.

### Threat, tank tools, and swing timer: moved to DCT (2.16.0; John, 2026-11-26)

From 2.9.0 to 2.15.1 the toolkit held the threat labels and sounds, pull
bars, tank button bar, pull countdown, pet taunt warning, and (2.15.0) the
swing timer. After CurseForge comments that the toolkit made too much noise
for players who wanted only a class AddOn, John moved them to a new AddOn,
Dyre's Threat and Combat Tools (DCT, folder `DyresCombatTools`, CurseForge
1833655). Their design notes and tests moved with the code. The toolkit
keeps:

- `## SavedVariablesPerCharacter: DyresToolkitCharDB` and its old tank,
  threat, and swing keys, untouched: DCT copies them once per character.
  Never sanitize them away here.
- `Bindings.xml` with eight of the nine old `CLICK DyresToolkit*:LeftButton`
  names (one Skull row, mouseover else target; SkullMouseover's row is gone,
  its button stays in DCT for old keys; John, 2026-11-26),
  named in `Bindings.lua` (John, 2026-11-26: "B now, service later"), in
  the key binding category "Dyre's AddOns" (`category` in Bindings.xml;
  John, 2026-11-26: ours "should not be" in the shared AddOns section).
  The client draws a `header` only as a blank gap, never its text
  (classic_era Blizzard_SettingsDefinitions_Frame/Keybindings.lua 189-229:
  a category makes a section, a header a KeybindingSpacer). Every Dyre's
  AddOn with key bindings uses this category. Two AddOns cannot define one
  binding name (John's client: "was attempted to be loaded more than once"),
  so DCT ships no Bindings.xml. DCT makes the buttons with these names. A
  toolkit key-binding service may replace this later.
- The 18 public functions DCT checks (contract 2), and no `DYRESTOOLKITTANK`
  slash key and no claim on DCT's owner kinds (threat, warn:petTaunt,
  tank:markers, tank:pings, tank:pull, tank:pullDisplay). DCT runs only when
  the toolkit is 2.16.0 or later and `SlashCmdList.DYRESTOOLKITTANK` is nil.
- `/dyre` words of the old features (`ns.MOVED_WORDS`) answer one line that
  names `/dct`. The toolkit page ends with an `AddSettingsLink` to
  `DyresCombatTools`, then the Profile section (Core.lua at PLAYER_LOGIN).

### Rules

- Tooltips (John, 2026-11-27: "every one of the tooltips seems to start
  with a good one sentence description, but then has nonsensical follow-on
  text that is clearly not meant for users to see"): ONE plain sentence that
  says what the setting does or what the player sees. No how-to tips,
  commands, combat timing, defaults, internal ownership, or history. A
  second short sentence only when a player would be confused or lose
  something without it. Applied to every toolkit tooltip in 2.17.0.
- Settings rows are pooled and shared with Blizzard's own settings (a
  player's error, 2026-11-19: Blizzard's Status Text setting failed with
  "attempt to compare a secret number value (execution tainted by
  'DyresToolkit')"; the toolkit had replaced `SetupDropdownMenu` on the
  pooled dropdown frames; John chose option A, 2026-11-19). Never replace a
  method on a Blizzard row frame or on a settings initializer, never write a
  field on a Blizzard frame, and never leave a function of ours on one (no
  `getSelectionTextFunc`). Use `hooksecurefunc` only: Blizzard's code runs
  first, untainted, then ours. Per-frame state goes in a weak-keyed table.
  Applied in Widgets.lua
  (`AddDefaultTick`), and Profiles.lua (`AttachRowButton`: InitFrame and
  Resetter hooks). Dyre's Sounds 1.7.2's Menu.lua follows the same rule.
  Not checked in client yet: change Interface > Status Text after opening
  Dyre's pages; no error.
- Frames always start locked at login. Frames move only out of combat.
- The minimap button uses LibDataBroker-1.1 and LibDBIcon-1.0, embedded
  (author: "the standard way"); Forever has no AddOn compartment
  (Blizzard_Minimap.toc loads it for mainline only). LibDBIcon keeps its place
  in `DyresToolkitDB.minimap`.
- Welcome messages (2.14.0; John, 2026-11-23: "Add an option to all of our
  addons to toggle off our welcome messages unless there is an
  error/problem", then "A: one Toolkit switch"): `DyresToolkitDB.welcome`
  (account-wide, default true, not in profiles), the row "Welcome messages
  at login" (`DYRE_WELCOME`) after the minimap switch, and
  `DyresToolkit.ShowWelcome()`. Each Dyre's AddOn asks it (a feature test:
  no function means print) before its title-and-version line and any
  "ready" line; errors and problems always print. The toolkit itself prints
  no welcome line.
- The menu uses MenuUtil.CreateContextMenu (Blizzard_Menu loads for every
  game type).

## Project structure

- Runtime: DyresToolkit.toc, Libs/ (LibStub, CallbackHandler-1.0,
  LibDataBroker-1.1, LibDBIcon-1.0, and Ace3-LICENSE.txt), Core.lua,
  Layout.lua, Widgets.lua, Settings.lua, Profiles.lua, Minimap.lua, Auras.lua, Units.lua,
  Procs.lua, HealthBars.lua, Spells.lua, Macros.lua, Announce.lua, ClassData.lua,
  Owners.lua, Control.lua, DotTracker.lua, PlateDots.lua, DotPredict.lua,
  loaded in that order (SettingsTemplates.xml right after Settings.lua), with Bindings.lua right after Core.lua; Bindings.xml
  (the client loads it); Textures/Stripes.tga; the fallback proc arcs
  (Textures/ProcArc.tga, ProcArcLeft.tga; scripts/make_proc_arcs.py).
- tests/run.lua: the Lua 5.1 mock suite; it loads tests/profiles.lua (the
  profile engine, with its own richer settings and popup mock; restored in
  2.16.0, when tests/tank.lua, which held them, moved to Dyre's Threat and
  Combat Tools) into the same run. tests/test_*.py: the release helpers.
- Package only the TOC, Libs/ files listed in scripts/build_release.py, the
  twenty-seven runtime files, Bindings.xml, the seven textures in
  `MEDIA_FILES` (Stripes, the four icon layers, and the two proc arcs), and
  LICENSE, under `DyresToolkit/`, named
  `DyresToolkit-<version>-forever.zip`, with `release.json` for WowUp.

## Client and API verification

- Target: Forever beta 1.60.1, build 70888 (John's client on 2026-11-11, the
  threat probe; John, 2026-11-13: "verified correct on 11/11"; the release
  scripts say 70888 since then), Lua 5.1. Interface 16001 is not changed:
  70888 has 16001 (John, in client, 2026-11-13:
  `/dump (select(4, GetBuildInfo()))` gave 16001). Pin
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
