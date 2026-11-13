# Dyre's Toolkit

The shared toolkit for Dyre's AddOns on World of Warcraft: Forever and Classic
Era. The Dyre's AddOns you install use it, and the CurseForge app installs it
with them. It also gives every player threat warnings and tank tools.

## Threat indicators and group warnings

- **Threat** beside enemy nameplates and above your target: an icon for your
  view and your threat percent, both in green, yellow, or red.
  - Shield, the tank view: green while the mob is on you, yellow while another
    player or pet has more threat or is at 80% of the pull point, blue while
    another tank has it, red when you lost it.
  - Crossed swords, the DPS and healer view: green below the tank, yellow
    at 80% of the pull point (on your target), orange when you have more
    threat than the tank, red when the mob is on you. Orange and red play
    the same two sounds as the tank view; yellow is silent.
  - Auto (default) uses the tank bar's rule: the tank view for group role
    Tank or raid main tank, a Druid in Bear Form, a Paladin with Righteous
    Fury, or a Warrior in Defensive Stance; else the DPS view. Or choose
    Tank or DPS/Healer.
  - "Alert sound (red)" when a mob turns red (by default "Dyre's Alerts: Bell buzz"
    from Dyre's Sounds 1.5.0 or later; without it, the game's raid
    warning).
  - Tank view on nameplates: LOSING in orange when another player has more
    threat on a mob you still hold, with "Warning sound (orange)" (by default "Dyre's
    Alerts: Cartoon shake" from Dyre's Sounds 1.5.0 or later; without it,
    the game's quest failed sound).
  - Choose each sound from eight game sounds ("Game Warnings"), or None;
    with Dyre's Sounds installed, all of its sounds too, in its groups. A
    choice plays once so you can hear it. The sounds play only in a party
    or raid, unless you turn on "Threat sounds when solo".
  - Pull bars (tank view, in a party): a thin bar per party member under
    each enemy nameplate, full when that member pulls the mob.
  - Where Forever hides the threat state in combat, the percent shows in white.
  - Move the labels: left/right and up/down sliders (-50 to 50 pixels) for
    the nameplate labels and for the target label, which also set the gap.
  - Resize the labels: a size slider (50% to 200%) for the nameplate labels
    and one for the target label.
- **Pet taunt on**: Hunters and Warlocks get a message on screen and in chat
  when Growl, Torment, or Suffering is on autocast in a group where they are
  not the tank.

Each has its own switch, on at first except "Threat sounds when solo". The
settings page has the sections Threat Indicators: Nameplates, Threat
Indicators: Target Frame, Threat Indicators: Sounds, Group Warnings, and Tank
Tools.

## Tank tools

- **Marking in combat** with no "blocked from an action" popup: Skull your
  target, Skull the mob under your mouse (key binding), and Next marker
  (skull, cross, square, triangle, diamond, circle, star). Moon stays free for
  Banish and Polymorph.
- **Pings** (Forever): Attack, Warning, Assist, On my way, and Skull and ping
  in one press. Classic Era has no pings.
- **Pull countdown**: the PULL button or `/dyre pull 10` (`/dyre pull 0`
  cancels). With Deadly Boss Mods or BigWigs, they run the pull; else the
  game's countdown, which every group member sees. If the game refuses it
  (it may need the group leader), Dyre's Toolkit users in your group still
  get the toolkit's countdown.
- **Dyre's countdown on screen**: when anyone in your group starts a pull,
  a big number in the middle of the screen that pops each second (gold,
  then orange at 3, red at 1), a bar that drains over the whole pull, who
  started it, and a "PULL!" splash at 0; "Pull cancelled" on a cancel. It
  takes the place of the game's own countdown. It never overrides another
  AddOn: with BigWigs it stays hidden (BigWigs always shows its own pull
  bar); with Deadly Boss Mods it stays hidden unless you turn on DBM's own
  "Do not show Pull/Break Timer bar" (and "Do not show announce text") in
  /dbm > Global Disables & Filters > Disable DBM Features. Choose the
  tick and go sounds (game sounds, or Dyre's Sounds), the size, and the
  opacity; `/dyre unlock` to move it. The checkbox is only the display:
  sending a pull always uses the best path.
- `/dtt debug` also lists the boss mod and version each group member runs,
  as heard from Deadly Boss Mods' and BigWigs' own version messages
  (the toolkit sends nothing to find out).

The buttons are on one bar, and each has a key binding: Key Bindings >
AddOns > Dyre's Toolkit. The bar shows while you tank: group role Tank,
Defensive Stance, Bear Form, or Righteous Fury, and hides 30 seconds out of
combat after the last of them ends. Set it to Always or Never in the settings.
The settings are per character.

## What it gives you

- **One layout mode.** `/dyre unlock` shows every Dyre's AddOn's frames, so
  you can drag them where you want; `/dyre lock` locks them all again. Each
  AddOn's own unlock command does the same.
- **Snapping.** A frame you drop near another snaps beside it, also when the
  other frame belongs to a different Dyre's AddOn. Shift-drag moves a group of
  snapped frames together.
- **A grid** while frames are unlocked, with red lines through the center of
  the screen. Its size is a setting. With **Snap to the grid** (on by default), a dropped
  frame near a red center line centers on it, or puts its nearer edge on it.
  Elsewhere, an edge within a quarter of the grid size (8 at 32) of a grey
  line lines up with it. When both edges (left and right, or top and bottom)
  are that close, the one that moves the least wins, so the frame may line
  up at its lower-right corner rather than its upper-left: check both.
  Snapping to another Dyre's frame comes before the grid; a Shift-dragged
  group snaps to the grid as one block. Hold **Ctrl** as you drop a frame to
  place it exactly, with no snapping.
- **Move without unlocking.** Hold **Ctrl** and drag a frame by a button or
  a box's header to move it while frames are locked, as with Questie's
  tracker. It goes exactly where you drop it. Frames move only out of combat.
- **A minimap button.** Left-click locks or unlocks frames. Right-click opens a
  menu: lock or unlock, the grid switches, the settings, and each installed
  Dyre's AddOn's settings. `/dyre minimap` hides or shows the button.
- **One settings home.** Options → AddOns → **Dyre's AddOns** holds these
  settings, with each Dyre's AddOn's page under it. `/dyre` opens it.

Frames always start locked when you log in. Frames move only out of combat.

## Commands

| Command | What it does |
| --- | --- |
| `/dyre` | Opens the settings (out of combat) |
| `/dyre unlock`, `/dyre lock` | Unlocks or locks every Dyre's AddOn's frames |
| `/dyre grid` | Shows or hides the grid while unlocked |
| `/dyre snap` | Turns snapping to the grid on or off |
| `/dyre minimap` | Shows or hides the minimap button |
| `/dyre debug` | Until you reload: says in chat when another AddOn's hook into the toolkit fails, and lists those so far |
| `/dyre pull [seconds]` | Starts the pull countdown (1 to 60) |
| `/dyre tank_reset` | Puts the tank button bar back in its first place |
| `/dyre tank_debug`, `/dyre threat_debug`, `/dyre taunt_debug` | Diagnostics for the tank tools, the threat labels, and the party's taunts |
| `/dtt`, `/tanktools` | The same tank words, short: `/dtt pull 10`, `/dtt reset`, `/dtt debug`, `/dtt debug_threat`, `/dtt debug_taunts` |

`/dyretoolkit` works the same, in case another AddOn uses `/dyre`.

## For nameplate and unit frame authors

Dyre's AddOns that predict DoT damage draw a block and a **DIES** badge on
mob health bars. If your AddOn draws its own bars, or the badge covers
something of yours, `DyresToolkit.HealthBars` lets you say where your bar
is, where the badge goes, and when to draw nothing. You can also read the
prediction to show it your own way. See
[docs/HEALTHBARS_API.md](docs/HEALTHBARS_API.md).

## Compatibility

For the Forever beta client 1.60.1, build 70888, Interface 16001.

## Credits

DoT damage prediction on WoW: Forever follows the method of Does It Die, by
Joe Greive: casts, tooltips, and the timing of hits, with the damage meter
for tick sizes. The code is Dyre's own.

## Support

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

## License

MIT; see LICENSE. The embedded libraries keep their own terms: LibStub (public
domain), CallbackHandler-1.0 and LibDBIcon-1.0 (Ace3 BSD-style, see
`Libs/Ace3-LICENSE.txt`), and LibDataBroker-1.1 (its author asks AddOns to
embed it).
