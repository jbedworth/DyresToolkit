-- The tank buttons' key bindings (Bindings.xml) stay in the toolkit after
-- 2.16.0, under the heading of Dyre's Threat and Combat Tools, which makes
-- the buttons (John, 2026-11-26: "B now, service later"). Two AddOns cannot
-- define the same binding name: with both files the client warned nine times
-- at each load ("was attempted to be loaded more than once", John's client,
-- 2026-11-26). Same names and the same file, so saved keys stay. Without
-- Dyre's Threat and Combat Tools the buttons do not exist and a key does
-- nothing. A toolkit key-binding service may replace this later.
-- One Skull row (John, 2026-11-26: "The skull keybind should skull my
-- mouseover,harm,nodead or harm,nodead target ... instead of two different
-- keybinds"): the SkullMouseover row is gone. DCT keeps that button, with
-- the Skull button's macro, so a key bound to it in 2.9-2.15 still works
-- (a CLICK binding needs no Bindings.xml row, only the named button).
local addonName, ns = ...

BINDING_HEADER_DYRESTOOLKIT = "Dyre's Threat and Combat Tools"

ns.BINDING_NAMES = {
    Skull = "Skull mouseover, else target",
    NextMarker = "Next marker (mouse, else target)",
    MarkPing = "Skull and ping Attack, mouseover, else target",
    PingAttack = "Ping Attack on your target",
    PingWarning = "Ping Warning on your target",
    PingAssist = "Ping Assist on your target",
    PingOnmyway = "Ping On my way on your target",
    Pull = "Pull countdown",
}
for name, text in pairs(ns.BINDING_NAMES) do
    _G["BINDING_NAME_CLICK DyresToolkit" .. name .. ":LeftButton"] = text
end
