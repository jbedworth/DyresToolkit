# Testing

## Method

1. **Pinned source review.** Client behavior is read from Blizzard's UI source
   at Gethe/wow-ui-source `943764493e6b16d63ded3ab304150d1f05e58b57`.
2. **Automated mock tests.** `tests/run.lua` exercises the interface, saved
   settings repair, locking, dragging and snapping (neighbors, Shift groups,
   the grid), the settings home, commands, and the minimap button against a
   small mock of the client. The Python tests cover the release helpers.
3. **In-client checks.** The checklist below covers what mocks cannot.

## Source findings

- Settings sub-pages draw recursively (Blizzard_CategoryList.lua,
  CreateSection), so Dyre's AddOns → an AddOn → its own pages displays.
- The AddOn list nests a child whose `## Group` equals a parent's folder name;
  a child whose parent is missing shows at the top level (AddonList.lua).
- Forever loads no AddOn compartment (Blizzard_Minimap.toc: mainline only), so
  the minimap button is LibDBIcon's. MenuUtil loads for every game type.

## In-client checklist

- [ ] The AddOn list shows a "Dyre's AddOns" section with Dyre's Toolkit, and
      every installed Dyre's AddOn nested under it.
- [ ] Options → AddOns → Dyre's AddOns shows the toolkit's settings, with each
      Dyre's AddOn's page under it (MTF's and WTF's own pages one level
      deeper).
- [ ] The minimap button shows; left-click unlocks every Dyre's AddOn's frames
      with one chat line; right-click opens the menu; each AddOn entry opens
      its page.
- [ ] While unlocked, the grid shows; a frame from one AddOn snaps beside a
      frame from another; Shift-drag moves a snapped group.
- [ ] "Snap to the grid": near a red center line a dropped frame centers on
      it, or puts an edge on it; elsewhere an edge within a quarter of the grid size of a grey line
      lines up with it, and farther away the frame stays put; near another Dyre's frame it snaps to the frame instead; a
      Shift-dragged group lines up as one block. Changing "Grid size" redraws
      the grid.
- [ ] Ctrl held as you drop: the frame stays exactly there, also beside
      another frame or near a grid line; Shift+Ctrl moves a group unsnapped.
- [ ] After /reload, frames start locked and stay where they were dropped.
- [ ] In combat, /dyre opens nothing and says so; a drag ends after combat.

### 2.18.0: button bars

- [ ] MTF Conjure and Portals: Layout Vertical stacks the buttons top to
      bottom; the bar stays in place; Horizontal brings the row back.
- [ ] Changed in combat: applies when combat ends; no "blocked" error.
- [ ] /reload and a relog keep the choice; a profile copy brings it.
- [ ] /dyre unlock: a rotate arrow on each bar's outline (top-right); a click
      flips it; the arrow texture shows (not green); the Layout row agrees.

### 2.17.0: settings sections

- [ ] With MTF and DBR (both with sections): MTF's Cooldown Chimes page shows
      the Mage chimes, not a button; a switch turned off there is off on
      DBR's page and in play, and back on from DBR's page.
- [ ] Without DBR: MTF's Cooldown Chimes page shows the primer box (gold
      edge, dark box, the host's text, not cut off) above the greyed "Open
      Buff Reminders settings" button. No Lua error. A full client restart
      is needed first (new file SettingsTemplates.xml).
- [ ] Settings search for a chime name finds it (once per page); no taint
      error when typing in the search box (the Discord one is Blizzard's).

### 2.16.0: threat, tank, and swing moved to Dyre's Threat and Combat Tools

Install the 2.16.0 test build. All checked by John on Forever, 2026-11-26, with DCT 1.0.0. The tank, threat, and swing checks moved to
Dyre's Threat and Combat Tools' TESTING.md.

- [x] Without Dyre's Threat and Combat Tools: no threat labels, no threat
      sounds, no tank bar, no swing timer, no pet taunt warning. No Lua error.
- [x] `/dyre pull` (and `/dyre debug_threat`, `/dyre tank_reset`,
      `/dyre debug_swing`): one line saying these moved, naming `/dct`.
- [x] `/dyre` page: no threat, tank, or swing sections; a "Threat, tank tools,
      and swing timer" row with an Open button before the Profile section.
      Without DCT, the button explains where to get it; with DCT, it opens its
      page.
- [x] Key Bindings: a "Dyre's AddOns" section (not in AddOns) with the eight
      tank buttons (one Skull row), shown once, and no "loaded more than once"
      warning at login (DCT without its own Bindings.xml).
- [x] A key bound to Skull before the update still skulls your target with
      DCT installed, after `/reload` and after a relog.
- [x] With DCT: its settings arrive from the old toolkit settings (threat
      view, sounds, bar mode, swing Show), once per character.

### 2.16.0 fixes (vanquishu's report)

- [ ] Warrior with Revenge rank 2 or later trained: Revenge's arc shows as it
      turns usable (Dyre's Buff Reminders); the proc report (`handle.Report`)
      says "spell known".
- [ ] Profiles: Export, then Import of that line on the same character works
      (no "not ready yet"). `/dump GetRealmName()` shows whether this client
      gives a realm; the profile header shows the key used.

### Proc cues (unreleased, 2.11.0)

Not checked in client yet. Needs a class AddOn that registers procs (Mage
Tools Forever with Missile Barrage, or Dyre's Shields Up's prototype moved
to the toolkit), Dyre's Sounds installed, and a Mage with the talent.

2.12.0 (with Dyre's Buff Reminders 1.13.0 and Dyre's Shields Up 1.4.x or 1.5.0):
- [ ] With DSU 1.4.x and DBR 1.13.0 both loaded: each proc shows one pair of
      arcs and one sound (DBR's); DSU's proc rows are greyed and name DBR.
- [ ] With DSU 1.4.x and DBR 1.12.x (Toolkit 2.12.0 first): nothing changes;
      Overpower and Revenge sound once (DBR's chime), arcs from DSU.
- [ ] Warrior with DBR 1.13.0: Overpower's sound plays as it becomes usable,
      in combat too, not again for rage flicker within 3 s; its arc and sound
      rows sit together.
- [ ] A proc with arcOn = false (DBR's Nature's Grace): sound, no arcs, until
      its arc switch is turned on.

- [ ] Forever, out of combat: when Missile Barrage procs, both arcs show,
      one each side of the character, in the proc's color, and drain with
      the time left; casting Arcane Missiles hides both at once. With Dyre's
      Shields Up's catalog the arcs are its art; an AddOn with no art of
      its own gets the plain crescent.
- [ ] Forever, in combat (a fight long enough for several procs): the arcs
      show and drain on both sides; no Lua error and no taint blamed on
      DyresToolkit (`/console taintLog 1` or BugSack).
- [ ] The sound plays as the buff appears, out of combat and in combat, once
      per proc (not once per arc); the sound switch off silences it; a new
      choice in the dropdown plays once and is then the proc sound.
- [ ] The buff ID is learned: after the first proc out of combat, the class
      AddOn's debug line (handle `Report`) says "(confirmed)" for an ID,
      and after /reload the arcs show from the first proc on.
- [ ] A non-English client (2.11.1; French if a player can check): the arcs
      and the sound show for a proc, and the debug line lists "(named)" IDs.
- [ ] Without the talent the "Procs" header and rows are hidden; after
      learning it (no reload) they show. "Proc arc size" shows only when
      the talent was known as the page was built.
- [ ] A stacking proc (Fingers of Frost, `stacks` 2; never holds a release:
      no Frost Mage to test with): at two charges both arcs show; after one
      Ice Lance only the left arc shows; a new proc back to two shows the
      right arc again and plays the sound; in combat too. No Lua error.
- [ ] `/dyre unlock` shows both sample arcs, full, to drag; the size slider
      grows the gap with them; reset puts them back under the character.
- [ ] In a boss encounter, changing the sound waits until the encounter
      ends, then the new sound plays.
- [ ] Classic Era: Missile Barrage is Forever only, so nothing shows and no
      Lua error. A proc the Era client has shows its arcs with the buff
      (plain-Lua containers) and plays no sound.
- [ ] Usable procs (Warrior Overpower 7384 and Revenge 6572, from Dyre's
      Shields Up): after a dodge (Overpower) or a block, dodge, or parry
      (Revenge), both arcs show full in combat; they go when the window
      closes or you use the ability. Open question: does `IsSpellUsable`'s
      second return (short of power) read in combat? If yes, the arcs dim
      while rage is short instead of flickering; if it is secret or always
      false, they hide then (note what you see). No sound from the engine:
      Dyre's Buff Reminders still plays its own. `/dsu debug_procs` shows
      "usable full|dim|off". No Lua error, no taint.

### Profiles (2.10.0)

Not checked in client yet.

- [ ] The header says "Profile: <Name> - <Realm> (<Class>)" for this
      character.
- [ ] "Copy settings from" shows this character first, "(this character)",
      chosen, and Copy is grey. Pick Defaults or another character: Copy
      turns on. Pick this character again: Copy is grey.
- [ ] Log in on two characters. On the second, Profile > "Copy settings
      from" lists the first with its class, and "Defaults (a clean slate)".
- [ ] The Copy button is at the right of the dropdown, on the same row, and
      does not cover anything. Scroll the page up and down, and open another
      Dyre's AddOns page: no Copy button shows on any other row.
- [ ] Copy with the settings page open: the popup names both characters;
      "Copy" does NOT reload. At once, the threat, group warning, and tank
      tool settings are the first character's, and the page's controls show
      the new values. The tank bar, warning box, and pull countdown move to
      the first character's places and sizes (`/dyre unlock` to see them).
      The layout settings at the top did not change. Chat: "Profile copied."
- [ ] Copy Defaults: everything back to the defaults, at once.
- [ ] After a copy, the threat labels, tank bar mode, marker order, and
      sounds behave as the copied settings say, with no reload.
- [ ] A change on a character, then logout and login on another: the copy
      has the change (the snapshot at logout).
- [ ] Export: the popup shows one line, selected; Ctrl+C copies it; typing
      does not change it. Import it on another character: it applies at
      once, with no reload. A long line fits (no cut-off).
- [ ] Import of bad text: the popup stays open and chat says why.
- [ ] In combat the settings do not open (no popup in combat).
- [ ] Era: the same, with no Lua error.

### Shared tracker code (2.4.0)

Mocks cannot prove these; check them once a dependent uses the modules.

- [ ] Both clients load Dyre's Toolkit 2.4.0 with no Lua errors, and every
      Dyre's AddOn behaves as on 2.3.1 (none uses the new modules yet).
- [ ] Era: a plain-Lua aura container shows your debuff on your target, with
      the time left counting down, and hides when it ends.
- [ ] Forever, before any switch-over: an AuraContainer made by toolkit code
      shows your auras in combat, and no error or taint names DyresToolkit.
- [ ] Era: `/focus` leaves `DyresToolkitDB.focusWorks` nil. Forever: the first
      focus sets it true; a reload keeps it.
- [ ] The block and DIES draw on Blizzard's target frame and nameplates, and
      on each installed frame AddOn's bars, as WTF 1.4.0's did.
- [ ] HealthBars API: with `/run` registering an adapter that returns
      `TargetFrame.healthbar` and `side = "right"`, DIES shows right of the
      target frame's bar; one that errors leaves Blizzard's placement, says
      nothing, and `/dyre debug` then lists it.
- [ ] Threat Plates with its target-of-target text on, in combat, and Plater with
      its cast target name right of the cast bar: DIES shows left
      of the bar (or inside it), not over the text; with a raid marker
      left of the bar too, inside the bar's right end.
