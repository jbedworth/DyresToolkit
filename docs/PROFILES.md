# Dyre's Toolkit Profile (design, Toolkit 2.10.0)

Status: built in Profiles.lua (unreleased). The Toolkit's own settings are
its first part, applied live. Not checked in client. Each other Dyre's AddOn
adds its part in its own release.

Source request (a player, on CurseForge): "It would be great to see some kind
of profile options so I don't have to set it up separately for each
character." John: "I find myself doing this too."

## The model (John, 2026-11-15)

John, first: "I think it's important to preserve the current user's
configurations per character. So we will create a profile for each character
that has saved settings today, with those settings preserved. You can not
switch to another profile; however, you can copy settings from another
character's profile, or the Defaults (our default settings) if you want a
clean-slate. You can also export or import settings to a file (or a text
string the user can copy/paste)."

John, then: "Ultimately, what I want is profiles to be entirely owned by the
Toolkit. Settings for every Dyre addon, positions of every widget and visual,
sound selections, everything. Each character has it's own "Dyre's Toolkit
Profile" that they can copy, export, etc., and characters can copy from
another character, and that includes every setting for every Dyre addon."

Decisions (John, 2026-11-15):

- Each AddOn keeps its live settings in its own SavedVariables; the Toolkit
  owns the profile (the copies, the UI, the text line).
- Account-wide settings are not in a profile: "account-wide settings are for
  how the toolkit itself works; I think they are left out of the export
  because they are user-centric, not per character."
- "Hold and rebuild with this design": 2.10.0 ships this design, not the
  earlier per-AddOn Profile sections.
- Apply: "A reload is fine, other addons do this. Live apply would be cooler
  though." So live apply, with a reload only for an AddOn that cannot.

What the player gets:

- Each character has exactly one profile: its own, named "Name - Realm". A
  character with settings today keeps them, unchanged.
- One Profile section, at the end of the Toolkit's page. Its header names
  this character: "Profile: Name - Realm (Class)" (John: not seeing it "is
  disconcerting").
- **Copy settings from**: a dropdown with this character's own profile
  first ("(this character)"), chosen at first, then "Defaults" (a clean
  slate), then the other characters' profiles, with a Copy button at its
  right, on the same row. Copy is grey while this character is chosen (John,
  2026-11-15: "put my current character's profile in the list, fixed at the
  top, selected by default, with the "Copy" button disabled"). Copy
  overwrites this character's profile, every AddOn, after a confirm popup.
- **Export profile**: a popup with the whole profile as one text line,
  selected, for Ctrl+C.
- **Import profile**: a popup where the player pastes a line; it overwrites
  this character's profile, after a check.
- No switching and no shared profile.
- Not possible: export to a file. An AddOn cannot write or read files; the
  only disk storage is SavedVariables. So export and import are text only.

## Storage

- Live settings: each AddOn's own tables, as today. An AddOn without the
  Toolkit still works, nothing moves, and the minimum Toolkit version stays
  low (the rollout rule).
- Profile copies: `DyresToolkitDB.profiles["Name - Realm"] = {class, seen,
  parts = {[addon] = settings}, pending = {[addon] = settings}}`. Written at
  each AddOn's registration, after a copy or import, and at PLAYER_LOGOUT
  (the client writes SavedVariables after that event). This is the one
  exception to the family rule "the engine never owns SavedVariables".
- A part of an AddOn that is not loaded now stays in the profile, so a copy
  carries it on. A copied or imported part for such an AddOn waits in
  `pending` and is written when that AddOn next registers.
- The character key is `UnitName("player") .. " - " .. GetRealmName()`.
  Forever and Era installs have their own SavedVariables, so they never mix.
- `characterKeys`: an AddOn's keys that stay per character and are never
  copied, exported, or imported (owned macro names: macros are per
  character). Each owner session audits its own keys.
- Not in a profile: the Toolkit's account-wide settings (lock, grid, snap,
  grid size, minimap) and any AddOn's account tables.

## Registering a part (contract 2 addition; a dependent checks that it exists)

```lua
if DyresToolkit.RegisterProfilePart then
    DyresToolkit.RegisterProfilePart{
        addon = "DyresShieldsUp",                           -- folder name
        title = "Dyre's Shields Up",                        -- optional, for messages
        current = function() return DyresShieldsUpDB end,   -- the live table
        sanitize = function(settings) return ns.SanitizeDB(settings) end,
        characterKeys = {"ownedMacros"},                    -- optional
        refresh = function() ns.ApplySettings() end,        -- optional: live apply
    }
end
```

Register after the SavedVariables load and before the frames are built. No
account SavedVariables line is needed.

## Applying a copy or import

1. Refused in combat ("Settings change out of combat.").
2. All or nothing: every loaded part's `sanitize` runs first, on a copy, in
   pcall. If one fails, nothing changes and the player is told which AddOn.
3. Each part is written into its live table **in place**: the table is
   cleared and filled, and nested tables that exist are filled, not
   replaced. So widgets (`spec.store`), trackers (`store`), and settings
   closures that hold the table see the new values. `characterKeys` are not
   touched.
4. Each part's `refresh` runs, in pcall. The Toolkit's own
   (`DTT.ApplyProfile`) runs `ReapplyWidgets` (place, scale, size, opacity
   from the store, as at creation; a protected widget waits out combat),
   then the threat labels, tank bar, marker order, pull display, and Pet
   Taunt warning read the settings again.
5. Every Dyre's settings page tells its settings to read their values again
   (`setting:NotifyUpdate()`, Blizzard_Setting.lua: for "a source other than
   the setting object"), so an open page shows the new values.
6. A part with no `refresh`, or whose refresh failed, is saved, and a popup
   asks to reload ("Reload to finish ..."). Otherwise chat says "Profile
   copied." or "Profile imported."

Defaults: every loaded part is built from `{}` through its own `sanitize`;
each not-loaded part waits as `{}`.

## Export format

- `DYRE2:profile:<data>:<checksum>`. One line, printable ASCII, no `|` (the
  edit box reads `|` as an escape code), so it pastes in chat, Discord, and
  forums. The data maps each AddOn folder to its part.
- Strings, numbers, booleans, and nested tables only. Import parses it with
  the engine's own parser. It never uses `loadstring` or runs any part of
  the text. Limits: depth 20, 20000 items, 60000 characters.
- Import refuses: another kind of line, a bad checksum, a newer format, a
  `DYRE1` line from a test build, a part that is not an AddOn table, or text
  over the size limit. It says why, and changes nothing.
- Unknown keys are dropped and bad values are repaired by each `sanitize`,
  so a line from an older or newer version still imports what it can.

## Clean fallback (the rollout rule)

- An AddOn with an older Toolkit (no `RegisterProfilePart`) uses its own
  tables as today. No error.
- The live settings never leave the AddOn's tables, so this fallback shows
  the current settings.
- The minimum Toolkit version is not raised for profiles.

## Rollout

1. Toolkit 2.10.0: the engine, the one Profile section, and the Toolkit's
   own part (DyresToolkitCharDB, no `characterKeys`, live apply).
2. 24 h later or more, each AddOn in its own session and release: its
   `characterKeys` audit, its `RegisterProfilePart`, and a `refresh` for live
   apply (it may join with reload only first).

## Client facts checked (Gethe/wow-ui-source 943764493e6b)

- Settings dropdown options can be a function
  (Blizzard_Settings_Shared/Blizzard_SettingControls.lua), so the list of
  characters can change.
- No settings row has a dropdown and a button (Blizzard_SettingControls.lua);
  the settings list pools row frames and calls each initializer's Resetter
  before reuse (Blizzard_SettingsList.lua SetElementResetter), so the Copy
  button is attached in InitFrame and hidden in Resetter.
- `SettingMixin:NotifyUpdate` re-reads a setting and tells its controls
  (Blizzard_Setting.lua 185).
- StaticPopup has edit box support on both clients (GameDialog.lua).
- Not checked: the edit box's longest text on each client; live apply in
  client; Era's settings page with the attached Copy button.
