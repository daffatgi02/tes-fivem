-- resources/[warzone]/warzone_combat/server/roles.lua

WarzoneRoles = {}
local playerAbilities = {} -- Track ability cooldowns

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Initialize roles system
function WarzoneRoles.Init()
    print("^2[WARZONE ROLES] Server roles system initialized^7")
end

-- Handle ability usage
RegisterNetEvent('warzone_combat:useAbility')
AddEventHandler('warzone_combat:useAbility', function(abilityName)
    local _source = source
    local player = WarzonePlayer.GetBySource(_source)
    if not player then return end
    
    local roleData = WarzoneCombatConfig.GetRoleData(player.role)
    if not roleData or not roleData.abilities or not roleData.abilities[abilityName] then
        TriggerClientEvent('esx:showNotification', _source, '❌ Ability not available for your role')
        return
    end
    
    local ability = roleData.abilities[abilityName]
    
    -- Check cooldown
    local playerId = player.identifier
    if not playerAbilities[playerId] then
        playerAbilities[playerId] = {}
    end
    
    local lastUsed = playerAbilities[playerId][abilityName] or 0
    local currentTime = os.time()
    
    if currentTime - lastUsed < ability.cooldown then
        local remaining = ability.cooldown - (currentTime - lastUsed)
        TriggerClientEvent('esx:showNotification', _source, 
            string.format('⏳ %s on cooldown (%ds remaining)', abilityName, remaining))
        return
    end
    
    -- Execute ability
    local success = WarzoneRoles.ExecuteAbility(_source, player.role, abilityName, ability)
    
    if success then
        playerAbilities[playerId][abilityName] = currentTime
        TriggerClientEvent('warzone_combat:abilityCooldown', _source, abilityName, ability.cooldown)
    end
end)

-- Execute specific ability
function WarzoneRoles.ExecuteAbility(source, roleName, abilityName, abilityConfig)
    if roleName == "assault" then
        return WarzoneRoles.ExecuteAssaultAbility(source, abilityName, abilityConfig)
    elseif roleName == "support" then
        return WarzoneRoles.ExecuteSupportAbility(source, abilityName, abilityConfig)
    elseif roleName == "medic" then
        return WarzoneRoles.ExecuteMedicAbility(source, abilityName, abilityConfig)
    elseif roleName == "recon" then
        return WarzoneRoles.ExecuteReconAbility(source, abilityName, abilityConfig)
    end
    
    return false
end

-- Assault abilities
function WarzoneRoles.ExecuteAssaultAbility(source, abilityName, config)
    if abilityName == "explosiveAmmo" then
        local playerPed = GetPlayerPed(source)
        local currentWeapon = GetSelectedPedWeapon(playerPed)
        
        if currentWeapon == GetHashKey("WEAPON_UNARMED") then
            TriggerClientEvent('esx:showNotification', source, '❌ No weapon equipped')
            return false
        end
        
        -- Give explosive ammo effect for duration
        TriggerClientEvent('warzone_combat:explosiveAmmoActive', source, config.duration)
        TriggerClientEvent('esx:showNotification', source, 
            string.format('💥 Explosive ammo active for %ds!', config.duration))
        
        return true
        
    elseif abilityName == "damageBoost" then
        TriggerClientEvent('warzone_combat:damageBoostActive', source, config.multiplier, config.duration)
        TriggerClientEvent('esx:showNotification', source, 
            string.format('⚔️ Damage boost active! (+%d%% for %ds)', 
                math.floor((config.multiplier - 1) * 100), config.duration))
        
        return true
    end
    
    return false
end

-- Support abilities
function WarzoneRoles.ExecuteSupportAbility(source, abilityName, config)
    if abilityName == "supplyDrop" then
        local playerCoords = GetEntityCoords(GetPlayerPed(source))
        
        -- Create supply drop
        WarzoneRoles.CreateSupplyDrop(playerCoords, config.contents)
        
        TriggerClientEvent('esx:showNotification', source, '📦 Supply drop deployed!')
        
        -- Notify nearby players
        for _, playerId in ipairs(GetPlayers()) do
            local targetCoords = GetEntityCoords(GetPlayerPed(tonumber(playerId)))
            local distance = #(playerCoords - targetCoords)
            
            if distance <= 100.0 and tonumber(playerId) ~= source then
                TriggerClientEvent('esx:showNotification', tonumber(playerId), 
                    '📦 Supply drop available nearby!')
            end
        end
        
        return true
    end
    
    return false
end

-- Medic abilities
function WarzoneRoles.ExecuteMedicAbility(source, abilityName, config)
    if abilityName == "healthBoost" then
        local playerPed = GetPlayerPed(source)
        local maxHealth = config.maxHealth or 150
        
        SetEntityMaxHealth(playerPed, maxHealth)
        SetEntityHealth(playerPed, maxHealth)
        
        TriggerClientEvent('esx:showNotification', source, 
            string.format('💚 Health boost active! (%d HP for %ds)', maxHealth, config.duration))
        
        -- Reset after duration
        Citizen.SetTimeout(config.duration * 1000, function()
            SetEntityMaxHealth(playerPed, 200) -- Default max health
            if GetEntityHealth(playerPed) > 200 then
                SetEntityHealth(playerPed, 200)
            end
            TriggerClientEvent('esx:showNotification', source, '💚 Health boost expired')
        end)
        
        return true
        
    elseif abilityName == "medicalSupplies" then
        local playerPed = GetPlayerPed(source)
        local currentHealth = GetEntityHealth(playerPed)
        local healAmount = config.healAmount or 50
        local newHealth = math.min(GetEntityMaxHealth(playerPed), currentHealth + healAmount)
        
        SetEntityHealth(playerPed, newHealth)
        
        TriggerClientEvent('esx:showNotification', source, 
            string.format('🏥 Healed %d HP!', healAmount))
        
        return true
    end
    
    return false
end

-- Recon abilities
function WarzoneRoles.ExecuteReconAbility(source, abilityName, config)
    if abilityName == "stealthMode" then
        TriggerClientEvent('warzone_combat:stealthModeActive', source, config.duration)
        TriggerClientEvent('esx:showNotification', source, 
            string.format('👤 Stealth mode active for %ds!', config.duration))
        
        return true
        
    elseif abilityName == "precisionShot" then
        TriggerClientEvent('warzone_combat:precisionShotReady', source, config.damageMultiplier)
        TriggerClientEvent('esx:showNotification', source, 
            string.format('🎯 Precision shot ready! (+%d%% damage)', 
                math.floor((config.damageMultiplier - 1) * 100)))
        
        return true
    end
    
    return false
end

-- Create supply drop
function WarzoneRoles.CreateSupplyDrop(coords, contents)
    -- Spawn supply crate prop
    local crateModel = GetHashKey("prop_box_ammo03a")
    
    RequestModel(crateModel)
    while not HasModelLoaded(crateModel) do
        Citizen.Wait(0)
    end
    
    local crate = CreateObject(crateModel, coords.x, coords.y, coords.z, true, true, true)
    SetEntityHeading(crate, math.random(0, 360))
    
    -- Make it interactive
    TriggerClientEvent('warzone_combat:createSupplyDrop', -1, NetworkGetNetworkIdFromEntity(crate), coords, contents)
    
    -- Auto-cleanup after 5 minutes
    Citizen.SetTimeout(300000, function()
        if DoesEntityExist(crate) then
            DeleteEntity(crate)
        end
    end)
end

-- Handle ammo sharing
RegisterNetEvent('warzone_combat:shareAmmo')
AddEventHandler('warzone_combat:shareAmmo', function(nearbyPlayers)
    local _source = source
    local player = WarzonePlayer.GetBySource(_source)
    if not player then return end
    
    -- Check if support role
    if player.role ~= "support" then
        TriggerClientEvent('esx:showNotification', _source, '❌ Only Support role can share ammo')
        return
    end
    
    local shared = 0
    for _, playerId in ipairs(nearbyPlayers) do
        local targetSource = GetPlayerServerId(playerId)
        local targetPlayer = WarzonePlayer.GetBySource(targetSource)
        
        if targetPlayer and targetPlayer.crew_id == player.crew_id then
            -- Give ammo to target
            TriggerClientEvent('warzone_combat:receiveAmmo', targetSource, player:GetDisplayName())
            shared = shared + 1
        end
    end
    
    if shared > 0 then
        TriggerClientEvent('esx:showNotification', _source, 
            string.format('🎒 Shared ammo with %d teammate(s)', shared))
    else
        TriggerClientEvent('esx:showNotification', _source, '❌ No valid teammates nearby')
    end
end)

-- Handle fast revive
RegisterNetEvent('warzone_combat:fastRevive')
AddEventHandler('warzone_combat:fastRevive', function(targetSource)
    local _source = source
    local player = WarzonePlayer.GetBySource(_source)
    local target = WarzonePlayer.GetBySource(targetSource)
    
    if not player or not target then return end
    
    -- Check if medic role
    if player.role ~= "medic" then
        TriggerClientEvent('esx:showNotification', _source, '❌ Only Medic role can fast revive')
        return
    end
    
    -- Check distance
    local playerPed = GetPlayerPed(_source)
    local targetPed = GetPlayerPed(targetSource)
    local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
    
    if distance > 5.0 then
        TriggerClientEvent('esx:showNotification', _source, '❌ Target too far away')
        return
    end
    
    -- Revive target
    local roleData = WarzoneCombatConfig.GetRoleData("medic")
    local reviveSpeed = roleData.stats and roleData.stats.reviveSpeedMultiplier or 2.5
    
    TriggerClientEvent('warzone_combat:startFastRevive', _source, targetSource, reviveSpeed)
end)

-- Initialize
Citizen.CreateThread(function()
    while GetResourceState('warzone_core') ~= 'started' do
        Citizen.Wait(100)
    end
    
    WarzoneRoles.Init()
end)

-- Export functions
exports('ExecuteAbility', WarzoneRoles.ExecuteAbility)
exports('CreateSupplyDrop', WarzoneRoles.CreateSupplyDrop)