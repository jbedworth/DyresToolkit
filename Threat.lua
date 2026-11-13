local _, ns = ...
local DTT = ns.tank

-- Threat labels on enemy nameplates and on your target (2.9.0, from Dyre's
-- Tank Tools; Owners kind "threat"): a shield (tank view)
-- or crossed swords (DPS and healer view), and your threat percent in the
-- view's color. Event-driven: threat, nameplate, target, combat, group, role,
-- form, and (a Paladin's) aura events; no OnUpdate. A Righteous Fury read
-- the aura API may hide (a plain nil in combat) keeps the view; form and
-- stance answers apply at once, in combat too (see HasAura);
-- PLAYER_REGEN_ENABLED reads it again.
--
-- Auto picks the view by the tank bar's rule (DTT.TankReasons): the tank
-- view for a group Tank or raid main tank, a Druid in Bear Form, a Paladin
-- with Righteous Fury, or a Warrior in Defensive Stance; else the DPS view.
--
-- The views (author, 2026-11-10):
--   tank: green while you hold the mob securely, yellow while you hold it but
--         another unit has more threat, red when it is not on you.
--   dps:  green while you are below the tank, yellow at 80% of the pull
--         point where your percent reads (your target; John, 2026-11-13: "An
--         early yellow for DPS would be nice (no sound, just flip it yellow
--         when they get above 80%)"), orange when you are in danger of
--         pulling it (more threat than the tank, no aggro yet), red when it
--         is on you.
--         (John, 2026-11-13: "Can we make it symmetrical for DPS? Green, on
--         threat table, but not 1st or 2nd. Orange, in danger of pulling
--         aggro, Red, you pulled aggro. And play the same sounds?") Orange
--         plays the losing sound ("Warning sound (orange)") on a change from a
--         known green; red plays the red sound, as before.
-- The status numbers are the game's UnitDetailedThreatSituation status: 3 you
-- have aggro and the most threat, 2 aggro but not the most, 1 no aggro but
-- more than the tank, 0 no aggro and less.
--
-- Tank view only (author, 2026-11-10), from the group's threat on the mob:
--   early yellow: you hold it securely, but another member or pet is at
--         EARLY_WARNING percent of the pull point or more;
--   blue: it is not on you but on another tank (group role Tank, or a raid's
--         main tank), so it is not lost.
-- A sound (a game sound, author) plays when a mob turns red on a threat
-- event, at most once per ALARM_GAP seconds; never for a secret status.
--
-- Losing a mob, nameplates in the tank view (John, 2026-11-11: "To
-- effectively tank, I need a visible clue that threat is getting low on a
-- mob -- before the visual clue of it turning and beating the healer
-- down."): status 2 (you have aggro, another unit has more threat) shows
-- the word LOSING in orange, not the percent (always 100 while you hold the
-- mob). A change from 3 to 2 on a threat event plays another game sound
-- (the player's choice), once per change, at most once per LOSING_GAP seconds. The
-- target label keeps its readable percent and early yellow.
--
-- Pull bars, nameplates in the tank view, in a party (not a raid): under
-- each enemy plate's health bar, one thin bar per party member in its class
-- color, filled to that member's scaled threat on the mob (100 pulls it).
-- The value goes to StatusBar:SetValue as it comes, secret or not, never
-- compared or computed; no value (not on the threat list) hides that bar.
-- Plain frames, made at a plate's first show and reused, so they change in
-- combat. Pets get no bar: a pet's taunt in a group is the Pet Taunt
-- warning's job, and four bars stay small.
--
-- On Forever the threat values can be secret in combat. Lua cannot compare a
-- secret, so DTT cannot pick a color from a secret status. FontString's
-- SetFormattedText takes a secret argument from AddOn code (SecretArguments
-- = "AllowedWhenTainted" in the client's API documentation), so a secret
-- percent still shows, in white. The icon's shape comes from the view, not
-- from the threat, so it always shows. Its color is the text's color (John,
-- 2026-11-11: "can we make the shield/swords icon itself use the color
-- scheme"): a white fill texture tinted with SetVertexColor from the same
-- constant table as the text (white for a secret status, never a color made
-- from a secret), under a dark outline texture with no tint
-- (scripts/make_icons.py draws both). In combat on Forever a nameplate token's
-- detailed values are all secret but UnitThreatSituation reads (John's
-- /dtt debug_threat, 2026-11-11), so plates take their color from it.
local GREEN, YELLOW, RED, BLUE, WHITE = {0.2, 1, 0.2}, {1, 0.85, 0}, {1, 0.2, 0.2}, {0.3, 0.6, 1}, {1, 1, 1}
local ORANGE = {1, 0.5, 0}
local OFF_TANK = {word = "OFF", color = BLUE}
local LOSING = {word = "LOSING", color = ORANGE, wordOnly = true}
-- The red and losing sounds are the player's choices (Tank.lua DTT.SOUNDS;
-- defaults: raid warning and quest failed, so the two can be told apart).
local LOSING_GAP = 2
local PULL_BAR_HEIGHT, PULL_BAR_GAP = 3, 1
local PULL_BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local PARTY_SIZE = 4
-- A member's bar color when its class does not read.
local SLOT_COLORS = {{0.9, 0.9, 0.9}, {0.6, 0.8, 1}, {1, 0.7, 0.9}, {0.8, 1, 0.6}}
local EARLY_WARNING = 80
local ALARM_GAP = 2
local TEXTURES = "Interface\\AddOns\\DyresToolkit\\Textures\\"
local VIEWS = {
    tank = {
        icon = TEXTURES .. "ShieldFill",
        edge = TEXTURES .. "ShieldEdge",
        [3] = {word = "OK", color = GREEN},
        [2] = {word = "LOW", color = YELLOW},
        [1] = {word = "LOST", color = RED},
        [0] = {word = "LOST", color = RED},
    },
    dps = {
        icon = TEXTURES .. "SwordsFill",
        edge = TEXTURES .. "SwordsEdge",
        [0] = {word = "OK", color = GREEN},
        [1] = {word = "HIGH", color = ORANGE},
        -- Early, on a readable percent at EARLY_WARNING or more: no sound.
        early = {word = "HIGH", color = YELLOW},
        [2] = {word = "AGGRO", color = RED},
        [3] = {word = "AGGRO", color = RED},
    },
}
local ICON_SIZE = 14
local ICON_GAP = 2
local FONT = "GameFontNormalSmall"
local BAR_GAP = 4
local TARGET_PLACE = "above"

local plates = {}
local target

-- Who tanks: auto mode --------------------------------------------------------------

-- One rule for the tank bar and the threat view (John, 2026-11-11: "Threat
-- label rules should be exactly the same as Tank bar rules. Druid in Bear,
-- Paladin with Righteous Fury up, Warrior in Defensive Stance or anyone
-- designated Group Tank or Raid Main Tank get the bar and are treated like
-- tanks for aggro indicators."). DTT.TankReasons is that rule; the bar's
-- Auto (TankBarWanted) and the view's Auto (AutoRole) both call it, so they
-- cannot drift apart. Talents and pets are not part of it: never read
-- talents to decide a role (John, 2026-11-11: "Drop any attempt to look at
-- talent builds to determine, that was wrong. Especially given the new
-- tendency towards hybrid builds that mix Arms, Prot and Fury.").
--
-- GetShapeshiftFormID: 5 Bear Form, 8 Dire Bear Form. Also found by the
-- active form's spell (Bear Form 5487, Dire Bear Form 9634), as Dyre's Buff
-- Reminders finds Cat Form, because one of the two alone missed a Druid.
local BEAR_FORM_IDS = {[5] = true, [8] = true}
local BEAR_SPELLS = {5487, 9634}
-- Warrior 18 Defensive Stance (17 Battle, 19 Berserker); the stance's spell
-- is 71. Righteous Fury is the aura 25780.
local DEFENSIVE_STANCE_IDS, DEFENSIVE_STANCE_SPELLS = {[18] = true}, {71}
local RIGHTEOUS_FURY = {25780}
local AURA_SLOTS = 40

local function Plain(value)
    if DTT.IsSecret(value) then
        return nil
    end
    return value
end

local function SpellName(id)
    if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        return Plain(C_Spell.GetSpellName(id))
    end
    if type(GetSpellInfo) == "function" then
        return Plain((GetSpellInfo(id)))
    end
end

local function SpellNames(ids)
    local names = {}
    for _, id in ipairs(ids) do
        local name = SpellName(id)
        if name then
            names[name] = true
        end
    end
    return names
end

-- Whether one of these forms or stances is active: true, false, or nil when
-- the client hides the answer (a secret value; never compared).
local function FormActive(formIDs, spells)
    local hidden = false
    if type(GetShapeshiftFormID) == "function" then
        local id = GetShapeshiftFormID()
        if DTT.IsSecret(id) then
            hidden = true
        elseif id and formIDs[id] then
            return true
        end
    end
    if type(GetNumShapeshiftForms) == "function" and type(GetShapeshiftFormInfo) == "function" then
        local names = SpellNames(spells)
        local count = GetNumShapeshiftForms()
        if DTT.IsSecret(count) then
            hidden, count = true, 0
        end
        for index = 1, type(count) == "number" and count or 0 do
            local _, active, _, spellID = GetShapeshiftFormInfo(index)
            if DTT.IsSecret(active) or DTT.IsSecret(spellID) then
                hidden = true
            elseif active == true and spellID and names[SpellName(spellID) or ""] then
                return true
            end
        end
    end
    if hidden then
        return nil
    end
    return false
end

-- Only the aura read is held; form and stance answers apply at once, in
-- combat too. The aura API hides an aura in combat and gives a plain nil,
-- not a secret: Dyre's Buff Reminders' Druid probe in John's client
-- (DyresBuffReminders TESTING.md:63-68: out of combat GetPlayerAuraBySpellID
-- found Mark of the Wild and Thorns and C_Secrets.ShouldSpellAuraBeSecret
-- said false; at the first UNIT_AURA in combat both read "present=no
-- secret=true"), and John's Paladin test, Forever 1.60.1 70888, 2026-11-11
-- (Righteous Fury up the whole fight, the label went green to red at 100%;
-- UNIT_AURA 46, red view=6). The form API is not hidden: John's Druid test,
-- 2026-11-11 (Bear Form in and out in combat gave green and red at once).
-- So a nil aura read means:
--   ShouldSpellAuraBeSecret true, secret, or an error: hidden, keep the view;
--   ShouldSpellAuraBeSecret false: "off", at once, in combat too;
--   no C_Secrets or no such function (Era), or another answer: hidden in
--   combat (InCombatLockdown), "off" out of combat.
-- A found aura is always true. PLAYER_REGEN_ENABLED reads the reasons again,
-- so a real change made in combat takes effect then. InCombatLockdown only,
-- not UnitAffectingCombat: the lockdown ends before PLAYER_REGEN_ENABLED
-- fires (the toolkit's OutOfCombat queue relies on the same order).
local function CombatLocked()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

-- What the Righteous Fury reads gave, for /dtt debug_threat, in combat and
-- out of combat: the raw C_UnitAuras answer (aura, nil, secret, other) or
-- UnitBuff's result (true, false, secret); and ShouldSpellAuraBeSecret's
-- answer (true, false, secret, error, other, missing), asked on every read.
-- held: a nil read kept as hidden; viewChanges: Auto view changes in combat.
DTT.auraReads = {combat = {}, calm = {}}
DTT.AURA_READ_ORDER = {"aura", "nil", "secret", "other", "true", "false"}
DTT.auraSecretReads = {combat = {}, calm = {}}
DTT.AURA_SECRET_ORDER = {"true", "false", "secret", "error", "other", "missing"}
DTT.tankCounts = {held = 0, viewChanges = 0}

local function Count(store, kind)
    local counts = store[CombatLocked() and "combat" or "calm"]
    counts[kind] = (counts[kind] or 0) + 1
end

local function CountRead(kind)
    Count(DTT.auraReads, kind)
end

-- C_Secrets.ShouldSpellAuraBeSecret(id), in pcall: "true", "false",
-- "secret", "error", "other" (another plain value), or "missing".
local function AuraSecretAnswer(id)
    if type(C_Secrets) ~= "table" or type(C_Secrets.ShouldSpellAuraBeSecret) ~= "function" then
        return "missing"
    end
    local ok, answer = pcall(C_Secrets.ShouldSpellAuraBeSecret, id)
    if not ok then
        return "error"
    end
    if DTT.IsSecret(answer) then
        return "secret"
    end
    if answer == true then
        return "true"
    end
    if answer == false then
        return "false"
    end
    return "other"
end

local HIDES = {["true"] = true, secret = true, error = true}

-- What "not found" means for these spells: false ("off"), or nil and true
-- when the read may be hidden (held). Every spell's answer is counted.
local function NotFound(spells)
    local hides, off = false, true
    for _, id in ipairs(spells) do
        local answer = AuraSecretAnswer(id)
        Count(DTT.auraSecretReads, answer)
        if HIDES[answer] then
            hides = true
        elseif answer ~= "false" then
            off = false
        end
    end
    if hides or (not off and CombatLocked()) then
        return nil, true
    end
    return false
end

-- Whether you have one of these auras: true, false, or nil when hidden (a
-- secret answer; or a nil read the aura API may hide, then also true).
local function HasAura(spells)
    if type(C_UnitAuras) == "table" and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function" then
        local hidden, found = false, false
        for _, id in ipairs(spells) do
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
            if DTT.IsSecret(aura) then
                CountRead("secret")
                hidden = true
            elseif aura == nil then
                CountRead("nil")
            elseif type(aura) == "table" then
                CountRead("aura")
                found = true
            else
                CountRead("other")
                if aura then
                    found = true
                end
            end
        end
        -- C_Secrets is asked on every read, found or not, so the debug line
        -- shows its answers in and out of combat.
        local off, held = NotFound(spells)
        if found then
            return true
        end
        if hidden then
            return nil
        end
        return off, held
    end
    if type(UnitBuff) ~= "function" then
        return false
    end
    local wanted, names, hidden = {}, SpellNames(spells), false
    for _, id in ipairs(spells) do
        wanted[id] = true
    end
    for index = 1, AURA_SLOTS do
        local name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", index)
        if DTT.IsSecret(name) or DTT.IsSecret(spellID) then
            hidden = true
        elseif name == nil then
            break
        elseif (spellID and wanted[spellID]) or names[name] then
            CountRead("true")
            return true
        end
    end
    if hidden then
        CountRead("secret")
        return nil
    end
    CountRead("false")
    return NotFound(spells)
end

-- A unit is a designated tank: group role Tank, or a raid's main tank (the
-- raid frame's assignment). Secret answers count as no.
local function GroupTank(unit)
    if type(UnitGroupRolesAssigned) == "function" and Plain(UnitGroupRolesAssigned(unit)) == "TANK" then
        return true, "group role Tank"
    end
    if type(GetPartyAssignment) == "function" and Plain(GetPartyAssignment("MAINTANK", unit)) == true then
        return true, "raid main tank"
    end
    return false
end

-- The shared rule: whether you tank (true, false, or nil when the client
-- hides the answer, a secret form or aura), and why (for /dtt debug). A
-- designated tank always tanks, whatever the class or role field says
-- (a raid main tank with the Damage role is a tank).
function DTT.TankReasons()
    local designated, designation = GroupTank("player")
    if designated then
        return true, designation
    end
    local classFile = DTT.classFile
    local active, why, held
    if classFile == "WARRIOR" then
        active, why = FormActive(DEFENSIVE_STANCE_IDS, DEFENSIVE_STANCE_SPELLS), "Defensive Stance"
    elseif classFile == "DRUID" then
        active, why = FormActive(BEAR_FORM_IDS, BEAR_SPELLS), "Bear Form"
    elseif classFile == "PALADIN" then
        active, held = HasAura(RIGHTEOUS_FURY)
        why = "Righteous Fury"
    else
        return false, "not a tank class and not the group's tank"
    end
    if held then
        DTT.tankCounts.held = DTT.tankCounts.held + 1
        return nil, why .. " not found, but the aura may be hidden (held)"
    end
    if active == nil then
        return nil, why .. " hidden (secret)"
    end
    return active, (active and "" or "not in ") .. why
end

-- The tank bar in Auto: shown while TankReasons is true (nil keeps the bar
-- as it is). Its 30 s sticky hide is the bar's own (TankButtons.lua).
function DTT.TankBarWanted()
    return DTT.TankReasons()
end

local function Grouped()
    return type(IsInGroup) == "function" and Plain(IsInGroup()) == true
end

-- The view in Auto: "tank" exactly while TankReasons is true, else "dps",
-- and why. It follows the reasons at once (no sticky wait: the view is not
-- a frame that flickers in and out). A hidden (secret) answer keeps the
-- view it had; with none yet, "dps".
local autoRole
local function AutoRole()
    local tanking, why = DTT.TankReasons()
    if tanking == nil then
        return autoRole or "dps", why .. ", view kept"
    end
    autoRole = tanking and "tank" or "dps"
    return autoRole, why
end

function DTT.ThreatRole()
    local mode = DTT.db and DTT.db.threatMode or "auto"
    if mode == "tank" then
        return "tank", "Tank mode"
    elseif mode == "dps" then
        return "dps", "DPS/Healer mode"
    end
    return AutoRole()
end

-- Reading and showing -------------------------------------------------------------

-- One unit's threat, never comparing a secret. status is a readable number
-- 0-3 or nil; secretStatus says it was secret; percent is a readable number,
-- a secret, or nil (the scaled percent: 100 means you have or take aggro).
-- hasPercent is set apart, so no code ever compares a secret percent to nil.
local function Readable(status)
    if not DTT.IsSecret(status) and type(status) == "number" and VIEWS.tank[status] then
        return status
    end
end

function DTT.ReadThreat(unit)
    local reading = {}
    local _, status, percent = UnitDetailedThreatSituation("player", unit)
    reading.status = Readable(status)
    if not reading.status then
        local fallback = UnitThreatSituation("player", unit)
        reading.status = Readable(fallback)
        reading.secretStatus = not reading.status and (DTT.IsSecret(status) or DTT.IsSecret(fallback)) or nil
    end
    if DTT.IsSecret(percent) or type(percent) == "number" then
        reading.percent = percent
        reading.hasPercent = true
    end
    return reading
end

-- The units of your group that can hold or pull a mob: members and pets,
-- never you.
local function GroupUnits()
    local units = {"pet"}
    if type(IsInRaid) == "function" and IsInRaid() then
        local count = Plain(type(GetNumGroupMembers) == "function" and GetNumGroupMembers()) or 0
        for index = 1, type(count) == "number" and count or 0 do
            units[#units + 1] = "raid" .. index
            units[#units + 1] = "raidpet" .. index
        end
    elseif Grouped() then
        for index = 1, 4 do
            units[#units + 1] = "party" .. index
            units[#units + 1] = "partypet" .. index
        end
    end
    return units
end

-- The group's threat on a mob: the highest scaled percent of another member
-- or pet (100 pulls aggro), and whether another tank holds it. Secret values
-- count as unknown.
function DTT.ReadGroupThreat(mob)
    local highest, offTank
    for _, unit in ipairs(GroupUnits()) do
        if Plain(UnitExists(unit)) == true and Plain(UnitIsUnit(unit, "player")) ~= true then
            local tanking, _, scaled = UnitDetailedThreatSituation(unit, mob)
            tanking, scaled = Plain(tanking), Plain(scaled)
            if type(scaled) == "number" and (not highest or scaled > highest) then
                highest = scaled
            end
            if tanking == true and GroupTank(unit) then
                offTank = true
            end
        end
    end
    return highest, offTank
end

-- The tank view's extra look from the group's threat. The DPS view's early
-- yellow: no aggro and less than the tank, but your own scaled percent reads
-- EARLY_WARNING or more (on the target token; a plate's is secret).
local function AddGroupThreat(reading, mob, role)
    if not reading.status then
        return reading
    end
    if role ~= "tank" then
        local percent = Plain(reading.percent)
        reading.early = reading.status == 0 and type(percent) == "number" and percent >= EARLY_WARNING or nil
        return reading
    end
    local highest, offTank = DTT.ReadGroupThreat(mob)
    reading.offTank = reading.status <= 1 and offTank or nil
    reading.early = reading.status == 3 and highest and highest >= EARLY_WARNING or nil
    return reading
end

-- The look for a readable status in a view; plate: a nameplate's label.
local function Look(reading, role, plate)
    local view = VIEWS[role] or VIEWS.dps
    if not reading.status then
        return nil, view
    end
    if plate and role == "tank" and reading.status == 2 then
        return LOSING, view
    end
    if reading.offTank then
        return OFF_TANK, view
    elseif reading.early then
        return role == "tank" and view[2] or view.early, view
    end
    return view[reading.status], view
end

-- Writes a reading into a label (icon and text) for a view ("tank" or
-- "dps"); false when there is nothing to show. plate: a nameplate's label.
function DTT.ShowThreat(label, reading, role, plate)
    local info, view = Look(reading, role, plate)
    if not info and not reading.hasPercent then
        return false
    end
    label.icon:SetTexture(view.icon)
    label.edge:SetTexture(view.edge)
    label.role = role
    if info then
        label.icon:SetVertexColor(unpack(info.color))
        label.text:SetTextColor(unpack(info.color))
        if reading.hasPercent and not info.wordOnly then
            label.text:SetFormattedText("%.0f%%", reading.percent)
        else
            label.text:SetText(info.word)
        end
        return true
    end
    label.icon:SetVertexColor(unpack(WHITE))
    label.text:SetTextColor(unpack(WHITE))
    label.text:SetFormattedText("%.0f%%", reading.percent)
    return true
end

local function NewLabel()
    local label = CreateFrame("Frame", nil, UIParent)
    label:SetSize(1, ICON_SIZE)
    label:SetFrameStrata("HIGH")
    label.icon = label:CreateTexture(nil, "OVERLAY", nil, 0)
    label.icon:SetSize(ICON_SIZE, ICON_SIZE)
    -- The outline above the tinted fill, on the same square.
    label.edge = label:CreateTexture(nil, "OVERLAY", nil, 1)
    label.edge:SetAllPoints(label.icon)
    label.text = label:CreateFontString(nil, "OVERLAY", FONT)
    label:Hide()
    return label
end

-- Puts a label beside its bar: right and left run outward from the bar's
-- edge (icon nearest the bar), above and below center the icon and text on it.
-- x and y (the player's offsets, whole pixels; John, 2026-11-11: an
-- adjustable "Gap Distance" or "vertical/horizontal adjustments") add to
-- the place, so 0 and 0 keep it. scale (whole percent, 50 to 200; John,
-- 2026-11-13: "scale up or down, up to 100% (2x) it's default size") sizes
-- the icon and text with SetScale; a frame's own point offsets are in its
-- scaled units, so the gap and x and y are divided by the scale and stay
-- screen pixels. Labels are plain frames: this may run in combat.
local function Place(label, anchor, place, x, y, scale)
    x, y, scale = x or 0, y or 0, (scale or 100) / 100
    if label.anchor == anchor and label.place == place and label.x == x and label.y == y
            and label.scale == scale then
        return
    end
    label.anchor, label.place, label.x, label.y, label.scale = anchor, place, x, y, scale
    label:SetScale(scale)
    label:ClearAllPoints()
    label.icon:ClearAllPoints()
    label.text:ClearAllPoints()
    if place == "left" then
        label:SetPoint("RIGHT", anchor, "LEFT", (-BAR_GAP + x) / scale, y / scale)
        label.icon:SetPoint("RIGHT", label, "RIGHT")
        label.text:SetPoint("RIGHT", label.icon, "LEFT", -ICON_GAP, 0)
    elseif place == "above" or place == "below" then
        if place == "above" then
            label:SetPoint("BOTTOM", anchor, "TOP", x / scale, (BAR_GAP / 2 + y) / scale)
        else
            label:SetPoint("TOP", anchor, "BOTTOM", x / scale, (-BAR_GAP / 2 + y) / scale)
        end
        label.icon:SetPoint("RIGHT", label, "CENTER", -ICON_GAP / 2, 0)
        label.text:SetPoint("LEFT", label, "CENTER", ICON_GAP / 2, 0)
    else
        label:SetPoint("LEFT", anchor, "RIGHT", (BAR_GAP + x) / scale, y / scale)
        label.icon:SetPoint("LEFT", label, "LEFT")
        label.text:SetPoint("LEFT", label.icon, "RIGHT", ICON_GAP, 0)
    end
end

-- The bar a nameplate's label goes beside: the health bar Dyre's Toolkit
-- finds (Blizzard, Plater, Platynator, Threat Plates), else the plate.
local function PlateAnchor(unit)
    local toolkit = DTT.Toolkit()
    if toolkit and type(toolkit.FindPlateBar) == "function" then
        local bar = toolkit.FindPlateBar(unit)
        if bar then
            return bar
        end
    end
    local plate = type(C_NamePlate) == "table" and type(C_NamePlate.GetNamePlateForUnit) == "function"
        and C_NamePlate.GetNamePlateForUnit(unit)
    if plate and not (type(plate.IsForbidden) == "function" and plate:IsForbidden()) then
        return plate
    end
end

local function TargetAnchor()
    local toolkit = DTT.Toolkit()
    if toolkit and type(toolkit.FindUnitBar) == "function" then
        local bar = toolkit.FindUnitBar("target")
        if bar then
            return bar
        end
    end
    return rawget(_G, "TargetFrameHealthBar") or rawget(_G, "TargetFrame")
end

local function Hostile(unit)
    if not UnitExists(unit) then
        return false
    end
    local canAttack = UnitCanAttack("player", unit)
    return not DTT.IsSecret(canAttack) and canAttack == true
end

-- The view, found again only on the events that can change it.
local role = "dps"

-- Red by unit token, so the sound plays when a mob turns red, not while it
-- stays red. A plate's entry goes with the plate.
local red = {}
local lastAlarm
-- A plate's last readable status, for the 3 -> 2 losing sound.
local lastStatus = {}
-- DPS view: orange by unit token (true, false, or nil before a readable
-- status), for the orange sound on a change from a known green.
local orange = {}
local lastLosing
local pullBars = {}

-- What the sounds did since login, for /dtt debug_threat (John,
-- 2026-11-11: the red sound "fires only about 10% of the time"), per mob,
-- not per label. red: seen (a mob turned red), played, and skipped: gap
-- (within 2 s of the last), none (the setting), calm (out of combat and not
-- a threat event), solo (not in a group, with "Threat sounds when solo"
-- off); not seen: view (red after a view change, which the
-- player made), same (the same mob already red on another label: the
-- target and its plate). losing: seen (tank 3 to 2, or DPS green to
-- orange), played, gap, none, calm, solo, first (a 2 with no known 3, or an
-- orange with no known green, before it), and same (DPS: the same mob
-- already orange on another label).
DTT.soundCounts = {
    red = {seen = 0, played = 0, gap = 0, none = 0, calm = 0, solo = 0, view = 0, same = 0},
    losing = {seen = 0, played = 0, gap = 0, none = 0, calm = 0, solo = 0, first = 0, same = 0},
}
DTT.SOUND_COUNT_ORDER = {
    red = {"seen", "played", "gap", "none", "calm", "solo", "view", "same"},
    losing = {"seen", "played", "gap", "none", "calm", "solo", "first", "same"},
}
-- Labels whose state a view change cleared: their next red is not news.
local viewReset = {}

local function Count(kind, what)
    local counts = DTT.soundCounts[kind]
    counts[what] = counts[what] + 1
end

local function Alarm()
    local now = type(GetTime) == "function" and GetTime() or 0
    if lastAlarm and now - lastAlarm < ALARM_GAP then
        return "gap"
    end
    lastAlarm = now
    -- A Dyre's Sounds text-to-speech choice says what happened.
    DTT.PlayChoice(DTT.db.redSound, DTT.DEFAULT_RED_SOUND, role == "tank" and "Aggro lost" or "Aggro")
    return "played"
end

local function LosingAlarm()
    local now = type(GetTime) == "function" and GetTime() or 0
    if lastLosing and now - lastLosing < LOSING_GAP then
        return "gap"
    end
    lastLosing = now
    DTT.PlayChoice(DTT.db.losingSound, DTT.DEFAULT_LOSING_SOUND, role == "tank" and "Losing" or "High threat")
    return "played"
end

-- One sound decision for a change seen, and why it did or did not play.
-- soloSounds off (John, 2026-11-12: "super useful in groups, but can get
-- tiresome when solo grinding hearing it on every pull"): no red or losing
-- sound while not in a group. The labels still change color.
local function Sound(kind, audible, setting, alarm)
    Count(kind, "seen")
    if not audible then
        Count(kind, "calm")
    elseif setting == "none" then
        Count(kind, "none")
    elseif DTT.db.soloSounds ~= true and not Grouped() then
        Count(kind, "solo")
    else
        Count(kind, alarm())
    end
end

-- The token to read a unit's threat from. On Forever (John's /dtt
-- debug_threat in combat, 1.60.1 build 70888, 2026-11-11), the "target"
-- token's UnitDetailedThreatSituation values are readable, but every value
-- for a "nameplateN" token is secret (only UnitThreatSituation reads there).
-- So the plate that shows your target reads "target": a readable percent,
-- and the group's threat for early yellow and blue. A secret or unknown
-- UnitIsUnit keeps the plate's own token.
local function ReadUnit(unit)
    if unit ~= "target" and type(UnitIsUnit) == "function" and Plain(UnitIsUnit(unit, "target")) == true then
        return "target"
    end
    return unit
end

-- Whether the mob a label shows is already red (or orange: states) on
-- another label: the target label and the plate of your target. A secret
-- or unknown UnitIsUnit counts as a different mob.
local function SameMob(states, unit)
    local function IsTarget(plate)
        return type(UnitIsUnit) == "function" and Plain(UnitIsUnit(plate, "target")) == true
    end
    if unit == "target" then
        for plate in pairs(plates) do
            if states[plate] == true and IsTarget(plate) then
                return true
            end
        end
        return false
    end
    return states.target == true and IsTarget(unit)
end

-- The sounds come from a change of state, not from the event that showed
-- it (John, 2026-11-11: the red sound "fires only about 10% of the time,
-- randomly"). Before, only a threat event could play it, but every update
-- noted the color: at a pull PLAYER_REGEN_DISABLED (or a target, form, or
-- roster event) often came first, turned the label red silently, and the
-- threat event then found it already red. Now a label that turns red plays
-- the red sound on any update path, while audible (a threat event,
-- PLAYER_REGEN_DISABLED, or in combat), also on its first reading (John:
-- "If a mob attacks me, and threat turns red, I should still hear the
-- chime that I got aggro": a new plate shown already red, a target change
-- onto a mob on you). Two cases stay silent: red after a view change (a
-- form or role change resets every label; the player made it), and the
-- same mob already red on another label (counted once per mob). Losing
-- (3 to 2) needs a known 3 before the 2. Never for a secret status: only a
-- readable status is red or kept.
local function Show(label, unit, audible)
    local plate = unit ~= "target"
    local source = ReadUnit(unit)
    local reading = AddGroupThreat(DTT.ReadThreat(source), source, role)
    local shown = DTT.ShowThreat(label, reading, role, plate)
    local info = shown and Look(reading, role, plate) or nil
    local isRed = info ~= nil and info.color == RED
    if isRed and red[unit] ~= true then
        if red[unit] == nil and viewReset[unit] then
            Count("red", "view")
        elseif SameMob(red, unit) then
            Count("red", "same")
        else
            Sound("red", audible, DTT.db.redSound, Alarm)
        end
    end
    red[unit] = isRed
    -- DPS orange: a change from a known green or yellow (a readable status
    -- before). Yellow plays nothing.
    local isOrange = info ~= nil and role ~= "tank" and info.color == ORANGE
    if isOrange and orange[unit] ~= true then
        if orange[unit] == nil then
            Count("losing", "first")
        elseif SameMob(orange, unit) then
            Count("losing", "same")
        else
            Sound("losing", audible, DTT.db.losingSound, LosingAlarm)
        end
    end
    if info ~= nil then
        orange[unit] = isOrange
    elseif reading.secretStatus then
        orange[unit] = nil
    end
    viewReset[unit] = nil
    -- reading.status is readable or nil, never a secret.
    if plate then
        if role == "tank" and reading.status == 2 and lastStatus[unit] ~= 2 then
            if lastStatus[unit] == 3 then
                Sound("losing", audible, DTT.db.losingSound, LosingAlarm)
            else
                Count("losing", "first")
            end
        end
        -- A secret status clears it: 3, secret, 2 is no known change.
        lastStatus[unit] = reading.status
    end
    label:SetShown(shown)
end

-- Pull bars ----------------------------------------------------------------------------

local function PullBarsWanted()
    return DTT.db.pullBars and role == "tank" and Grouped()
        and not (type(IsInRaid) == "function" and Plain(IsInRaid()) == true)
end

local function MemberColor(member, slot)
    local _, classFile = UnitClass(member)
    classFile = Plain(classFile)
    local colors = rawget(_G, "RAID_CLASS_COLORS")
    local color = type(classFile) == "string" and type(colors) == "table" and colors[classFile]
    if type(color) == "table" and type(color.r) == "number" then
        return color.r, color.g, color.b
    end
    return unpack(SLOT_COLORS[slot])
end

local function NewPullBars()
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetFrameStrata("HIGH")
    holder.bars = {}
    for slot = 1, PARTY_SIZE do
        local bar = CreateFrame("StatusBar", nil, holder)
        bar:SetStatusBarTexture(PULL_BAR_TEXTURE)
        bar:SetMinMaxValues(0, 100)
        bar:SetHeight(PULL_BAR_HEIGHT)
        bar.back = bar:CreateTexture(nil, "BACKGROUND")
        bar.back:SetAllPoints(bar)
        bar.back:SetColorTexture(0, 0, 0, 0.5)
        bar:Hide()
        holder.bars[slot] = bar
    end
    holder:Hide()
    return holder
end

-- The bars under a plate's health bar (anchor), or hidden; the holder when
-- one or more bars show.
local function UpdatePullBars(unit, anchor)
    local holder = pullBars[unit]
    if not (anchor and PullBarsWanted()) then
        if holder then
            holder:Hide()
        end
        return nil
    end
    holder = holder or NewPullBars()
    pullBars[unit] = holder
    if holder.anchor ~= anchor then
        holder.anchor = anchor
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -PULL_BAR_GAP)
        holder:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -PULL_BAR_GAP)
    end
    local mob = ReadUnit(unit)
    local shown = 0
    for slot = 1, PARTY_SIZE do
        local bar, member = holder.bars[slot], "party" .. slot
        local has, scaled = false, nil
        if Plain(UnitExists(member)) == true then
            local _, _, value = UnitDetailedThreatSituation(member, mob)
            -- type() and IsSecret only: the value is never compared.
            if DTT.IsSecret(value) or type(value) == "number" then
                has, scaled = true, value
            end
        end
        if has then
            local y = -shown * (PULL_BAR_HEIGHT + PULL_BAR_GAP)
            shown = shown + 1
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, y)
            bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, y)
            bar:SetStatusBarColor(MemberColor(member, slot))
            bar:SetValue(scaled)
            bar:Show()
        else
            bar:Hide()
        end
    end
    holder:SetHeight(math.max(1, shown * (PULL_BAR_HEIGHT + PULL_BAR_GAP)))
    holder:SetShown(shown > 0)
    return shown > 0 and holder or nil
end

local function UpdatePlate(unit, alert)
    local label = plates[unit]
    local bar = DTT.Owns("threat") and Hostile(unit) and PlateAnchor(unit)
    local holder = UpdatePullBars(unit, bar or nil)
    local anchor = DTT.db.plateThreat and bar
    if not anchor then
        red[unit], lastStatus[unit], orange[unit] = nil, nil, nil
        if label then
            label:Hide()
        end
        return
    end
    label = label or NewLabel()
    plates[unit] = label
    -- Below the bar, the label goes under the pull bars.
    Place(label, DTT.db.platePlace == "below" and holder or anchor, DTT.db.platePlace, DTT.db.plateX, DTT.db.plateY,
        DTT.db.plateScale)
    Show(label, unit, alert)
end

local function UpdateTarget(alert)
    if not target then
        return
    end
    local anchor = DTT.db.targetThreat and DTT.Owns("threat") and Hostile("target") and TargetAnchor()
    if not anchor then
        red.target, orange.target = nil, nil
        target:Hide()
        return
    end
    Place(target, anchor, TARGET_PLACE, DTT.db.targetX, DTT.db.targetY, DTT.db.targetScale)
    Show(target, "target", alert)
end

-- Whether a red or losing change may sound now: in combat (a pull's other
-- events come in any order with the threat events).
local function InCombat()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return true
    end
    return type(UnitAffectingCombat) == "function" and Plain(UnitAffectingCombat("player")) == true
end

-- audible: a change seen now may sound (default: in combat). A new view
-- changes what red means, so every label starts again from a first reading.
function DTT.RefreshThreat(audible)
    if audible == nil then
        audible = InCombat()
    end
    local newRole = DTT.ThreatRole()
    if newRole ~= role then
        if role ~= nil and CombatLocked() then
            DTT.tankCounts.viewChanges = DTT.tankCounts.viewChanges + 1
        end
        red, lastStatus, orange, viewReset = {}, {}, {}, {target = true}
        for unit in pairs(plates) do
            viewReset[unit] = true
        end
    end
    role = newRole
    for unit in pairs(plates) do
        UpdatePlate(unit, audible)
    end
    UpdateTarget(audible)
end

local function IsPlateUnit(unit)
    return type(unit) == "string" and unit:find("^nameplate%d+$") ~= nil
end

-- Event counts since login, for /dtt debug_threat: they tell whether the
-- client sends threat events to AddOns at all.
DTT.threatEvents = {}

local function OnEvent(_, event, unit)
    DTT.threatEvents[event] = (DTT.threatEvents[event] or 0) + 1
    if event == "NAME_PLATE_UNIT_ADDED" then
        if IsPlateUnit(unit) then
            -- A token may now show another mob: a first reading (it sounds
            -- when red: a new mob, not a view change).
            red[unit], lastStatus[unit], orange[unit], viewReset[unit] = nil, nil, nil, nil
            UpdatePlate(unit, InCombat())
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        red[unit], lastStatus[unit], orange[unit] = nil, nil, nil
        if plates[unit] then
            plates[unit]:Hide()
        end
        if pullBars[unit] then
            pullBars[unit]:Hide()
        end
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        -- Each has one argument, unitTarget (UnitDocumentation.lua: Forever
        -- 70888 lines 4891-4907, Era 70576 3329-3345). LIST's is the mob;
        -- SITUATION's is the unit whose situation changed (often "player"),
        -- so on SITUATION every plate is read again.
        if IsPlateUnit(unit) then
            UpdatePlate(unit, true)
        elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
            for plate in pairs(plates) do
                UpdatePlate(plate, true)
            end
        end
        UpdateTarget(true)
    elseif event == "UNIT_AURA" then
        -- A Paladin's auras: only Righteous Fury on or off changes anything.
        if DTT.ThreatRole() ~= role then
            DTT.RefreshThreat()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Another mob: a first reading (it sounds when red, unless its plate
        -- is already red).
        red.target, viewReset.target = nil, nil
        DTT.RefreshThreat()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat starts: a change now is the pull.
        DTT.RefreshThreat(true)
    else
        DTT.RefreshThreat()
    end
end

local EVENTS = {"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_THREAT_LIST_UPDATE",
    "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UPDATE_SHAPESHIFT_FORM"}
-- Registered only where the client says they exist: registering an unknown
-- event is an error.
local OPTIONAL_EVENTS = {"PLAYER_ROLES_ASSIGNED"}

local function EventExists(event)
    return type(C_EventUtils) == "table" and type(C_EventUtils.IsEventValid) == "function"
        and C_EventUtils.IsEventValid(event) == true
end

function DTT.InitializeThreat()
    target = NewLabel()
    local frame = CreateFrame("Frame")
    for _, event in ipairs(EVENTS) do
        frame:RegisterEvent(event)
    end
    for _, event in ipairs(OPTIONAL_EVENTS) do
        if EventExists(event) then
            frame:RegisterEvent(event)
        end
    end
    -- Righteous Fury, as the tank bar watches it: only a Paladin's own auras.
    if DTT.classFile == "PALADIN" then
        frame:RegisterUnitEvent("UNIT_AURA", "player")
    end
    frame:SetScript("OnEvent", OnEvent)
    DTT.RefreshThreat()
end

-- For the tests: the label on a nameplate unit, the target's label, and
-- the pull bars by nameplate unit.
function DTT.ThreatLabels()
    return plates, target, pullBars
end
