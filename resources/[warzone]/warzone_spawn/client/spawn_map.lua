-- resources/[warzone]/warzone_spawn/client/spawn_map.lua

local WarzoneSpawnMap = {}
local mapVisible = false
local selectedLocation = nil
local locationBlips = {}
local previewCamera = nil
local originalCam = nil

local ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Initialize spawn map system
function WarzoneSpawnMap.Init()
    print("^2[WARZONE SPAWN] Client map system initialized^7")
end

-- Open interactive spawn map
function WarzoneSpawnMap.OpenMap()
    if mapVisible then return end
    
    mapVisible = true
    
    -- Setup UI
    WarzoneSpawnMap.SetupMapUI()
    
    -- Create location blips
    WarzoneSpawnMap.CreateLocationBlips()
    
    -- Enable map controls
    WarzoneSpawnMap.EnableMapControls()
    
    -- Show NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "showSpawnMap",
        locations = WarzoneSpawnMap.GetLocationData(),
        playerData = WarzonePlayer.GetData()
    })
end

-- Close spawn map
function WarzoneSpawnMap.CloseMap()
    if not mapVisible then return end
    
    mapVisible = false
    selectedLocation = nil
    
    -- Cleanup blips
    WarzoneSpawnMap.ClearLocationBlips()
    
    -- Disable map controls
    WarzoneSpawnMap.DisableMapControls()
    
    -- Reset camera
    WarzoneSpawnMap.ResetCamera()
    
    -- Hide NUI
    SetNuiFocus(false, false)
    SendNUIMessage({type = "hideSpawnMap"})
end

-- Setup map UI elements
function WarzoneSpawnMap.SetupMapUI()
    -- Disable radar and HUD elements for cleaner map view
    DisplayRadar(true)
    SetRadarZoom(1200) -- Zoom out for better overview
    
    -- Store original camera
    if not originalCam then
        originalCam = GetRenderingCam()
    end
end

-- Create interactive location blips
function WarzoneSpawnMap.CreateLocationBlips()
    local locations = WarzoneSpawnConfigClient.GetLocations()
    
    for categoryName, category in pairs(locations.categories) do
        for locationId, location in pairs(category.locations) do
            local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
            
            -- Configure blip appearance
            SetBlipSprite(blip, WarzoneSpawnMap.GetCategoryIcon(categoryName))
            SetBlipColour(blip, WarzoneSpawnMap.GetCategoryColor(categoryName))
            SetBlipScale(blip, 1.2)
            SetBlipAsShortRange(blip, false)
            
            -- Add blip name
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(string.format("%s %s", category.icon, location.name))
            EndTextCommandSetBlipName(blip)
            
            -- Store blip reference
            locationBlips[locationId] = {
                blip = blip,
                location = location,
                category = categoryName
            }
        end
    end
end

-- Clear all location blips
function WarzoneSpawnMap.ClearLocationBlips()
    for locationId, blipData in pairs(locationBlips) do
        if DoesBlipExist(blipData.blip) then
            RemoveBlip(blipData.blip)
        end
    end
    locationBlips = {}
end

-- Enable map interaction controls
function WarzoneSpawnMap.EnableMapControls()
    Citizen.CreateThread(function()
        while mapVisible do
            Citizen.Wait(0)
            
            -- Disable unwanted controls
            DisableControlAction(0, 1, true) -- Mouse look
            DisableControlAction(0, 2, true) -- Mouse look
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 142, true) -- Attack 2
            DisableControlAction(0, 143, true) -- Attack 3
            
            -- Handle location selection
            if IsControlJustPressed(0, 38) then -- E key
                local playerCoords = GetEntityCoords(PlayerPedId())
                local nearestLocation = WarzoneSpawnMap.GetNearestLocation(playerCoords)
                
                if nearestLocation and nearestLocation.distance <= 50.0 then
                    WarzoneSpawnMap.SelectLocation(nearestLocation.locationId)
                end
            end
            
            -- Handle preview controls
            if IsControlJustPressed(0, 47) then -- G key
                if selectedLocation then
                    WarzoneSpawnMap.PreviewLocation(selectedLocation)
                end
            end
            
            -- Handle spawn confirmation
            if IsControlJustPressed(0, 191) then -- Enter key
                if selectedLocation then
                    WarzoneSpawnMap.ConfirmSpawn(selectedLocation)
                end
            end
            
            -- Handle map close
            if IsControlJustPressed(0, 322) then -- ESC key
                WarzoneSpawnMap.CloseMap()
            end
        end
    end)
end

-- Disable map controls
function WarzoneSpawnMap.DisableMapControls()
    -- This function is called when map is closed
    -- Controls are automatically re-enabled when the thread ends
end

-- Location selection logic
function WarzoneSpawnMap.SelectLocation(locationId)
    selectedLocation = locationId
    
    local blipData = locationBlips[locationId]
    if blipData then
        -- Highlight selected blip
        SetBlipScale(blipData.blip, 1.5)
        SetBlipFlashes(blipData.blip, true)
        
        -- Unhighlight other blips
        for otherLocationId, otherBlipData in pairs(locationBlips) do
            if otherLocationId ~= locationId then
                SetBlipScale(otherBlipData.blip, 1.2)
                SetBlipFlashes(otherBlipData.blip, false)
            end
        end
        
        -- Update NUI
        SendNUIMessage({
            type = "locationSelected",
            locationId = locationId,
            locationData = blipData.location
        })
        
        -- Show location info
        WarzoneSpawnMap.ShowLocationInfo(blipData.location)
    end
end

-- Preview location with camera
function WarzoneSpawnMap.PreviewLocation(locationId)
    local blipData = locationBlips[locationId]
    if not blipData then return end
    
    local location = blipData.location
    local coords = vector3(location.coords.x, location.coords.y, location.coords.z + 50.0)
    
    -- Create preview camera
    if previewCamera then
        DestroyCam(previewCamera, false)
    end
    
    previewCamera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", 
        coords.x, coords.y, coords.z,
        -45.0, 0.0, 0.0,
        60.0, false, 0)
    
    SetCamActive(previewCamera, true)
    RenderScriptCams(true, true, 1000, true, false)
    
    -- Show preview UI
    SendNUIMessage({
        type = "showLocationPreview",
        locationId = locationId,
        locationData = location
    })
    
    -- Start preview animation
    WarzoneSpawnMap.StartPreviewAnimation(coords, location)
end

-- Animated camera preview
function WarzoneSpawnMap.StartPreviewAnimation(startCoords, location)
    Citizen.CreateThread(function()
        local targetCoords = vector3(location.coords.x, location.coords.y, location.coords.z + 20.0)
        local animationTime = 5000 -- 5 seconds
        local startTime = GetGameTimer()
        
        while GetGameTimer() - startTime < animationTime and previewCamera do
            local progress = (GetGameTimer() - startTime) / animationTime
            
            -- Smooth interpolation
            local currentX = startCoords.x + (targetCoords.x - startCoords.x) * progress
            local currentY = startCoords.y + (targetCoords.y - startCoords.y) * progress
            local currentZ = startCoords.z + (targetCoords.z - startCoords.z) * progress
            
            -- Rotate camera around location
            local angle = progress * 2 * math.pi
            local radius = 30.0
            local camX = location.coords.x + math.cos(angle) * radius
            local camY = location.coords.y + math.sin(angle) * radius
            
            SetCamCoord(previewCamera, camX, camY, currentZ)
            PointCamAtCoord(previewCamera, location.coords.x, location.coords.y, location.coords.z)
            
            Citizen.Wait(16) -- ~60 FPS
        end
    end)
end

-- Reset camera to original state
function WarzoneSpawnMap.ResetCamera()
    if previewCamera then
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(previewCamera, false)
        previewCamera = nil
    end
end

-- Confirm spawn at selected location
function WarzoneSpawnMap.ConfirmSpawn(locationId)
    if not selectedLocation then
        ESX.ShowNotification('❌ No location selected')
        return
    end
    
    -- Get player preferences for spawn strategy
    local strategy = WarzoneSpawnMap.GetPlayerSpawnStrategy()
    
    -- Send spawn request to server
    TriggerServerEvent('warzone_spawn:requestSpawn', locationId, strategy)
    
    -- Close map
    WarzoneSpawnMap.CloseMap()
    
    -- Show loading indicator
    ESX.ShowNotification('🔄 Processing spawn request...')
end

-- Get player spawn strategy preference
function WarzoneSpawnMap.GetPlayerSpawnStrategy()
    -- This could be from UI selection or saved preferences
    return "balanced" -- Default strategy
end

-- Show location information
function WarzoneSpawnMap.ShowLocationInfo(location)
    local infoText = string.format([[
🏃 %s
📍 %s
⚠️ Risk Level: %d/5
👥 Capacity: %d players
🎯 Recommended: %s
    ]], 
        location.name,
        location.description,
        location.riskLevel or 1,
        location.maxCapacity or 8,
        table.concat(location.recommendedRoles or {}, ", ")
    )
    
    -- Display as notification or UI element
    ESX.ShowNotification(infoText)
end

-- Utility functions
function WarzoneSpawnMap.GetLocationData()
    local locations = WarzoneSpawnConfigClient.GetLocations()
    local processedLocations = {}
    
    for categoryName, category in pairs(locations.categories) do
        processedLocations[categoryName] = {
            label = category.label,
            icon = category.icon,
            color = category.color,
            locations = {}
        }
        
        for locationId, location in pairs(category.locations) do
            processedLocations[categoryName].locations[locationId] = {
                name = location.name,
                description = location.description,
                coords = location.coords,
                riskLevel = location.riskLevel,
                advantages = location.advantages,
                disadvantages = location.disadvantages,
                recommendedRoles = location.recommendedRoles,
                maxCapacity = location.maxCapacity
            }
        end
    end
    
    return processedLocations
end

function WarzoneSpawnMap.GetNearestLocation(playerCoords)
    local nearestLocation = nil
    local nearestDistance = math.huge
    
    for locationId, blipData in pairs(locationBlips) do
        local location = blipData.location
        local locationCoords = vector3(location.coords.x, location.coords.y, location.coords.z)
        local distance = #(playerCoords - locationCoords)
        
        if distance < nearestDistance then
            nearestDistance = distance
            nearestLocation = {
                locationId = locationId,
                distance = distance
            }
        end
    end
    
    return nearestLocation
end

function WarzoneSpawnMap.GetCategoryIcon(categoryName)
    local icons = {
        urban = 475,     -- City icon
        industrial = 477, -- Factory icon
        military = 110,   -- Military icon
        remote = 501     -- Mountain icon
    }
    return icons[categoryName] or 1
end

function WarzoneSpawnMap.GetCategoryColor(categoryName)
    local colors = {
        urban = 2,      -- Green
        industrial = 47, -- Orange
        military = 1,    -- Red
        remote = 5      -- Yellow
    }
    return colors[categoryName] or 0
end

-- Event handlers
RegisterNetEvent('warzone_spawn:requestResult')
AddEventHandler('warzone_spawn:requestResult', function(result)
    if result.success then
        ESX.ShowNotification('✅ ' .. result.message)
    else
        ESX.ShowNotification('❌ ' .. result.error)
    end
end)

RegisterNetEvent('warzone_spawn:preTeleport')
AddEventHandler('warzone_spawn:preTeleport', function(location)
    -- Fade screen out
    DoScreenFadeOut(1000)
    
    -- Show teleport message
    ESX.ShowNotification(string.format('🚁 Deploying to %s...', location.name))
end)

RegisterNetEvent('warzone_spawn:postTeleport')
AddEventHandler('warzone_spawn:postTeleport', function(spawnPoint, location)
    -- Wait for fade out to complete
    Citizen.Wait(1000)
    
    -- Fade screen back in
    DoScreenFadeIn(2000)
    
    -- Show spawn success message
    ESX.ShowNotification(string.format('✅ Deployed at %s', location.name))
    
    -- Apply spawn effects
    WarzoneSpawnMap.ApplySpawnEffects(spawnPoint)
end)

RegisterNetEvent('warzone_spawn:spawnProtectionActive')
AddEventHandler('warzone_spawn:spawnProtectionActive', function(duration)
    ESX.ShowNotification(string.format('🛡️ Spawn protection active for %ds', duration))
    
    -- Visual spawn protection effect
    WarzoneSpawnMap.ShowSpawnProtectionEffect(duration)
end)

RegisterNetEvent('warzone_spawn:spawnProtectionExpired')
AddEventHandler('warzone_spawn:spawnProtectionExpired', function()
    ESX.ShowNotification('⚠️ Spawn protection expired')
end)

-- Visual effects
function WarzoneSpawnMap.ApplySpawnEffects(spawnPoint)
    local ped = PlayerPedId()
    
    -- Landing effect
    local coords = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
    
    -- Create particle effect
    RequestNamedPtfxAsset("scr_rcbarry2")
    while not HasNamedPtfxAssetLoaded("scr_rcbarry2") do
        Citizen.Wait(0)
    end
    
    UseParticleFxAssetNextCall("scr_rcbarry2")
    StartParticleFxLoopedAtCoord("scr_clown_appears", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
    
    -- Play sound effect
    PlaySoundFrontend(-1, "PARACHUTE_LAND", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
end

function WarzoneSpawnMap.ShowSpawnProtectionEffect(duration)
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        local endTime = startTime + (duration * 1000)
        
        while GetGameTimer() < endTime do
            Citizen.Wait(0)
            
            -- Draw protection indicator
            local remaining = math.ceil((endTime - GetGameTimer()) / 1000)
            
            SetTextFont(4)
            SetTextProportional(true)
            SetTextScale(0.0, 0.5)
            SetTextColour(0, 255, 0, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextEntry("STRING")
            AddTextComponentString(string.format("🛡️ SPAWN PROTECTION: %ds", remaining))
            DrawText(0.5, 0.05)
            
            -- Pulsing effect
            local alpha = math.abs(math.sin(GetGameTimer() / 500)) * 100 + 155
            DrawRect(0.0, 0.0, 2.0, 2.0, 0, 255, 0, alpha / 10)
        end
    end)
end

-- Commands
RegisterCommand('spawnmap', function()
    WarzoneSpawnMap.OpenMap()
end)

RegisterKeyMapping('spawnmap', 'Open Spawn Map', 'keyboard', 'F4')

-- NUI Callbacks
RegisterNUICallback('selectLocation', function(data, cb)
    WarzoneSpawnMap.SelectLocation(data.locationId)
    cb({success = true})
end)

RegisterNUICallback('previewLocation', function(data, cb)
    WarzoneSpawnMap.PreviewLocation(data.locationId)
    cb({success = true})
end)

RegisterNUICallback('confirmSpawn', function(data, cb)
    WarzoneSpawnMap.ConfirmSpawn(data.locationId)
   cb({success = true})
end)

RegisterNUICallback('closeMap', function(data, cb)
   WarzoneSpawnMap.CloseMap()
   cb({success = true})
end)

RegisterNUICallback('updateStrategy', function(data, cb)
   -- Save player spawn strategy preference
   TriggerServerEvent('warzone_spawn:updatePreferences', {
       strategy = data.strategy,
       categories = data.preferredCategories,
       avoided = data.avoidedLocations,
       crewCoordination = data.crewCoordination
   })
   cb({success = true})
end)

-- Initialize when configs are loaded
AddEventHandler('warzone_spawn:configsLoaded', function()
   WarzoneSpawnMap.Init()
end)

-- Export functions
exports('OpenSpawnMap', WarzoneSpawnMap.OpenMap)
exports('CloseSpawnMap', WarzoneSpawnMap.CloseMap)
exports('GetSelectedLocation', function() return selectedLocation end)