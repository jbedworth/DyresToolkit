# HealthBars API

For authors of nameplate and unit frame AddOns. Dyre's AddOns that predict
damage (Dyre's Debuff Tracker, Warlock Tools Forever) draw two things on a
mob's health bar:

- **the block**: a striped span from the end of the health back toward the
  start, as wide as the damage the player's DoTs still have to deal;
- **the DIES badge**: a red skull and "DIES" beside the bar when that damage
  will kill the mob.

Dyre's Toolkit finds the bar on Blizzard's frames, Threat Plates, Plater,
Platynator, Shadowed Unit Frames, BetterBlizzFrames, and EllesmereUI by
itself. If your AddOn draws its own health bars, or the badge lands on top
of something yours shows, use this API to tell the toolkit where things go.

It lives at `DyresToolkit.HealthBars` (no new global), from Dyre's Toolkit
2.4.0. `HealthBars.API_VERSION` is 1. It goes up only for a change you must
know about; added functions keep it at 1, so check that a function exists
before you call it.

```lua
local api = DyresToolkit and DyresToolkit.HealthBars
if api and api.API_VERSION == 1 then
    -- register here
end
```

Add `## OptionalDeps: DyresToolkit` to your TOC so the toolkit loads first
when it is installed. Nothing else changes when it is not.

## Safety

Every function you give runs in `pcall`. One that errors is turned off until
the player reloads, and the bar falls back to the next adapter (Blizzard's
last). The error is said in chat only in debug mode: `/dyre debug` turns it
on until reload and lists the failures so far. Players never see a message
from a broken hook.

The toolkit never changes your frames. It puts its own child frame on your
bar, and reads anchors only (`GetPoint`, never `GetLeft` or `GetCenter`).
It never compares, prints, or indexes a secret value.

## Adapters

```lua
api.RegisterAdapter({
    name = "My Plates",                -- required; registering the same name again replaces it
    plate = function(plate, unit)      -- a Blizzard nameplate frame and its unit token
        local mine = plate.myPlate
        return mine and mine:IsShown() and mine.healthBar or nil
    end,
    unit = function(unit)              -- "target" or "focus"
        return MyTargetFrame and MyTargetFrame.healthBar or nil
    end,
    side = "right",                    -- optional: "left", "right", or "inside"
    anchor = {"LEFT", "RIGHT", 6, 0},  -- optional: exact {point, relativePoint, x, y} from the bar
    strata = "MEDIUM",                 -- optional: the badge's frame strata
    level = 12,                        -- optional: the badge's frame level above the bar
    avoid = function(plate, bar, unit) -- optional: the sides your frame writes on now
        return {right = plate and plate.myPlate.targetText:IsShown()}
    end,
    suppress = function(bar, unit)     -- optional: true, or a function; true means draw nothing
        return bar.showingCastBar
    end,
})
```

- Give `plate`, `unit`, or both. Each returns the StatusBar that shows the
  unit's health, or nil to let the next adapter look. A forbidden frame or a
  value without `GetStatusBarTexture` counts as nil.
- Registered adapters come before the built-in ones, in the order they
  registered.
- Where the badge goes: the player's own side setting in a Dyre's AddOn,
  then your `anchor`, then your `side`, then the toolkit's own choice (left
  of unit frames, right of nameplates, skipping a side that `avoid` or a
  text anchored there says is taken).
- `avoid` gets `plate` nil for unit frames. It is called each time the toolkit
  looks up the bar, which happens on events only.
- `api.UnregisterAdapter(name)` removes yours.

Returns `true`, or `false` and a reason (a bad field).

## Turning it off for one bar

```lua
api.SetSuppressed(bar, true)   -- hides the block and badge now, and draws nothing until...
api.SetSuppressed(bar, false)
```

The toolkit keeps the bar as a weak key, so a bar you throw away is let go.

## Asking for a redraw

```lua
api.Refresh(unit)   -- a unit token; nil for every unit
```

Call it when your frame changed (a new bar, a new layout). The Dyre's AddOn
that predicts damage draws again on the next frame, once, however often you
call it.

## Reading the prediction

```lua
local damage = api.GetPredictedDamage(unitOrGUID)  -- a number, or nil when no Dyre's AddOn knows
local dies = api.WillDie(unitOrGUID)               -- true, false, or nil when the health is secret

api.RegisterCallback("PREDICTION_CHANGED", function(event, unit, guid)
    -- unit or guid may be nil; this can come in combat
end)
api.UnregisterCallback("PREDICTION_CHANGED", callback)
```

Use these to draw the prediction your own way. Each mob is counted once: when
several Dyre's AddOns predict damage, only the highest-priority one answers
(Dyre's Debuff Tracker before Warlock Tools Forever).

On WoW: Forever, unit health is a secret value, so `WillDie` returns nil
there unless the predicting AddOn can tell by itself. The toolkit draws no
block or badge where the health is secret.

## For Dyre's AddOns only

`RegisterSource`, `SetSourceEnabled`, `IsActiveSource`, and `NotifyChanged`
are how Dyre's AddOns supply the prediction. They accept only an AddOn whose
TOC has `## Group: DyresToolkit`.

```lua
api.RegisterSource({
    addon = "DyresDebuffTracker",
    priority = 5,                            -- Warlock Tools Forever uses 10, and wins
    damage = function(unitOrGUID) ... end,   -- number or nil
    willDie = function(unitOrGUID) ... end,  -- optional: true, false, or nil
    refresh = function(unit) ... end,        -- optional: draw again (unit nil: all)
})
api.SetSourceEnabled(addon, on)   -- off while the player turned prediction off
api.IsActiveSource(addon)         -- draw only when true, so nothing is drawn twice
api.NotifyChanged(addon, unit, guid)
```
