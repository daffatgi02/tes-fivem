-- resources/[warzone]/warzone_core/client/main.lua
ESX = nil
WarzonePlayer = {}
local playerData = {}
local isLoggedIn = false
local combatStatus = false

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    
    print("^2[WARZONE]^7 Client initialized!")
end)

-- Player Data Loaded
RegisterNetEvent('warzone:playerLoaded')
AddEventHandler('warzone:playerLoaded', function(data)
    playerData = data
    isLoggedIn = true
    
    ESX.ShowNotification(string.format('🎮 Welcome back, %s#%s!', data.nickname, data.tag))
    ESX.ShowNotification(string.format('🎖️ Role: %s | 💀 K/D: %d/%d', 
        Config.Roles[data.role].label, data.kills, data.deaths))
    
    -- Initialize UI
    TriggerEvent('warzone:updateHUD', data)
end)

-- Character Creation
RegisterNetEvent('warzone:showCharacterCreation')
AddEventHandler('warzone:showCharacterCreation', function()
    -- Simple character creation using ESX input
    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'character_creation', {
        title = 'WARZONE INDONESIA - Character Creation'
    }, function(data, menu)
        local nickname = data.value
        if nickname and string.len(nickname) >= 3 then
            ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'tag_creation', {
                title = 'Enter your TAG (2-6 characters)'
            }, function(data2, menu2)
                local tag = data2.value
                if tag and string.len(tag) >= 2 then
                    menu.close()
                    menu2.close()
                    TriggerServerEvent('warzone:createCharacter', nickname, tag)
                else
                    ESX.ShowNotification('❌ Tag must be 2-6 characters!')
                end
            end, function(data2, menu2)
                menu2.close()
            end)
        else
            ESX.ShowNotification('❌ Nickname must be at least 3 characters!')
        end
    end, function(data, menu)
        menu.close()
    end)
end)

-- Character Created
RegisterNetEvent('warzone:characterCreated')
AddEventHandler('warzone:characterCreated', function()
    -- Character creation successful
    ESX.ShowNotification('✅ Welcome to WARZONE INDONESIA!')
    
    -- Teleport to spawn
    local ped = PlayerPedId()
    SetEntityCoords(ped, Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z)
    SetEntityHeading(ped, Config.DefaultSpawn.heading)
end)

-- Combat Status
RegisterNetEvent('warzone:setCombatStatus')
AddEventHandler('warzone:setCombatStatus', function(status)
    combatStatus = status
    
    if status then
        ESX.ShowNotification('⚔️ You are now in combat!')
    else
        ESX.ShowNotification('✅ You are no longer in combat')
    end
end)

-- Combat Detection
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        
        if isLoggedIn then
            local ped = PlayerPedId()
            
            -- Check if player is shooting
            if IsPedShooting(ped) then
                if not combatStatus then
                    TriggerServerEvent('warzone:enterCombat')
                end
            end
            
            -- Check if player took damage
            if HasEntityBeenDamagedByAnyPed(ped) then
                ClearEntityLastDamageEntity(ped)
                if not combatStatus then
                    TriggerServerEvent('warzone:enterCombat')
                end
            end
        end
    end
end)

-- Death Handler
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local damage = args[6]
        local weapon = args[7]
        
        if victim == PlayerPedId() and GetEntityHealth(victim) <= 0 then
            -- Player died
            local attackerPlayerId = NetworkGetPlayerIndexFromPed(attacker)
            if attackerPlayerId ~= -1 then
                local attackerServerId = GetPlayerServerId(attackerPlayerId)
                TriggerServerEvent('warzone:playerKilled', attackerServerId, weapon)
            else
                TriggerServerEvent('warzone:playerKilled', nil, weapon)
            end
        end
    end
end)

-- Disable default respawn
AddEventHandler('esx:onPlayerDeath', function(data)
    -- Custom death handling will be implemented later
end)

-- Commands
RegisterCommand('role', function()
    if playerData.role then
        ESX.ShowNotification(string.format('🎖️ Current Role: %s', Config.Roles[playerData.role].label))
    end
end)

RegisterCommand('money', function()
    if playerData.money then
        ESX.ShowNotification(string.format('💰 Money: $%d', playerData.money))
    end
end)

-- Utility Functions
function WarzonePlayer.GetData()
    return playerData
end

function WarzonePlayer.IsLoggedIn()
    return isLoggedIn
end

function WarzonePlayer.IsInCombat()
    return combatStatus
end