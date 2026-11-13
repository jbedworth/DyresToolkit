local _, ns = ...
local DTT = ns.tank

-- Marker, ping, and pull buttons, on a bar and as key bindings (Bindings.xml)
-- (2.9.0, from Dyre's Tank Tools; Owners kinds "tank:markers", "tank:pings",
-- "tank:pull").
--
-- Marking: AddOn code never calls SetRaidTarget. It has HasRestrictions, and
-- in combat the game blocks it with the "blocked from an action" popup. The
-- buttons are secure action buttons with macro text instead: the game's own
-- /tm marks in combat. "!" keeps a second press from taking the marker off.
-- The game puts each marker on a short cooldown (about 4 fast presses).
--
-- "Next marker" puts the next marker of the order on each press: skull, then
-- cross, square... A restricted snippet (SecureHandlerWrapScript) changes the
-- button's macrotext before each click; restricted code may SetAttribute in
-- combat. The order starts again after combat.
--
-- Pings: the ping API (C_PingSecure) is secure only, so the game's /ping in
-- macro text too. A client without /ping (Classic Era) gets no ping buttons,
-- and their key bindings do nothing.
--
-- The bar is a toolkit widget (mouse "always": it is a bar of buttons): it
-- moves with every Dyre's frame (/dyre unlock, or Ctrl-drag while locked), by
-- any button too (AddDragHandle), and changes only out of combat.
--
-- When it shows (John, 2026-11-11): "auto" (the default) while you tank
-- (Threat.lua TankBarWanted: group role Tank or raid main tank, Warrior
-- Defensive Stance, Druid Bear Form, Paladin Righteous Fury); "always";
-- "never". It shows also while frames are unlocked, to move it. Show and
-- hide is a protected change: out of combat only, else at the end of combat.
-- No macro condition covers the role or Righteous Fury, so no state driver.
-- An answer the client hides (a secret) keeps the bar as it is.
--
-- Auto is sticky (John, 2026-11-11: "sticky auto with a 30 second delay"),
-- so stance dancing does not make the bar flicker: it shows at once when a
-- reason to show comes, and hides only after 30 continuous seconds out of
-- combat with none. One one-shot C_Timer (no ticker, no OnUpdate) starts
-- when the reasons end out of combat, or at the end of combat when they are
-- gone then; a reason that comes back, or combat, cancels it. When it fires,
-- the bar hides only if there is still no reason and no combat. While your
-- role is Tank or raid main tank, there is always a reason: it never hides.
local HIDE_DELAY = 30
local BUTTON_SIZE = 30
local BUTTON_GAP = 4
local PADDING = 4
local BAR_POINT = {point = "CENTER", relativePoint = "CENTER", x = 0, y = -180}
local MARKER_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local SKULL = 8
local LABEL_FONT = "GameFontNormalSmall"
local PREFIX = "DyresToolkit"

local bar, header
local buttons = {}
-- Whether Auto shows the bar (a secret answer keeps it), and the hide timer.
local lastWanted = false
local hideTimer

-- Macro text -----------------------------------------------------------------------

-- The game's /tm for one or more units in order, or nil for no marker.
-- (DyresToolkit.MarkLine marks one unit; this takes a list, mouse first.)
function DTT.MarkLine(units, marker)
    if type(marker) ~= "number" or not DTT.MARKERS[marker] then
        return nil
    end
    local conditions = {}
    for _, unit in ipairs(units) do
        conditions[#conditions + 1] = "[@" .. unit .. ",harm,nodead,exists]"
    end
    return "/tm " .. table.concat(conditions) .. " !" .. marker
end

DTT.PING_TYPES = {
    {key = "attack", name = "Attack", label = "Attack", short = "ATK", condition = "[@target,harm,exists]"},
    {key = "warning", name = "Warning", label = "Warning", short = "WARN", condition = "[@target,exists]"},
    {key = "assist", name = "Assist", label = "Assist", short = "HELP", condition = "[@target,exists]"},
    {key = "onmyway", name = "Onmyway", label = "On my way", short = "OMW", condition = "[@target,exists]"},
}

function DTT.PingLine(kind)
    for _, ping in ipairs(DTT.PING_TYPES) do
        if ping.key == kind then
            return "/ping " .. ping.condition .. " " .. ping.key
        end
    end
end

-- Whether this client has the game's /ping (Forever does; Classic Era 1.15
-- has no ping system, to be checked in client: TESTING.md).
function DTT.HasPings()
    return type(rawget(_G, "SLASH_PING1")) == "string"
end

local NEXT_UNITS = {"mouseover", "target"}

-- The macro text for each step of the "next marker" order.
function DTT.NextMarkerTexts(order)
    local texts = {}
    for index, marker in ipairs(order) do
        texts[index] = DTT.MarkLine(NEXT_UNITS, marker)
    end
    return texts
end

-- Runs in the restricted environment before each click: on the release (the
-- press that acts), it moves to the next text of the order.
DTT.NEXT_MARKER_SNIPPET = [[
    local count = self:GetAttribute("dtt-count") or 0
    if down or count == 0 then
        return
    end
    local index = (self:GetAttribute("dtt-index") or 0) % count + 1
    self:SetAttribute("dtt-index", index)
    self:SetAttribute("macrotext", self:GetAttribute("dtt-text" .. index))
]]

-- Runs fn now out of combat, else once combat ends (one entry per key).
function DTT.OutOfCombat(key, fn)
    return ns.toolkit.OutOfCombat("tank:" .. key, fn)
end

-- Buttons --------------------------------------------------------------------------

local function Tooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.title)
    if button.hint then
        GameTooltip:AddLine(button.hint, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function Decorate(button, title, hint)
    button.title, button.hint = title, hint
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.label = button:CreateFontString(nil, "OVERLAY", LABEL_FONT)
    button.label:SetPoint("CENTER")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.6)
    button:SetScript("OnEnter", Tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A named secure button (key bindings click it by name) with macro text.
local function SecureButton(name, title, hint, text)
    local button = CreateFrame("Button", PREFIX .. name, bar, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown")
    -- Act on the release, as Warlock Tools Forever's buttons do, so key
    -- bindings work with ActionButtonUseKeyDown on or off.
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", text)
    Decorate(button, title, hint)
    return button
end

local function ShowNextIcon(button)
    local order = DTT.db.markerOrder
    local index = button:GetAttribute("dtt-index") or 0
    local marker = order[index % #order + 1]
    button.icon:SetTexture(MARKER_ICON .. marker)
end

-- The macro texts, from the settings and the owners; out of combat only. A
-- feature another Dyre's AddOn owns gets no text: its button and binding do
-- nothing, and its button hides.
local function ApplyTexts()
    local pings = DTT.HasPings() and DTT.Owns("pings")
    local marks = DTT.Owns("markers")
    local skullText = marks and DTT.MarkLine({"target"}, SKULL) or nil
    buttons.skull:SetAttribute("macrotext", skullText)
    buttons.skull.available = marks
    buttons.mouseover:SetAttribute("macrotext", marks and DTT.MarkLine({"mouseover"}, SKULL) or nil)
    buttons.markPing:SetAttribute("macrotext",
        marks and pings and (skullText .. "\n" .. DTT.PingLine("attack")) or nil)
    buttons.markPing.available = marks and pings
    for _, ping in ipairs(DTT.PING_TYPES) do
        local button = buttons["ping" .. ping.key]
        button:SetAttribute("macrotext", pings and DTT.PingLine(ping.key) or nil)
        button.available = pings
    end
    local nextButton = buttons.next
    local texts = marks and DTT.NextMarkerTexts(DTT.db.markerOrder) or {}
    nextButton:SetAttribute("dtt-count", #texts)
    nextButton:SetAttribute("dtt-index", 0)
    for index, text in ipairs(texts) do
        nextButton:SetAttribute("dtt-text" .. index, text)
    end
    nextButton:SetAttribute("macrotext", texts[1])
    nextButton.available = marks
    ShowNextIcon(nextButton)
    buttons.pull.available = DTT.Owns("pull")
end

-- Writes the order into the "next marker" button; out of combat only.
function DTT.ApplyMarkerOrder()
    if not buttons.next then
        return
    end
    DTT.OutOfCombat("markerOrder", ApplyTexts)
end

local function CreateNextButton()
    local button = SecureButton("NextMarker", "Next marker",
        "Puts the next marker on the mob under your mouse, else your target: skull, then cross, square... "
            .. "The order starts again after combat.", nil)
    header = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    SecureHandlerWrapScript(button, "OnClick", header, DTT.NEXT_MARKER_SNIPPET)
    button:HookScript("PostClick", ShowNextIcon)
    return button
end

local function CreatePullButton()
    local button = CreateFrame("Button", PREFIX .. "Pull", bar)
    Decorate(button, "Pull countdown", "Starts the pull countdown (DBM or BigWigs when loaded). Set its "
        .. "length in the settings, or type /dtt pull 10.")
    button.label:SetText("PULL")
    button:SetScript("OnClick", function() DTT.StartPull() end)
    return button
end

-- The shown buttons in a row; the widget's size follows them.
local function LayOut()
    local shown = {}
    for _, button in ipairs(buttons) do
        if button.available then
            shown[#shown + 1] = button
        else
            button:Hide()
        end
    end
    for index, button in ipairs(shown) do
        button:ClearAllPoints()
        button:SetPoint("LEFT", bar, "LEFT", PADDING + (index - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
        button:Show()
    end
    local count = math.max(1, #shown)
    bar:SetContentSize(PADDING * 2 + count * BUTTON_SIZE + (count - 1) * BUTTON_GAP, BUTTON_SIZE + PADDING * 2)
end

-- Whether the bar shows now, and why (for /dtt debug).
function DTT.BarShown()
    if not (buttons.skull and buttons.pull) or not (buttons.skull.available or buttons.pull.available) then
        return false, "no button is on"
    end
    if not ns.toolkit.IsLocked() then
        return true, "frames unlocked"
    end
    local mode = DTT.db.barMode
    if mode == "always" then
        DTT.CancelBarHide()
        return true, "Always"
    elseif mode == "never" then
        DTT.CancelBarHide()
        return false, "Never"
    end
    local wanted, why = DTT.TankBarWanted()
    if wanted == nil then
        return lastWanted, "Auto: " .. why .. ", kept"
    elseif wanted then
        DTT.CancelBarHide()
        lastWanted = true
        return true, "Auto: " .. why
    elseif lastWanted and type(C_Timer) == "table" and type(C_Timer.NewTimer) == "function" then
        DTT.StartBarHide()
        return true, "Auto: " .. why .. ", hides after " .. HIDE_DELAY .. " s out of combat"
    end
    lastWanted = false
    return false, "Auto: " .. why
end

function DTT.CancelBarHide()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

-- The one-shot hide timer; out of combat only, one at a time.
function DTT.StartBarHide()
    if hideTimer or InCombatLockdown() or type(C_Timer) ~= "table" or type(C_Timer.NewTimer) ~= "function" then
        return
    end
    hideTimer = C_Timer.NewTimer(HIDE_DELAY, function()
        hideTimer = nil
        if InCombatLockdown() or DTT.db.barMode ~= "auto" or DTT.TankBarWanted() ~= false then
            return
        end
        lastWanted = false
        DTT.UpdateBarShown()
    end)
end

-- Show or hide the bar; out of combat (in combat, at the end of combat).
function DTT.UpdateBarShown()
    if not bar then
        return
    end
    DTT.OutOfCombat("barShown", function()
        bar:SetShown((DTT.BarShown()))
    end)
end

-- Texts, buttons, and the bar from the settings and the owners; out of combat.
function DTT.RefreshBar()
    if not bar then
        return
    end
    DTT.OutOfCombat("bar", function()
        ApplyTexts()
        LayOut()
        bar:SetShown((DTT.BarShown()))
    end)
end

function DTT.ResetBar()
    if not bar then
        return
    end
    bar:ResetPosition()
    DTT.Report("The tank button bar is back in its first place.")
end

local function BindingNames()
    _G.BINDING_HEADER_DYRESTOOLKIT = "Dyre's Toolkit"
    local names = {
        Skull = "Skull your target",
        SkullMouseover = "Skull the mob under your mouse",
        NextMarker = "Next marker (mouse, else target)",
        MarkPing = "Skull and ping Attack on your target",
        Pull = "Pull countdown",
    }
    for _, ping in ipairs(DTT.PING_TYPES) do
        names["Ping" .. ping.name] = "Ping " .. ping.label .. " on your target"
    end
    for name, text in pairs(names) do
        _G["BINDING_NAME_CLICK " .. PREFIX .. name .. ":LeftButton"] = text
    end
end

function DTT.InitializeButtons()
    BindingNames()
    bar = CreateFrame("Frame", PREFIX .. "TankBar", UIParent)
    ns.toolkit.CreateWidget({
        addon = DTT.ADDON, key = "tankBar", title = "Tank buttons", frame = bar, store = DTT.db.bar,
        width = BUTTON_SIZE + PADDING * 2, height = BUTTON_SIZE + PADDING * 2, point = BAR_POINT,
        sizes = {scale = true}, mouse = "always", hint = "Tank buttons",
        onUnlock = function() DTT.UpdateBarShown() end,
    })

    buttons.skull = SecureButton("Skull", "Skull", "Puts the skull on your target, also in combat.", nil)
    buttons.skull.icon:SetTexture(MARKER_ICON .. SKULL)
    -- Key binding only: a click on the bar has no mob under the mouse.
    buttons.mouseover = SecureButton("SkullMouseover", "Skull (mouse)",
        "Puts the skull on the mob under your mouse.", nil)
    buttons.next = CreateNextButton()
    buttons.markPing = SecureButton("MarkPing", "Skull and ping",
        "Puts the skull on your target and pings Attack on it, in one press.", nil)
    buttons.markPing.icon:SetTexture(MARKER_ICON .. SKULL)
    buttons.markPing.label:SetText("!")
    buttons[#buttons + 1] = buttons.skull
    buttons[#buttons + 1] = buttons.next
    buttons[#buttons + 1] = buttons.markPing
    for _, ping in ipairs(DTT.PING_TYPES) do
        local button = SecureButton("Ping" .. ping.name, "Ping " .. ping.label,
            "Pings " .. ping.label .. " on your target.", nil)
        button.label:SetText(ping.short)
        buttons["ping" .. ping.key] = button
        buttons[#buttons + 1] = button
    end
    buttons.pull = CreatePullButton()
    buttons[#buttons + 1] = buttons.pull
    for _, button in ipairs(buttons) do
        bar:AddDragHandle(button)
    end
    buttons.mouseover:Hide()
    DTT.RefreshBar()

    -- The "next marker" order starts again after each fight.
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function()
        buttons.next:SetAttribute("dtt-index", 0)
        buttons.next:SetAttribute("macrotext", buttons.next:GetAttribute("dtt-text1"))
        ShowNextIcon(buttons.next)
    end)

    -- Auto: the bar follows your role, stance, form, and Righteous Fury.
    -- Events only; in combat a change waits for the end of combat.
    local watch = CreateFrame("Frame")
    for _, event in ipairs({"UPDATE_SHAPESHIFT_FORM", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD"}) do
        watch:RegisterEvent(event)
    end
    if DTT.EventExists("PLAYER_ROLES_ASSIGNED") then
        watch:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    end
    -- Righteous Fury: only a Paladin's own auras.
    if DTT.classFile == "PALADIN" then
        watch:RegisterUnitEvent("UNIT_AURA", "player")
    end
    -- Combat stops the hide wait; its end starts it again if no reason is back.
    watch:RegisterEvent("PLAYER_REGEN_DISABLED")
    watch:RegisterEvent("PLAYER_REGEN_ENABLED")
    watch:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            DTT.CancelBarHide()
        elseif DTT.db.barMode == "auto" then
            DTT.UpdateBarShown()
        end
    end)
end

-- For /dtt debug and the tests.
function DTT.Buttons()
    return buttons, bar
end
