-- resources/[warzone]/warzone_combat/client/attachments.lua

local WarzoneAttachmentsClient = {}
local weaponAttachments = {}
local attachmentUI = false

local ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Initialize attachments system
function WarzoneAttachmentsClient.Init()
    print("^2[WARZONE ATTACHMENTS] Client attachments system initialized^7")
end

-- Open attachment menu
function WarzoneAttachmentsClient.OpenAttachmentMenu()
    local ped = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(ped)
    
    if currentWeapon == GetHashKey("WEAPON_UNARMED") then
        ESX.ShowNotification('❌ No weapon equipped')
        return
    end
    
    local weaponData = WarzoneCombatConfigClient.GetWeaponData(currentWeapon)
    if not weaponData then
        ESX.ShowNotification('❌ Invalid weapon')
        return
    end
    
    local attachmentConfig = WarzoneCombatConfigClient.GetAttachments()
    if not attachmentConfig.attachments then
        ESX.ShowNotification('❌ No attachments available')
        return
    end
    
    local elements = {}
    
    -- Available attachments for this weapon
    for attachmentName, attachment in pairs(attachmentConfig.attachments) do
        local compatible = false
        for _, category in ipairs(attachment.compatibleWeapons) do
            if category == weaponData.category then
                compatible = true
                break
            end
        end
        
        if compatible then
            local hasAttachment = weaponAttachments[currentWeapon] and weaponAttachments[currentWeapon][attachmentName]
            local statusText = hasAttachment and " ✅" or " ❌"
            
            table.insert(elements, {
                label = string.format('%s%s - $%d', attachment.name, statusText, attachment.price),
                value = attachmentName,
                description = attachment.description,
                price = attachment.price,
                hasAttachment = hasAttachment,
                attachment = attachment
            })
        end
    end
    
    if #elements == 0 then
        ESX.ShowNotification('❌ No compatible attachments for this weapon')
        return
    end
    
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'weapon_attachments', {
        title = string.format('🔧 Attachments - %s', weaponData.name),
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        local attachment = data.current.attachment
        local hasAttachment = data.current.hasAttachment
        
        if hasAttachment then
            -- Remove attachment
            WarzoneAttachmentsClient.RemoveAttachment(currentWeapon, data.current.value)
        else
            -- Install attachment
            WarzoneAttachmentsClient.InstallAttachment(currentWeapon, data.current.value, attachment)
        end
        
        menu.close()
        Citizen.SetTimeout(500, function()
            WarzoneAttachmentsClient.OpenAttachmentMenu() -- Refresh menu
        end)
    end, function(data, menu)
        menu.close()
    end)
end

-- Install attachment
function WarzoneAttachmentsClient.InstallAttachment(weaponHash, attachmentName, attachmentData)
    -- Check if player has enough money
    ESX.TriggerServerCallback('warzone_combat:canAffordAttachment', function(canAfford)
        if not canAfford then
            ESX.ShowNotification('❌ Not enough money')
            return
        end
        
        -- Start installation animation
        WarzoneAttachmentsClient.StartInstallationAnimation(attachmentData.installationTime or 2.0, function()
            -- Apply attachment
            if not weaponAttachments[weaponHash] then
                weaponAttachments[weaponHash] = {}
            end
            
            weaponAttachments[weaponHash][attachmentName] = attachmentData
            
            -- Apply effects
            WarzoneAttachmentsClient.ApplyAttachmentEffects(weaponHash, attachmentName, attachmentData)
            
            -- Save to server
            TriggerServerEvent('warzone_combat:installAttachment', weaponHash, attachmentName)
            
            ESX.ShowNotification(string.format('🔧 %s installed!', attachmentData.name))
        end)
    end, attachmentData.price)
end

-- Remove attachment
function WarzoneAttachmentsClient.RemoveAttachment(weaponHash, attachmentName)
    if not weaponAttachments[weaponHash] or not weaponAttachments[weaponHash][attachmentName] then return end
    
    local attachmentData = weaponAttachments[weaponHash][attachmentName]
    
    -- Start removal animation
    WarzoneAttachmentsClient.StartRemovalAnimation(attachmentData.removalTime or 1.5, function()
        -- Remove attachment effects
        WarzoneAttachmentsClient.RemoveAttachmentEffects(weaponHash, attachmentName, attachmentData)
        
        weaponAttachments[weaponHash][attachmentName] = nil
        
        -- Save to server
        TriggerServerEvent('warzone_combat:removeAttachment', weaponHash, attachmentName)
        
        ESX.ShowNotification(string.format('🔧 %s removed!', attachmentData.name))
    end)
end

-- Apply attachment effects
function WarzoneAttachmentsClient.ApplyAttachmentEffects(weaponHash, attachmentName, attachmentData)
    local ped = PlayerPedId()
    
    -- Visual attachment (if supported by weapon)
    local attachmentHash = WarzoneAttachmentsClient.GetAttachmentHash(attachmentName)
    if attachmentHash then
        GiveWeaponComponentToPed(ped, weaponHash, attachmentHash)
    end
    
    -- Apply stat effects
    if attachmentData.effects then
        local effects = attachmentData.effects
        
        -- These effects will be handled by the damage calculation system
        -- We store them in the weapon data for reference
        if not weaponAttachments[weaponHash] then
            weaponAttachments[weaponHash] = {}
        end
        weaponAttachments[weaponHash][attachmentName] = attachmentData
    end
end

-- Remove attachment effects
function WarzoneAttachmentsClient.RemoveAttachmentEffects(weaponHash, attachmentName, attachmentData)
    local ped = PlayerPedId()
    
    -- Remove visual attachment
    local attachmentHash = WarzoneAttachmentsClient.GetAttachmentHash(attachmentName)
    if attachmentHash then
        RemoveWeaponComponentFromPed(ped, weaponHash, attachmentHash)
    end
end

-- Get GTA attachment hash from name
function WarzoneAttachmentsClient.GetAttachmentHash(attachmentName)
    local attachmentHashes = {
        ["suppressor"] = GetHashKey("COMPONENT_AT_AR_SUPP_02"),
        ["flashlight"] = GetHashKey("COMPONENT_AT_AR_FLSH"),
        ["extendedMag"] = GetHashKey("COMPONENT_AT_AR_CLIP_02"),
        ["scope"] = GetHashKey("COMPONENT_AT_SCOPE_MEDIUM"),
        ["advancedScope"] = GetHashKey("COMPONENT_AT_SCOPE_LARGE"),
        ["grip"] = GetHashKey("COMPONENT_AT_AR_AFGRIP"),
        ["compensator"] = GetHashKey("COMPONENT_AT_AR_COMP"),
        ["laserSight"] = GetHashKey("COMPONENT_AT_AR_RAIL_01")
    }
    
    return attachmentHashes[attachmentName]
end

-- Start installation animation
function WarzoneAttachmentsClient.StartInstallationAnimation(duration, callback)
    local ped = PlayerPedId()
    
    RequestAnimDict("mp_weapon_purchase")
    while not HasAnimDictLoaded("mp_weapon_purchase") do
        Citizen.Wait(0)
    end
    
    TaskPlayAnim(ped, "mp_weapon_purchase", "pickup_weapon", 8.0, -8.0, duration * 1000, 0, 0, false, false, false)
    
    -- Show progress
    WarzoneAttachmentsClient.ShowInstallProgress(duration, "Installing attachment...")
    
    Citizen.SetTimeout(duration * 1000, function()
        ClearPedTasks(ped)
        callback()
    end)
end

-- Start removal animation
function WarzoneAttachmentsClient.StartRemovalAnimation(duration, callback)
    local ped = PlayerPedId()
    
    RequestAnimDict("mp_weapon_purchase")
    while not HasAnimDictLoaded("mp_weapon_purchase") do
        Citizen.Wait(0)
    end
    
    TaskPlayAnim(ped, "mp_weapon_purchase", "pickup_weapon", 8.0, -8.0, duration * 1000, 16, 0, false, false, false)
    
    -- Show progress
    WarzoneAttachmentsClient.ShowInstallProgress(duration, "Removing attachment...")
    
    Citizen.SetTimeout(duration * 1000, function()
        ClearPedTasks(ped)
        callback()
    end)
end

-- Show installation progress
function WarzoneAttachmentsClient.ShowInstallProgress(duration, text)
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
            DrawRect(x, y, barWidth * progress, barHeight, 255, 165, 0, 255)
            
            -- Text
            SetTextFont(4)
            SetTextProportional(true)
            SetTextScale(0.0, 0.4)
            SetTextColour(255, 255, 255, 255)
            SetTextEntry("STRING")
            AddTextComponentString("🔧 " .. text)
            DrawText(x, y - 0.05)
            
            -- Cancel if player moves
            if GetEntitySpeed(PlayerPedId()) > 1.0 then
                ClearPedTasks(PlayerPedId())
                ESX.ShowNotification('❌ Installation cancelled')
                return
            end
        end
    end)
end

-- Get weapon attachment effects for damage calculation
function WarzoneAttachmentsClient.GetWeaponAttachmentEffects(weaponHash)
    local effects = {
        damageMultiplier = 1.0,
        accuracyBonus = 0.0,
        rangeBonus = 0.0,
        recoilReduction = 0.0,
        magazineMultiplier = 1.0
    }
    
    if weaponAttachments[weaponHash] then
        for attachmentName, attachmentData in pairs(weaponAttachments[weaponHash]) do
            if attachmentData.effects then
                local attachEffects = attachmentData.effects
                
                if attachEffects.damageMultiplier then
                    effects.damageMultiplier = effects.damageMultiplier * attachEffects.damageMultiplier
                end
                if attachEffects.accuracyBonus then
                    effects.accuracyBonus = effects.accuracyBonus + attachEffects.accuracyBonus
                end
                if attachEffects.rangeBonus then
                    effects.rangeBonus = effects.rangeBonus + attachEffects.rangeBonus
                end
                if attachEffects.recoilReduction then
                    effects.recoilReduction = effects.recoilReduction + attachEffects.recoilReduction
                end
                if attachEffects.magazineMultiplier then
                    effects.magazineMultiplier = effects.magazineMultiplier * attachEffects.magazineMultiplier
                end
            end
        end
    end
    
    return effects
end

-- Commands
RegisterCommand('attachments', function()
    WarzoneAttachmentsClient.OpenAttachmentMenu()
end)

RegisterKeyMapping('attachments', 'Open Attachments Menu', 'keyboard', 'F7')

-- Initialize when configs are loaded
AddEventHandler('warzone_combat:configsLoaded', function()
    WarzoneAttachmentsClient.Init()
end)

-- Export functions
exports('OpenAttachmentMenu', WarzoneAttachmentsClient.OpenAttachmentMenu)
exports('GetWeaponAttachmentEffects', WarzoneAttachmentsClient.GetWeaponAttachmentEffects)