-- MomentDisplay: client-side display of viral moment broadcasts
-- Receives plain string messages from MomentEvent and shows as system chat.
-- Uses TextChatService with StarterGui:SetCore fallback for legacy chat.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")

local MomentEvent = ReplicatedStorage:WaitForChild("MomentEvent")

local function displayMessage(message)
    -- Try new chat (TextChatService)
    local ok = pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            TextChatService:DisplaySystemMessage(message)
        else
            error("legacy")
        end
    end)

    if not ok then
        -- Fallback: legacy chat
        pcall(function()
            StarterGui:SetCore("ChatMakeSystemMessage", {
                Text      = message,
                Color     = Color3.fromRGB(255, 215, 0),
                Font      = Enum.Font.GothamBold,
                TextSize  = 18,
            })
        end)
    end
end

MomentEvent.OnClientEvent:Connect(function(message)
    if type(message) == "string" then
        displayMessage(message)
    end
end)
