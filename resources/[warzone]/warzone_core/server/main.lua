-- resources/[warzone]/warzone_core/server/main.lua

WarzoneCore = {}
WarzonePlayer = {}

-- Initialize core system
function WarzoneCore.Init()
    print("^2[WARZONE CORE] Initializing core system...^7")
    
    -- Wait for ESX
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    
    -- Initialize database
    WarzoneCore.InitDatabase()
    
    -- Setup player management
    WarzoneCore.SetupPlayerEvents()
    
    print("^2[WARZONE CORE] Core system initialized successfully!^7")
end

-- Initialize database tables
function WarzoneCore.InitDatabase()
    local queries = {
        [[CREATE TABLE IF NOT EXISTS warzone_players (
            identifier VARCHAR(50) PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            kills INT DEFAULT 0,
            deaths INT DEFAULT 0,
            credits INT DEFAULT 5000,
            playtime INT DEFAULT 0,
            last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            data JSON DEFAULT '{}'
        )]],
        
        [[CREATE TABLE IF NOT EXISTS warzone_crews (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(50) UNIQUE NOT NULL,
            leader VARCHAR(50) NOT NULL,
            members JSON DEFAULT '[]',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            data JSON DEFAULT '{}'
        )]],
        
        [[CREATE TABLE IF NOT EXISTS warzone_statistics (
            id INT AUTO_INCREMENT PRIMARY KEY,
            player_id VARCHAR(50) NOT NULL,
            event_type VARCHAR(50) NOT NULL,
            event_data JSON DEFAULT '{}',
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )]]
    }
    
    for _, query in ipairs(queries) do
        MySQL.query(query, {}, function(result)
            if result then
                WarzoneUtils.Log('info', 'Database table created/verified')
            end
        end)
    end
end

-- Setup player events
function WarzoneCore.SetupPlayerEvents()
    -- Player connecting
    AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
        local source = source
        local identifier = ESX.GetIdentifier(source)
        
        WarzoneUtils.Log('info', 'Player %s (%s) connecting...', name, identifier)
    end)
    
    -- Player joined
    AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
        WarzonePlayer.Load(playerId, xPlayer)
    end)
    
    -- Player left
    AddEventHandler('esx:playerDropped', function(playerId, reason)
        WarzonePlayer.Unload(playerId)
    end)
end

-- Player management
function WarzonePlayer.Load(playerId, xPlayer)
    local identifier = xPlayer.identifier
    
    -- Load player data from database
    MySQL.single('SELECT * FROM warzone_players WHERE identifier = ?', {identifier}, function(result)
        if result then
            -- Player exists, load data
            WarzonePlayer[playerId] = {
                identifier = identifier,
                name = xPlayer.getName(),
                kills = result.kills or 0,
                deaths = result.deaths or 0,
                credits = result.credits or 5000,
                playtime = result.playtime or 0,
                data = json.decode(result.data) or {}
            }
        else
            -- New player, create record
            WarzonePlayer[playerId] = {
                identifier = identifier,
                name = xPlayer.getName(),
                kills = 0,
                deaths = 0,
                credits = 5000,
                playtime = 0,
                data = {}
            }
            
            MySQL.insert('INSERT INTO warzone_players (identifier, name) VALUES (?, ?)', {
                identifier, xPlayer.getName()
            })
        end
        
        WarzoneUtils.Log('info', 'Player %s loaded successfully', xPlayer.getName())
        TriggerClientEvent('warzone_core:playerLoaded', playerId, WarzonePlayer[playerId])
    end)
end

function WarzonePlayer.Unload(playerId)
    if WarzonePlayer[playerId] then
        WarzonePlayer.Save(playerId)
        WarzonePlayer[playerId] = nil
        WarzoneUtils.Log('info', 'Player %s unloaded', playerId)
    end
end

function WarzonePlayer.Save(playerId)
    local playerData = WarzonePlayer[playerId]
    if not playerData then return end
    
    MySQL.update('UPDATE warzone_players SET kills = ?, deaths = ?, credits = ?, playtime = ?, data = ? WHERE identifier = ?', {
        playerData.kills,
        playerData.deaths, 
        playerData.credits,
        playerData.playtime,
        json.encode(playerData.data),
        playerData.identifier
    })
end

-- Export functions
exports('GetPlayerData', function(playerId)
    return WarzonePlayer[playerId]
end)

exports('SavePlayerData', function(playerId)
    return WarzonePlayer.Save(playerId)
end)

-- Initialize when resource starts
Citizen.CreateThread(function()
    WarzoneCore.Init()
end)

-- Auto-save players every 5 minutes
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- 5 minutes
        
        for playerId, _ in pairs(WarzonePlayer) do
            WarzonePlayer.Save(playerId)
        end
        
        WarzoneUtils.Log('info', 'Auto-saved all player data')
    end
end)