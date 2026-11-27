local _, ns = ...
local DTT = ns.tank

-- Swing timer and range box (unreleased; John, 2026-11-24): for every class,
-- in the toolkit "for the same reason we didn't put the tanking stuff in its
-- own addon". One widget: a bar per swing (main hand, off hand, ranged) and a
-- box around them, green or red by range, with the state as text (RANGE,
-- MELEE, DEAD ZONE, TOO CLOSE, TOO FAR).
--
-- Sources, all events, no polling and no OnUpdate (checked in client on
-- Forever, 2026-11-24, John's probes):
--   - PLAYER_SWING (swingDuration, swingType 0 main hand, 1 off hand, 2
--     ranged) starts a bar; the bar fills itself (StatusBar:SetTimerDuration
--     with a C_DurationUtil duration). Forever only: Classic Era has no
--     PLAYER_SWING, so there only the range box works.
--   - C_Spell.EnableSpellRangeCheck(spell, true) and SPELL_RANGE_CHECK_UPDATE
--     (spellIdentifier, isInRange, checksRange) give range. The native swing
--     range (C_SwingTimer.EnableRangeCheck, PLAYER_SWING_RANGE_UPDATE) never
--     turned on in client (checksRange false, also in combat), so it is not
--     used. The client keeps a spell's range check on across /reload, so every
--     check turned on here is turned off again when no longer wanted.
--   - Ranged: Auto Shot (Hunter), else the equipped ranged weapon's shoot
--     spell (Shoot Bow, Shoot Gun, Shoot Crossbow, Throw, wand Shoot), by
--     name. Auto Shot by ID 75 said "in range" from too far away; by name it
--     was right.
--   - Melee: one instant melee spell per class (John: "Melee spell per
--     class"), each only after an in-client check: Hunter Wing Clip, all
--     ranks by name. Raptor Strike's range is true at every distance on
--     Forever (both reference AddOns say so too) and is never used.
--   - DEAD ZONE (John: every ranged weapon attack has it, bow, gun,
--     crossbow, thrown, Auto Shot; wands do not): ranged out of range and
--     the target near (CheckInteractDistance index 3, about 10 yards, read
--     once at each event; true in the dead zone and in melee, false out of
--     range, also in combat).
--   - Before a class has a melee check (a Hunter below level 12, John: "Yes,
--     use that"): TOO CLOSE covers the dead zone and melee together, and
--     MELEE shows while main-hand swings keep coming (PLAYER_SWING type 0),
--     until one swing time and a half second pass with none.
-- The order follows WeaponSwingTimer SixxFix (John: "Just follow what
-- weaponswingtimersixfixx does for now"): a ranged answer wins first, then
-- melee. Facts only from it and from ForeverHunterDeadzone (no license in
-- either): no code is copied.
--
-- Hunters (Auto Shot known): the last half second of the ranged bar is the
-- Auto Shot cast, the red "hold still" zone. Moving in it delays the shot.
-- Its label says HOLD STILL, or STOP while you move (PLAYER_STARTED_MOVING
-- and PLAYER_STOPPED_MOVING), from one-shot timers set at each shot.
--
-- Settings live in DyresToolkitCharDB.swing (so in the toolkit's profile
-- part), repaired in place at login (ns.SanitizeSwing, from Tank.lua's
-- SanitizeDB). Show: Off (never), In combat, or Always (John). Unlocked
-- frames show a sample to move, unless Show is Off.
local Swing = {}
ns.swing = Swing

Swing.SHOW_MODES = {"combat", "always", "off"}
Swing.SHOW_LABELS = {combat = "In combat", always = "Always", off = "Off (never show)"}
-- Off by default since 2.15.1 (John, 2026-11-26: "turn the Toolkit's swing
-- timer off by default first"; it moves to Dyre's Threat and Combat Tools).
Swing.DEFAULT_SHOW = "off"
Swing.THEME_KEYS = {"gold", "tactical"}
Swing.THEME_LABELS = {gold = "Gold and black", tactical = "Tactical black and red"}

-- Spells by Classic Era ID, used by name (the client's language, every rank).
Swing.AUTO_SHOT = 75
Swing.MELEE_PROBES = {HUNTER = {2974}}
-- The equipped ranged weapon's attack, by item subclass (Enum.ItemWeaponSubclass
-- on Classic Era: Bows 2, Guns 3, Thrown 16, Crossbow 18, Wand 19).
Swing.RANGED_BY_SUBCLASS = {[2] = 2480, [3] = 7918, [16] = 2764, [18] = 7919, [19] = 5019}
Swing.WAND = 19
Swing.RANGED_SLOT = 18
-- Index 3 of CheckInteractDistance: about 10 yards.
Swing.NEAR_INDEX = 3
-- A change of range state waits this long, so the flicker at an edge (Wing
-- Clip flipped every 0.3 s on the melee edge in client) does not blink the box.
Swing.SETTLE = 0.15
-- Auto Shot's cast at the end of each ranged swing: 0.5 s at the weapon's
-- own speed, scaled with ranged haste (0.5 x this swing / the weapon's base
-- speed; WeaponSwingTimer SixxFix's Forever finding, John: "Yes, both").
-- Without a base speed, 0.5 s.
Swing.HOLD = 0.5
-- Clip zones (John, 2026-11-24: "What about the aimed shot/sniper shot
-- clipping zones?", then "Build it now"): for each cast-time shot you know,
-- the part of the ranged bar where starting it overlaps Auto Shot's cast,
-- from (swing - HOLD - cast time) up to the red zone. Cast times are read
-- live (C_Spell.GetSpellInfo castTime, haste included) at each ranged swing.
-- Aimed Shot (Classic Era ID 19434; Forever: trainable at 20, a 2 s cast,
-- TalentsForeverBook) and Sniper Shot (Forever talent, 1310687). NOT CHECKED
-- IN CLIENT: the rule assumes Era's behavior, where a late cast pushes the
-- next Auto Shot back; John's Hunter is below level 20 (TESTING.md).
Swing.CLIP_SPELLS = {19434, 1310687}
local CLIP_COLORS = {{1, 0.5, 0.05, 0.5}, {1, 0.78, 0.2, 0.45}}
-- After the last main-hand swing, MELEE (without a melee check) holds this
-- much longer than the swing.
Swing.MELEE_GRACE = 0.5

Swing.STATE_TEXT = {range = "RANGE", melee = "MELEE", deadzone = "DEAD ZONE", close = "TOO CLOSE", far = "TOO FAR"}
Swing.GOOD = {range = true, melee = true}
local GREEN, RED = {0.15, 0.9, 0.25}, {0.95, 0.15, 0.1}

Swing.THEMES = {
    gold = {
        background = {0, 0, 0, 0.7}, border = {1, 0.82, 0}, text = {1, 0.82, 0},
        bars = {[0] = {0.85, 0.65, 0.2}, [1] = {0.7, 0.52, 0.18}, [2] = {0.95, 0.88, 0.45}},
        texture = "Interface\\TargetingFrame\\UI-StatusBar",
        edge = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, inset = 3,
    },
    tactical = {
        background = {0.03, 0.03, 0.03, 0.85}, border = {0.55, 0.05, 0.05}, text = {0.95, 0.22, 0.2},
        bars = {[0] = {0.72, 0.1, 0.1}, [1] = {0.52, 0.08, 0.08}, [2] = {0.78, 0.78, 0.78}},
        texture = "Interface\\Buttons\\WHITE8X8",
        edge = "Interface\\Buttons\\WHITE8X8", edgeSize = 2, inset = 2,
    },
}
local HOLD_COLOR = {0.95, 0.1, 0.1, 0.55}
local ROW_LABELS = {[0] = "Main hand", [1] = "Off hand", [2] = "Ranged"}

-- Layout, in widget units at 100%.
Swing.WIDTH = {min = 120, max = 400, step = 10, default = 220}
local PAD, ROW_HEIGHT, ROW_GAP, HEADER_HEIGHT = 6, 12, 3, 14

local function OneOf(value, choices, default)
    for _, choice in ipairs(choices) do
        if value == choice then
            return value
        end
    end
    return default
end

local function Flag(value, default)
    if type(value) == "boolean" then
        return value
    end
    return default
end

-- Opacity in and out of combat (John, 2026-11-24: "opacity settings for in
-- and out of combat (if someone sets show always)"): whole percent on steps
-- of 5, 10 to 100; else 100.
Swing.OPACITY = {min = 10, max = 100, step = 5, default = 100}
function Swing.SanitizeOpacity(value)
    local range = Swing.OPACITY
    if type(value) ~= "number" or value ~= value then
        return range.default
    end
    value = range.min + math.floor((value - range.min) / range.step + 0.5) * range.step
    return math.max(range.min, math.min(range.max, value))
end

-- Ranged first for the classes whose melee is a last resort (John: "If the
-- class is a Hunter (or I supposed a caster: Mage, Warlock, Priest) let's
-- always put the ranged timer on top"). The class orders rows only; it never
-- turns a feature on or off.
Swing.RANGED_FIRST = {HUNTER = true, MAGE = true, WARLOCK = true, PRIEST = true}
-- A bar in use stays this long after its swing ends (John: "hide/show the
-- timer bars that aren't being used and have the widget grow/shrink").
Swing.LINGER = 2

-- In place, so a widget's store (db.frame) and a profile's write keep the
-- same table.
function ns.SanitizeSwing(db)
    db = type(db) == "table" and db or {}
    -- 2.15.0 saved "combat" for every character as its default. Once, a saved
    -- "combat" from before 2.15.1 turns Off; a choice made after that stays.
    if db.defaultsVersion ~= 2 then
        if db.show == "combat" then
            db.show = Swing.DEFAULT_SHOW
        end
        db.defaultsVersion = 2
    end
    db.show = OneOf(db.show, Swing.SHOW_MODES, Swing.DEFAULT_SHOW)
    db.range = Flag(db.range, true)
    db.hold = Flag(db.hold, true)
    db.theme = OneOf(db.theme, Swing.THEME_KEYS, "gold")
    db.combatOpacity = Swing.SanitizeOpacity(db.combatOpacity)
    db.idleOpacity = Swing.SanitizeOpacity(db.idleOpacity)
    db.inUse = Flag(db.inUse, true)
    db.clip = Flag(db.clip, true)
    if type(db.frame) ~= "table" then
        db.frame = {}
    end
    return db
end

local function DB()
    local db = DTT.db.swing
    if type(db) ~= "table" then
        db = ns.SanitizeSwing(nil)
        DTT.db.swing = db
    end
    return db
end
Swing.DB = DB

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

-- From PLAYER_REGEN_DISABLED and _ENABLED: InCombatLockdown is still false
-- while PLAYER_REGEN_DISABLED runs.
local inCombat = false

local function InCombat()
    return inCombat
end

local function SpellName(identifier)
    if type(identifier) == "string" then
        return identifier
    end
    if type(identifier) ~= "number" then
        return nil
    end
    local read = type(C_Spell) == "table" and C_Spell.GetSpellName or rawget(_G, "GetSpellInfo")
    if type(read) ~= "function" then
        return nil
    end
    local name = read(identifier)
    if type(name) == "string" and not IsSecret(name) then
        return name
    end
end

-- The spell's name when the player knows it (any rank), else nil.
function Swing.Known(id)
    local name = SpellName(id)
    if not name then
        return nil
    end
    local book = rawget(_G, "C_SpellBook")
    if type(book) == "table" and type(book.FindSpellBookSlotForSpell) == "function" then
        local ok, slot = pcall(book.FindSpellBookSlotForSpell, name)
        if ok and slot ~= nil and not IsSecret(slot) then
            return name
        end
    end
    if type(IsPlayerSpell) == "function" and IsPlayerSpell(id) == true then
        return name
    end
    if type(book) == "table" and type(book.IsSpellKnown) == "function" and book.IsSpellKnown(id) == true then
        return name
    end
end

-- The equipped ranged weapon's item subclass, or nil.
function Swing.RangedSubclass()
    if type(GetInventoryItemID) ~= "function" then
        return nil
    end
    local item = GetInventoryItemID("player", Swing.RANGED_SLOT)
    if type(item) ~= "number" then
        return nil
    end
    local info = type(C_Item) == "table" and C_Item.GetItemInfoInstant or rawget(_G, "GetItemInfoInstant")
    if type(info) ~= "function" then
        return nil
    end
    local subclass = select(7, info(item))
    if type(subclass) == "number" then
        return subclass
    end
end

-- The equipped ranged weapon's base speed from its tooltip's Speed line (the
-- game's own label, SPEED), cached per item; nil when it cannot be read.
local baseSpeeds = {}

local function SpeedIn(text)
    if type(text) ~= "string" or IsSecret(text) then
        return nil
    end
    local label = type(SPEED) == "string" and SPEED or "Speed"
    local start = text:find(label, 1, true)
    local number = start and text:match("(%d+[%.,]%d+)", start)
    return number and tonumber((number:gsub(",", ".")))
end

function Swing.RangedBaseSpeed()
    if type(GetInventoryItemID) ~= "function" then
        return nil
    end
    local item = GetInventoryItemID("player", Swing.RANGED_SLOT)
    if type(item) ~= "number" then
        return nil
    end
    if baseSpeeds[item] ~= nil then
        return baseSpeeds[item] or nil
    end
    local info = rawget(_G, "C_TooltipInfo")
    local data = type(info) == "table" and type(info.GetItemByID) == "function" and info.GetItemByID(item)
    local speed
    if type(data) == "table" then
        if type(TooltipUtil) == "table" and type(TooltipUtil.SurfaceArgs) == "function" then
            TooltipUtil.SurfaceArgs(data)
        end
        for _, line in ipairs(type(data.lines) == "table" and data.lines or {}) do
            speed = SpeedIn(line.rightText) or SpeedIn(line.leftText)
            if speed then
                break
            end
        end
    end
    if speed and speed > 0 then
        baseSpeeds[item] = speed
    elseif type(data) == "table" then
        -- Read, but no Speed line: do not ask again for this item.
        baseSpeeds[item] = false
    end
    return speed and speed > 0 and speed or nil
end

-- Auto Shot's cast for a ranged swing of this length.
function Swing.HoldTime(duration)
    local base = Swing.RangedBaseSpeed()
    local hold = Swing.HOLD
    if base and type(duration) == "number" and duration > 0 then
        hold = Swing.HOLD * duration / base
    end
    if type(duration) == "number" and duration > 0 then
        hold = math.min(hold, duration)
    end
    return hold
end

-- The range state from what is known now (a pure rule, tested on its own).
-- s.hostile: a live enemy target; s.ranged, s.melee: true, false, or nil (no
-- answer); s.meleeProbe: the class has a melee check; s.deadZone: the ranged
-- attack has a minimum range; s.near(): the target within about 10 yards
-- (read only when needed); s.recentMelee: a main-hand swing just now.
function Swing.RangeState(s)
    if not s.hostile then
        return nil
    end
    if s.ranged == true then
        return "range"
    end
    if s.melee == true then
        return "melee"
    end
    if not s.meleeProbe and s.recentMelee then
        return "melee"
    end
    if s.ranged == false then
        if s.deadZone and s.near() then
            return s.meleeProbe and "deadzone" or "close"
        end
        return "far"
    end
    if s.melee == false then
        return "far"
    end
    return nil
end

-- State --------------------------------------------------------------------------------

local widget, events
local rows = {}
local probes = {}
local shown, pending, settleTimer
local lastMelee, meleeTimer
local holding, moving, holdTimers = false, false, {}
-- The ranged bar restarted by a melee swing (grey until the next shot).
local rangedReset = false
local RESET_COLOR = {0.55, 0.55, 0.55}
local lastRanged
local ohSeen = false
-- Per swing type: the time its row stops being in use, and the one-shot
-- timer that shrinks the frame then.
local activeUntil, activeTimers = {}, {}

local function Cancel(timer)
    if timer and type(timer.Cancel) == "function" then
        timer:Cancel()
    end
end

local function NewTimer(seconds, callback)
    if type(C_Timer) == "table" and type(C_Timer.NewTimer) == "function" then
        return C_Timer.NewTimer(seconds, callback)
    end
end

local function EventExists(event)
    return DTT.EventExists(event)
end

function Swing.Theme()
    return Swing.THEMES[DB().theme] or Swing.THEMES.gold
end

local function Unlocked()
    return ns.db.locked == false
end

local function BarsAvailable()
    return Swing.barsAvailable == true
end

local function RangeAvailable()
    return Swing.rangeAvailable == true
end

local function RangeWanted()
    local db = DB()
    return RangeAvailable() and db.range and db.show ~= "off"
end

function Swing.Visible()
    local db = DB()
    if db.show == "off" then
        return false
    end
    return Unlocked() or db.show == "always" or (db.show == "combat" and InCombat())
end

local function HoldWanted()
    return DB().hold and Swing.Known(Swing.AUTO_SHOT) ~= nil
end

-- Range checks -----------------------------------------------------------------------

local function EnableCheck(name, enable)
    if type(C_Spell) == "table" and type(C_Spell.EnableSpellRangeCheck) == "function" then
        C_Spell.EnableSpellRangeCheck(name, enable)
    end
end

-- The checks this character wants now: its melee spell, and Auto Shot or the
-- equipped ranged weapon's shoot spell. Old ones are turned off.
function Swing.SetupProbes()
    local wanted = {}
    if RangeWanted() then
        local class = DTT.classFile
        for _, id in ipairs(Swing.MELEE_PROBES[class] or {}) do
            local name = Swing.Known(id)
            if name then
                wanted[name] = "melee"
            end
        end
        local ranged = Swing.Known(Swing.AUTO_SHOT)
        local subclass = Swing.RangedSubclass()
        if not ranged and subclass and Swing.RANGED_BY_SUBCLASS[subclass] then
            ranged = Swing.Known(Swing.RANGED_BY_SUBCLASS[subclass])
        end
        if ranged then
            wanted[ranged] = "ranged"
        end
        Swing.deadZone = ranged ~= nil and subclass ~= Swing.WAND
    end
    for name in pairs(probes) do
        if not wanted[name] then
            EnableCheck(name, false)
            probes[name] = nil
        end
    end
    for name, kind in pairs(wanted) do
        if not probes[name] or probes[name].kind ~= kind then
            probes[name] = {kind = kind, inRange = nil}
            EnableCheck(name, true)
        end
    end
end

function Swing.Probes()
    return probes
end

local function Answer(kind)
    local answer
    for _, probe in pairs(probes) do
        if probe.kind == kind and probe.inRange ~= nil then
            answer = answer or probe.inRange
        end
    end
    return answer
end

local function HasProbe(kind)
    for _, probe in pairs(probes) do
        if probe.kind == kind then
            return true
        end
    end
    return false
end

local function Hostile()
    if type(UnitExists) ~= "function" or not UnitExists("target") then
        return false
    end
    if type(UnitCanAttack) == "function" then
        local can = UnitCanAttack("player", "target")
        if IsSecret(can) or not can then
            return false
        end
    end
    if type(UnitIsDeadOrGhost) == "function" then
        local dead = UnitIsDeadOrGhost("target")
        if not IsSecret(dead) and dead then
            return false
        end
    end
    return true
end

local function Near()
    if type(CheckInteractDistance) ~= "function" then
        return false
    end
    local near = CheckInteractDistance("target", Swing.NEAR_INDEX)
    return not IsSecret(near) and near == true
end

local function RecentMelee()
    return lastMelee ~= nil and Now() - lastMelee.at <= lastMelee.duration + Swing.MELEE_GRACE
end

function Swing.CurrentState()
    if not RangeWanted() then
        return nil
    end
    return Swing.RangeState({
        hostile = Hostile(),
        ranged = Answer("ranged"),
        melee = Answer("melee"),
        meleeProbe = HasProbe("melee"),
        deadZone = Swing.deadZone == true,
        near = Near,
        recentMelee = RecentMelee(),
    })
end

function Swing.ShownState()
    return shown
end

local Paint

-- A new state waits SETTLE seconds; one that comes back in time cancels it.
function Swing.Evaluate()
    local state = Swing.CurrentState()
    if state == shown then
        Cancel(settleTimer)
        settleTimer, pending = nil, nil
        return
    end
    if state == pending and settleTimer then
        return
    end
    Cancel(settleTimer)
    pending = state
    settleTimer = NewTimer(Swing.SETTLE, function()
        settleTimer, pending = nil, nil
        shown = Swing.CurrentState()
        Swing.Refresh()
    end)
    if not settleTimer then
        pending = nil
        shown = state
        Swing.Refresh()
    end
end

local function OnRangeUpdate(spell, inRange, checksRange)
    if IsSecret(spell) or IsSecret(inRange) or IsSecret(checksRange) then
        return
    end
    local name = SpellName(spell)
    local probe = name and probes[name]
    if not probe then
        return
    end
    if checksRange == true then
        probe.inRange = inRange == true
    else
        probe.inRange = nil
    end
    Swing.Evaluate()
end

-- Swing bars -------------------------------------------------------------------------

-- The rows top to bottom: ranged first for a class whose melee is a last
-- resort, else main hand, off hand, ranged.
function Swing.RowOrder()
    if Swing.RANGED_FIRST[DTT.classFile] then
        return {2, 0, 1}
    end
    return {0, 1, 2}
end

local function HasRanged()
    return Swing.RangedSubclass() ~= nil or lastRanged ~= nil
end

-- A row the character can use at all: main hand always, off hand once it
-- swung (until equipment changes), ranged with a ranged weapon.
local function RowPossible(swingType)
    if swingType == 0 then
        return true
    elseif swingType == 1 then
        return ohSeen
    end
    return HasRanged()
end

-- A swing of this type is running or just ended (LINGER).
local function Active(swingType)
    local until_ = activeUntil[swingType]
    return until_ ~= nil and Now() < until_
end

-- The row always shown: ranged for a ranged-first class with a ranged
-- weapon, else main hand.
function Swing.PrimaryRow()
    if Swing.RANGED_FIRST[DTT.classFile] and HasRanged() then
        return 2
    end
    return 0
end

local function InUse(swingType)
    if Active(swingType) then
        return true
    end
    -- In melee range: the main hand row too (John: a Hunter "sees the ranged
    -- timer bar, unless he gets into melee range").
    return swingType == 0 and shown == "melee"
end

local function RowShown(swingType)
    if not BarsAvailable() or not RowPossible(swingType) and not Unlocked() then
        return false
    end
    if Unlocked() or not DB().inUse then
        return true
    end
    -- The primary row always; the others while in use.
    return swingType == Swing.PrimaryRow() or InUse(swingType)
end

local function ShownRows()
    local list = {}
    for _, swingType in ipairs(Swing.RowOrder()) do
        if rows[swingType] and RowShown(swingType) then
            list[#list + 1] = swingType
        end
    end
    return list
end
Swing.ShownRows = ShownRows

local function HeaderShown()
    return RangeWanted()
end

local function Measure()
    local count = #ShownRows()
    local height = 2 * PAD + count * ROW_HEIGHT + math.max(0, count - 1) * ROW_GAP
    if HeaderShown() then
        height = height + HEADER_HEIGHT + ROW_GAP
    end
    local width = widget and widget:GetSetting("width") or Swing.WIDTH.default
    return width, height
end

local function SetColor(texture, color)
    if texture and color then
        texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
end

local function HoldWidth(duration)
    local row = rows[2]
    if not row or type(duration) ~= "number" or duration <= 0 then
        return 0
    end
    return row.width * math.min(1, Swing.HoldTime(duration) / duration)
end

-- A known spell's cast time in seconds, or nil (unknown, instant, secret).
function Swing.CastTime(id)
    local name = Swing.Known(id)
    local info = name and type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function"
        and C_Spell.GetSpellInfo(name)
    local cast = type(info) == "table" and info.castTime
    if IsSecret(cast) or type(cast) ~= "number" or cast ~= cast or cast <= 0 then
        return nil
    end
    return cast / 1000
end

-- The clip zones' widths in bar pixels for a ranged swing, by CLIP_SPELLS
-- order (0 for a shot not known or instant): from (swing - HOLD - cast) to
-- the red zone, at most the whole bar before it.
function Swing.ClipWidths(duration, barWidth)
    local widths = {}
    for index, id in ipairs(Swing.CLIP_SPELLS) do
        local cast = Swing.CastTime(id)
        local free = duration - Swing.HoldTime(duration)
        if cast and free > 0 then
            widths[index] = barWidth * math.min(cast, free) / duration
        else
            widths[index] = 0
        end
    end
    return widths
end

local function PlaceHold()
    local row = rows[2]
    if not row then
        return
    end
    local wanted = HoldWanted()
    local width = HoldWidth(lastRanged)
    if wanted and width > 0 then
        row.hold:SetWidth(width)
        row.hold:Show()
    else
        row.hold:Hide()
    end
    local widths = (wanted and DB().clip and type(lastRanged) == "number" and lastRanged > 0)
        and Swing.ClipWidths(lastRanged, row.width) or {}
    for index, zone in ipairs(row.clips) do
        local clip = widths[index] or 0
        zone:ClearAllPoints()
        if clip > 0 then
            zone:SetPoint("TOPRIGHT", row.bar, "TOPRIGHT", -width, 0)
            zone:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", -width, 0)
            zone:SetWidth(clip)
            zone:Show()
        else
            zone:Hide()
        end
    end
end

local function RowLabel(swingType)
    if swingType == 2 and holding then
        return moving and "STOP" or "HOLD STILL"
    end
    return ROW_LABELS[swingType]
end

local function PaintRows()
    local theme = Swing.Theme()
    for swingType = 0, 2 do
        local row = rows[swingType]
        if row then
            row.bar:SetStatusBarTexture(theme.texture)
            local color = (swingType == 2 and rangedReset) and RESET_COLOR or theme.bars[swingType]
            row.bar:SetStatusBarColor(color[1], color[2], color[3], 1)
            row.label:SetText(RowLabel(swingType))
            if swingType == 2 and holding then
                row.label:SetTextColor(RED[1], RED[2], RED[3])
            else
                row.label:SetTextColor(1, 1, 1)
            end
        end
    end
end

local function Layout(width)
    if not widget then
        return
    end
    -- From the setting, not GetWidth: reading a placed frame's geometry makes
    -- the client lay out pending frames inside our call (Widgets.lua rule).
    width = width or widget:GetSetting("width") or Swing.WIDTH.default
    local barWidth = math.max(1, width - 2 * PAD)
    local top = -PAD
    widget.handle:ClearAllPoints()
    widget.handle:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, 0)
    widget.handle:SetPoint("TOPRIGHT", widget, "TOPRIGHT", 0, 0)
    widget.handle:SetHeight(PAD + (HeaderShown() and HEADER_HEIGHT or ROW_HEIGHT))
    widget.header:ClearAllPoints()
    if HeaderShown() then
        widget.header:SetPoint("TOP", widget, "TOP", 0, top)
        widget.header:Show()
        top = top - HEADER_HEIGHT - ROW_GAP
    else
        widget.header:Hide()
    end
    for _, swingType in ipairs(Swing.RowOrder()) do
        local row = rows[swingType]
        if row then
            row.frame:ClearAllPoints()
            if RowShown(swingType) then
                row.frame:SetPoint("TOPLEFT", widget, "TOPLEFT", PAD, top)
                row.frame:SetSize(barWidth, ROW_HEIGHT)
                row.width = barWidth
                row.frame:Show()
                top = top - ROW_HEIGHT - ROW_GAP
            else
                row.frame:Hide()
            end
        end
    end
    PlaceHold()
end

-- The box, the state text, and the bars' colors.
function Paint()
    if not widget then
        return
    end
    local theme = Swing.Theme()
    local state = shown
    if Unlocked() and state == nil and RangeWanted() then
        state = "range"
    end
    local border = theme.border
    if state then
        border = Swing.GOOD[state] and GREEN or RED
    end
    widget.box:SetBackdropColor(theme.background[1], theme.background[2], theme.background[3],
        theme.background[4])
    widget.box:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    widget.header:SetText(state and Swing.STATE_TEXT[state] or "")
    if state then
        widget.header:SetTextColor(border[1], border[2], border[3])
    else
        widget.header:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
    end
    PaintRows()
end

local function ApplyTheme()
    if not widget then
        return
    end
    local theme = Swing.Theme()
    if type(widget.box.SetBackdrop) == "function" then
        widget.box:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = theme.edge,
            edgeSize = theme.edgeSize, insets = {left = theme.inset, right = theme.inset, top = theme.inset,
            bottom = theme.inset}})
    end
    Paint()
end

-- Shows, hides, and resizes from what is wanted now.
function Swing.Refresh()
    if not widget then
        return
    end
    local width, height = Measure()
    widget:SetContentSize(width, height, "TOP")
    Layout()
    widget:SetShown(Swing.Visible())
    Swing.ApplyOpacity()
    Paint()
end

-- In combat, out of combat, or full while unlocked (to place it).
function Swing.Opacity()
    if Unlocked() then
        return 1
    end
    local db = DB()
    return (InCombat() and db.combatOpacity or db.idleOpacity) / 100
end

function Swing.ApplyOpacity()
    if widget then
        widget:SetAlpha(Swing.Opacity())
    end
end

local function SampleBars()
    for swingType = 0, 2 do
        local row = rows[swingType]
        if row then
            row.bar:SetMinMaxValues(0, 1)
            row.bar:SetValue(0.35 + 0.2 * swingType)
        end
    end
end

local function ClearBars()
    for swingType = 0, 2 do
        local row = rows[swingType]
        if row then
            row.bar:SetMinMaxValues(0, 1)
            row.bar:SetValue(0)
        end
    end
end

local function LeaveHold()
    holding = false
    PaintRows()
end

local function EnterHold()
    holding = true
    PaintRows()
end

local function StartBar(row, duration)
    local make = type(C_DurationUtil) == "table" and C_DurationUtil.CreateDuration
    if type(make) ~= "function" or type(row.bar.SetTimerDuration) ~= "function" then
        return false
    end
    local timer = make()
    timer:SetTimeFromStart(Now(), duration)
    row.bar:SetTimerDuration(timer)
    return true
end

-- The hold-still label's two one-shot timers for a ranged swing starting now.
local function StartHold(duration)
    for _, timer in ipairs(holdTimers) do
        Cancel(timer)
    end
    holdTimers = {}
    LeaveHold()
    if HoldWanted() then
        holdTimers[1] = NewTimer(math.max(0, duration - Swing.HoldTime(duration)), EnterHold)
        holdTimers[2] = NewTimer(duration, LeaveHold)
    end
end

-- PLAYER_SWING: a bar starts over. Secret or odd values are skipped.
function Swing.OnSwing(duration, swingType)
    if IsSecret(duration) or IsSecret(swingType) or type(duration) ~= "number" or duration ~= duration
            or duration <= 0 or duration == math.huge then
        return
    end
    local row = rows[swingType]
    if not row then
        return
    end
    local before = table.concat(ShownRows(), ",")
    activeUntil[swingType] = Now() + duration + Swing.LINGER
    Cancel(activeTimers[swingType])
    activeTimers[swingType] = NewTimer(duration + Swing.LINGER, function()
        activeTimers[swingType] = nil
        Swing.Refresh()
    end)
    if swingType == 0 then
        lastMelee = {at = Now(), duration = duration}
        Cancel(meleeTimer)
        meleeTimer = NewTimer(duration + Swing.MELEE_GRACE, Swing.Evaluate)
        Swing.Evaluate()
    elseif swingType == 1 then
        ohSeen = true
    elseif swingType == 2 then
        lastRanged = duration
        rangedReset = false
        StartHold(duration)
    end
    -- A melee swing restarts the ranged timer on Forever (WeaponSwingTimer
    -- SixxFix's finding; John: "Yes, both"): the ranged bar starts over from
    -- now with the last ranged length, grey until the next shot.
    if swingType ~= 2 and lastRanged and rows[2] then
        rangedReset = true
        StartHold(lastRanged)
        StartBar(rows[2], lastRanged)
        PaintRows()
    end
    -- Grow or shrink only when the rows shown change.
    if table.concat(ShownRows(), ",") ~= before then
        Swing.Refresh()
    elseif swingType == 2 then
        PlaceHold()
        PaintRows()
    end
    StartBar(row, duration)
end

-- The frame ------------------------------------------------------------------------------

local function NewRow(swingType)
    local frame = CreateFrame("Frame", nil, widget)
    local back = frame:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(frame)
    back:SetTexture("Interface\\Buttons\\WHITE8X8")
    SetColor(back, {0, 0, 0, 0.5})
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetAllPoints(frame)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local row = {frame = frame, bar = bar, width = Swing.WIDTH.default - 2 * PAD}
    if swingType == 2 then
        row.hold = bar:CreateTexture(nil, "OVERLAY")
        row.hold:SetTexture("Interface\\Buttons\\WHITE8X8")
        SetColor(row.hold, HOLD_COLOR)
        row.hold:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        row.hold:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        row.hold:Hide()
        -- The clip zones, under the red zone: Aimed Shot, then Sniper Shot over it.
        row.clips = {}
        for index, color in ipairs(CLIP_COLORS) do
            local zone = bar:CreateTexture(nil, "OVERLAY", nil, index - 3)
            zone:SetTexture("Interface\\Buttons\\WHITE8X8")
            SetColor(zone, color)
            zone:Hide()
            row.clips[index] = zone
        end
    end
    -- On its own frame above the bar, so the fill never covers it.
    local text = CreateFrame("Frame", nil, frame)
    text:SetAllPoints(frame)
    text:SetFrameLevel(bar:GetFrameLevel() + 2)
    row.label = text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", frame, "LEFT", 4, 0)
    return row
end

local function Build()
    widget = ns.toolkit.CreateWidget({
        addon = DTT.ADDON, key = "swing", title = "Swing timer", name = "DyresToolkitSwingTimer",
        store = DB().frame, width = Swing.WIDTH.default, height = 60,
        point = {"CENTER", "CENTER", 0, -160},
        -- Opacity is this file's own, in and out of combat (Swing.Opacity).
        sizes = {scale = true, width = Swing.WIDTH},
        measure = function() return Measure() end,
        hint = "Swing timer · drag to move · /dyre lock when done",
        onLayout = function(_, width) Layout(width) end,
        onUnlock = function(_, unlocked)
            if unlocked then
                SampleBars()
            else
                ClearBars()
            end
            Swing.Refresh()
        end,
    })
    widget:SetFrameStrata("MEDIUM")
    widget.box = CreateFrame("Frame", nil, widget, "BackdropTemplate")
    widget.box:SetAllPoints(widget)
    widget.box:SetFrameLevel(math.max(0, widget:GetFrameLevel()))
    -- On its own frame above the box and the bars, so neither covers it.
    local top = CreateFrame("Frame", nil, widget)
    top:SetAllPoints(widget)
    top:SetFrameLevel(widget:GetFrameLevel() + 6)
    widget.header = top:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- A thin strip along the top takes the mouse also while locked, so a
    -- Ctrl-drag can move the frame then (the toolkit's locked-move rule needs
    -- a part that takes the mouse); the rest stays click-through.
    widget.handle = CreateFrame("Frame", nil, widget)
    widget.handle:SetFrameLevel(widget:GetFrameLevel() + 7)
    widget.handle:EnableMouse(true)
    widget:AddDragHandle(widget.handle)
    for swingType = 0, 2 do
        rows[swingType] = NewRow(swingType)
    end
    ApplyTheme()
    Swing.Refresh()
end

function Swing.Widget()
    return widget
end

function Swing.Rows()
    return rows
end

-- Events ---------------------------------------------------------------------------------

local function OnEvent(_, event, ...)
    if event == "PLAYER_SWING" then
        Swing.OnSwing(...)
    elseif event == "SPELL_RANGE_CHECK_UPDATE" then
        OnRangeUpdate(...)
    elseif event == "PLAYER_TARGET_CHANGED" then
        for _, probe in pairs(probes) do
            probe.inRange = nil
        end
        Swing.Evaluate()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        inCombat = event == "PLAYER_REGEN_DISABLED"
        if not inCombat and not Unlocked() then
            ClearBars()
        end
        Swing.Refresh()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ohSeen, lastRanged, rangedReset = false, nil, false
        Swing.SetupProbes()
        Swing.Refresh()
        Swing.Evaluate()
    elseif event == "SPELLS_CHANGED" then
        Swing.SetupProbes()
        Swing.Evaluate()
    elseif event == "PLAYER_STARTED_MOVING" or event == "PLAYER_STOPPED_MOVING" then
        moving = event == "PLAYER_STARTED_MOVING"
        if holding then
            PaintRows()
        end
    end
end

local EVENTS = {"PLAYER_SWING", "SPELL_RANGE_CHECK_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "PLAYER_STARTED_MOVING",
    "PLAYER_STOPPED_MOVING"}

local function CheckAPIs()
    Swing.barsAvailable = EventExists("PLAYER_SWING") and type(C_DurationUtil) == "table"
        and type(C_DurationUtil.CreateDuration) == "function"
    Swing.rangeAvailable = EventExists("SPELL_RANGE_CHECK_UPDATE") and type(C_Spell) == "table"
        and type(C_Spell.EnableSpellRangeCheck) == "function"
    return Swing.barsAvailable or Swing.rangeAvailable
end

-- A setting changed, or a profile was applied.
function ns.RefreshSwing()
    if not widget then
        return
    end
    ApplyTheme()
    Swing.SetupProbes()
    Swing.Refresh()
    Swing.Evaluate()
end

-- From Tank.lua's InitializeTank, right after the saved settings load (so
-- also on a client without the threat API). Quiet at login.
function ns.InitializeSwing()
    if widget or not CheckAPIs() then
        return
    end
    events = CreateFrame("Frame")
    for _, event in ipairs(EVENTS) do
        if EventExists(event) then
            events:RegisterEvent(event)
        end
    end
    events:SetScript("OnEvent", OnEvent)
    inCombat = type(InCombatLockdown) == "function" and InCombatLockdown() == true
    Build()
    Swing.SetupProbes()
    Swing.Evaluate()
end

-- Settings: a section on the toolkit's page, before the profile -------------------------

local category, layout

local function Section(text)
    if type(CreateSettingsListSectionHeaderInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

local function Proxy(variable, variableType, name, default, getValue, setValue)
    return Settings.RegisterProxySetting(category, variable, variableType, name, default, getValue, setValue)
end

local function Checkbox(variable, name, key, default, tooltip)
    local setting = Proxy(variable, Settings.VarType.Boolean, name, default,
        function() return DB()[key] end,
        function(value)
            DB()[key] = value == true
            ns.RefreshSwing()
        end)
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function Dropdown(variable, name, key, choices, labels, default, tooltip)
    if type(Settings.CreateDropdown) ~= "function" or type(Settings.CreateControlTextContainer) ~= "function" then
        return
    end
    local setting = Proxy(variable, Settings.VarType.String, name, default,
        function() return DB()[key] end,
        function(value)
            DB()[key] = OneOf(value, choices, DB()[key])
            -- A Show the player chose, so Dyre's Threat and Combat Tools can
            -- tell a chosen Off from 2.15.1's default Off when it copies it.
            if key == "show" then
                DB().showChosen = true
            end
            ns.RefreshSwing()
        end)
    local function Options()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(choices) do
            container:Add(choice, labels[choice])
        end
        return container:GetData()
    end
    Settings.CreateDropdown(category, setting, Options, tooltip)
end

-- A percent slider with its number at the right and the gold default mark.
local function OpacitySlider(variable, name, key, tooltip)
    local range = Swing.OPACITY
    local setting = Proxy(variable, Settings.VarType.Number, name, range.default,
        function() return DB()[key] end,
        function(value)
            DB()[key] = Swing.SanitizeOpacity(value)
            Swing.ApplyOpacity()
        end)
    local options = Settings.CreateSliderOptions(range.min, range.max, range.step)
    if type(options.SetLabelFormatter) == "function" and type(MinimalSliderWithSteppersMixin) == "table"
            and MinimalSliderWithSteppersMixin.Label then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return string.format("%d%%", value) end)
    end
    ns.AddDefaultTick(Settings.CreateSlider(category, setting, options, tooltip), range)
end

function ns.AddSwingSettings(pageCategory, pageLayout)
    category, layout = pageCategory, pageLayout
    Section("Swing Timer")
    Dropdown("DYRE_SWING_SHOW", "Show", "show", Swing.SHOW_MODES, Swing.SHOW_LABELS, Swing.DEFAULT_SHOW,
        "A bar for each swing: main hand, off hand (once it swings), and ranged (with a ranged weapon), in a "
        .. "box that turns green or red by your target's range.\n\nIn combat: shown in combat. Always: shown "
        .. "all the time. Off: never shown, also while frames are unlocked.\n\nThe bars need WoW: Forever's "
        .. "swing event; on Classic Era only the range box works.")
    OpacitySlider("DYRE_SWING_OPACITY_COMBAT", "Opacity in combat", "combatOpacity",
        "How solid the swing timer is in combat. It changes at once.")
    OpacitySlider("DYRE_SWING_OPACITY_IDLE", "Opacity out of combat", "idleOpacity",
        "How solid the swing timer is out of combat, with Show set to Always. While frames are unlocked it is "
        .. "always solid, to place it.")
    Checkbox("DYRE_SWING_IN_USE", "Only bars in use", "inUse", true,
        "On: a bar shows only while you use it (a swing running, or just ended), and the frame grows and "
        .. "shrinks to fit. One bar always stays: ranged for a Hunter, Mage, Warlock, or Priest with a ranged "
        .. "weapon, else main hand. A Hunter shooting sees the ranged bar; in melee range, or swinging, the "
        .. "main-hand bar joins it. Off: every bar your weapons can use, all the time.")
    Checkbox("DYRE_SWING_RANGE", "Range box", "range", true,
        "The box around the bars turns green in range and red out of range, with the state as text: RANGE, "
        .. "MELEE, DEAD ZONE (too close for a bow, gun, crossbow, thrown weapon, or Auto Shot; not a wand), "
        .. "TOO CLOSE, or TOO FAR.\n\nMELEE and DEAD ZONE apart need your class's melee check (a Hunter: Wing "
        .. "Clip, from level 12). Until then, TOO CLOSE covers both, and MELEE shows while your melee swings "
        .. "keep landing.")
    Checkbox("DYRE_SWING_HOLD", "Auto Shot: hold still zone", "hold", true,
        "Hunters: the last half second of the ranged bar is red. That is Auto Shot's cast: moving then delays "
        .. "your shot. The bar's label says HOLD STILL, or STOP while you move.")
    Checkbox("DYRE_SWING_CLIP", "Auto Shot: clip zones", "clip", true,
        "Hunters: orange on the ranged bar before the red zone, one shade for Aimed Shot and one for Sniper "
        .. "Shot (when you know them). Starting that cast in its orange zone overlaps Auto Shot's cast and "
        .. "delays your next Auto Shot; start it before the orange. The zones follow your cast times, haste "
        .. "included.")
    Dropdown("DYRE_SWING_THEME", "Theme", "theme", Swing.THEME_KEYS, Swing.THEME_LABELS, "gold",
        "Gold and black: the game's own look. Tactical black and red: flat bars, a thin edge.")
    if widget then
        ns.toolkit.AddWidgetSettings(category, layout, widget, {
            labels = {scale = "Swing timer size (%)", width = "Swing timer width"}})
    end
end

-- /dyre debug_swing and /dyre swing_reset -------------------------------------------------

local function Describe(value)
    if IsSecret(value) then
        return "secret"
    end
    return tostring(value)
end

function Swing.ReportDebug()
    local db = DB()
    ns.Report("swing bars=" .. tostring(Swing.barsAvailable == true) .. " range=" .. tostring(Swing.rangeAvailable == true)
        .. " show=" .. db.show .. " rangeBox=" .. tostring(db.range) .. " hold=" .. tostring(db.hold) .. " theme="
        .. db.theme .. " class=" .. tostring(DTT.classFile))
    local names = {}
    for name in pairs(probes) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        ns.Report("swing check " .. name .. " (" .. probes[name].kind .. ") inRange=" .. Describe(probes[name].inRange))
    end
    if #names == 0 then
        ns.Report("swing checks: none")
    end
    ns.Report("swing state=" .. tostring(shown) .. " now=" .. tostring(Swing.CurrentState()) .. " deadZone="
        .. tostring(Swing.deadZone == true) .. " rangedSubclass=" .. tostring(Swing.RangedSubclass()) .. " near="
        .. tostring(Hostile() and Near()))
end

function ns.HandleSwingCommand(message)
    local command = type(message) == "string" and message:match("^%s*(%S*)%s*$")
    command = command and command:lower()
    if command == "debug_swing" then
        Swing.ReportDebug()
        return true
    elseif command == "swing_reset" then
        if widget then
            widget:ResetPosition()
        end
        ns.Report("The swing timer is back in its default place.")
        return true
    end
    return false
end
