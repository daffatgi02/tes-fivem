-- resources/[warzone]/warzone_combat/client/combat.lua

local WarzoneCombatClient = {}
local currentWeaponData = {}
local combatMode = false
local lastDamageTime = 0

local ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Initialize combat client
function WarzoneCombatClient.Init()
    print("^2[WARZONE COMBAT] Client combat system initialized^7")

    -- Start combat monitoring
    WarzoneCombatClient.StartCombatThread()
end

-- Start combat monitoring thread
function WarzoneCombatClient.StartCombatThread()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)

            local ped = PlayerPedId()
            local playerData = WarzonePlayer.GetData()

            if playerData then
                -- Monitor weapon changes
                WarzoneCombatClient.MonitorWeapons(ped)

                -- Apply role-specific combat modifiers
                WarzoneCombatClient.ApplyRoleModifiers(ped, playerData.role)

                -- Handle combat abilities
                WarzoneCombatClient.HandleAbilities(ped, playerData.role)
            else
                Citizen.Wait(1000)
            end
        end
    end)
end

-- Monitor weapon changes and apply data
function WarzoneCombatClient.MonitorWeapons(ped)
    local currentWeapon = GetSelectedPedWeapon(ped)

    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
        local weaponData = WarzoneCombatConfigClient.GetWeaponData(currentWeapon)
        if weaponData then
            -- Apply weapon-specific modifications
            WarzoneCombatClient.ApplyWeaponModifications(ped, currentWeapon, weaponData)
        end
    end
end

-- Apply weapon modifications
function WarzoneCombatClient.ApplyWeaponModifications(ped, weaponHash, weaponData)
    -- Apply accuracy modifications
    if weaponData.accuracy then
        SetPlayerWeaponDamageModifier(PlayerId(), weaponData.accuracy)
    end

    -- Apply range modifications
    if weaponData.range then
        -- Visual feedback for range
        if weaponData.range > 100 then
            SetPedCanSwitchWeapon(ped, true)
        end
    end

    -- Store current weapon data
    currentWeaponData[weaponHash] = weaponData
end

-- Apply role-specific modifiers
function WarzoneCombatClient.ApplyRoleModifiers(ped, roleName)
    local roleData = WarzoneCombatConfigClient.GetRoleData(roleName)
    if not roleData or not roleData.stats then return end

    local stats = roleData.stats

    -- Apply speed modifier
    if stats.speedMultiplier then
        SetPedMoveRateOverride(ped, stats.speedMultiplier)
    end

    -- Apply accuracy modifier
    if stats.accuracyMultiplier then
        SetPlayerWeaponDamageModifier(PlayerId(), stats.accuracyMultiplier)
    end

    -- Apply reload speed modifier
    if stats.reloadSpeedMultiplier then
        SetWeaponAnimationOverride(ped, GetHashKey("RELOAD_SPEED"), stats.reloadSpeedMultiplier)
    end
end

-- Handle role abilities
function WarzoneCombatClient.HandleAbilities(ped, roleName)
    local roleData = WarzoneCombatConfigClient.GetRoleData(roleName)
    if not roleData or not roleData.abilities then return end

    -- Check for ability key presses
    if IsControlJustPressed(0, 47) then -- G key
        WarzoneCombatClient.TriggerPrimaryAbility(roleName)
    end

    if IsControlJustPressed(0, 74) then -- H key
        WarzoneCombatClient.TriggerSecondaryAbility(roleName)
    end
end

-- Trigger primary role ability
function WarzoneCombatClient.TriggerPrimaryAbility(roleName)
    local roleData = WarzoneCombatConfigClient.GetRoleData(roleName)
    if not roleData then return end

    if roleName == "assault" then
        WarzoneCombatClient.TriggerExplosiveAmmo()
    elseif roleName == "support" then
        WarzoneCombatClient.TriggerAmmoSharing()
    elseif roleName == "medic" then
        WarzoneCombatClient.TriggerFastRevive()
    elseif roleName == "recon" then
        WarzoneCombatClient.TriggerEnemySpotting()
    end
end

-- Assault: Explosive ammo ability
function WarzoneCombatClient.TriggerExplosiveAmmo()
    TriggerServerEvent('warzone_combat:useAbility', 'explosiveAmmo')
end

-- Support: Ammo sharing ability
function WarzoneCombatClient.TriggerAmmoSharing()
    local nearbyPlayers = WarzoneCombatClient.GetNearbyPlayers(10.0)
    if #nearbyPlayers > 0 then
        TriggerServerEvent('warzone_combat:shareAmmo', nearbyPlayers)
        ESX.ShowNotification('🎒 Sharing ammo with nearby team members...')
    else
        ESX.ShowNotification('❌ No team members nearby')
    end
end

-- Medic: Fast revive ability
function WarzoneCombatClient.TriggerFastRevive()
    local nearbyPlayers = WarzoneCombatClient.GetNearbyPlayers(5.0)
    for _, playerId in ipairs(nearbyPlayers) do
        local targetPed = GetPlayerPed(playerId)
        if IsEntityDead(targetPed) then
            TriggerServerEvent('warzone_combat:fastRevive', GetPlayerServerId(playerId))
            ESX.ShowNotification('🏥 Fast reviving teammate...')
            break
        end
    end
end

-- Recon: Enemy spotting ability
function WarzoneCombatClient.TriggerEnemySpotting()
    local roleData = WarzoneCombatConfigClient.GetRoleData("recon")
    if not roleData.abilities.enemySpotting then return end

    local range = roleData.abilities.enemySpotting.range
    local enemies = WarzoneCombatClient.GetNearbyEnemies(range)

    for _, enemyId in ipairs(enemies) do
        local enemyPed = GetPlayerPed(enemyId)
        local blip = AddBlipForEntity(enemyPed)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1) -- Red
        SetBlipScale(blip, 1.0)
        SetBlipAsShortRange(blip, false)

        -- Auto-remove blip after duration
        Citizen.SetTimeout(roleData.abilities.enemySpotting.duration * 1000, function()
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end)
    end

    TriggerServerEvent('warzone_combat:useAbility', 'enemySpotting')
    ESX.ShowNotification(string.format('🔭 Spotted %d enemies in %dm radius', #enemies, range))
end

-- Get nearby players
function WarzoneCombatClient.GetNearbyPlayers(range)
    local players = {}
    local playerCoords = GetEntityCoords(PlayerPedId())

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetCoords = GetEntityCoords(GetPlayerPed(playerId))
            local distance = #(playerCoords - targetCoords)

            if distance <= range then
                table.insert(players, playerId)
            end
        end
    end

    return players
end

-- Get nearby enemies (players not in same crew)
function WarzoneCombatClient.GetNearbyEnemies(range)
    local enemies = {}
    local playerCoords = GetEntityCoords(PlayerPedId())
    local playerCrew = exports.warzone_crew and exports.warzone_crew:GetCurrentCrew() or nil

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetCoords = GetEntityCoords(GetPlayerPed(playerId))
            local distance = #(playerCoords - targetCoords)

            if distance <= range then
                -- Check if not in same crew
                local isEnemy = true
                if playerCrew then
                    local targetServerId = GetPlayerServerId(playerId)
                    for _, member in pairs(playerCrew.members) do
                        if member.source == targetServerId then
                            isEnemy = false
                            break
                        end
                    end
                end

                if isEnemy then
                    table.insert(enemies, playerId)
                end
            end
        end
    end

    return enemies
end

-- Handle weapon data application
RegisterNetEvent('warzone_combat:applyWeaponData')
AddEventHandler('warzone_combat:applyWeaponData', function(weaponHash, data)
    if data.attachments then
        for attachmentName, _ in pairs(data.attachments) do
            local attachmentData = WarzoneCombatConfigClient.GetAttachmentData(attachmentName)
            if attachmentData then
                WarzoneCombatClient.ApplyAttachment(weaponHash, attachmentName, attachmentData)
            end
        end
    end

    -- Update weapon level display
    if data.level and data.level > 1 then
        ESX.ShowNotification(string.format('🔫 %s (Level %d)',
            WarzoneCombatConfigClient.GetWeaponData(weaponHash).name, data.level))
    end
end)

-- Apply weapon attachment
function WarzoneCombatClient.ApplyAttachment(weaponHash, attachmentName, attachmentData)
    local ped = PlayerPedId()

    -- Apply attachment effects
    if attachmentData.effects then
        local effects = attachmentData.effects

        if effects.damageMultiplier then
            SetPlayerWeaponDamageModifier(PlayerId(), effects.damageMultiplier)
        end

        if effects.accuracyBonus then
            -- Visual feedback for accuracy bonus
            SetPlayerWeaponDamageModifier(PlayerId(), 1.0 + effects.accuracyBonus)
        end

        if effects.magazineMultiplier then
            local currentAmmo = GetAmmoInPedWeapon(ped, weaponHash)
            local newAmmo = math.floor(currentAmmo * effects.magazineMultiplier)
            SetPedAmmo(ped, weaponHash, newAmmo)
        end
    end
end

-- Handle ability cooldowns
local abilityCooldowns = {}

RegisterNetEvent('warzone_combat:abilityCooldown')
AddEventHandler('warzone_combat:abilityCooldown', function(abilityName, cooldownTime)
    abilityCooldowns[abilityName] = GetGameTimer() + (cooldownTime * 1000)

    -- Show cooldown notification
    ESX.ShowNotification(string.format('⏳ %s on cooldown (%ds)', abilityName, cooldownTime))
end)

-- Check if ability is on cooldown
function WarzoneCombatClient.IsAbilityOnCooldown(abilityName)
    local cooldownEnd = abilityCooldowns[abilityName]
    return cooldownEnd and GetGameTimer() < cooldownEnd
end

-- Combat HUD thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if WarzonePlayer.IsLoggedIn() then
            WarzoneCombatClient.DrawCombatHUD()
        else
            Citizen.Wait(1000)
        end
    end
end)

-- Draw combat HUD
function WarzoneCombatClient.DrawCombatHUD()
    local playerData = WarzonePlayer.GetData()
    if not playerData then return end

    local ped = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(ped)

    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
        local weaponData = WarzoneCombatConfigClient.GetWeaponData(currentWeapon)
        if weaponData then
            -- Draw weapon info
            local ammo = GetAmmoInPedWeapon(ped, currentWeapon)
            local maxAmmo = GetMaxAmmoInClip(ped, currentWeapon, 1)

            local weaponText = string.format("🔫 %s | %d/%d", weaponData.name, ammo, maxAmmo)

            SetTextFont(4)
            SetTextProportional(true)
            SetTextScale(0.0, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextEntry("STRING")
            AddTextComponentString(weaponText)
            DrawText(0.01, 0.85)
        end
    end

    -- Draw role abilities
    local roleData = WarzoneCombatConfigClient.GetRoleData(playerData.role)
    if roleData and roleData.abilities then
        local y = 0.88
        local lineHeight = 0.025

        for abilityName, ability in pairs(roleData.abilities) do
            if ability.enabled then
                local onCooldown = WarzoneCombatClient.IsAbilityOnCooldown(abilityName)
                local color = onCooldown and { 255, 100, 100 } or { 100, 255, 100 }

                local abilityText = string.format("⚡ %s [G]", abilityName)
                if onCooldown then
                    local remaining = math.ceil((abilityCooldowns[abilityName] - GetGameTimer()) / 1000)
                    abilityText = abilityText .. string.format(" (%ds)", remaining)
                end

                SetTextFont(4)
                SetTextProportional(true)
                SetTextScale(0.0, 0.3)
                SetTextColour(color[1], color[2], color[3], 255)
                SetTextEntry("STRING")
                AddTextComponentString(abilityText)
                DrawText(0.01, y)

                y = y + lineHeight
            end
        end
    end
end

-- Initialize when configs are loaded
AddEventHandler('warzone_combat:configsLoaded', function()
    WarzoneCombatClient.Init()
end)

-- Export functions
exports('GetCurrentWeaponData', function() return currentWeaponData end)
exports('IsAbilityOnCooldown', WarzoneCombatClient.IsAbilityOnCooldown)
