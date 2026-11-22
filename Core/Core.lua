local _, ns = ...
-- luacheck: globals FallensFlyoutsDB FallensFlyouts_AttachDevTools
-- luacheck: read globals CreateFrame UnitGUID UnitName GetUnitName UnitClass GetRealmName issecretvalue
-- luacheck: read globals InCombatLockdown UIErrorsFrame geterrorhandler

-- the dev addon's way in
function FallensFlyouts_AttachDevTools(take) take(ns) end

-- the dev addon swaps this for its log
function ns.Log() end

-- Nothing is said in chat of what the player has just done and can see. (His words, 2026-11-22, of
-- "Elixirs is off the bars. Its flyout is removed.": "what the fuck is the point of these messages?")
-- A line for someone new, or one that tells of an update, is the only kind chat is for.

-- red, where the game says what it cannot do
function ns.Warn(why)
    if why and UIErrorsFrame then UIErrorsFrame:AddMessage(why, 1, 0.1, 0.1) end
end

-- names can repeat across characters; the id cannot
local function Who()
    local name = GetUnitName and GetUnitName("player", false) or UnitName("player")
    -- this client gives an empty realm
    local realm = GetRealmName()
    if type(realm) ~= "string" or realm == "" then realm = nil end
    local class = UnitClass("player")
    local id = UnitGUID("player")
    if type(id) ~= "string" or (issecretvalue and issecretvalue(id)) then
        id = tostring(name) .. "-" .. (realm or "")
    end
    return { id = id, name = tostring(name), realm = realm, class = class or "?" }
end

-- flyouts sit on protected buttons: no change in a fight
ns.Profiles.Busy = function() return InCombatLockdown() end

local starters = {}

-- fn() once the saved data is loaded
function ns.OnStart(fn) starters[#starters + 1] = fn end

-- saved data and this character's profile, once
function ns.Start()
    if ns.started then return end
    ns.started = true
    FallensFlyoutsDB = FallensFlyoutsDB or {}
    ns.me = Who()
    ns.Profiles.Load(FallensFlyoutsDB, ns.me)
    -- each part starts by itself: one that fails is reported and the rest still start
    for _, fn in ipairs(starters) do xpcall(fn, geterrorhandler()) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() ns.Start() end)
