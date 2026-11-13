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

### Group warnings and tank tools (2.9.0)

Ported from Dyre's Tank Tools' checklist; none is checked in client yet.

#### Threat sounds when solo

- [ ] Solo, "Threat sounds when solo" off (the default; also on a character
      that had a test build): pull a mob; the label turns red with no
      sound. `/dtt debug_threat` shows `soloSounds=false` and `solo=1` (or
      more) on the red line.
- [ ] Join a party with it still off: the red sound plays on a pull.
- [ ] Turn it on: solo pulls play the red sound.

#### Load (both clients)

- [ ] No Lua errors at login with `/console scriptErrors 1`, and no chat line
      from the toolkit. With Dyre's Tank Tools also installed, disable it
      first: both would show labels and bind the same keys.
- [ ] Options > AddOns > Dyre's AddOns shows, in order, "Threat Indicators:
      Nameplates", "Threat Indicators: Target Frame", "Threat Indicators:
      Sounds", "Group Warnings", and "Tank Tools" (John, 2026-11-12), each
      with only its own settings. "Threat on Target Frame" is the target
      label's name.
- [ ] The "Pull countdown (seconds)" slider shows its number (for example
      "10 s") at the right, and a gold mark at 10.

#### Tank bar (both clients)

- [ ] Tank button bar on "Auto (tank only)": a Warrior's bar shows at once
      in Defensive Stance; in Battle or Berserker Stance it hides after 30
      seconds out of combat, not before.
- [ ] Stance dancing (out of Defensive Stance and back within 30 seconds, a
      few times): the bar does not flicker.
- [ ] A fight that starts during the 30 seconds: the bar stays in combat,
      and hides 30 seconds after the fight ends.
- [ ] A Druid's bar shows in Bear Form (Dire Bear Form too) and hides 30
      seconds out of it.
- [ ] A Paladin's bar shows with Righteous Fury and hides 30 seconds after
      it ends or is cancelled.
- [ ] A Mage or Priest with the Tank role in a group (or a raid's main tank):
      the bar shows and never hides while the role stays; it hides 30 seconds
      after the role changes or the group ends.
- [ ] Defensive Stance taken in combat: the bar shows at the end of combat,
      with no "blocked" message and no Lua error.
- [ ] Always: the bar shows for every class. Never: it stays hidden, also in
      Defensive Stance; `/dyre unlock` shows it to move, `/dyre lock` hides it.
- [ ] With the bar hidden, the key bindings still mark, ping, and pull.
- [ ] Key Bindings > AddOns > Dyre's Toolkit lists the nine tank bindings.
- [ ] `/dtt debug` and `/dyre tank_debug` print the owners (all
      DyresToolkit), pings, and the pull runner.

#### Pet taunt (both clients)

- [ ] Hunter with Growl on autocast in a party without the Tank role: the
      message box and the chat line; none solo or as the Tank role.
- [ ] Warlock with the Voidwalker's Torment on autocast: the same.
- [ ] With Dyre's Buff Reminders installed: one warning, not two (once DBR
      yields through "warn:petTaunt").
- [ ] `/dyre unlock` shows the sample message box to move.

#### Focus lines (Forever; John, 2026-11-12)

- [x] `/focus [@mouseover,harm,nodead][@focus,noharm][@focus,dead]` by
      hand: no focus, the target or mouseover becomes the focus; a live
      focus stays (John, in client).
- [ ] Mage: "! Polymorph" one mob, kill it, then in the same fight target
      another mob (no mouseover) and press "! Polymorph": it focuses, marks,
      and sheeps the new mob, and its timer shows.
- [ ] With a live sheep as focus, target another mob and press it: the
      sheep stays the focus. Shift-press, and a right-click on the action
      button: the focus clears, and the target becomes the new focus. A key
      binding with Shift clears it; without Shift it does not.

#### Taunt probe (Forever first, then Era; John, 2026-11-12)

The probe only counts: it sends nothing to chat or the party and saves
nothing. `/reload` first, so the counts start at 0.

- [ ] In a party in a dungeon, out of combat and then in combat, each of
      these once or more (not the tank, where you can):
      - a Warrior who is not the tank casts Taunt (and Mocking Blow or
        Challenging Shout if known);
      - a Druid who is not the tank casts Growl or Challenging Roar in Bear
        Form;
      - a Hunter's pet Growls (autocast on);
      - a Warlock's Voidwalker casts Torment (or Suffering);
      - a Paladin casts Righteous Fury;
      - you cast one of them too (the "player" and "pet" lines are the
        control: your own spell IDs are known to read in combat).
- [ ] Then type `/dtt debug_taunts` and paste every "debug_taunts" line.
      What decides the design: on the "party" and "partypet" lines, the
      "combat:" part. "spellRead" above 0 there means party casts read in
      combat; "spellSecret", "guidSecret", or "unitSecret" there means the
      client hides them. "matches:" and the "recent" lines show which
      watched spells were seen (unit token and spell only, no names).
- [ ] `/dtt debug` has the line "debug taunt probe: N casts seen, N
      watched".

#### Threat (Forever, then Era)

- [x] `/dtt debug_threat` in combat in the open world on Forever (John,
      build 70888, 2026-11-11): the target token reads, plate tokens are
      secret except UnitThreatSituation.
- [ ] `/dtt debug_threat` in combat in a dungeon on Forever, with an enemy
      target and plates: does UnitThreatSituation still read on a plate?
      Keep the chat lines.
- [ ] In a group on Forever: the plate of your target shows a real percent
      and early yellow when a party member nears the pull point; other
      plates show the percent in the threat color.
- [ ] `/dtt debug_threat` in a party in combat in the open world on
      Forever: the "target party1:" and "nameplateN party1:" lines. Keep
      them: nil on a plate means the pull bars cannot work there.
- [ ] The same in combat in a dungeon on Forever.
- [ ] Tank view in a party: a mob where a DPS passes you shows LOSING in
      orange on its plate, with the losing sound once (Cartoon shake, or
      quest failed without Dyre's Sounds 1.5.0; not the red sound); "Sound
      when losing a mob" set to None stops it.
- [ ] Pull bars: under each enemy plate, one thin bar per party member in
      its class color, rising as that member's threat rises; none in a raid,
      in the DPS view, or solo; the label placed Below sits under them.
- [ ] The icons show on both clients: the drawn shield and crossed swords,
      each in the text's color (green, yellow, red, blue, orange for
      LOSING, white when secret), with a dark outline that reads on light
      and dark nameplates; not a green square (a texture that did not load).
      Note whether 14 is a good size.
- [ ] "Alert sound (red)" and "Warning sound (orange)": each
      dropdown lists None and eight sounds; picking one plays it once; in
      combat a pick plays nothing. Listen to each sound on both clients
      (Quest failed plays by number 847; no sound in the list has been
      heard in client yet).
- [ ] With Dyre's Sounds: both menus show Game Warnings first, then its
      groups as submenus, and Text to Speech at the top; a pick plays it
      once; the alarms play it; Text to Speech says "Aggro lost" (tank),
      "Aggro" (DPS), "Losing". Other settings dropdowns (Dyre's Sounds' own
      pickers, other AddOns) still show their own menus and labels.
- [ ] Pick a Dyre's Sounds sound, disable Dyre's Sounds, /reload: the menu
      shows the default sound as chosen and the default plays; enable it
      again: your pick is back.
- [ ] After the update from an earlier 2.9.0 test build with "Warning
      sound (orange)" turned off: it shows None.
- [ ] Defaults with Dyre's Sounds 1.5.0 (John, 2026-11-11): "Alert sound
      (red)" shows "Dyre's Alerts: Bell buzz" and the alarm plays
      it; "Warning sound (orange)" shows "Dyre's Alerts: Cartoon shake"
      and LOSING plays it. A save from an earlier test build that had the
      raid warning (red) or quest failed (losing) now shows these.
- [ ] Defaults without Dyre's Sounds 1.5.0 (disable it, /reload): the menus
      show Raid warning and Quest failed as chosen, and those play; enable
      it again: Bell buzz and Cartoon shake are back. The settings'
      Defaults button gives the same result.
- [ ] The four label sliders (nameplate and target, left/right and up/down)
      show "0 px" and a gold mark at 0; moving one moves the shown labels at
      once, also in combat; at 0 the labels sit where they did before.
- [ ] The two label size sliders show "100%" and a gold mark at 100; at
      200% the icon and text are twice as big, at 50% half, at once, also in
      combat; the gap to the bar and the px offsets stay the same on screen;
      the text stays sharp (not blurred) at 200%. Seen (John, Forever,
      2026-11-13, screenshot: a large nameplate label left of the bar, the
      target label at its default size): "The adjustable size font scales
      well enough, I think it looks fine." The size range and combat are not
      noted as checked.
- [ ] Label right of each enemy nameplate's bar, not on the mob's name;
      Left, Above, and Below in the settings move it. The target's label sits
      above the target frame's bar. With Dyre's Debuff Tracker or WTF: the
      label and the DIES badge do not cover each other.
- [ ] Tank view (group role Tank, raid main tank, Bear Form, Righteous
      Fury, Defensive Stance, or forced):
      green while you tank, yellow while another has more threat, red when a
      mob leaves you.
- [ ] Tank view in a group: yellow before a DPS pulls (at 80% of the pull
      point), blue for a mob another Tank-role player or raid main tank holds.
- [ ] DPS view: green below the tank, yellow at 80% of the pull point on
      your target and its nameplate (no sound), orange above the tank,
      red with aggro (John, 2026-11-13). In a group, green or yellow to orange plays "Warning sound
      (orange)" once; orange to red plays "Alert sound (red)". A mob first
      seen already orange plays nothing. Text to Speech says "High threat".
- [ ] In a raid as the tank: no frame rate drop from the group threat read.
- [ ] The red sound when a mob turns red, not again while it stays red, at
      most once in 2 seconds; none with None; none while the status is
      secret; another choice plays that sound instead.
- [ ] The red sound on every pull (fixed 2026-11-11: it played about 1 in
      10): ten pulls in the DPS view (solo caster form, or a DPS in a
      group) each play it once; then `/dtt debug_threat` shows "red sound:
      seen=10 played=10" or the skips with their reasons (gap, none, calm,
      view, same). In combat, a new plate already red and a target change
      onto a mob on you play it (2 s gap allowing); a form change that turns
      a label red plays nothing; your target and its plate count as one
      mob.
- [ ] `/dtt debug` names the view and why. Auto changes on a role change
      and a form or stance change, at once, and the tank bar agrees (it
      only hides 30 s later).
- [ ] Paladin (John's bug, 2026-11-11): Righteous Fury on, the shield shows
      and a mob on you is green; Righteous Fury off, the crossed swords show
      and a mob on you is red. Protection talents alone do not change it.
- [ ] Warrior: Defensive Stance gives the shield; Battle or Berserker
      Stance gives the crossed swords.
- [ ] Paladin with Righteous Fury, solo, a long fight (John's bug,
      2026-11-11: green turned red at 100% after a few swings): the label
      stays green; then `/dtt debug_threat`: "righteous fury reads combat:"
      shows what the game gave in combat (nil proves the cause) and
      ", aura secret ..." what C_Secrets.ShouldSpellAuraBeSecret said
      (expected: true in combat, false out of combat, as Dyre's Buff
      Reminders' probe saw); "view changes in combat=0", and red "view=0".
      Click Righteous Fury off in combat: the view changes at once if
      "aura secret" says false in combat, else when combat ends. Out of
      combat, click it off: the crossed swords show at once (if they do
      not, ShouldSpellAuraBeSecret says true out of combat too; report it).
- [ ] Druid, in combat (John's test, 2026-11-11): Bear Form gives the
      shield, caster or Cat Form the crossed swords, at once each time.
      Warrior, in combat: Defensive Stance and Battle Stance switch at once.
- [ ] Where values are secret: the percent shows in white, the icon still
      shows, no Lua error.
- [ ] With Plater or Platynator: the label sits beside their
      health bar.

#### Marking (both clients, in combat)

- [ ] Skull button and binding: skull on the target, no "blocked" popup.
- [ ] Skull (mouse) binding: skull on the mob under the mouse.
- [ ] Next marker: skull, cross, square... on each press; the button icon
      shows the next marker; after combat it starts at skull again.
- [ ] Count how many fast presses the game takes before its marker cooldown.
- [ ] In a raid without assist: the game refuses the marker, the toolkit shows no
      error.

#### Pings

- [ ] Forever: Attack, Warning, Assist, On my way on the target; Skull and
      ping in one press.
- [ ] Classic Era: confirm that `/ping` does not exist and that the toolkit shows no
      ping buttons.

#### Pull

- [ ] With DBM, then with BigWigs: PULL and `/dtt pull 5` start their timer;
      `/dtt pull 0` cancels it.
- [ ] Without both: the game's countdown starts, solo, as leader, and as a
      party member without lead, and as a raid member without assist.
      Record each: does the game take it (all members see its countdown),
      or refuse it (the chat line "The game refused its countdown", and
      what else the game shows: a red error, a chat line, nothing)?
- [ ] No "AddOn blocked" message from `C_PartyInfo.DoCountdown`.
- [ ] Era: the same; does START_PLAYER_COUNTDOWN come there?

#### Dyre's countdown on screen (both clients)

- [ ] Without a boss mod: a pull (another member's /countdown 10, or the
      PULL button) shows Dyre's countdown and NOT the game's own (no game
      bar, no game big numbers): the number pops each second, gold, orange
      at 3 and 2, red at 1; the bar drains smoothly to empty; "Pull in N -
      Name" names the starter; a tick on 5 to 1; "PULL!" grows and fades
      with the go sound.
- [ ] Turn "Dyre's countdown on screen" off: the game's own countdown is
      back at once (out of combat), and Dyre's never shows.
- [ ] /console taint.log 1 (or 2), a few pulls in and out of combat, a PvP
      or Challenge Mode start timer if one is at hand: no taint line names
      DyresToolkit or TimerTracker; no "AddOn blocked" message.
- [ ] DBM only, with DBM's "Do not show Pull/Break Timer bar" and "Do not
      show announce text" on (/dbm > Global Disables & Filters > Disable DBM
      Features): Dyre's countdown shows, the game's numbers do not, and no
      DBM bar or text shows. Does DBM's countdown voice still play? Turn the
      DBM option off again: the next pull after a /reload or a group change
      is DBM's again, with the game's numbers.
- [ ] DBM and BigWigs both loaded (John's setup), DBM's bar off: Dyre's
      countdown stays hidden (BigWigs shows its own).
- [ ] With DBM (its bar on) or BigWigs loaded: Dyre's countdown never shows; theirs
      shows; the game's countdown is as they leave it.
- [ ] A member with DBM pulls (as leader): one countdown, not two.
- [ ] A cancel (/countdown 0, /pull 0, `/dtt pull 0`) shows "Pull
      cancelled" for a moment, then hides.
- [ ] Combat during the countdown does not stop it.
- [ ] The tick and go sound menus: Game Warnings first, then Dyre's Sounds;
      None silences each; Text to Speech says the numbers and "Pull".
- [ ] "Countdown size (%)" and "Countdown opacity (%)" change it; the
      checkbox tooltip shows the Sending and On screen parts.
- [ ] The dash in "Pull in 10 - Name" and the font look right; the bar and
      numbers are readable on bright and dark ground.
- [ ] Two toolkit users, the game refuses the countdown (not the leader):
      the other one sees the toolkit's countdown.
- [ ] `/dyre unlock` shows a sample "10" to move; it stays put after
      /reload.
- [ ] In a group with a DBM user and a BigWigs user: a few seconds after
      the group forms, `/dtt debug` names each with its version; a member
      with neither is "unknown"; after someone leaves, they are gone from
      the list. In a 5-player party: do BigWigs' messages (sent on "RAID")
      arrive at all?

#### Bar

- [ ] `/dyre unlock` shows the outline; drag by a button; `/dyre lock`.
      Locked: Ctrl-drag by a button. The drag does not click the button (no
      marker, no ping). No drag in combat. `/dtt reset`.
- [ ] Hide the bar in combat in the settings: it hides after combat.
- [ ] `/reload`: the place and the settings stay.

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
