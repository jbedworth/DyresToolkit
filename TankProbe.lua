local _, ns = ...
local DTT = ns.tank

-- `/dtt debug_threat` tells which threat values this client hides from
-- AddOns, and which ways of showing a secret still work. Run it out of
-- combat, then in combat with an enemy as your target, in the open world
-- and in a dungeon. It reads and prints only; the test text and bar it draws
-- on are hidden. Each check runs on its own (pcall), so one refused API
-- cannot hide the others; the client may not show Lua errors, so a failure
-- is printed in chat.
--
-- `/dtt debug` (`/dyre tank_debug`) prints the state: owners, pings, pull
-- runner, buttons, keys. `/dyre threat_debug` is `/dtt debug_threat`.
-- `/dtt debug_taunts` (`/dyre taunt_debug`): the taunt probe, at the end.
local MAX_PLATES_SHOWN = 4
local MAX_NAMEPLATE_UNITS = 40

local function Report(text)
    DTT.Report("debug_threat " .. text)
end

-- A value's type, and its contents when not secret.
local function Kind(value)
    if DTT.IsSecret(value) then
        return "secret(" .. type(value) .. ")"
    end
    if type(value) == "number" then
        return string.format("%.1f", value)
    end
    return tostring(value)
end

local function Try(fn, ...)
    local ok, failure = pcall(fn, ...)
    if ok then
        return "ok"
    end
    return "fail(" .. tostring(failure):gsub("^.-:%d+: ", "") .. ")"
end

-- A value to pass on: a secret as it is (never tested), nil as 0.
local function Pass(value)
    if DTT.IsSecret(value) then
        return value
    end
    return value or 0
end

local probe
local function ProbeFrames()
    if not probe then
        probe = CreateFrame("Frame", nil, UIParent)
        probe:Hide()
        probe.text = probe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        probe.bar = CreateFrame("StatusBar", nil, probe)
        probe.bar:SetMinMaxValues(0, 3)
    end
    return probe
end

-- Which ways of showing a secret status or percent this client allows.
local function ReportShowTests(label, isTanking, status, percent)
    local frames = ProbeFrames()
    local text, bar = frames.text, frames.bar
    local parts = {}
    parts[#parts + 1] = "formatPercent=" .. Try(text.SetFormattedText, text, "%.0f%%", Pass(percent))
    parts[#parts + 1] = "formatStatus=" .. Try(text.SetFormattedText, text, "%d", Pass(status))
    parts[#parts + 1] = "barValue=" .. Try(bar.SetValue, bar, Pass(status))
    if type(GetThreatStatusColor) == "function" then
        local ok, r, g, b = pcall(GetThreatStatusColor, Pass(status))
        if ok then
            parts[#parts + 1] = "statusColor=" .. Kind(r) .. " textColor="
                .. Try(text.SetTextColor, text, r, g, b)
        else
            parts[#parts + 1] = "statusColor=fail"
        end
    else
        parts[#parts + 1] = "statusColor=n/a"
    end
    if type(C_CurveUtil) == "table" and type(C_CurveUtil.CreateColorCurve) == "function" then
        local curve = C_CurveUtil.CreateColorCurve()
        parts[#parts + 1] = "colorCurve=" .. Try(function()
            curve:AddPoint(0, CreateColor(1, 0, 0))
            curve:AddPoint(3, CreateColor(0, 1, 0))
            local color = curve:Evaluate(Pass(status))
            text:SetTextColor(color:GetRGB())
        end)
    else
        parts[#parts + 1] = "colorCurve=n/a"
    end
    if type(text.SetAlphaFromBoolean) == "function" then
        local tanking = isTanking
        if not DTT.IsSecret(tanking) then
            tanking = tanking == true
        end
        parts[#parts + 1] = "alphaFromTanking=" .. Try(text.SetAlphaFromBoolean, text, tanking, 1, 0.3)
    else
        parts[#parts + 1] = "alphaFromTanking=n/a"
    end
    Report(label .. " show: " .. table.concat(parts, " "))
end

local function ReportUnit(label, unit)
    if not UnitExists(unit) then
        Report(label .. ": none")
        return
    end
    local ok, isTanking, status, scaled, raw, value = pcall(UnitDetailedThreatSituation, "player", unit)
    if not ok then
        Report(label .. ": UnitDetailedThreatSituation failed: " .. tostring(isTanking))
        return
    end
    local simpleOk, simple = pcall(UnitThreatSituation, "player", unit)
    Report(string.format("%s: tanking=%s status=%s scaled=%s raw=%s value=%s; UnitThreatSituation=%s",
        label, Kind(isTanking), Kind(status), Kind(scaled), Kind(raw), Kind(value),
        simpleOk and Kind(simple) or "failed"))
    ReportShowTests(label, isTanking, status, scaled)
end

local function ReportContext()
    local _, build = GetBuildInfo()
    local inInstance, instanceType = IsInInstance()
    Report(string.format("client=%s build=%s combat=%s instance=%s(%s) pings=%s",
        tostring((GetBuildInfo())), tostring(build), tostring(InCombatLockdown()), tostring(inInstance),
        tostring(instanceType), tostring(DTT.HasPings())))
end

local function ReportEvents()
    local parts = {}
    for event, count in pairs(DTT.threatEvents or {}) do
        parts[#parts + 1] = event .. "=" .. count
    end
    table.sort(parts)
    Report("events since login: " .. (#parts > 0 and table.concat(parts, " ") or "none"))
    -- The red and losing sounds since login, per mob: seen, played, and
    -- each skip (Threat.lua soundCounts).
    for _, kind in ipairs({"red", "losing"}) do
        local counts = DTT.soundCounts and DTT.soundCounts[kind]
        local order = DTT.SOUND_COUNT_ORDER and DTT.SOUND_COUNT_ORDER[kind]
        if counts and order then
            local parts = {}
            for index, key in ipairs(order) do
                parts[#parts + 1] = (index == 3 and "skipped " or "") .. key .. "=" .. tostring(counts[key])
            end
            Report(kind .. " sound: " .. table.concat(parts, " "))
        end
    end
    -- Who tanks in combat (Threat.lua auraReads, auraSecretReads, and
    -- tankCounts): the Righteous Fury reads in and out of combat, what
    -- C_Secrets.ShouldSpellAuraBeSecret said ("aura secret"), the nil reads
    -- held as hidden, and the Auto view changes in combat.
    if DTT.auraReads and DTT.auraSecretReads and DTT.tankCounts then
        local function Counts(store, order, place)
            local counts = {}
            for _, key in ipairs(order) do
                if store[place][key] then
                    counts[#counts + 1] = key .. "=" .. store[place][key]
                end
            end
            return #counts > 0 and table.concat(counts, " ") or "none"
        end
        local parts = {}
        for _, place in ipairs({"combat", "calm"}) do
            parts[#parts + 1] = place .. ": " .. Counts(DTT.auraReads, DTT.AURA_READ_ORDER, place)
                .. ", aura secret " .. Counts(DTT.auraSecretReads, DTT.AURA_SECRET_ORDER, place)
        end
        Report("righteous fury reads " .. table.concat(parts, "; ") .. "; held="
            .. DTT.tankCounts.held .. " view changes in combat=" .. DTT.tankCounts.viewChanges)
    end
end

-- Each party member's and pet's threat on a mob (what the pull bars and
-- early yellow need): plain, secret(type), or nil; one line per unit there.
local GROUP_PROBE_UNITS = {"pet", "party1", "party2", "party3", "party4",
    "partypet1", "partypet2", "partypet3", "partypet4"}

local function ReportGroup(label, mob)
    if not UnitExists(mob) then
        return
    end
    local count = 0
    for _, member in ipairs(GROUP_PROBE_UNITS) do
        if UnitExists(member) then
            count = count + 1
            local ok, isTanking, status, scaled, raw = pcall(UnitDetailedThreatSituation, member, mob)
            local simpleOk, simple = pcall(UnitThreatSituation, member, mob)
            if ok then
                Report(string.format("%s %s: tanking=%s status=%s scaled=%s raw=%s; UnitThreatSituation=%s",
                    label, member, Kind(isTanking), Kind(status), Kind(scaled), Kind(raw),
                    simpleOk and Kind(simple) or "failed"))
            else
                Report(label .. " " .. member .. ": UnitDetailedThreatSituation failed")
            end
        end
    end
    if count == 0 then
        Report(label .. " group: no party members or pets")
    end
end

function DTT.ReportThreatProbe()
    ReportContext()
    ReportUnit("target", "target")
    ReportGroup("target", "target")
    local shown = 0
    for index = 1, MAX_NAMEPLATE_UNITS do
        local unit = "nameplate" .. index
        if shown < MAX_PLATES_SHOWN and UnitExists(unit) then
            local canAttack = UnitCanAttack("player", unit)
            if DTT.IsSecret(canAttack) or canAttack then
                shown = shown + 1
                ReportUnit(unit, unit)
                if shown == 1 then
                    ReportGroup(unit, unit)
                end
            end
        end
    end
    ReportEvents()
end

local function BindingText(name)
    local key = GetBindingKey("CLICK " .. name .. ":LeftButton")
    return key and tostring(key) or "unbound"
end

function DTT.ReportDebug()
    if DTT.ReportPetTauntDebug then
        DTT.ReportPetTauntDebug()
    end
    local kind = DTT.PullRunner()
    DTT.Report(string.format("debug available=%s class=%s pings=%s pull=%s combat=%s",
        tostring(DTT.available), tostring(DTT.classFile), tostring(DTT.HasPings()), DTT.PullRunnerName(kind),
        tostring(InCombatLockdown())))
    local owners = {}
    for feature, ownerKind in pairs(DTT.KINDS) do
        owners[#owners + 1] = feature .. "=" .. tostring(ns.toolkit.KindOwner(ownerKind))
    end
    table.sort(owners)
    DTT.Report("debug owners " .. table.concat(owners, " "))
    -- Heard only: the toolkit sends nothing to learn these.
    local members = DTT.GroupAddOnLines and DTT.GroupAddOnLines() or {}
    DTT.Report("debug group boss mods (heard): " .. (#members > 0 and table.concat(members, "; ") or "no group"))
    DTT.Report("debug taunt probe: " .. DTT.TauntProbeSummary())
    if not DTT.db then
        return
    end
    local order = {}
    for _, marker in ipairs(DTT.db.markerOrder) do
        order[#order + 1] = DTT.MARKERS[marker]
    end
    local role, why = DTT.ThreatRole()
    DTT.Report("debug threat mode=" .. DTT.db.threatMode .. " view=" .. role .. " (" .. why .. ")"
        .. " platePlace=" .. DTT.db.platePlace
        .. " redSound=" .. (DTT.db.redSound or "default") .. ">" .. DTT.EffectiveSound(DTT.db.redSound,
            DTT.DEFAULT_RED_SOUND)
        .. " losingSound=" .. (DTT.db.losingSound or "default") .. ">" .. DTT.EffectiveSound(DTT.db.losingSound,
            DTT.DEFAULT_LOSING_SOUND)
        .. " soloSounds=" .. tostring(DTT.db.soloSounds)
        .. " pullBars=" .. tostring(DTT.db.pullBars)
        .. " petTaunt=" .. tostring(DTT.db.petTaunt))
    DTT.Report("debug plates=" .. tostring(DTT.db.plateThreat) .. " target=" .. tostring(DTT.db.targetThreat)
        .. " bar=" .. DTT.db.barMode .. " (" .. select(2, DTT.BarShown()) .. ")" .. " pullSeconds=" .. DTT.db.pull
        .. " order=" .. table.concat(order, ","))
    local buttons = DTT.Buttons and DTT.Buttons() or {}
    if buttons.next then
        DTT.Report("debug next index=" .. tostring(buttons.next:GetAttribute("dtt-index"))
            .. " keys: skull=" .. BindingText("DyresToolkitSkull")
            .. " mouse=" .. BindingText("DyresToolkitSkullMouseover")
            .. " next=" .. BindingText("DyresToolkitNextMarker")
            .. " markPing=" .. BindingText("DyresToolkitMarkPing")
            .. " pull=" .. BindingText("DyresToolkitPull"))
    end
end

-- Taunt probe (`/dtt debug_taunts`; John, 2026-11-12: "Can we announce with
-- either an emote or in party chat when someone other than the tank taunts,
-- growls, pops Righteous Fury, etc.?" ... "Yes, probe first, then build
-- it."). The announcement is not built: it waits for John's probe output.
-- Unknown: whether party members' and party pets' UNIT_SPELLCAST_SUCCEEDED
-- arguments (unit, castGUID, spellID) read in combat on Forever, or are
-- secret. Your own ("player", "pet") are counted the same way, as a control.
-- It only counts: nothing goes to chat or the party, nothing is saved (the
-- counts and the last 10 matches live for the session). Events only: one
-- frame per unit kind and pair of units (RegisterUnitEvent takes two units
-- per call; a later call on the same frame replaces them), no polling, no
-- combat log. Without RegisterUnitEvent, one frame takes the event for every
-- unit and keeps only these tokens. Never compares, prints, or indexes a
-- secret value.
local TAUNT_UNITS = {
    {kind = "player", units = {"player"}},
    {kind = "pet", units = {"pet"}},
    {kind = "party", units = {"party1", "party2"}},
    {kind = "party", units = {"party3", "party4"}},
    {kind = "partypet", units = {"partypet1", "partypet2"}},
    {kind = "partypet", units = {"partypet3", "partypet4"}},
}
DTT.TAUNT_KINDS = {"player", "pet", "party", "partypet"}
-- Watched by spell name (ranks differ by client): the name of each listed ID
-- in the client's language, and the English name. The IDs are rank 1.
DTT.TAUNT_WATCH = {
    {label = "Taunt", id = 355}, {label = "Mocking Blow", id = 694},
    {label = "Challenging Shout", id = 1161}, {label = "Growl", id = 2649},
    {label = "Challenging Roar", id = 5209}, {label = "Torment", id = 3716},
    {label = "Suffering", id = 17735}, {label = "Distracting Shot", id = 20736},
    {label = "Righteous Fury", id = 25780}, {label = "Defensive Stance", id = 71},
}
DTT.TAUNT_COUNT_ORDER = {"events", "spellRead", "spellSecret", "spellOther", "nameSecret", "guidSecret",
    "unitSecret"}
local TAUNT_RECENT = 10

local tauntProbe

local function PlainValue(value)
    if DTT.IsSecret(value) then
        return nil
    end
    return value
end

local function TauntSpellName(id)
    if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        return C_Spell.GetSpellName(id)
    end
    if type(GetSpellInfo) == "function" then
        return (GetSpellInfo(id))
    end
end

local function TauntCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function Now()
    local now = type(GetTime) == "function" and PlainValue(GetTime())
    return type(now) == "number" and now or 0
end

-- One event: counted by its frame's kind (known even when the unit is
-- secret); a readable spell's name is matched to the watch list.
local function CountCast(kind, unit, castGUID, spellID)
    local place = TauntCombat() and "combat" or "calm"
    local counts = tauntProbe.counts[kind][place]
    local function Add(key)
        counts[key] = (counts[key] or 0) + 1
    end
    Add("events")
    if DTT.IsSecret(unit) then
        Add("unitSecret")
    end
    if DTT.IsSecret(castGUID) then
        Add("guidSecret")
    end
    if DTT.IsSecret(spellID) then
        Add("spellSecret")
        return
    end
    if type(spellID) ~= "number" then
        Add("spellOther")
        return
    end
    Add("spellRead")
    local name = TauntSpellName(spellID)
    if DTT.IsSecret(name) then
        Add("nameSecret")
        return
    end
    local label = type(name) == "string" and tauntProbe.watch[name]
    if not label then
        return
    end
    local matches = tauntProbe.matches[label]
    matches[kind] = (matches[kind] or 0) + 1
    local recent = tauntProbe.recent
    recent[#recent + 1] = {time = Now(), combat = place == "combat",
        unit = type(PlainValue(unit)) == "string" and unit or "secret", kind = kind, spell = label}
    if #recent > TAUNT_RECENT then
        table.remove(recent, 1)
    end
end

function DTT.InitializeTauntProbe()
    if tauntProbe or type(CreateFrame) ~= "function" then
        return
    end
    tauntProbe = {counts = {}, matches = {}, recent = {}, watch = {}, registered = {}}
    for _, kind in ipairs(DTT.TAUNT_KINDS) do
        tauntProbe.counts[kind] = {combat = {}, calm = {}}
    end
    for _, entry in ipairs(DTT.TAUNT_WATCH) do
        tauntProbe.matches[entry.label] = {}
        tauntProbe.watch[entry.label] = entry.label
        local name = PlainValue(TauntSpellName(entry.id))
        if type(name) == "string" then
            tauntProbe.watch[name] = entry.label
        end
    end
    local first = CreateFrame("Frame")
    if type(first.RegisterUnitEvent) == "function" then
        tauntProbe.method = "RegisterUnitEvent"
        for index, group in ipairs(TAUNT_UNITS) do
            local frame = index == 1 and first or CreateFrame("Frame")
            local ok, result = pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", unpack(group.units))
            local answer = not ok and "error" or (result == false and "refused" or "ok")
            tauntProbe.registered[#tauntProbe.registered + 1] = table.concat(group.units, ",") .. "=" .. answer
            local kind = group.kind
            frame:SetScript("OnEvent", function(_, _, unit, castGUID, spellID)
                CountCast(kind, unit, castGUID, spellID)
            end)
        end
        return
    end
    tauntProbe.method = "RegisterEvent"
    local kinds = {}
    for _, group in ipairs(TAUNT_UNITS) do
        for _, unit in ipairs(group.units) do
            kinds[unit] = group.kind
        end
    end
    local ok = pcall(first.RegisterEvent, first, "UNIT_SPELLCAST_SUCCEEDED")
    tauntProbe.registered[1] = "all units=" .. (ok and "ok" or "error")
    first:SetScript("OnEvent", function(_, _, unit, castGUID, spellID)
        -- A secret unit cannot be told apart here: not counted.
        local kind = type(PlainValue(unit)) == "string" and kinds[unit]
        if kind then
            CountCast(kind, unit, castGUID, spellID)
        end
    end)
end

-- The probe's state, for tests: counts[kind][place][key],
-- matches[label][kind], recent, registered, method.
function DTT.TauntProbeState()
    return tauntProbe
end

local function TauntReport(text)
    DTT.Report("debug_taunts " .. text)
end

function DTT.ReportTauntProbe()
    if not tauntProbe then
        TauntReport("not running (the tank tools are off on this client)")
        return
    end
    TauntReport("registered (" .. tauntProbe.method .. "): " .. table.concat(tauntProbe.registered, " ")
        .. "; combat=" .. tostring(TauntCombat()))
    for _, kind in ipairs(DTT.TAUNT_KINDS) do
        local parts = {}
        for _, place in ipairs({"combat", "calm"}) do
            local counts, shown = tauntProbe.counts[kind][place], {}
            for _, key in ipairs(DTT.TAUNT_COUNT_ORDER) do
                if counts[key] then
                    shown[#shown + 1] = key .. "=" .. counts[key]
                end
            end
            parts[#parts + 1] = place .. ": " .. (#shown > 0 and table.concat(shown, " ") or "none")
        end
        TauntReport(kind .. " " .. table.concat(parts, "; "))
    end
    local matched = {}
    for _, entry in ipairs(DTT.TAUNT_WATCH) do
        local counts, shown = tauntProbe.matches[entry.label], {}
        for _, kind in ipairs(DTT.TAUNT_KINDS) do
            if counts[kind] then
                shown[#shown + 1] = kind .. "=" .. counts[kind]
            end
        end
        if #shown > 0 then
            matched[#matched + 1] = entry.label .. " " .. table.concat(shown, " ")
        end
    end
    TauntReport("matches: " .. (#matched > 0 and table.concat(matched, "; ") or "none"))
    local now = Now()
    for index = #tauntProbe.recent, 1, -1 do
        local match = tauntProbe.recent[index]
        TauntReport(string.format("recent %ds ago %s %s %s", math.floor(now - match.time + 0.5),
            match.combat and "combat" or "calm", match.unit, match.spell))
    end
end

-- One line for /dtt debug.
function DTT.TauntProbeSummary()
    if not tauntProbe then
        return "not running"
    end
    local events, matches = 0, 0
    for _, kind in ipairs(DTT.TAUNT_KINDS) do
        for _, place in ipairs({"combat", "calm"}) do
            events = events + (tauntProbe.counts[kind][place].events or 0)
        end
    end
    for _, counts in pairs(tauntProbe.matches) do
        for _, count in pairs(counts) do
            matches = matches + count
        end
    end
    return events .. " casts seen, " .. matches .. " watched; /dtt debug_taunts for details"
end
