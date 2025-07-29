-- resources/[warzone]/warzone_zones/client/blips.lua

WarzoneBlips = {}
WarzoneBlips.ZoneBlips = {}
WarzoneBlips.GreenZoneBlips = {}

-- Initialize blips
function WarzoneBlips.Init()
    WarzoneBlips.CreateGreenZoneBlips()
    WarzoneBlips.CreateCombatZoneBlips()
    WarzoneBlips.StartBlipUpdater()
end

-- Create green zone blips
function WarzoneBlips.CreateGreenZoneBlips()
    if not ZoneConfig.Blips.ShowGreenZones then return end
    
    for _, zone in pairs(Config.GreenZones) do
        local blip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
        SetBlipAlpha(blip, 80)
        SetBlipColour(blip, 2) -- Green
        
        local labelBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
        SetBlipSprite(labelBlip, zone.blip.sprite)
        SetBlipDisplay(labelBlip, 4)
        SetBlipScale(labelBlip, zone.blip.scale)
        SetBlipColour(labelBlip, zone.blip.color)
        SetBlipAsShortRange(labelBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(string.format("🛡️ %s", zone.label))
        EndTextCommandSetBlipName(labelBlip)
        
        WarzoneBlips.GreenZoneBlips[zone.name] = {
            radius = blip,
            label = labelBlip
        }
    end
    
    print(string.format("[WARZONE ZONES] Created %d green zone blips", #Config.GreenZones))
end

-- Create combat zone blips
function WarzoneBlips.CreateCombatZoneBlips()
    if not ZoneConfig.Blips.ShowCombatZones then return end
    
    for _, zone in pairs(Config.CombatZones) do
        local blip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
        SetBlipAlpha(blip, 60)
        SetBlipColour(blip, 1) -- Red (default)
        
        local labelBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
        SetBlipSprite(labelBlip, zone.blip.sprite)
        SetBlipDisplay(labelBlip, 4)
        SetBlipScale(labelBlip, zone.blip.scale)
        SetBlipColour(labelBlip, zone.blip.color)
        SetBlipAsShortRange(labelBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(string.format("⚔️ %s", zone.label))
        EndTextCommandSetBlipName(labelBlip)
        
        WarzoneBlips.ZoneBlips[zone.name] = {
            radius = blip,
            label = labelBlip,
            activityLevel = 'white'
        }
    end
    
    print(string.format("[WARZONE ZONES] Created %d combat zone blips", #Config.CombatZones))
end

-- Update blip based on activity
function WarzoneBlips.UpdateBlip(zoneName, activityLevel)
    local blipData = WarzoneBlips.ZoneBlips[zoneName]
    if not blipData then return end
    
    blipData.activityLevel = activityLevel
    
    -- Update colors and scale
    local color = 1 -- Default red
    local alpha = 60
    local scale = ZoneConfig.Blips.ScaleMultiplier[activityLevel] or 1.0
    
    if activityLevel == 'red' then
        color = 1 -- Red
        alpha = 100
    elseif activityLevel == 'yellow' then
        color = 5 -- Yellow
        alpha = 80
    elseif activityLevel == 'white' then
        color = 0 -- White
        alpha = 60
    end
    
    -- Update radius blip
    SetBlipColour(blipData.radius, color)
    SetBlipAlpha(blipData.radius, alpha)
    
    -- Update label blip
    SetBlipScale(blipData.label, scale)
    
    -- Update blip name with activity
    BeginTextCommandSetBlipName("STRING")
    local zoneName_clean = zoneName:gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)
    local activityIcon = "⚪"
    if activityLevel == 'red' then
        activityIcon = "🔴"
    elseif activityLevel == 'yellow' then
        activityIcon = "🟡"
    end
    AddTextComponentString(string.format("%s %s", activityIcon, zoneName_clean))
    EndTextCommandSetBlipName(blipData.label)
end

-- Start blip updater
function WarzoneBlips.StartBlipUpdater()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(ZoneConfig.Blips.UpdateInterval)
            
            if ZoneConfig.Blips.ShowActivityLevels then
                -- Update blips based on current zone states
                for zoneName, state in pairs(WarzoneZonesClient.ZoneStates or {}) do
                    WarzoneBlips.UpdateBlip(zoneName, state.activityLevel)
                end
            end
        end
    end)
end

-- Event handler for blip updates
RegisterNetEvent('warzone_zones:updateBlip')
AddEventHandler('warzone_zones:updateBlip', function(zoneName, activityLevel)
    WarzoneBlips.UpdateBlip(zoneName, activityLevel)
end)

-- Initialize when zones are ready
RegisterNetEvent('warzone_zones:clientReady')
AddEventHandler('warzone_zones:clientReady', function()
    WarzoneBlips.Init()
end)

-- Initialize on resource start
Citizen.CreateThread(function()
    while GetResourceState('warzone_core') ~= 'started' do
        Citizen.Wait(100)
    end
    
    Citizen.Wait(2000) -- Wait for zones to load
    WarzoneBlips.Init()
end)