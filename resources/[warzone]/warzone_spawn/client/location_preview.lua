-- resources/[warzone]/warzone_spawn/client/location_preview.lua

WarzoneLocationPreview = {}
local previewCamera = nil
local isPreviewActive = false
local previewData = {}
local originalCamera = nil

-- Initialize location preview system
function WarzoneLocationPreview.Init()
    print("^2[WARZONE SPAWN] Location preview system initialized^7")
end

-- Start location preview
function WarzoneLocationPreview.StartPreview(locationId, locationData)
    if isPreviewActive then
        WarzoneLocationPreview.StopPreview()
    end
    
    previewData = {
        locationId = locationId,
        locationData = locationData,
        startTime = GetGameTimer()
    }
    
    -- Get spawn config for preview settings
    local config = WarzoneSpawnConfigClient.GetSpawn()
    
    -- Create preview camera
    local coords = vector3(locationData.coords.x, locationData.coords.y, locationData.coords.z)
    local previewCoords = coords + vector3(0.0, 0.0, 50.0) -- 50m above location
    
    -- Store original camera
    originalCamera = GetRenderingCam()
    
    -- Create new camera
    previewCamera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA",
        previewCoords.x, previewCoords.y, previewCoords.z,
        -45.0, 0.0, 0.0, -- Look down at 45 degrees
        60.0, false, 0)
    
    -- Set camera properties
    SetCamActive(previewCamera, true)
    RenderScriptCams(true, true, 1000, true, false)
    
    isPreviewActive = true
    
    -- Start preview animation
    WarzoneLocationPreview.StartPreviewAnimation()
    
    -- Notify UI
    SendNUIMessage({
        type = 'previewStarted',
        locationId = locationId,
        locationData = locationData
    })
    
    -- Show preview controls
    WarzoneLocationPreview.ShowPreviewControls()
    
    print(string.format("^2[PREVIEW] Started preview for location %s^7", locationId))
end

-- Stop location preview
function WarzoneLocationPreview.StopPreview()
    if not isPreviewActive then return end
    
    isPreviewActive = false
    
    -- Destroy preview camera
    if previewCamera then
        SetCamActive(previewCamera, false)
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(previewCamera, false)
        previewCamera = nil
    end
    
    -- Restore original camera if needed
    if originalCamera and originalCamera ~= -1 then
        SetRenderingCam(originalCamera)
    end
    
    -- Clear preview data
    previewData = {}
    
    -- Notify UI
    SendNUIMessage({
        type = 'previewStopped'
    })
    
    print("^2[PREVIEW] Preview stopped^7")
end

-- Start smooth camera animation
function WarzoneLocationPreview.StartPreviewAnimation()
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        local animationDuration = 8000 -- 8 seconds for full rotation
        local radius = 100.0
        local height = 50.0
        
        local locationCoords = vector3(previewData.locationData.coords.x, 
                                     previewData.locationData.coords.y, 
                                     previewData.locationData.coords.z)
        
        while isPreviewActive do
            local currentTime = GetGameTimer()
            local elapsed = currentTime - startTime
            local progress = (elapsed % animationDuration) / animationDuration
            
            -- Calculate circular motion
            local angle = progress * 2 * math.pi
            local camX = locationCoords.x + math.cos(angle) * radius
            local camY = locationCoords.y + math.sin(angle) * radius
            local camZ = locationCoords.z + height
            
            -- Update camera position
            if previewCamera then
                SetCamCoord(previewCamera, camX, camY, camZ)
                PointCamAtCoord(previewCamera, locationCoords.x, locationCoords.y, locationCoords.z)
            end
            
            -- Update preview info
            WarzoneLocationPreview.UpdatePreviewInfo(progress)
            
            Citizen.Wait(16) -- ~60 FPS
        end
    end)
end

-- Show preview controls
function WarzoneLocationPreview.ShowPreviewControls()
    Citizen.CreateThread(function()
        while isPreviewActive do
            -- Display preview controls
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.0, 0.4)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            
            local controlText = "~w~📹 ~b~LOCATION PREVIEW~w~\n" ..
                              "~INPUT_FRONTEND_ACCEPT~ ~g~Confirm Spawn~w~\n" ..
                              "~INPUT_FRONTEND_CANCEL~ ~r~Cancel Preview~w~\n" ..
                              "~INPUT_MOVE_LR~ ~INPUT_MOVE_UD~ ~y~Manual Control~w~"
            
            AddTextComponentString(controlText)
            DrawText(0.02, 0.15)
            
            -- Handle input
            if IsControlJustPressed(0, 201) then -- Enter key
                TriggerEvent('warzone_spawn:confirmPreviewSpawn', previewData.locationId)
                break
            elseif IsControlJustPressed(0, 194) then -- Backspace/Cancel
                WarzoneLocationPreview.StopPreview()
                break
            end
            
            -- Manual camera control
            WarzoneLocationPreview.HandleManualControl()
            
            Citizen.Wait(0)
        end
    end)
end

-- Handle manual camera control
function WarzoneLocationPreview.HandleManualControl()
    if not previewCamera then return end
    
    local moveSpeed = 2.0
    local rotateSpeed = 1.0
    
    -- Get current camera position and rotation
    local camCoords = GetCamCoord(previewCamera)
    local camRot = GetCamRot(previewCamera)
    
    -- Movement controls
    local newX, newY, newZ = camCoords.x, camCoords.y, camCoords.z
    local newRotX, newRotY, newRotZ = camRot.x, camRot.y, camRot.z
    
    -- Movement (WASD + QE for up/down)
    if IsControlPressed(0, 32) then -- W
        newY = newY + moveSpeed
    elseif IsControlPressed(0, 33) then -- S
        newY = newY - moveSpeed
    end
    
    if IsControlPressed(0, 34) then -- A
        newX = newX - moveSpeed
    elseif IsControlPressed(0, 35) then -- D
        newX = newX + moveSpeed
    end
    
    if IsControlPressed(0, 44) then -- Q
        newZ = newZ + moveSpeed
    elseif IsControlPressed(0, 38) then -- E
        newZ = newZ - moveSpeed
    end
    
    -- Rotation (Mouse)
    local mouseX = GetDisabledControlNormal(0, 1) -- Mouse X
    local mouseY = GetDisabledControlNormal(0, 2) -- Mouse Y
    
    if math.abs(mouseX) > 0.01 or math.abs(mouseY) > 0.01 then
        newRotZ = newRotZ - mouseX * rotateSpeed * 50
        newRotX = newRotX - mouseY * rotateSpeed * 50
        
        -- Clamp vertical rotation
        newRotX = math.max(-89.0, math.min(89.0, newRotX))
    end
    
    -- Apply changes
    SetCamCoord(previewCamera, newX, newY, newZ)
    SetCamRot(previewCamera, newRotX, newRotY, newRotZ)
end

-- Update preview information display
function WarzoneLocationPreview.UpdatePreviewInfo(progress)
    local location = previewData.locationData
    local elapsed = GetGameTimer() - previewData.startTime
    
    -- Send updated info to UI
    SendNUIMessage({
        type = 'updatePreviewInfo',
        data = {
            locationName = location.name,
            category = location.category,
            safetyLevel = location.safetyLevel or 'Unknown',
            nearbyPlayers = WarzoneLocationPreview.GetNearbyPlayerCount(),
            previewTime = math.floor(elapsed / 1000),
            animationProgress = progress
        }
    })
end

-- Get nearby player count for preview
function WarzoneLocationPreview.GetNearbyPlayerCount()
    if not previewData.locationData then return 0 end
    
    local location = previewData.locationData
    local coords = vector3(location.coords.x, location.coords.y, location.coords.z)
    local players = GetActivePlayers()
    local nearbyCount = 0
    
    for _, playerId in ipairs(players) do
        local playerPed = GetPlayerPed(playerId)
        if DoesEntityExist(playerPed) then
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(coords - playerCoords)
            
            if distance < 100.0 then -- 100m radius
                nearbyCount = nearbyCount + 1
            end
        end
    end
    
    return nearbyCount
end

-- Get preview tactical data
function WarzoneLocationPreview.GetTacticalData()
    if not previewData.locationData then return {} end
    
    local location = previewData.locationData
    local coords = vector3(location.coords.x, location.coords.y, location.coords.z)
    
    -- Analyze tactical situation
    local tacticalData = {
        coverPoints = WarzoneLocationPreview.AnalyzeCover(coords),
        elevationAdvantage = WarzoneLocationPreview.AnalyzeElevation(coords),
        escapeRoutes = WarzoneLocationPreview.AnalyzeEscapeRoutes(coords),
        sightLines = WarzoneLocationPreview.AnalyzeSightLines(coords)
    }
    
    return tacticalData
end

-- Analyze cover around location
function WarzoneLocationPreview.AnalyzeCover(coords)
    local coverPoints = {}
    local radius = 50.0
    local checkPoints = 8
    
    for i = 1, checkPoints do
        local angle = (i / checkPoints) * 2 * math.pi
        local checkX = coords.x + math.cos(angle) * radius
        local checkY = coords.y + math.sin(angle) * radius
        
        -- Simple cover analysis (you can enhance this)
        local groundZ = GetGroundZFor_3dCoord(checkX, checkY, coords.z + 50.0)
        local coverScore = math.random(1, 5) -- Placeholder for actual analysis
        
        table.insert(coverPoints, {
            coords = vector3(checkX, checkY, groundZ),
            score = coverScore,
            angle = angle
        })
    end
    
    return coverPoints
end

-- Analyze elevation advantage
function WarzoneLocationPreview.AnalyzeElevation(coords)
    local surroundingHeights = {}
    local radius = 100.0
    local checkPoints = 16
    
    for i = 1, checkPoints do
        local angle = (i / checkPoints) * 2 * math.pi
        local checkX = coords.x + math.cos(angle) * radius
        local checkY = coords.y + math.sin(angle) * radius
        local checkZ = GetGroundZFor_3dCoord(checkX, checkY, coords.z + 50.0)
        
        table.insert(surroundingHeights, checkZ)
    end
    
    -- Calculate average surrounding height
    local avgHeight = 0
    for _, height in ipairs(surroundingHeights) do
        avgHeight = avgHeight + height
    end
    avgHeight = avgHeight / #surroundingHeights
    
    return {
        locationHeight = coords.z,
        averageSurroundingHeight = avgHeight,
        elevationAdvantage = coords.z - avgHeight,
        rating = coords.z > avgHeight and 'Advantage' or 'Disadvantage'
    }
end

-- Analyze escape routes
function WarzoneLocationPreview.AnalyzeEscapeRoutes(coords)
    local routes = {}
    local directions = {'North', 'South', 'East', 'West', 'Northeast', 'Northwest', 'Southeast', 'Southwest'}
    
    for i, direction in ipairs(directions) do
        local angle = (i / #directions) * 2 * math.pi
        local routeScore = math.random(1, 5) -- Placeholder for actual route analysis
        
        table.insert(routes, {
            direction = direction,
            score = routeScore,
            angle = angle
        })
    end
    
    return routes
end

-- Analyze sight lines
function WarzoneLocationPreview.AnalyzeSightLines(coords)
    return {
        clearSightLines = math.random(3, 8),
        obstructedLines = math.random(1, 4),
        visibility = math.random(60, 95) .. '%'
    }
end

-- Export functions
exports('StartPreview', WarzoneLocationPreview.StartPreview)
exports('StopPreview', WarzoneLocationPreview.StopPreview)
exports('GetTacticalData', WarzoneLocationPreview.GetTacticalData)

-- Event handlers
RegisterNetEvent('warzone_spawn:previewLocation')
AddEventHandler('warzone_spawn:previewLocation', function(locationId)
    ESX.TriggerServerCallback('warzone_spawn:getLocationData', function(locationData)
        if locationData then
            WarzoneLocationPreview.StartPreview(locationId, locationData)
        else
            ESX.ShowNotification('❌ Unable to load location data', 'error')
        end
    end, locationId)
end)

RegisterNetEvent('warzone_spawn:stopPreview')
AddEventHandler('warzone_spawn:stopPreview', function()
    WarzoneLocationPreview.StopPreview()
end)

RegisterNetEvent('warzone_spawn:confirmPreviewSpawn')
AddEventHandler('warzone_spawn:confirmPreviewSpawn', function(locationId)
    WarzoneLocationPreview.StopPreview()
    TriggerServerEvent('warzone_spawn:requestSpawn', locationId, 'preview')
end)

-- Initialize when ready
Citizen.CreateThread(function()
    WarzoneLocationPreview.Init()
end)