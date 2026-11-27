local addonName, ns = ...
local DyresToolkit = ns.toolkit

-- Proc cues (unreleased, 2.11.0; John, 2026-11-18: "It would be nice if there
-- was a shared engine that multiple classes can use for their procs, but the
-- class-specific stuff stayed closer to its own class-specific addon ... the
-- visual on-screen representation of procs that make certain abilities hit
-- better is a general need; what those are vary class to class."). Then
-- (John, 2026-11-18, after a review of SpellActivationOverlay): "DSU is the
-- right home for our 'spell activation overlays'", so Dyre's Shields Up holds
-- every class's procs and their art, and the engine stays here. Ported
-- from Dyre's Shields Up's prototype (its Procs.lua, uncommitted, 2026-11-18);
-- the design, not its namespace. A class AddOn passes its procs as data; the
-- toolkit draws two mirrored arcs, one each side of the caster, in one widget,
-- while the proc's buff is up, and plays a sound when it appears, both in
-- combat too. The AddOn keeps its settings and the learned buff IDs in its
-- own SavedVariables (the family rule: the toolkit never owns them) and
-- passes functions that return its live tables.
--
-- A proc: key, label, buff (the buff's English name), class, talents (the
-- talent's spell IDs: only a player who knows one gets the cue and the rows;
-- never a buff ID, since the talent's passive aura carries the buff's name),
-- ids (candidate buff IDs; each counts only when C_Spell.GetSpellName names
-- it the buff in the client's language: see BuffName), color {r, g, b}, sound (a Dyre's Sounds key), and optional
-- soundOn (false: the sound switch starts off), tooltip (extra text for its rows, such as a macro), stacks (a stacking
-- proc's most stacks, 2 to 10: the right arc then shows only at that many,
-- and the sound plays again as a stack is added), and art (below).
--
-- Art (John, 2026-11-18: "I would prefer if each client of the 'toolkit
-- platform' APIs could provide their own artwork instead of having all art
-- across all addins baked into the toolkit"): a proc's art, else the spec's
-- art, is {right = path, left = path, tint = boolean}. Both paths must be in
-- the registering AddOn's own folder (Interface\AddOns\<addon>\...); the
-- left file is the right one mirrored, since a StatusBar sets its fill's
-- texture coordinates itself. tint (default true): the art is white and the
-- proc's color tints it; false: the art keeps its own colors. Art that does
-- not pass, or none, gets the toolkit's plain crescent (Textures/ProcArc.tga
-- and ProcArcLeft.tga, scripts/make_proc_arcs.py), tinted. The geometry is
-- a contract: square, the ring center CENTER_X (8/128) in from the flat
-- side, the crescent OUTER_SPAN (118/128) of the height, the art within
-- radii 89 and 118 of 128 (below). The game cannot tell AddOn code whether
-- a texture file is there, so each AddOn tests its own files.
--
-- Stacks (John, 2026-11-18, from players of other proc AddOns: "Fingers of
-- frost procs should drop one side when 1 stack is consumed"): AddOn code
-- cannot read the stack count in combat, so the game decides. The right
-- arc's parts sit inside a StatusBar that the slot button's
-- SetApplicationBar(gate, {minApplications, maxApplications}) shows only
-- while the buff has at least minApplications (Blizzard_CustomAuraButton.lua
-- ApplyApplicationBar: SetShown(applications >= minApplications); Gethe
-- wow-ui-source 943764493e6b; the options in
-- AuraContainerUtilDocumentation.lua). The gate draws nothing itself. A
-- client without it shows both arcs, as before. The sound also takes the
-- trigger ApplicationsIncreased (UnitAuraConstantsDocumentation.lua: 1).
--
-- Rules (each from the prototype):
--   - Auras are never read in combat. The real buff ID is read out of combat
--     (GetAuraDataBySpellName(player, buff).spellId), saved in the AddOn's
--     learned table, and used from then on. A secret answer is never tested.
--   - The engine's AuraContainer frames are forbidden to AddOn code in combat
--     (MageProcs, seen in client: "calling 'SetScale' on bad self"), so
--     containers are made, shown, and hidden only out of combat; a change in
--     combat waits for PLAYER_REGEN_ENABLED. The widget frame is ours and
--     shows or hides at once.
--   - Two containers per proc, one per side; includeSpellIDs is a set, not a
--     list (DSU's Shield.lua: a list matched nothing in client).
--   - The sound is C_UnitAuras.AddAuraSound (trigger Added, unit player,
--     channel master, throttle 1 s), once per buff ID; an Encounter
--     restriction refuses changes, so they wait for
--     ADDON_RESTRICTION_STATE_CHANGED. Classic Era has no aura sounds: no
--     sound there, no error; its plain-Lua containers still draw the arcs.
--   - Talents: IsPlayerSpell, C_SpellBook.IsSpellKnown, or IsSpellKnown,
--     checked again on SPELLS_CHANGED.
--   - Events only: no OnUpdate, no polling.

-- A short, sharp sound for a proc whose own default an older Dyre's Sounds lacks.
DyresToolkit.DEFAULT_PROC_SOUND = "magical"
-- The owner kind for one proc's cue ("proc:" .. key) and the claim's
-- priority: a class Tools AddOn's, as the control engine's.
DyresToolkit.PROC_KIND_PREFIX = "proc:"
DyresToolkit.PROC_OWNER_PRIORITY = 10
-- The home of every proc cue (2.12.0; John, 2026-11-20: Dyre's Buff Reminders
-- holds "all buffs/procs ... chimes and visuals", Dyre's Shields Up shields
-- only): it passes spec.priority = PROC_OWNER_PRIORITY_HOME, above the 10
-- that Dyre's Shields Up 1.4 claims, and the engine draws and plays a proc
-- only for the AddOn that owns its kind, so an older DSU steps aside.
DyresToolkit.PROC_OWNER_PRIORITY_HOME = 20
-- What this engine offers, for feature tests: 2 (2.12.0) adds spec.priority,
-- the owner gate, arcOn, and sound for usable procs.
DyresToolkit.PROC_ENGINE_VERSION = 2
-- A usable proc's sound plays at most once per this many seconds (rage makes
-- the answer flicker; Dyre's Buff Reminders' reactive chimes used 3).
local USABLE_SOUND_GAP = 3
-- At most one sound per this many seconds (the API allows 0 to 5).
local SOUND_THROTTLE = 1
local SOUNDS_CONTRACT = 1
local SOUND_API = {"Resolve", "AuraSound", "Play", "Choices", "SetupMenu"}
local AURA_FILTER = "HELPFUL"
-- The fallback arcs: Textures/ProcArc.tga (right) and its mirror
-- ProcArcLeft.tga (left), a plain white crescent made by
-- scripts/make_proc_arcs.py, tinted with each proc's color. All proc art
-- keeps the ratios of DSU's shield arc: the ring center is CENTER_X = 8 of
-- 128 texels in from the crescent's flat side, the crescent spans
-- OUTER_SPAN = 118 of 128 texels in height (the art stays within radii 89
-- and 118 of 128). DSU's ring draws 160 units at 100%
-- (RING_SIZE); the arcs are ARC_SCALE times that, so the bolts run 122 to 162
-- units from the caster, outside DSU's shield ring. A StatusBar sets its fill's texture coordinates
-- itself, so the left side is a mirrored file, not flipped coordinates.
local TEXTURES = "Interface\\AddOns\\" .. addonName .. "\\Textures\\"
local SIDES = {
    {key = "left", point = "RIGHT", sign = 1},
    {key = "right", point = "LEFT", sign = -1},
}
local DEFAULT_ART = {right = TEXTURES .. "ProcArc", left = TEXTURES .. "ProcArcLeft", tint = true}
local WHITE_TINT = {1, 1, 1}
local OUTER_SPAN = 118 / 128
local CENTER_X = 8 / 128
local ARC_SCALE = 1.1
local RING_SIZE = 160
local BACKGROUND_ALPHA = 0.35
local ARC_WIDTH = RING_SIZE * ARC_SCALE
local ARC_HEIGHT = ARC_WIDTH * OUTER_SPAN
local CENTER_INSET = ARC_WIDTH * CENTER_X
-- The widget: both arcs side by side, centered on the caster.
local WIDGET_WIDTH = 2 * (ARC_WIDTH - CENTER_INSET)
local WIDGET_KEY = "procarcs"
local WIDGET_TITLE = "Proc arcs"
local DEFAULT_PLACE = {point = "CENTER", relativePoint = "CENTER", x = 0, y = -20}
-- Usable procs (unreleased; DSU's request, John, 2026-11-19: "yes, send it to
-- the coordinator; skip Paladin for now"): Warrior Overpower and Revenge are
-- not buffs; the game makes the ability usable for a few seconds. A proc with
-- `usable` = the rank 1 spell ID (no buff, no ids) shows its arcs, full, from
-- C_Spell.IsSpellUsable (else the global IsUsableSpell) by name, so every
-- rank counts, on SPELL_UPDATE_USABLE, also in combat. Usable: full; not
-- usable but short of power (the second return): dimmed, so rage does not
-- make it flicker; neither: hidden. A secret answer is never compared: the
-- arcs stay as they are. The arcs are two textures on the widget's own plain
-- frame (no aura slot), so they may change in combat. Since 2.12.0 (John,
-- 2026-11-20: one place for Overpower's arc and sound) a usable proc also has
-- a sound: Dyre's Sounds plays it (any sound, not only aura sounds) when the
-- spell turns usable on SPELL_UPDATE_USABLE, at most once per
-- USABLE_SOUND_GAP, never on the first read; and it claims its kind as an
-- aura proc does, so Dyre's Buff Reminders' own reactive chime steps aside.
-- DBR's probe (its TESTING.md): IsSpellUsable reads in combat for Revenge;
-- the second return in combat is not yet seen in client.
local USABLE_DIM_ALPHA = 0.4

-- One handle per registering AddOn.
local handles = {}

local function IsSecret(value)
    return DyresToolkit.IsSecret(value)
end

-- Dyre's Sounds with the functions used here, else nil. Read each time: it
-- may load after the toolkit.
local function SoundLibrary()
    local library = rawget(_G, "DyresSounds")
    if type(library) ~= "table" or type(library.RequireContract) ~= "function" then
        return nil
    end
    local ok, api = pcall(library.RequireContract, SOUNDS_CONTRACT)
    if not ok or type(api) ~= "table" then
        return nil
    end
    for _, name in ipairs(SOUND_API) do
        if type(api[name]) ~= "function" then
            return nil
        end
    end
    return api
end

-- Whether the client can play aura sounds at all (Classic Era cannot).
local function HasAuraSounds()
    return type(C_UnitAuras) == "table" and type(C_UnitAuras.AddAuraSound) == "function"
        and type(C_UnitAuras.RemoveAuraSound) == "function"
end

local function EncounterRestricted()
    if type(C_RestrictedActions) ~= "table" or type(C_RestrictedActions.IsAddOnRestrictionActive) ~= "function"
        or type(Enum) ~= "table" or type(Enum.AddOnRestrictionType) ~= "table" then
        return false
    end
    return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Encounter) == true
end

-- An event only where the client has it (C_EventUtils.IsEventValid when there).
local function RegisterIfValid(frame, event)
    if type(C_EventUtils) == "table" and type(C_EventUtils.IsEventValid) == "function"
            and not C_EventUtils.IsEventValid(event) then
        return false
    end
    return pcall(frame.RegisterEvent, frame, event) == true
end

-- A stacking proc's most stacks (whole, 2 to 10), else nil.
local function ProcStacks(proc)
    local stacks = proc.stacks
    if type(stacks) == "number" and stacks >= 2 and stacks <= 10 and stacks % 1 == 0 then
        return stacks
    end
    return nil
end

-- Art from the AddOn (a proc's or the spec's) when both paths are files in
-- its own folder, as a new table; else nil.
local function ValidArt(art, addon)
    if type(art) ~= "table" then
        return nil
    end
    local prefix = ("Interface\\AddOns\\" .. addon .. "\\"):lower()
    for _, key in ipairs({"right", "left"}) do
        local path = art[key]
        if type(path) ~= "string" or #path <= #prefix or path:sub(1, #prefix):lower() ~= prefix
                or path:find("..", 1, true) then
            return nil
        end
    end
    return {right = art.right, left = art.left, tint = art.tint ~= false}
end

-- The color an arc's art is drawn in: the proc's when the art is tinted.
local function ArtColor(proc, art)
    if art.tint and type(proc.color) == "table" then
        return proc.color
    end
    return WHITE_TINT
end

-- A usable proc: `usable` is a whole spell ID, with no buff.
local function IsUsableProc(proc)
    return type(proc.usable) == "number" and proc.usable > 0 and proc.usable % 1 == 0
end

local function ValidProc(proc)
    if not (type(proc) == "table" and type(proc.key) == "string" and proc.key:find("^[%w_]+$") ~= nil
            and type(proc.label) == "string" and type(proc.class) == "string") then
        return false
    end
    if IsUsableProc(proc) then
        return proc.talents == nil or type(proc.talents) == "table"
    end
    return type(proc.buff) == "string" and type(proc.talents) == "table" and type(proc.ids) == "table"
end

-- A saved sound in the library's spelling when it can be an aura sound (a
-- file or a game file ID), else the default. Without the library a key is
-- kept, so a missing library never resets a choice.
function DyresToolkit.SanitizeProcSound(key, default)
    default = default or DyresToolkit.DEFAULT_PROC_SOUND
    if type(key) ~= "string" then
        return default
    end
    local library = SoundLibrary()
    if not library then
        return key
    end
    local resolved = library.Resolve(key)
    return resolved and library.AuraSound(resolved) and resolved or default
end

-- The widget's saved place ({point, relativePoint, x, y}, and the grow edge
-- fields the toolkit adds), else nil.
local function SanitizePosition(position)
    if type(position) ~= "table" or type(position.x) ~= "number" or type(position.y) ~= "number"
            or type(position.point) ~= "string" or type(position.relativePoint) ~= "string" then
        return nil
    end
    local clean = {point = position.point, relativePoint = position.relativePoint, x = position.x, y = position.y}
    if type(position.anchor) == "string" and type(position.width) == "number" and type(position.height) == "number" then
        clean.anchor, clean.width, clean.height = position.anchor, position.width, position.height
    end
    return clean
end

-- A proc's sound switch before the player sets it: on, unless the proc has
-- soundOn = false (a proc the game already gives a sound, such as
-- Clearcasting: John's rule in Dyre's Buff Reminders, "off, the game already
-- plays a sound for it").
function DyresToolkit.ProcSoundDefault(proc)
    return type(proc) ~= "table" or proc.soundOn ~= false
end

-- A proc's arc switch before the player sets it: on, unless the proc has
-- arcOn = false (2.12.0: a proc that is a sound only by default, such as
-- Dyre's Buff Reminders' Nature's Grace).
function DyresToolkit.ProcArcDefault(proc)
    return type(proc) ~= "table" or proc.arcOn ~= false
end

-- A usable proc's saved sound: any sound Dyre's Sounds knows (the engine
-- plays it itself, not as an aura sound), else the default. Without the
-- library a key is kept.
function DyresToolkit.SanitizeUsableProcSound(key, default)
    default = default or DyresToolkit.DEFAULT_PROC_SOUND
    if type(key) ~= "string" then
        return default
    end
    local library = SoundLibrary()
    if not library then
        return key
    end
    return library.Resolve(key) or default
end

-- The AddOn's proc settings, repaired (it calls this from its own
-- SanitizeDB): per proc, the arc switch (on by default), the sound switch
-- (ProcSoundDefault), and the sound; the arcs widget's place and size (the
-- widget clamps the size).
function DyresToolkit.SanitizeProcs(saved, procs)
    saved = type(saved) == "table" and saved or {}
    local function Part(name)
        return type(saved[name]) == "table" and saved[name] or {}
    end
    local arc, sound, sounds = Part("arc"), Part("sound"), Part("sounds")
    local clean = {arc = {}, sound = {}, sounds = {}, position = SanitizePosition(saved.position),
        scale = type(saved.scale) == "number" and saved.scale or nil}
    for _, proc in ipairs(type(procs) == "table" and procs or {}) do
        if ValidProc(proc) then
            if type(arc[proc.key]) == "boolean" then
                clean.arc[proc.key] = arc[proc.key]
            else
                clean.arc[proc.key] = DyresToolkit.ProcArcDefault(proc)
            end
            if type(sound[proc.key]) == "boolean" then
                clean.sound[proc.key] = sound[proc.key]
            else
                clean.sound[proc.key] = DyresToolkit.ProcSoundDefault(proc)
            end
            if IsUsableProc(proc) then
                clean.sounds[proc.key] = DyresToolkit.SanitizeUsableProcSound(sounds[proc.key], proc.sound)
            else
                clean.sounds[proc.key] = DyresToolkit.SanitizeProcSound(sounds[proc.key], proc.sound)
            end
        end
    end
    return clean
end

local function IsTalent(proc, id)
    for _, talent in ipairs(proc.talents or {}) do
        if talent == id then
            return true
        end
    end
    return false
end

-- The proc's buff name in the client's language (a French player report,
-- 2026-11-20: proc.buff is English, and GetSpellName gives "Idées claires"
-- for Clearcasting, so nothing matched). A listed ID the client names
-- proc.buff keeps proc.buff (an English client, unchanged); else the first
-- listed ID's name; a proc with no IDs (Decimation) takes its talent's
-- name, as the buff and the talent share it; else proc.buff.
local function LocalName(id)
    local name = type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function"
        and C_Spell.GetSpellName(id)
    if IsSecret(name) or type(name) ~= "string" or name == "" then
        return nil
    end
    return name
end

local function BuffName(proc)
    local ids, first = proc.ids or {}, nil
    for _, id in ipairs(ids) do
        local name = LocalName(id)
        if name == proc.buff then
            return proc.buff
        end
        first = first or name
    end
    if first then
        return first
    end
    if #ids == 0 then
        for _, id in ipairs(proc.talents or {}) do
            local name = LocalName(id)
            if name then
                return name
            end
        end
    end
    return proc.buff
end
DyresToolkit.ProcBuffName = BuffName

-- The buff IDs read in client, per proc: data, not a setting, so the AddOn
-- keeps it with the character (a profile characterKeys entry). A talent ID
-- is never kept.
function DyresToolkit.SanitizeProcIDs(saved, procs)
    saved = type(saved) == "table" and saved or {}
    local clean = {}
    for _, proc in ipairs(type(procs) == "table" and procs or {}) do
        if ValidProc(proc) and not IsUsableProc(proc) then
            local id = saved[proc.key]
            if type(id) == "number" and id > 0 and id == math.floor(id) and not IsTalent(proc, id) then
                clean[proc.key] = id
            end
        end
    end
    return clean
end

-- Whether this character knows the proc's talent (any of its IDs); a usable
-- proc with no talents: whether it knows the spell itself. Then by name in
-- the spellbook (2.16.0; a CurseForge player, 2026-11-27: Revenge's cue went
-- away after training a higher rank, since the check asked only for rank 1's
-- ID and Forever reported only the trained rank as known): any rank, in the
-- client's own language, with no rank list to keep.
local function KnowsByName(ids)
    if type(DyresToolkit.SpellbookIDsByName) ~= "function" or type(DyresToolkit.SpellName) ~= "function" then
        return false
    end
    local _, learned = DyresToolkit.SpellbookIDsByName()
    for _, id in ipairs(ids) do
        local name = DyresToolkit.SpellName(id)
        if name and learned[name] == true then
            return true
        end
    end
    return false
end

local function KnowsTalent(proc)
    local ids = proc.talents or {}
    if IsUsableProc(proc) and #ids == 0 then
        ids = {proc.usable}
    end
    for _, id in ipairs(ids) do
        if type(IsPlayerSpell) == "function" and IsPlayerSpell(id) == true then
            return true
        end
        if type(C_SpellBook) == "table" and type(C_SpellBook.IsSpellKnown) == "function"
                and C_SpellBook.IsSpellKnown(id) == true then
            return true
        end
        if type(IsSpellKnown) == "function" and IsSpellKnown(id) == true then
            return true
        end
    end
    return KnowsByName(ids)
end

local function HasAuraContainer()
    return DyresToolkit.AuraEngineKind() ~= nil
end

-- One side's crescent, its ring center on the widget's center: the right
-- arc's flat side is left of the center, the left (mirrored) arc's right of it.
local function FitArc(region, frame, side)
    region:SetSize(ARC_WIDTH, ARC_HEIGHT)
    region:SetPoint(side.point, frame, "CENTER", side.sign * CENTER_INSET, 0)
end

local function NoMouse(region)
    for _, method in ipairs({"SetMouseClickEnabled", "SetMouseMotionEnabled"}) do
        if type(region[method]) == "function" then
            region[method](region, false)
        end
    end
    region:EnableMouse(false)
end

-- The engine shows the slot while the buff is up, drains its bar with the
-- buff's time left, and hides it the moment the buff is used, also in
-- combat, when AddOn code cannot read buffs.
local function ArcInitializer(proc, frame, side, art)
    return function(button)
        NoMouse(button)
        button:SetAllPoints(frame)
        -- A stacking proc's right arc: inside the game's stack gate (above).
        local holder = button
        local stacks = ProcStacks(proc)
        if stacks and side.key == "right" and type(button.SetApplicationBar) == "function" then
            local gate = CreateFrame("StatusBar", nil, button)
            gate:SetAllPoints(button)
            gate:SetMinMaxValues(0, 1)
            NoMouse(gate)
            if pcall(button.SetApplicationBar, button, gate,
                    {minApplications = stacks, maxApplications = stacks}) then
                holder = gate
            else
                gate:Hide()
            end
        end
        local track = holder:CreateTexture(nil, "BACKGROUND")
        FitArc(track, frame, side)
        track:SetTexture(art[side.key])
        track:SetVertexColor(0, 0, 0)
        track:SetAlpha(BACKGROUND_ALPHA)
        local bar = CreateFrame("StatusBar", nil, holder)
        FitArc(bar, frame, side)
        bar:SetStatusBarTexture(art[side.key])
        bar:SetOrientation("VERTICAL")
        local color = ArtColor(proc, art)
        bar:SetStatusBarColor(color[1], color[2], color[3])
        local direction = type(Enum) == "table" and type(Enum.StatusBarTimerDirection) == "table"
            and Enum.StatusBarTimerDirection.RemainingTime or nil
        button:SetDurationBar(bar, {direction = direction})
    end
end

-- spec: addon (folder), procs (list), store() and learned() (the AddOn's live
-- tables from SanitizeProcs and SanitizeProcIDs), optional title, point, and
-- art (the default for its procs; see Art above).
-- Returns a handle, or nil when no proc matches the player's class (then no
-- frame, no events). Call it at PLAYER_LOGIN, after the AddOn's settings load.
function DyresToolkit.RegisterProcs(spec)
    if type(spec) ~= "table" or type(spec.addon) ~= "string" or not spec.addon:find("%S")
            or type(spec.procs) ~= "table" or type(spec.store) ~= "function" or type(spec.learned) ~= "function" then
        return nil
    end
    if handles[spec.addon] then
        return handles[spec.addon]
    end
    local _, class = UnitClass("player")
    local list = {}
    for _, proc in ipairs(spec.procs) do
        if ValidProc(proc) and proc.class == class then
            list[#list + 1] = proc
        end
    end
    if #list == 0 or type(spec.store()) ~= "table" then
        return nil
    end
    -- Each proc's art, read once: its own, else the spec's, else the toolkit's.
    local arts = {}
    local specArt = ValidArt(spec.art, spec.addon)
    for _, proc in ipairs(list) do
        arts[proc.key] = ValidArt(proc.art, spec.addon) or specArt or DEFAULT_ART
    end
    -- One sound per proc for the family (John, 2026-11-18: Nightfall in WTF,
    -- while Dyre's Buff Reminders has its own Nightfall chime): each proc
    -- here claims "proc:<key>" for this AddOn at PROC_OWNER_PRIORITY, so an
    -- AddOn with its own copy (DBR's Proc Chimes) checks KindOwner and steps
    -- aside. A switch turned off keeps the claim (off means off). Since
    -- 2.12.0 usable procs claim too (they have a sound), at spec.priority
    -- when given, and this AddOn draws and plays a proc only while it owns
    -- the kind (Owns, below).
    local priority = type(spec.priority) == "number" and spec.priority or DyresToolkit.PROC_OWNER_PRIORITY
    -- Usable procs sound only for an AddOn that asks (spec.usableSounds):
    -- Dyre's Shields Up 1.4 has Overpower and Revenge while Dyre's Buff
    -- Reminders 1.12 plays its own chime for them, so a sound here would be a
    -- second one. Without it, a usable proc claims nothing and stays silent.
    local usableSounds = spec.usableSounds == true
    if type(DyresToolkit.ClaimOwner) == "function" then
        for _, proc in ipairs(list) do
            if usableSounds or not IsUsableProc(proc) then
                DyresToolkit.ClaimOwner(DyresToolkit.PROC_KIND_PREFIX .. proc.key, spec.addon, priority)
            end
        end
    end

    local state = {known = {}, handles = {}, registered = {}, containers = {}, pending = false, deferred = false,
        usable = {}, usableArcs = {}, playedAt = {}}
    local hasUsable = false
    for _, proc in ipairs(list) do
        hasUsable = hasUsable or IsUsableProc(proc)
    end
    local handle = {}

    local function Store()
        local store = spec.store()
        return type(store) == "table" and store or {}
    end

    local function Switch(part, key)
        local values = Store()[part]
        return type(values) == "table" and values[key] == true
    end

    -- Whether this AddOn owns the proc's kind (no Owners, or no owner at all:
    -- yes). Another AddOn's higher claim takes the arcs and the sound.
    local function Owns(proc)
        if type(DyresToolkit.KindOwner) ~= "function" then
            return true
        end
        local owner = DyresToolkit.KindOwner(DyresToolkit.PROC_KIND_PREFIX .. proc.key)
        return owner == nil or owner == spec.addon
    end

    -- Known (the talent or spell) and owned: the proc may show and sound.
    local function Active(proc)
        return state.known[proc.key] == true and Owns(proc)
    end

    local function Learned()
        local learned = spec.learned()
        return type(learned) == "table" and learned or {}
    end

    -- The buff IDs a proc's arcs and sound follow: its candidates the client
    -- names as the buff, then the ID read in client (never a talent).
    local function ProcIDs(proc)
        if IsUsableProc(proc) then
            return {}
        end
        local ids, seen = {}, {}
        local function Add(id)
            if not seen[id] and not IsTalent(proc, id) then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end
        local buff = BuffName(proc)
        for _, id in ipairs(proc.ids) do
            if LocalName(id) == buff then
                Add(id)
            end
        end
        local learned = Learned()[proc.key]
        if type(learned) == "number" then
            Add(learned)
        end
        return ids
    end

    local function NewContainer()
        local container = DyresToolkit.CreateAuraContainer(state.frame)
        container:SetPoint("TOPLEFT", state.frame, "TOPLEFT")
        container:SetSize(1, 1)
        return container
    end

    -- Two containers per proc, one per side, for the IDs known now. A new ID
    -- (read in client) gets new containers, out of combat only; the old ones
    -- are hidden.
    local function BuildArcs()
        if not HasAuraContainer() then
            return
        end
        if InCombatLockdown() then
            state.pending = true
            return
        end
        state.pending = false
        for _, proc in ipairs(list) do
            local ids = Active(proc) and ProcIDs(proc) or {}
            local signature = table.concat(ids, ",")
            local old = state.containers[proc.key]
            if not old or old.signature ~= signature then
                for _, container in pairs(old and old.sides or {}) do
                    container:Hide()
                end
                state.containers[proc.key] = nil
                if #ids > 0 then
                    local entry = {signature = signature, sides = {}}
                    for _, side in ipairs(SIDES) do
                        -- A set, not a list: each side its own table.
                        local set = {}
                        for _, id in ipairs(ids) do
                            set[id] = true
                        end
                        local container = NewContainer()
                        container:AddAuraSlot(proc.key, AURA_FILTER, {
                            candidateFilters = {includeSpellIDs = set},
                            initializeFrame = ArcInitializer(proc, state.frame, side, arts[proc.key]),
                        })
                        container:SetUnit("player")
                        container:UpdateAllAuras()
                        entry.sides[side.key] = container
                    end
                    state.containers[proc.key] = entry
                end
            end
        end
    end

    -- Registers each known proc's sound for its IDs, or removes them; waits
    -- out an encounter, when the game refuses aura sound changes.
    local function ApplySounds()
        if not HasAuraSounds() then
            return
        end
        if EncounterRestricted() then
            state.deferred = true
            return
        end
        state.deferred = false
        for _, id in ipairs(state.handles) do
            C_UnitAuras.RemoveAuraSound(id)
        end
        state.handles, state.registered = {}, {}
        local library = SoundLibrary()
        if not library then
            return
        end
        local sounds = Store().sounds
        sounds = type(sounds) == "table" and sounds or {}
        local triggers = type(Enum) == "table" and type(Enum.UnitAuraSoundTrigger) == "table"
            and Enum.UnitAuraSoundTrigger or {}
        local added = triggers.Added or 0
        for _, proc in ipairs(list) do
            local sound = not IsUsableProc(proc) and Active(proc) and Switch("sound", proc.key)
                and (type(sounds[proc.key]) == "string" and library.AuraSound(sounds[proc.key])
                    or type(proc.sound) == "string" and library.AuraSound(proc.sound)
                    or library.AuraSound(DyresToolkit.DEFAULT_PROC_SOUND))
            if type(sound) == "table" then
                state.registered[proc.key] = {}
                -- A stacking proc: again as a stack is added.
                local when = {added}
                if ProcStacks(proc) and type(triggers.ApplicationsIncreased) == "number" then
                    when[2] = triggers.ApplicationsIncreased
                end
                for _, id in ipairs(ProcIDs(proc)) do
                    for _, trigger in ipairs(when) do
                        local registration = C_UnitAuras.AddAuraSound(trigger, {
                            spellID = id,
                            unitToken = "player",
                            outputChannel = "master",
                            throttleSeconds = SOUND_THROTTLE,
                            soundFileName = sound.soundFileName,
                            soundFileID = sound.soundFileID,
                        })
                        if registration then
                            state.handles[#state.handles + 1] = registration
                            if trigger == added then
                                table.insert(state.registered[proc.key], id)
                            end
                        end
                    end
                end
            end
        end
    end

    -- A usable proc's two arcs: our own textures, so shown, hidden, and
    -- dimmed at once, also in combat.
    local function ShowUsable(proc)
        local arcs = state.usableArcs[proc.key]
        if not arcs then
            return
        end
        local look = Active(proc) and Switch("arc", proc.key) and state.usable[proc.key] or "off"
        for _, texture in pairs(arcs) do
            texture:SetShown(look ~= "off")
            texture:SetAlpha(look == "dim" and USABLE_DIM_ALPHA or 1)
        end
    end

    -- A usable proc's sound (2.12.0), through Dyre's Sounds: known, owned,
    -- its sound switch on, and not within USABLE_SOUND_GAP of its last. A
    -- voice sound says the spell's name in the client's language.
    local function PlayUsable(proc)
        if not usableSounds or not Active(proc) or not Switch("sound", proc.key) then
            return
        end
        local now = type(GetTime) == "function" and GetTime() or 0
        local last = state.playedAt[proc.key]
        if last and now - last < USABLE_SOUND_GAP then
            return
        end
        local library = SoundLibrary()
        if not library then
            return
        end
        local sounds = Store().sounds
        local choice = type(sounds) == "table" and type(sounds[proc.key]) == "string" and sounds[proc.key]
            or proc.sound or DyresToolkit.DEFAULT_PROC_SOUND
        local speech = LocalName(proc.usable) or proc.label
        state.playedAt[proc.key] = now
        library.Play(choice, speech, "Master")
    end

    -- Reads each known usable proc's spell by name (every rank counts): usable
    -- is "full"; short of power "dim"; else "off". A secret answer changes
    -- nothing (never compared). fromEvent: SPELL_UPDATE_USABLE (may sound).
    local function UpdateUsable(fromEvent)
        for _, proc in ipairs(list) do
            if IsUsableProc(proc) then
                local spell = proc.usable
                local name = type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function"
                    and C_Spell.GetSpellName(proc.usable)
                if type(name) == "string" and not IsSecret(name) then
                    spell = name
                end
                local usable, noPower
                if type(C_Spell) == "table" and type(C_Spell.IsSpellUsable) == "function" then
                    usable, noPower = C_Spell.IsSpellUsable(spell)
                elseif type(IsUsableSpell) == "function" then
                    usable, noPower = IsUsableSpell(spell)
                end
                if not IsSecret(usable) and not IsSecret(noPower) then
                    local before = state.usable[proc.key]
                    local now = usable == true and "full" or (noPower == true and "dim" or "off")
                    state.usable[proc.key] = now
                    -- The sound as it turns usable; never on the first read.
                    if fromEvent and now == "full" and before ~= nil and before ~= "full" then
                        PlayUsable(proc)
                    end
                end
                ShowUsable(proc)
            end
        end
    end

    -- Shows the widget while any known proc's arc is on; while unlocked, both
    -- sample arcs, full, in the first such proc's color, to place it.
    local function Refresh()
        local any, sample = false, nil
        local combat = InCombatLockdown()
        for _, proc in ipairs(list) do
            local on = Active(proc) and Switch("arc", proc.key)
            local entry = state.containers[proc.key]
            if combat then
                if entry then
                    state.pending = true
                end
            else
                for _, container in pairs(entry and entry.sides or {}) do
                    container:SetShown(on == true)
                end
            end
            if on then
                any = true
                sample = sample or proc
            end
            if IsUsableProc(proc) then
                ShowUsable(proc)
            end
        end
        state.frame:SetShown(any)
        local unlocked = not DyresToolkit.IsLocked()
        local art = sample and arts[sample.key]
        for key, texture in pairs(state.samples) do
            if art then
                local color = ArtColor(sample, art)
                texture:SetTexture(art[key])
                texture:SetVertexColor(color[1], color[2], color[3])
            end
            texture:SetShown(unlocked and sample ~= nil)
        end
    end

    -- Out of combat only: reads the real buff ID of each known proc whose arc
    -- or sound is on. A new one is saved, and the arcs and sound follow it.
    local function Learn()
        if InCombatLockdown() or type(C_UnitAuras) ~= "table"
                or type(C_UnitAuras.GetAuraDataBySpellName) ~= "function" then
            return
        end
        local learned, grew = spec.learned(), false
        if type(learned) ~= "table" then
            return
        end
        for _, proc in ipairs(list) do
            if not IsUsableProc(proc) and Active(proc)
                    and (Switch("arc", proc.key) or Switch("sound", proc.key)) then
                local aura = C_UnitAuras.GetAuraDataBySpellName("player", BuffName(proc), AURA_FILTER)
                -- A secret answer is never tested or indexed.
                if aura and not IsSecret(aura) and type(aura) == "table" then
                    local id = aura.spellId
                    -- The talent's passive aura has the same name: never learned.
                    if type(id) == "number" and not IsSecret(id) and not IsTalent(proc, id)
                            and learned[proc.key] ~= id then
                        learned[proc.key] = id
                        grew = true
                    end
                end
            end
        end
        if grew then
            BuildArcs()
            ApplySounds()
            Refresh()
        end
    end

    -- Talents change out of combat; a talent learned later gets its cue.
    local function CheckTalents()
        local changed = false
        for _, proc in ipairs(list) do
            local known = KnowsTalent(proc)
            if known ~= (state.known[proc.key] == true) then
                state.known[proc.key] = known
                changed = true
            end
        end
        return changed
    end

    -- After any setting change, a profile copy, or a new learned ID.
    function handle.Apply()
        BuildArcs()
        ApplySounds()
        UpdateUsable()
        Refresh()
        Learn()
    end

    -- Whether this character knows the proc's talent (gets its cue and rows).
    function handle.Known(key)
        return state.known[key] == true
    end

    -- Whether this AddOn's usable procs have sound (spec.usableSounds).
    function handle.UsableSounds()
        return usableSounds
    end

    -- Whether this AddOn owns the proc's kind (2.12.0), and else the owner.
    function handle.Owns(key)
        for _, proc in ipairs(list) do
            if proc.key == key then
                local owns = Owns(proc)
                local owner = not owns and DyresToolkit.KindOwner(DyresToolkit.PROC_KIND_PREFIX .. key) or nil
                return owns, owner
            end
        end
        return false, nil
    end

    -- The procs of this character's class, in settings order.
    function handle.List()
        local copy = {}
        for index, proc in ipairs(list) do
            copy[index] = proc
        end
        return copy
    end

    function handle.Widget()
        return state.widget
    end

    function handle.Addon()
        return spec.addon
    end

    -- The AddOn's live settings table (its store()), for the settings rows.
    function handle.Store()
        return Store()
    end

    -- The arcs back to their default place. True when there is a widget.
    function handle.ResetPosition()
        if not state.widget then
            return false
        end
        state.widget:ResetPosition()
        return true
    end

    -- Plays a proc's sound once (the settings preview); never in combat.
    function handle.Preview(key)
        local library = SoundLibrary()
        if not library or InCombatLockdown() then
            return false
        end
        local sounds = Store().sounds
        local choice = type(sounds) == "table" and sounds[key]
        if type(choice) ~= "string" then
            return false
        end
        return library.Play(choice, nil, "Master") == true
    end

    -- One debug line per proc: the talent, its buff IDs (named: a candidate
    -- the client names the buff; confirmed: read in client), arcs, sound.
    function handle.Report(report)
        if type(report) ~= "function" then
            return
        end
        local learned = Learned()
        for _, proc in ipairs(list) do
            local owner = not Owns(proc) and DyresToolkit.KindOwner(DyresToolkit.PROC_KIND_PREFIX .. proc.key)
            if owner then
                report(proc.label .. ": shown by " .. tostring(owner) .. ", not here")
            elseif IsUsableProc(proc) then
                report(proc.label .. ": spell " .. (state.known[proc.key] and "known" or "not known")
                    .. ", usable " .. (state.usable[proc.key] or "not read yet")
                    .. ", arcs " .. (Switch("arc", proc.key) and "on" or "off")
                    .. ", sound " .. (not usableSounds and "none (usable proc)"
                        or Switch("sound", proc.key) and "on" or "off"))
            else
            local parts = {}
            for _, id in ipairs(ProcIDs(proc)) do
                parts[#parts + 1] = id .. (learned[proc.key] == id and " (confirmed)" or " (named)")
            end
            local registered = state.registered[proc.key]
            report(proc.label .. ": talent " .. (state.known[proc.key] and "known" or "not known")
                .. ", buff IDs " .. (#parts > 0 and table.concat(parts, ", ") or "none yet")
                .. ", arcs " .. (state.containers[proc.key] and "ready" or "none")
                .. ", sound " .. (registered and #registered > 0 and "registered" or "off"))
            end
        end
    end

    -- For tests and debug: a usable proc's look ("full", "dim", "off", or nil
    -- before the first read) and its two arc textures.
    function handle.Usable(key)
        return state.usable[key], state.usableArcs[key]
    end

    -- For tests and debug: the widget's frame, and a proc's container on one
    -- side ("left" or "right").
    function handle.Frame()
        return state.frame
    end

    function handle.Container(key, side)
        local entry = state.containers[key]
        return entry and entry.sides[side]
    end

    -- A plain frame, a toolkit widget that takes the mouse only while unlocked.
    state.frame = CreateFrame("Frame", nil, UIParent)
    state.samples = {}
    for _, side in ipairs(SIDES) do
        local texture = state.frame:CreateTexture(nil, "ARTWORK")
        FitArc(texture, state.frame, side)
        texture:SetTexture(DEFAULT_ART[side.key])
        texture:Hide()
        state.samples[side.key] = texture
    end
    -- Each usable proc's arcs: full art in its own color, on our frame.
    for _, proc in ipairs(list) do
        if IsUsableProc(proc) then
            local art, arcs = arts[proc.key], {}
            local color = ArtColor(proc, art)
            for _, side in ipairs(SIDES) do
                local texture = state.frame:CreateTexture(nil, "ARTWORK")
                FitArc(texture, state.frame, side)
                texture:SetTexture(art[side.key])
                texture:SetVertexColor(color[1], color[2], color[3])
                texture:Hide()
                arcs[side.key] = texture
            end
            state.usableArcs[proc.key] = arcs
        end
    end
    local point = type(spec.point) == "table" and spec.point or DEFAULT_PLACE
    state.widget = DyresToolkit.CreateWidget({
        addon = spec.addon,
        key = WIDGET_KEY,
        title = type(spec.title) == "string" and spec.title or WIDGET_TITLE,
        frame = state.frame,
        store = spec.store(),
        width = WIDGET_WIDTH,
        height = ARC_HEIGHT,
        point = point,
        sizes = {scale = true},
        mouse = "unlocked",
        onUnlock = function() Refresh() end,
    })
    state.frame:Hide()
    CheckTalents()

    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" then
            if not IsSecret(unit) and unit == "player" then
                Learn()
            end
        elseif event == "SPELLS_CHANGED" then
            if CheckTalents() then
                handle.Apply()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if state.ownerPending then
                state.ownerPending = false
                handle.Apply()
            end
            if state.pending then
                BuildArcs()
                Refresh()
            end
            if state.deferred and not EncounterRestricted() then
                ApplySounds()
            end
            Learn()
        elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
            if state.deferred and not EncounterRestricted() then
                ApplySounds()
            end
        elseif event == "SPELL_UPDATE_USABLE" then
            UpdateUsable(true)
        end
    end)
    -- Only for an AddOn with a usable proc of this class.
    if hasUsable then
        RegisterIfValid(events, "SPELL_UPDATE_USABLE")
    end
    RegisterIfValid(events, "SPELLS_CHANGED")
    RegisterIfValid(events, "PLAYER_REGEN_ENABLED")
    if type(events.RegisterUnitEvent) == "function" then
        events:RegisterUnitEvent("UNIT_AURA", "player")
    else
        RegisterIfValid(events, "UNIT_AURA")
    end
    if HasAuraSounds() then
        RegisterIfValid(events, "ADDON_RESTRICTION_STATE_CHANGED")
    end
    -- Another AddOn may claim a kind later (its own PLAYER_LOGIN): the arcs
    -- and sounds follow the owner, out of combat (in combat, after it).
    if type(DyresToolkit.OnOwnerChanged) == "function" then
        for _, proc in ipairs(list) do
            DyresToolkit.OnOwnerChanged(DyresToolkit.PROC_KIND_PREFIX .. proc.key, function()
                if InCombatLockdown() then
                    state.ownerPending = true
                else
                    handle.Apply()
                end
            end)
        end
    end
    handles[spec.addon] = handle
    handle.Apply()
    return handle
end

-- Settings rows for a handle, on the AddOn's own page: a section header
-- (opts.header, default "Procs") shown while any proc's talent is known;
-- per proc an arc switch, a sound switch, and its sound (Dyre's Sounds' aura
-- sounds) under the sound switch, each shown only while its talent is known;
-- then the arcs' size and Reset size, when a talent is known as the page is
-- built (the toolkit's slider rows take no shown predicate). Without the
-- settings API, nothing. Returns the rows by proc key, else nil.
local REQUIRED_SETTINGS = {"RegisterProxySetting", "CreateCheckbox", "CreateDropdown"}

local function HasSettingsAPI()
    if type(Settings) ~= "table" or type(Settings.VarType) ~= "table" then
        return false
    end
    for _, name in ipairs(REQUIRED_SETTINGS) do
        if type(Settings[name]) ~= "function" then
            return false
        end
    end
    return true
end

local function ShownIf(initializer, predicate)
    if type(initializer) == "table" and type(initializer.AddShownPredicate) == "function" then
        initializer:AddShownPredicate(predicate)
    end
    return initializer
end

function DyresToolkit.AddProcSettings(category, layout, handle, opts)
    if not HasSettingsAPI() or type(category) ~= "table" or type(handle) ~= "table"
            or type(handle.List) ~= "function" then
        return nil
    end
    opts = type(opts) == "table" and opts or {}
    local list = handle.List()
    if #list == 0 then
        return nil
    end
    local addon = handle.Addon()
    local function AnyKnown()
        for _, proc in ipairs(list) do
            if handle.Known(proc.key) then
                return true
            end
        end
        return false
    end
    local function Variable(proc, part)
        return ("DYRE_" .. addon .. "_PROC_" .. proc.key .. "_" .. part):upper():gsub("[^%w_]", "_")
    end
    local function Store()
        return handle.Store()
    end
    local rows = {}
    if type(layout) == "table" and type(layout.AddInitializer) == "function"
            and type(CreateSettingsListSectionHeaderInitializer) == "function" then
        local header = CreateSettingsListSectionHeaderInitializer(opts.header or "Procs")
        ShownIf(header, AnyKnown)
        layout:AddInitializer(header)
        rows.header = header
    end
    -- 2.12.0: a proc another AddOn owns keeps its rows, greyed, naming it.
    local function OwnedHere(proc)
        if type(handle.Owns) ~= "function" then
            return true
        end
        return (handle.Owns(proc.key))
    end
    local function OwnerNote(proc)
        if OwnedHere(proc) then
            return ""
        end
        local _, owner = handle.Owns(proc.key)
        local title = owner
        if type(DyresToolkit.AddOns) == "function" then
            for _, info in ipairs(DyresToolkit.AddOns()) do
                if type(info) == "table" and info.addon == owner and type(info.title) == "string" then
                    title = info.title
                end
            end
        end
        return " Shown by " .. tostring(title) .. " now, so this setting does nothing here."
    end
    local function Greyed(initializer, proc)
        if type(initializer) == "table" and type(initializer.AddModifyPredicate) == "function" then
            initializer:AddModifyPredicate(function() return OwnedHere(proc) end)
        end
        return initializer
    end
    local function Defaults(proc, part)
        if part == "sound" then
            return DyresToolkit.ProcSoundDefault(proc)
        end
        return DyresToolkit.ProcArcDefault(proc)
    end
    local function Flag(proc, part, name, tooltip)
        local text = tooltip
        if type(handle.Owns) == "function" then
            text = function() return tooltip .. OwnerNote(proc) end
        end
        local setting = Settings.RegisterProxySetting(category, Variable(proc, part), Settings.VarType.Boolean,
            name, Defaults(proc, part),
            function()
                local values = Store()[part]
                return type(values) == "table" and values[proc.key] == true
            end,
            function(value)
                local store = Store()
                store[part] = type(store[part]) == "table" and store[part] or {}
                store[part][proc.key] = value == true
                handle.Apply()
            end)
        local row = ShownIf(Settings.CreateCheckbox(category, setting, text), function() return handle.Known(proc.key) end)
        return Greyed(row, proc)
    end
    for _, proc in ipairs(list) do
        local extra = type(proc.tooltip) == "string" and proc.tooltip ~= "" and (" " .. proc.tooltip) or ""
        local usable = IsUsableProc(proc)
        -- An aura proc's sound is an aura sound (a file); a usable proc's is
        -- played by the engine, so any sound (2.12.0).
        local filter = not usable and "aura" or nil
        local function Choices()
            local library = SoundLibrary()
            return library and library.Choices(filter)() or {}
        end
        local arc, sound
        local silent = usable and not (type(handle.UsableSounds) == "function" and handle.UsableSounds())
        if silent then
            -- A usable proc without usableSounds: the arc switch only.
            rows[proc.key] = {arc = Flag(proc, "arc", proc.label .. " arc",
                "An arc each side of you, in its own color, while " .. proc.label .. " can be used. It is "
                    .. "dimmed while you are short of rage or other power, also in combat." .. extra)}
        elseif usable then
            arc = Flag(proc, "arc", proc.label .. " arc",
                "An arc each side of you, in its own color, while " .. proc.label .. " can be used. It is "
                    .. "dimmed while you are short of rage or other power, also in combat." .. extra)
            sound = Flag(proc, "sound", proc.label .. " sound",
                "Play a sound the moment " .. proc.label .. " can be used, also in combat; at most once every "
                    .. USABLE_SOUND_GAP .. " seconds." .. extra)
        else
            arc = Flag(proc, "arc", proc.label .. " arc",
                "An arc each side of you, in its own color, while " .. proc.label .. " is up. It drains with the "
                    .. "time left and goes the moment you use it, also in combat." .. extra)
            sound = Flag(proc, "sound", proc.label .. " sound",
                "Play a sound the moment " .. proc.label .. " procs, also in combat." .. extra)
        end
        if not silent then
        local choice = Settings.RegisterProxySetting(category, Variable(proc, "sound_choice"),
            Settings.VarType.String or "string", "Sound", proc.sound or DyresToolkit.DEFAULT_PROC_SOUND,
            function()
                local sounds = Store().sounds
                return type(sounds) == "table" and sounds[proc.key] or proc.sound
            end,
            function(value)
                local store = Store()
                store.sounds = type(store.sounds) == "table" and store.sounds or {}
                if usable then
                    store.sounds[proc.key] = DyresToolkit.SanitizeUsableProcSound(value, proc.sound)
                else
                    store.sounds[proc.key] = DyresToolkit.SanitizeProcSound(value, proc.sound)
                end
                handle.Apply()
                handle.Preview(proc.key)
            end)
        local dropdown = Greyed(ShownIf(Settings.CreateDropdown(category, choice, Choices,
            "The sound when " .. proc.label .. (usable and " can be used" or " procs")
                .. ". Choosing one plays it once. The sounds come from Dyre's Sounds." .. extra),
            function() return handle.Known(proc.key) end), proc)
        local library = SoundLibrary()
        if library then
            library.SetupMenu(dropdown, filter)
        end
        if type(dropdown) == "table" and type(dropdown.SetParentInitializer) == "function" then
            dropdown:SetParentInitializer(sound, function()
                local values = Store().sound
                return type(values) == "table" and values[proc.key] == true
            end)
        end
        rows[proc.key] = {arc = arc, sound = sound, choice = dropdown}
        end
    end
    local widget = handle.Widget()
    if widget and AnyKnown() then
        DyresToolkit.AddWidgetSettings(category, layout, widget, {
            labels = {scale = "Proc arc size"},
            tooltips = {scale = "How big the proc arcs are, in percent. They grow and shrink from their center, "
                .. "and the gap between them grows with them."},
            resetTooltip = "The proc arcs back to 100%.",
        })
    end
    return rows
end

