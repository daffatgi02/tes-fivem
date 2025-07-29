-- resources/[warzone]/warzone_crew/server/radio.lua

WarzoneRadio = {}

-- Setup radio for player
RegisterNetEvent('warzone_crew:setupRadio')
AddEventHandler('warzone_crew:setupRadio', function(source, frequency)
    if GetResourceState('pma-voice') ~= 'started' then
        print("[WARZONE CREW] pma-voice not available")
        return
    end
    
    -- Set player radio frequency
    exports['pma-voice']:setPlayerRadio(source, frequency)
    
    -- Notify player
    TriggerClientEvent('esx:showNotification', source, 
        string.format('📻 Radio frequency set to: %.1f', frequency))
    
    if Config.Debug then
        print(string.format("[WARZONE CREW] Player %d radio set to %.1f", source, frequency))
    end
end)

-- Remove radio from player
RegisterNetEvent('warzone_crew:removeRadio')
AddEventHandler('warzone_crew:removeRadio', function(source)
    if GetResourceState('pma-voice') ~= 'started' then return end
    
    -- Remove player from radio
    exports['pma-voice']:removePlayerFromRadio(source)
    
    -- Notify player
    TriggerClientEvent('esx:showNotification', source, '📻 Radio disconnected')
    
    if Config.Debug then
        print(string.format("[WARZONE CREW] Player %d radio removed", source))
    end
end)

-- Handle crew radio communication
RegisterNetEvent('warzone_crew:radioMessage')
AddEventHandler('warzone_crew:radioMessage', function(message)
    local _source = source
    local crewId = WarzoneCrews.PlayerCrews[_source]
    
    if not crewId then return end
    
    local crew = WarzoneCrews.ActiveCrews[crewId]
    if not crew then return end
    
    local player = WarzonePlayer.GetBySource(_source)
    if not player then return end
    
    -- Send to all crew members
    for identifier, member in pairs(crew.members) do
        if member.source and member.source ~= _source then
            TriggerClientEvent('warzone_crew:receiveRadioMessage', member.source, {
                sender = player:GetDisplayName(),
                message = message,
                frequency = crew.radioFrequency
            })
        end
    end
end)

-- Proximity voice integration
function WarzoneRadio.SetupProximityVoice(source)
    if GetResourceState('pma-voice') ~= 'started' then return end
    
    -- Set proximity voice settings for crew
    exports['pma-voice']:setPlayerRadio(source, 0) -- Default channel
end

-- Export functions
exports('SetupPlayerRadio', function(source, frequency)
    TriggerEvent('warzone_crew:setupRadio', source, frequency)
end)

exports('RemovePlayerRadio', function(source)
    TriggerEvent('warzone_crew:removeRadio', source)
end)