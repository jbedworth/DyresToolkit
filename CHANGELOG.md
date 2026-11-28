# Changelog

Player-facing changes for each Dyre's Toolkit release, newest first. The
release builder copies the section for the TOC version into the GitHub release
notes and the CurseForge changelog, and fails if that section is missing.

## 2.21.0

### Other changes
- Dyre's AddOns can now tell when your main-hand weapon has an enchant, such as a Spellstone or Firestone, so they can remind you to put one on.

## 2.20.0

### Fixes
- While frames are unlocked, each outline's label is now short, like "DBR: Aspect bar" or "DDT: Target", so labels of frames that sit close together no longer pile on top of each other. Point at a frame to see how to move it. A label near the edge of the screen stays on screen.
- The DoT tracker's Target, Focus, and Others panels now have labels while frames are unlocked, so you can tell them apart.

## 2.19.0

### Features
- Button bars can have one opacity out of combat and another in combat, set with two sliders under the bar's Layout setting. Set a bar to 0% in combat and it stays out of the way, then shows at 80% or more as soon as your mouse is over it, so you never click a button you can't see. Both start at the bar's opacity today. This works for Mage Tools Forever's Conjure and Portals bars, the Warlock's Stones bar, the Hunter's Aspect bar, and the tank bar. Thanks to user_kegtgryr84rvp31h on CurseForge for the idea.
- Named profiles. Press New at the end of the Dyre's AddOns page to make a profile from the settings and frame positions you use now, and give it a name. On any character, pick it in "Profile in use" and that character shares it: change something on one, and the others have it at their next login. Pick "This character's own" to go back to that character's own settings, or Delete to remove a profile.

### Fixes
- A character no longer shows up twice in "Copy settings from", once with your realm and once with your character's last name. Each character keeps one profile name for good, and the extra copy is folded in, the newer settings winning, the next time that character logs in.

## 2.18.2

### Fixes
- A feared mob that runs out of range keeps its time left on its bar's name line, like "~6 s", instead of showing only its name. The "~" means it's counted from your cast, since damage can break Fear early.
- A Fear bar now goes when that Fear's time is up (10 seconds for rank 1), instead of staying for 25 seconds.
- Your focus's Fear no longer shows twice, once in the Focus box and again on a bar.

## 2.18.1

### Fixes
- With Blizzard's nameplates, changing a setting on the Options > Nameplates page, or casting with your own nameplate showing, could throw Lua errors that blamed a Dyre's AddOn. The DoT dots, crowd-control timers, and DIES now go only on a mob's nameplate, never on yours or on the preview plate in the settings.
- The "Copy settings from" list fits its box again. Your own character shows as "This character", and characters on your realm show without the realm name.
- The link to Dyre's Threat and Combat Tools on the settings page is now called "Threat and Combat Tools", so its name isn't cut off.

## 2.18.0

### Features
- Button bars can now be horizontal or vertical. Mage Tools Forever's Conjure and Portal bars get the option first; other Dyre's AddOns' bars follow in their own updates. Thanks to a player on CurseForge for the idea.
- While frames are unlocked, a bar's outline has a small rotate button: click it to switch the bar between a row and a column.

## 2.17.0

### Features
- Settings in one place: Mage Tools Forever and Warlock Tools Forever can now show the real settings of the Dyre's AddOns they work with (Shields Up, Buff Reminders, Debuff Tracker) on their own pages, instead of an "Open settings" button. Each setting still lives in the AddOn that owns it, so a change on either page is the same change.
- Each feature's on/off switch sits on the class AddOn's main page; its other settings are on its own page and are greyed out while the feature is off, at once when you click.
- When one of those AddOns is not installed, its page says in a short note what it would add and where to get it.
- Proc arcs and sounds have one master switch. Every proc of your class is listed, greyed out until you learn it.
- Crowd-control bars (Polymorph, Fear, Banish, Seduction): switching the bar off now also stops its group messages and removes its "!" macros. Switched on again, the macros come back; put them on your action bars again.

### Fixes
- Greyed-out buttons in the settings now grey their label too, like the other rows.
- Setting tooltips are now one short, plain sentence each.
- In layout mode, each frame's label starts with the name of the AddOn it belongs to.

## 2.16.0

### Fixes
- Proc cues: Revenge, Overpower, Mongoose Bite, and every talent proc now count as known when you have trained a higher rank. Before, the cue went away on Forever after training Revenge rank 2 or later. Thanks to vanquishu on CurseForge.
- Profiles: import and copy now work when the game gives no realm name (seen on Forever). Before, import said "Your character is not ready yet" every time. Thanks to vanquishu on CurseForge.

### Other changes
- **What moved:** the threat labels and sounds, the pull bars, the tank button bar (markers, pings, and the PULL button), the pull countdown, the pet taunt warning, and the swing timer are now in their own AddOn, **Dyre's Threat and Combat Tools**. Install it from CurseForge to keep them. Your settings and key bindings come with you. Its command is `/dct`.
- Dyre's Toolkit is again only the shared part of Dyre's AddOns: one layout mode, the grid and snapping, the minimap button, the settings home, and profiles. Without Dyre's Threat and Combat Tools it shows no threat labels, plays no threat sounds, and shows no swing timer.
- `/dyre pull` and the other old threat, tank, and swing words now say where these went.
- The settings page has a link to Dyre's Threat and Combat Tools where its sections were.
- The key bindings for the tank buttons stay in this AddOn and now have their own section, **Dyre's AddOns**, in Key Bindings (before, they were in the shared AddOns section). Your keys stay bound. They work when that AddOn is installed.
- One Skull key binding: **Skull mouseover, else target** skulls the mob under your mouse, else your target. The separate "Skull the mob under your mouse" row is gone; a key you bound to it still works and now does the same.

## 2.15.1

### Fixes
- Swing timer: off by default. 2.15.0 turned it on for every character, also for classes that do not need it. If you want it, turn it on again under Swing Timer > Show. The swing timer, the threat labels, and the tank tools move to a new AddOn, Dyre's Threat and Combat Tools, in a later update.

## 2.15.0

### Features
- New: a swing timer with a range box, for every class. A bar for each swing (main hand, off hand, ranged) in a box that turns green in range and red out of range, with the state as text: RANGE, MELEE, DEAD ZONE, TOO CLOSE, or TOO FAR. Settings are under "Swing Timer": Show (In combat, Always, or Off), opacity in combat and out of combat, "Only bars in use", the range box, the theme (Gold and black, or Tactical black and red), and size and width. `/dyre unlock` to move it, or Ctrl-drag its top edge.
- Only bars in use (on by default): one bar always shows, and the others join while you use them, so the frame grows and shrinks. Hunters, Mages, Warlocks, and Priests get the ranged bar on top; a Hunter shooting sees the ranged bar, and the main-hand bar joins in melee.
- Hunters: the last half second of the ranged bar is the red "hold still" zone of Auto Shot's cast, with HOLD STILL, or STOP while you move. Before it, orange clip zones for Aimed Shot and Sniper Shot: start the cast before its orange zone, or it delays your next Auto Shot. They follow your cast times, haste included. The red zone follows your ranged haste too. A melee swing restarts the ranged bar, shown grey until your next shot. DEAD ZONE and MELEE apart need Wing Clip (level 12); before that, TOO CLOSE covers both, and MELEE shows while your melee swings land.
- The bars need WoW: Forever's swing event. On Classic Era, only the range box works.

### Fixes
- Pet taunt warning: with your pet's taunt already on autocast, forming a group now shows the warning. Before, it could stay silent until you turned autocast off and on again.
- Threat, tank view: no more siren at the start of a pack pull. A mob that is not on you yet, while nobody has more threat than you, now shows yellow PULLING with no sound. Red and the siren mean someone else has more threat than you and the mob is not on you. `/dtt debug_threat` lists the last 10 of these changes.
- Tank bar (Auto): when you get the Tank role as a group forms, the bar now shows. Before, it could wait until you changed stance or form.

## 2.14.1

### Features
- Settings: a new switch, **Welcome messages at login**, on the Dyre's AddOns page. Turn it off to hide the name-and-version line that each Dyre's AddOn says in chat at login. Errors and problems always show. It is on by default, so nothing changes until you turn it off. Every Dyre's AddOn that says a welcome line follows it from its 2026-11-23 update: Buff Reminders 1.13.3, Crit Mayhem 0.3.6, Quest Targeting 1.8.0, Shields Up 1.5.2, Mage Tools 1.6.2, Warlock Tools 1.12.3, Weapon Sets 1.2.1 and Weapon Skills 1.4.2.

### Other changes
- The same code as 2.14.0, which did not reach CurseForge.

## 2.14.0

### Features
- Settings: a new switch, **Welcome messages at login**, on the Dyre's AddOns page. Turn it off to hide the name-and-version line that each Dyre's AddOn says in chat at login. Errors and problems always show. It is on by default, so nothing changes until you turn it off. Every Dyre's AddOn that says a welcome line follows it from its 2026-11-23 update: Buff Reminders 1.13.3, Crit Mayhem 0.3.6, Quest Targeting 1.8.0, Shields Up 1.5.2, Mage Tools 1.6.2, Warlock Tools 1.12.3, Weapon Sets 1.2.1 and Weapon Skills 1.4.2.

## 2.13.1

### Fixes
- Settings: the Grid size slider now has the gold mark at its default (32), as every other Dyre's slider has.

## 2.13.0

### Features
- For AddOn authors: the DoT tracker's rows can be drawn with no background and no border: `frame = false` in the tracker's store (`TRACKER_FRAME`). The name, the bars, the health, and the target and focus outline stay. A change applies with `ApplyPanelColors`, at once, also in combat.
- For AddOn authors: each DoT tracker panel (target, focus, and the other mobs) can have its own mob health, health text, frame, outline width, and sizes: `panels = {target = {...}, focus = {...}, list = {...}}` in the tracker's store (`TRACKER_PANEL_OPTIONS`). A value a panel does not set uses the tracker-wide one, so nothing changes until an AddOn sets one. The frame applies with `ApplyPanelColors`, at once; the others with `Rebuild`, out of combat.

## 2.12.0

### Features
- Proc cues: an AddOn can now give the proc arcs and sounds a home that wins over another Dyre's AddOn's copy, so you see and hear each proc once. Dyre's Buff Reminders becomes the home for every proc in its own update; until then nothing changes. A proc another AddOn shows keeps its settings rows, greyed, naming that AddOn.
- Proc cues: abilities the game makes usable for a few seconds, such as Warrior Overpower and Revenge, can have a sound next to their arcs, set in the same place. It plays when the ability becomes usable, also in combat, at most once every 3 seconds. Dyre's Buff Reminders brings it in its own update.
- Proc cues: an AddOn can start a proc's arcs off, for a proc that is a sound by default.

### Other changes
- **What moved:** nothing moves in this update. It prepares the move of every proc arc and sound from Dyre's Shields Up to Dyre's Buff Reminders, which comes in Dyre's Buff Reminders 1.13 and Dyre's Shields Up 1.5.

## 2.11.1

### Fixes
- Proc cues now work on game clients in every language, not only English. Before, the proc arcs and sounds in Dyre's Shields Up never showed on a French client (a player report), or on any other non-English client.
- Warlock "! Seduction" macro: works on game clients in every language. It checked for a pet named in English ("Succubus/Incubus"), so on other clients it did nothing; it now uses your demon's family as your client names it.
- Control macros stay within the game's 255-byte limit when a spell's name is long in your language (such as Russian or Chinese), so the end of the macro is no longer cut off. When a macro would be too long, it first leaves out the spell name after `#showtooltip` (the icon still shows), then the marker's fallback, then the marker line. The cast line always stays.
- Raid markers in group messages now show as icons for every player, whatever their game language: the messages use the codes `{rt1}` to `{rt8}` in place of words such as `{moon}`.

## 2.11.0

### Features
- Proc cues: a shared engine for proc overlays. When a proc's buff comes up, two arcs show, one each side of your character, and drain with the time left; a sound plays as the buff appears. Both work in combat. Dyre's Shields Up brings the procs for each class, with their art, switches, sounds, and arc size, in its own update. Sounds come from Dyre's Sounds. On Classic Era the arcs show with no sound. An AddOn that gives no art of its own gets a plain crescent in its proc's color. A stacking proc, such as Fingers of Frost, shows the right arc only while all its stacks are up, so one arc goes when you use a stack, also in combat; its sound plays again when a stack is added.
- Proc cues: a second kind of proc, for abilities the game makes usable for a few seconds, such as Warrior Overpower and Revenge. Its arcs show while you can use it, in combat too, and dim while you are short of rage instead of flickering. Dyre's Shields Up brings them in its own update. These play no sound from the toolkit; Dyre's Buff Reminders keeps its own.
- Proc cues: an AddOn can start a proc's sound switch off, for a proc the game already gives a cue, such as Clearcasting. The arcs still start on.
- DoT tracker: a new store setting, show, turns each of the three panels (target, focus, others) on or off. All three show by default. Dyre's Debuff Tracker and Warlock Tools Forever add the checkboxes in their own updates.

### Fixes
- Game settings: changing a Blizzard setting, such as Interface > Status Text, after you opened a Dyre's AddOns settings page no longer gives "attempt to compare a secret number value (execution tainted by 'DyresToolkit')". The toolkit no longer changes the settings rows that Blizzard's own settings reuse. The warning-sound dropdowns now show the sound's name without its group.
- DoT damage prediction: no more "attempt to compare a secret" error in combat when the game hides a health bar's direction, fill side, or texture (seen on the target frame). The toolkit keeps what it last read for that bar, else draws with your chosen look.

## 2.10.3

### Features
- DoT tracker: a new store setting, hideEmpty, hides the dim placeholder of each DoT that is not on the mob, so only the DoTs that are up show. The slots keep their places, and the target and focus rows then take no recast clicks. Dyre's Debuff Tracker and Warlock Tools Forever add the checkbox in their own updates.

### Fixes
- Profiles: copying from a character whose saved profile is damaged now says that an AddOn "cannot take those settings" and changes nothing. Before, it could stop with a Lua error.

## 2.10.2

### Features
- Warrior: Hamstring is a crowd-control bar spell, one bar per mob (for Dyre's Debuff Tracker).

## 2.10.1

### Fixes
- DoT tracking: a DoT cast by mouseover at a mob with the same name as your target now shows on the mob it hit. When two mobs share the cast's name, the toolkit waits up to 1.5 seconds for one of them to get a new aura. If no aura shows, both mobs are listed, so no DoT is lost.

### Other changes
- New command /dtt debug_dots (/dyre debug_dots): after each of your DoT casts, it counts what the game lets the toolkit see about which mob the DoT landed on. It sends nothing and saves nothing.
- The /dyre debug words now have the same names as /dtt: /dyre debug_threat and /dyre debug_taunts. The old /dyre threat_debug and /dyre taunt_debug still work.

## 2.10.0

### Features
- Each character now has a Dyre's Toolkit profile: its settings, frame places, sizes, and sounds. At the end of the Dyre's Toolkit settings page, the Profile section names this character and lets you copy another character's profile, or the Defaults for a clean slate. Each character keeps its own settings until you copy, so nothing changes when you update. A character shows in the list after it logs in once with this version.
- Export and import a profile as one line of text: keep a backup, move it to another account, or share it with a friend.
- A copy or import applies at once, with no reload. Dyre's AddOns join the profile in their own updates; until then they keep their own settings.

## 2.9.4

### Features
- Each feature section on the Dyre's AddOns settings page now starts with its own **Enable** switch, on by default: Threat Indicators: Nameplates, Threat Indicators: Target Frame, Threat Indicators: Sounds, Group Warnings, and Tank Tools. Turn off what you do not use, for example the threat sounds, and the rest keeps working. The layout settings at the top stay as they are.

## 2.9.3

### Fixes
- Crowd-control bars with a fixed click (Mage Tools Forever's Polymorph bar): the click now works for a Polymorph first cast in combat. The click is ready as soon as you know the spell, and the bar shows, dimmed with your focus's name, while a click would cast on your focus.
- A crowd-control bar's click always casts the spell you learned. After a Polymorph variant from a scroll (Pig, Turtle, and the others), the click casts Polymorph, so it does not use up your scrolls.

## 2.9.2

### Features
- The DoT tracker can grow up: for each panel (target, focus, others), the owner AddOn can set Up, so the first DoT sits where you placed the panel and the next ones go above it. In the others panel, new mobs also stack upward. Down stays the default. The mob name keeps the place you chose for it.

## 2.9.1

### Features
- The DoT and crowd-control engine knows every class, for Dyre's Debuff Tracker: Druid, Hunter, Priest, Rogue, Shaman, Warrior, and Paladin DoTs and crowd control, and the DoT parts of Mage's Fireball, Pyroblast, and Frostfire Bolt. Rip and Rupture count your combo points, and Serpent Sting and the Mage projectiles start their DoT when they land. Damage to come for these DoTs shows after their first ticks (or from the tooltip on WoW: Forever).

### Other changes
- The threat label now sits left of enemy nameplates by default, so DIES from Dyre's Debuff Tracker or Warlock Tools Forever has the right side. If you had the old default (Right), it moves to Left once; choose Right again in the settings to keep it there.

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
