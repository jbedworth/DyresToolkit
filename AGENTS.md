# Agent Guidelines

## Project purpose and scope

Dyre's Toolkit is a WoW: Forever library AddOn: the code Dyre's AddOns share
(author-approved, 2026-10-19). Since 2.9.0 it also has features of its own
for every player, the group warnings and tank tools below (John,
2026-11-10: the old rule "It does nothing on its own" is "obsolete now"). It
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
- Announce.lua: `RAID_MARKERS`, `ValidMarker`, `MarkerCode`,
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
  Entangling Roots is both a DoT slot and a control bar spell.

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

### Group warnings and tank tools (2.9.0; John, 2026-11-10)

Dyre's Tank Tools (src/DyresTankTools, never released) moved here whole
(John: "The DTT "tank only" parts also move into DT"), and Dyre's Buff
Reminders' Pet Taunt warning with it, so they are "universally available"
for tanks and non-tanks alike. Files: Tank.lua (the shared table `ns.tank`,
per-character settings, commands, API checks, owners, startup), Threat.lua,
PetTaunt.lua, TankButtons.lua, Pull.lua, TankProbe.lua, GroupSettings.lua,
and Bindings.xml (loaded by the client, not listed in the TOC). Core's
PLAYER_LOGIN calls `ns.InitializeTank` after the toolkit's own settings.

- Settings: `DyresToolkitCharDB` (`## SavedVariablesPerCharacter`; a tank
  and a DPS character want different views), repaired at login
  (`ns.tank.SanitizeDB`). All warnings on by default but solo sounds, each with a switch
  (John: "Warnings on by default, but a user can toggle them off"). Five
  sections on the toolkit's own page (John, 2026-11-12: "Group warnings has
  everything all mixed up; a kitchen sink of settings."): "Threat
  Indicators: Nameplates" (the threat view first, it sets every label and
  sound), "Threat Indicators: Target Frame", "Threat Indicators: Sounds"
  (red, losing, solo), "Group Warnings" (pull bars, the countdown and its
  sounds and sliders, the Pet Taunt warning), and "Tank Tools"; tests check
  the order (`ns.HomeCategory`). The pull slider has the number at its right and the
  gold default mark (`ns.AddDefaultTick`), as every toolkit slider must.
- Tank bar (`barMode`: "auto" default, "always", "never"; John, 2026-11-11:
  "the Tank Bar should show [if] a) Group Role is Tank, b) Warrior Defensive
  Stance, Druid Bear Form, Paladin with Righteous Fury enabled"). Auto is
  Threat.lua's `TankBarWanted`, which is `DTT.TankReasons` (the one rule the
  threat view shares): group role Tank or raid main tank (also with another
  role set), Warrior form ID 18 or spell 71, Druid form 5/8 or Bear Form
  spells, Paladin aura 25780. Events only: UPDATE_SHAPESHIFT_FORM, GROUP_ROSTER_UPDATE,
  PLAYER_ENTERING_WORLD, PLAYER_ROLES_ASSIGNED (where it exists), UNIT_AURA
  on "player" for Paladins only. Show and hide is protected (the bar holds
  secure buttons): out of combat through `DTT.OutOfCombat`, else at the end
  of combat. No state driver: no macro condition covers the role or
  Righteous Fury. A secret answer keeps the bar as it is. Unlocked frames
  show the bar in every mode, to move it. Key bindings work with it hidden.
  Auto is sticky (John, 2026-11-11: "sticky auto with a 30 second delay", so
  stance dancing does not make it flicker): it shows at once, and hides only
  after 30 continuous seconds out of combat with no reason to show. One
  one-shot `C_Timer.NewTimer` (the handle kept; no ticker, no OnUpdate)
  starts when the reasons end out of combat, or at PLAYER_REGEN_ENABLED
  when they are gone then; a reason that comes back, PLAYER_REGEN_DISABLED,
  or Always/Never cancels it; when it fires it checks again (still no reason,
  not in combat). While the role is Tank or raid main tank it never hides.
- Owners (Owners.lua): the toolkit claims "threat", "warn:petTaunt",
  "tank:markers", "tank:pings", and "tank:pull" as "DyresToolkit" at 50,
  above a class Tools AddOn's 10, so an AddOn with its own copy (DBR's Pet
  Taunt warning, for toolkits before 2.9.0) yields. A feature runs only while
  the toolkit owns its kind; a switch turned off keeps the claim (off means
  off, not "let another AddOn do it"). Owners.lua lets the toolkit itself
  claim (its TOC has no Group line).
- Threat labels (Threat.lua's head has the rules): a shield (tank view) or
  crossed swords (DPS/healer view) and the scaled percent beside nameplate
  bars (right by default; left, above, below) and above the target bar.
  Auto, Tank, or DPS/Healer. Auto is exactly the tank bar's rule (John,
  2026-11-11: "Threat label rules should be exactly the same as Tank bar
  rules. Druid in Bear, Paladin with Righteous Fury up, Warrior in Defensive
  Stance or anyone designated Group Tank or Raid Main Tank get the bar and
  are treated like tanks for aggro indicators."; found: his Paladin with
  Righteous Fury had the DPS view, because the view used Protection
  talents): `DTT.TankReasons` true is the tank view, false the DPS view;
  the bar and the view both call it, so they cannot drift apart. No talent,
  pet, or solo rules (removed: Protection talents, the Warlock and Hunter
  pet rules, and "solo without a pet"). Never read talents to decide a role
  (John, 2026-11-11: "Drop any attempt to look at talent builds to
  determine, that was wrong. Especially given the new tendency towards
  hybrid builds that mix Arms, Prot and Fury."): no GetTalentTabInfo and no
  talent events; a hybrid Warrior is a tank in Defensive Stance and not in
  Battle Stance. The tests keep a talents mock only to prove talents have
  no effect. Warlocks and Hunters have the DPS view for now (John,
  2026-11-11: "I'd actually be ok if we just treated Hunters and Warlocks
  like DPS and played with it that way for a while, and build drain-tank
  support later, too."). Later, not built: solo only, a Warlock with the
  Voidwalker out is DPS and the pet tanks; with another pet out the Warlock
  tanks (drain tanking) and the pet is DPS. A Hunter whose pet has Growl or
  another taunt on autocast is DPS and the pet tanks (PetTaunt.lua already
  reads autocast); no pet, DPS. A secret form or aura answer keeps
  the view it had (DPS before any answer). The view follows the reasons at
  once; the bar's 30 s sticky hide is only the bar's. A view change clears
  the label state silently (the sounds bullet). Events: the form, roster,
  role, and world events, and UNIT_AURA on "player" for a Paladin (a
  refresh only when the view changes). Only the Righteous Fury read is
  held; form and stance answers apply at once, in combat too (John's Druid
  test, 2026-11-11: Bear Form in and out in combat gave green and red at
  once; GetShapeshiftFormID and GetShapeshiftFormInfo are not hidden in
  combat). The aura API hides an aura in combat and gives a plain nil, not
  a secret: Dyre's Buff Reminders' Druid probe in John's client
  (DyresBuffReminders TESTING.md:63-68: out of combat
  GetPlayerAuraBySpellID found Mark of the Wild and Thorns and
  `C_Secrets.ShouldSpellAuraBeSecret` said false; at the first UNIT_AURA in
  combat both read "present=no secret=true"), and John's Paladin test
  (Forever 1.60.1 70888, 2026-11-11: Righteous Fury up the whole fight,
  green turned red at 100% after a few swings; UNIT_AURA=46, red view=6).
  So a nil aura read means (Threat.lua HasAura, NotFound): with
  ShouldSpellAuraBeSecret true, a secret, or an error (pcall), hidden, and
  the view and the bar keep what they had (`held`); with it false, "off",
  at once, in combat too; with no C_Secrets or no such function (Era), or
  another answer, hidden in combat (InCombatLockdown) and "off" out of
  combat. A found aura is always true; a secret form or aura answer is
  hidden, as before. PLAYER_REGEN_ENABLED reads the reasons again (the
  lockdown has ended by then; UnitAffectingCombat is not used, its timing
  at that event is not checked), so a real change in combat takes effect
  at combat's end at the latest. `/dtt debug_threat` prints "righteous fury
  reads combat: ..., aura secret ...; calm: ..., aura secret ...; held=N
  view changes in combat=N": the raw C_UnitAuras answer (aura, nil, secret,
  other; or UnitBuff's true, false, secret), ShouldSpellAuraBeSecret's
  answer on every read (true, false, secret, error, other, missing), the
  nil reads held, and the Auto view changes in combat (`DTT.auraReads`,
  `DTT.auraSecretReads`, `DTT.tankCounts`). Not checked in client yet:
  that ShouldSpellAuraBeSecret says false for Righteous Fury out of combat
  (if it says true, a Paladin who clicks it off keeps the tank view).
  Tank view:
  early yellow when another member or pet is at 80% of the pull point;
  blue when another tank holds the mob. A sound when a label turns red
  (`redSound`, default Dyre's Sounds' Bell buzz, else the raid warning;
  below), at most once in 2 seconds, never for a secret status.
- The sounds come from a change of state, not from an event (John,
  2026-11-11: the red sound "fires only about 10% of the time, randomly";
  found: only a threat event could play it, but every update noted the
  color, so when PLAYER_REGEN_DISABLED or a target, form, or roster event
  came first at a pull, the label turned red silently and the threat event
  then saw it already red). Now a label that turns red plays it on any
  update, while audible: a threat event, PLAYER_REGEN_DISABLED, or in
  combat (InCombatLockdown or UnitAffectingCombat). A first reading plays
  too (John, 2026-11-11, after "seen=8 played=4 ... first=5": "If a mob
  attacks me, and threat turns red, I should still hear the chime that I
  got aggro, right?"): a new plate token shown already red, a target change
  onto a mob on you. Two cases stay silent: red after a view change (a form
  or role change clears every label's state and marks it; the player made
  that change), and the same mob already red on another label (the target
  label and the plate where `UnitIsUnit(plate, "target")` reads true; a
  secret or unknown answer counts as a different mob). The 2 s gap, the
  setting, and the secret rule stay. LOSING (3 to 2) still needs a known 3
  before the 2; a secret status clears its last status. Each
  threat event has one argument, unitTarget (UnitDocumentation.lua:
  Forever 70888 4891-4907, Era 70576 3329-3345); for
  UNIT_THREAT_SITUATION_UPDATE it is the unit whose situation changed (often
  "player"), so every plate is read again on it. `DTT.soundCounts` print in
  `/dtt debug_threat`, per mob, not per label: red seen (a mob turned red),
  played, and skipped gap, none, calm (out of combat), then view and same
  (not counted as seen); losing seen, played, gap, none, calm, first (a 2
  with no known 3, or an orange with no known green), and same (DPS: the
  same mob already orange on another label). The view follows the tank bar's rule (Threat.lua
  AutoRole calls `DTT.TankReasons`: a Druid in Bear Form, a Paladin with
  Righteous Fury, or a Warrior in Defensive Stance has the tank view, where
  red means a mob left you; otherwise the DPS view, where red means a mob is
  on you): a link John saw between the bar and the sound is the view, not
  the bar.
- DPS orange (John, 2026-11-13: "Can we make it symmetrical for DPS?
  Green, on threat table, but not 1st or 2nd. Orange, in danger of pulling
  aggro, Red, you pulled aggro. And play the same sounds?"): the DPS view's
  status 1 (more threat than the tank, no aggro) is orange (was yellow) and
  shows the percent, on every plate (the status reads). On a readable
  percent (the target token and the plate of your target), status 0 at
  EARLY_WARNING (80) or more of the pull point is yellow (`VIEWS.dps.early`;
  John, 2026-11-13: "An early yellow for DPS would be nice (no sound, just
  flip it yellow when they get above 80%)"; "A DPS targeting the wrong mob
  will see this on their target and know to back off"); a secret percent
  is not compared, so other plates skip it. "Not 1st or
  2nd" is not read as a rank: a plate's group values are secret on
  Forever, so the rank cannot be known; the status and your own percent
  stand in for it. A change from a known green or yellow (a readable
  status before) to orange plays `losingSound` (Text to Speech "High threat"), with the
  same 2 s gap, setting, and solo rule; a first reading already orange is
  silent (`first`), and the same mob already orange on the other label is
  counted `same` (Threat.lua `SameMob`). Red is unchanged. A view change,
  a plate removed or added, or a label hidden clears `orange`.
- Warning sounds (John, 2026-11-11: "The sound for "turning red" needs to
  be configurable."): "Alert sound (red)" (`redSound`) and "Warning sound (orange)"
  (`losingSound`; it plays at LOSING, orange on a plate; John, 2026-11-13:
  "Use "(orange)" ... Orange is more clear"; it plays at the DPS view's
  orange too) are dropdowns over one list,
  Tank.lua's `DTT.SOUNDS`: None, Raid warning (RAID_WARNING 8959, red's game
  fallback), Quest failed (847, losing's fallback), Ready check (8960), Alarm
  clock (ALARM_CLOCK_WARNING_3 12889), Boss emote (RAID_BOSS_EMOTE_WARNING
  12197), Boss whisper (UI_RAID_BOSS_WHISPER_WARNING 37666), Battleground
  ready (PVP_THROUGH_QUEUE 8459), Map ping (3175). `SOUNDKIT[key]` where it
  is a number, else the number. Every key and number is in
  SoundKitConstants.lua on both clients (Gethe/wow-ui-source forever
  1.60.1 70888 Mainline, classic_era 1.15.9 70576 Vanilla); 847 has no key
  on either (the old `SOUNDKIT.IG_QUEST_FAILED` was always nil), so it plays
  by number. All play on the Master channel. A choice made in the settings
  plays once as a preview, never in combat. Old boolean saves migrate:
  false is "none", true the default (the red one from the old `sound`
  key, which is dropped); a string that is not key-shaped (`[%w_]`, at
  most 64) is the default. These eight and None are the "Game Warnings"
  group.
- Threat sounds when solo (`soloSounds`, checkbox, off by default; John,
  2026-11-12: "super useful in groups, but can get tiresome when solo
  grinding hearing it on every pull"; "Change it to default off. Most
  people, when solo, will not want the sound."; the one warning that is off
  by default): off, the red and losing sounds play
  only while `IsInGroup()` reads true (Threat.lua `Sound`; a secret answer
  counts as solo). The labels still change color. Counted as `solo` in
  `/dtt debug_threat`. Read at each sound, so a change needs no refresh.
- Dyre's Sounds in the warning sounds (John, 2026-11-11: "Keep the sounds
  you found in-game in the "Game Warnings" group, but add all the Dyre's
  Sounds as options."): when `DyresSounds.RequireContract(1)` gives its
  interface with Groups, List, Play, Playable, Resolve, Label, and Parts
  (src/DyresSounds 1.4.0 Sounds.lua; `DTT.SoundLibrary`, read each time),
  both dropdowns list Game Warnings first, then every group of its `Groups()`
  (a sound with no group, Text to Speech, at the top), as a nested menu
  built like its Menu.lua (a submenu per group; the pooled control frames
  are wrapped only for the toolkit's own two dropdowns, and another
  dropdown's label is cleared, as its code does). The plain list (full
  labels) stays where the client has no `Settings.InitDropdown`. A pick
  saves its key through `Resolve` and only when `Playable`; it plays through
  `DyresSounds.Play(key, speech, "Master")`, also as the preview (never in
  combat). Text to Speech is offered: Play takes the words (red: "Aggro
  lost" in the tank view, "Aggro" in the DPS view and the preview; losing:
  "Losing"). A Play that returns false plays the default game sound. Without
  the library, with an older contract, or with a key it does not have, the
  saved key stays (SanitizeDB keeps key-shaped strings), the dropdown shows
  the default as chosen (`EffectiveSound`), and the default game sound
  plays until it is back. No file of Dyre's Sounds is copied or named
  here.
- Default warning sounds (John, 2026-11-11, from his settings: "set these
  as the defaults, I like them fairly well"): `DEFAULT_RED_SOUND`
  "alertbellbuzz" ("Dyre's Alerts: Bell buzz") and `DEFAULT_LOSING_SOUND`
  "alertshake" ("Dyre's Alerts: Cartoon shake"), keys of Dyre's Sounds
  1.5.0's "Dyre's Alerts" group (src/DyresSounds Catalog.lua). Without the
  library, with one before 1.5.0 (no such key: `Resolve` gives nil), or
  with `Playable` false, the default in effect is its game fallback
  (`SOUND_FALLBACK`: the raid warning 8959 for red, quest failed 847 for
  losing; `DefaultSound`), and the menu shows that as chosen; a Play that
  returns false plays the fallback too (`GameFallback`). Toolkit 2.9.0
  ships with or after Dyre's Sounds 1.5.0. The pull tick and go defaults
  stay game sounds.
- Saved sound choices since `soundSaves` 1: only a player's own choice is
  saved; nil is the default (`EffectiveSound(nil, default)`). Picking the
  default key (or the settings' Defaults button, which sets it even
  without the library) saves nil. Before, SanitizeDB always wrote the
  default, so a save could not tell a choice from a default: a save
  without `soundSaves` 1 has its old defaults (red "raidWarning", losing
  "questFailed", pull "countdownTick" and "countdownGo") moved to nil once
  (a player who chose the raid warning in a test build gets the new
  default; the lead asked for this move). Other choices stay.
- Label offsets (John, 2026-11-11: "Can we have an adjustable "Gap
  Distance" slider (minimum) or vertical/horizontal adjustments for the
  Threat indicators?"): `plateX`/`plateY` (nameplate labels) and
  `targetX`/`targetY` (the target label), whole pixels -50 to 50, default
  0, repaired to that (`SanitizeOffset`). They add to the place's own
  offsets (BAR_GAP 4, half of it above and below), so 0 moves nothing; X
  and Y also cover the gap. Each slider shows "N px" and the gold default
  mark (GroupSettings.lua `Slider`, which the pull slider uses too). A move
  re-places every label at once (`RefreshThreat`), also in combat: labels
  are plain frames.
- Label size (John, 2026-11-13: "make the size of the threat indicator
  scale up or down, up to 100% (2x) it's default size"): `plateScale` and
  `targetScale`, whole percent 50 to 200, default 100 (`SanitizeScale`;
  "down" to half is our choice), a slider each ("N%", the gold mark) under
  its section's offsets. Threat.lua `Place` calls `SetScale` on the label
  (icon and text; ICON_SIZE stays 14) and divides the gap and x and y by the
  scale, because a frame's point offsets are in its own scaled units, so
  they stay screen pixels. At once, also in combat. Pull bars are not
  scaled.
- Secret threat values: never compare, concatenate, index, do arithmetic
  on, test for truth, or print a value that may be secret. A secret percent
  shows in white through `SetFormattedText` (`AllowedWhenTainted`);
  `ColorCurve:Evaluate` is `AllowedWhenUntainted`. The icon's shape comes
  from the view, never from a threat value.
- Tinted icons (John, 2026-11-11: "can we make the shield/swords icon
  itself use the color scheme - I realize this means custom images, I'm ok
  with that as long as they are attractive."): Textures/ShieldFill.tga and
  SwordsFill.tga (white to grey, shaded top to bottom, a lit bevel) are
  tinted with `SetVertexColor` from the same constant color as the text
  (green, yellow, red, blue, orange; white for a secret status; never a
  color made from a secret); ShieldEdge.tga and SwordsEdge.tga, a dark
  outline with no tint, lie above them (OVERLAY sublevel 1, `SetAllPoints`
  on the fill), so the icon reads on any background. 64x64 32-bit TGAs,
  drawn by scripts/make_icons.py (pure Python signed distance fields,
  4x4 supersampling; `--preview DIR` writes PNG sheets of all six colors);
  tests/test_icons.py checks them and that the committed files are its
  output. ICON_SIZE stays 14.
- What Forever reads in combat (John's `/dtt debug_threat`, 1.60.1 build
  70888, open world, 2026-11-11): on the "target" token every
  `UnitDetailedThreatSituation` value reads; on a "nameplateN" token every
  one is secret, but `UnitThreatSituation("player", plate)` reads. So the
  color comes from the readable status, and `ReadThreat` falls back to
  `UnitThreatSituation` (the color method; closed). `GetThreatStatusColor`
  and `ColorCurve:Evaluate` fail on the secret status: not used. A plate
  shows its secret percent through `SetFormattedText` in the status color
  (white only when both statuses are secret). The plate of your target reads
  the "target" token instead (`ReadUnit`, when `UnitIsUnit(plate, "target")`
  reads true; a secret keeps the plate token): a readable percent, plus early
  yellow and blue. Other plates lose early yellow and blue (the group's
  values on a plate token count as unknown); the target label keeps them.
  Whether party members' values on the "target" token read is not yet seen
  in client. A dungeon may hide more (TESTING.md).
- Losing a mob (John, 2026-11-11: "To effectively tank, I need a visible
  clue that threat is getting low on a mob -- before the visual clue of it
  turning and beating the healer down."; "Yes, all three, go ahead."): on a
  nameplate in the tank view, status 2 shows the word LOSING in orange (the
  percent is always 100 while you hold the mob); the target label keeps its
  percent and early yellow. Status 3 to 2 on a threat event plays the
  `losingSound` choice (default Cartoon shake, else Quest failed 847; not the red
  sound), once per change, at most once in 2 seconds, never for a secret
  status (only a readable status is kept); None turns it off. Status 2 reads on plates in combat
  (UnitThreatSituation), so this works on Forever plates.
- Pull bars (`pullBars`, "Pull bars under nameplates", on by default): tank
  view, in a party, not a raid. Under each enemy plate's health bar, one
  StatusBar (3 px, 1 px gap, 0-100) per party member in its class color,
  `SetValue` with `UnitDetailedThreatSituation(member, mob)`'s scaled
  percent as it comes, secret or plain, never compared or computed (only
  `type` and `issecretvalue`); no value hides that bar, and the shown bars
  close up. The plate of your target reads the "target" token. No pet bars
  (the Pet Taunt warning covers pets; four bars stay small). Plain frames,
  made at a plate's first show and reused, so they change in combat; events
  only (threat, plate, target, group). A label placed below goes under the
  bars. DIES placed "below" on plates (a player's own place) can overlap
  them; the default places cannot. Not yet proven in client: if
  `/dtt debug_threat` in a group shows party members' values on a plate as
  nil, the bars never show there; then turn the setting off by default and
  say so here. `/dtt debug_threat` prints each party member's and pet's
  values on the target and on the first hostile plate.
- Pet Taunt warning (PetTaunt.lua, DBR 1.5.0's code): in a group where you
  are not the designated tank, Growl, Torment, or Suffering on autocast; a
  message box widget ("DyresToolkitWarning") and a chat line, when it
  becomes true or its text changes and once more as combat starts, at most
  once in 30 seconds; checked out of combat only.
- Marking: AddOn code never calls `SetRaidTarget` (`HasRestrictions`; in
  combat the game blocks it with a popup). Markers come only from the
  game's `/tm` in secure action buttons' macro text, with `!` and `exists`.
  "Next marker" changes its macrotext in a `SecureHandlerWrapScript` OnClick
  pre-snippet, on the release only; the order starts again at
  `PLAYER_REGEN_ENABLED`; the default order leaves out moon (WTF's Banish,
  MTF's Polymorph).
- Pings only from the game's `/ping` in macro text (`C_PingSecure` is
  secure only). Without `SLASH_PING1` (Classic Era) no ping buttons.
- Pull (John, 2026-11-11: "check that [the in-game pull timer] before
  falling back to nothing"): Deadly Boss Mods (`/dbm pull N`), then BigWigs
  (`/pull N`), else the game's `C_PartyInfo.DoCountdown(N) -> success` (both
  clients: PartyInfoDocumentation.lua, Forever 70888 155-170 with
  HasRestrictions and AllowedWhenUntainted, Era 70576 50-64 with
  HasRestrictions). Every member gets START_PLAYER_COUNTDOWN and sees the
  game's countdown with no AddOn. A false return (refused; who may call it
  is not in the UI source: `/countdown` has no leader check, the raid
  manager's button shows only for leader or assist; John recalls leader
  only), or a client without that event, also sends the toolkit's own
  message and shows it here, with a chat line on a refusal. Without
  DoCountdown: the toolkit's message alone. `/dtt pull 0` cancels in each
  path (DoCountdown(0), `/dbm pull 0`, `/pull 0`, the toolkit's CANCEL). The
  toolkit registers no `/pull`.
- What reaches whom (research, 2026-11-11, with sources in the shared notes
  toolkit-2.9.0-pull-countdown-research.md: DBM e903df81, BigWigs
  dccbd7b8): current DBM and BigWigs start a pull only with DoCountdown and
  show one only from START_PLAYER_COUNTDOWN; neither reads the old addon
  formats now (DBM "D5" `Name-Realm\t1\tPT\t<s>\t<areaID>`, D4 `PT\t<s>`,
  BigWigs `P^Pull^<s>`), so the toolkit sends none of them. DBM drops a pull
  from a sender of rank 0 (in a party, anyone but the leader), in combat, in
  PvP or an encounter, under 3 s, or a secret; BigWigs has no rank check
  (an instance ID match), replaces DoCountdown with its own /pull path, and
  hides the game's countdown display for its users. A party member who is
  not the leader therefore reaches BigWigs users and players with no AddOn
  (if the game allows the call) but not DBM users; faking a rank is not
  possible and not tried.
- The pull countdown display (Pull.lua; Owners kind "tank:pullDisplay";
  John: "our own pull timer indicator ... for both tank and party
  members"; round 9: "If we're going to have our own pull experience, it
  should be really good. Otherwise, don't bother."). A widget "Pull
  countdown" (`pullTimer` store; scale and opacity sliders through
  AddWidgetSettings, "Countdown size (%)", "Countdown opacity (%)"; `/dyre
  unlock` shows a sample "10") in the middle of the screen:
  - The number: Friz Quadrata (STANDARD_TEXT_FONT) 72 px THICKOUTLINE with
    a shadow; gold (the toolkit's 1, 0.82, 0) above 3, orange at 3 and 2,
    red at 1. Each second a pop (AnimationGroup: Scale 1.5 to 1 and Alpha 0
    to 1 over 0.2 s, then Alpha to 0.35 from 0.6 s for 0.35 s).
  - The bar: 200 x 6 under it, a 1 px dark edge (the icons' style), in the
    number's color; its length is the time left of the pull's whole length
    (START_PLAYER_COUNTDOWN's totalTime, else the start), and one Scale
    animation (origin LEFT, to 0.001 wide) drains it over the time left +
    0.1 s, so the engine moves it; code only sets its color each second.
  - The line: "Pull in N - Name" (16 px, gold) when the source names the
    starter (the game event's initiatedByName, the addon message's
    sender, your own name for your pull); a secret name is never shown;
    realm dropped on yours, "|" and control characters removed, 24
    characters at most. ASCII " - " (the font's dash support is not
    checked).
  - At 0: "PULL!" (60 px, green) grows 0.7x to 1.6x over 1 s and fades
    from 0.4 s for 0.6 s; its OnFinished hides the display. A cancel
    (CANCEL_PLAYER_COUNTDOWN, a 0 message, `/dtt pull 0`) shows "Pull
    cancelled" (28 px, grey) for 1 s, fading for 0.6 s, then hides; a
    cancel with nothing running shows nothing.
  - Sounds: "Countdown tick sound" (`pullTick`, default Countdown tick,
    UI_BATTLEGROUND_COUNTDOWN_TIMER 25477) on each of the last 5 seconds,
    and "Countdown go sound" (`pullGo`, default Countdown go,
    UI_BATTLEGROUND_COUNTDOWN_FINISHED 25478) at 0, each from the same menu
    as the warning sounds (Game Warnings, which now also lists these two,
    then Dyre's Sounds; None). Text to Speech says the number and "Pull".
    Five ticks, not 3-2-1: the game's own countdown and DBM's and BigWigs'
    count the last 5, and the color already marks 3 to 1.
  - It starts on START_PLAYER_COUNTDOWN (initiatedBy, timeRemaining,
    totalTime, informChat, initiatedByName; WorldStateInfoDocumentation.lua
    on both clients; Forever flags it SecretInChatMessagingLockdown, so a
    secret time is ignored), on CHAT_MSG_ADDON from "D5"/"D4" (a "PT"
    field, older DBM), "BigWigs" (`P^Pull^<s>`, older BigWigs), and its own
    prefix "DyresToolkit" (`1\tPULL\t<s>`, `1\tCANCEL`). It registers those
    prefixes itself. A start within 1 s with about the same end is the same
    pull (a later source may name the starter); combat does not cancel it;
    over 300 s is ignored. Code runs once a second: one `C_Timer.NewTimer`
    at a time (the handle kept), never OnUpdate or a ticker; the motion is
    AnimationGroups.
  - The design rule for the pull display (John, 2026-11-11): "We sit
    between other addons and the default experience, only." Never
    override, hook, hide, or change another AddOn's display or settings
    (its frames, its functions, its saved options). The toolkit replaces
    only the game's default countdown, and only when no boss mod shows one.
  - `pullDisplay`, "Dyre's countdown on screen", is a checkbox, on by
    default, and only about this display, never the send path (sending has
    no setting and always takes the best path above). On: it shows only
    when no boss mod shows a pull (`BossModShowingPull`, read at each
    pull): BigWigs loaded always shows its own (its pull bar has no switch:
    Plugins/Pull.lua 429 at dccbd7b8; its chat line always prints, 418), so
    Dyre's steps aside; DBM-Core loaded shows its own unless DBM's own "Do
    not show Pull/Break Timer bar" is on (`DBM.Options.DontShowPT2`,
    DBM-Core/modules/objects/CoreOptions.lua 418 at e903df81; /dbm > Global
    Disables & Filters > Disable DBM Features). With it on (and no
    BigWigs), DBM is not "the" pull timer (John: "If DBM is installed and
    configured to be "the" pull timer, let it."), so Dyre's shows and takes
    the game's countdown (DBM draws no center numbers of its own and never
    touches TimerTracker). `DBM.Options` is read with rawget, fresh each
    time, never written, no hook; a missing or odd table counts as DBM
    showing its own. DBM fires no event when an option changes, so the
    game's countdown is matched to it at login, PLAYER_ENTERING_WORLD,
    GROUP_ROSTER_UPDATE, ADDON_LOADED, and after each START_PLAYER_COUNTDOWN
    (for the next pull; the first pull after a change may show the game's
    numbers or none). DBM's countdown voice may still play: its
    DontPlayPTCountdown option is noted in its own code as not working
    (PBC.lua 11). Research: shared notes
    toolkit-2.9.0-bossmod-pull-settings.md. Off: never. Older saves: "auto"
    and "always" are on, "never" off ("Always" is gone: John, "DBM/Bigwigs
    ... results in two timers at once"). Its tooltip: a Sending part, an On
    screen part, one line on DBM's two options with the menu path, and one
    line that BigWigs always shows its own pull bar.
  - In place of the game's own countdown (John: "Yes, send it"): while it
    shows (no boss mod showing a pull), the toolkit unregisters
    START_PLAYER_COUNTDOWN and CANCEL_PLAYER_COUNTDOWN from TimerTracker,
    as BigWigs does (Loader.lua 1232-1233 at dccbd7b8, at its load). Only
    those two registrations (where the client has the events): no function
    replaced, no frame shown, hidden, or moved, nothing protected touched;
    TimerTracker's PvP and Challenge Mode timers stay. Done out of combat
    (`DTT.OutOfCombat("gameCountdown")`; a change in combat waits). They are
    registered again when it is turned off, when DBM's pull bar is on, or
    when DBM loads later (ADDON_LOADED), but never over BigWigs (its loader
    took them itself, with no condition, and never gives them back).
    The game's chat line "<name> started a countdown" (informChat) goes with
    them, as with BigWigs; the line under the bar names the starter
    instead. Not seen in client yet: that this taints nothing (TESTING.md).
- The game's own countdown display (Blizzard_FrameXML Timer.lua and
  Timer.xml, identical on Forever 70888 and Era 70576, loaded by
  Blizzard_FrameXML.toc and Blizzard_FrameXML_Vanilla.toc): TimerTracker
  registers START_PLAYER_COUNTDOWN and CANCEL_PLAYER_COUNTDOWN (lines
  48-50) and starts a PlayerCountdown timer (181-196; TIMER_DATA line 6: a
  bar from 31 s, big numbers under 11 s, sounds). So a player without a boss
  mod would see the game's numbers and Dyre's countdown at once (BigWigs
  unregisters TimerTracker for its users); since round 9 Dyre's countdown
  takes the game's place (above). On Era, TIMER_DATA's PlayerCountdown sound kits
  (UI_COUNTDOWN_TIMER and friends) are not in its SoundKitConstants, so
  they are nil there; the big-number tick falls back to
  UI_BATTLEGROUND_COUNTDOWN_TIMER (lines 325-329).
- Group boss mods, heard only (John, 2026-11-11: "build the version list
  too"): `/dtt debug` lists each other group member and what was heard from
  it. The toolkit sends nothing for it (no hello, no reply). DBM's "D5"
  V (`<Name-Realm>\t<protocol>\tV\t<revision>\t<release>\t<display>...`,
  field 6) gives "DBM <display>"; BigWigs' `Q^<version>^...` or
  `V^<version>^...` gives "BigWigs <version>" (version 0 is DBM's query and
  is skipped); a D5 hello (`\tH\t`) alone gives "DBM or BigWigs"; a toolkit
  pull message gives "Dyre's Toolkit"; nothing heard gives "unknown" (most
  toolkit users). Each boss mod can fake the other's reply, so this is what
  was heard, not proof. Only PARTY, RAID, and INSTANCE_CHAT count (not
  GUILD's GV). Keys are `Ambiguate(sender, "none")`, the form
  `GetUnitName(unit, true)` gives; a member not in the group at
  GROUP_ROSTER_UPDATE is dropped. Payloads are data: patterns only, never
  run; a secret field skips the message; stored text has "|" and control
  characters removed and is cut to 24 characters. The prefixes are the ones
  the display registers (only where `C_ChatInfo.RegisterAddonMessagePrefix`
  exists).
- The bar is a widget (`mouse = "always"`, each button a drag handle); secure
  frames change only out of combat (`ns.tank.OutOfCombat`, the toolkit's
  queue). Buttons and bindings are named `DyresToolkit<Name>`.
- Commands: `/dyre pull [seconds]`, `/dyre tank_reset`, `/dyre tank_debug`,
  `/dyre threat_debug`, `/dyre taunt_debug` (Core asks
  `ns.HandleTankCommand` first); `/dtt` and `/tanktools` keep Dyre's Tank
  Tools' words (`/dtt pull 10`, `/dtt reset`, `/dtt debug`,
  `/dtt debug_threat`, `/dtt debug_taunts`; `/dtt` alone opens the
  settings). The login is quiet; a command says why a feature is off.
- Taunt probe (TankProbe.lua, end; John, 2026-11-12: "Can we announce with
  either an emote or in party chat when someone other than the tank
  taunts, growls, pops Righteous Fury, etc.?" ... "Yes, probe first, then
  build it. The list is a good starting point, at least, if not
  complete."). Built: the probe only, `/dtt debug_taunts` (and a summary
  line in `/dtt debug`). UNIT_SPELLCAST_SUCCEEDED through
  `RegisterUnitEvent`, two units per frame (player; pet; party1-2;
  party3-4; partypet1-2; partypet3-4), so a frame's unit kind is known
  even when the unit argument is secret; without RegisterUnitEvent, one
  frame with RegisterEvent keeps only those tokens (a secret unit is not
  counted there). Each registration's pcall result is printed. Counts per
  kind (player, pet, party, partypet), in combat (InCombatLockdown) and
  out: events, spellRead, spellSecret, spellOther (no number), nameSecret,
  guidSecret, unitSecret. Watched by name, from `C_Spell.GetSpellName` (or
  GetSpellInfo) of a readable spell ID, against each listed rank-1 ID's
  name in the client's language and its English name (`TAUNT_WATCH`):
  Taunt 355, Mocking Blow 694, Challenging Shout 1161, Growl 2649,
  Challenging Roar 5209, Torment 3716, Suffering 17735, Distracting Shot
  20736, Righteous Fury 25780, Defensive Stance 71. Matches per name and
  kind, and the last 10 (time, combat, unit token or "secret", spell; no
  player names), in session memory only: nothing is saved and nothing is
  sent. Known before it (not tested again): an emote is blocked when sent
  from a spell event (WarlockToolsForever TESTING.md:179), so no emote;
  party chat from UNIT_SPELLCAST_SUCCEEDED works (WTF TESTING.md:55-56);
  your own spell IDs read in combat (DCC AGENTS.md:34, WTF
  TESTING.md:199-200). Unknown, the probe's question: whether party
  members' and party pets' arguments read in combat on Forever.
  Later design, not built (waits for John's probe output): only the
  designated tank's toolkit announces (`GroupTank("player")`); by default
  only the tank sees it (on screen and a chat line); party chat is a
  setting, off by default; at most one announcement per player and spell
  in 10 seconds.
- Never register `COMBAT_LOG_EVENT_UNFILTERED`. No popups in combat. No
  `OnUpdate`. Unknown events register only where `C_EventUtils.IsEventValid`
  says they exist (Era lacks some).

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
  HealthBars.lua, Spells.lua, Macros.lua, Announce.lua, ClassData.lua,
  Owners.lua, Control.lua, DotTracker.lua, PlateDots.lua, DotPredict.lua,
  Tank.lua, Threat.lua, PetTaunt.lua, TankButtons.lua, Pull.lua,
  TankProbe.lua, GroupSettings.lua, loaded in that order; Bindings.xml (the
  client loads it); Textures/Stripes.tga and the threat icons
  (Textures/ShieldFill.tga, ShieldEdge.tga, SwordsFill.tga,
  SwordsEdge.tga; scripts/make_icons.py).
- tests/run.lua: the Lua 5.1 mock suite; it loads tests/tank.lua (the group
  warnings and tank tools, with their own richer client mock, ported from
  Dyre's Tank Tools) into the same run. tests/test_*.py: the release helpers.
- Package only the TOC, Libs/ files listed in scripts/build_release.py, the
  twenty-four runtime files, Bindings.xml, the five textures in
  `MEDIA_FILES` (Stripes and the four icon layers), and LICENSE, under `DyresToolkit/`, named
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
