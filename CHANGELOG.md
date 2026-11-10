# Changelog

Player-facing changes for each Dyre's Toolkit release, newest first. The
release builder copies the section for the TOC version into the GitHub release
notes and the CurseForge changelog, and fails if that section is missing.

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
