local addonName, ns = ...

-- Group warnings and tank tools (2.9.0; John, 2026-11-10: "The DTT "tank
-- only" parts also move into DT", and the threat warning "works universally,
-- for tanks and non-tanks alike"). They were Dyre's Tank Tools, which never
-- shipped: threat labels on nameplates and the target (Threat.lua), the Pet
-- Taunt warning from Dyre's Buff Reminders (PetTaunt.lua), secure marker and
-- ping buttons on a bar (TankButtons.lua), the pull countdown (Pull.lua), and
-- the diagnostics (TankProbe.lua). Their settings are two sections of the
-- toolkit's own page (GroupSettings.lua). This file owns the shared table
-- `ns.tank`, the per-character settings (DyresToolkitCharDB) and their
-- repair, the commands, the API checks, and startup.
--
-- One owner per feature (Owners.lua): the toolkit claims the kinds "threat",
-- "warn:petTaunt", "tank:markers", "tank:pings", "tank:pull", and
-- "tank:pullDisplay" for itself
-- at SELF_PRIORITY, above a class Tools AddOn's 10, so an AddOn that has its
-- own copy (Dyre's Buff Reminders' Pet Taunt warning) sees the toolkit own it
-- and yields. A feature runs only while the toolkit owns its kind.
local DTT = {}
ns.tank = DTT

DTT.ADDON = addonName
DTT.SELF_PRIORITY = 50
DTT.KINDS = {threat = "threat", petTaunt = "warn:petTaunt", markers = "tank:markers", pings = "tank:pings",
    pull = "tank:pull", pullDisplay = "tank:pullDisplay"}

function DTT.Report(message)
    ns.Report(message)
end

-- Combat data can be a secret value on Forever: code may store it and pass it
-- to the client (FontString:SetFormattedText takes it), but never compare,
-- concatenate, index, or print it.
function DTT.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- Text for diagnostics that never touches a secret value's contents.
function DTT.Describe(value)
    if DTT.IsSecret(value) then
        return "secret"
    end
    return tostring(value)
end

-- Registered only where the client says the event exists: registering an
-- unknown event is an error (Era lacks some).
function DTT.EventExists(event)
    return type(C_EventUtils) == "table" and type(C_EventUtils.IsEventValid) == "function"
        and C_EventUtils.IsEventValid(event) == true
end

-- The toolkit itself, as the ported files reach it.
function DTT.Toolkit()
    return ns.toolkit, "ok"
end

-- Raid markers by index, as the game numbers them for /tm.
DTT.MARKERS = {
    [1] = "Star", [2] = "Circle", [3] = "Diamond", [4] = "Triangle",
    [5] = "Moon", [6] = "Square", [7] = "Cross", [8] = "Skull",
}
-- The "next marker" order: skull first, then the kill markers. Moon is left
-- out: Warlock Tools Forever (Banish) and Mage Tools Forever (Polymorph) put
-- it on their crowd-control targets by default.
DTT.DEFAULT_MARKER_ORDER = {8, 7, 6, 4, 3, 2, 1}
DTT.PULL_MIN, DTT.PULL_MAX, DTT.DEFAULT_PULL = 1, 60, 10
-- Threat label offsets (John, 2026-11-11), whole pixels added to the place.
DTT.OFFSET_MIN, DTT.OFFSET_MAX = -50, 50
-- Threat label size, whole percent of the default (John, 2026-11-13: "scale
-- up or down, up to 100% (2x) it's default size"); down to half.
DTT.SCALE_MIN, DTT.SCALE_MAX, DTT.DEFAULT_SCALE = 50, 200, 100
-- Threat view (author, 2026-11-10): "auto" finds whether you tank by the
-- tank bar's rule (Threat.lua TankReasons); "tank" and "dps" force a view. "dps" is also the healer view.
DTT.THREAT_MODES = {"auto", "tank", "dps"}
-- Where the threat label sits beside a nameplate's health bar. Right by
-- default: John's screenshot (2026-11-10) had the label above the bar under
-- the mob's name, and the space right of the bar free.
DTT.PLATE_PLACES = {"right", "left", "above", "below"}
-- The tank bar: "auto" shows it while you tank (Threat.lua TankBarWanted:
-- group role Tank or raid main tank, Defensive Stance, Bear Form, Righteous
-- Fury; the same rule as the threat view); "always"
-- and "never" force it. Its key bindings work with the bar hidden.
DTT.BAR_MODES = {"auto", "always", "never"}
-- Warning sounds (John, 2026-11-11: "The sound for "turning red" needs to be
-- configurable."): one list for the red sound and the losing sound. Each is
-- a SOUNDKIT key where the client has it, else the number. Every key and
-- number is in SoundKitConstants.lua on both clients (Gethe/wow-ui-source
-- forever 1.60.1 70888, Mainline; classic_era 1.15.9 70576, Vanilla),
-- except 847, the quest failed sound DTT used before: no SOUNDKIT key on
-- either client, so it plays by number. These are the "Game Warnings" group.
--
-- Dyre's Sounds (John, 2026-11-11: "add all the Dyre's Sounds as options"):
-- when its library is loaded (the global DyresSounds, RequireContract(1),
-- with the functions in SOUND_LIBRARY_API), every sound it lists follows as
-- its own groups, saved by its key (Resolve) and played through
-- DyresSounds.Play on the Master channel. Its files are never copied here
-- (licensing). A saved key it does not have (or the library missing or too
-- old) stays saved; the default game sound plays until it is back.
DTT.SOUND_GROUP = "Game Warnings"
DTT.SOUNDS = {
    {key = "none", label = "None"},
    {key = "raidWarning", label = "Raid warning", kit = "RAID_WARNING", id = 8959},
    {key = "questFailed", label = "Quest failed", id = 847},
    {key = "readyCheck", label = "Ready check", kit = "READY_CHECK", id = 8960},
    {key = "alarmClock", label = "Alarm clock", kit = "ALARM_CLOCK_WARNING_3", id = 12889},
    {key = "bossEmote", label = "Boss emote", kit = "RAID_BOSS_EMOTE_WARNING", id = 12197},
    {key = "bossWhisper", label = "Boss whisper", kit = "UI_RAID_BOSS_WHISPER_WARNING", id = 37666},
    {key = "queueReady", label = "Battleground ready", kit = "PVP_THROUGH_QUEUE", id = 8459},
    {key = "mapPing", label = "Map ping", kit = "MAP_PING", id = 3175},
    -- The game's battleground countdown sounds, the pull countdown's
    -- defaults (both clients' SoundKitConstants.lua).
    {key = "countdownTick", label = "Countdown tick", kit = "UI_BATTLEGROUND_COUNTDOWN_TIMER", id = 25477},
    {key = "countdownGo", label = "Countdown go", kit = "UI_BATTLEGROUND_COUNTDOWN_FINISHED", id = 25478},
}
DTT.SOUND_CHOICES, DTT.SOUND_LABELS = {}, {}
for _, sound in ipairs(DTT.SOUNDS) do
    DTT.SOUND_CHOICES[#DTT.SOUND_CHOICES + 1] = sound.key
    DTT.SOUND_LABELS[sound.key] = sound.label
end
-- The warning defaults are Dyre's Sounds 1.5.0's "Dyre's Alerts: Bell buzz"
-- and "Dyre's Alerts: Cartoon shake" (John, 2026-11-11: "set these as the
-- defaults, I like them fairly well"). Without Dyre's Sounds, with one
-- before 1.5.0 (no such key), or with the key not playable, each plays its
-- game fallback (SOUND_FALLBACK, the defaults before): the raid warning for
-- red, quest failed for losing; the menu then shows that game sound.
DTT.DEFAULT_RED_SOUND, DTT.DEFAULT_LOSING_SOUND = "alertbellbuzz", "alertshake"
DTT.DEFAULT_PULL_TICK, DTT.DEFAULT_PULL_GO = "countdownTick", "countdownGo"
DTT.SOUND_FALLBACK = {alertbellbuzz = "raidWarning", alertshake = "questFailed"}
-- Saved values that were only the defaults before: SanitizeDB always wrote
-- the default, so a save cannot tell a choice from a default. Since
-- SOUND_SAVES 1, only a player's own choice is saved (nil is the default),
-- and these old defaults become nil once.
DTT.SOUND_SAVES = 1
local OLD_SOUND_DEFAULTS = {redSound = "raidWarning", losingSound = "questFailed",
    pullTick = "countdownTick", pullGo = "countdownGo"}

-- The sound to play for a game choice, or nil for "none" or another choice.
function DTT.SoundID(choice)
    for _, sound in ipairs(DTT.SOUNDS) do
        if sound.key == choice and sound.id then
            local kit = sound.kit and type(SOUNDKIT) == "table" and SOUNDKIT[sound.kit]
            return type(kit) == "number" and kit or sound.id
        end
    end
end

local function GameSound(choice)
    return DTT.SOUND_LABELS[choice] ~= nil
end

local SOUND_LIBRARY_API = {"Groups", "List", "Play", "Playable", "Resolve", "Label", "Parts"}

-- Dyre's Sounds' interface when loaded with contract 1 and every function
-- DTT uses, else nil. Read each time: it may load after the toolkit.
function DTT.SoundLibrary()
    local library = rawget(_G, "DyresSounds")
    if type(library) ~= "table" or type(library.RequireContract) ~= "function" then
        return nil
    end
    local ok, api = pcall(library.RequireContract, 1)
    if not ok or type(api) ~= "table" then
        return nil
    end
    for _, name in ipairs(SOUND_LIBRARY_API) do
        if type(api[name]) ~= "function" then
            return nil
        end
    end
    return api
end

-- A saved choice that is a Dyre's Sounds key this client can play: its own
-- key (Resolve), else nil.
function DTT.LibrarySound(choice)
    local library = DTT.SoundLibrary()
    if not library or type(choice) ~= "string" or GameSound(choice) then
        return nil
    end
    local key = library.Resolve(choice)
    if type(key) == "string" and library.Playable(key) == true then
        return key
    end
end

-- A default's game sound: itself when it is one, else its fallback.
function DTT.GameFallback(default)
    if GameSound(default) then
        return default
    end
    return DTT.SOUND_FALLBACK[default] or "none"
end

-- The default in effect: a game default, a playable Dyre's Sounds default,
-- else its game fallback.
function DTT.DefaultSound(default)
    if GameSound(default) then
        return default
    end
    return DTT.LibrarySound(default) or DTT.GameFallback(default)
end

-- The choice in effect: nil is the default; a game choice, a playable
-- Dyre's Sounds key, else the default in effect (a saved key the library
-- does not have, or no library).
function DTT.EffectiveSound(choice, default)
    if choice == nil then
        return DTT.DefaultSound(default)
    end
    if GameSound(choice) then
        return choice
    end
    return DTT.LibrarySound(choice) or DTT.DefaultSound(default)
end

function DTT.SoundLabel(choice)
    if GameSound(choice) then
        return DTT.SOUND_LABELS[choice]
    end
    local key = DTT.LibrarySound(choice)
    return key and DTT.SoundLibrary().Label(key) or nil
end

-- Plays a choice on the Master channel (heard with game sounds turned down).
-- speech: what a Dyre's Sounds text-to-speech choice says. A Dyre's Sounds
-- choice that does not play falls back to the default's game sound.
function DTT.PlayChoice(choice, default, speech)
    local effective = DTT.EffectiveSound(choice, default)
    if not GameSound(effective) then
        local played = DTT.SoundLibrary().Play(effective, speech, "Master")
        if played == true then
            return true
        end
        effective = DTT.GameFallback(default)
    end
    local id = DTT.SoundID(effective)
    if id and type(PlaySound) == "function" then
        PlaySound(id, "Master")
        return true
    end
    return false
end

-- A choice picked in the settings plays once, never in combat.
function DTT.PreviewSound(choice, default, speech)
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return false
    end
    return DTT.PlayChoice(choice, default, speech)
end

local function OneOf(value, choices)
    for _, choice in ipairs(choices) do
        if value == choice then
            return value
        end
    end
    return choices[1]
end

local function IsWholeNumber(value)
    return type(value) == "number" and value == value and value == math.floor(value)
end

function DTT.SanitizeOffset(value)
    if not IsWholeNumber(value) then
        return 0
    end
    return math.max(DTT.OFFSET_MIN, math.min(DTT.OFFSET_MAX, value))
end

function DTT.SanitizeScale(value)
    if not IsWholeNumber(value) then
        return DTT.DEFAULT_SCALE
    end
    return math.max(DTT.SCALE_MIN, math.min(DTT.SCALE_MAX, value))
end

function DTT.SanitizePull(value)
    if not IsWholeNumber(value) then
        return DTT.DEFAULT_PULL
    end
    return math.max(DTT.PULL_MIN, math.min(DTT.PULL_MAX, value))
end

-- A marker order: whole numbers 1 to 8, each once, at least one; else the default.
function DTT.SanitizeMarkerOrder(order)
    if type(order) ~= "table" then
        return {unpack(DTT.DEFAULT_MARKER_ORDER)}
    end
    local clean, seen = {}, {}
    for _, index in ipairs(order) do
        if IsWholeNumber(index) and DTT.MARKERS[index] and not seen[index] then
            seen[index] = true
            clean[#clean + 1] = index
        end
    end
    if #clean == 0 then
        return {unpack(DTT.DEFAULT_MARKER_ORDER)}
    end
    return clean
end

local function Flag(value, default)
    if type(value) == "boolean" then
        return value
    end
    return default
end

-- A sound choice, nil for the default; an older boolean switch (before
-- 2.9.0's dropdowns) keeps its meaning: false is "none", true the default.
-- Any key-shaped string is kept (a Dyre's Sounds key may come back with the
-- library); other values are the default. In a save from before SOUND_SAVES,
-- the old default is the default (nil) once.
local MAX_SOUND_KEY = 64
local function SoundChoice(db, key, legacy)
    local value = db[key]
    if type(value) == "string" then
        if db.soundSaves ~= DTT.SOUND_SAVES and value == OLD_SOUND_DEFAULTS[key] then
            return nil
        end
        if #value <= MAX_SOUND_KEY and value:find("^[%w_]+$") then
            return value
        end
        return nil
    end
    if value == false or (value == nil and legacy == false) then
        return "none"
    end
    return nil
end

-- Per-character settings in DyresToolkitCharDB (a tank and a DPS character
-- want different views), repaired on load so a damaged or older table can
-- never break the toolkit. All warnings are on by default (John, 2026-11-10:
-- "Warnings on by default, but a user can toggle them off"). bar is the
-- widget's own store (place and scale; Widgets.lua repairs it).
function DTT.SanitizeDB(db, classFile)
    db = type(db) == "table" and db or {}
    return {
        plateThreat = Flag(db.plateThreat, true),
        targetThreat = Flag(db.targetThreat, true),
        threatMode = OneOf(db.threatMode, DTT.THREAT_MODES),
        platePlace = OneOf(db.platePlace, DTT.PLATE_PLACES),
        plateX = DTT.SanitizeOffset(db.plateX),
        plateY = DTT.SanitizeOffset(db.plateY),
        targetX = DTT.SanitizeOffset(db.targetX),
        targetY = DTT.SanitizeOffset(db.targetY),
        plateScale = DTT.SanitizeScale(db.plateScale),
        targetScale = DTT.SanitizeScale(db.targetScale),
        -- Sound choices: nil is the default (EffectiveSound).
        redSound = SoundChoice(db, "redSound", db.sound),
        losingSound = SoundChoice(db, "losingSound"),
        soundSaves = DTT.SOUND_SAVES,
        -- Off by default (John, 2026-11-12: "Most people, when solo, will
        -- not want the sound.").
        soloSounds = Flag(db.soloSounds, false),
        pullBars = Flag(db.pullBars, true),
        petTaunt = Flag(db.petTaunt, true),
        barMode = OneOf(db.barMode, DTT.BAR_MODES),
        -- A checkbox since round 9; the old "auto" and "always" are on,
        -- "never" off.
        pullDisplay = Flag(db.pullDisplay, db.pullDisplay ~= "never"),
        pullTick = SoundChoice(db, "pullTick"),
        pullGo = SoundChoice(db, "pullGo"),
        pullTimer = type(db.pullTimer) == "table" and db.pullTimer or {},
        pull = DTT.SanitizePull(db.pull),
        markerOrder = DTT.SanitizeMarkerOrder(db.markerOrder),
        bar = type(db.bar) == "table" and db.bar or {},
        warning = type(db.warning) == "table" and db.warning or {},
    }
end

-- Until SavedVariables load, defaults, so early calls are safe.
DTT.db = DTT.SanitizeDB(nil)

-- Whether the toolkit owns a feature's kind (another Dyre's AddOn with a
-- higher claim may own it; then the toolkit's copy stays off).
function DTT.Owns(feature)
    return ns.toolkit.IsOwner(DTT.KINDS[feature], DTT.ADDON) == true
end

-- Commands ---------------------------------------------------------------------------

local USAGE = "Use /dtt (settings), /dtt pull [seconds], /dtt reset, /dtt debug, /dtt debug_threat, or "
    .. "/dtt debug_taunts. /dyre pull, /dyre tank_reset, /dyre tank_debug, /dyre threat_debug, and "
    .. "/dyre taunt_debug do the same."
local UNAVAILABLE = "The threat labels and tank tools are off on this client: "

-- /dtt words, and the /dyre words for the same commands. "" opens the settings.
local COMMANDS = {
    [""] = {handler = "OpenSettings"},
    options = {handler = "OpenSettings"},
    pull = {handler = "StartPull", argument = "seconds"},
    reset = {handler = "ResetBar"},
    debug = {handler = "ReportDebug", always = true},
    debug_threat = {handler = "ReportThreatProbe", always = true},
    debug_taunts = {handler = "ReportTauntProbe", always = true},
}
local DYRE_WORDS = {pull = "pull", tank_reset = "reset", tank_debug = "debug", threat_debug = "debug_threat",
    taunt_debug = "debug_taunts"}

-- The command and its argument (a number for "seconds"), or nil and the
-- usage. dyre: the /dyre words (unknown words are not ours: nil, nil).
function DTT.ParseCommand(message, dyre)
    if type(message) ~= "string" then
        return nil, USAGE
    end
    local text = message:match("^%s*(.-)%s*$"):lower()
    local command, rest = text:match("^(%S*)%s*(.-)$")
    if dyre then
        command = DYRE_WORDS[command]
        if not command then
            return nil, nil
        end
    end
    local entry = COMMANDS[command]
    if not entry then
        return nil, USAGE
    end
    if rest == "" then
        return command
    end
    if entry.argument ~= "seconds" then
        return nil, USAGE
    end
    local seconds = tonumber(rest)
    -- 0 cancels a running pull (as DBM's and BigWigs' /pull 0).
    if not seconds or seconds ~= math.floor(seconds) or (seconds ~= 0 and seconds < DTT.PULL_MIN)
            or seconds > DTT.PULL_MAX then
        return nil, "Give the pull time as whole seconds, " .. DTT.PULL_MIN .. " to " .. DTT.PULL_MAX
            .. ", or 0 to cancel."
    end
    return command, seconds
end

-- Runs a command; returns whether it was one of ours (for /dyre).
function DTT.HandleCommand(message, dyre)
    local command, argument = DTT.ParseCommand(message, dyre)
    if not command then
        if argument then
            DTT.Report(argument)
            return true
        end
        return false
    end
    local entry = COMMANDS[command]
    if not DTT.available and not entry.always then
        DTT.Report(UNAVAILABLE .. tostring(DTT.unavailable))
        return true
    end
    DTT[entry.handler](argument)
    return true
end

-- /dyre's words (Core.lua asks here first).
function ns.HandleTankCommand(message)
    return DTT.HandleCommand(message, true)
end

function DTT.OpenSettings()
    ns.toolkit.OpenSettings()
end

-- /dtt and /tanktools, Dyre's Tank Tools' commands, as aliases. Another
-- AddOn can register /dtt too; the last one loaded wins, so DTT says so.
local SLASH_KEY = "DYRESTOOLKITTANK"
local PRIMARY_SLASH, BACKUP_SLASH = "/dtt", "/tanktools"
local MAX_SLASH_ALIASES = 10
SLASH_DYRESTOOLKITTANK1 = PRIMARY_SLASH
SLASH_DYRESTOOLKITTANK2 = BACKUP_SLASH
SlashCmdList[SLASH_KEY] = function(message) DTT.HandleCommand(message) end

local function FindSlashConflict()
    for key in pairs(SlashCmdList) do
        if key ~= SLASH_KEY then
            for index = 1, MAX_SLASH_ALIASES do
                local alias = rawget(_G, "SLASH_" .. key .. index)
                if type(alias) == "string" and alias:lower() == PRIMARY_SLASH then
                    return key
                end
            end
        end
    end
end

-- Startup ----------------------------------------------------------------------------

-- Functions the other files must define: a mixed install of old and new
-- files otherwise fails silently, because the client hides Lua errors.
local REQUIRED_NAMESPACE = {"InitializeThreat", "InitializeButtons", "InitializePetTaunt", "StartPull",
    "ResetBar", "ReportThreatProbe", "ReportDebug", "ThreatRole", "InitializeGroupSettings", "ReportTauntProbe",
    "InitializeTauntProbe"}
local REQUIRED_APIS = {
    {nil, "UnitExists"},
    {nil, "UnitThreatSituation"},
    {nil, "UnitDetailedThreatSituation"},
    {"C_Timer", "After"},
}

local function CheckInstall()
    for _, name in ipairs(REQUIRED_NAMESPACE) do
        if type(DTT[name]) ~= "function" then
            return false, "the toolkit's files are from different versions (missing " .. name
                .. "). Reinstall Dyre's Toolkit, then restart the client."
        end
    end
    for _, api in ipairs(REQUIRED_APIS) do
        local owner = _G
        if api[1] then
            owner = rawget(_G, api[1])
        end
        if type(owner) ~= "table" or type(owner[api[2]]) ~= "function" then
            return false, "this client lacks " .. (api[1] and (api[1] .. "." .. api[2]) or api[2]) .. "."
        end
    end
    return true
end

local function LoadDB()
    local classFile
    if type(UnitClass) == "function" then
        classFile = select(2, UnitClass("player"))
    end
    DTT.classFile = classFile
    DyresToolkitCharDB = DTT.SanitizeDB(DyresToolkitCharDB, classFile)
    DTT.db = DyresToolkitCharDB
end

-- Each kind: claimed for the toolkit, and its feature refreshed on a change
-- of owner.
local function ClaimKinds()
    local toolkit = ns.toolkit
    for feature, kind in pairs(DTT.KINDS) do
        toolkit.ClaimOwner(kind, DTT.ADDON, DTT.SELF_PRIORITY)
        toolkit.OnOwnerChanged(kind, function()
            if DTT.OnOwnerChanged then
                DTT.OnOwnerChanged(feature)
            end
        end)
    end
end

-- From Core.lua's PLAYER_LOGIN, after the toolkit's own settings, so the
-- sections come below them on the page.
function ns.InitializeTank()
    LoadDB()
    local available, why = CheckInstall()
    DTT.available, DTT.unavailable = available, why
    local conflict = FindSlashConflict()
    if conflict then
        DTT.Report("Another AddOn (" .. conflict .. ") also uses " .. PRIMARY_SLASH .. ". Use "
            .. BACKUP_SLASH .. " or /dyre instead.")
    end
    -- Quiet at login (the toolkit loads with every Dyre's AddOn); /dtt and
    -- /dtt debug say why.
    if not available then
        return
    end
    ClaimKinds()
    DTT.InitializeThreat()
    DTT.InitializePetTaunt()
    DTT.InitializeButtons()
    DTT.InitializePullDisplay()
    DTT.InitializeGroupSettings()
    DTT.InitializeTauntProbe()
end
