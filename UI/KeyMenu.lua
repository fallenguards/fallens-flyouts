local _, ns = ...
-- luacheck: read globals SettingsPanel C_Timer GetMouseFoci GetMouseFocus GetBinding

-- In the game's key menu a hover on a flyout's row lights its bar button,
-- as the game lights a bar button under the rows of its own.
local K = {}
ns.KeyMenu = K
local F, Binds = ns.Flyouts, ns.Binds

local ticker, lit

-- the command of the key menu row under the mouse, if it is on one
local function Row()
    local frame
    if GetMouseFoci then
        local foci = GetMouseFoci()
        frame = foci and foci[1]
    elseif GetMouseFocus then
        frame = GetMouseFocus()
    end
    -- the row itself, or a button or the text on it
    for _ = 1, 3 do
        if type(frame) ~= "table" or frame:IsForbidden() then return nil end
        local data = type(frame.initializer) == "table" and frame.initializer.data
        if type(data) == "table" and data.bindingIndex then return (GetBinding(data.bindingIndex)) end
        frame = frame:GetParent()
    end
    return nil
end

-- lights the button of the row's flyout; any other row, or none, puts it out
function K.Hover(command)
    local n = Binds.Number(command)
    if n == lit then return end
    lit = n
    F.Point(n)
end

local function Watch()
    if ticker then return end
    ticker = C_Timer.NewTicker(0.1, function() K.Hover(Row()) end)
end

local function Rest()
    if ticker then ticker:Cancel() end
    ticker = nil
    K.Hover(nil)
end

-- only while the game's settings window is up
ns.OnStart(function()
    if not (SettingsPanel and SettingsPanel.HookScript) then return end
    SettingsPanel:HookScript("OnShow", Watch)
    SettingsPanel:HookScript("OnHide", Rest)
    if SettingsPanel:IsShown() then Watch() end
end)
