local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

-- Only run on the server
if not RunService:IsServer() then return end

local url = "http://localhost:8080"

local function sendLog(message, messageType)
    local typeStr = "INFO"
    if messageType == Enum.MessageType.MessageError then typeStr = "ERROR"
    elseif messageType == Enum.MessageType.MessageWarning then typeStr = "WARN"
    end
    
    task.spawn(function()
        pcall(function()
            HttpService:PostAsync(url, HttpService:JSONEncode({
                message = message,
                type = typeStr
            }), Enum.HttpContentType.ApplicationJson)
        end)
    end)
end

LogService.MessageOut:Connect(function(message, messageType)
    -- Ignore built-in spam if any, just send it all
    sendLog(message, messageType)
end)

print("--- AI LOGGER CONNECTED ---")
