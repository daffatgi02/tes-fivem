-- resources/[warzone]/warzone_zones/client/zones.lua

WarzoneZonesClient = {}
WarzoneZonesClient.CurrentZone = nil
WarzoneZonesClient.CurrentZoneType = nil
WarzoneZonesClient.ZoneStates = {}
WarzoneZonesClient.PlayerInsideGreen = false

local ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Initialize client zones
Citizen.CreateThread(function()
    while GetResourceState('warzone_core') ~= 'started' do
        Citizen.Wait(100)
    end
    
    WarzoneZonesClient.Init()
end)

-- Initialize zone system
function WarzoneZonesClient.Init()
    print("[WARZONE ZONES] Client zone system initialized")
    
    -- Start zone monitoring
    WarzoneZonesClient.StartZoneMonitoring()
    
    -- Start green zone mechanics
    WarzoneZonesClient.StartGreenZoneMechanics()
    
    -- Initialize zone visuals
    WarzoneZonesClient.StartZoneVisuals()
end

-- Zone monitoring thread
function WarzoneZonesClient.StartZoneMonitoring()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1000) -- Check every second
            
            if WarzonePlayer and WarzonePlayer.IsLoggedIn() then
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                
                WarzoneZonesClient.CheckZoneEntry(playerCoords)
            end
        end
    end)
end

-- Check if player entered/exited zones
function WarzoneZonesClient.CheckZoneEntry(playerCoords)
    local newZone, newZoneType = WarzoneZonesClient.GetZoneByCoords(playerCoords)
    
    -- Check if zone changed
    if newZone and newZone.name ~= WarzoneZonesClient.CurrentZone then
        -- Exited previous zone
        if WarzoneZonesClient.CurrentZone then
            WarzoneZonesClient.ExitZone(WarzoneZonesClient.CurrentZone, WarzoneZonesClient.CurrentZoneType)
        end
        
        -- Entered new zone
        WarzoneZonesClient.EnterZone(newZone.name, newZoneType, newZone.label)
        
    elseif not newZone and WarzoneZonesClient.CurrentZone then
        -- Exited zone completely
        WarzoneZonesClient.ExitZone(WarzoneZonesClient.CurrentZone, WarzoneZonesClient.CurrentZoneType)
    end
end

-- Get zone by coordinates
function WarzoneZonesClient.GetZoneByCoords(coords)
    -- Check green zones first (priority)
    for _, zone in pairs(Config.GreenZones) do
        local distance = #(coords - zone.coords)
        if distance <= zone.radius then
            return zone, 'green'
        end
    end
    
    -- Check combat zones
    for _, zone in pairs(Config.CombatZones) do
        local distance = #(coords - zone.coords)
        if distance <= zone.radius then
            return zone, 'combat'
        end
    end
    
    return nil, nil
end

-- Enter zone
function WarzoneZonesClient.EnterZone(zoneName, zoneType, zoneLabel)
    WarzoneZonesClient.CurrentZone = zoneName
    WarzoneZonesClient.CurrentZoneType = zoneType
    
    if zoneType == 'green' then
        WarzoneZonesClient.PlayerInsideGreen = true
    end
    
    -- Notify server
    TriggerServerEvent('warzone_zones:playerEnteredZone', zoneName, zoneType)
    
    if Config.Debug then
        print(string.format("[WARZONE ZONES] Entered %s zone: %s", zoneType, zoneLabel))
    end
end

-- Exit zone
function WarzoneZonesClient.ExitZone(zoneName, zoneType)
    -- Notify server
    TriggerServerEvent('warzone_zones:playerExitedZone', zoneName, zoneType)
    
    if zoneType == 'green' then
        WarzoneZonesClient.PlayerInsideGreen = false
    end
    
    WarzoneZonesClient.CurrentZone = nil
    WarzoneZonesClient.CurrentZoneType = nil
    
    if Config.Debug then
        print(string.format("[WARZONE ZONES] Exited %s zone: %s", zoneType, zoneName))
    end
end

-- Green zone mechanics
function WarzoneZonesClient.StartGreenZoneMechanics()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            
            if WarzoneZonesClient.PlayerInsideGreen then
                local playerPed = PlayerPedId()
                
                -- Disable weapon firing
                if ZoneConfig.GreenZone.DisableWeapons then
                    DisablePlayerFiring(PlayerId(), true)
                    DisableControlAction(0, 25, true) -- Aim
                    DisableControlAction(0, 68, true) -- Melee Attack A
                    DisableControlAction(0, 91, true) -- Melee Attack B
                    DisableControlAction(0, 92, true) -- Melee Attack C
                    DisableControlAction(0, 24, true) -- Attack
                    DisableControlAction(0, 47, true) -- Weapon Wheel
                    DisableControlAction(0, 264, true) -- Weapon Wheel
                end
                
                -- Disable vehicle damage
                if ZoneConfig.GreenZone.DisableVehicleDamage then
                    local vehicle = GetVehiclePedIsIn(playerPed, false)
                    if vehicle ~= 0 then
                        SetEntityCanBeDamaged(vehicle, false)
                    end
                end
                
                -- Show green zone indicator
                WarzoneZonesClient.DrawGreenZoneIndicator()
            else
                Citizen.Wait(1000)
            end
        end
    end)
end

-- Green zone healing thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if WarzoneZonesClient.PlayerInsideGreen and ZoneConfig.GreenZone.EnableHealing then
            local playerPed = PlayerPedId()
            local currentHealth = GetEntityHealth(playerPed)
            local maxHealth = GetEntityMaxHealth(playerPed)
            
            -- Heal player
            if currentHealth < maxHealth then
                local newHealth = math.min(currentHealth + ZoneConfig.GreenZone.HealRate, maxHealth)
                SetEntityHealth(playerPed, newHealth)
            end
            
            -- Restore armor
            if ZoneConfig.GreenZone.EnableArmorRestore then
                local currentArmor = GetPedArmour(playerPed)
                if currentArmor < ZoneConfig.GreenZone.MaxArmor then
                    local newArmor = math.min(currentArmor + ZoneConfig.GreenZone.ArmorRestoreRate, ZoneConfig.GreenZone.MaxArmor)
                    SetPedArmour(playerPed, newArmor)
                end
            end
        end
    end
end)

-- Draw green zone indicator
function WarzoneZonesClient.DrawGreenZoneIndicator()
    -- Draw text indicator
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, 0.6)
    SetTextColour(0, 255, 0, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString("~g~SAFE ZONE~w~\nWeapons Disabled")
    DrawText(0.5, 0.85)
end

-- Zone visuals thread
function WarzoneZonesClient.StartZoneVisuals()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            
            if WarzonePlayer and WarzonePlayer.IsLoggedIn() then
                local playerCoords = GetEntityCoords(PlayerPedId())
                
                -- Draw combat zone markers
                for _, zone in pairs(Config.CombatZones) do
                    local distance = #(playerCoords - zone.coords)
                    
                    if distance <= ZoneConfig.Visual.DrawDistance then
                        local activityLevel = WarzoneZonesClient.ZoneStates[zone.name] and WarzoneZonesClient.ZoneStates[zone.name].activityLevel or 'white'
                        local color = ZoneConfig.Visual.Colors[activityLevel]
                        
                        -- Draw zone marker
                        DrawMarker(
                            ZoneConfig.Visual.MarkerType,
                            zone.coords.x, zone.coords.y, zone.coords.z - 1.0,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            zone.radius * 2, zone.radius * 2, 2.0,
                            color.r, color.g, color.b, color.a,
                            ZoneConfig.Visual.MarkerBobUpAndDown,
                            true,
                            2,
                            ZoneConfig.Visual.MarkerRotate,
                            false,
                            false
                        )
                        
                        -- Draw zone label
                        if distance <= zone.radius + 50 then
                            WarzoneZonesClient.DrawZoneLabel(zone, activityLevel, distance)
                        end
                    end
                end
                
                -- Draw green zone markers
                for _, zone in pairs(Config.GreenZones) do
                    local distance = #(playerCoords - zone.coords)
                    
                    if distance <= ZoneConfig.Visual.DrawDistance then
                        local color = ZoneConfig.Visual.Colors.green
                        
                        DrawMarker(
                            ZoneConfig.Visual.MarkerType,
                            zone.coords.x, zone.coords.y, zone.coords.z - 1.0,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            zone.radius * 2, zone.radius * 2, 2.0,
                            color.r, color.g, color.b, color.a,
                            ZoneConfig.Visual.MarkerBobUpAndDown,
                            true,
                            2,
                            ZoneConfig.Visual.MarkerRotate,
                            false,
                            false
                        )
                    end
                end
            else
                Citizen.Wait(1000)
            end
        end
    end)
end

-- Draw zone label
function WarzoneZonesClient.DrawZoneLabel(zone, activityLevel, distance)
    local onScreen, screenX, screenY = World3dToScreen2d(zone.coords.x, zone.coords.y, zone.coords.z + 10.0)
    
    if onScreen then
        local scale = 1.0 - (distance / 200.0)
        if scale < 0.3 then scale = 0.3 end
        
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.0, 0.35 * scale)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 255)
        SetTextEntry("STRING")
        
        local activityText = ""
        if activityLevel == 'red' then
            activityText = "~r~[HIGH ACTIVITY]~w~"
        elseif activityLevel == 'yellow' then
            activityText = "~y~[MODERATE ACTIVITY]~w~"
        else
            activityText = "~w~[LOW ACTIVITY]~w~"
        end
        
        AddTextComponentString(string.format("~b~%s~w~\n%s", zone.label, activityText))
        DrawText(screenX, screenY)
    end
end

-- Event Handlers
RegisterNetEvent('warzone_zones:enteredZone')
AddEventHandler('warzone_zones:enteredZone', function(zoneName, zoneType, zoneLabel)
    if ZoneConfig.Notifications.ShowZoneEntry then
        local message = string.format("🌍 Entered: %s", zoneLabel)
        if zoneType == 'green' then
            message = string.format("🛡️ Entered Safe Zone: %s", zoneLabel)
        elseif zoneType == 'combat' then
            local activityLevel = WarzoneZonesClient.ZoneStates[zoneName] and WarzoneZonesClient.ZoneStates[zoneName].activityLevel or 'white'
            if activityLevel == 'red' then
                message = message .. " ~r~[HIGH ACTIVITY]"
            elseif activityLevel == 'yellow' then
                message = message .. " ~y~[MODERATE ACTIVITY]"
            end
        end
        
        ESX.ShowNotification(message)
    end
end)

RegisterNetEvent('warzone_zones:exitedZone')
AddEventHandler('warzone_zones:exitedZone', function(zoneName, zoneType, zoneLabel)
    if ZoneConfig.Notifications.ShowZoneExit then
        local message = string.format("🚪 Exited: %s", zoneLabel)
        ESX.ShowNotification(message)
    end
end)

RegisterNetEvent('warzone_zones:updateActivity')
AddEventHandler('warzone_zones:updateActivity', function(zoneName, activityLevel, recentKills)
    if not WarzoneZonesClient.ZoneStates[zoneName] then
        WarzoneZonesClient.ZoneStates[zoneName] = {}
    end
    
    WarzoneZonesClient.ZoneStates[zoneName].activityLevel = activityLevel
    WarzoneZonesClient.ZoneStates[zoneName].recentKills = recentKills
    
    -- Show activity notification if player is in zone
    if WarzoneZonesClient.CurrentZone == zoneName and ZoneConfig.Notifications.ShowActivityLevel then
        local activityText = ""
        if activityLevel == 'red' then
            activityText = "🔴 HIGH ACTIVITY"
        elseif activityLevel == 'yellow' then
            activityText = "🟡 MODERATE ACTIVITY"
        else
            activityText = "⚪ LOW ACTIVITY"
        end
        
        ESX.ShowNotification(string.format("Zone Activity: %s (%d recent kills)", activityText, recentKills))
    end
    
    -- Update blips
    TriggerEvent('warzone_zones:updateBlip', zoneName, activityLevel)
end)

RegisterNetEvent('warzone_zones:fullUpdate')
AddEventHandler('warzone_zones:fullUpdate', function(zoneStates)
    WarzoneZonesClient.ZoneStates = zoneStates
    
    -- Update all blips
    for zoneName, state in pairs(zoneStates) do
        TriggerEvent('warzone_zones:updateBlip', zoneName, state.activityLevel)
    end
end)

-- Combat entry prevention
AddEventHandler('warzone:setCombatStatus', function(inCombat)
    if inCombat and WarzoneZonesClient.PlayerInsideGreen and ZoneConfig.GreenZone.CombatEntryBlocked then
        -- Force player out of green zone
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Find nearest exit point
        local currentZone = nil
        for _, zone in pairs(Config.GreenZones) do
            if zone.name == WarzoneZonesClient.CurrentZone then
                currentZone = zone
                break
            end
        end
        
        if currentZone then
            -- Calculate exit position
            local direction = playerCoords - currentZone.coords
            direction = direction / #direction -- Normalize
            local exitCoords = currentZone.coords + (direction * (currentZone.radius + 5.0))
            
            SetEntityCoords(playerPed, exitCoords.x, exitCoords.y, exitCoords.z)
            ESX.ShowNotification("⚠️ You have been ejected from the safe zone due to combat status!")
        end
    end
end)

-- Utility functions
function WarzoneZonesClient.GetCurrentZone()
    return WarzoneZonesClient.CurrentZone, WarzoneZonesClient.CurrentZoneType
end

function WarzoneZonesClient.IsInGreenZone()
    return WarzoneZonesClient.PlayerInsideGreen
end

function WarzoneZonesClient.GetZoneActivity(zoneName)
    return WarzoneZonesClient.ZoneStates[zoneName] and WarzoneZonesClient.ZoneStates[zoneName].activityLevel or 'white'
end

-- Export functions
exports('GetCurrentZone', WarzoneZonesClient.GetCurrentZone)
exports('IsInGreenZone', WarzoneZonesClient.IsInGreenZone)
exports('GetZoneActivity', WarzoneZonesClient.GetZoneActivity)