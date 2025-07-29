-- resources/[warzone]/warzone_spawn/client/config_loader.lua

WarzoneSpawnConfigClient = {}
local configs = {}

-- Load config from server
function WarzoneSpawnConfigClient.Init()
    ESX.TriggerServerCallback('warzone_spawn:getConfigs', function(serverConfigs)
        configs = serverConfigs
        print("^2[WARZONE SPAWN] Client configs loaded^7")
        
        -- Trigger config loaded event
        TriggerEvent('warzone_spawn:configsLoaded')
    end)
end

-- Getter functions
function WarzoneSpawnConfigClient.GetSpawn()
    return configs.spawn or {}
end

function WarzoneSpawnConfigClient.GetLocations()
    return configs.locations or {}
end

-- Handle config reload
RegisterNetEvent('warzone_spawn:configReloaded')
AddEventHandler('warzone_spawn:configReloaded', function()
    WarzoneSpawnConfigClient.Init()
    ESX.ShowNotification('🔄 Spawn configuration reloaded!')
end)

-- Initialize when ready
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    
    WarzoneSpawnConfigClient.Init()
end)