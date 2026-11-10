# DoT prediction on WoW: Forever (design)

Status: built in Toolkit 2.6.0 (John: "Yes, build it", 2026-11-08). Not yet checked in client.

## Goal

Make `CreateDotPredictor` (DotPredict.lua) work on Forever. Today it returns
nil and "the combat log" there, so WTF and DDT grey every prediction setting.
After this change, the same predictor draws the purple block and DIES on
Forever, and WTF and DDT get it with no new engine API.

## Evidence

- Does It Die v0.9.3 (Joe Greive, CurseForge 1709161) works on Forever without
  the combat log. John checked it in client, 2026-11-08. Its source is in
  `_forever_\Interface\AddOns\DoesItDie`. We take the method, not the code.
- Its in-client findings (its comments and CHANGELOG):
  - The combat log is blocked: registering it shows a popup.
  - In combat, `UNIT_COMBAT`'s amount is secret. Its action (WOUND, ABSORB,
    MISS...) and school are usually readable; the school is sometimes secret.
  - Target health and max health are secret. A StatusBar takes secret values,
    so the widget compares damage with health, not Lua.
  - Spell tooltips give base damage without spell power.
  - `C_DamageMeter` combat-session totals per spell become readable a few
    seconds after combat.
  - Creature GUIDs are secret in instances; in the open world they read.
  - Auras are secret in combat. It reads no auras.

## Design

A second input path in DotPredict.lua, chosen when `CombatLogUsable()` is
false and `UNIT_COMBAT` plus `C_DamageMeter` exist (gate on APIs, not on the
client). The output side (PredictedDamage, the HealthBars source, DrawRow,
DebugLines) stays the same.

### 1. Cast: which DoT, which mob

- `UNIT_SPELLCAST_SENT` (player): the mob of that name at the target, focus,
  soft enemy, or mouseover, keyed by castGUID (not `LockCast`: it needs a
  readable GUID). Players tab to the next mob before SUCCEEDED arrives.
  As Does It Die v0.9.3: no mob of that name goes to the target, or to the
  soft enemy when the target cannot be attacked (friendly, or none) or is a
  corpse. A named mob with no key (secret GUID, no plate) skips the cast;
  it is never put on the target (John, 2026-11-09).
- `UNIT_SPELLCAST_SUCCEEDED` (player): a ClassData rank, or a spell of a
  family's name (the client's own ID), starts the DoT on that mob. Base
  damage and duration come from its tooltip (English; Forever's numbers),
  else ClassData's rank; the interval from ClassData.
- Mob key: the GUID when it reads. When it is secret, the plate token key
  (`plate:nameplateN`, dropped at NAME_PLATE_UNIT_REMOVED), else "target"
  (dropped at PLAYER_TARGET_CHANGED). Instances then track per plate.
- `_FAILED`, `_INTERRUPTED`: drop the pending DoT.

### 2. Landed or avoided

- The first `UNIT_COMBAT` outcome on that mob within 0.4 s after the cast
  decides. An avoid (MISS, RESIST, IMMUNE...) drops the DoT, or restores the
  earlier one on a recast. A melee-only avoid (DODGE, PARRY) is not ours.
- An avoid in another school marks the DoT "doubtful": it shows from its
  first matched tick.

### 3. Ticks

- `UNIT_COMBAT` WOUND or ABSORB on target, focus, softenemy or a nameplate,
  with a readable school equal to the DoT's school.
- Match by time: the nearest open tick slot (applied + n x interval) within
  0.45 s, then 0.25 s once the first tick anchors the rhythm. One hit per
  slot. The same hit on two unit tokens in one frame counts once.
- A secret amount counts the tick only (no size). A readable amount (out of
  combat, or Era) is checked against the expected size and learned, as now.
- Two missed ticks on a mob a unit shows: the DoT was resisted, drop it. A
  mob no unit shows keeps its DoTs until they expire.

### 4. Size: spell power

- First guess: ClassData base plus spell power, as `GuessTotal`.
  `GetSpellBonusDamage` may be secret in combat, so read it out of combat
  and keep the last readable value (check in client).
- Learn after combat: at PLAYER_REGEN_ENABLED, read
  `C_DamageMeter.GetCombatSessionSourceFromType` for the player's spells,
  retry each 0.5 s, at most 10 s, until it reads. For each rank:
  measured total / (ticks counted x expected tick) is the factor. Use it only
  from 0.5 to 2.5, with 2 or more ticks, and no cast with an unknown mob.
  Store in `DyresToolkitDB.ticks[rank] = {tick, power}` as now, so Era and
  Forever share one store.
- Immolate's direct hit is in the meter total, so the meter teaches no
  Immolate tick (ClassData `direct = true`). Its tick comes from the guess,
  or from a tick learned on Era or out of combat (a readable amount).

### 5. Time: no polling

- No OnUpdate. One `C_Timer.After` per DoT for each expected tick plus its
  window (a missed tick), and one for its expiry, as the expiry timer now.
  The meter retry runs only after combat, for at most 10 s.

### 6. Drawing with secret health (HealthBars.lua)

- `DrawPrediction` takes a secret health. Without Lua comparisons:
  `SetMinMaxValues(0, health)`, `SetValue(damage)`; the StatusBar clamps,
  so no `math.min`.
- DIES: a clip frame (`SetClipsChildren(true)`) the size of the badge, at
  the badge's place. In it, an invisible StatusBar 10000 px wide, anchored by
  its right edge, max health, value damage. The badge hangs on the fill's
  right edge. It is in view only when damage >= health (the last
  badge width / 10000 of health).
- Then Lua cannot know if DIES shows, so `DrawPrediction` returns nil, not
  true or false. A tracker row then keeps its health number and puts DIES at
  the bar's right end. `HealthBars.WillDie` already gives nil for a secret
  health.
- Readable health (Era, out of combat) keeps today's path.

### 7. Owners and settings

- Owners do not change: WTF at 10 wins over DDT at 5 for Warlock.
- WTF: `predict.available` is already true when a predictor is made. Its
  tooltips' "Needs the combat log ... Forever support comes later" text must
  go (WTF session). DDT's comment at Engines.lua:104 too (DDT session).

## Limits (to say in the listings)

- In a group, another player's DoT of the same school and rhythm can count
  as yours (the amount is secret). It errs high there.
- A mob you tab away from, with no nameplate, ticks unseen: its DoTs run on
  time, not on ticks.
- The first fight after login guesses spell power until the meter teaches it.
- Curse of Agony's ramp comes from ClassData `weights`, as now.

## Tests

- Mock suite: secret values (the mock `issecretvalue`) for amount, health,
  GUID; UNIT_COMBAT sequences for landed, avoided, doubtful, ticks, missed
  ticks, two Shadow DoTs, a recast, plate keys; the meter read and its retry;
  the clip gate's geometry (fill end vs window).
- In client (John, Forever): block and DIES on target, focus, plates and DoT
  rows, solo and in a group; no taint or blocked-action popup; meter
  learning after two fights; Era unchanged.

## Release

Toolkit 2.6.0 (CONTRACT stays 2), then WTF and DDT text changes in their
next versions. Credit Does It Die in the Toolkit README for the method.
