-- resources/[warzone]/warzone_zones/server/zones.lua

WarzoneZones = {}
WarzoneZones.ActiveZones = {}
WarzoneZones.GreenZones = {}

-- Initialize Zone System
function WarzoneZones.Init()
    print("[WARZONE ZONES] Initializing zone system...")
    
    -- Initialize database tables
    WarzoneZones.InitDatabase()
    
    -- Load green zones
    WarzoneZones.LoadGreenZones()
    
    -- Load combat zones
    WarzoneZones.LoadCombatZones()
    
    -- Start activity monitoring
    WarzoneZones.StartActivityMonitoring()
    
    print("[WARZONE ZONES] Zone system initialized successfully!")
end

-- Initialize Database Tables
function WarzoneZones.InitDatabase()
    -- Create zones activity table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_zones_activity` (
            `zone_name` VARCHAR(50) PRIMARY KEY,
            `activity_level` ENUM('white', 'yellow', 'red') DEFAULT 'white',
            `kills_last_5min` INT DEFAULT 0,
            `last_activity` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `total_kills` INT DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `activity_idx` (`activity_level`),
            INDEX `last_activity_idx` (`last_activity`)
        )
    ]])
    
    -- Create zone events table for detailed tracking
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_zone_events` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `zone_name` VARCHAR(50) NOT NULL,
            `event_type` ENUM('kill', 'death', 'entry', 'exit') NOT NULL,
            `player_identifier` VARCHAR(60) NOT NULL,
            `event_data` JSON,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `zone_idx` (`zone_name`),
            INDEX `time_idx` (`created_at`),
            INDEX `player_idx` (`player_identifier`)
        )
    ]])
    
    -- Initialize zone records
    for _, zone in pairs(Config.CombatZones) do
        MySQL.insert('INSERT IGNORE INTO warzone_zones_activity (zone_name) VALUES (?)', {zone.name})
    end
end

-- Load Green Zones
function WarzoneZones.LoadGreenZones()
    for _, zone in pairs(Config.GreenZones) do
        WarzoneZones.GreenZones[zone.name] = {
            name = zone.name,
            label = zone.label,
            coords = zone.coords,
            radius = zone.radius,
            playersInside = {}
        }
    end
    
    print(string.format("[WARZONE ZONES] Loaded %d green zones", #Config.GreenZones))
end

-- Load Combat Zones 
function WarzoneZones.LoadCombatZones()
    for _, zone in pairs(Config.CombatZones) do
        WarzoneZones.ActiveZones[zone.name] = {
            name = zone.name,
            label = zone.label,
            coords = zone.coords,
            radius = zone.radius,
            activityLevel = 'white',
            recentKills = {},
            playersInside = {}
        }
    end
    
    print(string.format("[WARZONE ZONES] Loaded %d combat zones", #Config.CombatZones))
end

-- Get zone by coordinates
function WarzoneZones.GetZoneByCoords(coords)
    -- Check combat zones first
    for zoneName, zone in pairs(WarzoneZones.ActiveZones) do
        local distance = #(coords - zone.coords)
        if distance <= zone.radius then
            return zone, 'combat'
        end
    end
    
    -- Check green zones
    for zoneName, zone in pairs(WarzoneZones.GreenZones) do
        local distance = #(coords - zone.coords)
        if distance <= zone.radius then
            return zone, 'green'
        end
    end
    
    return nil, nil
end

-- Record kill in zone
function WarzoneZones.RecordKill(killerCoords, victimCoords, killerIdentifier, victimIdentifier, weapon, headshot)
    local zone, zoneType = WarzoneZones.GetZoneByCoords(killerCoords)
    
    if zone and zoneType == 'combat' then
        -- Add to recent kills
        table.insert(zone.recentKills, {
            time = os.time(),
            killer = killerIdentifier,
            victim = victimIdentifier,
            weapon = weapon,
            headshot = headshot or false
        })
        
        -- Update database
        local eventData = json.encode({
            killer = killerIdentifier,
            victim = victimIdentifier,
            weapon = weapon,
            headshot = headshot,
            coords = {x = killerCoords.x, y = killerCoords.y, z = killerCoords.z}
        })
        
        MySQL.insert('INSERT INTO warzone_zone_events (zone_name, event_type, player_identifier, event_data) VALUES (?, ?, ?, ?)', 
            {zone.name, 'kill', killerIdentifier, eventData})
        
        -- Update activity level
        WarzoneZones.UpdateZoneActivity(zone.name)
        
        if Config.Debug then
            print(string.format("[WARZONE ZONES] Kill recorded in zone: %s", zone.name))
        end
        
        return zone.name
    end
    
    return "unknown"
end

-- Update zone activity level
function WarzoneZones.UpdateZoneActivity(zoneName)
    local zone = WarzoneZones.ActiveZones[zoneName]
    if not zone then return end
    
    -- Count recent kills (last 5 minutes)
    local currentTime = os.time()
    local recentKills = 0
    
    for i = #zone.recentKills, 1, -1 do
        local kill = zone.recentKills[i]
        if (currentTime - kill.time) <= Config.ZoneThresholds.ActivityWindow then
            recentKills = recentKills + 1
            if kill.headshot then
                recentKills = recentKills + 0.5 -- Headshots count as 1.5 kills
            end
        else
            -- Remove old kills
            table.remove(zone.recentKills, i)
        end
    end
    
    -- Determine activity level
    local newLevel = 'white'
    if recentKills >= Config.ZoneThresholds.RedKills then
        newLevel = 'red'
    elseif recentKills >= Config.ZoneThresholds.YellowKills then
        newLevel = 'yellow'
    end
    
    -- Update if changed
    if zone.activityLevel ~= newLevel then
        zone.activityLevel = newLevel
        
        -- Update database
        MySQL.update('UPDATE warzone_zones_activity SET activity_level = ?, kills_last_5min = ? WHERE zone_name = ?', 
            {newLevel, recentKills, zoneName})
        
        -- Notify all clients
        TriggerClientEvent('warzone_zones:updateActivity', -1, zoneName, newLevel, recentKills)
        
        if Config.Debug then
            print(string.format("[WARZONE ZONES] Zone %s activity: %s (%d kills)", zoneName, newLevel, recentKills))
        end
    end
end

-- Player entered zone
function WarzoneZones.PlayerEnteredZone(source, zoneName, zoneType)
    local zone = zoneType == 'green' and WarzoneZones.GreenZones[zoneName] or WarzoneZones.ActiveZones[zoneName]
    if not zone then return end
    
    zone.playersInside[source] = true
    
    -- Record entry event
    if zoneType == 'combat' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            MySQL.insert('INSERT INTO warzone_zone_events (zone_name, event_type, player_identifier) VALUES (?, ?, ?)', 
                {zoneName, 'entry', xPlayer.identifier})
        end
    end
    
    TriggerClientEvent('warzone_zones:enteredZone', source, zoneName, zoneType, zone.label)
end

-- Player exited zone
function WarzoneZones.PlayerExitedZone(source, zoneName, zoneType)
    local zone = zoneType == 'green' and WarzoneZones.GreenZones[zoneName] or WarzoneZones.ActiveZones[zoneName]
    if not zone then return end
    
    zone.playersInside[source] = nil
    
    -- Record exit event
    if zoneType == 'combat' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            MySQL.insert('INSERT INTO warzone_zone_events (zone_name, event_type, player_identifier) VALUES (?, ?, ?)', 
                {zoneName, 'exit', xPlayer.identifier})
        end
    end
    
    TriggerClientEvent('warzone_zones:exitedZone', source, zoneName, zoneType, zone.label)
end

-- Start activity monitoring
function WarzoneZones.StartActivityMonitoring()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Config.ZoneThresholds.UpdateInterval * 1000)
            
            -- Update all zone activities
            for zoneName, zone in pairs(WarzoneZones.ActiveZones) do
                WarzoneZones.UpdateZoneActivity(zoneName)
            end
            
            -- Send full update to all clients
            TriggerClientEvent('warzone_zones:fullUpdate', -1, WarzoneZones.GetZoneStates())
        end
    end)
end

-- Get all zone states
function WarzoneZones.GetZoneStates()
    local states = {}
    
    for zoneName, zone in pairs(WarzoneZones.ActiveZones) do
        states[zoneName] = {
            name = zoneName,
            activityLevel = zone.activityLevel,
            playerCount = WarzoneUtils.TableSize(zone.playersInside),
            recentKills = #zone.recentKills
        }
    end
    
    return states
end

ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Wait for ESX to be ready before initializing
Citizen.CreateThread(function()
    while ESX == nil do
        Citizen.Wait(10)
    end
    
    -- Wait for warzone_core to be ready
    while GetResourceState('warzone_core') ~= 'started' do
        Citizen.Wait(100)
    end
    
    WarzoneZones.Init()
end)

-- Event Handlers
RegisterNetEvent('warzone_zones:playerEnteredZone')
AddEventHandler('warzone_zones:playerEnteredZone', function(zoneName, zoneType)
    WarzoneZones.PlayerEnteredZone(source, zoneName, zoneType)
end)

RegisterNetEvent('warzone_zones:playerExitedZone')
AddEventHandler('warzone_zones:playerExitedZone', function(zoneName, zoneType)
    WarzoneZones.PlayerExitedZone(source, zoneName, zoneType)
end)

-- Hook into kill system
AddEventHandler('warzone:killRecorded', function(killerSource, victimSource, killerCoords, victimCoords, weapon, headshot)
    local killerPlayer = WarzonePlayer.GetBySource(killerSource)
    local victimPlayer = WarzonePlayer.GetBySource(victimSource)
    
    if killerPlayer and victimPlayer then
        local zoneName = WarzoneZones.RecordKill(killerCoords, victimCoords, killerPlayer.identifier, victimPlayer.identifier, weapon, headshot)
        
        -- Update kill record with zone info
        TriggerEvent('warzone:updateKillZone', killerPlayer.identifier, victimPlayer.identifier, zoneName)
    end
end)

-- Commands for testing
if Config.Debug then
    ESX.RegisterCommand('zonestats', 'admin', function(xPlayer, args, showError)
        local stats = {}
        for zoneName, zone in pairs(WarzoneZones.ActiveZones) do
            table.insert(stats, string.format("%s: %s (%d players, %d recent kills)", 
                zone.label, zone.activityLevel, WarzoneUtils.TableSize(zone.playersInside), #zone.recentKills))
        end
        
        TriggerClientEvent('esx:showNotification', xPlayer.source, table.concat(stats, "\n"))
    end, false, {help = 'Show zone statistics'})
end