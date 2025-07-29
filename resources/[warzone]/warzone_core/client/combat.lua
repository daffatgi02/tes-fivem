-- resources/[warzone]/warzone_core/client/combat.lua

local combatActive = false
local lastDamageTime = 0

-- Enable Friendly Fire
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Disable automatic weapon switching
        DisablePlayerVehicleRewards(PlayerId())
        
        -- Enable friendly fire for all players
        SetCanAttackFriendly(PlayerPedId(), true, true)
        NetworkSetFriendlyFireOption(true)
        
        -- Disable auto-aim on players
        SetPlayerTargetingMode(0)
    end
end)

-- Combat prevention in green zones
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        
        if WarzonePlayer.IsLoggedIn() and GetResourceState('warzone_zones') == 'started' then
            local inGreenZone = exports.warzone_zones:IsInGreenZone()
            
            if inGreenZone then
                -- Prevent weapon firing
                DisablePlayerFiring(PlayerId(), true)
                
                -- Prevent melee attacks
                DisableControlAction(0, 140, true) -- Melee Attack Light
                DisableControlAction(0, 141, true) -- Melee Attack Heavy
                DisableControlAction(0, 142, true) -- Melee Attack Alternate
                
                -- Prevent throwing weapons
                DisableControlAction(0, 57, true) -- Throw
            end
        end
    end
end)

-- Enhanced kill feed with zone information
RegisterNetEvent('warzone:killFeed')
AddEventHandler('warzone:killFeed', function(data)
    local weaponName = GetDisplayNameFromVehicleModel(data.weapon) or "Unknown"
    local headshotText = data.headshot and " [HEADSHOT]" or ""
    local distanceText = string.format(" (%.0fm)", data.distance)
    local zoneText = data.zone and data.zone ~= "unknown" and string.format(" in %s", data.zone:gsub("_", " ")) or ""
    
    local message = string.format("💀 %s killed %s%s%s%s", 
        data.killer, data.victim, distanceText, headshotText, zoneText)
    
    -- Display kill feed notification
    ESX.ShowNotification(message, "error", 5000)
    
    -- Add to kill feed UI
    TriggerEvent('warzone:addKillFeed', data)
end)

-- Combat Status Monitor
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        
        if WarzonePlayer.IsLoggedIn() then
            local ped = PlayerPedId()
            local currentTime = GetGameTimer()
            
            -- Check if recently damaged
            if HasEntityBeenDamagedByAnyPed(ped) or HasEntityBeenDamagedByAnyVehicle(ped) then
                lastDamageTime = currentTime
                if not combatActive then
                    combatActive = true
                    TriggerServerEvent('warzone:enterCombat')
                end
                ClearEntityLastDamageEntity(ped)
            end
            
            -- Check if shooting
            if IsPedShooting(ped) then
                lastDamageTime = currentTime
                if not combatActive then
                    combatActive = true
                    TriggerServerEvent('warzone:enterCombat')
                end
            end
            
            -- Check combat timeout (90 seconds)
            if combatActive and (currentTime - lastDamageTime) > (Config.CombatTimeout * 1000) then
                combatActive = false
                TriggerServerEvent('warzone:exitCombat')
            end
        end
    end
end)

-- Damage Modifier based on Role
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local entity = args[1]
        local attacker = args[2]
        local damage = args[6]
        local weapon = args[7]
        
        -- If attacker is current player
        if attacker == PlayerPedId() then
            local playerData = WarzonePlayer.GetData()
            if playerData and playerData.role then
                local roleConfig = Config.Roles[playerData.role]
                if roleConfig and roleConfig.damageMultiplier then
                    -- Apply damage multiplier (this is visual only, server handles actual damage)
                    local modifiedDamage = damage * roleConfig.damageMultiplier
                    -- Store for potential server validation
                end
            end
        end
    end
end)

-- Kill Feed Display
RegisterNetEvent('warzone:killFeed')
AddEventHandler('warzone:killFeed', function(data)
    local weaponName = GetDisplayNameFromVehicleModel(data.weapon) or "Unknown"
    local headshotText = data.headshot and " [HEADSHOT]" or ""
    local distanceText = string.format(" (%.0fm)", data.distance)
    
    local message = string.format("💀 %s killed %s%s%s", 
        data.killer, data.victim, distanceText, headshotText)
    
    -- Display kill feed notification
    ESX.ShowNotification(message, "error", 5000)
    
    -- Add to kill feed UI (to be implemented in UI system)
    TriggerEvent('warzone:addKillFeed', data)
end)

-- Respawn Handler
RegisterNetEvent('warzone:respawn')
AddEventHandler('warzone:respawn', function()
    local ped = PlayerPedId()
    
    -- Reset health and revive
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    NetworkResurrectLocalPlayer(Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z, Config.DefaultSpawn.heading, true, false)
    
    -- Clear combat status
    combatActive = false
    lastDamageTime = 0
    
    -- Give basic equipment
    GiveWeaponToPed(ped, `WEAPON_PISTOL`, 250, false, true)
    SetPedArmour(ped, 25) -- Basic armor on spawn
    
    ESX.ShowNotification('🔄 You have respawned!')
end)

-- Anti-Godmode (basic protection)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if WarzonePlayer.IsLoggedIn() then
            local ped = PlayerPedId()
            
            -- Check for potential godmode
            if GetPlayerInvincible(PlayerId()) then
                SetPlayerInvincible(PlayerId(), false)
            end
            
            -- Ensure proper health values
            local health = GetEntityHealth(ped)
            local maxHealth = GetEntityMaxHealth(ped)
            
            if health > maxHealth then
                SetEntityHealth(ped, maxHealth)
            end
        end
    end
end)

-- Weapon Restrictions based on Role
function CheckWeaponAccess(weapon)
    local playerData = WarzonePlayer.GetData()
    if not playerData or not playerData.role then return false end
    
    local roleConfig = Config.Roles[playerData.role]
    if not roleConfig or not roleConfig.weaponAccess then return true end
    
    -- Check weapon category access
    for _, category in pairs(Config.WeaponCategories) do
        for _, weaponData in pairs(category.weapons) do
            if weaponData.hash == weapon then
                for _, allowedCategory in pairs(roleConfig.weaponAccess) do
                    if allowedCategory == _ then -- category name
                        return true
                    end
                end
                return false
            end
        end
    end
    
    return true -- Default allow if weapon not found in config
end

-- Block weapon pickup if not allowed for role
AddEventHandler('esx:onPickup', function(pickup)
    if pickup.type == 'item_weapon' then
        local weapon = GetHashKey(pickup.name)
        if not CheckWeaponAccess(weapon) then
            ESX.ShowNotification('❌ Your role cannot use this weapon!')
            return false
        end
    end
end)