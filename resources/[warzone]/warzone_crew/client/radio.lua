-- resources/[warzone]/warzone_crew/client/radio.lua

local CrewRadio = {}
local radioMessages = {}
local maxRadioMessages = 10

-- Handle radio messages
RegisterNetEvent('warzone_crew:receiveRadioMessage')
AddEventHandler('warzone_crew:receiveRadioMessage', function(data)
    -- Add to message queue
    table.insert(radioMessages, 1, {
        sender = data.sender,
        message = data.message,
        frequency = data.frequency,
        time = GetGameTimer()
    })
    
    -- Limit message history
    while #radioMessages > maxRadioMessages do
        table.remove(radioMessages)
    end
    
    -- Show notification
    ESX.ShowNotification(string.format('📻 [%.1f] %s: %s', data.frequency, data.sender, data.message))
    
    -- Play radio sound effect
    PlaySoundFrontend(-1, "BEEP", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
end)

-- Send radio message
function CrewRadio.SendMessage(message)
    if not message or string.len(message) == 0 then return end
    
    TriggerServerEvent('warzone_crew:radioMessage', message)
    
    -- Show sent message
    ESX.ShowNotification(string.format('📻 Sent: %s', message))
end

-- Draw radio chat
function CrewRadio.DrawRadioChat()
    if #radioMessages == 0 then return end
    
    local currentTime = GetGameTimer()
    local startY = 0.7
    local lineHeight = 0.025
    
    for i, msg in ipairs(radioMessages) do
        if i > 5 then break end -- Show only last 5 messages
        
        -- Fade out old messages
        local age = currentTime - msg.time
        local alpha = math.max(0, 255 - (age / 20)) -- Fade over 5 seconds
        
        if alpha > 0 then
            local messageText = string.format('[%.1f] %s: %s', msg.frequency, msg.sender, msg.message)
            
            SetTextFont(4)
            SetTextProportional(true)
            SetTextScale(0.0, 0.3)
            SetTextColour(255, 255, 100, alpha) -- Yellow radio text
            SetTextDropshadow(0, 0, 0, 0, alpha)
            SetTextEdge(1, 0, 0, 0, alpha)
            SetTextEntry("STRING")
            AddTextComponentString(messageText)
            DrawText(0.01, startY - (i - 1) * lineHeight)
        end
    end
end

-- Radio chat thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if #radioMessages > 0 then
            CrewRadio.DrawRadioChat()
        else
            Citizen.Wait(500)
        end
    end
end)

-- Radio command
RegisterCommand('r', function(source, args)
    if #args > 0 then
        local message = table.concat(args, ' ')
        CrewRadio.SendMessage(message)
    else
        ESX.ShowNotification('Usage: /r [message]')
    end
end)

RegisterCommand('radio', function(source, args)
    if #args > 0 then
        local message = table.concat(args, ' ')
        CrewRadio.SendMessage(message)
    else
        ESX.ShowNotification('Usage: /radio [message]')
    end
end)

-- Export functions
exports('SendRadioMessage', CrewRadio.SendMessage)
exports('GetRadioMessages', function() return radioMessages end)