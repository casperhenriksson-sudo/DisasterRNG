-- CameraStateManager: priority-based camera ownership stack
-- Priority values: CinematicDeath=2, SpectatorCamera=1, ScreenshotMode=0
-- Only the highest-priority system controls the camera at any time.

local CameraStateManager = {}

local stack = {}  -- array of {name=string, priority=number}

local function getHighest()
    local best = nil
    for _, entry in ipairs(stack) do
        if best == nil or entry.priority > best.priority then
            best = entry
        end
    end
    return best
end

local function applyState()
    local cam = workspace.CurrentCamera
    local best = getHighest()
    if best then
        cam.CameraType = Enum.CameraType.Scriptable
    else
        cam.CameraType = Enum.CameraType.Custom
    end
end

-- Push a named camera controller onto the stack.
-- If it's already in the stack, update its priority.
function CameraStateManager.push(name, priority)
    -- Remove existing entry with same name
    for i = #stack, 1, -1 do
        if stack[i].name == name then
            table.remove(stack, i)
        end
    end
    table.insert(stack, {name = name, priority = priority})
    applyState()
end

-- Remove a named camera controller from the stack.
-- The next highest-priority controller (or default) becomes active.
function CameraStateManager.pop(name)
    for i = #stack, 1, -1 do
        if stack[i].name == name then
            table.remove(stack, i)
        end
    end
    applyState()
end

-- Returns the name of the currently active controller, or nil if none.
function CameraStateManager.getActive()
    local best = getHighest()
    return best and best.name or nil
end

return CameraStateManager
