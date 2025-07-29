-- resources/[warzone]/warzone_spawn/client/spawn_ui.lua

WarzoneSpawnUI = {}
local isUIOpen = false
local currentQueueData = nil
local spawnUIVisible = false

-- Initialize spawn UI system
function WarzoneSpawnUI.Init()
    print("^2[WARZONE SPAWN] UI system initialized^7")
    
    -- Register NUI callbacks
    WarzoneSpawnUI.RegisterCallbacks()
    
    -- Setup key bindings
    WarzoneSpawnUI.SetupKeybinds()
end

-- Setup key bindings
function WarzoneSpawnUI.SetupKeybinds()
    RegisterKeyMapping('openspawnmap', 'Open Spawn Map', 'keyboard', 'F4')
    RegisterCommand('openspawnmap', function()
        WarzoneSpawnUI.ToggleSpawnMap()
    end, false)
    
    -- Additional dev commands
    if Config.Debug then
        RegisterCommand('spawnhere', function()
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            TriggerServerEvent('warzone_spawn:forceSpawn', coords)
        end, false)
    end
end

-- Toggle spawn map visibility
function WarzoneSpawnUI.ToggleSpawnMap()
    if isUIOpen then
        WarzoneSpawnUI.CloseSpawnMap()
    else
        WarzoneSpawnUI.OpenSpawnMap()
    end
end

-- Open spawn map
function WarzoneSpawnUI.OpenSpawnMap()
    if isUIOpen then return end
    
    -- Get current player data
    ESX.TriggerServerCallback('warzone_spawn:getPlayerSpawnData', function(spawnData)
        if spawnData then
            isUIOpen = true
            SetNuiFocus(true, true)
            
            -- Send data to NUI
            SendNUIMessage({
                type = 'openSpawnMap',
                data = spawnData
            })
            
            -- Start map rendering
            TriggerEvent('warzone_spawn:startMapRender')
            
            print("^2[SPAWN UI] Spawn map opened^7")
        else
            ESX.ShowNotification('⚠️ Unable to load spawn data', 'error')
        end
    end)
end

-- Close spawn map
function WarzoneSpawnUI.CloseSpawnMap()
    if not isUIOpen then return end
    
    isUIOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        type = 'closeSpawnMap'
    })
    
    -- Stop map rendering
    TriggerEvent('warzone_spawn:stopMapRender')
    
    print("^2[SPAWN UI] Spawn map closed^7")
end

-- Register NUI callbacks
function WarzoneSpawnUI.RegisterCallbacks()
    -- Close map callback
    RegisterNUICallback('closeMap', function(data, cb)
        WarzoneSpawnUI.CloseSpawnMap()
        cb('ok')
    end)
    
    -- Update strategy callback
    RegisterNUICallback('updateStrategy', function(data, cb)
        local strategy = data.strategy
        TriggerServerEvent('warzone_spawn:updateStrategy', strategy)
        cb('ok')
    end)
    
    -- Preview location callback
    RegisterNUICallback('previewLocation', function(data, cb)
        local locationId = data.locationId
        TriggerEvent('warzone_spawn:previewLocation', locationId)
        cb('ok')
    end)
    
    -- Confirm spawn callback
    RegisterNUICallback('confirmSpawn', function(data, cb)
        local locationId = data.locationId
        local strategy = data.strategy
        
        WarzoneSpawnUI.ProcessSpawnRequest(locationId, strategy)
        cb('ok')
    end)
    
    -- Join queue callback
    RegisterNUICallback('joinQueue', function(data, cb)
        local locationId = data.locationId
        TriggerServerEvent('warzone_spawn:joinQueue', locationId)
        cb('ok')
    end)
    
    -- Leave queue callback
    RegisterNUICallback('leaveQueue', function(data, cb)
        TriggerServerEvent('warzone_spawn:leaveQueue')
        cb('ok')
    end)
    
    -- Request location data callback
    RegisterNUICallback('requestLocationData', function(data, cb)
        local locationId = data.locationId
        ESX.TriggerServerCallback('warzone_spawn:getLocationData', function(locationData)
            cb(locationData)
        end, locationId)
    end)
end

-- Process spawn request
function WarzoneSpawnUI.ProcessSpawnRequest(locationId, strategy)
    -- Show loading
    SendNUIMessage({
        type = 'showLoading',
        message = 'Processing spawn request...'
    })
    
    -- Request spawn from server
    ESX.TriggerServerCallback('warzone_spawn:requestSpawn', function(result)
        if result.success then
            WarzoneSpawnUI.HandleSpawnSuccess(result)
        else
            WarzoneSpawnUI.HandleSpawnFailure(result)
        end
    end, locationId, strategy)
end

-- Handle successful spawn
function WarzoneSpawnUI.HandleSpawnSuccess(result)
    SendNUIMessage({
        type = 'hideLoading'
    })
    
    -- Close UI
    WarzoneSpawnUI.CloseSpawnMap()
    
    -- Show success notification
    ESX.ShowNotification('✅ Spawning at ' .. (result.locationName or 'selected location'), 'success')
    
    -- Trigger spawn animation/effects
    if result.coords then
        TriggerEvent('warzone_spawn:performSpawn', result.coords, result.heading)
    end
end

-- Handle spawn failure
function WarzoneSpawnUI.HandleSpawnFailure(result)
    SendNUIMessage({
        type = 'hideLoading'
    })
    
    local reason = result.reason or 'Unknown error'
    local message = 'Spawn failed: ' .. reason
    
    -- Handle specific error types
    if result.errorType == 'queue_required' then
        WarzoneSpawnUI.ShowQueueOption(result)
    elseif result.errorType == 'location_unsafe' then
        SendNUIMessage({
            type = 'locationUnsafe',
            data = result
        })
        ESX.ShowNotification('⚠️ Location unsafe - ' .. reason, 'error')
    else
        ESX.ShowNotification('❌ ' .. message, 'error')
    end
end

-- Show queue option
function WarzoneSpawnUI.ShowQueueOption(result)
    SendNUIMessage({
        type = 'showQueueOption',
        data = {
            locationId = result.locationId,
            queueSize = result.queueSize,
            estimatedWait = result.estimatedWait,
            reason = result.reason
        }
    })
end

-- Update spawn UI with real-time data
function WarzoneSpawnUI.UpdateSpawnData(data)
    if isUIOpen then
        SendNUIMessage({
            type = 'updateSpawnData',
            data = data
        })
    end
end

-- Show queue status
function WarzoneSpawnUI.ShowQueueStatus(queueData)
    currentQueueData = queueData
    
    SendNUIMessage({
        type = 'updateQueueStatus',
        data = queueData
    })
    
    -- Show persistent queue notification
    local message = string.format('Queue Position: %d/%d (Est. %ds)', 
                                  queueData.position, 
                                  queueData.queueSize, 
                                  queueData.estimatedWait)
    
    TriggerEvent('warzone_spawn:showQueueNotification', message)
end

-- Hide queue status
function WarzoneSpawnUI.HideQueueStatus()
    currentQueueData = nil
    
    SendNUIMessage({
        type = 'hideQueueStatus'
    })
    
    TriggerEvent('warzone_spawn:hideQueueNotification')
end

-- Show spawn protection status
function WarzoneSpawnUI.ShowSpawnProtection(duration)
    SendNUIMessage({
        type = 'showSpawnProtection',
        duration = duration
    })
end

-- Update location statistics
function WarzoneSpawnUI.UpdateLocationStats(locationId, stats)
    if isUIOpen then
        SendNUIMessage({
            type = 'updateLocationStats',
            locationId = locationId,
            stats = stats
        })
    end
end

-- Show tactical information
function WarzoneSpawnUI.ShowTacticalInfo(data)
    if isUIOpen then
        SendNUIMessage({
            type = 'updateTacticalInfo',
            data = data
        })
    end
end

-- Export functions
exports('OpenSpawnMap', WarzoneSpawnUI.OpenSpawnMap)
exports('CloseSpawnMap', WarzoneSpawnUI.CloseSpawnMap)
exports('UpdateSpawnData', WarzoneSpawnUI.UpdateSpawnData)
exports('ShowQueueStatus', WarzoneSpawnUI.ShowQueueStatus)

-- Event handlers
RegisterNetEvent('warzone_spawn:openUI')
AddEventHandler('warzone_spawn:openUI', function()
    WarzoneSpawnUI.OpenSpawnMap()
end)

RegisterNetEvent('warzone_spawn:closeUI')
AddEventHandler('warzone_spawn:closeUI', function()
    WarzoneSpawnUI.CloseSpawnMap()
end)

RegisterNetEvent('warzone_spawn:queueJoined')
AddEventHandler('warzone_spawn:queueJoined', function(queueData)
    WarzoneSpawnUI.ShowQueueStatus(queueData)
    ESX.ShowNotification('🕐 Joined spawn queue - Position: ' .. queueData.position, 'info')
end)

RegisterNetEvent('warzone_spawn:queueUpdated')
AddEventHandler('warzone_spawn:queueUpdated', function(queueData)
    WarzoneSpawnUI.ShowQueueStatus(queueData)
end)

RegisterNetEvent('warzone_spawn:queueLeft')
AddEventHandler('warzone_spawn:queueLeft', function()
    WarzoneSpawnUI.HideQueueStatus()
    ESX.ShowNotification('↩️ Left spawn queue', 'info')
end)

RegisterNetEvent('warzone_spawn:queueTimeout')
AddEventHandler('warzone_spawn:queueTimeout', function()
    WarzoneSpawnUI.HideQueueStatus()
    ESX.ShowNotification('⏰ Queue timeout - Please try again', 'error')
end)

RegisterNetEvent('warzone_spawn:spawnSuccess')
AddEventHandler('warzone_spawn:spawnSuccess', function(data)
    WarzoneSpawnUI.HandleSpawnSuccess(data)
end)

RegisterNetEvent('warzone_spawn:spawnFailed')
AddEventHandler('warzone_spawn:spawnFailed', function(data)
    WarzoneSpawnUI.HandleSpawnFailure(data)
end)

RegisterNetEvent('warzone_spawn:locationDataUpdated')
AddEventHandler('warzone_spawn:locationDataUpdated', function(data)
    WarzoneSpawnUI.UpdateSpawnData(data)
end)

RegisterNetEvent('warzone_spawn:tacticalUpdate')
AddEventHandler('warzone_spawn:tacticalUpdate', function(data)
    WarzoneSpawnUI.ShowTacticalInfo(data)
end)

RegisterNetEvent('warzone_spawn:spawnProtectionStarted')
AddEventHandler('warzone_spawn:spawnProtectionStarted', function(duration)
    WarzoneSpawnUI.ShowSpawnProtection(duration)
    ESX.ShowNotification('🛡️ Spawn protection active for ' .. duration .. 's', 'success')
end)

-- Initialize when ready
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    
    WarzoneSpawnUI.Init()
end)