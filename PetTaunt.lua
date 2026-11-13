local _, ns = ...
local DTT = ns.tank

-- The Pet Taunt warning (2.9.0, moved from Dyre's Buff Reminders 1.5.0's
-- Reminders.lua and Buffs.lua; Owners kind "warn:petTaunt"): in a group
-- where you are not the designated tank, your pet's taunt on autocast pulls
-- mobs off the tank. A message box on screen (a toolkit widget you can move)
-- and a line in chat say so, when it becomes true (joining a group, a role
-- change, the pet summoned, autocast turned on) or its text changes, and
-- once more as combat starts; at most once per WARNING_GAP seconds. The
-- check runs out of combat (DBR's rule). A secret answer: no warning.
--
-- Dyre's Buff Reminders keeps its own copy for older toolkits; with this
-- toolkit the toolkit owns the kind at a higher priority, so DBR yields.
local WARNING_GAP = 30
local POP_WIDTH, POP_HEIGHT = 420, 58
local POP_PLACE = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 300}
local POP_HOLD, POP_FADE = 4, 1.5
local GOLD = {1, 0.82, 0}
local PET_ACTION_SLOTS = rawget(_G, "NUM_PET_ACTION_SLOTS") or 10

-- By class: the pet taunts, every rank, by name; knownBy: the spells that
-- make it apply (a pet's spells are not yours). Growl; the Voidwalker's
-- Torment and Suffering, and the Felguard's Anguish (TBC IDs, as DBR).
DTT.PET_TAUNTS = {
    HUNTER = {petTaunts = {2649, 14916, 14917, 14918, 14919, 14920, 14921, 27047}, knownBy = {883}},
    WARLOCK = {petTaunts = {3716, 7809, 7810, 7811, 11774, 11775, 27270, 17735, 17750, 17751, 17752, 27271,
        33701, 33698, 33699, 33700}, knownBy = {697, 30146}},
}

local spec
local state = {}
local pop

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

-- Your group's designated tank: the Tank role, or a raid's main tank. A
-- secret or missing answer is not a tank.
local function DesignatedTank()
    if type(UnitGroupRolesAssigned) == "function" and Plain(UnitGroupRolesAssigned("player")) == "TANK" then
        return true
    end
    return type(IsInRaid) == "function" and IsInRaid() and type(GetPartyAssignment) == "function"
        and Plain(GetPartyAssignment("MAINTANK", "player")) == true
end

-- The taunts on your pet's bar with autocast on, by name.
local function TauntsOn()
    local names, on = {}, {}
    for _, id in ipairs(spec.petTaunts) do
        local name = SpellName(id)
        if name then
            names[name] = true
        end
    end
    if type(GetPetActionInfo) ~= "function" or Plain(UnitExists("pet")) ~= true then
        return on
    end
    for slot = 1, PET_ACTION_SLOTS do
        local name, _, isToken, _, _, autoCastEnabled = GetPetActionInfo(slot)
        if not DTT.IsSecret(name) and not DTT.IsSecret(autoCastEnabled) and not isToken and names[name]
                and autoCastEnabled == true then
            on[#on + 1] = name
        end
    end
    return on
end

-- The warning's title and line while it applies, else nil.
function DTT.PetTauntText()
    if not spec or not DTT.db.petTaunt or not DTT.Owns("petTaunt") or not ns.toolkit.KnowsAny(spec.knownBy) then
        return nil
    end
    if not IsInGroup() or DesignatedTank() then
        return nil
    end
    local on = TauntsOn()
    if #on > 0 then
        return "Pet taunt on", table.concat(on, " and ") .. (#on > 1 and " are" or " is")
            .. " on autocast in a group. Turn it off."
    end
end

local function ShowPop(title, line)
    pop.title:SetText(title)
    pop.line:SetText(line)
    pop.fader:Stop()
    pop.content:SetAlpha(1)
    pop.content:Show()
    pop.fader:Play()
end

-- On screen and in chat, at most once per WARNING_GAP seconds.
local function Announce()
    local now = GetTime()
    if state.shown and now - state.shown < WARNING_GAP then
        return
    end
    state.shown = now
    ShowPop(state.title, state.line)
    DTT.Report(state.title .. ": " .. state.line)
end

-- Out of combat: says the warning when it becomes true or its text changes.
function DTT.CheckPetTaunt()
    if not spec or InCombatLockdown() then
        return
    end
    local title, line = DTT.PetTauntText()
    local text = title and (title .. "\n" .. line) or nil
    local changed = text ~= nil and text ~= state.text
    state.title, state.line, state.text = title, line, text
    if changed then
        Announce()
    end
end

local function BuildPop()
    local frame = CreateFrame("Frame", "DyresToolkitWarning", UIParent)
    frame:SetFrameStrata("HIGH")
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    content:Hide()
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", content, "TOP", 0, -2)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local line = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    line:SetPoint("TOP", title, "BOTTOM", 0, -4)
    local fader = content:CreateAnimationGroup()
    local fade = fader:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(POP_HOLD)
    fade:SetDuration(POP_FADE)
    fader:SetScript("OnFinished", function() content:Hide() end)
    pop = {frame = frame, content = content, title = title, line = line, fader = fader}
    ns.toolkit.CreateWidget({
        addon = DTT.ADDON, key = "warnings", title = "Warning messages", frame = frame, store = DTT.db.warning,
        width = POP_WIDTH, height = POP_HEIGHT, point = POP_PLACE, sizes = {scale = true},
        onUnlock = function(_, unlocked)
            if unlocked then
                pop.fader:Stop()
                pop.title:SetText("Pet taunt on")
                pop.line:SetText("Growl is on autocast in a group. Turn it off.")
                pop.content:SetAlpha(1)
                pop.content:Show()
            elseif not pop.fader:IsPlaying() then
                pop.content:Hide()
            end
        end,
    })
end

local EVENTS = {"PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"}
local OPTIONAL_EVENTS = {"PLAYER_ROLES_ASSIGNED"}

local function OnEvent(_, event, unit)
    if event == "UNIT_PET" and unit ~= "player" then
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        -- Combat starts: once more while still true.
        if state.text then
            Announce()
        end
        return
    end
    DTT.CheckPetTaunt()
end

-- Only for a class with a pet taunt; the message box is made for it alone.
function DTT.InitializePetTaunt()
    spec = DTT.PET_TAUNTS[DTT.classFile]
    if not spec then
        return
    end
    BuildPop()
    local frame = CreateFrame("Frame")
    for _, event in ipairs(EVENTS) do
        frame:RegisterEvent(event)
    end
    for _, event in ipairs(OPTIONAL_EVENTS) do
        if DTT.EventExists(event) then
            frame:RegisterEvent(event)
        end
    end
    frame:SetScript("OnEvent", OnEvent)
    DTT.CheckPetTaunt()
end

function DTT.ReportPetTauntDebug()
    if not spec then
        DTT.Report("debug petTaunt: no pet taunt for this class")
        return
    end
    DTT.Report(string.format("debug petTaunt on=%s owner=%s known=%s now=%s", tostring(DTT.db.petTaunt),
        tostring(ns.toolkit.KindOwner(DTT.KINDS.petTaunt)), tostring(ns.toolkit.KnowsAny(spec.knownBy)),
        state.text and (state.title .. ": " .. state.line) or "none"))
end
