local _, ns = ...
local DTT = ns.tank

-- The pull countdown (2.9.0, from Dyre's Tank Tools; Owners kind "tank:pull"):
-- `/dtt pull N`, `/dyre pull N`, and the PULL button. When Deadly Boss
-- Mods or BigWigs is loaded, DTT gives the pull to it (its own /pull);
-- else the game's countdown, C_PartyInfo.DoCountdown(seconds) -> success
-- (PartyInfoDocumentation.lua: Forever 70888 lines 155-170, HasRestrictions,
-- SecretArguments AllowedWhenUntainted; Era 70576 lines 50-64,
-- HasRestrictions; no protected flag). Every group member gets
-- START_PLAYER_COUNTDOWN and sees the game's TimerTracker countdown with no
-- AddOn; current DBM (UserTimers.lua) and BigWigs (Plugins/Pull.lua) send and
-- show pulls only through it. A false return (refused: who may call it is
-- not in the UI source, John recalls the leader only) or a client without
-- the event falls back to the toolkit's own message, which only toolkit
-- users see. Only when DoCountdown is missing: the toolkit's message alone.
-- 0 cancels (DoCountdown(0), as DBM and BigWigs do). The toolkit registers
-- no /pull of its own.
local DBM_SLASH = "/dbm"
local PULL_SLASH = "/pull"
local MAX_SLASH_ALIASES = 10

-- The SlashCmdList handler of another AddOn's command, else nil.
function DTT.FindSlashHandler(alias)
    for key, handler in pairs(SlashCmdList) do
        if key ~= "DYRESTOOLKITTANK" and key ~= "DYRESTOOLKIT" and type(handler) == "function" then
            for index = 1, MAX_SLASH_ALIASES do
                local name = rawget(_G, "SLASH_" .. key .. index)
                if type(name) == "string" and name:lower() == alias then
                    return handler
                end
            end
        end
    end
end

local function Loaded(name)
    if type(C_AddOns) ~= "table" or type(C_AddOns.IsAddOnLoaded) ~= "function" then
        return false
    end
    local loaded = C_AddOns.IsAddOnLoaded(name)
    return loaded == true
end

-- Who runs the countdown: "dbm", "bigwigs", "game", or nil (none can), and
-- the function that starts it with a number of seconds.
function DTT.PullRunner()
    if Loaded("DBM-Core") then
        local handler = DTT.FindSlashHandler(DBM_SLASH)
        if handler then
            return "dbm", function(seconds) handler("pull " .. seconds) end
        end
    end
    if Loaded("BigWigs") or Loaded("BigWigs_Core") or Loaded("BigWigs_Plugins") then
        local handler = DTT.FindSlashHandler(PULL_SLASH)
        if handler then
            return "bigwigs", function(seconds) handler(tostring(seconds)) end
        end
    end
    if type(C_PartyInfo) == "table" and type(C_PartyInfo.DoCountdown) == "function" then
        return "game", function(seconds)
            local success = C_PartyInfo.DoCountdown(seconds)
            -- Refused, or no countdown event to reach the group: tell other
            -- toolkit users, and show it here.
            if success == false or not DTT.GameCountdownEvent() then
                DTT.SendPull(seconds > 0 and seconds or nil)
                if seconds > 0 then
                    DTT.ShowPullCountdown(seconds, "toolkit", DTT.PlayerName())
                else
                    DTT.CancelPullCountdown()
                end
                if success == false then
                    DTT.Report("The game refused its countdown (it may need the group leader); Dyre's Toolkit "
                        .. "users in your group see the toolkit's.")
                end
            end
        end
    end
    if DTT.CanSendPull() then
        return "toolkit", function(seconds)
            if seconds > 0 then
                DTT.SendPull(seconds)
                DTT.ShowPullCountdown(seconds, "toolkit", DTT.PlayerName())
            else
                DTT.SendPull(nil)
                DTT.CancelPullCountdown()
            end
        end
    end
end

function DTT.PlayerName()
    return type(UnitName) == "function" and UnitName("player") or nil
end

local RUNNER_NAMES = {dbm = "Deadly Boss Mods", bigwigs = "BigWigs", game = "the game's countdown",
    toolkit = "Dyre's Toolkit's countdown"}

function DTT.PullRunnerName(kind)
    return RUNNER_NAMES[kind] or "none"
end

-- seconds: from /dtt pull N, else the saved length; 0 cancels.
function DTT.StartPull(seconds)
    if not DTT.Owns("pull") then
        DTT.Report("Another Dyre's AddOn runs the pull countdown.")
        return false
    end
    if seconds ~= 0 then
        seconds = DTT.SanitizePull(seconds or DTT.db.pull)
    end
    local kind, run = DTT.PullRunner()
    if not run then
        DTT.Report("This client has no pull countdown, and neither DBM nor BigWigs is loaded.")
        return false
    end
    run(seconds)
    return true, kind
end

-- The pull countdown display (2.9.0; Owners kind "tank:pullDisplay"; John,
-- 2026-11-11: "our own pull timer indicator ... for both tank and party
-- members"; "If we're going to have our own pull experience, it should be
-- really good."). In the middle of the screen (a widget you can move, scale,
-- and fade): a big number that pops in and fades each second, gold, then
-- orange at 3 and 2, red at 1; a thin bar under it that drains over the
-- whole pull; "Pull in 10 - Name" when the source names who started it; a
-- "PULL!" splash at 0 that grows and fades; "Pull cancelled" on a cancel.
-- A tick sound on each of the last TICK_FROM seconds and a go sound at 0,
-- each the player's choice from the warning sound menus.
--
-- Motion is the engine's: AnimationGroups (Scale and Alpha) for the pop,
-- the splash, and the bar's drain (one Scale from full to empty over the
-- time left, origin LEFT). Code runs only on whole seconds: one C_Timer at a
-- time, never OnUpdate or a ticker. The end of the splash or the cancel
-- note hides it (their OnFinished).
--
-- It starts on every pull the client can see: the game's countdown event
-- (START_PLAYER_COUNTDOWN where it exists), older Deadly Boss Mods' and
-- BigWigs' pull messages, and the toolkit's own message (PULL_PREFIX). A
-- cancel from any of them shows "Pull cancelled". A second start within
-- SAME_PULL seconds with about the same end is the same pull; a combat start
-- does not cancel it.
--
-- `pullDisplay` ("Dyre's countdown on screen", a checkbox, on by default;
-- only this display, never the send path): on, it shows unless Deadly Boss
-- Mods or BigWigs is loaded (they always draw their own: John's test,
-- 2026-11-11, "they hook the game's countdown timer and always render"),
-- and then it replaces the game's own countdown (TimerTracker's player
-- countdown) as BigWigs does (Loader.lua 1232-1233 at dccbd7b8:
-- TimerTracker:UnregisterEvent for START_PLAYER_COUNTDOWN and
-- CANCEL_PLAYER_COUNTDOWN). Only those two registrations change: no
-- function is replaced, no frame is shown, hidden, or moved, and nothing
-- protected is touched; TimerTracker's other timers (PvP, Challenge Mode)
-- stay. They are given back when the display turns off or a boss mod
-- loads. Off: it never shows, and the game's countdown is the game's.
local PULL_PREFIX = "DyresToolkit"
local PULL_PROTOCOL = "1"
local DBM_PREFIXES = {D5 = true, D4 = true}
local BIGWIGS_PREFIX = "BigWigs"
local SAME_PULL = 1
local MAX_PULL = 300
local TICK_FROM = 5
local GAME_COUNTDOWN_EVENTS = {"START_PLAYER_COUNTDOWN", "CANCEL_PLAYER_COUNTDOWN"}
local DISPLAY_WIDTH, DISPLAY_HEIGHT = 260, 150
local DISPLAY_PLACE = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 180}
local NUMBER_SIZE, LINE_SIZE, SPLASH_SIZE, CANCEL_SIZE = 72, 16, 60, 28
local BAR_WIDTH, BAR_HEIGHT, BAR_EDGE = 200, 6, 1
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
-- The toolkit's gold (the warning box's), then orange and red as the
-- threat labels use them; green for the go.
local GOLD = {1, 0.82, 0}
local ORANGE = {1, 0.5, 0}
local RED = {1, 0.2, 0.2}
local GREEN = {0.2, 1, 0.2}
local GREY = {0.8, 0.8, 0.8}
-- The pop: in from 1.5x and transparent to 1x in POP_IN, then a fade to
-- POP_FADE_TO from POP_FADE_AT for POP_FADE seconds, all in one second.
local POP_IN, POP_FROM = 0.2, 1.5
local POP_FADE_AT, POP_FADE, POP_FADE_TO = 0.6, 0.35, 0.35
-- The splash: grows 0.7x to 1.6x over SPLASH_GROW, fades from SPLASH_FADE_AT
-- for SPLASH_FADE.
local SPLASH_GROW, SPLASH_FROM, SPLASH_TO = 1.0, 0.7, 1.6
local SPLASH_FADE_AT, SPLASH_FADE = 0.4, 0.6
local CANCEL_HOLD, CANCEL_FADE = 1.0, 0.6
local NAME_LENGTH = 24

local display
-- The running pull: when it ends, when it started, its source and starter,
-- and the one timer.
local pull = {}
-- Whether the toolkit has taken TimerTracker's two countdown events.
local tookGameCountdown = false

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function Plain(value)
    if DTT.IsSecret(value) then
        return nil
    end
    return value
end

-- Whether a boss mod that shows its own pull timer is loaded.
function DTT.BossModLoaded()
    return Loaded("DBM-Core") or Loaded("BigWigs") or Loaded("BigWigs_Core") or Loaded("BigWigs_Plugins")
end

-- The design rule (John, 2026-11-11): "We sit between other addons and the
-- default experience, only." So: which boss mod shows a pull, else nil
-- (the toolkit's turn). BigWigs always does (its pull bar has no switch,
-- Plugins/Pull.lua 429 at dccbd7b8). DBM does unless its own "Do not show
-- Pull/Break Timer bar" is on (DBM.Options.DontShowPT2, CoreOptions.lua 418
-- at e903df81): then DBM is not "the" pull timer, and Dyre's countdown
-- shows. Read fresh each time with rawget, never written, no hook; an
-- unreadable DBM.Options counts as DBM showing its own.
function DTT.BossModShowingPull()
    if Loaded("BigWigs") or Loaded("BigWigs_Core") or Loaded("BigWigs_Plugins") then
        return "bigwigs"
    end
    if Loaded("DBM-Core") then
        local dbm = rawget(_G, "DBM")
        local options = type(dbm) == "table" and rawget(dbm, "Options")
        if type(options) == "table" and rawget(options, "DontShowPT2") == true then
            return nil
        end
        return "dbm"
    end
end

function DTT.PullDisplayWanted()
    return DTT.Owns("pullDisplay") and DTT.db.pullDisplay == true and not DTT.BossModShowingPull()
end

-- The game's countdown event, where the client has one.
function DTT.GameCountdownEvent()
    return DTT.EventExists("START_PLAYER_COUNTDOWN")
end

-- Takes or gives back TimerTracker's player countdown events, out of
-- combat (an event registration, but the toolkit keeps Blizzard frames out
-- of combat-time changes). Only events this client has.
function DTT.ApplyGameCountdown()
    DTT.OutOfCombat("gameCountdown", function()
        local tracker = rawget(_G, "TimerTracker")
        if type(tracker) ~= "table" or type(tracker.UnregisterEvent) ~= "function"
                or type(tracker.RegisterEvent) ~= "function" then
            return
        end
        local take = DTT.PullDisplayWanted()
        if take == tookGameCountdown then
            return
        end
        -- BigWigs' loader takes them itself (Loader.lua 1232-1233): never
        -- hand them back over it.
        local bigwigs = Loaded("BigWigs") or Loaded("BigWigs_Core")
        for _, event in ipairs(GAME_COUNTDOWN_EVENTS) do
            if DTT.EventExists(event) and (take or not bigwigs) then
                if take then
                    tracker:UnregisterEvent(event)
                else
                    tracker:RegisterEvent(event)
                end
            end
        end
        tookGameCountdown = take
    end)
end

function DTT.TookGameCountdown()
    return tookGameCountdown
end

function DTT.CanSendPull()
    return type(C_ChatInfo) == "table" and type(C_ChatInfo.SendAddonMessage) == "function"
        and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function"
end

-- Tells other toolkit users in your group. Solo: nobody to tell.
function DTT.SendPull(seconds)
    if not DTT.CanSendPull() then
        return false
    end
    local channel = (type(IsInRaid) == "function" and IsInRaid() and "RAID")
        or (type(IsInGroup) == "function" and IsInGroup() and "PARTY") or nil
    if not channel then
        return false
    end
    local message = seconds and (PULL_PROTOCOL .. "\tPULL\t" .. seconds) or (PULL_PROTOCOL .. "\tCANCEL")
    C_ChatInfo.SendAddonMessage(PULL_PREFIX, message, channel)
    return true
end

-- A starter's name as plain text: realm dropped on your realm, no escape
-- codes, cut short; nil for a secret or nothing.
local function StarterName(name)
    name = Plain(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if type(Ambiguate) == "function" then
        local short = Ambiguate(name, "none")
        name = type(short) == "string" and short or name
    end
    name = name:gsub("[|%c]", ""):sub(1, NAME_LENGTH)
    return name ~= "" and name or nil
end

local function StopTimer()
    if pull.timer then
        pull.timer:Cancel()
        pull.timer = nil
    end
end

local function ColorFor(whole)
    if whole <= 1 then
        return RED
    elseif whole <= 3 then
        return ORANGE
    end
    return GOLD
end

local function Restart(group)
    group:Stop()
    group:Play()
end

local function ShowParts(number, bar, splash)
    display.number:SetShown(number)
    display.line:SetShown(number)
    display.barBack:SetShown(bar)
    display.bar:SetShown(bar)
    display.splash:SetShown(splash)
    display.content:Show()
end

-- The number for a whole second, its color, the line, and the pop.
local function DrawSecond(whole)
    local color = ColorFor(whole)
    display.number:SetText(tostring(whole))
    display.number:SetTextColor(color[1], color[2], color[3])
    display.bar:SetVertexColor(color[1], color[2], color[3])
    display.line:SetText(pull.starter and ("Pull in " .. whole .. " - " .. pull.starter) or ("Pull in " .. whole))
    Restart(display.pop)
end

-- The bar: as long as the time left is of the whole pull, draining to empty
-- by the end (a little after, so it never springs back before the splash).
local function StartBar(left, total)
    local fraction = math.max(0.02, math.min(1, left / total))
    display.bar:SetWidth(BAR_WIDTH * fraction)
    display.drain:Stop()
    display.drainScale:SetDuration(left + 0.1)
    display.drain:Play()
end

local function Finish()
    StopTimer()
    display.drain:Stop()
    if display.sample then
        return
    end
    display.content:Hide()
end

local function Clear()
    pull.ends, pull.started, pull.source, pull.starter, pull.total = nil, nil, nil, nil, nil
end

local function Splash(text, color, size, group)
    display.splash:SetFont(display.font, size, "THICKOUTLINE")
    display.splash:SetText(text)
    display.splash:SetTextColor(color[1], color[2], color[3])
    display.pop:Stop()
    display.drain:Stop()
    ShowParts(false, false, true)
    display.go:Stop()
    display.cancelled:Stop()
    group:Play()
end

-- One step a second: the number, a tick on the last seconds, and the one
-- timer to the next whole second; at 0 the splash and the go sound.
local function Step()
    pull.timer = nil
    local left = pull.ends - Now()
    local whole = math.ceil(left - 0.05)
    if whole <= 0 then
        Clear()
        Splash("PULL!", GREEN, SPLASH_SIZE, display.go)
        DTT.PlayChoice(DTT.db.pullGo, DTT.DEFAULT_PULL_GO, "Pull")
        return
    end
    DrawSecond(whole)
    if whole <= TICK_FROM then
        DTT.PlayChoice(DTT.db.pullTick, DTT.DEFAULT_PULL_TICK, tostring(whole))
    end
    pull.timer = C_Timer.NewTimer(math.max(0.05, left - (whole - 1)), Step)
end

-- Starts (or restarts) the display. source: who sent it ("game", "dbm",
-- "bigwigs", "toolkit"); starter: the name the source gave, if any; total:
-- the pull's whole length, if the source says (the bar's full length).
function DTT.ShowPullCountdown(seconds, source, starter, total)
    seconds, total = Plain(seconds), Plain(total)
    if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 or seconds > MAX_PULL then
        return false
    end
    if not display or not DTT.PullDisplayWanted() or type(C_Timer) ~= "table"
            or type(C_Timer.NewTimer) ~= "function" then
        return false
    end
    local now = Now()
    if pull.ends and pull.started and now - pull.started < SAME_PULL
            and math.abs(pull.ends - (now + seconds)) <= SAME_PULL then
        -- The same pull from another source: keep it, and learn its starter.
        pull.starter = pull.starter or StarterName(starter)
        return false
    end
    StopTimer()
    display.go:Stop()
    display.cancelled:Stop()
    total = type(total) == "number" and total >= seconds and total <= MAX_PULL and total or seconds
    pull.ends, pull.started, pull.source, pull.starter, pull.total = now + seconds, now, source,
        StarterName(starter), total
    ShowParts(true, true, false)
    StartBar(seconds, total)
    Step()
    return true
end

-- A cancel: "Pull cancelled" for a moment, when one was running.
function DTT.CancelPullCountdown()
    if not pull.ends then
        return false
    end
    StopTimer()
    Clear()
    if display then
        Splash("Pull cancelled", GREY, CANCEL_SIZE, display.cancelled)
    end
    return true
end

-- Turned off, or a boss mod took over: gone at once, no note.
function DTT.StopPullCountdown()
    StopTimer()
    Clear()
    if display then
        display.go:Stop()
        display.cancelled:Stop()
        Finish()
    end
end

-- The setting changed: stop a running display it no longer wants, and take
-- or give back the game's countdown.
function DTT.ApplyPullDisplay()
    if not DTT.PullDisplayWanted() then
        DTT.StopPullCountdown()
    end
    DTT.ApplyGameCountdown()
end

function DTT.PullCountdownState()
    return pull, display
end

-- Messages ----------------------------------------------------------------------------

local function Split(text)
    local fields = {}
    for field in (text .. "\t"):gmatch("([^\t]*)\t") do
        fields[#fields + 1] = field
    end
    return fields
end

-- Deadly Boss Mods: "PT" then the seconds (0 cancels), anywhere after its
-- sender and protocol fields (D5) or first (D4).
local function ReadDBM(text)
    local fields = Split(text)
    for index, field in ipairs(fields) do
        if field == "PT" then
            return tonumber(fields[index + 1])
        end
    end
end

-- BigWigs: "P^Pull^<seconds>" (0 cancels).
local function ReadBigWigs(text)
    local seconds = text:match("^P%^Pull%^(%d+)")
    return tonumber(seconds)
end

local function ReadToolkit(text)
    local fields = Split(text)
    if fields[1] ~= PULL_PROTOCOL then
        return nil
    end
    if fields[2] == "CANCEL" then
        return 0
    elseif fields[2] == "PULL" then
        return tonumber(fields[3])
    end
end

-- A pull message: the seconds (0 cancels), else nil. Never for a secret.
function DTT.ReadPullMessage(prefix, text)
    prefix, text = Plain(prefix), Plain(text)
    if type(prefix) ~= "string" or type(text) ~= "string" then
        return nil
    end
    if DBM_PREFIXES[prefix] then
        return ReadDBM(text), "dbm"
    elseif prefix == BIGWIGS_PREFIX then
        return ReadBigWigs(text), "bigwigs"
    elseif prefix == PULL_PREFIX then
        return ReadToolkit(text), "toolkit"
    end
end

-- Group members' boss mods, heard only (John, 2026-11-11: "build the
-- version list too"; for /dtt debug). The toolkit sends nothing for it:
-- DBM and BigWigs answer each other's hellos within seconds of a group
-- forming (research notes, toolkit-2.9.0-pull-countdown-research.md):
--   DBM "D5": "<Name-Realm>\t<protocol>\tV\t<revision>\t<release>\t<display>..."
--     (AddonComms.lua 522); "...\tH\t" is a hello from DBM or BigWigs.
--   BigWigs "BigWigs": "Q^<version>^..." and "V^<version>^..." (Loader.lua
--     96-101); version 0 is DBM's query, not a version.
-- Each one fakes the other's reply when asked (BigWigs a DBM V, DBM a BigWigs
-- V), so the list says what was heard, not proof. A toolkit pull message
-- marks Dyre's Toolkit; other toolkit users show as unknown. Only party,
-- raid, and instance messages count; a member who left is dropped at
-- GROUP_ROSTER_UPDATE. Payloads are data: read with patterns, never run;
-- a secret field is skipped; stored text is cut to MAX_VERSION_TEXT with
-- "|" and control characters removed, so it prints as plain text.
local GROUP_CHANNELS = {PARTY = true, RAID = true, INSTANCE_CHAT = true}
local MAX_VERSION_TEXT = 24
local heard = {}

local function CleanText(text)
    return (text:gsub("[|%c]", ""):sub(1, MAX_VERSION_TEXT))
end

-- A sender as group units name it: "Name" on your realm, else "Name-Realm".
local function MemberKey(sender)
    if type(Ambiguate) == "function" then
        local short = Ambiguate(sender, "none")
        if type(short) == "string" then
            return short
        end
    end
    return sender
end

-- Your group's other members by MemberKey, in group order.
local function GroupMembers()
    local members = {}
    if type(IsInGroup) ~= "function" or not IsInGroup() or type(GetUnitName) ~= "function" then
        return members
    end
    local raid = type(IsInRaid) == "function" and IsInRaid()
    local count = raid and (Plain(type(GetNumGroupMembers) == "function" and GetNumGroupMembers()) or 0) or 4
    for index = 1, type(count) == "number" and count or 0 do
        local unit = (raid and "raid" or "party") .. index
        if Plain(UnitExists(unit)) == true and Plain(UnitIsUnit(unit, "player")) ~= true then
            local name = Plain(GetUnitName(unit, true))
            if type(name) == "string" then
                members[#members + 1] = name
            end
        end
    end
    return members
end

local function Note(sender, mod, version)
    local key = MemberKey(sender)
    heard[key] = heard[key] or {}
    local entry = heard[key]
    if version or not entry[mod] then
        entry[mod] = version or entry[mod] or "?"
    end
end

-- One CHAT_MSG_ADDON message, for the version list.
function DTT.HearAddonMessage(prefix, text, channel, sender)
    prefix, text, channel, sender = Plain(prefix), Plain(text), Plain(channel), Plain(sender)
    if type(prefix) ~= "string" or type(text) ~= "string" or type(sender) ~= "string" or sender == ""
            or not GROUP_CHANNELS[channel] then
        return
    end
    if prefix == "D5" then
        local fields = Split(text)
        if fields[3] == "V" and fields[6] and fields[6] ~= "" then
            Note(sender, "DBM", CleanText(fields[6]))
        elseif fields[3] == "H" then
            Note(sender, "hello")
        end
    elseif prefix == BIGWIGS_PREFIX then
        local kind, version = text:match("^([QV])%^(%d+)%^")
        if kind and version ~= "0" then
            Note(sender, "BigWigs", CleanText(version))
        end
    elseif prefix == PULL_PREFIX then
        Note(sender, "Dyre's Toolkit")
    end
end

-- Drops members who left.
function DTT.ForgetGoneMembers()
    local present = {}
    for _, name in ipairs(GroupMembers()) do
        present[name] = true
    end
    for key in pairs(heard) do
        if not present[key] then
            heard[key] = nil
        end
    end
end

-- "Name: DBM 11.2.3, BigWigs 427" per group member; "unknown" when nothing
-- named a boss mod (a DBM or BigWigs hello alone says "DBM or BigWigs").
function DTT.GroupAddOnLines()
    local lines = {}
    for _, name in ipairs(GroupMembers()) do
        local entry = heard[name] or {}
        local parts = {}
        for _, mod in ipairs({"DBM", "BigWigs", "Dyre's Toolkit"}) do
            if entry[mod] then
                parts[#parts + 1] = entry[mod] == "?" and mod or (mod .. " " .. entry[mod])
            end
        end
        if #parts == 0 and entry.hello then
            parts[1] = "DBM or BigWigs"
        end
        lines[#lines + 1] = CleanText(name) .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "unknown")
    end
    return lines
end

local function OnPullEvent(_, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        DTT.ForgetGoneMembers()
        -- Also a moment to match the game's countdown to DBM's option.
        DTT.ApplyGameCountdown()
    elseif event == "PLAYER_ENTERING_WORLD" then
        DTT.ApplyGameCountdown()
    elseif event == "ADDON_LOADED" then
        -- A boss mod loaded later (on demand): it draws its own.
        if DTT.BossModLoaded() then
            DTT.ApplyPullDisplay()
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, _, sender = ...
        DTT.HearAddonMessage(...)
        local seconds, source = DTT.ReadPullMessage(prefix, text)
        if seconds == 0 then
            DTT.CancelPullCountdown()
        elseif seconds then
            DTT.ShowPullCountdown(seconds, source, sender)
        end
    elseif event == "START_PLAYER_COUNTDOWN" then
        local _, timeRemaining, totalTime, _, initiatedByName = ...
        DTT.ShowPullCountdown(timeRemaining, "game", initiatedByName, totalTime)
        -- DBM's option may have changed since: match the game's countdown
        -- to it for the next pull (it has no change event).
        DTT.ApplyGameCountdown()
    elseif event == "CANCEL_PLAYER_COUNTDOWN" then
        DTT.CancelPullCountdown()
    end
end

local function NewAnimation(group, kind, order)
    local animation = group:CreateAnimation(kind)
    if order and type(animation.SetOrder) == "function" then
        animation:SetOrder(order)
    end
    return animation
end

-- A Scale animation from one size to another (SetScaleFrom/To where the
-- client has them, else a relative SetScale), around origin.
local function ScaleAnimation(group, from, to, duration, origin)
    local scale = NewAnimation(group, "Scale")
    if type(scale.SetScaleFrom) == "function" and type(scale.SetScaleTo) == "function" then
        scale:SetScaleFrom(from[1], from[2])
        scale:SetScaleTo(to[1], to[2])
    else
        scale:SetScale(to[1] / from[1], to[2] / from[2])
    end
    scale:SetDuration(duration)
    if origin then
        scale:SetOrigin(origin, 0, 0)
    end
    if type(scale.SetSmoothing) == "function" then
        scale:SetSmoothing("OUT")
    end
    return scale
end

local function AlphaAnimation(group, from, to, delay, duration)
    local alpha = NewAnimation(group, "Alpha")
    alpha:SetFromAlpha(from)
    alpha:SetToAlpha(to)
    alpha:SetStartDelay(delay)
    alpha:SetDuration(duration)
    return alpha
end

local function BuildDisplay()
    local frame = CreateFrame("Frame", "DyresToolkitPullTimer", UIParent)
    frame:SetFrameStrata("HIGH")
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    content:Hide()
    -- GameFontNormalHuge's face (Friz Quadrata on both clients), larger.
    local font = rawget(_G, "STANDARD_TEXT_FONT") or "Fonts\\FRIZQT__.TTF"
    local number = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    number:SetFont(font, NUMBER_SIZE, "THICKOUTLINE")
    number:SetShadowOffset(2, -2)
    number:SetPoint("CENTER", content, "CENTER", 0, 18)
    local barBack = content:CreateTexture(nil, "ARTWORK", nil, 0)
    barBack:SetTexture(WHITE_TEXTURE)
    barBack:SetVertexColor(0, 0, 0, 0.75)
    barBack:SetSize(BAR_WIDTH + 2 * BAR_EDGE, BAR_HEIGHT + 2 * BAR_EDGE)
    barBack:SetPoint("TOP", number, "BOTTOM", 0, -6)
    local bar = content:CreateTexture(nil, "ARTWORK", nil, 1)
    bar:SetTexture(WHITE_TEXTURE)
    bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
    bar:SetPoint("LEFT", barBack, "LEFT", BAR_EDGE, 0)
    local line = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    line:SetFont(font, LINE_SIZE, "OUTLINE")
    line:SetPoint("TOP", barBack, "BOTTOM", 0, -6)
    line:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local splash = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    splash:SetFont(font, SPLASH_SIZE, "THICKOUTLINE")
    splash:SetShadowOffset(2, -2)
    splash:SetPoint("CENTER", content, "CENTER", 0, 18)

    -- The pop, on the number each second.
    local pop = number:CreateAnimationGroup()
    ScaleAnimation(pop, {POP_FROM, POP_FROM}, {1, 1}, POP_IN)
    AlphaAnimation(pop, 0, 1, 0, POP_IN)
    AlphaAnimation(pop, 1, POP_FADE_TO, POP_FADE_AT, POP_FADE)
    -- The drain, on the bar, from its left end.
    local drain = bar:CreateAnimationGroup()
    local drainScale = ScaleAnimation(drain, {1, 1}, {0.001, 1}, 1, "LEFT")
    if type(drainScale.SetSmoothing) == "function" then
        drainScale:SetSmoothing("NONE")
    end
    -- The splash at 0, and the cancel note; each hides it when done.
    local go = splash:CreateAnimationGroup()
    ScaleAnimation(go, {SPLASH_FROM, SPLASH_FROM}, {SPLASH_TO, SPLASH_TO}, SPLASH_GROW)
    AlphaAnimation(go, 1, 0, SPLASH_FADE_AT, SPLASH_FADE)
    go:SetScript("OnFinished", Finish)
    local cancelled = splash:CreateAnimationGroup()
    AlphaAnimation(cancelled, 1, 0, CANCEL_HOLD, CANCEL_FADE)
    cancelled:SetScript("OnFinished", Finish)

    display = {frame = frame, content = content, number = number, line = line, bar = bar, barBack = barBack,
        splash = splash, pop = pop, drain = drain, drainScale = drainScale, go = go, cancelled = cancelled,
        font = font}
    display.widget = ns.toolkit.CreateWidget({
        addon = DTT.ADDON, key = "pullTimer", title = "Pull countdown", frame = frame, store = DTT.db.pullTimer,
        width = DISPLAY_WIDTH, height = DISPLAY_HEIGHT, point = DISPLAY_PLACE,
        sizes = {scale = true, opacity = true},
        onUnlock = function(_, unlocked)
            display.sample = unlocked or nil
            if unlocked then
                if not pull.ends then
                    ShowParts(true, true, false)
                    pull.starter = nil
                    DrawSecond(10)
                    display.bar:SetWidth(BAR_WIDTH)
                end
            elseif not pull.ends then
                Finish()
            end
        end,
    })
end

function DTT.PullDisplayWidget()
    return display and display.widget
end

function DTT.InitializePullDisplay()
    BuildDisplay()
    local frame = CreateFrame("Frame")
    if type(C_ChatInfo) == "table" and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        C_ChatInfo.RegisterAddonMessagePrefix(PULL_PREFIX)
        -- Boss mods register theirs when loaded; without them the client
        -- gives an AddOn only the prefixes it registered.
        for prefix in pairs(DBM_PREFIXES) do
            C_ChatInfo.RegisterAddonMessagePrefix(prefix)
        end
        C_ChatInfo.RegisterAddonMessagePrefix(BIGWIGS_PREFIX)
        frame:RegisterEvent("CHAT_MSG_ADDON")
    end
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ADDON_LOADED")
    for _, event in ipairs(GAME_COUNTDOWN_EVENTS) do
        if DTT.EventExists(event) then
            frame:RegisterEvent(event)
        end
    end
    frame:SetScript("OnEvent", OnPullEvent)
    DTT.ApplyGameCountdown()
end
