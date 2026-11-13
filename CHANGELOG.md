# Changelog

Player-facing changes for each Dyre's Toolkit release, newest first. The
release builder copies the section for the TOC version into the GitHub release
notes and the CurseForge changelog, and fails if that section is missing.

## 2.9.0

### Features
- Threat on enemy nameplates and on your target, for every class: a shield (tank view) or crossed swords (DPS and healer view) and your threat percent, the icon and the text both in green, yellow, or red. In the tank view, yellow also comes early, when another player or pet nears the point where they pull the mob, and a mob another tank holds is blue. A sound plays when a mob turns red: Bell buzz by default (below), or one of the game sounds, or none ("Alert sound (red)"; a choice plays once so you can hear it). Auto uses the same rule as the tank bar: the tank view for group role Tank or raid main tank, a Druid in Bear Form, a Paladin with Righteous Fury, or a Warrior in Defensive Stance; else the DPS view. You can also choose Tank or DPS/Healer. The nameplate label sits right of the health bar, or left, above, or below. In the tank view, a nameplate says LOSING in orange when another player has more threat on a mob you still hold, and a sound of its own plays when that starts (Cartoon shake by default, below; "Warning sound (orange)"). In the DPS and healer view, your target turns yellow at 80% of the pull point (no sound), any mob turns orange when you have more threat than the tank and plays the same warning sound, and red plays the alert sound. In a party, thin pull bars under each enemy nameplate show how close each member is to pulling the mob ("Pull bars under nameplates"). On WoW: Forever, a nameplate's threat percent is hidden in combat: it shows in the threat color (white only when the threat state is hidden too), and the nameplate of your target shows its real percent, with the early yellow and blue.
- The warning sounds can also be any sound of Dyre's Sounds, when it is installed: its groups follow the "Game Warnings" group in both menus, and Text to Speech says "Aggro lost", "Aggro", or "Losing". Without Dyre's Sounds, your choice is kept and the default game sound plays.
- The default warning sounds come from Dyre's Sounds 1.5.0 or later: "Dyre's Alerts: Bell buzz" when a mob turns red, "Dyre's Alerts: Cartoon shake" when losing a mob. Without Dyre's Sounds 1.5.0 (not installed, older, or the sound cannot play), they are the game's raid warning and quest failed sounds. Dyre's Toolkit 2.9.0 is released with or after Dyre's Sounds 1.5.0.
- If you used an earlier 2.9.0 test build, a warning sound left at the raid warning (red) or quest failed (losing) becomes the new default once; any other sound you chose stays.
- Dyre's countdown on screen, for every Dyre's Toolkit user, when anyone in the group starts a pull (the game's countdown, Deadly Boss Mods, BigWigs, or the toolkit): a big number that pops each second and turns orange at 3 and red at 1, a bar that drains over the whole pull, who started it, a "PULL!" splash at 0, and "Pull cancelled" on a cancel. It takes the place of the game's own countdown. It never overrides another AddOn: with BigWigs loaded it stays hidden (BigWigs always shows its own pull bar), and with Deadly Boss Mods it shows only when DBM's own "Do not show Pull/Break Timer bar" is on. A tick sound on the last 5 seconds and a go sound, each your choice; size and opacity sliders; /dyre unlock to move it. The checkbox is only about the display: sending a pull always uses the best path.
- The PULL button uses the game's countdown when no boss mod is loaded, so every group member sees it. If the game refuses it, Dyre's Toolkit users in the group still get the toolkit's countdown. /dyre pull 0 cancels a pull.
- /dtt debug lists the boss mod and version of each group member, as heard from Deadly Boss Mods' and BigWigs' own version messages. The toolkit sends nothing for it, so a member with neither shows as unknown.
- "Threat sounds when solo", off by default: the red and losing sounds play only in a party or raid, not on every pull while you grind alone. The threat labels still change color. Turn it on to hear them solo too.
- Move the threat labels: left/right and up/down sliders (-50 to 50 pixels) for the nameplate labels and for the target label. They also set the gap to the health bar; at 0 nothing moves.
- Resize the threat labels: a size slider (50% to 200% of the default) for the nameplate labels and one for the target label. The gap and the offsets stay the same on screen.
- The pet taunt warning moves here from Dyre's Buff Reminders, so every Dyre's AddOn has it: in a group where you are not the tank, a message on screen and in chat when Growl, Torment, or Suffering is on autocast.
- Tank tools: a bar with Skull, Next marker (skull, cross, square, triangle, diamond, circle, star; moon stays free for Banish and Polymorph), Skull and ping, the Attack, Warning, Assist, and On my way pings, and PULL. They mark and ping in combat with no "blocked from an action" popup. Each has a key binding under Dyre's Toolkit. Classic Era has no pings, so those buttons do not show there. PULL hands the countdown to Deadly Boss Mods or BigWigs when one is loaded, else the game's countdown. The bar shows while you tank: your group role is Tank (or you are a raid's main tank), or you are a Warrior in Defensive Stance, a Druid in Bear or Dire Bear Form, or a Paladin with Righteous Fury. The "Tank button bar" setting also has Always and Never. It shows at once and hides only after 30 seconds out of combat with no reason to show, so stance dancing does not make it flicker; while your role is Tank, it stays. A change in combat waits for the end of combat. The bar moves with every Dyre's frame, and shows while frames are unlocked.
- All of this is in new sections of the Dyre's AddOns settings page: "Threat Indicators: Nameplates", "Threat Indicators: Target Frame", "Threat Indicators: Sounds", "Group Warnings" (pull bars, the countdown, the pet taunt warning), and "Tank Tools". Each warning has its own switch; all are on at first except "Threat sounds when solo". The settings are per character.
- New commands: /dyre pull [seconds], /dyre tank_reset, /dyre tank_debug, /dyre threat_debug, and /dyre taunt_debug. /dtt and /tanktools do the same with the short words (/dtt pull 10, /dtt reset, /dtt debug, /dtt debug_threat, /dtt debug_taunts). /dtt debug_taunts counts the taunts and Righteous Fury casts the game lets the toolkit see from your party; it sends nothing and saves nothing.

### Fixes
- The focus macros of Dyre's AddOns (Polymorph, Banish, Seduction) work again in combat after the first mob dies. A live enemy focus stays locked on. With no focus, or a dead one, the mob under the mouse or your target becomes the focus, in combat too. Shift-click or right-click clears the focus, so the same press picks a new mob (from a key binding, hold Shift).

### Other changes
- For AddOn authors: the toolkit now has features of its own. It claims the owner kinds "threat", "warn:petTaunt", "tank:markers", "tank:pings", "tank:pull", and "tank:pullDisplay" at priority 50, so a Dyre's AddOn with its own copy of a feature sees the toolkit own it and stays quiet. Contract 2 is unchanged.

## 2.8.0

### Other changes
- For AddOn authors: the DoT tracker's target and focus rows take `outlineWidth` from the tracker's store: the solid outline's width in whole pixels, 0 to 20 (`TRACKER_OUTLINE`), 3 by default as before. At 0 there is no outline, and the stacked rows close up by the same amount. A change applies with `Rebuild`, out of combat.

## 2.7.0

### Other changes
- For AddOn authors: the smart curse for the DoT tracker. With `curseMode` "smart" in the tracker's store, the Curse slot on your target and focus casts Curse of Tongues on a mob with mana, else Curse of the Elements, else Curse of Weakness; Ctrl-click casts Tongues, Shift-click Weakness, Alt-click Recklessness. The game lets a click change only out of combat, so the pick is set before the pull; a letter on the slot (T, E, or W) shows the best curse for the mob, also in combat. `names.smartCurse` adds a button for a keybind, and `onSmartCurse(body)` gives the owner the text for a "! Curse" macro. Without Curse of Weakness, there is none of this.

## 2.6.0

### Features
- DoT damage prediction now works on WoW: Forever. The purple damage-to-come block and the red skull **DIES** badge show on your target, focus, nameplates, and DoT tracker rows, as on Classic Era. Forever has no combat log for AddOns and hides damage numbers in combat, so the toolkit follows your casts, the DoT's tooltip, and when each tick lands. After each fight, it learns your real tick sizes from Blizzard's damage meter. The method comes from Does It Die, by Joe Greive.
- On a DoT tracker row on Forever, **DIES** shows just left of the health numbers, which stay; with no health text, at the right end of the health bar.

### Fixes
- In dungeons and raids, the DoT tracker's list of other mobs and the crowd-control bar now show your mobs. The game hides mob IDs there, so the toolkit follows each mob by its enemy nameplate. In those places, the list needs enemy nameplates on, and a row goes when the mob's nameplate goes.
- **DIES** now shows on EllesmereUI's target and focus frames. Before, only the damage-to-come block showed there: EllesmereUI cuts off what is drawn outside its frames.
- On Forever, a DoT you cast at the mob under your mouse, or at a mob the game hides and that has no nameplate, is no longer counted on your target. With a friendly target or a corpse targeted, a DoT counts on your soft enemy, as the game casts it.

### Other changes
- For AddOn authors: `DrawPrediction`'s style takes the DIES places `"center"`, `"above"`, and `"below"`, and offsets `x` and `y` (whole pixels, at most 200 each way); `CreateDotPredictor` reads them from its store (`diesPlace`, `diesX`, `diesY` for the target and focus frames; `plateDiesPlace`, `plateDiesX`, `plateDiesY` for nameplates; `"auto"` is the toolkit's choice).
- For AddOn authors: `PlateToken`, `PlateKey`, `KeyPlate`, and `MobKey` give a key for a mob whose GUID is secret, and `LockCast` takes `plateKey`. A key of the form `plate:nameplateN` is good only until that plate goes.
- For AddOn authors: `CreateDotPredictor` now gives a predictor where the combat log is restricted (`predictor.hidden` is true), and `DrawPrediction` draws with a secret health: it then returns nil for "DIES shows", which Lua cannot know there.

## 2.5.0

### Other changes
- For AddOn authors: the first part of the shared tracking engine. `SpellbookIDsByName`, `SpellSet`, `IndexSpells`, `KnowsAny`, and `PetKnows` find a spell by name in every client's spellbook; `CreateMacroKeeper`, `OutOfCombat`, `MarkLine`, and `FocusCastMacro` keep character macros, out of combat only, and take over another Dyre's AddOn's macro by its name instead of making a second one; `CreateAnnouncer`, `FormatAnnouncement`, `GroupChannel`, and `RAID_MARKERS` send group messages; `ClassData` holds the Warlock and Mage spell tables. Contracts 1 and 2 are unchanged.
- For AddOn authors: `CreateControlTracker` is the crowd-control bar of Warlock Tools Forever and Mage Tools Forever in one engine: a row per mob you Fear, Banish, or Polymorph, its click to cast again on your focus, the Focus box, timers under nameplates, the group messages, and the macros. `ClaimOwner`, `IsOwner`, and `OnOwnerChanged` make sure that with two Dyre's AddOns on, only one shows a bar, writes the macros, or tells your group: a class's own Tools AddOn first.
- For AddOn authors: `CreateDotTracker`, `CreatePlateDots`, and `CreateDotPredictor` are Warlock Tools Forever's DoT tracker, nameplate dots, and damage to come in one engine. The ticks each DoT has shown are now kept once for every Dyre's AddOn, and Warlock Tools Forever's are carried over the first time.

## 2.4.0

### Features
- The damage-to-come block and the red skull **DIES** badge, for Dyre's AddOns that predict damage, now come from the toolkit. They work on Blizzard's frames, Threat Plates, Plater, Platynator, Shadowed Unit Frames, BetterBlizzFrames (also with smooth bars), and EllesmereUI.
- The **DIES** badge no longer runs into what a nameplate AddOn shows beside the health bar: Threat Plates' target-of-target name, crowd-control icons, and threat text, or Plater's cast target name and raid marker. When that side of the bar is taken, the badge moves to the other side, or into the bar's right end.
- For nameplate and unit frame AddOn authors: `DyresToolkit.HealthBars` (API version 1) lets your AddOn point to its own health bars, place the **DIES** badge, keep it off the sides your frame uses, turn the block off on a bar, ask for a redraw, and read the damage to come (`GetPredictedDamage`, `WillDie`, and a `PREDICTION_CHANGED` callback). See docs/HEALTHBARS_API.md.
- `/dyre debug` turns on debug mode until you reload. A hook from another AddOn that fails is turned off quietly, and said in chat only in debug mode.

### Other changes
- Whether your client has a focus target is now learned once for every Dyre's AddOn, not once per AddOn.
- For AddOn authors: `CreateAuraContainer` and `AuraEngineKind` (aura slots on Forever's engine, and in plain Lua on Classic Era); `ReadGUID`, `ReadName`, `IsDead`, `FindUnit`, the nameplate memory (`LearnPlate`, `LearnPlates`, `ForgetPlate`, `KnownPlate`, `PlateGUID`), and `LockCast`, which finds the mob a cast goes to as it starts; `FocusWorks`, `OnFocusWorks`, `LearnFocusWorks`, `NoteFocusWorks`, `ResetFocusWorks`, and `FOCUS_RESET_TEXT`; `FindPlateBar`, `FindUnitBar`, `RegisterBarAdapter`, `UseBar`, `PrepareBar`, `DrawPrediction`, `HidePrediction`, and `MoveDies`. Contracts 1 and 2 are unchanged.

## 2.3.1

### Other changes
- Now also for WoW Classic Era (1.15.9): the toolkit loads there without "out of date", so Dyre's AddOns can use it on Era as on Forever.

## 2.3.0

### Other changes
- For AddOn authors: `AddSettingsLink(category, layout, {addon, name, button, tooltip, missing})` adds a row that opens another Dyre's AddOn's settings page, for a feature that moved there. While that AddOn is missing or disabled, the button is greyed and says what to install.

## 2.2.2

### Other changes
- A widget's size slider is now labeled **Size** instead of **Size (%)**: its value already shows the % sign.

## 2.2.1

### Fixes
- Fixed Lua errors blamed on Dyre's Toolkit in the game's own code, such as "tainted by 'DyresToolkit'" from combat text and the quest tracker, and a blocked action bar move when your pet appeared or left in combat. Placing and resizing Dyre's frames, at login and when their content changes, no longer makes the game lay out its own frames in the middle of the toolkit's work.

### Other changes
- **Snap to the grid** is now on for new installs, so dropped frames line up with the grid from the start. Existing installs keep their current setting. Hold **Ctrl** as you drop to place a frame exactly, or turn snapping off in the settings or with `/dyre snap`.

## 2.2.0

### Features
- Move a Dyre's frame without unlocking: hold **Ctrl** and drag it, as with Questie's tracker. The frame goes exactly where you drop it, with no snapping and no grid. Start the drag on a part you can click, such as a button or a box's header; the rest of a locked frame still lets your clicks through. Frames still move only out of combat.

### Fixes
- Frames that grow from an edge (a bar that grows left or right, or a box that folds toward its top, such as Dyre's Quest Targeting's box) come back exactly where you left them after a reload, instead of shifting a little each time.

### Other changes
- For AddOn authors: `AddDefaultTick(initializer, {min, max, default})` puts the gold default mark on an AddOn's own slider.

## 2.1.0

### Other changes
- For AddOn authors: `widget:SetContentSize(width, height, anchor)` can keep an edge or a corner fixed (`"LEFT"`, `"RIGHT"`, `"TOP"`, `"BOTTOM"`, or a corner such as `"TOPLEFT"`), so a bar grows left to right or right to left, and a box collapses toward its top; `"CENTER"` stays the default. `ResizeFromCenter` takes the same anchor.

## 2.0.0

### Features
- Every Dyre's AddOn that moves to the toolkit's widgets places, drags, snaps, and resizes its frames exactly the same way: the gold outline and hint while frames are unlocked, magnetic snapping, the grid, Shift-drag for a group, and Ctrl for an exact place.
- Their size and opacity settings look and work the same everywhere, each slider with a gold mark at its default, and a "Reset size" button.

### Fixes
- Frames that change size or scale keep their place on screen. Before, making a frame bigger through a size setting could move it right and up, away from where you put it.
- A frame you lock no longer takes your mouse clicks where it sits, unless it is a bar of buttons you click.

### Other changes
- Dyre's AddOns will need Dyre's Toolkit from their next releases on; the CurseForge app installs it with them.
- For AddOn authors: contract 2 adds `CreateWidget`, `AddWidgetSettings`, `ResetWidgets`, and `Widgets`, plus `ResizeFromCenter`. Contract 1 still works.

## 1.0.0

The first full release for WoW: Forever, no longer marked beta: it was play tested on the Forever beta client 1.60.1, build 70450. CurseForge now offers it as a release, so the app updates it and installs what it needs for every player.

- The CurseForge app now installs Dyre's Toolkit with the Dyre's AddOns that need it.

## 0.1.1-beta

First beta on CurseForge, for WoW: Forever. The AddOn is the same as 0.1.0-beta, which reached GitHub only.

- One layout mode for every Dyre's AddOn: `/dyre unlock` shows every frame to drag, `/dyre lock` locks them all.
- Frames snap to each other, also across AddOns; Shift-drag moves a snapped group.
- A grid while unlocked, with its size a setting, and "Snap to the grid": near a red center line a frame centers on it or puts an edge on it; elsewhere an edge within a quarter of the grid size of a grey line lines up with it (when both edges are that close, the one that moves the least wins). Snapping to another Dyre's frame comes first; a Shift-dragged group snaps as one block. Hold Ctrl as you drop to place a frame exactly, with no snapping.
- A minimap button: left-click locks or unlocks frames, right-click opens a menu with the grid switches, the settings, and each installed Dyre's AddOn.
- One "Dyre's AddOns" settings home in Options > AddOns, with each Dyre's AddOn's page under it. `/dyre` opens it.

## 0.1.0-beta

First beta for WoW: Forever.

- One layout mode for every Dyre's AddOn: `/dyre unlock` shows every frame to drag, `/dyre lock` locks them all.
- Frames snap to each other, also across AddOns; Shift-drag moves a snapped group.
- A grid while unlocked, with its size a setting, and "Snap to the grid": near a red center line a frame centers on it or puts an edge on it; elsewhere an edge within a quarter of the grid size of a grey line lines up with it (when both edges are that close, the one that moves the least wins). Snapping to another Dyre's frame comes first; a Shift-dragged group snaps as one block. Hold Ctrl as you drop to place a frame exactly, with no snapping.
- A minimap button: left-click locks or unlocks frames, right-click opens a menu with the grid switches, the settings, and each installed Dyre's AddOn.
- One "Dyre's AddOns" settings home in Options > AddOns, with each Dyre's AddOn's page under it. `/dyre` opens it.
