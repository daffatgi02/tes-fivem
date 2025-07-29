-- resources/[warzone]/warzone_combat/client/armor.lua

local WarzoneArmorClient = {}
local armorKits = 0
local maxArmorKits = 3
local lastArmorRepair = 0
local repairCooldown = 5000 -- 5 seconds

local ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Initialize armor system
function WarzoneArmorClient.Init()
    local armorConfig = WarzoneCombatConfigClient.GetArmor()
    if armorConfig.armor and armorConfig.armor.system then
        maxArmorKits = armorConfig.armor.system.maxArmorKits or 3
        repairCooldown = (armorConfig.armor.system.repairCooldown or 5.0) * 1000
    end

    print("^2[WARZONE ARMOR] Client armor system initialized^7")
end

-- Use armor kit
function WarzoneArmorClient.UseArmorKit()
    if armorKits <= 0 then
        ESX.ShowNotification('❌ No armor kits available')
        return false
    end

    local currentTime = GetGameTimer()
    if currentTime - lastArmorRepair < repairCooldown then
        local remaining = math.ceil((repairCooldown - (currentTime - lastArmorRepair)) / 1000)
        ESX.ShowNotification(string.format('⏳ Armor repair cooldown: %ds', remaining))
        return false
    end

    local ped = PlayerPedId()
    local currentArmor = GetPedArmour(ped)

    if currentArmor >= 100 then
        ESX.ShowNotification('✅ Armor is already at maximum')
        return false
    end

    -- Start repair animation
    WarzoneArmorClient.StartRepairAnimation()

    return true
end

-- Start armor repair animation
function WarzoneArmorClient.StartRepairAnimation()
    local ped = PlayerPedId()
    local armorConfig = WarzoneCombatConfigClient.GetArmor()
    local useTime = armorConfig.armor and armorConfig.armor.kits and armorConfig.armor.kits.basicKit and
        armorConfig.armor.kits.basicKit.useTime or 3.0

    -- Play animation
    RequestAnimDict("mp_arresting")
    while not HasAnimDictLoaded("mp_arresting") do
        Citizen.Wait(0)
    end

    TaskPlayAnim(ped, "mp_arresting", "a_uncuff", 8.0, -8.0, useTime * 1000, 0, 0, false, false, false)

    -- Show progress
    WarzoneArmorClient.ShowRepairProgress(useTime)

    -- Complete repair after animation
    Citizen.SetTimeout(useTime * 1000, function()
        WarzoneArmorClient.CompleteArmorRepair()
    end)
end

-- Show repair progress
function WarzoneArmorClient.ShowRepairProgress(duration)
    local startTime = GetGameTimer()

    Citizen.CreateThread(function()
        while GetGameTimer() - startTime < duration * 1000 do
            Citizen.Wait(0)

            local progress = (GetGameTimer() - startTime) / (duration * 1000)
            local barWidth = 0.2
            local barHeight = 0.02
            local x = 0.5 - barWidth / 2
            local y = 0.8

            -- Background
            DrawRect(x, y, barWidth, barHeight, 0, 0, 0, 200)

            -- Progress bar
            DrawRect(x, y, barWidth * progress, barHeight, 0, 255, 0, 255)

            -- Text
            SetTextFont(4)
            SetTextProportional(true)
            SetTextScale(0.0, 0.4)
            SetTextColour(255, 255, 255, 255)
            SetTextEntry("STRING")
            AddTextComponentString("🛡️ Repairing Armor...")
            DrawText(x, y - 0.05)

            -- Cancel if player moves
            if GetEntitySpeed(PlayerPedId()) > 1.0 then
                ClearPedTasks(PlayerPedId())
                ESX.ShowNotification('❌ Armor repair cancelled')
                return
            end
        end
    end)
end

-- Complete armor repair
function WarzoneArmorClient.CompleteArmorRepair()
    local ped = PlayerPedId()
    local currentArmor = GetPedArmour(ped)

    local armorConfig = WarzoneCombatConfigClient.GetArmor()
    local repairAmount = armorConfig.armor and armorConfig.armor.kits and armorConfig.armor.kits.basicKit and
        armorConfig.armor.kits.basicKit.repairAmount or 25

    local newArmor = math.min(100, currentArmor + repairAmount)
    SetPedArmour(ped, newArmor)

    armorKits = armorKits - 1
    lastArmorRepair = GetGameTimer()

    -- Update server
    TriggerServerEvent('warzone_combat:armorRepaired', repairAmount)

    ESX.ShowNotification(string.format('🛡️ Armor repaired! (%d/%d) | Kits: %d/%d',
        newArmor, 100, armorKits, maxArmorKits))

    ClearPedTasks(ped)
end

-- Share armor with nearby players
function WarzoneArmorClient.ShareArmor()
    if armorKits <= 0 then
        ESX.ShowNotification('❌ No armor kits to share')
        return
    end

    local nearbyPlayers = WarzoneArmorClient.GetNearbyTeammates(5.0)
    if #nearbyPlayers == 0 then
        ESX.ShowNotification('❌ No teammates nearby')
        return
    end

    -- Find teammate with lowest armor
    local targetPlayer = nil
    local lowestArmor = 100

    for _, playerId in ipairs(nearbyPlayers) do
        local targetPed = GetPlayerPed(playerId)
        local targetArmor = GetPedArmour(targetPed)

        if targetArmor < lowestArmor then
            lowestArmor = targetArmor
            targetPlayer = playerId
        end
    end

    if targetPlayer and lowestArmor < 100 then
        TriggerServerEvent('warzone_combat:shareArmor', GetPlayerServerId(targetPlayer))
        armorKits = armorKits - 1
        ESX.ShowNotification(string.format('🤝 Shared armor kit | Remaining: %d/%d', armorKits, maxArmorKits))
    else
        ESX.ShowNotification('✅ All nearby teammates have full armor')
    end
end

-- Get nearby teammates
function WarzoneArmorClient.GetNearbyTeammates(range)
    local teammates = {}
    local playerCoords = GetEntityCoords(PlayerPedId())
    local playerCrew = exports.warzone_crew and exports.warzone_crew:GetCurrentCrew() or nil

    if not playerCrew then return teammates end

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetCoords = GetEntityCoords(GetPlayerPed(playerId))
            local distance = #(playerCoords - targetCoords)

            if distance <= range then
                local targetServerId = GetPlayerServerId(playerId)
                -- Check if in same crew
                for _, member in pairs(playerCrew.members) do
                    if member.source == targetServerId then
                        table.insert(teammates, playerId)
                        break
                    end
                end
            end
        end
    end

    return teammates
end

-- Handle armor kit updates
RegisterNetEvent('warzone_combat:updateArmorKits')
AddEventHandler('warzone_combat:updateArmorKits', function(kits)
    armorKits = kits
end)

RegisterNetEvent('warzone_combat:receiveArmorKit')
AddEventHandler('warzone_combat:receiveArmorKit', function(senderName)
    local ped = PlayerPedId()
    local currentArmor = GetPedArmour(ped)
    local repairAmount = 25

    local newArmor = math.min(100, currentArmor + repairAmount)
    SetPedArmour(ped, newArmor)

    ESX.ShowNotification(string.format('🛡️ Received armor kit from %s! (%d/100)', senderName, newArmor))
end)

-- Controls
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        -- Use armor kit (V key)
        if IsControlJustPressed(0, 52) then
            WarzoneArmorClient.UseArmorKit()
        end

        -- Share armor (B key)
        if IsControlJustPressed(0, 29) then
            WarzoneArmorClient.ShareArmor()
        end
    end
end)

-- HUD Display
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if WarzonePlayer.IsLoggedIn() then
            WarzoneArmorClient.DrawArmorHUD()
        else
            Citizen.Wait(1000)
        end
    end
end)

-- Draw armor HUD
function WarzoneArmorClient.DrawArmorHUD()
    local ped = PlayerPedId()
    local armor = GetPedArmour(ped)

    -- Armor bar
    local barWidth = 0.15
    local barHeight = 0.015
    local x = 0.01
    local y = 0.92

    -- Background
    DrawRect(x + barWidth / 2, y, barWidth, barHeight, 50, 50, 50, 150)

    -- Armor bar
    local armorPercent = armor / 100
    local armorColor = armor > 50 and { 0, 150, 255 } or armor > 25 and { 255, 255, 0 } or { 255, 100, 100 }
    DrawRect(x + (barWidth * armorPercent) / 2, y, barWidth * armorPercent, barHeight, armorColor[1], armorColor[2],
        armorColor[3], 255)

    -- Armor text
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, 0.3)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    AddTextComponentString(string.format("🛡️ %d/100", armor))
    DrawText(x, y - 0.025)

    -- Armor kits
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, 0.3)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    AddTextComponentString(string.format("📦 Kits: %d/%d [V]", armorKits, maxArmorKits))
    DrawText(x, y + 0.02)
end

-- Initialize when configs are loaded
AddEventHandler('warzone_combat:configsLoaded', function()
    WarzoneArmorClient.Init()
end)

-- Export functions
exports('UseArmorKit', WarzoneArmorClient.UseArmorKit)
exports('ShareArmor', WarzoneArmorClient.ShareArmor)
exports('GetArmorKits', function() return armorKits end)
